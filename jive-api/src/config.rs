use rust_decimal::Decimal;

#[derive(Debug, Clone)]
pub struct TransactionConfig {
    pub use_core_transactions: bool,
    pub shadow_mode: bool,
    pub shadow_diff_threshold: Decimal,
}

impl Default for TransactionConfig {
    fn default() -> Self {
        Self {
            use_core_transactions: parse_bool_env("USE_CORE_TRANSACTIONS", false),
            shadow_mode: parse_bool_env("TRANSACTION_SHADOW_MODE", false),
            shadow_diff_threshold: Decimal::new(1, 6), // 0.000001
        }
    }
}

fn parse_bool_env(key: &str, default: bool) -> bool {
    match std::env::var(key) {
        Ok(v) => matches!(v.to_ascii_lowercase().as_str(), "1" | "true" | "yes" | "on"),
        Err(_) => default,
    }
}

