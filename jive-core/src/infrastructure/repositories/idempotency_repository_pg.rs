//! PostgreSQL Idempotency Repository Implementation
//!
//! Provides persistent idempotency storage using PostgreSQL.

use async_trait::async_trait;
use sqlx::PgPool;

use super::idempotency_repository::{IdempotencyRecord, IdempotencyRepository};
use crate::{
    domain::ids::RequestId,
    error::{JiveError, Result},
};

/// PostgreSQL implementation of IdempotencyRepository
pub struct PgIdempotencyRepository {
    pool: PgPool,
}

impl PgIdempotencyRepository {
    /// Create a new PostgreSQL idempotency repository
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl IdempotencyRepository for PgIdempotencyRepository {
    async fn get(&self, request_id: &RequestId) -> Result<Option<IdempotencyRecord>> {
        let record = sqlx::query_as!(
            IdempotencyRecordRow,
            r#"
            SELECT
                request_id,
                operation,
                result_payload,
                status_code,
                created_at,
                expires_at
            FROM idempotency_records
            WHERE request_id = $1
              AND expires_at > NOW()
            "#,
            request_id.as_uuid()
        )
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError {
            message: format!("Failed to get idempotency record: {}", e),
        })?;

        Ok(record.map(|row| IdempotencyRecord {
            request_id: RequestId::from_uuid(row.request_id),
            operation: row.operation,
            result_payload: row.result_payload,
            status_code: row.status_code.map(|c| c as u16),
            created_at: row.created_at,
            expires_at: row.expires_at,
        }))
    }

    async fn save(
        &self,
        request_id: &RequestId,
        operation: String,
        result_payload: String,
        status_code: Option<u16>,
        ttl_hours: Option<i64>,
    ) -> Result<()> {
        let ttl = ttl_hours.unwrap_or(24);

        sqlx::query!(
            r#"
            INSERT INTO idempotency_records
                (request_id, operation, result_payload, status_code, expires_at)
            VALUES
                ($1, $2, $3, $4, NOW() + INTERVAL '1 hour' * $5)
            ON CONFLICT (request_id)
            DO UPDATE SET
                operation = EXCLUDED.operation,
                result_payload = EXCLUDED.result_payload,
                status_code = EXCLUDED.status_code,
                expires_at = EXCLUDED.expires_at
            "#,
            request_id.as_uuid(),
            operation,
            result_payload,
            status_code.map(|c| c as i32),
            ttl
        )
        .execute(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError {
            message: format!("Failed to save idempotency record: {}", e),
        })?;

        Ok(())
    }

    async fn delete(&self, request_id: &RequestId) -> Result<()> {
        sqlx::query!(
            r#"
            DELETE FROM idempotency_records
            WHERE request_id = $1
            "#,
            request_id.as_uuid()
        )
        .execute(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError {
            message: format!("Failed to delete idempotency record: {}", e),
        })?;

        Ok(())
    }

    async fn cleanup_expired(&self) -> Result<usize> {
        let result = sqlx::query!(
            r#"
            DELETE FROM idempotency_records
            WHERE expires_at <= NOW()
            "#
        )
        .execute(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError {
            message: format!("Failed to cleanup expired records: {}", e),
        })?;

        Ok(result.rows_affected() as usize)
    }
}

/// Database row structure (for sqlx query_as)
#[allow(dead_code)]
struct IdempotencyRecordRow {
    request_id: uuid::Uuid,
    operation: String,
    result_payload: String,
    status_code: Option<i32>,
    created_at: chrono::DateTime<chrono::Utc>,
    expires_at: chrono::DateTime<chrono::Utc>,
}

#[cfg(test)]
mod tests {
    use super::*;

    // Note: These tests require a running PostgreSQL database
    // Run with: TEST_DATABASE_URL=postgresql://... cargo test

    #[tokio::test]
    #[ignore] // Requires database connection
    async fn test_pg_idempotency_save_and_get() {
        let database_url = std::env::var("TEST_DATABASE_URL")
            .expect("TEST_DATABASE_URL must be set for integration tests");

        let pool = PgPool::connect(&database_url).await.unwrap();
        let repo = PgIdempotencyRepository::new(pool);

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
    #[ignore] // Requires database connection
    async fn test_pg_idempotency_cleanup() {
        let database_url = std::env::var("TEST_DATABASE_URL")
            .expect("TEST_DATABASE_URL must be set for integration tests");

        let pool = PgPool::connect(&database_url).await.unwrap();
        let repo = PgIdempotencyRepository::new(pool);

        // Create expired record (0 hour TTL)
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

        // Wait a bit to ensure expiry
        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;

        // Cleanup
        let cleaned = repo.cleanup_expired().await.unwrap();
        assert!(cleaned >= 1);

        // Verify deleted
        assert!(!repo.exists(&expired_id).await.unwrap());
    }
}
