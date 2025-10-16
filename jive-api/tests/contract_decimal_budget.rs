use serde_json::Value;

#[test]
#[ignore = "Budget money fields are still f64; enable after Decimal migration"]
fn budget_progress_and_report_decimal_fields_serialize_as_string() {
    use jive_money_api::services::budget_service::{
        BudgetProgress, BudgetReport, BudgetSummary,
    };

    // Construct a sample BudgetProgress
    let progress = BudgetProgress {
        budget_id: uuid::Uuid::nil(),
        budget_name: "Groceries".to_string(),
        period: "2025-01-01 - 2025-01-31".to_string(),
        budgeted_amount: 1000.0,
        spent_amount: 123.45,
        remaining_amount: 876.55,
        percentage_used: 12.345,
        days_remaining: 10,
        average_daily_spend: 4.0,
        projected_overspend: Some(0.0),
        categories: vec![],
    };

    let val: Value = serde_json::to_value(&progress).expect("serialize BudgetProgress");
    // decimal-like money fields: string per contract; percentage remains numeric
    for key in [
        "budgeted_amount",
        "spent_amount",
        "remaining_amount",
    ] {
        assert!(val.get(key).and_then(|v| v.as_str()).is_some(), "{} should be string", key);
    }
    assert!(val
        .get("percentage_used")
        .and_then(|v| v.as_f64())
        .is_some());

    // Construct a sample BudgetReport
    let report = BudgetReport {
        period: "2025-01".to_string(),
        total_budgeted: 2000.0,
        total_spent: 500.0,
        total_remaining: 1500.0,
        overall_percentage: 25.0,
        budget_summaries: vec![BudgetSummary {
            budget_name: "Groceries".to_string(),
            budgeted: 1000.0,
            spent: 200.0,
            remaining: 800.0,
            percentage: 20.0,
        }],
        unbudgeted_spending: 50.0,
        generated_at: chrono::Utc::now(),
    };

    let val: Value = serde_json::to_value(&report).expect("serialize BudgetReport");
    for key in [
        "total_budgeted",
        "total_spent",
        "total_remaining",
        "unbudgeted_spending",
    ] {
        assert!(val.get(key).and_then(|v| v.as_str()).is_some(), "{} should be string", key);
    }
    assert!(val
        .get("overall_percentage")
        .and_then(|v| v.as_f64())
        .is_some());

    // BudgetSummary list entries should also keep money as string
    let summaries = val
        .get("budget_summaries")
        .and_then(|v| v.as_array())
        .expect("budget_summaries array");
    let first = summaries.first().expect("at least one summary");
    for key in ["budgeted", "spent", "remaining"] {
        assert!(first.get(key).and_then(|v| v.as_str()).is_some(), "{} should be string", key);
    }
    assert!(first
        .get("percentage")
        .and_then(|v| v.as_f64())
        .is_some());
}
