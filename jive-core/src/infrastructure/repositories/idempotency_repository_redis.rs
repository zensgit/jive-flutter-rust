//! Redis Idempotency Repository Implementation
//!
//! Provides fast cache-based idempotency storage using Redis.
//! Suitable for high-throughput scenarios with automatic expiry.

use async_trait::async_trait;
use redis::AsyncCommands;
use serde_json;

use super::idempotency_repository::{IdempotencyRecord, IdempotencyRepository};
use crate::{
    domain::ids::RequestId,
    error::{JiveError, Result},
};

/// Redis implementation of IdempotencyRepository
pub struct RedisIdempotencyRepository {
    client: redis::Client,
}

impl RedisIdempotencyRepository {
    /// Create a new Redis idempotency repository
    pub fn new(redis_url: &str) -> Result<Self> {
        let client = redis::Client::open(redis_url).map_err(|e| JiveError::DatabaseError {
            message: format!("Failed to connect to Redis: {}", e),
        })?;

        Ok(Self { client })
    }

    /// Generate Redis key for request ID
    fn key(&self, request_id: &RequestId) -> String {
        format!("idempotency:{}", request_id)
    }
}

#[async_trait]
impl IdempotencyRepository for RedisIdempotencyRepository {
    async fn get(&self, request_id: &RequestId) -> Result<Option<IdempotencyRecord>> {
        let mut conn = self.client.get_async_connection().await.map_err(|e| {
            JiveError::DatabaseError {
                message: format!("Failed to get Redis connection: {}", e),
            }
        })?;

        let key = self.key(request_id);
        let value: Option<String> = conn.get(&key).await.map_err(|e| JiveError::DatabaseError {
            message: format!("Failed to get from Redis: {}", e),
        })?;

        match value {
            Some(json) => {
                let record: IdempotencyRecord =
                    serde_json::from_str(&json).map_err(|e| JiveError::SerializationError {
                        message: format!("Failed to deserialize idempotency record: {}", e),
                    })?;

                // Check if expired
                if record.is_expired() {
                    // Delete expired record
                    let _: () = conn.del(&key).await.map_err(|e| JiveError::DatabaseError {
                        message: format!("Failed to delete expired record: {}", e),
                    })?;
                    Ok(None)
                } else {
                    Ok(Some(record))
                }
            }
            None => Ok(None),
        }
    }

    async fn save(
        &self,
        request_id: &RequestId,
        operation: String,
        result_payload: String,
        status_code: Option<u16>,
        ttl_hours: Option<i64>,
    ) -> Result<()> {
        let mut conn = self.client.get_async_connection().await.map_err(|e| {
            JiveError::DatabaseError {
                message: format!("Failed to get Redis connection: {}", e),
            }
        })?;

        let ttl = ttl_hours.unwrap_or(24);
        let record = IdempotencyRecord::new(
            *request_id,
            operation,
            result_payload,
            status_code,
            ttl,
        );

        let json = serde_json::to_string(&record).map_err(|e| JiveError::SerializationError {
            message: format!("Failed to serialize idempotency record: {}", e),
        })?;

        let key = self.key(request_id);
        let ttl_seconds = (ttl * 3600) as usize;

        // Set with expiry
        let _: () = conn
            .set_ex(&key, json, ttl_seconds)
            .await
            .map_err(|e| JiveError::DatabaseError {
                message: format!("Failed to save to Redis: {}", e),
            })?;

        Ok(())
    }

    async fn delete(&self, request_id: &RequestId) -> Result<()> {
        let mut conn = self.client.get_async_connection().await.map_err(|e| {
            JiveError::DatabaseError {
                message: format!("Failed to get Redis connection: {}", e),
            }
        })?;

        let key = self.key(request_id);
        let _: () = conn.del(&key).await.map_err(|e| JiveError::DatabaseError {
            message: format!("Failed to delete from Redis: {}", e),
        })?;

        Ok(())
    }

    async fn cleanup_expired(&self) -> Result<usize> {
        // Redis automatically removes expired keys, so we don't need to do anything
        // We return 0 to indicate no manual cleanup was performed
        Ok(0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Note: These tests require a running Redis instance
    // Run with: REDIS_URL=redis://localhost:6379 cargo test

    #[tokio::test]
    #[ignore] // Requires Redis connection
    async fn test_redis_idempotency_save_and_get() {
        let redis_url =
            std::env::var("REDIS_URL").unwrap_or_else(|_| "redis://localhost:6379".to_string());

        let repo = RedisIdempotencyRepository::new(&redis_url).unwrap();
        let request_id = RequestId::new();

        // Save
        repo.save(
            &request_id,
            "test_operation".to_string(),
            r#"{"result": "success"}"#.to_string(),
            Some(200),
            Some(24),
        )
        .await
        .unwrap();

        // Get
        let record = repo.get(&request_id).await.unwrap();
        assert!(record.is_some());

        let record = record.unwrap();
        assert_eq!(record.request_id, request_id);
        assert_eq!(record.operation, "test_operation");
        assert_eq!(record.status_code, Some(200));

        // Cleanup
        repo.delete(&request_id).await.unwrap();
    }

    #[tokio::test]
    #[ignore] // Requires Redis connection
    async fn test_redis_idempotency_expiry() {
        let redis_url =
            std::env::var("REDIS_URL").unwrap_or_else(|_| "redis://localhost:6379".to_string());

        let repo = RedisIdempotencyRepository::new(&redis_url).unwrap();
        let request_id = RequestId::new();

        // Save with 1 second TTL
        repo.save(
            &request_id,
            "test".to_string(),
            "{}".to_string(),
            None,
            Some(0), // 0 hours = immediately expired
        )
        .await
        .unwrap();

        // Should return None because immediately expired
        let record = repo.get(&request_id).await.unwrap();
        assert!(record.is_none());
    }

    #[tokio::test]
    #[ignore] // Requires Redis connection
    async fn test_redis_idempotency_exists() {
        let redis_url =
            std::env::var("REDIS_URL").unwrap_or_else(|_| "redis://localhost:6379".to_string());

        let repo = RedisIdempotencyRepository::new(&redis_url).unwrap();
        let request_id = RequestId::new();

        assert!(!repo.exists(&request_id).await.unwrap());

        repo.save(
            &request_id,
            "test".to_string(),
            "{}".to_string(),
            None,
            Some(24),
        )
        .await
        .unwrap();

        assert!(repo.exists(&request_id).await.unwrap());

        // Cleanup
        repo.delete(&request_id).await.unwrap();
    }
}
