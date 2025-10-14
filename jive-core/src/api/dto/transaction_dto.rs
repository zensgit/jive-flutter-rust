//! Transaction DTOs (Data Transfer Objects)
//!
//! These structures define the HTTP API contract for transaction operations.
//! They are deliberately separate from domain models and application commands
//! to provide API versioning flexibility and validation boundaries.

use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// ============================================================================
// Request DTOs (HTTP → Application)
// ============================================================================

/// Request to create a new transaction
///
/// # Example JSON
/// ```json
/// {
///   "request_id": "550e8400-e29b-41d4-a716-446655440000",
///   "ledger_id": "650e8400-e29b-41d4-a716-446655440001",
///   "account_id": "750e8400-e29b-41d4-a716-446655440002",
///   "name": "Grocery Shopping",
///   "amount": "125.50",
///   "currency": "USD",
///   "date": "2025-10-14",
///   "transaction_type": "expense",
///   "category_id": "850e8400-e29b-41d4-a716-446655440003",
///   "notes": "Weekly groceries",
///   "tags": ["food", "essentials"]
/// }
/// ```
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CreateTransactionRequest {
    /// Idempotency key - same request_id will return cached result
    pub request_id: Uuid,

    /// Ledger to create transaction in
    pub ledger_id: Uuid,

    /// Account for the transaction
    pub account_id: Uuid,

    /// Transaction name/description
    #[serde(default)]
    pub name: String,

    /// Amount as string to prevent floating-point precision issues
    /// Examples: "100.00", "1234.56", "0.01"
    pub amount: String,

    /// Currency code (USD, EUR, JPY, etc.)
    pub currency: String,

    /// Transaction date (YYYY-MM-DD)
    pub date: NaiveDate,

    /// Transaction type: "income", "expense", or "transfer"
    pub transaction_type: String,

    /// Optional category
    #[serde(skip_serializing_if = "Option::is_none")]
    pub category_id: Option<Uuid>,

    /// Optional notes
    #[serde(skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,

    /// Optional tags
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,

    /// Optional recipient (for expenses/transfers)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub recipient: Option<String>,

    /// Optional payer (for income)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub payer: Option<String>,
}

/// Request to transfer money between accounts
///
/// # Example JSON
/// ```json
/// {
///   "request_id": "550e8400-e29b-41d4-a716-446655440000",
///   "from_account_id": "750e8400-e29b-41d4-a716-446655440001",
///   "to_account_id": "750e8400-e29b-41d4-a716-446655440002",
///   "amount": "500.00",
///   "currency": "USD",
///   "date": "2025-10-14",
///   "name": "Transfer to savings",
///   "fx_rate": "1.25",
///   "fx_target_currency": "EUR"
/// }
/// ```
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TransferRequest {
    pub request_id: Uuid,
    pub from_account_id: Uuid,
    pub to_account_id: Uuid,

    /// Amount in source account currency (as string)
    pub amount: String,

    /// Source account currency
    pub currency: String,

    pub date: NaiveDate,

    #[serde(default)]
    pub name: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,

    /// Foreign exchange rate (for cross-currency transfers)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fx_rate: Option<String>,

    /// Target currency (for FX transfers)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fx_target_currency: Option<String>,
}

/// Request to update an existing transaction
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct UpdateTransactionRequest {
    pub request_id: Uuid,
    pub transaction_id: Uuid,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub name: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub amount: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub date: Option<NaiveDate>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub category_id: Option<Uuid>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub tags: Option<Vec<String>>,
}

/// Request to delete a transaction
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DeleteTransactionRequest {
    pub request_id: Uuid,
    pub transaction_id: Uuid,

    /// Optional reason for deletion (for audit trail)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
}

