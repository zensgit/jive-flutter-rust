//! Utility functions for Jive Core

use crate::error::{JiveError, Result};
use chrono::{DateTime, Datelike, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

/// 生成新的 UUID
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub fn generate_id() -> String {
    Uuid::new_v4().to_string()
}

/// 格式化金额为显示字符串
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub fn format_amount(amount: &str, currency: &str) -> String {
    match amount.parse::<Decimal>() {
        Ok(decimal) => {
            // 根据货币添加适当的符号
            let symbol = get_currency_symbol(currency);
            if currency == "JPY" || currency == "KRW" {
                // 这些货币通常不显示小数点
                format!("{}{:.0}", symbol, decimal)
            } else {
                format!("{}{:.2}", symbol, decimal)
            }
        }
        Err(_) => format!("{}0.00", get_currency_symbol(currency)),
    }
}

/// 获取货币符号
fn get_currency_symbol(currency: &str) -> &'static str {
    match currency {
        "USD" | "CAD" | "AUD" | "SGD" | "HKD" => "$",
        "EUR" => "€",
        "GBP" => "£",
        "JPY" => "¥",
        "CNY" => "¥",
        "KRW" => "₩",
        "INR" => "₹",
        "BRL" => "R$",
        "RUB" => "₽",
        "CHF" => "CHF ",
        "SEK" => "kr ",
        "NOK" => "kr ",
        "DKK" => "kr ",
        "ZAR" => "R",
        "TRY" => "₺",
        _ => "",
    }
}

/// 计算两个金额的加法
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub fn add_amounts(amount1: &str, amount2: &str) -> Result<String> {
    let a1 = amount1
        .parse::<Decimal>()
        .map_err(|_| JiveError::InvalidAmount {
            amount: amount1.to_string(),
        })?;
    let a2 = amount2
        .parse::<Decimal>()
        .map_err(|_| JiveError::InvalidAmount {
            amount: amount2.to_string(),
        })?;

    Ok((a1 + a2).to_string())
}

/// 计算两个金额的减法
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub fn subtract_amounts(amount1: &str, amount2: &str) -> Result<String> {
    let a1 = amount1
        .parse::<Decimal>()
        .map_err(|_| JiveError::InvalidAmount {
            amount: amount1.to_string(),
        })?;
    let a2 = amount2
        .parse::<Decimal>()
        .map_err(|_| JiveError::InvalidAmount {
            amount: amount2.to_string(),
        })?;

    Ok((a1 - a2).to_string())
}

/// 计算两个金额的乘法
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub fn multiply_amounts(amount: &str, multiplier: &str) -> Result<String> {
    let a = amount
        .parse::<Decimal>()
        .map_err(|_| JiveError::InvalidAmount {
            amount: amount.to_string(),
        })?;
    let m = multiplier
        .parse::<Decimal>()
        .map_err(|_| JiveError::InvalidAmount {
            amount: multiplier.to_string(),
        })?;

    Ok((a * m).to_string())
}

/// 货币转换器
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CurrencyConverter {
    base_currency: String,
}

