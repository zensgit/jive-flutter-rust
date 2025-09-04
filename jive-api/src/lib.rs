pub mod handlers;
pub mod error;
pub mod auth;
pub mod websocket;
pub mod models;
pub mod services;
// pub mod routes;  // Temporarily disabled for testing
pub mod middleware;

use sqlx::PgPool;

/// 应用状态
#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub ws_manager: std::sync::Arc<websocket::WsConnectionManager>,
}

// Re-export commonly used types
pub use error::{ApiError, ApiResult};
pub use services::{ServiceContext, ServiceError};