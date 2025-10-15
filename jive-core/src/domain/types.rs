/// Domain types - enums and type definitions for business logic
///
/// This module contains type-safe enumerations for domain concepts.
///
/// Note: TransactionType and TransactionStatus remain in base.rs for backward compatibility.

use serde::{Deserialize, Serialize};
use std::fmt;
use std::str::FromStr;

// Re-export from base module for convenience
pub use super::base::{TransactionType, TransactionStatus};

/// Entry nature - the direction of money flow in a journal entry
///
/// In double-entry bookkeeping, every transaction affects at least one
/// account, and the nature indicates whether money is flowing in or out.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Nature {
    /// Money flowing into the account (positive balance change)
    Inflow,
    /// Money flowing out of the account (negative balance change)
    Outflow,
}

impl Nature {
    /// Returns the string representation for database storage
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Inflow => "inflow",
            Self::Outflow => "outflow",
        }
    }

    /// Returns the opposite nature
    pub fn opposite(&self) -> Self {
        match self {
            Self::Inflow => Self::Outflow,
            Self::Outflow => Self::Inflow,
        }
    }

    /// Converts transaction type to entry nature for a given account
    ///
    /// For the source account:
    /// - Income → Inflow
    /// - Expense → Outflow
    /// - Transfer → Outflow (from source)
    pub fn from_transaction_type(txn_type: TransactionType, is_source: bool) -> Self {
        match (txn_type, is_source) {
            (TransactionType::Income, _) => Self::Inflow,
            (TransactionType::Expense, _) => Self::Outflow,
            (TransactionType::Transfer, true) => Self::Outflow,  // From source
            (TransactionType::Transfer, false) => Self::Inflow,  // To target
        }
    }
}

impl FromStr for Nature {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "inflow" => Ok(Self::Inflow),
            "outflow" => Ok(Self::Outflow),
            _ => Err(format!("Invalid nature: {}", s)),
        }
    }
}

impl fmt::Display for Nature {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}


/// Import policy for bulk operations
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct ImportPolicy {
    /// Whether to update existing transactions or skip them
    pub upsert: bool,
    /// Strategy for handling conflicts
    pub conflict_strategy: ConflictStrategy,
}

impl Default for ImportPolicy {
    fn default() -> Self {
        Self {
            upsert: false,
            conflict_strategy: ConflictStrategy::Skip,
        }
    }
}

/// Strategy for handling conflicts during import
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ConflictStrategy {
    /// Skip conflicting items
    Skip,
    /// Overwrite existing items
    Overwrite,
    /// Fail the entire import on first conflict
    Fail,
}

impl ConflictStrategy {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Skip => "skip",
            Self::Overwrite => "overwrite",
            Self::Fail => "fail",
        }
    }
}

/// Foreign exchange specification for cross-currency transfers
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct FxSpec {
    /// Exchange rate (how many units of target currency per unit of source)
    pub rate: rust_decimal::Decimal,
    /// Source of the exchange rate (e.g., "ECB", "manual", "api.exchangerate.com")
    pub source: String,
    /// Timestamp when this rate was obtained
    pub obtained_at: chrono::DateTime<chrono::Utc>,
    /// Optional: Rate validity window
    pub valid_until: Option<chrono::DateTime<chrono::Utc>>,
}

impl FxSpec {
    /// Converts an amount from source currency to target currency
    pub fn convert(&self, _source_money: &crate::domain::value_objects::money::Money)
        -> Result<crate::domain::value_objects::money::Money, String> {
        // Note: We don't know the target currency here, so caller must specify
        // This method is simplified; actual implementation would need target currency
        // Formula would be: target_amount = source_money.amount * self.rate
        Err("FxSpec::convert needs target currency parameter".to_string())
    }

    /// Validates that the exchange rate is within reasonable bounds
    pub fn validate(&self) -> Result<(), String> {
        use rust_decimal::Decimal;

        if self.rate <= Decimal::ZERO {
            return Err("Exchange rate must be positive".to_string());
        }

        // Check if rate has expired
        if let Some(valid_until) = self.valid_until {
            let now = chrono::Utc::now();
            if now > valid_until {
                return Err(format!("Exchange rate expired at {}", valid_until));
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_nature_opposite() {
        assert_eq!(Nature::Inflow.opposite(), Nature::Outflow);
        assert_eq!(Nature::Outflow.opposite(), Nature::Inflow);
    }

    #[test]
    fn test_nature_from_transaction_type() {
        assert_eq!(
            Nature::from_transaction_type(TransactionType::Income, true),
            Nature::Inflow
        );
        assert_eq!(
            Nature::from_transaction_type(TransactionType::Expense, true),
            Nature::Outflow
        );
        assert_eq!(
            Nature::from_transaction_type(TransactionType::Transfer, true),
            Nature::Outflow
        );
        assert_eq!(
            Nature::from_transaction_type(TransactionType::Transfer, false),
            Nature::Inflow
        );
    }

    #[test]
    fn test_fx_spec_validation() {
        use chrono::Utc;
        use rust_decimal::Decimal;

        let valid_fx = FxSpec {
            rate: Decimal::from_str("1.2").unwrap(),
            source: "test".to_string(),
            obtained_at: Utc::now(),
            valid_until: None,
        };

        assert!(valid_fx.validate().is_ok());

        let invalid_fx = FxSpec {
            rate: Decimal::ZERO,
            source: "test".to_string(),
            obtained_at: Utc::now(),
            valid_until: None,
        };

        assert!(invalid_fx.validate().is_err());
    }
}
