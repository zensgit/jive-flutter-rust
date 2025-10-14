//! Idempotency Repository
//!
//! Provides idempotency storage to prevent duplicate command execution.
//! Supports both PostgreSQL (persistent) and Redis (cache) implementations.

use async_trait::async_trait;
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};

use crate::{
    domain::ids::RequestId,
    error::{JiveError, Result},
};

/// Idempotency record - stores the result of a request
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IdempotencyRecord {
    /// Request ID (idempotency key)
    pub request_id: RequestId,
    /// Operation type (e.g., "create_transaction", "transfer")
    pub operation: String,
    /// Result payload (JSON serialized)
    pub result_payload: String,
    /// HTTP status code (for API operations)
    pub status_code: Option<u16>,
    /// Created timestamp
    pub created_at: DateTime<Utc>,
    /// Expiry timestamp (for automatic cleanup)
    pub expires_at: DateTime<Utc>,
}

impl IdempotencyRecord {
    /// Create a new idempotency record
    pub fn new(
        request_id: RequestId,
        operation: String,
        result_payload: String,
        status_code: Option<u16>,
        ttl_hours: i64,
    ) -> Self {
        let now = Utc::now();
        Self {
            request_id,
            operation,
            result_payload,
            status_code,
            created_at: now,
            expires_at: now + Duration::hours(ttl_hours),
        }
    }

    /// Check if record has expired
    pub fn is_expired(&self) -> bool {
        Utc::now() > self.expires_at
    }
}

/// Idempotency Repository trait
///
/// Provides storage and retrieval of idempotency records to prevent
/// duplicate execution of commands.
///
/// # Implementations
///
/// - PostgreSQL: Persistent storage for long-term idempotency
/// - Redis: Fast cache for short-term idempotency
///
/// # Usage Pattern
///
/// ```ignore
/// // Before executing command
/// if let Some(record) = repo.get(&request_id).await? {
///     // Request already processed, return cached result
///     return Ok(deserialize_result(record.result_payload));
/// }
///
/// // Execute command
/// let result = execute_command().await?;
///
/// // Store result for future requests
/// repo.save(&request_id, "operation", serialize_result(&result)).await?;
/// ```
#[async_trait]
pub trait IdempotencyRepository: Send + Sync {
    /// Get idempotency record by request ID
    ///
    /// Returns None if not found or expired.
    async fn get(&self, request_id: &RequestId) -> Result<Option<IdempotencyRecord>>;

    /// Save idempotency record
    ///
    /// # Parameters
    ///
    /// - `request_id`: Unique request identifier
    /// - `operation`: Operation name for debugging
    /// - `result_payload`: Serialized result (usually JSON)
    /// - `status_code`: Optional HTTP status code
    /// - `ttl_hours`: Time-to-live in hours (default: 24)
    async fn save(
        &self,
        request_id: &RequestId,
        operation: String,
        result_payload: String,
        status_code: Option<u16>,
        ttl_hours: Option<i64>,
    ) -> Result<()>;

    /// Delete idempotency record
    ///
    /// Used for cleanup or manual invalidation.
    async fn delete(&self, request_id: &RequestId) -> Result<()>;

    /// Check if request has been processed
    ///
    /// Returns true if record exists and hasn't expired.
    async fn exists(&self, request_id: &RequestId) -> Result<bool> {
        Ok(self.get(request_id).await?.is_some())
    }

    /// Cleanup expired records
    ///
    /// Removes records past their expiry time.
    /// Should be called periodically by a background job.
    async fn cleanup_expired(&self) -> Result<usize>;
}

/// In-memory idempotency repository (for testing)
#[cfg(test)]
pub struct InMemoryIdempotencyRepository {
    records: std::sync::Arc<tokio::sync::RwLock<std::collections::HashMap<RequestId, IdempotencyRecord>>>,
}

#[cfg(test)]
impl InMemoryIdempotencyRepository {
    pub fn new() -> Self {
        Self {
            records: std::sync::Arc::new(tokio::sync::RwLock::new(std::collections::HashMap::new())),
        }
    }
}

#[cfg(test)]
#[async_trait]
impl IdempotencyRepository for InMemoryIdempotencyRepository {
    async fn get(&self, request_id: &RequestId) -> Result<Option<IdempotencyRecord>> {
        let records = self.records.read().await;
        Ok(records.get(request_id).cloned().filter(|r| !r.is_expired()))
    }

