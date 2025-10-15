//! Transaction Results
//!
//! Result objects returned from transaction command execution.

use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

use crate::domain::{
    ids::{AccountId, CategoryId, EntryId, LedgerId, PayeeId, TransactionId},
    types::{Nature, TransactionStatus, TransactionType},
    value_objects::money::Money,
};

/// Result of creating a transaction
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TransactionResult {
    /// Created transaction ID
    pub transaction_id: TransactionId,
    /// Ledger ID
    pub ledger_id: LedgerId,
    /// Account ID
    pub account_id: AccountId,
    /// Transaction name
    pub name: String,
    /// Description
    pub description: Option<String>,
    /// Amount
    pub amount: Money,
    /// Transaction date
    pub date: NaiveDate,
    /// Transaction type
    pub transaction_type: TransactionType,
    /// Category
    pub category_id: Option<CategoryId>,
    /// Payee
    pub payee_id: Option<PayeeId>,
    /// Status
    pub status: TransactionStatus,
    /// Tags
    pub tags: Vec<String>,
    /// Notes
    pub notes: Option<String>,
    /// Related journal entries
    pub entries: Vec<EntryResult>,
    /// Account balance after transaction
    pub new_balance: Money,
    /// Created timestamp
    pub created_at: DateTime<Utc>,
    /// Updated timestamp
    pub updated_at: DateTime<Utc>,
}

/// Result of a journal entry
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EntryResult {
    /// Entry ID
    pub entry_id: EntryId,
    /// Account ID
    pub account_id: AccountId,
    /// Entry nature (Inflow/Outflow)
    pub nature: Nature,
    /// Amount
    pub amount: Money,
    /// Balance after this entry
    pub balance_after: Money,
}

/// Result of a transfer operation
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TransferResult {
    /// Transfer ID (transaction ID)
    pub transfer_id: TransactionId,
    /// Ledger ID
    pub ledger_id: LedgerId,
    /// Source transaction
    pub from_transaction: TransactionResult,
    /// Destination transaction
    pub to_transaction: TransactionResult,
    /// Source account balance after transfer
    pub from_balance: Money,
    /// Destination account balance after transfer
    pub to_balance: Money,
    /// Created timestamp
    pub created_at: DateTime<Utc>,
}

/// Result of a split transaction operation
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SplitTransactionResult {
    /// Original transaction ID
    pub original_transaction_id: TransactionId,
    /// Split transactions
    pub split_transactions: Vec<TransactionResult>,
    /// Total split amount
    pub total_amount: Money,
    /// Created timestamp
    pub created_at: DateTime<Utc>,
}

/// Result of bulk import operation
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BulkImportResult {
    /// Total transactions in import
    pub total: usize,
    /// Successfully imported
    pub imported: usize,
    /// Skipped (duplicates or conflicts)
    pub skipped: usize,
    /// Failed (errors)
    pub failed: usize,
    /// Successfully imported transaction IDs
    pub imported_ids: Vec<TransactionId>,
    /// Import errors
    pub errors: Vec<ImportError>,
    /// Import timestamp
    pub imported_at: DateTime<Utc>,
}

/// Import error details
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ImportError {
    /// Row index in import file
    pub row_index: usize,
    /// External ID (if provided)
    pub external_id: Option<String>,
    /// Error message
    pub error_message: String,
}

/// Result of settlement operation
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SettlementResult {
    /// Settled transaction IDs
    pub settled_transaction_ids: Vec<TransactionId>,
    /// Settlement date
    pub settlement_date: DateTime<Utc>,
    /// Count of settled transactions
    pub count: usize,
}

/// Result of reconciliation operation
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReconciliationResult {
    /// Account ID
    pub account_id: AccountId,
    /// Reconciled transaction IDs
    pub reconciled_transaction_ids: Vec<TransactionId>,
    /// Statement date
    pub statement_date: NaiveDate,
    /// Statement balance
    pub statement_balance: Money,
    /// Computed balance (from reconciled transactions)
    pub computed_balance: Money,
    /// Balance difference
    pub difference: Money,
    /// Is balanced (difference is zero)
    pub is_balanced: bool,
    /// Reconciliation timestamp
    pub reconciled_at: DateTime<Utc>,
}

/// Result of a delete operation
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DeleteResult {
    /// Deleted transaction ID
    pub transaction_id: TransactionId,
    /// Deletion timestamp
    pub deleted_at: DateTime<Utc>,
}

/// Result of a restore operation
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RestoreResult {
    /// Restored transaction ID
    pub transaction_id: TransactionId,
    /// Restore timestamp
    pub restored_at: DateTime<Utc>,
}

/// Balance summary
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BalanceSummary {
    /// Account ID
    pub account_id: AccountId,
    /// Current balance
    pub balance: Money,
    /// Pending transactions total
    pub pending_total: Money,
    /// Available balance (current - pending)
    pub available_balance: Money,
    /// Last transaction date
    pub last_transaction_date: Option<NaiveDate>,
    /// As of timestamp
    pub as_of: DateTime<Utc>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::domain::value_objects::money::CurrencyCode;
    use rust_decimal::Decimal;
    use std::str::FromStr;

    #[test]
    fn test_transaction_result() {
        let result = TransactionResult {
            transaction_id: TransactionId::new(),
            ledger_id: LedgerId::new(),
            account_id: AccountId::new(),
            name: "Test".to_string(),
            description: None,
            amount: Money::new(Decimal::from_str("100.00").unwrap(), CurrencyCode::USD).unwrap(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            transaction_type: TransactionType::Expense,
            category_id: None,
            payee_id: None,
            status: TransactionStatus::Pending,
            tags: vec![],
            notes: None,
            entries: vec![],
            new_balance: Money::new(Decimal::from_str("900.00").unwrap(), CurrencyCode::USD)
                .unwrap(),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };

        assert_eq!(result.name, "Test");
        assert_eq!(result.amount.currency, CurrencyCode::USD);
    }

    #[test]
    fn test_bulk_import_result() {
        let result = BulkImportResult {
            total: 100,
            imported: 95,
            skipped: 3,
            failed: 2,
            imported_ids: vec![],
            errors: vec![ImportError {
                row_index: 10,
                external_id: Some("EXT-123".to_string()),
                error_message: "Invalid amount".to_string(),
            }],
            imported_at: Utc::now(),
        };

        assert_eq!(result.total, 100);
        assert_eq!(result.imported + result.skipped + result.failed, 100);
    }

    #[test]
    fn test_reconciliation_result_balanced() {
        let statement_balance =
            Money::new(Decimal::from_str("1000.00").unwrap(), CurrencyCode::USD).unwrap();
        let computed_balance =
            Money::new(Decimal::from_str("1000.00").unwrap(), CurrencyCode::USD).unwrap();
        let difference = Money::zero(CurrencyCode::USD);

        let result = ReconciliationResult {
            account_id: AccountId::new(),
            reconciled_transaction_ids: vec![],
            statement_date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            statement_balance: statement_balance.clone(),
            computed_balance: computed_balance.clone(),
            difference,
            is_balanced: true,
            reconciled_at: Utc::now(),
        };

        assert!(result.is_balanced);
        assert_eq!(result.statement_balance, result.computed_balance);
    }
}
