#[cfg(test)]
mod tests {
    use chrono::{Duration, Utc};
    use rust_decimal::Decimal;
    use std::str::FromStr;
    use sqlx::Row;

    use jive_money_api::services::currency_service::{
        AddExchangeRateRequest,
        CurrencyService,
    };

    use crate::fixtures::create_test_pool;

    // Ignored by default. Enable with `cargo test -- --ignored` and ensure TEST_DATABASE_URL is set and migrated.
    #[tokio::test]
    async fn test_manual_rate_add_and_clear() {
        let pool = create_test_pool().await;
        let service = CurrencyService::new(pool.clone());

        let from = "USD";
        let to = "CNY";
        let rate = Decimal::from_str("7.1234").unwrap();
        let expiry = Utc::now() + Duration::days(365);

        // 1) Add manual rate with expiry (upsert on business date)
        let _ = service
            .add_exchange_rate(AddExchangeRateRequest {
                from_currency: from.to_string(),
                to_currency: to.to_string(),
                rate,
                source: Some("manual".to_string()),
                manual_rate_expiry: Some(expiry),
            })
            .await
            .expect("add_exchange_rate should succeed");

        // 2) Verify manual flags persisted for today
        let row = sqlx::query(
            r#"
            SELECT is_manual, manual_rate_expiry
            FROM exchange_rates
            WHERE from_currency = $1 AND to_currency = $2 AND date = CURRENT_DATE
            ORDER BY updated_at DESC
            LIMIT 1
            "#,
        )
        .bind(from)
        .bind(to)
        .fetch_one(&pool)
        .await
        .expect("should read back the manual rate row");

        let is_manual: Option<bool> = row.get("is_manual");
        let mre: Option<chrono::DateTime<Utc>> = row.get("manual_rate_expiry");
        assert_eq!(is_manual.unwrap_or(false), true, "is_manual should be true after manual add");
        assert!(mre.is_some(), "manual_rate_expiry should be set");

        // 3) Clear manual flag for this pair (today)
        service
            .clear_manual_rate(from, to)
            .await
            .expect("clear_manual_rate should succeed");

        // 4) Verify cleared
        let row2 = sqlx::query(
            r#"
            SELECT is_manual, manual_rate_expiry
            FROM exchange_rates
            WHERE from_currency = $1 AND to_currency = $2 AND date = CURRENT_DATE
            ORDER BY updated_at DESC
            LIMIT 1
            "#,
        )
        .bind(from)
        .bind(to)
        .fetch_one(&pool)
        .await
        .expect("should read back the cleared row");

        let is_manual2: Option<bool> = row2.get("is_manual");
        let mre2: Option<chrono::DateTime<Utc>> = row2.get("manual_rate_expiry");
        assert_eq!(is_manual2.unwrap_or(false), false, "is_manual should be false after clear");
        assert!(mre2.is_none(), "manual_rate_expiry should be NULL after clear");
    }
}
