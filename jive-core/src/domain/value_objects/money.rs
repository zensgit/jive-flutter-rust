/// Money value object - ensures type-safe currency operations
///
/// This module provides a type-safe representation of monetary values with
/// currency awareness. It prevents common errors like adding amounts in
/// different currencies and ensures precision is maintained according to
/// currency rules.
///
/// # Examples
///
/// ```
/// use jive_core::domain::value_objects::money::{Money, CurrencyCode};
/// use rust_decimal::Decimal;
/// use std::str::FromStr;
///
/// let usd_10 = Money::new(Decimal::from_str("10.00").unwrap(), CurrencyCode::USD).unwrap();
/// let usd_20 = Money::new(Decimal::from_str("20.00").unwrap(), CurrencyCode::USD).unwrap();
///
/// let total = usd_10.add(&usd_20).unwrap();
/// assert_eq!(total.amount, Decimal::from_str("30.00").unwrap());
/// ```

use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::fmt;
use std::str::FromStr;

/// Supported currency codes following ISO 4217
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum CurrencyCode {
    /// US Dollar
    USD,
    /// Chinese Yuan
    CNY,
    /// Euro
    EUR,
    /// British Pound
    GBP,
    /// Japanese Yen
    JPY,
    /// Hong Kong Dollar
    HKD,
    /// Singapore Dollar
    SGD,
    /// Australian Dollar
    AUD,
    /// Canadian Dollar
    CAD,
    /// Swiss Franc
    CHF,
}

impl CurrencyCode {
    /// Returns the standard number of decimal places for this currency
    ///
    /// Most currencies use 2 decimal places, but some (like JPY) use 0.
    pub fn decimal_places(&self) -> u32 {
        match self {
            Self::JPY => 0, // Japanese Yen has no fractional units
            Self::USD | Self::CNY | Self::EUR | Self::GBP | Self::HKD | Self::SGD
            | Self::AUD | Self::CAD | Self::CHF => 2,
        }
    }

    /// Returns the currency symbol
    pub fn symbol(&self) -> &'static str {
        match self {
            Self::USD => "$",
            Self::CNY => "¥",
            Self::EUR => "€",
            Self::GBP => "£",
            Self::JPY => "¥",
            Self::HKD => "HK$",
            Self::SGD => "S$",
            Self::AUD => "A$",
            Self::CAD => "C$",
            Self::CHF => "CHF",
        }
    }

    /// Returns the ISO 4217 code
    pub fn code(&self) -> &'static str {
        match self {
            Self::USD => "USD",
            Self::CNY => "CNY",
            Self::EUR => "EUR",
            Self::GBP => "GBP",
            Self::JPY => "JPY",
            Self::HKD => "HKD",
            Self::SGD => "SGD",
            Self::AUD => "AUD",
            Self::CAD => "CAD",
            Self::CHF => "CHF",
        }
    }
}

impl FromStr for CurrencyCode {
    type Err = MoneyError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_uppercase().as_str() {
            "USD" => Ok(Self::USD),
            "CNY" | "RMB" => Ok(Self::CNY),
            "EUR" => Ok(Self::EUR),
            "GBP" => Ok(Self::GBP),
            "JPY" => Ok(Self::JPY),
            "HKD" => Ok(Self::HKD),
            "SGD" => Ok(Self::SGD),
            "AUD" => Ok(Self::AUD),
            "CAD" => Ok(Self::CAD),
            "CHF" => Ok(Self::CHF),
            _ => Err(MoneyError::UnsupportedCurrency(s.to_string())),
        }
    }
}

impl fmt::Display for CurrencyCode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.code())
    }
}

/// Money value object containing amount and currency
///
/// This type ensures that:
/// - Amounts have the correct precision for their currency
/// - Currency arithmetic is type-safe (can't add USD and CNY)
/// - Decimal precision is maintained throughout calculations
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Money {
    /// The amount in the currency's standard units
    pub amount: Decimal,
    /// The currency of this amount
    pub currency: CurrencyCode,
}