/// Request to bulk import transactions
///
/// # Example JSON
/// ```json
/// {
///   "request_id": "550e8400-e29b-41d4-a716-446655440000",
///   "ledger_id": "650e8400-e29b-41d4-a716-446655440001",
///   "account_id": "750e8400-e29b-41d4-a716-446655440002",
///   "policy": "skip_duplicates",
///   "transactions": [
///     {
///       "name": "Transaction 1",
///       "amount": "100.00",
///       "currency": "USD",
///       "date": "2025-10-01",
///       "transaction_type": "expense"
///     }
///   ]
/// }
/// ```
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BulkImportRequest {
    pub request_id: Uuid,
    pub ledger_id: Uuid,
    pub account_id: Uuid,

    /// Import policy: "skip_duplicates", "update_existing", "fail_on_duplicate"
    pub policy: String,

    /// List of transactions to import
    pub transactions: Vec<ImportTransactionItem>,
}

/// Single transaction item for bulk import
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ImportTransactionItem {
    pub name: String,
    pub amount: String,
    pub currency: String,
    pub date: NaiveDate,
    pub transaction_type: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub category_id: Option<Uuid>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,

    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,

    /// External ID from source system (for duplicate detection)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub external_id: Option<String>,
}

// ============================================================================
// Response DTOs (Application → HTTP)
// ============================================================================

/// Response for transaction creation
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TransactionResponse {
    pub transaction_id: Uuid,
    pub account_id: Uuid,
    pub name: String,
    pub amount: String,  // Decimal as string
    pub currency: String,
    pub date: String,  // ISO 8601 date
    pub transaction_type: String,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub category_id: Option<Uuid>,

    #[serde(skip_serializing_if = "Option::is_none")]
    pub notes: Option<String>,

    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub tags: Vec<String>,

    /// Journal entries created (for double-entry bookkeeping)
    pub entries: Vec<EntryResponse>,

    /// New account balance after transaction
    pub new_balance: String,

    /// Timestamps
    pub created_at: String,  // ISO 8601 timestamp
    pub updated_at: String,
}

/// Journal entry in response
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EntryResponse {
    pub entry_id: Uuid,
    pub account_id: Uuid,
    pub amount: String,
    pub currency: String,
    pub nature: String,  // "inflow" or "outflow"
    pub balance_after: String,
}

/// Response for transfer operations
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TransferResponse {
    pub transfer_id: Uuid,
    pub from_account_id: Uuid,
    pub to_account_id: Uuid,
    pub amount: String,
    pub currency: String,
    pub date: String,
    pub name: String,

    /// Foreign exchange details (if applicable)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub fx_details: Option<FxDetailsResponse>,

    /// Transaction IDs created (one per account)
    pub transaction_ids: Vec<Uuid>,

    /// New balances
    pub from_account_new_balance: String,
    pub to_account_new_balance: String,

    pub created_at: String,
}

/// Foreign exchange details in response
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FxDetailsResponse {
    pub rate: String,
    pub source_amount: String,
    pub source_currency: String,
    pub target_amount: String,
    pub target_currency: String,
}

/// Response for bulk import operations
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BulkImportResponse {
    pub total: usize,
    pub imported: usize,
    pub skipped: usize,
    pub failed: usize,

    /// IDs of successfully imported transactions
    pub imported_ids: Vec<Uuid>,

    /// Errors for failed imports
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub errors: Vec<ImportErrorResponse>,

    pub completed_at: String,
}

/// Error details for failed import
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ImportErrorResponse {
    pub index: usize,
    pub external_id: Option<String>,
    pub error_message: String,
    pub error_code: String,
}

/// Response for deletion operations
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DeleteTransactionResponse {
    pub transaction_id: Uuid,
    pub deleted: bool,
    pub message: String,
    pub deleted_at: String,
}

// ============================================================================
// Query Parameters (for list endpoints)
// ============================================================================

