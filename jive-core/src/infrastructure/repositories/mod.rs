// Repository Layer - Data Access Implementation
// Based on Maybe's database structure

pub mod family_repository;
pub mod user_repository;
pub mod account_repository;
pub mod transaction_repository;
pub mod category_repository;
pub mod balance_repository;

use async_trait::async_trait;
use sqlx::PgPool;
use std::sync::Arc;
use uuid::Uuid;

// Common repository trait
#[async_trait]
pub trait Repository<T> {
    type Error;
    
    async fn find_by_id(&self, id: Uuid) -> Result<Option<T>, Self::Error>;
    async fn find_all(&self) -> Result<Vec<T>, Self::Error>;
    async fn create(&self, entity: T) -> Result<T, Self::Error>;
    async fn update(&self, entity: T) -> Result<T, Self::Error>;
    async fn delete(&self, id: Uuid) -> Result<bool, Self::Error>;
}

// Base repository struct
pub struct BaseRepository {
    pub pool: Arc<PgPool>,
}

impl BaseRepository {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }
}

// Common error type
#[derive(Debug, thiserror::Error)]
pub enum RepositoryError {
    #[error("Database error: {0}")]
    Database(#[from] sqlx::Error),
    
    #[error("Entity not found")]
    NotFound,
    
    #[error("Invalid data: {0}")]
    InvalidData(String),
    
    #[error("Foreign key violation: {0}")]
    ForeignKeyViolation(String),
    
    #[error("Unique constraint violation: {0}")]
    UniqueViolation(String),
}

impl From<sqlx::Error> for RepositoryError {
    fn from(err: sqlx::Error) -> Self {
        match err {
            sqlx::Error::RowNotFound => RepositoryError::NotFound,
            sqlx::Error::Database(db_err) => {
                if let Some(constraint) = db_err.constraint() {
                    if constraint.contains("fk_") {
                        return RepositoryError::ForeignKeyViolation(constraint.to_string());
                    } else if constraint.contains("unique") || constraint.contains("idx_") {
                        return RepositoryError::UniqueViolation(constraint.to_string());
                    }
                }
                RepositoryError::Database(sqlx::Error::Database(db_err))
            }
            _ => RepositoryError::Database(err),
        }
    }
}