impl Money {
    /// Creates a new Money instance with validation
    ///
    /// # Errors
    ///
    /// Returns `MoneyError::InvalidPrecision` if the amount has more decimal
    /// places than the currency allows.
    ///
    /// # Examples
    ///
    /// ```
    /// use jive_core::domain::value_objects::money::{Money, CurrencyCode};
    /// use rust_decimal::Decimal;
    /// use std::str::FromStr;
    ///
    /// // Valid: USD with 2 decimal places
    /// let money = Money::new(Decimal::from_str("10.99").unwrap(), CurrencyCode::USD).unwrap();
    ///
    /// // Invalid: USD with 3 decimal places
    /// let result = Money::new(Decimal::from_str("10.999").unwrap(), CurrencyCode::USD);
    /// assert!(result.is_err());
    /// ```
    pub fn new(amount: Decimal, currency: CurrencyCode) -> Result<Self, MoneyError> {
        // Validate precision
        if amount.scale() > currency.decimal_places() {
            return Err(MoneyError::InvalidPrecision {
                amount: amount.to_string(),
                currency,
                expected_scale: currency.decimal_places(),
                actual_scale: amount.scale(),
            });
        }

        Ok(Self { amount, currency })
    }

    /// Creates a new Money instance, rounding to the currency's precision
    ///
    /// This is safer than `new()` when dealing with calculated values that
    /// might have extra precision.
    pub fn new_rounded(amount: Decimal, currency: CurrencyCode) -> Self {
        let rounded = amount.round_dp(currency.decimal_places());
        Self {
            amount: rounded,
            currency,
        }
    }

    /// Creates a Money instance with zero amount
    pub fn zero(currency: CurrencyCode) -> Self {
        Self {
            amount: Decimal::ZERO,
            currency,
        }
    }

    /// Adds two Money values
    ///
    /// # Errors
    ///
    /// Returns `MoneyError::CurrencyMismatch` if currencies don't match.
    pub fn add(&self, other: &Self) -> Result<Self, MoneyError> {
        if self.currency != other.currency {
            return Err(MoneyError::CurrencyMismatch {
                expected: self.currency,
                actual: other.currency,
            });
        }

        Ok(Self {
            amount: self.amount + other.amount,
            currency: self.currency,
        })
    }

    /// Subtracts two Money values
    ///
    /// # Errors
    ///
    /// Returns `MoneyError::CurrencyMismatch` if currencies don't match.
    pub fn subtract(&self, other: &Self) -> Result<Self, MoneyError> {
        if self.currency != other.currency {
            return Err(MoneyError::CurrencyMismatch {
                expected: self.currency,
                actual: other.currency,
            });
        }

        Ok(Self {
            amount: self.amount - other.amount,
            currency: self.currency,
        })
    }

    /// Returns the negation of this Money value
    pub fn negate(&self) -> Self {
        Self {
            amount: -self.amount,
            currency: self.currency,
        }
    }

    /// Multiplies the amount by a factor
    pub fn multiply(&self, factor: Decimal) -> Self {
        Self::new_rounded(self.amount * factor, self.currency)
    }

    /// Divides the amount by a divisor
    ///
    /// # Errors
    ///
    /// Returns `MoneyError::DivisionByZero` if divisor is zero.
    pub fn divide(&self, divisor: Decimal) -> Result<Self, MoneyError> {
        if divisor.is_zero() {
            return Err(MoneyError::DivisionByZero);
        }

        Ok(Self::new_rounded(self.amount / divisor, self.currency))
    }

    /// Returns the absolute value
    pub fn abs(&self) -> Self {
        Self {
            amount: self.amount.abs(),
            currency: self.currency,
        }
    }

    /// Checks if the amount is zero
    pub fn is_zero(&self) -> bool {
        self.amount.is_zero()
    }

    /// Checks if the amount is positive
    pub fn is_positive(&self) -> bool {
        self.amount > Decimal::ZERO
    }

    /// Checks if the amount is negative
    pub fn is_negative(&self) -> bool {
        self.amount < Decimal::ZERO
    }

    /// Rounds to the currency's standard decimal places
    pub fn round(&self) -> Self {
        Self::new_rounded(self.amount, self.currency)
    }

