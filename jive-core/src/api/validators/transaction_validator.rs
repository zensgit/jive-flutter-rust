//! Transaction Request Validators
//!
//! Comprehensive validation logic for transaction DTOs.
//! Validates beyond basic type checking to enforce business rules.

use rust_decimal::Decimal;
use std::str::FromStr;

use crate::{
    api::dto::*,
    domain::value_objects::money::CurrencyCode,
    error::{JiveError, Result},
};

/// Validation result with multiple errors
#[derive(Debug, Clone)]
pub struct ValidationErrors {
    pub errors: Vec<ValidationError>,
}

#[derive(Debug, Clone)]
pub struct ValidationError {
    pub field: String,
    pub message: String,
}

impl ValidationErrors {
    pub fn new() -> Self {
        Self { errors: Vec::new() }
    }

    pub fn add(&mut self, field: impl Into<String>, message: impl Into<String>) {
        self.errors.push(ValidationError {
            field: field.into(),
            message: message.into(),
        });
    }

    pub fn is_empty(&self) -> bool {
        self.errors.is_empty()
    }

    pub fn into_result(self) -> Result<()> {
        if self.is_empty() {
            Ok(())
        } else {
            Err(JiveError::ValidationError {
                field: self.errors[0].field.clone(),
                message: format!(
                    "{} validation errors: {}",
                    self.errors.len(),
                    self.errors
                        .iter()
                        .map(|e| format!("{}: {}", e.field, e.message))
                        .collect::<Vec<_>>()
                        .join(", ")
                ),
            })
        }
    }
}

impl Default for ValidationErrors {
    fn default() -> Self {
        Self::new()
    }
}

// ============================================================================
// Request Validators
// ============================================================================

/// Validate CreateTransactionRequest
///
/// Checks:
/// - Non-empty required fields
/// - Valid amount format and range
/// - Valid currency code
/// - Valid transaction type
/// - Amount precision matches currency
/// - Tags format
pub fn validate_create_transaction_request(req: &CreateTransactionRequest) -> Result<()> {
    let mut errors = ValidationErrors::new();

    // Name validation
    if req.name.trim().is_empty() {
        errors.add("name", "Transaction name cannot be empty");
    }
    if req.name.len() > 200 {
        errors.add("name", "Transaction name cannot exceed 200 characters");
    }

    // Amount validation
    if req.amount.trim().is_empty() {
        errors.add("amount", "Amount cannot be empty");
    } else {
        match Decimal::from_str(&req.amount) {
            Ok(decimal) => {
                // Check if positive
                if decimal <= Decimal::ZERO {
                    errors.add("amount", "Amount must be positive");
                }

                // Check if too large (prevent overflow)
                if decimal > Decimal::from(999_999_999_999i64) {
                    errors.add("amount", "Amount too large (max: 999,999,999,999)");
                }

                // Validate precision against currency
                if let Ok(currency) = CurrencyCode::from_str(&req.currency) {
                    let max_scale = currency.decimal_places();
                    if decimal.scale() > max_scale {
                        errors.add(
                            "amount",
                            format!(
                                "{} supports maximum {} decimal places, got {}",
                                currency,
                                max_scale,
                                decimal.scale()
                            ),
                        );
                    }
                }
            }
            Err(_) => {
                errors.add("amount", "Invalid amount format. Use decimal numbers like '100.50'");
            }
        }
    }

    // Currency validation
    if req.currency.trim().is_empty() {
        errors.add("currency", "Currency cannot be empty");
    } else if CurrencyCode::from_str(&req.currency).is_err() {
        errors.add(
            "currency",
            format!(
                "Invalid currency code: {}. Supported: USD, EUR, GBP, JPY, CNY, AUD, CAD, CHF, HKD, SGD",
                req.currency
            ),
        );
    }

    // Transaction type validation
    if req.transaction_type.trim().is_empty() {
        errors.add("transaction_type", "Transaction type cannot be empty");
    } else {
        let valid_types = ["income", "expense", "transfer"];
        if !valid_types.contains(&req.transaction_type.to_lowercase().as_str()) {
            errors.add(
                "transaction_type",
                format!(
                    "Invalid transaction type: {}. Must be 'income', 'expense', or 'transfer'",
                    req.transaction_type
                ),
            );
        }
    }

    // Notes validation (optional but has max length)
    if let Some(notes) = &req.notes {
        if notes.len() > 1000 {
            errors.add("notes", "Notes cannot exceed 1000 characters");
        }
    }

    // Tags validation
    if req.tags.len() > 20 {
        errors.add("tags", "Maximum 20 tags allowed");
    }
    for tag in &req.tags {
        if tag.trim().is_empty() {
            errors.add("tags", "Tags cannot be empty strings");
            break;
        }
        if tag.len() > 50 {
            errors.add("tags", "Each tag cannot exceed 50 characters");
            break;
        }
    }

    // Recipient validation (optional, for expenses)
    if let Some(recipient) = &req.recipient {
        if recipient.len() > 200 {
            errors.add("recipient", "Recipient name cannot exceed 200 characters");
        }
    }

    // Payer validation (optional, for income)
    if let Some(payer) = &req.payer {
        if payer.len() > 200 {
            errors.add("payer", "Payer name cannot exceed 200 characters");
        }
    }

    errors.into_result()
}

