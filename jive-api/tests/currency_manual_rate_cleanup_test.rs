use chrono::{Duration, NaiveDate, Utc};
use jive_api::models::currency::Currency;
use jive_api::models::exchange_rate::ExchangeRate;
use jive_api::services::currency_service::CurrencyService;
use jive_api::test_utils::test_db_pool;
use rust_decimal::Decimal;
use sqlx::{Pool, Postgres};
use uuid::Uuid;

/// Test manual exchange rate cleanup functionality
/// This test ensures that old manual exchange rates are properly cleaned up
/// while preserving recent and necessary rates.
#[tokio::test]
async fn test_manual_rate_cleanup_old_rates() {
    let pool = test_db_pool().await;
    let currency_service = CurrencyService::new(pool.clone());

    // Setup test currencies
    let base_currency = create_test_currency(&pool, "USD", "US Dollar").await;
    let target_currency = create_test_currency(&pool, "EUR", "Euro").await;

    // Create old manual rates (30+ days old)
    let old_date = NaiveDate::from_ymd_opt(2024, 1, 1).unwrap();
    let old_rate = create_manual_exchange_rate(
        &pool,
        &base_currency.id,
        &target_currency.id,
        Decimal::new(85, 2), // 0.85
        old_date,
    ).await;

    // Create recent manual rates (within 30 days)
    let recent_date = (Utc::now().naive_utc().date() - Duration::days(5));
    let recent_rate = create_manual_exchange_rate(
        &pool,
        &base_currency.id,
        &target_currency.id,
        Decimal::new(87, 2), // 0.87
        recent_date,
    ).await;

    // Verify rates exist before cleanup
    let rates_before = get_exchange_rates_count(&pool, &base_currency.id, &target_currency.id).await;
    assert_eq!(rates_before, 2);

    // Perform cleanup (simulate 30-day retention policy)
    let cleanup_result = currency_service.cleanup_old_manual_rates(30).await;
    assert!(cleanup_result.is_ok());

    // Verify old rate is removed, recent rate is preserved
    let rates_after = get_exchange_rates_count(&pool, &base_currency.id, &target_currency.id).await;
    assert_eq!(rates_after, 1);

    // Verify the remaining rate is the recent one
    let remaining_rate = get_latest_exchange_rate(&pool, &base_currency.id, &target_currency.id).await;
    assert!(remaining_rate.is_some());
    assert_eq!(remaining_rate.unwrap().rate, Decimal::new(87, 2));

    println!("✅ Manual rate cleanup test passed - old rates removed, recent rates preserved");
}

/// Test cleanup with rate usage tracking
/// Rates that are actively used in transactions should be preserved
/// even if they are old.
#[tokio::test]
async fn test_manual_rate_cleanup_preserve_used_rates() {
    let pool = test_db_pool().await;
    let currency_service = CurrencyService::new(pool.clone());

    // Setup test currencies
    let base_currency = create_test_currency(&pool, "GBP", "British Pound").await;
    let target_currency = create_test_currency(&pool, "JPY", "Japanese Yen").await;

    // Create old manual rate
    let old_date = NaiveDate::from_ymd_opt(2024, 1, 15).unwrap();
    let used_rate = create_manual_exchange_rate(
        &pool,
        &base_currency.id,
        &target_currency.id,
        Decimal::new(15000, 2), // 150.00
        old_date,
    ).await;

    // Mark this rate as "used" by adding a reference in transactions table
    // (In a real scenario, this would be done through transaction creation)
    mark_exchange_rate_as_used(&pool, &used_rate.id).await;

    // Create unused old rate
    let unused_old_date = NaiveDate::from_ymd_opt(2024, 1, 10).unwrap();
    let _unused_rate = create_manual_exchange_rate(
        &pool,
        &base_currency.id,
        &target_currency.id,
        Decimal::new(14800, 2), // 148.00
        unused_old_date,
    ).await;

    // Verify rates exist before cleanup
    let rates_before = get_exchange_rates_count(&pool, &base_currency.id, &target_currency.id).await;
    assert_eq!(rates_before, 2);

    // Perform cleanup with usage preservation
    let cleanup_result = currency_service.cleanup_old_manual_rates_preserve_used(30).await;
    assert!(cleanup_result.is_ok());

    // Verify unused rate is removed, used rate is preserved
    let rates_after = get_exchange_rates_count(&pool, &base_currency.id, &target_currency.id).await;
    assert_eq!(rates_after, 1);

    // Verify the remaining rate is the used one
    let remaining_rate = get_latest_exchange_rate(&pool, &base_currency.id, &target_currency.id).await;
    assert!(remaining_rate.is_some());
    assert_eq!(remaining_rate.unwrap().rate, Decimal::new(15000, 2));

    println!("✅ Manual rate cleanup test passed - used rates preserved, unused rates removed");
}

