//! 请求限流中间件

use axum::{
    extract::{Request, State},
    http::StatusCode,
    middleware::Next,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use std::{
    collections::HashMap,
    sync::Arc,
    time::{Duration, Instant},
};
use tokio::sync::RwLock;

/// 限流配置
#[derive(Clone)]
pub struct RateLimitConfig {
    /// 时间窗口（秒）
    pub window_seconds: u64,
    /// 窗口内最大请求数
    pub max_requests: u32,
}

impl Default for RateLimitConfig {
    fn default() -> Self {
        Self {
            window_seconds: 60, // 1分钟
            max_requests: 100,  // 100个请求
        }
    }
}

/// 请求记录
#[derive(Debug, Clone)]
struct RequestRecord {
    count: u32,
    window_start: Instant,
}

/// 限流器
#[derive(Clone)]
pub struct RateLimiter {
    config: RateLimitConfig,
    records: Arc<RwLock<HashMap<String, RequestRecord>>>,
}

impl RateLimiter {
    pub fn new(config: RateLimitConfig) -> Self {
        Self {
            config,
            records: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// 检查是否应该限流
    pub async fn check_rate_limit(&self, client_id: String) -> bool {
        let mut records = self.records.write().await;
        let now = Instant::now();
        let window_duration = Duration::from_secs(self.config.window_seconds);

        match records.get_mut(&client_id) {
            Some(record) => {
                // 检查是否在同一个时间窗口内
                if now.duration_since(record.window_start) < window_duration {
                    // 在同一窗口内，增加计数
                    if record.count >= self.config.max_requests {
                        return true; // 超过限制
                    }
                    record.count += 1;
                } else {
                    // 新的时间窗口，重置计数
                    record.count = 1;
                    record.window_start = now;
                }
            }
            None => {
                // 首次请求，创建记录
                records.insert(
                    client_id,
                    RequestRecord {
                        count: 1,
                        window_start: now,
                    },
                );
            }
        }

        // 清理过期记录（可选，防止内存泄漏）
        records.retain(|_, record| now.duration_since(record.window_start) < window_duration * 2);

        false
    }
}

/// 限流中间件
pub async fn rate_limit_middleware(
    State(limiter): State<Arc<RateLimiter>>,
    request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    // 获取客户端标识（可以是IP地址、用户ID等）
    let client_id = request
        .headers()
        .get("x-forwarded-for")
        .and_then(|h| h.to_str().ok())
        .or_else(|| {
            request
                .headers()
                .get("x-real-ip")
                .and_then(|h| h.to_str().ok())
        })
        .unwrap_or("unknown")
        .to_string();

    // 检查限流
    if limiter.check_rate_limit(client_id).await {
        return Ok(Json(json!({
            "error": {
                "type": "rate_limited",
                "message": "Too many requests. Please try again later.",
                "retry_after": limiter.config.window_seconds,
            }
        }))
        .into_response());
    }

    Ok(next.run(request).await)
}