#[cfg_attr(feature = "wasm", wasm_bindgen)]
impl CurrencyConverter {
    #[cfg_attr(feature = "wasm", wasm_bindgen(constructor))]
    pub fn new(base_currency: String) -> Self {
        Self { base_currency }
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn convert(&self, amount: &str, from_currency: &str, to_currency: &str) -> Result<String> {
        if from_currency == to_currency {
            return Ok(amount.to_string());
        }

        let decimal_amount = amount
            .parse::<Decimal>()
            .map_err(|_| JiveError::InvalidAmount {
                amount: amount.to_string(),
            })?;

        let rate = self.get_exchange_rate(from_currency, to_currency)?;
        let converted = decimal_amount * rate;

        Ok(converted.to_string())
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn get_supported_currencies(&self) -> Vec<String> {
        vec![
            "USD".to_string(),
            "EUR".to_string(),
            "GBP".to_string(),
            "JPY".to_string(),
            "CNY".to_string(),
            "CAD".to_string(),
            "AUD".to_string(),
            "CHF".to_string(),
            "SEK".to_string(),
            "NOK".to_string(),
            "DKK".to_string(),
            "KRW".to_string(),
            "SGD".to_string(),
            "HKD".to_string(),
            "INR".to_string(),
            "BRL".to_string(),
            "MXN".to_string(),
            "RUB".to_string(),
            "ZAR".to_string(),
            "TRY".to_string(),
        ]
    }

    fn get_exchange_rate(&self, from: &str, to: &str) -> Result<Decimal> {
        // 简化的汇率表，实际应该从外部 API 获取
        let rates = [
            ("USD", "CNY", Decimal::new(720, 2)),    // 7.20
            ("EUR", "CNY", Decimal::new(780, 2)),    // 7.80
            ("GBP", "CNY", Decimal::new(890, 2)),    // 8.90
            ("USD", "EUR", Decimal::new(92, 2)),     // 0.92
            ("USD", "GBP", Decimal::new(80, 2)),     // 0.80
            ("USD", "JPY", Decimal::new(15000, 2)),  // 150.00
            ("USD", "KRW", Decimal::new(133000, 2)), // 1330.00
        ];

        for (from_curr, to_curr, rate) in rates.iter() {
            if from == *from_curr && to == *to_curr {
                return Ok(*rate);
            }
            if from == *to_curr && to == *from_curr {
                return Ok(Decimal::new(1, 0) / rate);
            }
        }

        // 如果没有找到直接汇率，尝试通过 USD 转换
        if from != "USD" && to != "USD" {
            let to_usd = self.get_exchange_rate(from, "USD")?;
            let from_usd = self.get_exchange_rate("USD", to)?;
            return Ok(to_usd * from_usd);
        }

        // 默认返回 1.0
        Ok(Decimal::new(1, 0))
    }
}

/// 日期时间工具
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct DateTimeUtils;

#[cfg_attr(feature = "wasm", wasm_bindgen)]
impl DateTimeUtils {
    /// 获取当前 UTC 时间
    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn now_utc() -> String {
        Utc::now().to_rfc3339()
    }

    /// 解析日期字符串
    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn parse_date(date_str: &str) -> Result<String> {
        let date = NaiveDate::parse_from_str(date_str, "%Y-%m-%d").map_err(|_| {
            JiveError::InvalidDate {
                date: date_str.to_string(),
            }
        })?;
        Ok(date.to_string())
    }

    /// 格式化日期
    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn format_date(date_str: &str, format: &str) -> Result<String> {
        let date = NaiveDate::parse_from_str(date_str, "%Y-%m-%d").map_err(|_| {
            JiveError::InvalidDate {
                date: date_str.to_string(),
            }
        })?;
        Ok(date.format(format).to_string())
    }

    /// 获取月初日期
    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn get_month_start(date_str: &str) -> Result<String> {
        let date = NaiveDate::parse_from_str(date_str, "%Y-%m-%d").map_err(|_| {
            JiveError::InvalidDate {
                date: date_str.to_string(),
            }
        })?;
        let month_start = date.with_day(1).unwrap();
        Ok(month_start.to_string())
    }

    /// 获取月末日期
    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn get_month_end(date_str: &str) -> Result<String> {
        let date = NaiveDate::parse_from_str(date_str, "%Y-%m-%d").map_err(|_| {
            JiveError::InvalidDate {
                date: date_str.to_string(),
            }
        })?;

        let next_month = if date.month() == 12 {
            NaiveDate::from_ymd_opt(date.year() + 1, 1, 1).unwrap()
        } else {
            NaiveDate::from_ymd_opt(date.year(), date.month() + 1, 1).unwrap()
        };

        let month_end = next_month.pred_opt().unwrap();
        Ok(month_end.to_string())
    }
}

/// 数据验证工具
pub struct Validator;

impl Validator {
    /// 验证账户名称
    pub fn validate_account_name(name: &str) -> Result<()> {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Account name cannot be empty".to_string(),
            });
        }
        if trimmed.len() > 100 {
            return Err(JiveError::ValidationError {
                message: "Account name too long (max 100 characters)".to_string(),
            });
        }
        if trimmed.len() < 2 {
            return Err(JiveError::ValidationError {
                message: "Account name too short (min 2 characters)".to_string(),
            });
        }
        Ok(())
    }

    /// 验证交易金额
    pub fn validate_transaction_amount(amount: &str) -> Result<Decimal> {
        let decimal = amount
            .parse::<Decimal>()
            .map_err(|_| JiveError::InvalidAmount {
                amount: amount.to_string(),
            })?;

        if decimal.is_zero() {
            return Err(JiveError::ValidationError {
                message: "Transaction amount cannot be zero".to_string(),
            });
        }

        // 检查金额是否过大
        if decimal.abs() > Decimal::new(999999999999i64, 2) {
            // 9,999,999,999.99
            return Err(JiveError::ValidationError {
                message: "Transaction amount too large".to_string(),
            });
        }

        Ok(decimal)
    }

    /// 验证邮箱地址
    pub fn validate_email(email: &str) -> Result<()> {
        let trimmed = email.trim();
        if trimmed.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Email cannot be empty".to_string(),
            });
        }

        if !trimmed.contains('@') || !trimmed.contains('.') {
            return Err(JiveError::ValidationError {
                message: "Invalid email format".to_string(),
            });
        }

        if trimmed.len() > 254 {
            return Err(JiveError::ValidationError {
                message: "Email too long".to_string(),
            });
        }

        Ok(())
    }

    /// 验证密码强度
    pub fn validate_password(password: &str) -> Result<()> {
        if password.len() < 8 {
            return Err(JiveError::ValidationError {
                message: "Password must be at least 8 characters long".to_string(),
            });
        }

        if password.len() > 128 {
            return Err(JiveError::ValidationError {
                message: "Password too long (max 128 characters)".to_string(),
            });
        }

        let has_upper = password.chars().any(|c| c.is_uppercase());
        let has_lower = password.chars().any(|c| c.is_lowercase());
        let has_digit = password.chars().any(|c| c.is_numeric());

        if !has_upper || !has_lower || !has_digit {
            return Err(JiveError::ValidationError {
                message: "Password must contain uppercase, lowercase, and numbers".to_string(),
            });
        }

        Ok(())
    }

    /// 验证描述字段
    pub fn validate_description(description: &str) -> Result<()> {
        if description.len() > 500 {
            return Err(JiveError::ValidationError {
                message: "Description too long (max 500 characters)".to_string(),
            });
        }
        Ok(())
    }
}