    async fn save(
        &self,
        request_id: &RequestId,
        operation: String,
        result_payload: String,
        status_code: Option<u16>,
        ttl_hours: Option<i64>,
    ) -> Result<()> {
        let mut records = self.records.write().await;
        let record = IdempotencyRecord::new(
            *request_id,
            operation,
            result_payload,
            status_code,
            ttl_hours.unwrap_or(24),
        );
        records.insert(*request_id, record);
        Ok(())
    }

    async fn delete(&self, request_id: &RequestId) -> Result<()> {
        let mut records = self.records.write().await;
        records.remove(request_id);
        Ok(())
    }

    async fn cleanup_expired(&self) -> Result<usize> {
        let mut records = self.records.write().await;
        let before_count = records.len();
        records.retain(|_, record| !record.is_expired());
        let after_count = records.len();
        Ok(before_count - after_count)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_idempotency_save_and_get() {
        let repo = InMemoryIdempotencyRepository::new();
        let request_id = RequestId::new();

        // Save record
        repo.save(
            &request_id,
            "test_operation".to_string(),
            r#"{"result": "success"}"#.to_string(),
            Some(200),
            Some(24),
        )
        .await
        .unwrap();

        // Get record
        let record = repo.get(&request_id).await.unwrap();
        assert!(record.is_some());

        let record = record.unwrap();
        assert_eq!(record.request_id, request_id);
        assert_eq!(record.operation, "test_operation");
        assert_eq!(record.result_payload, r#"{"result": "success"}"#);
        assert_eq!(record.status_code, Some(200));
    }

    #[tokio::test]
    async fn test_idempotency_exists() {
        let repo = InMemoryIdempotencyRepository::new();
        let request_id = RequestId::new();

        assert!(!repo.exists(&request_id).await.unwrap());

        repo.save(
            &request_id,
            "test".to_string(),
            "{}".to_string(),
            None,
            None,
        )
        .await
        .unwrap();

        assert!(repo.exists(&request_id).await.unwrap());
    }

    #[tokio::test]
    async fn test_idempotency_delete() {
        let repo = InMemoryIdempotencyRepository::new();
        let request_id = RequestId::new();

        repo.save(
            &request_id,
            "test".to_string(),
            "{}".to_string(),
            None,
            None,
        )
        .await
        .unwrap();

        assert!(repo.exists(&request_id).await.unwrap());

        repo.delete(&request_id).await.unwrap();

        assert!(!repo.exists(&request_id).await.unwrap());
    }

    #[tokio::test]
    async fn test_idempotency_expiry() {
        let repo = InMemoryIdempotencyRepository::new();
        let request_id = RequestId::new();

        // Create record with 0 hour TTL (immediately expired)
        repo.save(
            &request_id,
            "test".to_string(),
            "{}".to_string(),
            None,
            Some(0),
        )
        .await
        .unwrap();

        // Should return None because expired
        let record = repo.get(&request_id).await.unwrap();
        assert!(record.is_none());
    }

    #[tokio::test]
    async fn test_cleanup_expired() {
        let repo = InMemoryIdempotencyRepository::new();

        // Add expired record
        let expired_id = RequestId::new();
        repo.save(
            &expired_id,
            "expired".to_string(),
            "{}".to_string(),
            None,
            Some(0),
        )
        .await
        .unwrap();

        // Add valid record
        let valid_id = RequestId::new();
        repo.save(
            &valid_id,
            "valid".to_string(),
            "{}".to_string(),
            None,
            Some(24),
        )
        .await
        .unwrap();

        // Cleanup
        let cleaned = repo.cleanup_expired().await.unwrap();
        assert_eq!(cleaned, 1);

        // Valid record should still exist
        assert!(repo.exists(&valid_id).await.unwrap());
    }

    #[test]
    fn test_idempotency_record_is_expired() {
        let now = Utc::now();

        // Not expired
        let record = IdempotencyRecord {
            request_id: RequestId::new(),
            operation: "test".to_string(),
            result_payload: "{}".to_string(),
            status_code: None,
            created_at: now,
            expires_at: now + Duration::hours(1),
        };
        assert!(!record.is_expired());

        // Expired
        let expired_record = IdempotencyRecord {
            request_id: RequestId::new(),
            operation: "test".to_string(),
            result_payload: "{}".to_string(),
            status_code: None,
            created_at: now - Duration::hours(2),
            expires_at: now - Duration::hours(1),
        };
        assert!(expired_record.is_expired());
    }
}