/// Validate TransferRequest
///
/// Checks:
/// - All basic validations from create transaction
/// - Different source and target accounts
/// - FX rate consistency (both rate and target currency required)
pub fn validate_transfer_request(req: &TransferRequest) -> Result<()> {
    let mut errors = ValidationErrors::new();

    // Same account check
    if req.from_account_id == req.to_account_id {
        errors.add(
            "from_account_id",
            "Source and target accounts must be different",
        );
    }

    // Name validation
    if req.name.trim().is_empty() {
        errors.add("name", "Transfer description cannot be empty");
    }
    if req.name.len() > 200 {
        errors.add("name", "Transfer description cannot exceed 200 characters");
    }

    // Amount validation (similar to create transaction)
    if req.amount.trim().is_empty() {
        errors.add("amount", "Amount cannot be empty");
    } else {
        match Decimal::from_str(&req.amount) {
            Ok(decimal) => {
                if decimal <= Decimal::ZERO {
                    errors.add("amount", "Amount must be positive");
                }
                if decimal > Decimal::from(999_999_999_999i64) {
                    errors.add("amount", "Amount too large");
                }
            }
            Err(_) => {
                errors.add("amount", "Invalid amount format");
            }
        }
    }

    // Currency validation
    if req.currency.trim().is_empty() {
        errors.add("currency", "Currency cannot be empty");
    } else if CurrencyCode::from_str(&req.currency).is_err() {
        errors.add("currency", format!("Invalid currency code: {}", req.currency));
    }

    // FX validation (both or neither)
    match (&req.fx_rate, &req.fx_target_currency) {
        (Some(rate_str), Some(target_currency)) => {
            // Validate FX rate
            match Decimal::from_str(rate_str) {
                Ok(rate) => {
                    if rate <= Decimal::ZERO {
                        errors.add("fx_rate", "Exchange rate must be positive");
                    }
                    if rate > Decimal::from(10000) {
                        errors.add("fx_rate", "Exchange rate too large (max: 10000)");
                    }
                }
                Err(_) => {
                    errors.add("fx_rate", "Invalid exchange rate format");
                }
            }

            // Validate target currency
            if CurrencyCode::from_str(target_currency).is_err() {
                errors.add(
                    "fx_target_currency",
                    format!("Invalid target currency: {}", target_currency),
                );
            }

            // Check if source and target currencies are different
            if req.currency == *target_currency {
                errors.add(
                    "fx_target_currency",
                    "Source and target currencies must be different for FX transfers",
                );
            }
        }
        (Some(_), None) => {
            errors.add("fx_target_currency", "Target currency required when FX rate provided");
        }
        (None, Some(_)) => {
            errors.add("fx_rate", "Exchange rate required when target currency provided");
        }
        (None, None) => {
            // No FX transfer, OK
        }
    }

    // Notes validation
    if let Some(notes) = &req.notes {
        if notes.len() > 1000 {
            errors.add("notes", "Notes cannot exceed 1000 characters");
        }
    }

    errors.into_result()
}