/// Test bulk cleanup across multiple currency pairs
#[tokio::test]
async fn test_manual_rate_bulk_cleanup() {
    let pool = test_db_pool().await;
    let currency_service = CurrencyService::new(pool.clone());

    // Create multiple currency pairs
    let usd = create_test_currency(&pool, "USD_BULK", "US Dollar Bulk").await;
    let eur = create_test_currency(&pool, "EUR_BULK", "Euro Bulk").await;
    let gbp = create_test_currency(&pool, "GBP_BULK", "British Pound Bulk").await;

    // Create old rates for multiple pairs
    let old_date = NaiveDate::from_ymd_opt(2024, 1, 1).unwrap();

    // USD -> EUR
    let _old_usd_eur = create_manual_exchange_rate(
        &pool,
        &usd.id,
        &eur.id,
        Decimal::new(85, 2),
        old_date,
    ).await;

    // USD -> GBP
    let _old_usd_gbp = create_manual_exchange_rate(
        &pool,
        &usd.id,
        &gbp.id,
        Decimal::new(78, 2),
        old_date,
    ).await;

    // EUR -> GBP
    let _old_eur_gbp = create_manual_exchange_rate(
        &pool,
        &eur.id,
        &gbp.id,
        Decimal::new(92, 2),
        old_date,
    ).await;

    // Create recent rates
    let recent_date = (Utc::now().naive_utc().date() - Duration::days(5));

    let _recent_usd_eur = create_manual_exchange_rate(
        &pool,
        &usd.id,
        &eur.id,
        Decimal::new(87, 2),
        recent_date,
    ).await;

    // Count total rates before cleanup
    let total_rates_before = get_total_manual_rates_count(&pool).await;
    assert_eq!(total_rates_before, 4);

    // Perform bulk cleanup
    let cleanup_result = currency_service.cleanup_old_manual_rates(30).await;
    assert!(cleanup_result.is_ok());

    // Verify only recent rates remain
    let total_rates_after = get_total_manual_rates_count(&pool).await;
    assert_eq!(total_rates_after, 1);

    println!("✅ Bulk manual rate cleanup test passed - {} old rates removed, {} recent rates preserved",
             total_rates_before - total_rates_after, total_rates_after);
}

/// Test cleanup with audit logging
#[tokio::test]
async fn test_manual_rate_cleanup_with_audit() {
    let pool = test_db_pool().await;
    let currency_service = CurrencyService::new(pool.clone());

    // Create test currencies
    let base_currency = create_test_currency(&pool, "AUD", "Australian Dollar").await;
    let target_currency = create_test_currency(&pool, "CAD", "Canadian Dollar").await;

    // Create old manual rate
    let old_date = NaiveDate::from_ymd_opt(2024, 1, 1).unwrap();
    let old_rate = create_manual_exchange_rate(
        &pool,
        &base_currency.id,
        &target_currency.id,
        Decimal::new(92, 2),
        old_date,
    ).await;

    // Perform cleanup with audit logging
    let cleanup_result = currency_service.cleanup_old_manual_rates_with_audit(30, Some(Uuid::new_v4())).await;
    assert!(cleanup_result.is_ok());

    // Verify rate is removed
    let rates_after = get_exchange_rates_count(&pool, &base_currency.id, &target_currency.id).await;
    assert_eq!(rates_after, 0);

    // Verify audit log entry exists
    let audit_count = get_cleanup_audit_count(&pool).await;
    assert!(audit_count > 0);

    println!("✅ Manual rate cleanup with audit test passed - cleanup logged");
}

/// Test cleanup edge cases
#[tokio::test]
async fn test_manual_rate_cleanup_edge_cases() {
    let pool = test_db_pool().await;
    let currency_service = CurrencyService::new(pool.clone());

    // Test cleanup with no rates
    let cleanup_result = currency_service.cleanup_old_manual_rates(30).await;
    assert!(cleanup_result.is_ok());

    // Test cleanup with zero retention days (should remove all manual rates)
    let base_currency = create_test_currency(&pool, "TEST1", "Test Currency 1").await;
    let target_currency = create_test_currency(&pool, "TEST2", "Test Currency 2").await;

    let today = Utc::now().naive_utc().date();
    let _rate = create_manual_exchange_rate(
        &pool,
        &base_currency.id,
        &target_currency.id,
        Decimal::new(100, 2),
        today,
    ).await;

    let cleanup_result = currency_service.cleanup_old_manual_rates(0).await;
    assert!(cleanup_result.is_ok());

    let rates_after = get_exchange_rates_count(&pool, &base_currency.id, &target_currency.id).await;
    assert_eq!(rates_after, 0);

    println!("✅ Manual rate cleanup edge cases test passed");
}

