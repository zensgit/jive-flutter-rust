//! Transaction Adapter Layer
//!
//! Bridges HTTP DTOs (jive-api) with Application Service Commands.
//! Phase 1: Full implementation with TransactionAppService integration.

use axum::http::StatusCode;
use axum::Json;
use rust_decimal::Decimal;
use sqlx::PgPool;
use std::sync::Arc;
use uuid::Uuid;

use crate::application::transaction_app_service::{
    CreateTransactionCommand, TransactionAppService, UpdateTransactionCommand,
};
use crate::config::TransactionConfig;
use crate::error::{ApiError, ApiResult};
use crate::metrics::TransactionMetrics;
use crate::models::transaction::{CreateTransactionRequest, TransactionResponse};

/// Transaction adapter for HTTP ↔ Application Service translation
pub struct TransactionAdapter {
    pub config: TransactionConfig,
    pub metrics: Arc<TransactionMetrics>,
    app_service: TransactionAppService,
}

impl TransactionAdapter {
    pub fn new(config: TransactionConfig, metrics: Arc<TransactionMetrics>, pool: PgPool) -> Self {
        Self {
            config,
            metrics,
            app_service: TransactionAppService::new(pool),
        }
    }

    /// Create transaction - Implemented in Phase 1
    ///
    /// Maps HTTP request → Command → App Service → Response
    pub async fn create_transaction(
        &self,
        req: CreateTransactionRequest,
    ) -> ApiResult<Json<TransactionResponse>> {
        // Map HTTP DTO → Command
        let command = CreateTransactionCommand {
            ledger_id: req.ledger_id,
            account_id: req.account_id,
            transaction_date: req.transaction_date,
            amount: req.amount,
            transaction_type: req.transaction_type,
            category_id: req.category_id,
            payee: req.payee,
            notes: req.notes,
            target_account_id: req.target_account_id,
        };

        // Execute via application service
        let transaction = self.app_service.create_transaction(command).await?;

        // Update metrics
        self.metrics.increment_transaction_created();

        // Map domain model → HTTP response
        Ok(Json(TransactionResponse::from(transaction)))
    }

    /// Update transaction - Implemented in Phase 1
    pub async fn update_transaction(
        &self,
        id: Uuid,
        req: CreateTransactionRequest,
    ) -> ApiResult<Json<TransactionResponse>> {
        // Map HTTP DTO → Command
        let command = UpdateTransactionCommand {
            id,
            transaction_date: Some(req.transaction_date),
            amount: Some(req.amount),
            transaction_type: Some(req.transaction_type),
            category_id: req.category_id,
            payee: req.payee,
            notes: req.notes,
        };

        // Execute via application service
        let transaction = self.app_service.update_transaction(command).await?;

        // Update metrics
        self.metrics.increment_transaction_updated();

        // Map domain model → HTTP response
        Ok(Json(TransactionResponse::from(transaction)))
    }

    /// Delete transaction - Implemented in Phase 1
    pub async fn delete_transaction(&self, id: Uuid) -> ApiResult<()> {
        // Execute via application service
        self.app_service.delete_transaction(id).await?;

        // Update metrics
        self.metrics.increment_transaction_deleted();

        Ok(())
    }

    /// Get transaction by ID - Implemented in Phase 1
    pub async fn get_transaction(&self, id: Uuid) -> ApiResult<Json<TransactionResponse>> {
        // Execute via application service
        let transaction = self.app_service.get_transaction(id).await?;

        // Map domain model → HTTP response
        Ok(Json(TransactionResponse::from(transaction)))
    }

    /// List transactions - Implemented in Phase 1
    pub async fn list_transactions(
        &self,
        account_id: Option<Uuid>,
        ledger_id: Option<Uuid>,
        limit: Option<i64>,
        offset: Option<i64>,
    ) -> ApiResult<Json<Vec<TransactionResponse>>> {
        let limit = limit.unwrap_or(50).min(1000); // Cap at 1000
        let offset = offset.unwrap_or(0);

        // Execute via application service
        let transactions = self
            .app_service
            .list_transactions(account_id, ledger_id, limit, offset)
            .await?;

        // Map domain models → HTTP responses
        let responses: Vec<TransactionResponse> =
            transactions.into_iter().map(TransactionResponse::from).collect();

        Ok(Json(responses))
    }

    // Private error mapping helper
    #[allow(dead_code)]
    fn map_error(err: ApiError) -> ApiError {
        // Currently pass-through, but could add custom mapping
        err
    }
}