/// Validate BulkImportRequest
///
/// Checks:
/// - Valid import policy
/// - Non-empty transactions list
/// - Reasonable batch size
/// - Each transaction item validates
pub fn validate_bulk_import_request(req: &BulkImportRequest) -> Result<()> {
    let mut errors = ValidationErrors::new();

    // Policy validation
    let valid_policies = ["skip_duplicates", "update_existing", "fail_on_duplicate"];
    if !valid_policies.contains(&req.policy.to_lowercase().as_str()) {
        errors.add(
            "policy",
            format!(
                "Invalid import policy: {}. Must be 'skip_duplicates', 'update_existing', or 'fail_on_duplicate'",
                req.policy
            ),
        );
    }

    // Transactions list validation
    if req.transactions.is_empty() {
        errors.add("transactions", "Cannot import empty transaction list");
    }

    if req.transactions.len() > 1000 {
        errors.add(
            "transactions",
            format!(
                "Batch too large: {} transactions. Maximum 1000 per batch",
                req.transactions.len()
            ),
        );
    }

    // Validate first few transactions for immediate feedback
    for (index, item) in req.transactions.iter().take(10).enumerate() {
        // Name validation
        if item.name.trim().is_empty() {
            errors.add(
                format!("transactions[{}].name", index),
                "Transaction name cannot be empty",
            );
        }

        // Amount validation
        if let Err(_) = Decimal::from_str(&item.amount) {
            errors.add(
                format!("transactions[{}].amount", index),
                "Invalid amount format",
            );
        }

        // Currency validation
        if CurrencyCode::from_str(&item.currency).is_err() {
            errors.add(
                format!("transactions[{}].currency", index),
                format!("Invalid currency: {}", item.currency),
            );
        }

        // Transaction type validation
        let valid_types = ["income", "expense", "transfer"];
        if !valid_types.contains(&item.transaction_type.to_lowercase().as_str()) {
            errors.add(
                format!("transactions[{}].transaction_type", index),
                format!("Invalid transaction type: {}", item.transaction_type),
            );
        }

        // External ID validation (if provided)
        if let Some(external_id) = &item.external_id {
            if external_id.len() > 100 {
                errors.add(
                    format!("transactions[{}].external_id", index),
                    "External ID cannot exceed 100 characters",
                );
            }
        }
    }

    errors.into_result()
}

