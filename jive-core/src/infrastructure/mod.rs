//! 基础设施层
//! 包含数据库访问、外部服务集成等

#[cfg(feature = "server")]
pub mod database;

// 仅在服务端构建暴露 entities（大量依赖 sqlx::FromRow/sqlx::Type）
// 仅在显式启用 legacy_entities 时暴露（避免 SQLx 扫描到未对齐表）
#[cfg(all(feature = "server", feature = "legacy_entities"))]
pub mod entities;

// 仓储实现仅在启用 db 时暴露
#[cfg(feature = "db")]
pub mod repositories;
