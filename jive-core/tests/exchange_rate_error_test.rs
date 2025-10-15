//! 测试汇率获取失败时的错误处理
//!
//! 验证修复: 当汇率不在硬编码表中时,应该返回 ExchangeRateNotFound 错误,
//! 而不是返回默认值 1.0 误导用户。

use jive_core::error::JiveError;
use jive_core::utils::CurrencyConverter;

#[test]
fn test_exchange_rate_not_found_returns_error() {
    let converter = CurrencyConverter::new("CNY".to_string());

    // 测试不存在的货币对
    let result = converter.convert("100", "XYZ", "ABC");

    // 应该返回错误,而不是使用1.0作为汇率
    assert!(result.is_err(), "应该返回错误而非默认值1.0");

    // 检查错误类型是否正确
    match result {
        Err(JiveError::ExchangeRateNotFound {
            from_currency,
            to_currency,
        }) => {
            assert_eq!(from_currency, "XYZ");
            assert_eq!(to_currency, "ABC");
        }
        _ => panic!("错误类型不正确,应该是 ExchangeRateNotFound"),
    }
}

#[test]
fn test_exchange_rate_not_found_single_unknown_currency() {
    let converter = CurrencyConverter::new("CNY".to_string());

    // 测试:已知货币 -> 未知货币
    let result = converter.convert("100", "USD", "XYZ");
    assert!(result.is_err(), "USD->XYZ 应该返回错误");

    match result {
        Err(JiveError::ExchangeRateNotFound {
            from_currency,
            to_currency,
        }) => {
            assert_eq!(from_currency, "USD");
            assert_eq!(to_currency, "XYZ");
        }
        _ => panic!("错误类型不正确"),
    }

    // 测试:未知货币 -> 已知货币
    let result = converter.convert("100", "XYZ", "USD");
    assert!(result.is_err(), "XYZ->USD 应该返回错误");

    match result {
        Err(JiveError::ExchangeRateNotFound { .. }) => {
            // 正确
        }
        _ => panic!("错误类型不正确"),
    }
}

#[test]
fn test_exchange_rate_found_returns_ok() {
    let converter = CurrencyConverter::new("CNY".to_string());

    // 测试存在的货币对 (硬编码表中有 USD -> CNY)
    let result = converter.convert("100", "USD", "CNY");
    assert!(result.is_ok(), "USD->CNY 应该成功");

    let converted = result.unwrap();
    // 汇率是 7.20, 所以 100 USD = 720 CNY
    assert_eq!(converted, "720.00", "汇率计算不正确");
}

#[test]
fn test_exchange_rate_same_currency_returns_identity() {
    let converter = CurrencyConverter::new("CNY".to_string());

    // 相同货币转换应该返回原值
    let result = converter.convert("100", "USD", "USD");
    assert!(result.is_ok());
    assert_eq!(result.unwrap(), "100");
}

#[test]
fn test_exchange_rate_via_usd_intermediate() {
    let converter = CurrencyConverter::new("CNY".to_string());

    // 测试 EUR -> GBP 通过 USD 中转
    // EUR -> USD: 1/0.92 ≈ 1.087
    // USD -> GBP: 0.80
    // EUR -> GBP: 1.087 * 0.80 ≈ 0.87
    let result = converter.convert("100", "EUR", "GBP");

    // 这个应该成功,因为表中有 EUR->USD 和 USD->GBP
    assert!(result.is_ok(), "EUR->GBP 应该通过 USD 中转成功");
}

#[test]
fn test_exchange_rate_reverse_lookup() {
    let converter = CurrencyConverter::new("CNY".to_string());

    // 测试反向汇率 (表中有 USD->CNY 7.20, 所以 CNY->USD 应该是 1/7.20)
    let result = converter.convert("720", "CNY", "USD");
    assert!(result.is_ok(), "CNY->USD 应该通过反向汇率成功");

    let converted = result.unwrap();
    // 720 CNY = 100 USD (因为汇率是 1/7.20)
    assert_eq!(converted, "100.00", "反向汇率计算不正确");
}

#[test]
fn test_error_message_contains_currency_pair() {
    let converter = CurrencyConverter::new("CNY".to_string());

    let result = converter.convert("100", "ABC", "XYZ");

    match result {
        Err(e) => {
            let error_msg = e.to_string();
            assert!(error_msg.contains("ABC"), "错误信息应包含源货币");
            assert!(error_msg.contains("XYZ"), "错误信息应包含目标货币");
            assert!(
                error_msg.contains("Exchange rate not found"),
                "错误信息应说明汇率未找到"
            );
        }
        Ok(_) => panic!("应该返回错误"),
    }
}
