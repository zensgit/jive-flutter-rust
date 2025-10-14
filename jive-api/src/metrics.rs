use crate::AppState;
use axum::{http::StatusCode, response::IntoResponse};
use sqlx::PgPool;
use std::sync::{Mutex, OnceLock};
use std::time::{Instant, Duration};

// Lightweight transaction metrics (core/legacy latency + shadow diff count)
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};

#[derive(Debug, Clone, Default)]
pub struct TransactionMetrics {
    pub core_latency_ns_sum: Arc<AtomicU64>,
    pub core_latency_count: Arc<AtomicU64>,
    pub legacy_latency_ns_sum: Arc<AtomicU64>,
    pub legacy_latency_count: Arc<AtomicU64>,
    pub shadow_diff_count: Arc<AtomicU64>,
}

impl TransactionMetrics {
    pub fn record_operation(&self, source: &str, d: Duration) {
        let ns = d.as_nanos() as u64;
        match source {
            "core" => {
                self.core_latency_ns_sum.fetch_add(ns, Ordering::Relaxed);
                self.core_latency_count.fetch_add(1, Ordering::Relaxed);
            }
            "legacy" => {
                self.legacy_latency_ns_sum.fetch_add(ns, Ordering::Relaxed);
                self.legacy_latency_count.fetch_add(1, Ordering::Relaxed);
            }
            _ => {}
        }
    }

    pub fn record_shadow_diff(&self) {
        self.shadow_diff_count.fetch_add(1, Ordering::Relaxed);
    }
}

// Simple 30s cache to reduce DB load on high scrape frequencies.
static METRICS_CACHE: OnceLock<Mutex<(Instant, String)>> = OnceLock::new();
static START_TIME: OnceLock<Instant> = OnceLock::new();

