//! 基础Repository trait定义
//! 提供通用的CRUD操作接口

use async_trait::async_trait;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 分页参数
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pagination {
    pub page: u32,
    pub per_page: u32,
}

impl Default for Pagination {
    fn default() -> Self {
        Self {
            page: 1,
            per_page: 20,
        }
    }
}

/// 分页结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginatedResult<T> {
    pub items: Vec<T>,
    pub total: i64,
    pub page: u32,
    pub per_page: u32,
    pub total_pages: u32,
}

/// Repository错误类型
#[derive(Debug, thiserror::Error)]
pub enum RepositoryError {
    #[error("Record not found")]
    NotFound,
    
    #[error("Database error: {0}")]
    DatabaseError(String),
    
    #[error("Validation error: {0}")]
    ValidationError(String),
    
    #[error("Conflict error: {0}")]
    ConflictError(String),
    
    #[error("Transaction error: {0}")]
    TransactionError(String),
}

/// 基础Repository trait
#[async_trait]
pub trait Repository<T>: Send + Sync {
    /// 根据ID查找
    async fn find_by_id(&self, id: Uuid) -> Result<Option<T>, RepositoryError>;
    
    /// 查找所有记录
    async fn find_all(&self) -> Result<Vec<T>, RepositoryError>;
    
    /// 分页查询
    async fn find_paginated(&self, pagination: Pagination) -> Result<PaginatedResult<T>, RepositoryError>;
    
    /// 创建新记录
    async fn create(&self, entity: T) -> Result<T, RepositoryError>;
    
    /// 更新记录
    async fn update(&self, id: Uuid, entity: T) -> Result<T, RepositoryError>;
    
    /// 删除记录
    async fn delete(&self, id: Uuid) -> Result<bool, RepositoryError>;
    
    /// 批量创建
    async fn create_batch(&self, entities: Vec<T>) -> Result<Vec<T>, RepositoryError>;
    
    /// 批量删除
    async fn delete_batch(&self, ids: Vec<Uuid>) -> Result<usize, RepositoryError>;
}

/// 软删除支持
#[async_trait]
pub trait SoftDeleteRepository<T>: Repository<T> {
    /// 软删除记录
    async fn soft_delete(&self, id: Uuid) -> Result<bool, RepositoryError>;
    
    /// 恢复软删除的记录
    async fn restore(&self, id: Uuid) -> Result<bool, RepositoryError>;
    
    /// 查找包括软删除的所有记录
    async fn find_all_with_deleted(&self) -> Result<Vec<T>, RepositoryError>;
}

/// 查询构建器trait
pub trait QueryBuilder {
    type Entity;
    
    /// 添加WHERE条件
    fn where_clause(self, column: &str, value: &str) -> Self;
    
    /// 添加排序
    fn order_by(self, column: &str, desc: bool) -> Self;
    
    /// 限制返回数量
    fn limit(self, limit: u32) -> Self;
    
    /// 设置偏移量
    fn offset(self, offset: u32) -> Self;
    
    /// 执行查询
    fn execute(self) -> Result<Vec<Self::Entity>, RepositoryError>;
}