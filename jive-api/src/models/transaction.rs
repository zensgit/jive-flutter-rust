use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Transaction {
    pub id: Uuid,
    pub ledger_id: Uuid,
    pub account_id: Uuid,
    pub transaction_date: DateTime<Utc>,
    pub amount: Decimal,
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
    pub amount: Decimal,
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
    pub amount: Option<Decimal>,
    pub transaction_type: Option<TransactionType>,
    pub category_id: Option<Uuid>,
    pub category_name: Option<String>,
    pub payee: Option<String>,
    pub notes: Option<String>,
    pub status: Option<TransactionStatus>,
}

// ===== Phase 0: HTTP API Types (Decimal-enabled) =====

/// HTTP request type for creating transactions
/// Uses Decimal for precise monetary amounts with string serialization
#[derive(Debug, Clone, Deserialize)]
pub struct CreateTransactionRequest {
    pub ledger_id: Uuid,
    pub account_id: Uuid,
    pub transaction_date: DateTime<Utc>,

    #[serde(with = "rust_decimal::serde::str")]
    pub amount: Decimal,  // Precise monetary amount

    pub transaction_type: TransactionType,
    pub category_id: Option<Uuid>,
    pub payee: Option<String>,
    pub notes: Option<String>,
    pub target_account_id: Option<Uuid>, // For transfers
}

/// HTTP response type for transaction operations
/// Uses Decimal for precise monetary amounts with string serialization
#[derive(Debug, Clone, Serialize)]
pub struct TransactionResponse {
    pub id: Uuid,
    pub ledger_id: Uuid,
    pub account_id: Uuid,
    pub transaction_date: DateTime<Utc>,

    #[serde(with = "rust_decimal::serde::str")]
    pub amount: Decimal,  // Precise monetary amount

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

impl From<Transaction> for TransactionResponse {
    fn from(tx: Transaction) -> Self {
        Self {
            id: tx.id,
            ledger_id: tx.ledger_id,
            account_id: tx.account_id,
            transaction_date: tx.transaction_date,
            amount: tx.amount,
            transaction_type: tx.transaction_type,
            category_id: tx.category_id,
            category_name: tx.category_name,
            payee: tx.payee,
            notes: tx.notes,
            status: tx.status,
            related_transaction_id: tx.related_transaction_id,
            created_at: tx.created_at,
            updated_at: tx.updated_at,
        }
    }
}
