//! Transaction Commands
//!
//! Immutable command objects representing user intentions for transaction operations.

use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

use crate::domain::{
    ids::{AccountId, CategoryId, LedgerId, PayeeId, RequestId, TransactionId},
    types::{ConflictStrategy, FxSpec, ImportPolicy, Nature, TransactionStatus, TransactionType},
    value_objects::money::{CurrencyCode, Money},
};

/// Command to create a single transaction
///
/// # Examples
///
/// ```
/// use jive_core::application::commands::CreateTransactionCommand;
/// use jive_core::domain::value_objects::money::{Money, CurrencyCode};
/// use jive_core::domain::ids::*;
/// use jive_core::domain::types::TransactionType;
/// use chrono::{NaiveDate, Utc};
/// use rust_decimal::Decimal;
/// use std::str::FromStr;
///
/// let cmd = CreateTransactionCommand {
///     request_id: RequestId::new(),
///     ledger_id: LedgerId::new(),
///     account_id: AccountId::new(),
///     name: "Grocery shopping".to_string(),
///     description: Some("Weekly groceries".to_string()),
///     amount: Money::new(Decimal::from_str("150.00").unwrap(), CurrencyCode::USD).unwrap(),
///     date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
///     transaction_type: TransactionType::Expense,
///     category_id: Some(CategoryId::new()),
///     payee_id: None,
///     status: None,
///     tags: vec![],
///     notes: None,
/// };
/// ```
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CreateTransactionCommand {
    /// Idempotency key - prevents duplicate processing
    pub request_id: RequestId,
    /// Target ledger
    pub ledger_id: LedgerId,
    /// Account for the transaction
    pub account_id: AccountId,
    /// Transaction name/description
    pub name: String,
    /// Optional detailed description
    pub description: Option<String>,
    /// Transaction amount with currency
    pub amount: Money,
    /// Transaction date
    pub date: NaiveDate,
    /// Type: Income, Expense, or Transfer
    pub transaction_type: TransactionType,
    /// Optional category
    pub category_id: Option<CategoryId>,
    /// Optional payee
    pub payee_id: Option<PayeeId>,
    /// Optional status (defaults to Pending)
    pub status: Option<TransactionStatus>,
    /// Tags for categorization
    pub tags: Vec<String>,
    /// Additional notes
    pub notes: Option<String>,
}

/// Command to update an existing transaction
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct UpdateTransactionCommand {
    /// Idempotency key
    pub request_id: RequestId,
    /// Transaction to update
    pub transaction_id: TransactionId,
    /// Updated name
    pub name: Option<String>,
    /// Updated description
    pub description: Option<String>,
    /// Updated amount
    pub amount: Option<Money>,
    /// Updated date
    pub date: Option<NaiveDate>,
    /// Updated category
    pub category_id: Option<CategoryId>,
    /// Updated payee
    pub payee_id: Option<PayeeId>,
    /// Updated status
    pub status: Option<TransactionStatus>,
    /// Updated tags
    pub tags: Option<Vec<String>>,
    /// Updated notes
    pub notes: Option<String>,
}

/// Command to transfer money between accounts
///
/// Transfers create two entries (debit and credit) maintaining double-entry bookkeeping.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TransferCommand {
    /// Idempotency key
    pub request_id: RequestId,
    /// Target ledger
    pub ledger_id: LedgerId,
    /// Source account (money flows out)
    pub from_account_id: AccountId,
    /// Destination account (money flows in)
    pub to_account_id: AccountId,
    /// Transfer amount (in source account currency)
    pub amount: Money,
    /// Transfer date
    pub date: NaiveDate,
    /// Transfer description
    pub description: String,
    /// Optional category
    pub category_id: Option<CategoryId>,
    /// Optional exchange rate specification (for cross-currency transfers)
    pub fx_spec: Option<FxSpec>,
    /// Tags
    pub tags: Vec<String>,
    /// Notes
    pub notes: Option<String>,
}

/// Command to delete a transaction (soft delete)
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DeleteTransactionCommand {
    /// Idempotency key
    pub request_id: RequestId,
    /// Transaction to delete
    pub transaction_id: TransactionId,
}

/// Command to restore a soft-deleted transaction
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RestoreTransactionCommand {
    /// Idempotency key
    pub request_id: RequestId,
    /// Transaction to restore
    pub transaction_id: TransactionId,
}

