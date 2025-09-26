//! 统一错误处理中间件

use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use std::fmt;

/// 应用错误类型
#[derive(Debug)]
pub enum AppError {
    /// 数据库错误
    Database(sqlx::Error),
    /// 认证错误
    Authentication(String),
    /// 授权错误
    Authorization(String),
    /// 验证错误
    Validation(String),
    /// 未找到资源
    NotFound(String),
    /// 内部服务器错误
    InternalServer(String),
    /// 请求频率限制
    RateLimited(String),
    /// 错误请求
    BadRequest(String),
}

impl fmt::Display for AppError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AppError::Database(e) => write!(f, "Database error: {}", e),
            AppError::Authentication(msg) => write!(f, "Authentication error: {}", msg),
            AppError::Authorization(msg) => write!(f, "Authorization error: {}", msg),
            AppError::Validation(msg) => write!(f, "Validation error: {}", msg),
            AppError::NotFound(msg) => write!(f, "Not found: {}", msg),
            AppError::InternalServer(msg) => write!(f, "Internal server error: {}", msg),
            AppError::RateLimited(msg) => write!(f, "Rate limited: {}", msg),
            AppError::BadRequest(msg) => write!(f, "Bad request: {}", msg),
        }
    }
}

impl std::error::Error for AppError {}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_message, error_type) = match &self {
            AppError::Database(_) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                "Database operation failed".to_string(),
                "database_error",
            ),
            AppError::Authentication(msg) => (
                StatusCode::UNAUTHORIZED,
                msg.clone(),
                "authentication_error",
            ),
            AppError::Authorization(msg) => {
                (StatusCode::FORBIDDEN, msg.clone(), "authorization_error")
            }
            AppError::Validation(msg) => (StatusCode::BAD_REQUEST, msg.clone(), "validation_error"),
            AppError::NotFound(msg) => (StatusCode::NOT_FOUND, msg.clone(), "not_found"),
            AppError::InternalServer(msg) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                msg.clone(),
                "internal_error",
            ),
            AppError::RateLimited(msg) => {
                (StatusCode::TOO_MANY_REQUESTS, msg.clone(), "rate_limited")
            }
            AppError::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg.clone(), "bad_request"),
        };

        let body = Json(json!({
            "error": {
                "type": error_type,
                "message": error_message,
                "status": status.as_u16(),
            },
            "timestamp": chrono::Utc::now().to_rfc3339(),
        }));

        (status, body).into_response()
    }
}

// 实现从各种错误类型到 AppError 的转换
impl From<sqlx::Error> for AppError {
    fn from(err: sqlx::Error) -> Self {
        AppError::Database(err)
    }
}

impl From<jsonwebtoken::errors::Error> for AppError {
    fn from(err: jsonwebtoken::errors::Error) -> Self {
        AppError::Authentication(err.to_string())
    }
}

/// Result 类型别名
pub type AppResult<T> = Result<T, AppError>;
