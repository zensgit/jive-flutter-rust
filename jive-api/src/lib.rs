#![allow(dead_code, unused_imports)]

pub mod auth;
pub mod error;
pub mod handlers;
pub mod middleware;
pub mod models;
pub mod services;
pub mod utils;
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
    pub rehash_fail_count: Arc<AtomicU64>,
    pub export_request_stream_count: Arc<AtomicU64>,
    pub export_request_buffered_count: Arc<AtomicU64>,
    pub export_rows_stream: Arc<AtomicU64>,
    pub export_rows_buffered: Arc<AtomicU64>,
    pub auth_login_fail_count: Arc<AtomicU64>,
    pub auth_login_inactive_count: Arc<AtomicU64>,
    pub auth_password_change_total: Arc<AtomicU64>,
    pub auth_password_change_rehash_total: Arc<AtomicU64>,
    // Export duration histogram (buffered)
    pub export_dur_buf_le_005: Arc<AtomicU64>,
    pub export_dur_buf_le_02: Arc<AtomicU64>,
    pub export_dur_buf_le_1: Arc<AtomicU64>,
    pub export_dur_buf_le_3: Arc<AtomicU64>,
    pub export_dur_buf_le_10: Arc<AtomicU64>,
    pub export_dur_buf_le_inf: Arc<AtomicU64>,
    pub export_dur_buf_sum_ns: Arc<AtomicU64>,
    pub export_dur_buf_count: Arc<AtomicU64>,
    // Export duration histogram (stream)
    pub export_dur_stream_le_005: Arc<AtomicU64>,
    pub export_dur_stream_le_02: Arc<AtomicU64>,
    pub export_dur_stream_le_1: Arc<AtomicU64>,
    pub export_dur_stream_le_3: Arc<AtomicU64>,
    pub export_dur_stream_le_10: Arc<AtomicU64>,
    pub export_dur_stream_le_inf: Arc<AtomicU64>,
    pub export_dur_stream_sum_ns: Arc<AtomicU64>,
    pub export_dur_stream_count: Arc<AtomicU64>,
    pub rehash_fail_hash: Arc<AtomicU64>,
    pub rehash_fail_update: Arc<AtomicU64>,
    pub auth_login_rate_limited: Arc<AtomicU64>,
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
            rehash_fail_count: Arc::new(AtomicU64::new(0)),
            export_request_stream_count: Arc::new(AtomicU64::new(0)),
            export_request_buffered_count: Arc::new(AtomicU64::new(0)),
            export_rows_stream: Arc::new(AtomicU64::new(0)),
            export_rows_buffered: Arc::new(AtomicU64::new(0)),
            auth_login_fail_count: Arc::new(AtomicU64::new(0)),
            auth_login_inactive_count: Arc::new(AtomicU64::new(0)),
            auth_password_change_total: Arc::new(AtomicU64::new(0)),
            auth_password_change_rehash_total: Arc::new(AtomicU64::new(0)),
            export_dur_buf_le_005: Arc::new(AtomicU64::new(0)),
            export_dur_buf_le_02: Arc::new(AtomicU64::new(0)),
            export_dur_buf_le_1: Arc::new(AtomicU64::new(0)),
            export_dur_buf_le_3: Arc::new(AtomicU64::new(0)),
            export_dur_buf_le_10: Arc::new(AtomicU64::new(0)),
            export_dur_buf_le_inf: Arc::new(AtomicU64::new(0)),
            export_dur_buf_sum_ns: Arc::new(AtomicU64::new(0)),
            export_dur_buf_count: Arc::new(AtomicU64::new(0)),
            export_dur_stream_le_005: Arc::new(AtomicU64::new(0)),
            export_dur_stream_le_02: Arc::new(AtomicU64::new(0)),
            export_dur_stream_le_1: Arc::new(AtomicU64::new(0)),
            export_dur_stream_le_3: Arc::new(AtomicU64::new(0)),
            export_dur_stream_le_10: Arc::new(AtomicU64::new(0)),
            export_dur_stream_le_inf: Arc::new(AtomicU64::new(0)),
            export_dur_stream_sum_ns: Arc::new(AtomicU64::new(0)),
            export_dur_stream_count: Arc::new(AtomicU64::new(0)),
            rehash_fail_hash: Arc::new(AtomicU64::new(0)),
            rehash_fail_update: Arc::new(AtomicU64::new(0)),
            auth_login_rate_limited: Arc::new(AtomicU64::new(0)),
        }
    }

    pub fn increment_rehash(&self) {
        self.rehash_count.fetch_add(1, Ordering::Relaxed);
    }

    pub fn get_rehash_count(&self) -> u64 {
        self.rehash_count.load(Ordering::Relaxed)
    }

    pub fn increment_rehash_fail(&self) {
        self.rehash_fail_count.fetch_add(1, Ordering::Relaxed);
    }
    pub fn get_rehash_fail(&self) -> u64 {
        self.rehash_fail_count.load(Ordering::Relaxed)
    }

    pub fn inc_export_request_stream(&self) {
        self.export_request_stream_count
            .fetch_add(1, Ordering::Relaxed);
    }
    pub fn inc_export_request_buffered(&self) {
        self.export_request_buffered_count
            .fetch_add(1, Ordering::Relaxed);
    }
    pub fn add_export_rows_stream(&self, n: u64) {
        self.export_rows_stream.fetch_add(n, Ordering::Relaxed);
    }
    pub fn add_export_rows_buffered(&self, n: u64) {
        self.export_rows_buffered.fetch_add(n, Ordering::Relaxed);
    }
    pub fn get_export_counts(&self) -> (u64, u64, u64, u64) {
        (
            self.export_request_stream_count.load(Ordering::Relaxed),
            self.export_request_buffered_count.load(Ordering::Relaxed),
            self.export_rows_stream.load(Ordering::Relaxed),
            self.export_rows_buffered.load(Ordering::Relaxed),
        )
    }

    pub fn increment_login_fail(&self) {
        self.auth_login_fail_count.fetch_add(1, Ordering::Relaxed);
    }
    pub fn increment_login_inactive(&self) {
        self.auth_login_inactive_count
            .fetch_add(1, Ordering::Relaxed);
    }
    pub fn get_login_fail(&self) -> u64 {
        self.auth_login_fail_count.load(Ordering::Relaxed)
    }
    pub fn get_login_inactive(&self) -> u64 {
        self.auth_login_inactive_count.load(Ordering::Relaxed)
    }

    // Password change counters
    pub fn inc_password_change(&self) {
        self.auth_password_change_total
            .fetch_add(1, Ordering::Relaxed);
    }
    pub fn inc_password_change_rehash(&self) {
        self.auth_password_change_rehash_total
            .fetch_add(1, Ordering::Relaxed);
    }
    pub fn get_password_change(&self) -> u64 {
        self.auth_password_change_total.load(Ordering::Relaxed)
    }
    pub fn get_password_change_rehash(&self) -> u64 {
        self.auth_password_change_rehash_total
            .load(Ordering::Relaxed)
    }

    #[allow(clippy::too_many_arguments)]
    fn observe_histogram(
        dur_secs: f64,
        sum_ns: &AtomicU64,
        count: &AtomicU64,
        b005: &AtomicU64,
        b02: &AtomicU64,
        b1: &AtomicU64,
        b3: &AtomicU64,
        b10: &AtomicU64,
        binf: &AtomicU64,
    ) {
        let ns = (dur_secs * 1_000_000_000.0) as u64;
        sum_ns.fetch_add(ns, Ordering::Relaxed);
        count.fetch_add(1, Ordering::Relaxed);
        if dur_secs <= 0.05 {
            b005.fetch_add(1, Ordering::Relaxed);
        }
        if dur_secs <= 0.2 {
            b02.fetch_add(1, Ordering::Relaxed);
        }
        if dur_secs <= 1.0 {
            b1.fetch_add(1, Ordering::Relaxed);
        }
        if dur_secs <= 3.0 {
            b3.fetch_add(1, Ordering::Relaxed);
        }
        if dur_secs <= 10.0 {
            b10.fetch_add(1, Ordering::Relaxed);
        }
        binf.fetch_add(1, Ordering::Relaxed); // +Inf bucket always
    }

    pub fn observe_export_duration_buffered(&self, dur_secs: f64) {
        Self::observe_histogram(
            dur_secs,
            &self.export_dur_buf_sum_ns,
            &self.export_dur_buf_count,
            &self.export_dur_buf_le_005,
            &self.export_dur_buf_le_02,
            &self.export_dur_buf_le_1,
            &self.export_dur_buf_le_3,
            &self.export_dur_buf_le_10,
            &self.export_dur_buf_le_inf,
        );
    }
    pub fn observe_export_duration_stream(&self, dur_secs: f64) {
        Self::observe_histogram(
            dur_secs,
            &self.export_dur_stream_sum_ns,
            &self.export_dur_stream_count,
            &self.export_dur_stream_le_005,
            &self.export_dur_stream_le_02,
            &self.export_dur_stream_le_1,
            &self.export_dur_stream_le_3,
            &self.export_dur_stream_le_10,
            &self.export_dur_stream_le_inf,
        );
    }
    pub fn inc_rehash_fail_hash(&self) {
        self.rehash_fail_hash.fetch_add(1, Ordering::Relaxed);
    }
    pub fn inc_rehash_fail_update(&self) {
        self.rehash_fail_update.fetch_add(1, Ordering::Relaxed);
    }
    pub fn get_rehash_fail_breakdown(&self) -> (u64, u64) {
        (
            self.rehash_fail_hash.load(Ordering::Relaxed),
            self.rehash_fail_update.load(Ordering::Relaxed),
        )
    }
    pub fn inc_login_rate_limited(&self) {
        self.auth_login_rate_limited.fetch_add(1, Ordering::Relaxed);
    }
    pub fn get_login_rate_limited(&self) -> u64 {
        self.auth_login_rate_limited.load(Ordering::Relaxed)
    }
}

// 实现FromRef trait以便子状态可以从AppState中提取
impl FromRef<AppState> for PgPool {
    fn from_ref(app_state: &AppState) -> PgPool {
        app_state.pool.clone()
    }
}

// Extract metrics from AppState for handlers
impl FromRef<AppState> for AppMetrics {
    fn from_ref(app_state: &AppState) -> AppMetrics {
        app_state.metrics.clone()
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
