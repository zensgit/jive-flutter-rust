#[cfg(test)]
mod tests {
    use chrono::{Duration, Utc};
    use rust_decimal::Decimal;
    use std::str::FromStr;
    use sqlx::Row;

    use jive_money_api::services::currency_service::{
        AddExchangeRateRequest,
        ClearManualRatesBatchRequest,
        CurrencyService,
    };

    use crate::fixtures::create_test_pool;

    async fn read_manual_flags(
        pool: &sqlx::PgPool,
        from: &str,
        to: &str,
    ) -> (bool, Option<chrono::DateTime<Utc>>) {
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
        .fetch_one(pool)
        .await
        .expect("should read manual flags");
        let is_manual: Option<bool> = row.get("is_manual");
        let mre: Option<chrono::DateTime<Utc>> = row.get("manual_rate_expiry");
        (is_manual.unwrap_or(false), mre)
    }

    // Ignored by default: requires TEST_DATABASE_URL and migrations applied.
    #[tokio::test]
    async fn test_batch_clear_only_expired() {
        let pool = create_test_pool().await;
        let service = CurrencyService::new(pool.clone());

        let from = "USD";
        let eur = "EUR"; // expired
        let jpy = "JPY"; // not expired
        let rate = Decimal::from_str("1.2345").unwrap();

        // Seed: EUR expired yesterday, JPY expires in 1 year
        let _ = service.add_exchange_rate(AddExchangeRateRequest {
            from_currency: from.into(),
            to_currency: eur.into(),
            rate,
            source: Some("manual".into()),
            manual_rate_expiry: Some(Utc::now() - Duration::days(1)),
        }).await.expect("add EUR");

        let _ = service.add_exchange_rate(AddExchangeRateRequest {
            from_currency: from.into(),
            to_currency: jpy.into(),
            rate,
            source: Some("manual".into()),
            manual_rate_expiry: Some(Utc::now() + Duration::days(365)),
        }).await.expect("add JPY");

        // Clear only expired
        let affected = service.clear_manual_rates_batch(ClearManualRatesBatchRequest {
            from_currency: from.into(),
            to_currencies: None,
            before_date: None,
            only_expired: Some(true),
        }).await.expect("batch clear only expired");
        assert!(affected >= 1, "should clear at least EUR");

        let (is_manual_eur, mre_eur) = read_manual_flags(&pool, from, eur).await;
        let (is_manual_jpy, mre_jpy) = read_manual_flags(&pool, from, jpy).await;
        assert!(!is_manual_eur && mre_eur.is_none(), "EUR should be cleared");
        assert!(is_manual_jpy && mre_jpy.is_some(), "JPY should remain manual");
    }

    // Ignored: requires DB
    #[tokio::test]
    async fn test_batch_clear_by_date_threshold() {
        let pool = create_test_pool().await;
        let service = CurrencyService::new(pool.clone());

        let from = "USD";
        let gbp = "GBP";
        let rate = Decimal::from_str("1.1111").unwrap();

        let _ = service.add_exchange_rate(AddExchangeRateRequest {
            from_currency: from.into(),
            to_currency: gbp.into(),
            rate,
            source: Some("manual".into()),
            manual_rate_expiry: Some(Utc::now() + Duration::days(10)),
        }).await.expect("add GBP");

        // before_date = yesterday -> no clear
        let affected0 = service.clear_manual_rates_batch(ClearManualRatesBatchRequest {
            from_currency: from.into(),
            to_currencies: None,
            before_date: Some((Utc::now() - Duration::days(1)).date_naive()),
            only_expired: Some(false),
        }).await.expect("batch clear yesterday");
        assert_eq!(affected0, 0, "yesterday should not clear today's row");

        let (is_manual0, mre0) = read_manual_flags(&pool, from, gbp).await;
        assert!(is_manual0 && mre0.is_some());

        // before_date = today -> clear
        let affected1 = service.clear_manual_rates_batch(ClearManualRatesBatchRequest {
            from_currency: from.into(),
            to_currencies: None,
            before_date: Some(Utc::now().date_naive()),
            only_expired: Some(false),
        }).await.expect("batch clear today");
        assert!(affected1 >= 1);

        let (is_manual1, mre1) = read_manual_flags(&pool, from, gbp).await;
        assert!(!is_manual1 && mre1.is_none());
    }

    // Ignored: requires DB
    #[tokio::test]
    async fn test_batch_clear_subset_to_currencies() {
        let pool = create_test_pool().await;
        let service = CurrencyService::new(pool.clone());

        let from = "USD";
        let aud = "AUD";
        let cad = "CAD";
        let rate = Decimal::from_str("0.9876").unwrap();

        for tgt in [aud, cad] {
            let _ = service.add_exchange_rate(AddExchangeRateRequest {
                from_currency: from.into(),
                to_currency: tgt.into(),
                rate,
                source: Some("manual".into()),
                manual_rate_expiry: Some(Utc::now() + Duration::days(90)),
            }).await.expect("add manual");
        }

        // Clear only AUD via subset
        let affected = service.clear_manual_rates_batch(ClearManualRatesBatchRequest {
            from_currency: from.into(),
            to_currencies: Some(vec![aud.into()]),
            before_date: Some(Utc::now().date_naive()),
            only_expired: Some(false),
        }).await.expect("subset clear");
        assert!(affected >= 1);

        let (is_manual_aud, mre_aud) = read_manual_flags(&pool, from, aud).await;
        let (is_manual_cad, mre_cad) = read_manual_flags(&pool, from, cad).await;
        assert!(!is_manual_aud && mre_aud.is_none(), "AUD should be cleared");
        assert!(is_manual_cad && mre_cad.is_some(), "CAD should remain manual");
    }
}
