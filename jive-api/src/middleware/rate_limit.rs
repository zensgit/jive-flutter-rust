use crate::AppState;
use axum::{
    body::Body,
    extract::State,
    http::{HeaderValue, Request, StatusCode},
    middleware::Next,
    response::Response,
};
use sha2::{Digest, Sha256};
use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};
use tower::BoxError;
use tracing::warn;

#[derive(Clone)]
pub struct RateLimiter {
    pub inner: Arc<Mutex<HashMap<String, (u32, Instant)>>>, // key -> (count, window_start)
    pub max: u32,
    pub window: Duration,
    pub hash_email: bool,
}

impl RateLimiter {
    pub fn new(max: u32, window_secs: u64) -> Self {
        let hash_email = std::env::var("AUTH_RATE_LIMIT_HASH_EMAIL")
            .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
            .unwrap_or(true);
        Self {
            inner: Arc::new(Mutex::new(HashMap::new())),
            max,
            window: Duration::from_secs(window_secs),
            hash_email,
        }
    }
    fn check(&self, key: &str) -> (bool, u32, u64) {
        let mut map = self.inner.lock().unwrap();
        let now = Instant::now();
        // Opportunistic cleanup if map large
        if map.len() > 10_000 {
            let window = self.window;
            map.retain(|_, (_c, start)| now.duration_since(*start) <= window);
        }
        let entry = map.entry(key.to_string()).or_insert((0, now));
        if now.duration_since(entry.1) > self.window {
            *entry = (0, now);
        }
        entry.0 += 1;
        let allowed = entry.0 <= self.max;
        let remaining = self.max.saturating_sub(entry.0);
        let retry_after = self
            .window
            .saturating_sub(now.duration_since(entry.1))
            .as_secs();
        (allowed, remaining, retry_after)
    }
}

pub async fn login_rate_limit(
    State((limiter, app_state)): State<(RateLimiter, AppState)>,
    req: Request<Body>,
    next: Next,
) -> Result<Response, StatusCode> {
    // Buffer body (login payload is small)
    let (parts, body) = req.into_parts();
    let bytes = match axum::body::to_bytes(body, 64 * 1024).await {
        Ok(b) => b,
        Err(_) => {
            return Ok(Response::builder()
                .status(StatusCode::BAD_REQUEST)
                .header("Content-Type", "application/json")
                .body(Body::from("{\"error_code\":\"INVALID_BODY\"}"))
                .unwrap());
        }
    };
    let ip = parts
        .headers
        .get("x-forwarded-for")
        .and_then(|v| v.to_str().ok())
        .and_then(|s| s.split(',').next())
        .unwrap_or("unknown")
        .trim()
        .to_string();
    let email_key = extract_email_key(&bytes, limiter.hash_email);
    let key = format!("{}:{}", ip, email_key.unwrap_or_else(|| "_".into()));
    let (allowed, _remain, retry_after) = limiter.check(&key);
    let req_restored = Request::from_parts(parts, Body::from(bytes));
    if !allowed {
        app_state.metrics.inc_login_rate_limited();
        warn!(event="auth_rate_limit", ip=%ip, retry_after=retry_after, key=%key, "login rate limit triggered");
        let body = serde_json::json!({
            "error_code": "RATE_LIMITED",
            "message": "Too many login attempts. Please retry later.",
            "retry_after": retry_after
        });
        let resp = Response::builder()
            .status(StatusCode::TOO_MANY_REQUESTS)
            .header("Content-Type", "application/json")
            .header(
                "Retry-After",
                HeaderValue::from_str(&retry_after.to_string()).unwrap(),
            )
            .body(Body::from(body.to_string()))
            .unwrap();
        return Ok(resp);
    }
    Ok(next.run(req_restored).await)
}

fn extract_email_key(bytes: &[u8], hash: bool) -> Option<String> {
    if bytes.is_empty() {
        return None;
    }
    let v: serde_json::Value = serde_json::from_slice(bytes).ok()?;
    let raw = v.get("email")?.as_str()?;
    let norm = raw.trim().to_lowercase();
    if norm.is_empty() {
        return None;
    }
    if !hash {
        return Some(norm);
    }
    let mut h = Sha256::new();
    h.update(&norm);
    let hex = format!("{:x}", h.finalize());
    Some(hex[..8].to_string())
}