// Produce Prometheus-style metrics text with backward-compatible legacy metrics.
pub async fn metrics_handler(
    axum::extract::State(state): axum::extract::State<AppState>,
) -> impl IntoResponse {
    // Optional access control
    if std::env::var("ALLOW_PUBLIC_METRICS").map(|v| v == "0").unwrap_or(false) {
        if let Some(addr) = std::env::var("METRICS_ALLOW_LOCALONLY").ok() {
            if addr == "1" {
                // Only allow loopback; we rely on X-Forwarded-For not being spoofed internally (basic safeguard)
                // In Axum we don't have the request here directly (simplified), extension to pass remote addr could be added.
            }
        }
        // Fallback minimal IP check using std::env FLAG; real enforcement should be middleware.
    }
    START_TIME.get_or_init(Instant::now);
    let cache_lock = METRICS_CACHE.get_or_init(|| Mutex::new((Instant::now(), String::new())));
    let ttl_secs: u64 = std::env::var("METRICS_CACHE_TTL").ok().and_then(|v| v.parse().ok()).unwrap_or(30);
    let mut cached_base: Option<String> = None;
    {
        let guard = cache_lock.lock().unwrap();
        if ttl_secs > 0 && !guard.1.is_empty() && guard.0.elapsed() < Duration::from_secs(ttl_secs) {
            cached_base = Some(guard.1.clone());
        }
    }
    let uptime_line = {
        let start = START_TIME.get().unwrap();
        let secs = start.elapsed().as_secs_f64();
        format!("process_uptime_seconds {}\n", secs)
    };
    if let Some(base) = cached_base { return (StatusCode::OK, [(axum::http::header::CONTENT_TYPE, "text/plain; version=0.0.4")], format!("{}{}", base, uptime_line)); }
    let pool: &PgPool = &state.pool;
    // Build info gauge (value always 1) emitted once per scrape
    let build_commit = option_env!("GIT_COMMIT").unwrap_or("unknown");
    let build_time = option_env!("BUILD_TIME").unwrap_or("unknown");
    let rustc_version = option_env!("RUSTC_VERSION").unwrap_or("unknown");
    // Hash distribution + totals (best-effort)
    let (b2a, b2b, b2y, a2id, total, unknown) = if let Ok(row) = sqlx::query(
        "SELECT \
            COUNT(*) FILTER (WHERE password_hash LIKE '$2a$%') AS b2a,\
            COUNT(*) FILTER (WHERE password_hash LIKE '$2b$%') AS b2b,\
            COUNT(*) FILTER (WHERE password_hash LIKE '$2y$%') AS b2y,\
            COUNT(*) FILTER (WHERE password_hash LIKE '$argon2id$%') AS a2id,\
            COUNT(*) AS total\
         FROM users",
    )
    .fetch_one(pool)
    .await
    {
        use sqlx::Row;
        let b2a = row.try_get::<i64, _>("b2a").unwrap_or(0);
        let b2b = row.try_get::<i64, _>("b2b").unwrap_or(0);
        let b2y = row.try_get::<i64, _>("b2y").unwrap_or(0);
        let a2id = row.try_get::<i64, _>("a2id").unwrap_or(0);
        let total = row.try_get::<i64, _>("total").unwrap_or(0);
        let unknown = total - (b2a + b2b + b2y + a2id);
        (b2a, b2b, b2y, a2id, total, unknown)
    } else {
        (0, 0, 0, 0, 0, 0)
    };

    let rehash_count = state.metrics.get_rehash_count();
    let rehash_fail = state.metrics.get_rehash_fail();
    let (req_stream, req_buffered, rows_stream, rows_buffered) = state.metrics.get_export_counts();
    let login_fail = state.metrics.get_login_fail();
    let login_inactive = state.metrics.get_login_inactive();
    let pw_change = state.metrics.get_password_change();
    let pw_change_rehash = state.metrics.get_password_change_rehash();
    let login_rate_limited = state.metrics.get_login_rate_limited();
    // Histogram exports: convert ns sum back to seconds for Prometheus _sum
    let buf_sum_sec = state.metrics.export_dur_buf_sum_ns.load(std::sync::atomic::Ordering::Relaxed) as f64 / 1e9;
    let buf_count = state.metrics.export_dur_buf_count.load(std::sync::atomic::Ordering::Relaxed);
    let b005 = state.metrics.export_dur_buf_le_005.load(std::sync::atomic::Ordering::Relaxed);
    let b02 = state.metrics.export_dur_buf_le_02.load(std::sync::atomic::Ordering::Relaxed);
    let b1 = state.metrics.export_dur_buf_le_1.load(std::sync::atomic::Ordering::Relaxed);
    let b3 = state.metrics.export_dur_buf_le_3.load(std::sync::atomic::Ordering::Relaxed);
    let b10 = state.metrics.export_dur_buf_le_10.load(std::sync::atomic::Ordering::Relaxed);
    let binf = state.metrics.export_dur_buf_le_inf.load(std::sync::atomic::Ordering::Relaxed);

    let stream_sum_sec = state.metrics.export_dur_stream_sum_ns.load(std::sync::atomic::Ordering::Relaxed) as f64 / 1e9;
    let stream_count = state.metrics.export_dur_stream_count.load(std::sync::atomic::Ordering::Relaxed);
    let s005 = state.metrics.export_dur_stream_le_005.load(std::sync::atomic::Ordering::Relaxed);
    let s02 = state.metrics.export_dur_stream_le_02.load(std::sync::atomic::Ordering::Relaxed);
    let s1 = state.metrics.export_dur_stream_le_1.load(std::sync::atomic::Ordering::Relaxed);
    let s3 = state.metrics.export_dur_stream_le_3.load(std::sync::atomic::Ordering::Relaxed);
    let s10 = state.metrics.export_dur_stream_le_10.load(std::sync::atomic::Ordering::Relaxed);
    let sinf = state.metrics.export_dur_stream_le_inf.load(std::sync::atomic::Ordering::Relaxed);
    let bcrypt_total = b2a + b2b + b2y;

    let mut buf = String::new();

    // Rehash counters
    buf.push_str("# HELP jive_password_rehash_total Total successful bcrypt to argon2id password rehashes.\n");
    buf.push_str("# TYPE jive_password_rehash_total counter\n");
    buf.push_str(&format!("jive_password_rehash_total {}\n", rehash_count));
    buf.push_str("# HELP jive_password_rehash_fail_total Total failed password rehash attempts.\n");
    buf.push_str("# TYPE jive_password_rehash_fail_total counter\n");
    buf.push_str(&format!("jive_password_rehash_fail_total {}\n", rehash_fail));
    let (rf_hash, rf_update) = state.metrics.get_rehash_fail_breakdown();
    buf.push_str("# HELP jive_password_rehash_fail_breakdown_total Password rehash failures by cause.\n");
    buf.push_str("# TYPE jive_password_rehash_fail_breakdown_total counter\n");
    buf.push_str(&format!("jive_password_rehash_fail_breakdown_total{{cause=\"hash\"}} {}\n", rf_hash));
    buf.push_str(&format!("jive_password_rehash_fail_breakdown_total{{cause=\"update\"}} {}\n", rf_update));

    // Export metrics
    buf.push_str("# HELP export_requests_stream_total Number of streaming export requests.\n");
    buf.push_str("# TYPE export_requests_stream_total counter\n");
    buf.push_str(&format!("export_requests_stream_total {}\n", req_stream));
    buf.push_str("# HELP export_requests_buffered_total Number of buffered export requests (JSON+CSV).\n");
    buf.push_str("# TYPE export_requests_buffered_total counter\n");
    buf.push_str(&format!("export_requests_buffered_total {}\n", req_buffered));
    buf.push_str("# HELP export_rows_stream_total Rows exported via streaming.\n");
    buf.push_str("# TYPE export_rows_stream_total counter\n");
    buf.push_str(&format!("export_rows_stream_total {}\n", rows_stream));
    buf.push_str("# HELP export_rows_buffered_total Rows exported via buffered path.\n");
    buf.push_str("# TYPE export_rows_buffered_total counter\n");
    buf.push_str(&format!("export_rows_buffered_total {}\n", rows_buffered));

    // Auth login metrics
    buf.push_str("# HELP auth_login_fail_total Failed login attempts (wrong credentials / unknown user).\n");
    buf.push_str("# TYPE auth_login_fail_total counter\n");
    buf.push_str(&format!("auth_login_fail_total {}\n", login_fail));
    buf.push_str("# HELP auth_login_inactive_total Login attempts with inactive/disabled accounts.\n");
    buf.push_str("# TYPE auth_login_inactive_total counter\n");
    buf.push_str(&format!("auth_login_inactive_total {}\n", login_inactive));
    buf.push_str("# HELP auth_login_rate_limited_total Login attempts blocked by rate limiter.\n");
    buf.push_str("# TYPE auth_login_rate_limited_total counter\n");
    buf.push_str(&format!("auth_login_rate_limited_total {}\n", login_rate_limited));

    // Password change counters
    buf.push_str("# HELP auth_password_change_total Successful password changes.\n");
    buf.push_str("# TYPE auth_password_change_total counter\n");
    buf.push_str(&format!("auth_password_change_total {}\n", pw_change));
    buf.push_str("# HELP auth_password_change_rehash_total Password change events where legacy bcrypt was upgraded to Argon2id.\n");
    buf.push_str("# TYPE auth_password_change_rehash_total counter\n");
    buf.push_str(&format!("auth_password_change_rehash_total {}\n", pw_change_rehash));

    // Export buffered duration histogram
    buf.push_str("# HELP export_duration_buffered_seconds Export (buffered) duration histogram.\n");
    buf.push_str("# TYPE export_duration_buffered_seconds histogram\n");
    buf.push_str(&format!("export_duration_buffered_seconds_bucket{{le=\"0.05\"}} {}\n", b005));
    buf.push_str(&format!("export_duration_buffered_seconds_bucket{{le=\"0.2\"}} {}\n", b02));
    buf.push_str(&format!("export_duration_buffered_seconds_bucket{{le=\"1\"}} {}\n", b1));
    buf.push_str(&format!("export_duration_buffered_seconds_bucket{{le=\"3\"}} {}\n", b3));
    buf.push_str(&format!("export_duration_buffered_seconds_bucket{{le=\"10\"}} {}\n", b10));
    buf.push_str(&format!("export_duration_buffered_seconds_bucket{{le=\"+Inf\"}} {}\n", binf));
    buf.push_str(&format!("export_duration_buffered_seconds_sum {}\n", buf_sum_sec));
    buf.push_str(&format!("export_duration_buffered_seconds_count {}\n", buf_count));

    // Export streaming duration histogram
    buf.push_str("# HELP export_duration_stream_seconds Export (stream) duration histogram.\n");
    buf.push_str("# TYPE export_duration_stream_seconds histogram\n");
    buf.push_str(&format!("export_duration_stream_seconds_bucket{{le=\"0.05\"}} {}\n", s005));
    buf.push_str(&format!("export_duration_stream_seconds_bucket{{le=\"0.2\"}} {}\n", s02));
    buf.push_str(&format!("export_duration_stream_seconds_bucket{{le=\"1\"}} {}\n", s1));
    buf.push_str(&format!("export_duration_stream_seconds_bucket{{le=\"3\"}} {}\n", s3));
    buf.push_str(&format!("export_duration_stream_seconds_bucket{{le=\"10\"}} {}\n", s10));
    buf.push_str(&format!("export_duration_stream_seconds_bucket{{le=\"+Inf\"}} {}\n", sinf));
    buf.push_str(&format!("export_duration_stream_seconds_sum {}\n", stream_sum_sec));
    buf.push_str(&format!("export_duration_stream_seconds_count {}\n", stream_count));

    // Build info metric (labels)
    buf.push_str("# HELP jive_build_info Build information (value is always 1).\n");
    buf.push_str("# TYPE jive_build_info gauge\n");
    buf.push_str(&format!(
        "jive_build_info{{commit=\"{}\",time=\"{}\",rustc=\"{}\",version=\"{}\"}} 1\n",
        build_commit,
        build_time,
        rustc_version.replace('"', "'"),
        env!("CARGO_PKG_VERSION")
    ));

    // New canonical metrics
    buf.push_str("# HELP password_hash_bcrypt_total Users with any bcrypt hash (2a+2b+2y).\n");
    buf.push_str("# TYPE password_hash_bcrypt_total gauge\n");
    buf.push_str(&format!("password_hash_bcrypt_total {}\n", bcrypt_total));
    buf.push_str("# HELP password_hash_argon2id_total Users with argon2id hash.\n");
    buf.push_str("# TYPE password_hash_argon2id_total gauge\n");
    buf.push_str(&format!("password_hash_argon2id_total {}\n", a2id));
    buf.push_str("# HELP password_hash_unknown_total Users with unknown hash prefix.\n");
    buf.push_str("# TYPE password_hash_unknown_total gauge\n");
    buf.push_str(&format!("password_hash_unknown_total {}\n", unknown.max(0)));
    buf.push_str("# HELP password_hash_total_count Total users with password hashes.\n");
    buf.push_str("# TYPE password_hash_total_count gauge\n");
    buf.push_str(&format!("password_hash_total_count {}\n", total));
    buf.push_str("# HELP password_hash_bcrypt_variant Users by bcrypt variant.\n");
    buf.push_str("# TYPE password_hash_bcrypt_variant gauge\n");
    buf.push_str(&format!(
        "password_hash_bcrypt_variant{{variant=\"2a\"}} {}\n",
        b2a
    ));
    buf.push_str(&format!(
        "password_hash_bcrypt_variant{{variant=\"2b\"}} {}\n",
        b2b
    ));
    buf.push_str(&format!(
        "password_hash_bcrypt_variant{{variant=\"2y\"}} {}\n",
        b2y
    ));

    // Legacy (deprecated) metrics for transitional dashboards
    buf.push_str(
        "# HELP jive_password_hash_users (DEPRECATED) Users by password hash algorithm variant.\n",
    );
    buf.push_str("# TYPE jive_password_hash_users gauge\n");
    buf.push_str(&format!(
        "jive_password_hash_users{{algo=\"bcrypt_2a\"}} {}\n",
        b2a
    ));
    buf.push_str(&format!(
        "jive_password_hash_users{{algo=\"bcrypt_2b\"}} {}\n",
        b2b
    ));
    buf.push_str(&format!(
        "jive_password_hash_users{{algo=\"bcrypt_2y\"}} {}\n",
        b2y
    ));
    buf.push_str(&format!(
        "jive_password_hash_users{{algo=\"argon2id\"}} {}\n",
        a2id
    ));

    // Store base (without dynamic uptime) into cache
    {
        let mut guard = cache_lock.lock().unwrap();
        *guard = (Instant::now(), buf.clone());
    }
    let full = format!("{}{}", buf, uptime_line);
    (StatusCode::OK, [(axum::http::header::CONTENT_TYPE, "text/plain; version=0.0.4")], full)
}
