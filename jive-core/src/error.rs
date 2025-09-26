//! Error handling for Jive Core

use serde::{Deserialize, Serialize};
use thiserror::Error;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

/// Main error type for Jive Core
#[derive(Error, Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum JiveError {
    #[error("Not found: {message}")]
    NotFound { message: String },
    #[error("Account not found: {id}")]
    AccountNotFound { id: String },

    #[error("Transaction not found: {id}")]
    TransactionNotFound { id: String },

    #[error("Ledger not found: {id}")]
    LedgerNotFound { id: String },

    #[error("Category not found: {id}")]
    CategoryNotFound { id: String },

    #[error("User not found: {id}")]
    UserNotFound { id: String },

    #[error("Insufficient balance: available {available}, required {required}")]
    InsufficientBalance { available: String, required: String },

    #[error("Invalid amount: {amount}")]
    InvalidAmount { amount: String },

    #[error("Invalid currency: {currency}")]
    InvalidCurrency { currency: String },

    #[error("Invalid date: {date}")]
    InvalidDate { date: String },

    #[error("Validation error: {message}")]
    ValidationError { message: String },

    #[error("Database error: {message}")]
    DatabaseError { message: String },

    #[error("Network error: {message}")]
    NetworkError { message: String },

    #[error("Serialization error: {message}")]
    SerializationError { message: String },

    #[error("Authentication error: {message}")]
    AuthenticationError { message: String },

    #[error("Authorization error: {message}")]
    AuthorizationError { message: String },

    #[error("External service error: {service} - {message}")]
    ExternalServiceError { service: String, message: String },

    #[error("Configuration error: {message}")]
    ConfigurationError { message: String },

    #[error("Sync error: {message}")]
    SyncError { message: String },

    #[error("Encryption error: {message}")]
    EncryptionError { message: String },

    #[error("Permission denied: {message}")]
    PermissionDenied { message: String },

    #[error("Rate limit exceeded: {message}")]
    RateLimitExceeded { message: String },

    #[error("Unknown error: {message}")]
    Unknown { message: String },
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl JiveError {
    #[wasm_bindgen(getter)]
    pub fn message(&self) -> String {
        self.to_string()
    }

    #[wasm_bindgen(getter)]
    pub fn error_type(&self) -> String {
        match self {
            JiveError::AccountNotFound { .. } => "AccountNotFound".to_string(),
            JiveError::TransactionNotFound { .. } => "TransactionNotFound".to_string(),
            JiveError::LedgerNotFound { .. } => "LedgerNotFound".to_string(),
            JiveError::CategoryNotFound { .. } => "CategoryNotFound".to_string(),
            JiveError::UserNotFound { .. } => "UserNotFound".to_string(),
            JiveError::InsufficientBalance { .. } => "InsufficientBalance".to_string(),
            JiveError::InvalidAmount { .. } => "InvalidAmount".to_string(),
            JiveError::InvalidCurrency { .. } => "InvalidCurrency".to_string(),
            JiveError::InvalidDate { .. } => "InvalidDate".to_string(),
            JiveError::ValidationError { .. } => "ValidationError".to_string(),
            JiveError::DatabaseError { .. } => "DatabaseError".to_string(),
            JiveError::NetworkError { .. } => "NetworkError".to_string(),
            JiveError::SerializationError { .. } => "SerializationError".to_string(),
            JiveError::AuthenticationError { .. } => "AuthenticationError".to_string(),
            JiveError::AuthorizationError { .. } => "AuthorizationError".to_string(),
            JiveError::ExternalServiceError { .. } => "ExternalServiceError".to_string(),
            JiveError::ConfigurationError { .. } => "ConfigurationError".to_string(),
            JiveError::SyncError { .. } => "SyncError".to_string(),
            JiveError::EncryptionError { .. } => "EncryptionError".to_string(),
            JiveError::PermissionDenied { .. } => "PermissionDenied".to_string(),
            JiveError::RateLimitExceeded { .. } => "RateLimitExceeded".to_string(),
            JiveError::Unknown { .. } => "Unknown".to_string(),
        }
    }

    #[wasm_bindgen(getter)]
    pub fn is_recoverable(&self) -> bool {
        match self {
            JiveError::NetworkError { .. } => true,
            JiveError::RateLimitExceeded { .. } => true,
            JiveError::SyncError { .. } => true,
            _ => false,
        }
    }
}

/// Result type alias for Jive Core
pub type Result<T> = std::result::Result<T, JiveError>;

// 从标准错误类型转换
impl From<serde_json::Error> for JiveError {
    fn from(err: serde_json::Error) -> Self {
        JiveError::SerializationError {
            message: err.to_string(),
        }
    }
}

impl From<chrono::ParseError> for JiveError {
    fn from(err: chrono::ParseError) -> Self {
        JiveError::InvalidDate {
            date: err.to_string(),
        }
    }
}

#[cfg(feature = "db")]
impl From<sqlx::Error> for JiveError {
    fn from(err: sqlx::Error) -> Self {
        JiveError::DatabaseError {
            message: err.to_string(),
        }
    }
}

#[cfg(feature = "db")]
impl From<reqwest::Error> for JiveError {
    fn from(err: reqwest::Error) -> Self {
        JiveError::NetworkError {
            message: err.to_string(),
        }
    }
}

