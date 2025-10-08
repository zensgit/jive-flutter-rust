//! API错误处理模块

use axum::{http::StatusCode, response::{IntoResponse, Response}, Json};
use serde::{Deserialize, Serialize};

/// API错误类型
#[derive(Debug, thiserror::Error)]
pub enum ApiError {
    #[error("Not found: {0}")]
    NotFound(String),

    #[error("Bad request: {0}")]
    BadRequest(String),

    #[error("Unauthorized")]
    Unauthorized,

    #[error("Forbidden")]
    Forbidden,

    #[error("Database error: {0}")]
    DatabaseError(String),

    #[error("Validation error: {0}")]
    ValidationError(String),

    #[error("Internal server error")]
    InternalServerError,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ApiErrorResponse {
    pub error_code: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub retry_after: Option<u64>,
}

impl ApiErrorResponse {
    pub fn new(code: impl Into<String>, msg: impl Into<String>) -> Self {
        Self { error_code: code.into(), message: msg.into(), retry_after: None }
    }
    pub fn with_retry_after(mut self, sec: u64) -> Self {
        self.retry_after = Some(sec);
        self
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        let (status, body) = match self {
            ApiError::NotFound(msg) => (
                StatusCode::NOT_FOUND,
                ApiErrorResponse::new("NOT_FOUND", msg),
            ),
            ApiError::BadRequest(msg) => (
                StatusCode::BAD_REQUEST,
                ApiErrorResponse::new("INVALID_INPUT", msg),
            ),
            ApiError::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                ApiErrorResponse::new("UNAUTHORIZED", "Unauthorized"),
            ),
            ApiError::Forbidden => (
                StatusCode::FORBIDDEN,
                ApiErrorResponse::new("FORBIDDEN", "Forbidden"),
            ),
            ApiError::DatabaseError(msg) => (
                StatusCode::INTERNAL_SERVER_ERROR,
                ApiErrorResponse::new("INTERNAL_ERROR", format!("Database error: {}", msg)),
            ),
            ApiError::ValidationError(msg) => (
                StatusCode::UNPROCESSABLE_ENTITY,
                ApiErrorResponse::new("VALIDATION_ERROR", msg),
            ),
            ApiError::InternalServerError => (
                StatusCode::INTERNAL_SERVER_ERROR,
                ApiErrorResponse::new("INTERNAL_ERROR", "Internal server error"),
            ),
        };

        (status, Json(body)).into_response()
    }
}

/// API结果类型别名
pub type ApiResult<T> = Result<T, ApiError>;

use crate::auth::AuthError;

/// 实现AuthError到ApiError的转换
impl From<AuthError> for ApiError {
    fn from(err: AuthError) -> Self {
        match err {
            AuthError::WrongCredentials => ApiError::Unauthorized,
            AuthError::MissingCredentials => {
                ApiError::BadRequest("Missing credentials".to_string())
            }
            AuthError::TokenCreation => ApiError::InternalServerError,
            AuthError::InvalidToken => ApiError::Unauthorized,
        }
    }
}

/// 实现sqlx::Error到ApiError的转换
impl From<sqlx::Error> for ApiError {
    fn from(err: sqlx::Error) -> Self {
        match err {
            sqlx::Error::RowNotFound => ApiError::NotFound("Resource not found".to_string()),
            sqlx::Error::Database(db_err) => {
                ApiError::DatabaseError(db_err.message().to_string())
            }
            _ => ApiError::DatabaseError(err.to_string()),
        }
    }
}