/// Command to split a transaction into multiple parts
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SplitTransactionCommand {
    /// Idempotency key
    pub request_id: RequestId,
    /// Original transaction to split
    pub transaction_id: TransactionId,
    /// Split parts (must sum to original amount)
    pub splits: Vec<TransactionSplit>,
}

/// A split part of a transaction
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TransactionSplit {
    /// Amount for this split
    pub amount: Money,
    /// Category for this split
    pub category_id: CategoryId,
    /// Optional description
    pub description: Option<String>,
    /// Optional tags
    pub tags: Vec<String>,
}

/// Command to bulk import transactions
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BulkImportTransactionsCommand {
    /// Idempotency key
    pub request_id: RequestId,
    /// Target ledger
    pub ledger_id: LedgerId,
    /// Transactions to import
    pub transactions: Vec<ImportTransactionData>,
    /// Import policy
    pub policy: ImportPolicy,
}

/// Transaction data for import
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ImportTransactionData {
    /// External ID (for duplicate detection)
    pub external_id: Option<String>,
    /// Account ID
    pub account_id: AccountId,
    /// Transaction name
    pub name: String,
    /// Description
    pub description: Option<String>,
    /// Amount
    pub amount: Money,
    /// Date
    pub date: NaiveDate,
    /// Transaction type
    pub transaction_type: TransactionType,
    /// Category
    pub category_id: Option<CategoryId>,
    /// Payee
    pub payee_id: Option<PayeeId>,
    /// Tags
    pub tags: Vec<String>,
    /// Notes
    pub notes: Option<String>,
}

/// Command to settle (clear) pending transactions
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SettleTransactionsCommand {
    /// Idempotency key
    pub request_id: RequestId,
    /// Transactions to settle
    pub transaction_ids: Vec<TransactionId>,
    /// Settlement date
    pub settlement_date: DateTime<Utc>,
}

/// Command to reconcile transactions with bank statement
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReconcileTransactionsCommand {
    /// Idempotency key
    pub request_id: RequestId,
    /// Account being reconciled
    pub account_id: AccountId,
    /// Transactions to mark as reconciled
    pub transaction_ids: Vec<TransactionId>,
    /// Statement ending date
    pub statement_date: NaiveDate,
    /// Statement ending balance
    pub statement_balance: Money,
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal::Decimal;
    use std::str::FromStr;

    #[test]
    fn test_create_transaction_command() {
        let cmd = CreateTransactionCommand {
            request_id: RequestId::new(),
            ledger_id: LedgerId::new(),
            account_id: AccountId::new(),
            name: "Test Transaction".to_string(),
            description: None,
            amount: Money::new(Decimal::from_str("100.00").unwrap(), CurrencyCode::USD).unwrap(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            transaction_type: TransactionType::Expense,
            category_id: None,
            payee_id: None,
            status: None,
            tags: vec![],
            notes: None,
        };

        assert_eq!(cmd.name, "Test Transaction");
        assert_eq!(cmd.amount.currency, CurrencyCode::USD);
    }

    #[test]
    fn test_transfer_command() {
        let cmd = TransferCommand {
            request_id: RequestId::new(),
            ledger_id: LedgerId::new(),
            from_account_id: AccountId::new(),
            to_account_id: AccountId::new(),
            amount: Money::new(Decimal::from_str("500.00").unwrap(), CurrencyCode::USD).unwrap(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            description: "Transfer between accounts".to_string(),
            category_id: None,
            fx_spec: None,
            tags: vec![],
            notes: None,
        };

        assert_eq!(cmd.amount.amount, Decimal::from_str("500.00").unwrap());
    }

    #[test]
    fn test_split_transaction_command() {
        let split1 = TransactionSplit {
            amount: Money::new(Decimal::from_str("60.00").unwrap(), CurrencyCode::USD).unwrap(),
            category_id: CategoryId::new(),
            description: Some("Food".to_string()),
            tags: vec![],
        };

        let split2 = TransactionSplit {
            amount: Money::new(Decimal::from_str("40.00").unwrap(), CurrencyCode::USD).unwrap(),
            category_id: CategoryId::new(),
            description: Some("Drinks".to_string()),
            tags: vec![],
        };

        let cmd = SplitTransactionCommand {
            request_id: RequestId::new(),
            transaction_id: TransactionId::new(),
            splits: vec![split1, split2],
        };

        assert_eq!(cmd.splits.len(), 2);
    }
}
