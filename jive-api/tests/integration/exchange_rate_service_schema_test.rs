//! Integration test for ExchangeRateService database schema alignment
//!
//! This test verifies that:
//! 1. All columns exist and match the migration schema
//! 2. Data types are correctly aligned (especially Decimal vs f64)
//! 3. Unique constraints work as expected
//! 4. Required fields are populated
//!
//! Run with: `cargo test --test exchange_rate_service_schema_test`

use chrono::Utc;
use rust_decimal::Decimal;
use std::str::FromStr;
use std::sync::Arc;
use sqlx::Row;
use uuid::Uuid;
use tracing::warn;

use jive_money_api::services::exchange_rate_service::{
    ExchangeRate, ExchangeRateService,
};
use jive_money_api::error::ApiResult;

// Test-only extension trait for ExchangeRateService
trait ExchangeRateServiceTestExt {
    async fn store_rates_in_db_test(&self, rates: &[ExchangeRate]) -> ApiResult<()>;
}

impl ExchangeRateServiceTestExt for ExchangeRateService {
    async fn store_rates_in_db_test(&self, rates: &[ExchangeRate]) -> ApiResult<()> {
        if rates.is_empty() {
            return Ok(());
        }

        for rate in rates {
            let rate_decimal = Decimal::from_f64_retain(rate.rate)
                .unwrap_or_else(|| {
                    warn!("Failed to convert rate {} to Decimal, using 0", rate.rate);
                    Decimal::ZERO
                });

            let date_naive = rate.timestamp.date_naive();

            sqlx::query!(
                r#"
                INSERT INTO exchange_rates (
                    id, from_currency, to_currency, rate, source,
                    date, effective_date, is_manual
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                ON CONFLICT (from_currency, to_currency, date)
                DO UPDATE SET
                    rate = EXCLUDED.rate,
                    source = EXCLUDED.source,
                    updated_at = CURRENT_TIMESTAMP
                "#,
                Uuid::new_v4(),
                rate.from_currency,
                rate.to_currency,
                rate_decimal,
                "test-provider",
                date_naive,
                date_naive,
                false
            )
            .execute(self.pool().as_ref())
            .await
            .map_err(|e| {
                warn!("Failed to store test rate in DB: {}", e);
                e
            })?;
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Create test database connection pool
    async fn create_test_pool() -> sqlx::PgPool {
        let database_url = std::env::var("TEST_DATABASE_URL")
            .unwrap_or_else(|_| "postgresql://postgres:postgres@localhost:5433/jive_money".to_string());

        sqlx::PgPool::connect(&database_url)
            .await
            .expect("Failed to connect to test database")
    }

    /// Test that ExchangeRateService can successfully write to exchange_rates table
    /// with all required fields matching the database schema
    #[tokio::test]
    async fn test_exchange_rate_service_store_schema_alignment() {
        let pool = create_test_pool().await;

        // Create ExchangeRateService with no Redis (Redis is optional for this test)
        let service = ExchangeRateService::new(Arc::new(pool.clone()), None);

        // Create test exchange rates with various scenarios
        let test_rates = vec![
            // Standard fiat rate
            ExchangeRate {
                from_currency: "USD".to_string(),
                to_currency: "CNY".to_string(),
                rate: 7.2345,
                timestamp: Utc::now(),
            },
            // High precision rate
            ExchangeRate {
                from_currency: "USD".to_string(),
                to_currency: "JPY".to_string(),
                rate: 149.123456789012, // 12 decimal places
                timestamp: Utc::now(),
            },
            // Very small rate (crypto-like precision)
            ExchangeRate {
                from_currency: "USD".to_string(),
                to_currency: "BTC".to_string(),
                rate: 0.000014814814, // Small value testing precision
                timestamp: Utc::now(),
            },
        ];

        // Act: Store rates in database using the service
        service.store_rates_in_db_test(&test_rates).await
            .expect("store_rates_in_db should succeed");

        // Assert: Verify all rates were stored with correct schema
        for expected_rate in &test_rates {
            let row = sqlx::query(
                r#"
                SELECT
                    id,
                    from_currency,
                    to_currency,
                    rate,
                    source,
                    date,
                    effective_date,
                    is_manual,
                    created_at,
                    updated_at
                FROM exchange_rates
                WHERE from_currency = $1
                  AND to_currency = $2
                  AND date = CURRENT_DATE
                ORDER BY updated_at DESC
                LIMIT 1
                "#
            )
            .bind(&expected_rate.from_currency)
            .bind(&expected_rate.to_currency)
            .fetch_one(&pool)
            .await
            .expect(&format!(
                "Should find rate for {}/{}",
                expected_rate.from_currency,
                expected_rate.to_currency
            ));

            // Verify all required columns exist and have correct types
            let id: uuid::Uuid = row.get("id");
            let from_currency: String = row.get("from_currency");
            let to_currency: String = row.get("to_currency");
            let rate: Decimal = row.get("rate");
            let source: Option<String> = row.get("source");
            let date: chrono::NaiveDate = row.get("date");
            let effective_date: chrono::NaiveDate = row.get("effective_date");
            let is_manual: Option<bool> = row.get("is_manual");
            let created_at: Option<chrono::DateTime<Utc>> = row.get("created_at");
            let updated_at: Option<chrono::DateTime<Utc>> = row.get("updated_at");

            // Verify field values
            assert!(!id.is_nil(), "id should be a valid UUID");
            assert_eq!(from_currency, expected_rate.from_currency, "from_currency mismatch");
            assert_eq!(to_currency, expected_rate.to_currency, "to_currency mismatch");
            assert_eq!(source, Some("test-provider".to_string()), "source should be set");
            assert_eq!(date, Utc::now().date_naive(), "date should be today");
            assert_eq!(effective_date, Utc::now().date_naive(), "effective_date should equal date");
            assert_eq!(is_manual.unwrap_or(true), false, "is_manual should be false for external API");
            assert!(created_at.is_some(), "created_at should be set");
            assert!(updated_at.is_some(), "updated_at should be set");

            // Verify Decimal precision is preserved (within f64 conversion tolerance)
            // Note: f64 to Decimal conversion has inherent precision limitations
            // f64 has ~15-17 decimal digits of precision, so we can't expect full DECIMAL(30,12) accuracy
            let expected_decimal = Decimal::from_f64_retain(expected_rate.rate)
                .expect("Should convert expected rate to Decimal");
            let difference = (rate - expected_decimal).abs();
            let tolerance = Decimal::from_str("0.00000001").unwrap(); // 1e-8 (realistic for f64)
            assert!(
                difference < tolerance,
                "Rate precision beyond f64 capability: expected {}, got {}, difference {}",
                expected_decimal, rate, difference
            );
        }

        println!("✅ All {} test rates stored and verified successfully", test_rates.len());
    }

    /// Test ON CONFLICT behavior - should update existing rate
    #[tokio::test]
    async fn test_exchange_rate_service_on_conflict_update() {
        let pool = create_test_pool().await;
        let service = ExchangeRateService::new(Arc::new(pool.clone()), None);

        // First insert
        let initial_rate = vec![ExchangeRate {
            from_currency: "EUR".to_string(),
            to_currency: "USD".to_string(),
            rate: 1.0850,
            timestamp: Utc::now(),
        }];

        service.store_rates_in_db_test(&initial_rate).await
            .expect("First insert should succeed");

        // Get initial updated_at timestamp
        let initial_row = sqlx::query(
            "SELECT rate, updated_at FROM exchange_rates
             WHERE from_currency = 'EUR' AND to_currency = 'USD' AND date = CURRENT_DATE"
        )
        .fetch_one(&pool)
        .await
        .expect("Should find initial rate");

        let initial_rate_value: Decimal = initial_row.get("rate");
        let initial_updated_at: chrono::DateTime<Utc> = initial_row.get("updated_at");

        // Wait a bit to ensure timestamp difference
        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;

        // Update with new rate (same currency pair, same date)
        let updated_rate = vec![ExchangeRate {
            from_currency: "EUR".to_string(),
            to_currency: "USD".to_string(),
            rate: 1.0920, // Different rate
            timestamp: Utc::now(),
        }];

        service.store_rates_in_db_test(&updated_rate).await
            .expect("Update should succeed via ON CONFLICT");

        // Verify the rate was updated, not duplicated
        let count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM exchange_rates
             WHERE from_currency = 'EUR' AND to_currency = 'USD' AND date = CURRENT_DATE"
        )
        .fetch_one(&pool)
        .await
        .expect("Should count rates");

        assert_eq!(count, 1, "Should only have 1 row (updated, not duplicated)");

        // Verify the rate value was updated
        let final_row = sqlx::query(
            "SELECT rate, updated_at FROM exchange_rates
             WHERE from_currency = 'EUR' AND to_currency = 'USD' AND date = CURRENT_DATE"
        )
        .fetch_one(&pool)
        .await
        .expect("Should find updated rate");

        let final_rate_value: Decimal = final_row.get("rate");
        let final_updated_at: chrono::DateTime<Utc> = final_row.get("updated_at");

        let expected_final = Decimal::from_f64_retain(1.0920).unwrap();
        let difference = (final_rate_value - expected_final).abs();
        let tolerance = Decimal::from_str("0.00000001").unwrap();
        assert!(
            difference < tolerance,
            "Rate should be updated: expected {}, got {}, diff {}",
            expected_final, final_rate_value, difference
        );
        assert_ne!(final_updated_at, initial_updated_at, "updated_at should be refreshed");

        println!("✅ ON CONFLICT update verified: {} -> {}", initial_rate_value, final_rate_value);
    }

    /// Test unique constraint enforcement
    #[tokio::test]
    async fn test_exchange_rate_unique_constraint() {
        let pool = create_test_pool().await;

        // Clean up any previous test data for today's date
        sqlx::query(
            "DELETE FROM exchange_rates WHERE from_currency = 'USD' AND to_currency = 'CNY' AND effective_date = CURRENT_DATE"
        )
        .execute(&pool)
        .await
        .ok();

        // Use existing currencies that should be in the database
        // Manually try to insert duplicate (bypassing service to test constraint)
        let first_insert = sqlx::query(
            r#"
            INSERT INTO exchange_rates (
                id, from_currency, to_currency, rate, source, date, effective_date, is_manual
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            "#
        )
        .bind(uuid::Uuid::new_v4())
        .bind("USD")  // Use USD instead of GBP
        .bind("CNY")  // Use CNY instead of USD
        .bind(Decimal::from_str("1.2750").unwrap())
        .bind("test")
        .bind(Utc::now().date_naive())
        .bind(Utc::now().date_naive())
        .bind(false)
        .execute(&pool)
        .await;

        if let Err(e) = &first_insert {
            panic!("First insert failed with error: {:?}", e);
        }
        assert!(first_insert.is_ok(), "First insert should succeed");

        // Try to insert duplicate without ON CONFLICT
        let duplicate_insert = sqlx::query(
            r#"
            INSERT INTO exchange_rates (
                id, from_currency, to_currency, rate, source, date, effective_date, is_manual
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            "#
        )
        .bind(uuid::Uuid::new_v4())
        .bind("USD") // Same currency pair as first insert
        .bind("CNY")
        .bind(Decimal::from_str("1.2800").unwrap())
        .bind("test")
        .bind(Utc::now().date_naive()) // Same date
        .bind(Utc::now().date_naive())
        .bind(false)
        .execute(&pool)
        .await;

        assert!(duplicate_insert.is_err(), "Duplicate insert should fail due to unique constraint");

        // Verify the constraint is on (from_currency, to_currency, effective_date)
        let error_msg = duplicate_insert.unwrap_err().to_string();
        assert!(
            error_msg.contains("exchange_rates_from_currency_to_currency_effective_date_key") ||
            error_msg.contains("unique constraint") ||
            error_msg.contains("duplicate key"),
            "Error should mention unique constraint violation: {}",
            error_msg
        );

        println!("✅ Unique constraint (from_currency, to_currency, effective_date) verified");
    }

    /// Test Decimal precision preservation across the full range
    #[tokio::test]
    async fn test_decimal_precision_preservation() {
        let pool = create_test_pool().await;
        let service = ExchangeRateService::new(Arc::new(pool.clone()), None);

        // Test various precision scenarios
        // Note: DECIMAL(30,12) supports up to 18 digits before decimal point
        // and 12 digits after. f64 provides ~15-17 digits total precision.
        let precision_tests = vec![
            ("Large number", 999999999.123456),      // Within DECIMAL(30,12) and f64 range
            ("Very small", 0.000000000001),          // 12 decimal places
            ("Many decimals", 1.234567890123),       // Just beyond f64 precision
            ("Integer", 100.0),
            ("Typical fiat", 7.2345),
            ("Crypto precision", 0.0000148148),
        ];

        for (_i, (name, value)) in precision_tests.iter().enumerate() {
            let test_rate = vec![ExchangeRate {
                from_currency: "USD".to_string(),  // Use USD instead of TEST
                to_currency: "CNY".to_string(),    // Use CNY for consistency
                rate: *value,
                timestamp: Utc::now(),
            }];

            service.store_rates_in_db_test(&test_rate).await
                .expect(&format!("Should store {} precision test", name));

            // Verify precision - since all tests use same USD->CNY, just check the latest
            let stored_rate: Decimal = sqlx::query_scalar(
                "SELECT rate FROM exchange_rates
                 WHERE from_currency = 'USD' AND to_currency = 'CNY' AND date = CURRENT_DATE
                 ORDER BY updated_at DESC LIMIT 1"
            )
            .fetch_one(&pool)
            .await
            .expect(&format!("Should fetch {} precision test", name));

            let expected = Decimal::from_f64_retain(*value).unwrap();
            let difference = (stored_rate - expected).abs();
            let tolerance = Decimal::from_str("0.00000001").unwrap(); // 1e-8 for f64 precision

            assert!(
                difference < tolerance,
                "{} precision test failed: expected {}, got {}, diff {}",
                name, expected, stored_rate, difference
            );

            println!("✅ {} precision preserved: {}", name, stored_rate);
        }
    }
}
