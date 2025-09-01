//! 基础设施层
//! 包含数据库访问、外部服务集成等

#[cfg(feature = "server")]
pub mod database;

pub mod entities;