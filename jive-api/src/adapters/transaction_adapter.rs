use std::sync::Arc;
use rust_decimal::Decimal;
use uuid::Uuid;

use crate::config::TransactionConfig;
use crate::metrics::TransactionMetrics;

#[derive(Debug, Clone)]
pub struct TransactionAdapter {
    pub config: TransactionConfig,
    pub metrics: Arc<TransactionMetrics>,
    // TODO: wire core repository/app service here
    // core_repo: Arc<jive_core::infrastructure::repositories::TransactionRepository>,
    // legacy_service: Option<Arc<crate::services::transaction_service::TransactionService>>,
}

#[derive(Debug, Clone)]
pub struct TransactionResponse {
    pub id: Uuid,
    pub new_balance: Decimal,
}

impl TransactionAdapter {
    pub fn new(config: TransactionConfig, metrics: Arc<TransactionMetrics>) -> Self {
        Self { config, metrics }
    }
}

