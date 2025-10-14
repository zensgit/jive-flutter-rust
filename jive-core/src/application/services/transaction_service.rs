//! Transaction Service Trait
//!
//! Defines the contract for transaction application services.
//! Implementations must handle idempotency, validation, and
//! domain logic orchestration.

use async_trait::async_trait;
use chrono::NaiveDate;

use crate::{
    application::{
        commands::*,
        results::*,
    },
    domain::ids::{AccountId, LedgerId, TransactionId},
    error::Result,
};

/// Transaction Application Service
///
/// Orchestrates transaction use cases, coordinating between domain logic,
/// repositories, and infrastructure services.
///
/// # Responsibilities
///
/// - Validate commands
/// - Check idempotency (duplicate request prevention)
/// - Orchestrate domain logic
/// - Persist changes via repositories
/// - Return structured results
///
/// # Thread Safety
///
/// Implementations must be thread-safe (Send + Sync) for use in async contexts.
#[async_trait]
pub trait TransactionAppService: Send + Sync {
    /// Create a new transaction
    ///
    /// # Idempotency
    ///
    /// If a transaction with the same `request_id` exists, returns the existing
    /// transaction without creating a duplicate.
    ///
    /// # Validation
    ///
    /// - Account must exist and be active
    /// - Ledger must exist and belong to user's family
    /// - Amount must be valid for currency
    /// - Date must be valid
    ///
    /// # Balance Update
    ///
    /// Updates account balance according to transaction type:
    /// - Income: Balance increases
    /// - Expense: Balance decreases
    /// - Transfer: Handled by `transfer()` method
    ///
    /// # Returns
    ///
    /// `TransactionResult` with created transaction details and new balance.
    async fn create_transaction(
        &self,
        command: CreateTransactionCommand,
    ) -> Result<TransactionResult>;

    /// Update an existing transaction
    ///
    /// # Idempotency
    ///
    /// Uses `request_id` to prevent duplicate updates.
    ///
    /// # Validation
    ///
    /// - Transaction must exist and not be deleted
    /// - User must have permission to update
    /// - If amount changed, recalculates balance
    ///
    /// # Returns
    ///
    /// Updated `TransactionResult` with new balance if amount changed.
    async fn update_transaction(
        &self,
        command: UpdateTransactionCommand,
    ) -> Result<TransactionResult>;

    /// Transfer money between accounts
    ///
    /// Creates two transactions in a single atomic operation:
    /// - Debit from source account
    /// - Credit to destination account
    ///
    /// # Idempotency
    ///
    /// Uses `request_id` to prevent duplicate transfers.
    ///
    /// # Validation
    ///
    /// - Both accounts must exist and be active
    /// - Both accounts must belong to same ledger
    /// - Source account must have sufficient balance
    /// - If cross-currency, `fx_spec` must be provided
    ///
    /// # Balance Update
    ///
    /// - Source account balance decreases by amount
    /// - Destination account balance increases (by converted amount if cross-currency)
    ///
    /// # Returns
    ///
    /// `TransferResult` with both transactions and updated balances.
    async fn transfer(&self, command: TransferCommand) -> Result<TransferResult>;

    /// Split a transaction into multiple categories
    ///
    /// Replaces a single transaction with multiple split transactions,
    /// each with its own category and amount.
    ///
    /// # Idempotency
    ///
    /// Uses `request_id` to prevent duplicate splits.
    ///
    /// # Validation
    ///
    /// - Original transaction must exist
    /// - Split amounts must sum to original amount
    /// - All splits must have valid categories
    ///
    /// # Returns
    ///
    /// `SplitTransactionResult` with all split transactions.
    async fn split_transaction(
        &self,
        command: SplitTransactionCommand,
    ) -> Result<SplitTransactionResult>;

    /// Delete a transaction (soft delete)
    ///
    /// Marks transaction as deleted without removing from database.
    /// Balance is adjusted accordingly.
    ///
    /// # Idempotency
    ///
    /// Uses `request_id` to prevent duplicate deletes.
    ///
    /// # Validation
    ///
    /// - Transaction must exist
    /// - User must have permission to delete
    ///
    /// # Balance Update
    ///
    /// Reverses the transaction's effect on account balance.
    ///
    /// # Returns
    ///
    /// `DeleteResult` with deletion timestamp.
    async fn delete_transaction(
        &self,
        command: DeleteTransactionCommand,
    ) -> Result<DeleteResult>;

    /// Restore a soft-deleted transaction
    ///
    /// Unmarks transaction as deleted and restores balance effect.
    ///
    /// # Idempotency
    ///
    /// Uses `request_id` to prevent duplicate restores.
    ///
    /// # Returns
    ///
    /// `RestoreResult` with restore timestamp.
    async fn restore_transaction(
        &self,
        command: RestoreTransactionCommand,
    ) -> Result<RestoreResult>;

    /// Bulk import transactions
    ///
    /// Imports multiple transactions in a single operation with
    /// configurable conflict resolution.
    ///
    /// # Idempotency
    ///
    /// Uses `request_id` for overall operation. Individual transactions
    /// use `external_id` for duplicate detection.
    ///
    /// # Validation
    ///
    /// Each transaction is validated independently. Failures are collected
    /// and reported in the result.
    ///
    /// # Conflict Resolution
    ///
    /// Behavior depends on `ImportPolicy`:
    /// - Skip: Duplicates are skipped
    /// - Overwrite: Existing transactions are updated
    /// - Fail: First conflict aborts entire import
    ///
    /// # Returns
    ///
    /// `BulkImportResult` with success/failure counts and error details.
    async fn bulk_import(
        &self,
        command: BulkImportTransactionsCommand,
    ) -> Result<BulkImportResult>;

