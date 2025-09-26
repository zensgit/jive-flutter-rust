//! 基础设施层
//! 包含数据库访问、外部服务集成等

#[cfg(feature = "server")]
pub mod database;

// 仅在服务端构建暴露 entities（大量依赖 sqlx::FromRow/sqlx::Type）
#[cfg(feature = "server")]
pub mod entities;
