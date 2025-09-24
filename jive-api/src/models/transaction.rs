use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Transaction {
    pub id: Uuid,
    pub ledger_id: Uuid,
    pub account_id: Uuid,
    pub transaction_date: DateTime<Utc>,
    pub amount: f64,
    pub transaction_type: TransactionType,
    pub category_id: Option<Uuid>,
    pub category_name: Option<String>,
    pub payee: Option<String>,
    pub notes: Option<String>,
    pub status: TransactionStatus,
    pub related_transaction_id: Option<Uuid>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type, PartialEq)]
#[sqlx(type_name = "transaction_type", rename_all = "lowercase")]
#[serde(rename_all = "lowercase")]
pub enum TransactionType {
    Income,
    Expense,
    Transfer,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "transaction_status", rename_all = "lowercase")]
#[serde(rename_all = "lowercase")]
pub enum TransactionStatus {
    Pending,
    Cleared,
    Reconciled,
    Void,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionCreate {
    pub ledger_id: Uuid,
    pub account_id: Uuid,
    pub transaction_date: DateTime<Utc>,
    pub amount: f64,
    pub transaction_type: TransactionType,
    pub category_id: Option<Uuid>,
    pub category_name: Option<String>,
    pub payee: Option<String>,
    pub notes: Option<String>,
    pub status: TransactionStatus,
    pub target_account_id: Option<Uuid>, // For transfers
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionUpdate {
    pub transaction_date: Option<DateTime<Utc>>,
    pub amount: Option<f64>,
    pub transaction_type: Option<TransactionType>,
    pub category_id: Option<Uuid>,
    pub category_name: Option<String>,
    pub payee: Option<String>,
    pub notes: Option<String>,
    pub status: Option<TransactionStatus>,
}
