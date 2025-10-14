//! Transaction Mappers
//!
//! Bidirectional conversions between DTOs and domain/application types.
//! These mappers enforce the "interface-first" design by preventing
//! jive-api from directly using f64 or bypassing Money/Decimal types.

use chrono::Utc;
use rust_decimal::Decimal;
use std::str::FromStr;

use crate::{
    api::dto::*,
    domain::{
        ids::*,
        types::*,
        value_objects::money::{CurrencyCode, Money},
        base::{TransactionType, TransactionStatus},
    },
    error::{JiveError, Result},
};

// Application layer imports (feature-gated)
#[cfg(all(feature = "server", feature = "db"))]
use crate::application::{commands::*, results::*};

// ============================================================================
// Request DTOs → Commands
// ============================================================================

/// Convert CreateTransactionRequest to CreateTransactionCommand
///
/// # Errors
///
/// Returns error if:
/// - Amount cannot be parsed as Decimal
/// - Currency code is invalid
/// - Transaction type is invalid
pub fn create_transaction_request_to_command(
    dto: CreateTransactionRequest,
) -> Result<CreateTransactionCommand> {
    // Parse amount (string → Decimal to prevent f64 precision loss)
    let amount_decimal = Decimal::from_str(&dto.amount).map_err(|_| JiveError::InvalidAmount {
        amount: dto.amount.clone(),
    })?;

    // Parse currency
    let currency = CurrencyCode::from_str(&dto.currency).map_err(|_| {
        JiveError::InvalidCurrency {
            currency: dto.currency.clone(),
        }
    })?;

    // Create Money (validates precision)
    let amount = Money::new(amount_decimal, currency)?;

    // Parse transaction type
    let transaction_type = parse_transaction_type(&dto.transaction_type)?;

    Ok(CreateTransactionCommand {
        request_id: RequestId::from_uuid(dto.request_id),
        ledger_id: LedgerId::from_uuid(dto.ledger_id),
        account_id: AccountId::from_uuid(dto.account_id),
        name: dto.name,
        amount,
        date: dto.date,
        transaction_type,
        category_id: dto.category_id.map(CategoryId::from_uuid),
        notes: dto.notes,
        tags: dto.tags,
        recipient: dto.recipient,
        payer: dto.payer,
    })
}

/// Convert TransferRequest to TransferCommand
pub fn transfer_request_to_command(dto: TransferRequest) -> Result<TransferCommand> {
    let amount_decimal = Decimal::from_str(&dto.amount).map_err(|_| JiveError::InvalidAmount {
        amount: dto.amount.clone(),
    })?;

    let currency = CurrencyCode::from_str(&dto.currency).map_err(|_| {
        JiveError::InvalidCurrency {
            currency: dto.currency.clone(),
        }
    })?;

    let amount = Money::new(amount_decimal, currency)?;

    // Parse FX spec if provided
    let fx_spec = if let (Some(rate_str), Some(target_currency_str)) =
        (&dto.fx_rate, &dto.fx_target_currency)
    {
        let rate = Decimal::from_str(rate_str).map_err(|_| JiveError::InvalidAmount {
            amount: rate_str.clone(),
        })?;

        let target_currency =
            CurrencyCode::from_str(target_currency_str).map_err(|_| {
                JiveError::InvalidCurrency {
                    currency: target_currency_str.clone(),
                }
            })?;

        Some(FxSpec {
            rate,
            source_currency: currency,
            target_currency,
        })
    } else {
        None
    };

    Ok(TransferCommand {
        request_id: RequestId::from_uuid(dto.request_id),
        from_account_id: AccountId::from_uuid(dto.from_account_id),
        to_account_id: AccountId::from_uuid(dto.to_account_id),
        amount,
        date: dto.date,
        name: dto.name,
        notes: dto.notes,
        fx_spec,
    })
}

/// Convert UpdateTransactionRequest to UpdateTransactionCommand
pub fn update_transaction_request_to_command(
    dto: UpdateTransactionRequest,
) -> Result<UpdateTransactionCommand> {
    // Parse optional amount
    let amount = if let Some(amount_str) = dto.amount {
        let decimal = Decimal::from_str(&amount_str).map_err(|_| JiveError::InvalidAmount {
            amount: amount_str.clone(),
        })?;

        // Note: We don't have currency in update request, will need to fetch from existing transaction
        // For now, we'll store as Decimal and handle currency in service layer
        Some(decimal)
    } else {
        None
    };

    Ok(UpdateTransactionCommand {
        request_id: RequestId::from_uuid(dto.request_id),
        transaction_id: TransactionId::from_uuid(dto.transaction_id),
        name: dto.name,
        amount_decimal: amount, // Store as Decimal, not Money (currency from existing record)
        date: dto.date,
        category_id: dto.category_id.map(CategoryId::from_uuid),
        notes: dto.notes,
        tags: dto.tags,
    })
}