// Helper functions

async fn create_test_currency(pool: &Pool<Postgres>, code: &str, name: &str) -> Currency {
    let currency = Currency {
        id: Uuid::new_v4(),
        code: code.to_string(),
        name: name.to_string(),
        symbol: "$".to_string(),
        decimal_places: 2,
        is_active: true,
        created_at: Utc::now().naive_utc(),
        updated_at: Utc::now().naive_utc(),
    };

    sqlx::query!(
        r#"
        INSERT INTO currencies (id, code, name, symbol, decimal_places, is_active, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        "#,
        currency.id,
        currency.code,
        currency.name,
        currency.symbol,
        currency.decimal_places,
        currency.is_active,
        currency.created_at,
        currency.updated_at
    )
    .execute(pool)
    .await
    .expect("Failed to create test currency");

    currency
}

async fn create_manual_exchange_rate(
    pool: &Pool<Postgres>,
    from_currency_id: &Uuid,
    to_currency_id: &Uuid,
    rate: Decimal,
    date: NaiveDate,
) -> ExchangeRate {
    let exchange_rate = ExchangeRate {
        id: Uuid::new_v4(),
        from_currency_id: *from_currency_id,
        to_currency_id: *to_currency_id,
        rate,
        date,
        source: "manual".to_string(),
        created_at: Utc::now().naive_utc(),
        updated_at: Utc::now().naive_utc(),
    };

    sqlx::query!(
        r#"
        INSERT INTO exchange_rates (id, from_currency_id, to_currency_id, rate, date, source, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        "#,
        exchange_rate.id,
        exchange_rate.from_currency_id,
        exchange_rate.to_currency_id,
        exchange_rate.rate,
        exchange_rate.date,
        exchange_rate.source,
        exchange_rate.created_at,
        exchange_rate.updated_at
    )
    .execute(pool)
    .await
    .expect("Failed to create manual exchange rate");

    exchange_rate
}

async fn get_exchange_rates_count(
    pool: &Pool<Postgres>,
    from_currency_id: &Uuid,
    to_currency_id: &Uuid,
) -> i64 {
    sqlx::query_scalar!(
        "SELECT COUNT(*) FROM exchange_rates WHERE from_currency_id = $1 AND to_currency_id = $2",
        from_currency_id,
        to_currency_id
    )
    .fetch_one(pool)
    .await
    .expect("Failed to get exchange rates count")
    .unwrap_or(0)
}

async fn get_total_manual_rates_count(pool: &Pool<Postgres>) -> i64 {
    sqlx::query_scalar!(
        "SELECT COUNT(*) FROM exchange_rates WHERE source = 'manual'"
    )
    .fetch_one(pool)
    .await
    .expect("Failed to get total manual rates count")
    .unwrap_or(0)
}

async fn get_latest_exchange_rate(
    pool: &Pool<Postgres>,
    from_currency_id: &Uuid,
    to_currency_id: &Uuid,
) -> Option<ExchangeRate> {
    sqlx::query_as!(
        ExchangeRate,
        r#"
        SELECT id, from_currency_id, to_currency_id, rate, date, source, created_at, updated_at
        FROM exchange_rates
        WHERE from_currency_id = $1 AND to_currency_id = $2
        ORDER BY date DESC, created_at DESC
        LIMIT 1
        "#,
        from_currency_id,
        to_currency_id
    )
    .fetch_optional(pool)
    .await
    .expect("Failed to get latest exchange rate")
}

async fn mark_exchange_rate_as_used(pool: &Pool<Postgres>, rate_id: &Uuid) {
    // Simulate marking a rate as used by creating a reference
    // In a real system, this would be done through transaction creation
    sqlx::query!(
        r#"
        INSERT INTO exchange_rate_usage (id, exchange_rate_id, used_at)
        VALUES ($1, $2, $3)
        ON CONFLICT DO NOTHING
        "#,
        Uuid::new_v4(),
        rate_id,
        Utc::now().naive_utc()
    )
    .execute(pool)
    .await
    .ok(); // Ignore if table doesn't exist in test
}

async fn get_cleanup_audit_count(pool: &Pool<Postgres>) -> i64 {
    sqlx::query_scalar!(
        "SELECT COUNT(*) FROM family_audit_logs WHERE action = 'CLEANUP' AND entity_type = 'exchange_rate'"
    )
    .fetch_one(pool)
    .await
    .unwrap_or(Ok(0))
    .unwrap_or(0)
}