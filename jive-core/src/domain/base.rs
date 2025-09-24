//! Domain base traits and shared enums

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// 基础实体 trait
pub trait Entity {
    type Id;

    fn id(&self) -> &Self::Id;
    fn created_at(&self) -> DateTime<Utc>;
    fn updated_at(&self) -> DateTime<Utc>;
}

/// 软删除能力 trait
pub trait SoftDeletable {
    fn is_deleted(&self) -> bool;
    fn deleted_at(&self) -> Option<DateTime<Utc>>;
    fn soft_delete(&mut self);
    fn restore(&mut self);
}

/// 交易类型
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TransactionType {
    Income,
    Expense,
    Transfer,
}

/// 交易状态
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TransactionStatus {
    Pending,
    Completed,
    Reconciled,
    Voided,
}

/// 账户分类（领域层用于分类/模板）
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum AccountClassification {
    Income,
    Expense,
    Asset,
    Liability,
    Equity,
}
