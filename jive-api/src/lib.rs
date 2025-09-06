pub mod handlers;
pub mod error;
pub mod auth;
pub mod websocket;
pub mod models;
pub mod services;
// pub mod routes;  // Temporarily disabled for testing
pub mod middleware;

use sqlx::PgPool;
use axum::extract::FromRef;

/// 应用状态
#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub ws_manager: std::sync::Arc<websocket::WsConnectionManager>,
}

// 实现FromRef trait以便子状态可以从AppState中提取
impl FromRef<AppState> for PgPool {
    fn from_ref(app_state: &AppState) -> PgPool {
        app_state.pool.clone()
    }
}

impl FromRef<AppState> for std::sync::Arc<websocket::WsConnectionManager> {
    fn from_ref(app_state: &AppState) -> std::sync::Arc<websocket::WsConnectionManager> {
        app_state.ws_manager.clone()
    }
}

// Re-export commonly used types
pub use error::{ApiError, ApiResult};
pub use services::{ServiceContext, ServiceError};