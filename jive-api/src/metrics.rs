use crate::AppState;
use axum::{http::StatusCode, response::IntoResponse};
use sqlx::PgPool;

// Produce Prometheus-style metrics text with backward-compatible legacy metrics.
pub async fn metrics_handler(
    axum::extract::State(state): axum::extract::State<AppState>,
) -> impl IntoResponse {
    let pool: &PgPool = &state.pool;
    // Hash distribution + totals (best-effort)
    let (b2a, b2b, b2y, a2id, total, unknown) = if let Ok(row) = sqlx::query(
        "SELECT \
            COUNT(*) FILTER (WHERE password_hash LIKE '$2a$%') AS b2a,\
            COUNT(*) FILTER (WHERE password_hash LIKE '$2b$%') AS b2b,\
            COUNT(*) FILTER (WHERE password_hash LIKE '$2y$%') AS b2y,\
            COUNT(*) FILTER (WHERE password_hash LIKE '$argon2id$%') AS a2id,\
            COUNT(*) AS total\
         FROM users"
    ).fetch_one(pool).await {
        use sqlx::Row;
        let b2a = row.try_get::<i64,_>("b2a").unwrap_or(0);
        let b2b = row.try_get::<i64,_>("b2b").unwrap_or(0);
        let b2y = row.try_get::<i64,_>("b2y").unwrap_or(0);
        let a2id = row.try_get::<i64,_>("a2id").unwrap_or(0);
        let total = row.try_get::<i64,_>("total").unwrap_or(0);
        let unknown = total - (b2a + b2b + b2y + a2id);
        (b2a,b2b,b2y,a2id,total,unknown)
    } else { (0,0,0,0,0,0) };

    let rehash_count = state.metrics.get_rehash_count();
    let bcrypt_total = b2a + b2b + b2y;

    let mut buf = String::new();

    // Rehash counter
    buf.push_str("# HELP jive_password_rehash_total Total successful bcrypt to argon2id password rehashes.\n");
    buf.push_str("# TYPE jive_password_rehash_total counter\n");
    buf.push_str(&format!("jive_password_rehash_total {}\n", rehash_count));

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
    buf.push_str(&format!("password_hash_bcrypt_variant{{variant=\"2a\"}} {}\n", b2a));
    buf.push_str(&format!("password_hash_bcrypt_variant{{variant=\"2b\"}} {}\n", b2b));
    buf.push_str(&format!("password_hash_bcrypt_variant{{variant=\"2y\"}} {}\n", b2y));

    // Legacy (deprecated) metrics for transitional dashboards
    buf.push_str("# HELP jive_password_hash_users (DEPRECATED) Users by password hash algorithm variant.\n");
    buf.push_str("# TYPE jive_password_hash_users gauge\n");
    buf.push_str(&format!("jive_password_hash_users{{algo=\"bcrypt_2a\"}} {}\n", b2a));
    buf.push_str(&format!("jive_password_hash_users{{algo=\"bcrypt_2b\"}} {}\n", b2b));
    buf.push_str(&format!("jive_password_hash_users{{algo=\"bcrypt_2y\"}} {}\n", b2y));
    buf.push_str(&format!("jive_password_hash_users{{algo=\"argon2id\"}} {}\n", a2id));

    (StatusCode::OK, [(axum::http::header::CONTENT_TYPE, "text/plain; version=0.0.4")], buf)
}