/// Convert DeleteTransactionRequest to DeleteTransactionCommand
pub fn delete_transaction_request_to_command(
    dto: DeleteTransactionRequest,
) -> Result<DeleteTransactionCommand> {
    Ok(DeleteTransactionCommand {
        request_id: RequestId::from_uuid(dto.request_id),
        transaction_id: TransactionId::from_uuid(dto.transaction_id),
        reason: dto.reason,
    })
}

/// Convert BulkImportRequest to BulkImportTransactionsCommand
pub fn bulk_import_request_to_command(dto: BulkImportRequest) -> Result<BulkImportTransactionsCommand> {
    let policy = parse_import_policy(&dto.policy)?;

    let items: Result<Vec<_>> = dto
        .transactions
        .into_iter()
        .map(|item| {
            let amount_decimal =
                Decimal::from_str(&item.amount).map_err(|_| JiveError::InvalidAmount {
                    amount: item.amount.clone(),
                })?;

            let currency =
                CurrencyCode::from_str(&item.currency).map_err(|_| {
                    JiveError::InvalidCurrency {
                        currency: item.currency.clone(),
                    }
                })?;

            let amount = Money::new(amount_decimal, currency)?;
            let transaction_type = parse_transaction_type(&item.transaction_type)?;

            Ok(ImportTransactionItem {
                name: item.name,
                amount,
                date: item.date,
                transaction_type,
                category_id: item.category_id.map(CategoryId::from_uuid),
                notes: item.notes,
                tags: item.tags,
                external_id: item.external_id,
            })
        })
        .collect();

    Ok(BulkImportTransactionsCommand {
        request_id: RequestId::from_uuid(dto.request_id),
        ledger_id: LedgerId::from_uuid(dto.ledger_id),
        account_id: AccountId::from_uuid(dto.account_id),
        policy,
        transactions: items?,
    })
}

// ============================================================================
// Results → Response DTOs
// ============================================================================

/// Convert TransactionResult to TransactionResponse
pub fn transaction_result_to_response(result: TransactionResult) -> TransactionResponse {
    TransactionResponse {
        transaction_id: result.transaction_id.as_uuid(),
        account_id: result.account_id.as_uuid(),
        name: result.name,
        amount: result.amount.amount.to_string(),
        currency: result.amount.currency.to_string(),
        date: result.date.format("%Y-%m-%d").to_string(),
        transaction_type: transaction_type_to_string(result.transaction_type),
        category_id: result.category_id.map(|id| id.as_uuid()),
        notes: result.notes,
        tags: result.tags,
        entries: result
            .entries
            .into_iter()
            .map(entry_result_to_response)
            .collect(),
        new_balance: result.new_balance.amount.to_string(),
        created_at: result.created_at.to_rfc3339(),
        updated_at: result.updated_at.to_rfc3339(),
    }
}

/// Convert EntryResult to EntryResponse
pub fn entry_result_to_response(result: EntryResult) -> EntryResponse {
    EntryResponse {
        entry_id: result.entry_id.as_uuid(),
        account_id: result.account_id.as_uuid(),
        amount: result.amount.amount.to_string(),
        currency: result.amount.currency.to_string(),
        nature: nature_to_string(result.nature),
        balance_after: result.balance_after.amount.to_string(),
    }
}

/// Convert TransferResult to TransferResponse
pub fn transfer_result_to_response(result: TransferResult) -> TransferResponse {
    let fx_details = result.fx_details.map(|fx| FxDetailsResponse {
        rate: fx.rate.to_string(),
        source_amount: fx.source_amount.amount.to_string(),
        source_currency: fx.source_amount.currency.to_string(),
        target_amount: fx.target_amount.amount.to_string(),
        target_currency: fx.target_amount.currency.to_string(),
    });

    TransferResponse {
        transfer_id: result.transfer_id.as_uuid(),
        from_account_id: result.from_account_id.as_uuid(),
        to_account_id: result.to_account_id.as_uuid(),
        amount: result.amount.amount.to_string(),
        currency: result.amount.currency.to_string(),
        date: result.date.format("%Y-%m-%d").to_string(),
        name: result.name,
        fx_details,
        transaction_ids: result
            .transaction_ids
            .into_iter()
            .map(|id| id.as_uuid())
            .collect(),
        from_account_new_balance: result.from_account_new_balance.amount.to_string(),
        to_account_new_balance: result.to_account_new_balance.amount.to_string(),
        created_at: result.created_at.to_rfc3339(),
    }
}

/// Convert BulkImportResult to BulkImportResponse
pub fn bulk_import_result_to_response(result: BulkImportResult) -> BulkImportResponse {
    BulkImportResponse {
        total: result.total,
        imported: result.imported,
        skipped: result.skipped,
        failed: result.failed,
        imported_ids: result
            .imported_ids
            .into_iter()
            .map(|id| id.as_uuid())
            .collect(),
        errors: result
            .errors
            .into_iter()
            .map(|e| ImportErrorResponse {
                index: e.index,
                external_id: e.external_id,
                error_message: e.error_message,
                error_code: e.error_code,
            })
            .collect(),
        completed_at: Utc::now().to_rfc3339(),
    }
}

