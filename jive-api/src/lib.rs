#![allow(dead_code, unused_imports)]

pub mod auth;
pub mod error;
pub mod handlers;
pub mod middleware;
pub mod models;
pub mod services;
pub mod ws;

use axum::extract::FromRef;
use sqlx::PgPool;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;

/// 应用状态
#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub ws_manager: Option<std::sync::Arc<crate::ws::WsConnectionManager>>, // Optional WebSocket manager
    pub redis: Option<redis::aio::ConnectionManager>,
    pub metrics: AppMetrics,
}

/// Application metrics
#[derive(Clone)]
pub struct AppMetrics {
    pub rehash_count: Arc<AtomicU64>,
}

impl Default for AppMetrics {
    fn default() -> Self {
        Self::new()
    }
}

impl AppMetrics {
    pub fn new() -> Self {
        Self {
            rehash_count: Arc::new(AtomicU64::new(0)),
        }
    }

    pub fn increment_rehash(&self) {
        self.rehash_count.fetch_add(1, Ordering::Relaxed);
    }

    pub fn get_rehash_count(&self) -> u64 {
        self.rehash_count.load(Ordering::Relaxed)
    }
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
