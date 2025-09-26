//! 数据库基础设施模块

pub mod connection;

pub use connection::{Database, DatabaseConfig, HealthMonitor};
