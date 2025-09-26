#![allow(dead_code, unused_imports)]

pub mod handlers;
pub mod error;
pub mod auth;
pub mod models;
pub mod services;
pub mod middleware;
pub mod ws;

use sqlx::PgPool;
use axum::extract::FromRef;

/// 应用状态
#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub ws_manager: Option<std::sync::Arc<crate::ws::WsConnectionManager>>,  // Optional WebSocket manager
    pub redis: Option<redis::aio::ConnectionManager>,
    // Minimal metrics surface for middleware to update rate-limited counter
    // In full version, a richer AppMetrics can be reintroduced.
    pub rate_limited_counter: std::sync::Arc<std::sync::atomic::AtomicU64>,
}

// 实现FromRef trait以便子状态可以从AppState中提取
impl FromRef<AppState> for PgPool {
    fn from_ref(app_state: &AppState) -> PgPool {
        app_state.pool.clone()
    }
}

// Redis connection manager FromRef implementation
impl FromRef<AppState> for Option<redis::aio::ConnectionManager> {
    fn from_ref(app_state: &AppState) -> Option<redis::aio::ConnectionManager> {
        app_state.redis.clone()
    }
}

// Re-export commonly used types
pub use error::{ApiError, ApiResult};
pub use services::{ServiceContext, ServiceError};

