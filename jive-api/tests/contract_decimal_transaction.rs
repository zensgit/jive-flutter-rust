use chrono::{TimeZone, Utc};
use rust_decimal::Decimal;
use serde_json::Value;

#[test]
fn transaction_decimal_amount_serializes_as_string() {
    use jive_money_api::models::transaction::{Transaction, TransactionStatus, TransactionType};
    use uuid::Uuid;

    let tx = Transaction {
        id: Uuid::nil(),
        ledger_id: Uuid::nil(),
        account_id: Uuid::nil(),
        transaction_date: Utc.timestamp_opt(1_700_000_000, 0).unwrap(),
        amount: Decimal::new(12345, 2), // 123.45
        transaction_type: TransactionType::Income,
        category_id: None,
        category_name: Some("Salary".to_string()),
        payee: Some("Company".to_string()),
        notes: None,
        status: TransactionStatus::Cleared,
        related_transaction_id: None,
        created_at: Utc.timestamp_opt(1_700_000_000, 0).unwrap(),
        updated_at: Utc.timestamp_opt(1_700_000_000, 0).unwrap(),
    };

    let val: Value = serde_json::to_value(&tx).expect("serialize transaction");
    assert!(val.get("amount").and_then(|v| v.as_str()).is_some(), "amount should be string");
    assert_eq!(val["amount"].as_str().unwrap(), "123.45");
}

