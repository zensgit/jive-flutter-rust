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
}

// 实现FromRef trait以便子状态可以从AppState中提取
impl FromRef<AppState> for PgPool {
    fn from_ref(app_state: &AppState) -> PgPool {
        app_state.pool.clone()
    }
}

// WebSocket 管理器的 FromRef 实现已移至 main_complete.rs
// impl FromRef<AppState> for std::sync::Arc<ws::WsConnectionManager> {
//     fn from_ref(app_state: &AppState) -> std::sync::Arc<ws::WsConnectionManager> {
//         app_state.ws_manager.clone()
//     }
// }

// Re-export commonly used types
pub use error::{ApiError, ApiResult};
pub use services::{ServiceContext, ServiceError};