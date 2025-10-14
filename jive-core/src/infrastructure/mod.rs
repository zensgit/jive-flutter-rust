//! 基础设施层
//! 包含数据库访问、外部服务集成等

#[cfg(feature = "server")]
pub mod database;

// 仅在显式启用 legacy_entities 时暴露（避免 SQLx 准备阶段扫描到未对齐表）
#[cfg(all(feature = "server", feature = "legacy_entities"))]
pub mod entities;

pub mod repositories;