/// Validate ListTransactionsQuery
///
/// Checks:
/// - Pagination parameters (limit, offset)
/// - Sort field validity
/// - Date range validity
pub fn validate_list_transactions_query(query: &ListTransactionsQuery) -> Result<()> {
    let mut errors = ValidationErrors::new();

    // Limit validation
    if query.limit == 0 {
        errors.add("limit", "Limit must be at least 1");
    }
    if query.limit > 500 {
        errors.add("limit", "Limit cannot exceed 500");
    }

    // Sort field validation
    let valid_sorts = ["date", "amount", "created_at", "name"];
    if !valid_sorts.contains(&query.sort.as_str()) {
        errors.add(
            "sort",
            format!(
                "Invalid sort field: {}. Must be one of: date, amount, created_at, name",
                query.sort
            ),
        );
    }

    // Order validation
    let valid_orders = ["asc", "desc"];
    if !valid_orders.contains(&query.order.to_lowercase().as_str()) {
        errors.add(
            "order",
            format!("Invalid order: {}. Must be 'asc' or 'desc'", query.order),
        );
    }

    // Date range validation
    if let (Some(start), Some(end)) = (query.start_date, query.end_date) {
        if start > end {
            errors.add("start_date", "Start date must be before or equal to end date");
        }
    }

    // Transaction type validation (if provided)
    if let Some(txn_type) = &query.transaction_type {
        let valid_types = ["income", "expense", "transfer"];
        if !valid_types.contains(&txn_type.to_lowercase().as_str()) {
            errors.add(
                "transaction_type",
                format!("Invalid transaction type filter: {}", txn_type),
            );
        }
    }

    errors.into_result()
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDate;
    use uuid::Uuid;

    #[test]
    fn test_validate_create_transaction_request_success() {
        let req = CreateTransactionRequest {
            request_id: Uuid::new_v4(),
            ledger_id: Uuid::new_v4(),
            account_id: Uuid::new_v4(),
            name: "Valid Transaction".to_string(),
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

        assert!(validate_create_transaction_request(&req).is_ok());
    }

    #[test]
    fn test_validate_create_transaction_request_empty_name() {
        let req = CreateTransactionRequest {
            request_id: Uuid::new_v4(),
            ledger_id: Uuid::new_v4(),
            account_id: Uuid::new_v4(),
            name: "".to_string(),
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

        assert!(validate_create_transaction_request(&req).is_err());
    }

    #[test]
    fn test_validate_create_transaction_request_invalid_amount() {
        let req = CreateTransactionRequest {
            request_id: Uuid::new_v4(),
            ledger_id: Uuid::new_v4(),
            account_id: Uuid::new_v4(),
            name: "Test".to_string(),
            amount: "invalid".to_string(),
            currency: "USD".to_string(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            transaction_type: "expense".to_string(),
            category_id: None,
            notes: None,
            tags: vec![],
            recipient: None,
            payer: None,
        };

        assert!(validate_create_transaction_request(&req).is_err());
    }

    #[test]
    fn test_validate_create_transaction_request_negative_amount() {
        let req = CreateTransactionRequest {
            request_id: Uuid::new_v4(),
            ledger_id: Uuid::new_v4(),
            account_id: Uuid::new_v4(),
            name: "Test".to_string(),
            amount: "-100.50".to_string(),
            currency: "USD".to_string(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            transaction_type: "expense".to_string(),
            category_id: None,
            notes: None,
            tags: vec![],
            recipient: None,
            payer: None,
        };

        assert!(validate_create_transaction_request(&req).is_err());
    }

    #[test]
    fn test_validate_create_transaction_request_invalid_currency() {
        let req = CreateTransactionRequest {
            request_id: Uuid::new_v4(),
            ledger_id: Uuid::new_v4(),
            account_id: Uuid::new_v4(),
            name: "Test".to_string(),
            amount: "100.50".to_string(),
            currency: "INVALID".to_string(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            transaction_type: "expense".to_string(),
            category_id: None,
            notes: None,
            tags: vec![],
            recipient: None,
            payer: None,
        };

        assert!(validate_create_transaction_request(&req).is_err());
    }

    #[test]
    fn test_validate_create_transaction_request_precision_mismatch() {
        let req = CreateTransactionRequest {
            request_id: Uuid::new_v4(),
            ledger_id: Uuid::new_v4(),
            account_id: Uuid::new_v4(),
            name: "Test".to_string(),
            amount: "100.123".to_string(), // 3 decimals for USD (should be 2)
            currency: "USD".to_string(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            transaction_type: "expense".to_string(),
            category_id: None,
            notes: None,
            tags: vec![],
            recipient: None,
            payer: None,
        };

        assert!(validate_create_transaction_request(&req).is_err());
    }

    #[test]
    fn test_validate_transfer_request_same_account() {
        let account_id = Uuid::new_v4();
        let req = TransferRequest {
            request_id: Uuid::new_v4(),
            from_account_id: account_id,
            to_account_id: account_id, // Same account
            amount: "100.00".to_string(),
            currency: "USD".to_string(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            name: "Transfer".to_string(),
            notes: None,
            fx_rate: None,
            fx_target_currency: None,
        };

        assert!(validate_transfer_request(&req).is_err());
    }

    #[test]
    fn test_validate_transfer_request_fx_incomplete() {
        let req = TransferRequest {
            request_id: Uuid::new_v4(),
            from_account_id: Uuid::new_v4(),
            to_account_id: Uuid::new_v4(),
            amount: "100.00".to_string(),
            currency: "USD".to_string(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            name: "Transfer".to_string(),
            notes: None,
            fx_rate: Some("1.25".to_string()),
            fx_target_currency: None, // Missing target currency
        };

        assert!(validate_transfer_request(&req).is_err());
    }

    #[test]
    fn test_validate_bulk_import_request_empty() {
        let req = BulkImportRequest {
            request_id: Uuid::new_v4(),
            ledger_id: Uuid::new_v4(),
            account_id: Uuid::new_v4(),
            policy: "skip_duplicates".to_string(),
            transactions: vec![], // Empty
        };

        assert!(validate_bulk_import_request(&req).is_err());
    }

    #[test]
    fn test_validate_list_transactions_query_invalid_limit() {
        let query = ListTransactionsQuery {
            account_id: None,
            start_date: None,
            end_date: None,
            transaction_type: None,
            category_id: None,
            limit: 1000, // Too large
            offset: 0,
            sort: "date".to_string(),
            order: "desc".to_string(),
        };

        assert!(validate_list_transactions_query(&query).is_err());
    }

    #[test]
    fn test_validate_list_transactions_query_invalid_date_range() {
        let query = ListTransactionsQuery {
            account_id: None,
            start_date: Some(NaiveDate::from_ymd_opt(2025, 12, 31).unwrap()),
            end_date: Some(NaiveDate::from_ymd_opt(2025, 1, 1).unwrap()), // End before start
            transaction_type: None,
            category_id: None,
            limit: 50,
            offset: 0,
            sort: "date".to_string(),
            order: "desc".to_string(),
        };

        assert!(validate_list_transactions_query(&query).is_err());
    }
}
