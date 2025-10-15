use chrono::{TimeZone, Utc};
use rust_decimal::Decimal;
use serde_json::Value;

#[test]
fn global_market_stats_decimal_serializes_as_string() {
    use jive_money_api::models::global_market::GlobalMarketStats;

    let stats = GlobalMarketStats {
        total_market_cap_usd: Decimal::new(12_345_000_000, 0),
        total_volume_24h_usd: Decimal::new(987_654_321, 0),
        btc_dominance_percentage: Decimal::new(485, 1), // 48.5
        eth_dominance_percentage: Some(Decimal::new(180, 1)), // 18.0
        active_cryptocurrencies: 1000,
        markets: Some(500),
        updated_at: 1_700_000_000,
    };

    let val: Value = serde_json::to_value(&stats).expect("serialize market stats");
    for key in [
        "total_market_cap_usd",
        "total_volume_24h_usd",
        "btc_dominance_percentage",
    ] {
        assert!(val.get(key).and_then(|v| v.as_str()).is_some(), "{} should be string", key);
    }
    // updated_at is numeric unix timestamp
    assert!(val.get("updated_at").and_then(|v| v.as_i64()).is_some());
    assert!(val
        .get("eth_dominance_percentage")
        .and_then(|v| v.as_str())
        .is_some());
}

#[test]
fn account_response_decimal_serializes_as_string() {
    use jive_money_api::handlers::accounts::AccountResponse;
    use uuid::Uuid;

    let resp = AccountResponse {
        id: Uuid::nil(),
        ledger_id: Uuid::nil(),
        bank_id: None,
        name: "Checking".to_string(),
        account_type: "asset".to_string(),
        account_number: None,
        institution_name: None,
        currency: "USD".to_string(),
        current_balance: Decimal::new(12345, 2),
        available_balance: Some(Decimal::new(12000, 2)),
        credit_limit: None,
        status: "active".to_string(),
        is_manual: true,
        color: None,
        icon: None,
        notes: None,
        created_at: Utc.timestamp_opt(1_700_000_000, 0).unwrap(),
        updated_at: Utc.timestamp_opt(1_700_000_000, 0).unwrap(),
    };

    let val: Value = serde_json::to_value(&resp).expect("serialize account response");
    for key in ["current_balance"] {
        assert!(val.get(key).and_then(|v| v.as_str()).is_some(), "{} should be string", key);
    }
    // Optional Decimal fields should also be strings when present
    assert!(val
        .get("available_balance")
        .and_then(|v| v.as_str())
        .is_some());
}