    /// Settle (clear) pending transactions
    ///
    /// Marks pending transactions as settled/cleared with a settlement date.
    ///
    /// # Idempotency
    ///
    /// Uses `request_id` to prevent duplicate settlements.
    ///
    /// # Returns
    ///
    /// `SettlementResult` with count of settled transactions.
    async fn settle_transactions(
        &self,
        command: SettleTransactionsCommand,
    ) -> Result<SettlementResult>;

    /// Reconcile transactions with bank statement
    ///
    /// Marks transactions as reconciled and validates against statement balance.
    ///
    /// # Idempotency
    ///
    /// Uses `request_id` to prevent duplicate reconciliations.
    ///
    /// # Validation
    ///
    /// - All transactions must belong to specified account
    /// - Computes balance from reconciled transactions
    /// - Compares with statement balance
    ///
    /// # Returns
    ///
    /// `ReconciliationResult` with balance comparison and any discrepancies.
    async fn reconcile_transactions(
        &self,
        command: ReconcileTransactionsCommand,
    ) -> Result<ReconciliationResult>;

    /// Get transaction by ID
    ///
    /// # Returns
    ///
    /// `TransactionResult` or error if not found.
    async fn get_transaction(&self, id: TransactionId) -> Result<TransactionResult>;

    /// Get account balance summary
    ///
    /// # Returns
    ///
    /// `BalanceSummary` with current, pending, and available balance.
    async fn get_balance_summary(&self, account_id: AccountId) -> Result<BalanceSummary>;
}

/// Reporting Query Service
///
/// Provides read-only queries for transaction reporting and analytics.
/// Separate from TransactionAppService to follow CQRS pattern.
#[async_trait]
pub trait ReportingQueryService: Send + Sync {
    /// List transactions for an account
    ///
    /// # Parameters
    ///
    /// - `account_id`: Account to query
    /// - `start_date`: Optional start date filter
    /// - `end_date`: Optional end date filter
    /// - `limit`: Maximum results to return
    /// - `offset`: Pagination offset
    ///
    /// # Returns
    ///
    /// Vec of `TransactionResult` matching criteria.
    async fn list_transactions(
        &self,
        account_id: AccountId,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
        limit: usize,
        offset: usize,
    ) -> Result<Vec<TransactionResult>>;

    /// List transactions for a ledger
    ///
    /// Similar to `list_transactions` but queries entire ledger.
    async fn list_ledger_transactions(
        &self,
        ledger_id: LedgerId,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
        limit: usize,
        offset: usize,
    ) -> Result<Vec<TransactionResult>>;

    /// Get transaction count for an account
    ///
    /// # Parameters
    ///
    /// - `account_id`: Account to count
    /// - `start_date`: Optional start date filter
    /// - `end_date`: Optional end date filter
    ///
    /// # Returns
    ///
    /// Total count of matching transactions.
    async fn count_transactions(
        &self,
        account_id: AccountId,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
    ) -> Result<usize>;

    /// Search transactions by text
    ///
    /// Searches transaction name, description, and notes.
    ///
    /// # Returns
    ///
    /// Vec of matching `TransactionResult`.
    async fn search_transactions(
        &self,
        ledger_id: LedgerId,
        query: String,
        limit: usize,
    ) -> Result<Vec<TransactionResult>>;
}

#[cfg(test)]
mod tests {
    use super::*;

    // Mock implementation for testing
    struct MockTransactionService;

    #[async_trait]
    impl TransactionAppService for MockTransactionService {
        async fn create_transaction(
            &self,
            _command: CreateTransactionCommand,
        ) -> Result<TransactionResult> {
            unimplemented!("Mock implementation")
        }

        async fn update_transaction(
            &self,
            _command: UpdateTransactionCommand,
        ) -> Result<TransactionResult> {
            unimplemented!("Mock implementation")
        }

        async fn transfer(&self, _command: TransferCommand) -> Result<TransferResult> {
            unimplemented!("Mock implementation")
        }

        async fn split_transaction(
            &self,
            _command: SplitTransactionCommand,
        ) -> Result<SplitTransactionResult> {
            unimplemented!("Mock implementation")
        }

        async fn delete_transaction(
            &self,
            _command: DeleteTransactionCommand,
        ) -> Result<DeleteResult> {
            unimplemented!("Mock implementation")
        }

        async fn restore_transaction(
            &self,
            _command: RestoreTransactionCommand,
        ) -> Result<RestoreResult> {
            unimplemented!("Mock implementation")
        }

        async fn bulk_import(
            &self,
            _command: BulkImportTransactionsCommand,
        ) -> Result<BulkImportResult> {
            unimplemented!("Mock implementation")
        }

        async fn settle_transactions(
            &self,
            _command: SettleTransactionsCommand,
        ) -> Result<SettlementResult> {
            unimplemented!("Mock implementation")
        }

        async fn reconcile_transactions(
            &self,
            _command: ReconcileTransactionsCommand,
        ) -> Result<ReconciliationResult> {
            unimplemented!("Mock implementation")
        }

        async fn get_transaction(&self, _id: TransactionId) -> Result<TransactionResult> {
            unimplemented!("Mock implementation")
        }

        async fn get_balance_summary(&self, _account_id: AccountId) -> Result<BalanceSummary> {
            unimplemented!("Mock implementation")
        }
    }

    #[test]
    fn test_mock_service_compiles() {
        // Just verify that the mock implements the trait
        let _service: Box<dyn TransactionAppService> = Box::new(MockTransactionService);
    }
}
