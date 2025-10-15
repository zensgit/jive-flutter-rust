//! API Configuration
//!
//! Configuration structures for API adapter layer.

use serde::{Deserialize, Serialize};

/// API Configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiConfig {
    /// Default pagination limit
    pub default_page_size: usize,

    /// Maximum pagination limit
    pub max_page_size: usize,

    /// Maximum bulk import batch size
    pub max_bulk_import_size: usize,

    /// Request timeout in seconds
    pub request_timeout_seconds: u64,

    /// Enable detailed error messages (disable in production)
    pub detailed_errors: bool,

    /// API version
    pub api_version: String,
}

impl Default for ApiConfig {
    fn default() -> Self {
        Self {
            default_page_size: 50,
            max_page_size: 500,
            max_bulk_import_size: 1000,
            request_timeout_seconds: 30,
            detailed_errors: false,
            api_version: "v1".to_string(),
        }
    }
}

impl ApiConfig {
    /// Create production configuration
    pub fn production() -> Self {
        Self {
            detailed_errors: false,
            ..Default::default()
        }
    }

    /// Create development configuration
    pub fn development() -> Self {
        Self {
            detailed_errors: true,
            ..Default::default()
        }
    }

    /// Validate configuration
    pub fn validate(&self) -> Result<(), String> {
        if self.default_page_size == 0 {
            return Err("default_page_size must be greater than 0".to_string());
        }

        if self.max_page_size < self.default_page_size {
            return Err("max_page_size must be >= default_page_size".to_string());
        }

        if self.max_bulk_import_size == 0 {
            return Err("max_bulk_import_size must be greater than 0".to_string());
        }

        if self.request_timeout_seconds == 0 {
            return Err("request_timeout_seconds must be greater than 0".to_string());
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = ApiConfig::default();
        assert_eq!(config.default_page_size, 50);
        assert_eq!(config.max_page_size, 500);
        assert!(!config.detailed_errors);
    }

    #[test]
    fn test_production_config() {
        let config = ApiConfig::production();
        assert!(!config.detailed_errors);
        assert!(config.validate().is_ok());
    }

    #[test]
    fn test_development_config() {
        let config = ApiConfig::development();
        assert!(config.detailed_errors);
        assert!(config.validate().is_ok());
    }

    #[test]
    fn test_validation_invalid_page_size() {
        let config = ApiConfig {
            default_page_size: 100,
            max_page_size: 50, // Invalid: less than default
            ..Default::default()
        };

        assert!(config.validate().is_err());
    }
}
