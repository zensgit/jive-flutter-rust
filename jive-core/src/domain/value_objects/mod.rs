//! Value Objects - 值对象
//!
//! 不可变的领域值对象，确保业务规则和类型安全

pub mod money;

pub use money::{CurrencyCode, Money, MoneyError};