// 验证辅助函数
pub fn validate_amount(amount: &str) -> Result<rust_decimal::Decimal> {
    amount
        .parse::<rust_decimal::Decimal>()
        .map_err(|_| JiveError::InvalidAmount {
            amount: amount.to_string(),
        })
}

pub fn validate_currency(currency: &str) -> Result<()> {
    const VALID_CURRENCIES: &[&str] = &[
        "USD", "EUR", "GBP", "JPY", "CNY", "CAD", "AUD", "CHF", "SEK", "NOK", "DKK", "KRW", "SGD",
        "HKD", "INR", "BRL", "MXN", "RUB", "ZAR", "TRY",
    ];

    if VALID_CURRENCIES.contains(&currency) {
        Ok(())
    } else {
        Err(JiveError::InvalidCurrency {
            currency: currency.to_string(),
        })
    }
}

pub fn validate_email(email: &str) -> Result<()> {
    if email.is_empty() {
        return Err(JiveError::ValidationError {
            message: "Email cannot be empty".to_string(),
        });
    }

    if !email.contains('@') || !email.contains('.') {
        return Err(JiveError::ValidationError {
            message: "Invalid email format".to_string(),
        });
    }

    Ok(())
}

pub fn validate_id(id: &str) -> Result<uuid::Uuid> {
    uuid::Uuid::parse_str(id).map_err(|_| JiveError::ValidationError {
        message: format!("Invalid UUID format: {}", id),
    })
}

/// 错误分类助手
pub mod error_classification {
    use super::JiveError;

    /// 检查错误是否为用户错误（可以显示给用户）
    pub fn is_user_error(error: &JiveError) -> bool {
        matches!(
            error,
            JiveError::AccountNotFound { .. }
                | JiveError::TransactionNotFound { .. }
                | JiveError::LedgerNotFound { .. }
                | JiveError::CategoryNotFound { .. }
                | JiveError::InsufficientBalance { .. }
                | JiveError::InvalidAmount { .. }
                | JiveError::InvalidCurrency { .. }
                | JiveError::InvalidDate { .. }
                | JiveError::ValidationError { .. }
                | JiveError::AuthenticationError { .. }
                | JiveError::AuthorizationError { .. }
                | JiveError::PermissionDenied { .. }
        )
    }

    /// 检查错误是否为系统错误（需要记录日志）
    pub fn is_system_error(error: &JiveError) -> bool {
        matches!(
            error,
            JiveError::DatabaseError { .. }
                | JiveError::NetworkError { .. }
                | JiveError::SerializationError { .. }
                | JiveError::ExternalServiceError { .. }
                | JiveError::ConfigurationError { .. }
                | JiveError::SyncError { .. }
                | JiveError::EncryptionError { .. }
                | JiveError::Unknown { .. }
        )
    }

    /// 获取错误的严重程度
    pub fn get_severity(error: &JiveError) -> ErrorSeverity {
        match error {
            JiveError::Unknown { .. } => ErrorSeverity::Critical,
            JiveError::DatabaseError { .. } => ErrorSeverity::High,
            JiveError::EncryptionError { .. } => ErrorSeverity::High,
            JiveError::ExternalServiceError { .. } => ErrorSeverity::Medium,
            JiveError::NetworkError { .. } => ErrorSeverity::Medium,
            JiveError::SyncError { .. } => ErrorSeverity::Medium,
            JiveError::AuthenticationError { .. } => ErrorSeverity::Medium,
            JiveError::AuthorizationError { .. } => ErrorSeverity::Medium,
            _ => ErrorSeverity::Low,
        }
    }

    #[derive(Debug, Clone, PartialEq)]
    pub enum ErrorSeverity {
        Low,
        Medium,
        High,
        Critical,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_amount() {
        assert!(validate_amount("100.50").is_ok());
        assert!(validate_amount("invalid").is_err());
        assert!(validate_amount("0").is_ok());
        assert!(validate_amount("-100.50").is_ok());
    }

    #[test]
    fn test_validate_currency() {
        assert!(validate_currency("USD").is_ok());
        assert!(validate_currency("EUR").is_ok());
        assert!(validate_currency("CNY").is_ok());
        assert!(validate_currency("INVALID").is_err());
    }

    #[test]
    fn test_validate_email() {
        assert!(validate_email("test@example.com").is_ok());
        assert!(validate_email("user@domain.org").is_ok());
        assert!(validate_email("invalid").is_err());
        assert!(validate_email("").is_err());
        assert!(validate_email("@domain.com").is_err());
    }

    #[test]
    fn test_validate_id() {
        let uuid = uuid::Uuid::new_v4();
        assert!(validate_id(&uuid.to_string()).is_ok());
        assert!(validate_id("invalid-uuid").is_err());
        assert!(validate_id("").is_err());
    }

    #[test]
    fn test_error_classification() {
        use error_classification::*;

        let user_error = JiveError::ValidationError {
            message: "Test".to_string(),
        };
        assert!(is_user_error(&user_error));
        assert!(!is_system_error(&user_error));

        let system_error = JiveError::DatabaseError {
            message: "Test".to_string(),
        };
        assert!(!is_user_error(&system_error));
        assert!(is_system_error(&system_error));

        assert_eq!(get_severity(&user_error), ErrorSeverity::Low);
        assert_eq!(get_severity(&system_error), ErrorSeverity::High);
    }
}