/// 字符串工具
pub struct StringUtils;

impl StringUtils {
    /// 清理和标准化文本
    pub fn clean_text(text: &str) -> String {
        text.trim()
            .chars()
            .filter(|c| !c.is_control() || c.is_whitespace())
            .collect::<String>()
            .split_whitespace()
            .collect::<Vec<_>>()
            .join(" ")
    }

    /// 截断文本并添加省略号
    pub fn truncate(text: &str, max_length: usize) -> String {
        if text.len() <= max_length {
            text.to_string()
        } else {
            format!("{}...", &text[..max_length.saturating_sub(3)])
        }
    }

    /// 生成简短的显示ID（用于UI）
    pub fn short_id(full_id: &str) -> String {
        if full_id.len() > 8 {
            format!("{}...{}", &full_id[..4], &full_id[full_id.len() - 4..])
        } else {
            full_id.to_string()
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_generate_id() {
        let id = generate_id();
        assert!(!id.is_empty());
        assert!(Uuid::parse_str(&id).is_ok());
    }

    #[test]
    fn test_format_amount() {
        assert_eq!(format_amount("100.50", "USD"), "$100.50");
        assert_eq!(format_amount("1000", "JPY"), "¥1000");
        assert_eq!(format_amount("invalid", "USD"), "$0.00");
        assert_eq!(format_amount("100.50", "EUR"), "€100.50");
    }

    #[test]
    fn test_amount_operations() {
        assert_eq!(add_amounts("100", "50").unwrap(), "150");
        assert_eq!(subtract_amounts("100", "50").unwrap(), "50");
        assert_eq!(multiply_amounts("100", "1.5").unwrap(), "150.0");
        assert!(add_amounts("invalid", "50").is_err());
    }

    #[test]
    fn test_currency_converter() {
        let converter = CurrencyConverter::new("CNY".to_string());
        let result = converter.convert("100", "USD", "USD").unwrap();
        assert_eq!(result, "100");

        let currencies = converter.get_supported_currencies();
        assert!(currencies.contains(&"USD".to_string()));
        assert!(currencies.contains(&"EUR".to_string()));
    }

    #[test]
    fn test_datetime_utils() {
        let now = DateTimeUtils::now_utc();
        assert!(!now.is_empty());

        let date = DateTimeUtils::parse_date("2023-12-25").unwrap();
        assert_eq!(date, "2023-12-25");

        let formatted = DateTimeUtils::format_date("2023-12-25", "%B %d, %Y").unwrap();
        assert_eq!(formatted, "December 25, 2023");

        let month_start = DateTimeUtils::get_month_start("2023-12-25").unwrap();
        assert_eq!(month_start, "2023-12-01");

        let month_end = DateTimeUtils::get_month_end("2023-12-25").unwrap();
        assert_eq!(month_end, "2023-12-31");
    }

    #[test]
    fn test_validator() {
        assert!(Validator::validate_account_name("Test Account").is_ok());
        assert!(Validator::validate_account_name("").is_err());
        assert!(Validator::validate_account_name("A").is_err());

        assert!(Validator::validate_transaction_amount("100.50").is_ok());
        assert!(Validator::validate_transaction_amount("0").is_err());
        assert!(Validator::validate_transaction_amount("invalid").is_err());

        assert!(Validator::validate_email("test@example.com").is_ok());
        assert!(Validator::validate_email("invalid").is_err());

        assert!(Validator::validate_password("Password123").is_ok());
        assert!(Validator::validate_password("weak").is_err());
        assert!(Validator::validate_password("PASSWORD123").is_err());

        assert!(Validator::validate_description("Valid description").is_ok());
        assert!(Validator::validate_description(&"x".repeat(501)).is_err());
    }

    #[test]
    fn test_string_utils() {
        assert_eq!(StringUtils::clean_text("  hello   world  "), "hello world");
        assert_eq!(
            StringUtils::truncate("This is a long text", 10),
            "This is..."
        );
        assert_eq!(StringUtils::truncate("Short", 10), "Short");
        assert_eq!(StringUtils::short_id("123456789012345678"), "1234...5678");
        assert_eq!(StringUtils::short_id("12345678"), "12345678");
    }
}
