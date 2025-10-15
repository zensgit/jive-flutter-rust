use chrono::{TimeZone, Utc};
use rust_decimal::Decimal;
use serde_json::{json, Value};

#[test]
fn transaction_amount_serializes_as_string() {
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
    // amount should be a JSON string to avoid JS float issues
    assert!(val.get("amount").and_then(|v| v.as_str()).is_some());
    assert_eq!(val["amount"].as_str().unwrap(), "123.45");
}

#[test]
fn budget_report_amounts_serialize_as_string() {
    use jive_money_api::services::budget_service::{BudgetReport, BudgetSummary};

    let report = BudgetReport {
        period: "2025-10-01 - 2025-10-31".to_string(),
        total_budgeted: Decimal::new(100000, 2), // 1000.00
        total_spent: Decimal::new(12345, 2),     // 123.45
        total_remaining: Decimal::new(87655, 2), // 876.55
        overall_percentage: 12.345,
        budget_summaries: vec![BudgetSummary {
            budget_name: "Food".to_string(),
            budgeted: Decimal::new(50000, 2),
            spent: Decimal::new(1200, 2),
            remaining: Decimal::new(48800, 2),
            percentage: 2.4,
        }],
        unbudgeted_spending: Decimal::new(0, 0),
        generated_at: Utc.timestamp_opt(1_700_000_000, 0).unwrap(),
    };

    let val: Value = serde_json::to_value(&report).expect("serialize budget report");
    for key in [
        "total_budgeted",
        "total_spent",
        "total_remaining",
        "unbudgeted_spending",
    ] {
        assert!(val.get(key).and_then(|v| v.as_str()).is_some(), "{} should be string", key);
    }

    let first = &val["budget_summaries"][0];
    for key in ["budgeted", "spent", "remaining"] {
        assert!(first.get(key).and_then(|v| v.as_str()).is_some(), "summary {} string", key);
    }
}
