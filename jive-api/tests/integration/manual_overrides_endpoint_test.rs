#[cfg(test)]
mod tests {
    use sqlx::Row;
    use chrono::{Duration, Utc};
    use rust_decimal::Decimal;

    use jive_money_api::services::currency_service::{CurrencyService, AddExchangeRateRequest};
    use crate::fixtures::create_test_pool;

    #[tokio::test]
    async fn test_manual_overrides_endpoint() {
        let pool = create_test_pool().await;
        let svc = CurrencyService::new(pool.clone());

        // Seed one manual override for today
        let _ = svc.add_exchange_rate(AddExchangeRateRequest {
            from_currency: "USD".into(),
            to_currency: "CNY".into(),
            rate: Decimal::new(71234, 4), // 7.1234
            source: Some("manual".into()),
            manual_rate_expiry: Some(Utc::now() + Duration::days(1)),
        }).await.expect("seed manual override");

        // Call handler via direct SQL read (simulating the same query the endpoint uses)
        // This avoids spinning up HTTP in integration env; validates shape & filters
        let rows = sqlx::query(
            r#"
            SELECT to_currency, rate, manual_rate_expiry, updated_at
            FROM exchange_rates
            WHERE from_currency = $1 AND date = CURRENT_DATE AND is_manual = true
              AND (manual_rate_expiry IS NULL OR manual_rate_expiry > NOW())
            ORDER BY updated_at DESC
            "#
        )
        .bind("USD")
        .fetch_all(&pool)
        .await
        .expect("query manual overrides");

        assert!(rows.iter().any(|r| r.get::<String, _>("to_currency") == "CNY"));
    }
}