    /// Formats the money as a string with currency symbol
    pub fn format(&self) -> String {
        format!("{}{}", self.currency.symbol(), self.amount)
    }

    /// Converts to a string suitable for database storage
    pub fn to_db_string(&self) -> String {
        self.amount.to_string()
    }
}

impl fmt::Display for Money {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{} {}", self.amount, self.currency.code())
    }
}

/// Errors that can occur when working with Money
#[derive(Debug, thiserror::Error)]
pub enum MoneyError {
    #[error("Currency mismatch: expected {expected}, got {actual}")]
    CurrencyMismatch {
        expected: CurrencyCode,
        actual: CurrencyCode,
    },

    #[error("Invalid precision for {currency}: amount {amount} has {actual_scale} decimal places, but {expected_scale} are allowed")]
    InvalidPrecision {
        amount: String,
        currency: CurrencyCode,
        expected_scale: u32,
        actual_scale: u32,
    },

    #[error("Division by zero")]
    DivisionByZero,

    #[error("Unsupported currency: {0}")]
    UnsupportedCurrency(String),

    #[error("Invalid amount format: {0}")]
    InvalidFormat(String),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_money_creation() {
        let money = Money::new(Decimal::from_str("10.99").unwrap(), CurrencyCode::USD).unwrap();
        assert_eq!(money.amount, Decimal::from_str("10.99").unwrap());
        assert_eq!(money.currency, CurrencyCode::USD);
    }

    #[test]
    fn test_invalid_precision() {
        let result = Money::new(Decimal::from_str("10.999").unwrap(), CurrencyCode::USD);
        assert!(matches!(result, Err(MoneyError::InvalidPrecision { .. })));
    }

    #[test]
    fn test_money_addition() {
        let m1 = Money::new(Decimal::from_str("10.00").unwrap(), CurrencyCode::USD).unwrap();
        let m2 = Money::new(Decimal::from_str("20.00").unwrap(), CurrencyCode::USD).unwrap();

        let result = m1.add(&m2).unwrap();
        assert_eq!(result.amount, Decimal::from_str("30.00").unwrap());
    }

    #[test]
    fn test_currency_mismatch() {
        let m1 = Money::new(Decimal::from_str("10.00").unwrap(), CurrencyCode::USD).unwrap();
        let m2 = Money::new(Decimal::from_str("20.00").unwrap(), CurrencyCode::CNY).unwrap();

        let result = m1.add(&m2);
        assert!(matches!(result, Err(MoneyError::CurrencyMismatch { .. })));
    }

    #[test]
    fn test_decimal_precision_maintained() {
        // Classic floating point issue: 0.1 + 0.2 should equal 0.3
        let m1 = Money::new(Decimal::from_str("0.1").unwrap(), CurrencyCode::USD).unwrap();
        let m2 = Money::new(Decimal::from_str("0.2").unwrap(), CurrencyCode::USD).unwrap();

        let result = m1.add(&m2).unwrap();
        assert_eq!(result.amount, Decimal::from_str("0.3").unwrap());

        // This would fail with f64:
        // assert_eq!(0.1_f64 + 0.2_f64, 0.3_f64); // false!
    }

    #[test]
    fn test_jpy_no_decimal_places() {
        let jpy = Money::new(Decimal::from(1000), CurrencyCode::JPY).unwrap();
        assert_eq!(jpy.amount, Decimal::from(1000));

        // JPY shouldn't allow decimal places
        let result = Money::new(Decimal::from_str("1000.5").unwrap(), CurrencyCode::JPY);
        assert!(result.is_err());
    }

    #[test]
    fn test_money_negation() {
        let money = Money::new(Decimal::from_str("10.00").unwrap(), CurrencyCode::USD).unwrap();
        let negated = money.negate();
        assert_eq!(negated.amount, Decimal::from_str("-10.00").unwrap());
    }

    #[test]
    fn test_money_rounding() {
        let money = Money::new_rounded(
            Decimal::from_str("10.999").unwrap(),
            CurrencyCode::USD,
        );
        assert_eq!(money.amount, Decimal::from_str("11.00").unwrap());
    }
}