/// Query parameters for listing transactions
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ListTransactionsQuery {
    /// Account ID to filter by
    #[serde(skip_serializing_if = "Option::is_none")]
    pub account_id: Option<Uuid>,

    /// Start date (inclusive)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub start_date: Option<NaiveDate>,

    /// End date (inclusive)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub end_date: Option<NaiveDate>,

    /// Transaction type filter
    #[serde(skip_serializing_if = "Option::is_none")]
    pub transaction_type: Option<String>,

    /// Category filter
    #[serde(skip_serializing_if = "Option::is_none")]
    pub category_id: Option<Uuid>,

    /// Pagination: page size (default: 50, max: 500)
    #[serde(default = "default_limit")]
    pub limit: usize,

    /// Pagination: offset (default: 0)
    #[serde(default)]
    pub offset: usize,

    /// Sort field: "date", "amount", "created_at" (default: "date")
    #[serde(default = "default_sort")]
    pub sort: String,

    /// Sort direction: "asc" or "desc" (default: "desc")
    #[serde(default = "default_order")]
    pub order: String,
}

fn default_limit() -> usize {
    50
}

fn default_sort() -> String {
    "date".to_string()
}

fn default_order() -> String {
    "desc".to_string()
}

/// Paginated list response
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PaginatedTransactionsResponse {
    pub transactions: Vec<TransactionResponse>,
    pub total: usize,
    pub limit: usize,
    pub offset: usize,
    pub has_more: bool,
}

// ============================================================================
// Validation Helpers
// ============================================================================

impl CreateTransactionRequest {
    /// Basic validation (more comprehensive validation in validator module)
    pub fn is_valid(&self) -> bool {
        !self.name.is_empty()
            && !self.amount.is_empty()
            && !self.currency.is_empty()
            && !self.transaction_type.is_empty()
    }
}

impl TransferRequest {
    pub fn is_valid(&self) -> bool {
        !self.amount.is_empty()
            && !self.currency.is_empty()
            && self.from_account_id != self.to_account_id
    }
}

impl BulkImportRequest {
    pub fn is_valid(&self) -> bool {
        !self.policy.is_empty() && !self.transactions.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_transaction_request_serialization() {
        let request = CreateTransactionRequest {
            request_id: Uuid::new_v4(),
            ledger_id: Uuid::new_v4(),
            account_id: Uuid::new_v4(),
            name: "Test Transaction".to_string(),
            amount: "100.50".to_string(),
            currency: "USD".to_string(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            transaction_type: "expense".to_string(),
            category_id: None,
            notes: None,
            tags: vec![],
            recipient: None,
            payer: None,
        };

        let json = serde_json::to_string(&request).unwrap();
        assert!(json.contains("Test Transaction"));
        assert!(json.contains("100.50"));

        let deserialized: CreateTransactionRequest = serde_json::from_str(&json).unwrap();
        assert_eq!(deserialized.name, "Test Transaction");
        assert_eq!(deserialized.amount, "100.50");
    }

    #[test]
    fn test_transfer_request_validation() {
        let from_id = Uuid::new_v4();
        let to_id = Uuid::new_v4();

        let valid_request = TransferRequest {
            request_id: Uuid::new_v4(),
            from_account_id: from_id,
            to_account_id: to_id,
            amount: "100.00".to_string(),
            currency: "USD".to_string(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            name: "Transfer".to_string(),
            notes: None,
            fx_rate: None,
            fx_target_currency: None,
        };

        assert!(valid_request.is_valid());

        // Invalid: same account
        let invalid_request = TransferRequest {
            from_account_id: from_id,
            to_account_id: from_id,  // Same as from
            ..valid_request.clone()
        };

        assert!(!invalid_request.is_valid());
    }

    #[test]
    fn test_list_transactions_query_defaults() {
        let query = ListTransactionsQuery {
            account_id: None,
            start_date: None,
            end_date: None,
            transaction_type: None,
            category_id: None,
            limit: default_limit(),
            offset: 0,
            sort: default_sort(),
            order: default_order(),
        };

        assert_eq!(query.limit, 50);
        assert_eq!(query.sort, "date");
        assert_eq!(query.order, "desc");
    }
}