/// Convert DeleteTransactionResult to DeleteTransactionResponse
pub fn delete_transaction_result_to_response(
    result: DeleteTransactionResult,
) -> DeleteTransactionResponse {
    DeleteTransactionResponse {
        transaction_id: result.transaction_id.as_uuid(),
        deleted: result.deleted,
        message: result.message,
        deleted_at: result.deleted_at.to_rfc3339(),
    }
}

// ============================================================================
// Helper Parsers
// ============================================================================

/// Parse transaction type string to enum
fn parse_transaction_type(s: &str) -> Result<TransactionType> {
    match s.to_lowercase().as_str() {
        "income" => Ok(TransactionType::Income),
        "expense" => Ok(TransactionType::Expense),
        "transfer" => Ok(TransactionType::Transfer),
        _ => Err(JiveError::ValidationError {
            field: "transaction_type".to_string(),
            message: format!("Invalid transaction type: {}. Must be 'income', 'expense', or 'transfer'", s),
        }),
    }
}

/// Convert transaction type enum to string
fn transaction_type_to_string(t: TransactionType) -> String {
    match t {
        TransactionType::Income => "income".to_string(),
        TransactionType::Expense => "expense".to_string(),
        TransactionType::Transfer => "transfer".to_string(),
    }
}

/// Parse import policy string to enum
fn parse_import_policy(s: &str) -> Result<ImportPolicy> {
    match s.to_lowercase().as_str() {
        "skip_duplicates" => Ok(ImportPolicy::SkipDuplicates),
        "update_existing" => Ok(ImportPolicy::UpdateExisting),
        "fail_on_duplicate" => Ok(ImportPolicy::FailOnDuplicate),
        _ => Err(JiveError::ValidationError {
            field: "policy".to_string(),
            message: format!(
                "Invalid import policy: {}. Must be 'skip_duplicates', 'update_existing', or 'fail_on_duplicate'",
                s
            ),
        }),
    }
}

/// Convert Nature enum to string
fn nature_to_string(nature: Nature) -> String {
    match nature {
        Nature::Inflow => "inflow".to_string(),
        Nature::Outflow => "outflow".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDate;

    #[test]
    fn test_create_transaction_request_to_command() {
        let dto = CreateTransactionRequest {
            request_id: uuid::Uuid::new_v4(),
            ledger_id: uuid::Uuid::new_v4(),
            account_id: uuid::Uuid::new_v4(),
            name: "Test".to_string(),
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

        let command = create_transaction_request_to_command(dto).unwrap();

        assert_eq!(command.name, "Test");
        assert_eq!(command.amount.amount.to_string(), "100.50");
        assert_eq!(command.amount.currency, CurrencyCode::USD);
        assert_eq!(command.transaction_type, TransactionType::Expense);
    }

    #[test]
    fn test_invalid_amount_parsing() {
        let dto = CreateTransactionRequest {
            request_id: uuid::Uuid::new_v4(),
            ledger_id: uuid::Uuid::new_v4(),
            account_id: uuid::Uuid::new_v4(),
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

        let result = create_transaction_request_to_command(dto);
        assert!(result.is_err());
        assert!(matches!(result.unwrap_err(), JiveError::InvalidAmount { .. }));
    }

    #[test]
    fn test_invalid_currency() {
        let dto = CreateTransactionRequest {
            request_id: uuid::Uuid::new_v4(),
            ledger_id: uuid::Uuid::new_v4(),
            account_id: uuid::Uuid::new_v4(),
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

        let result = create_transaction_request_to_command(dto);
        assert!(result.is_err());
        assert!(matches!(
            result.unwrap_err(),
            JiveError::InvalidCurrency { .. }
        ));
    }

    #[test]
    fn test_transaction_type_parsing() {
        assert!(matches!(
            parse_transaction_type("income").unwrap(),
            TransactionType::Income
        ));
        assert!(matches!(
            parse_transaction_type("EXPENSE").unwrap(),
            TransactionType::Expense
        ));
        assert!(matches!(
            parse_transaction_type("Transfer").unwrap(),
            TransactionType::Transfer
        ));
        assert!(parse_transaction_type("invalid").is_err());
    }

    #[test]
    fn test_transfer_request_to_command() {
        let dto = TransferRequest {
            request_id: uuid::Uuid::new_v4(),
            from_account_id: uuid::Uuid::new_v4(),
            to_account_id: uuid::Uuid::new_v4(),
            amount: "500.00".to_string(),
            currency: "USD".to_string(),
            date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
            name: "Transfer".to_string(),
            notes: None,
            fx_rate: Some("1.25".to_string()),
            fx_target_currency: Some("EUR".to_string()),
        };

        let command = transfer_request_to_command(dto).unwrap();

        assert_eq!(command.amount.amount.to_string(), "500.00");
        assert!(command.fx_spec.is_some());

        let fx = command.fx_spec.unwrap();
        assert_eq!(fx.rate.to_string(), "1.25");
        assert_eq!(fx.target_currency, CurrencyCode::EUR);
    }
}
