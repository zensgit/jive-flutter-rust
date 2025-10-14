// tests/split_concurrency_test.rs
// Concurrency safety tests for transaction splitting

use jive_core::error::TransactionSplitError;
use jive_core::infrastructure::repositories::transaction_repository::{
    SplitRequest, TransactionRepository,
};
use rust_decimal::Decimal;
use sqlx::PgPool;
use std::str::FromStr;
use std::sync::Arc;
use std::time::Duration;
use tokio::task::JoinSet;
use uuid::Uuid;

// Test helper functions
async fn setup_test_pool() -> PgPool {
    let database_url =
        std::env::var("TEST_DATABASE_URL").expect("TEST_DATABASE_URL must be set");

    PgPool::connect(&database_url)
        .await
        .expect("Failed to connect to test database")
}

async fn create_test_transaction(pool: &PgPool, amount: Decimal) -> Uuid {
    // Create test family
    let family_id = Uuid::new_v4();
    sqlx::query!(
        r#"
        INSERT INTO families (id, name, created_at, updated_at)
        VALUES ($1, 'Test Family', NOW(), NOW())
        "#,
        family_id
    )
    .execute(pool)
    .await
    .unwrap();

    // Create test account
    let account_id = Uuid::new_v4();
    sqlx::query!(
        r#"
        INSERT INTO accounts (id, family_id, name, balance, currency, created_at, updated_at)
        VALUES ($1, $2, 'Test Account', $3, 'USD', NOW(), NOW())
        "#,
        account_id,
        family_id,
        amount.to_string()
    )
    .execute(pool)
    .await
    .unwrap();

    // Create test transaction
    let transaction_id = Uuid::new_v4();
    let entry_id = Uuid::new_v4();

    sqlx::query!(
        r#"
        INSERT INTO entries (
            id, account_id, entryable_type, entryable_id,
            amount, currency, date, name, nature,
            created_at, updated_at
        )
        VALUES ($1, $2, 'Transaction', $3, $4, 'USD', CURRENT_DATE, 'Test Transaction', 'outflow', NOW(), NOW())
        "#,
        entry_id,
        account_id,
        transaction_id,
        amount.to_string()
    )
    .execute(pool)
    .await
    .unwrap();

    sqlx::query!(
        r#"
        INSERT INTO transactions (
            id, entry_id, kind, created_at, updated_at
        )
        VALUES ($1, $2, 'standard', NOW(), NOW())
        "#,
        transaction_id,
        entry_id
    )
    .execute(pool)
    .await
    .unwrap();

    transaction_id
}

#[tokio::test]
async fn test_concurrent_split_same_transaction() {
    let pool = Arc::new(setup_test_pool().await);
    let repo = Arc::new(TransactionRepository::new(pool.clone()));

    // Create a 100元 transaction
    let transaction_id =
        create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // Create 10 concurrent tasks trying to split the same transaction
    let mut tasks = JoinSet::new();

    for i in 0..10 {
        let repo_clone = repo.clone();
        let tid = transaction_id;

        tasks.spawn(async move {
            let splits = vec![
                SplitRequest {
                    description: Some(format!("并发拆分{}-1", i)),
                    amount: Decimal::from_str("60.00").unwrap(),
                    percentage: None,
                    category_id: None,
                },
                SplitRequest {
                    description: Some(format!("并发拆分{}-2", i)),
                    amount: Decimal::from_str("40.00").unwrap(),
                    percentage: None,
                    category_id: None,
                },
            ];

            repo_clone.split_transaction(tid, splits).await
        });
    }

    // Collect results
    let mut success_count = 0;
    let mut error_count = 0;

    while let Some(result) = tasks.join_next().await {
        match result.unwrap() {
            Ok(_) => success_count += 1,
            Err(TransactionSplitError::AlreadySplit { .. }) => error_count += 1,
            Err(TransactionSplitError::ConcurrencyConflict { .. }) => error_count += 1,
            Err(e) => panic!("Unexpected error: {:?}", e),
        }
    }

    // Only one should succeed, the rest should fail
    assert_eq!(success_count, 1);
    assert_eq!(error_count, 9);

    // Verify database has exactly 2 split records
    let splits = sqlx::query!(
        "SELECT COUNT(*) as count FROM transaction_splits WHERE original_transaction_id = $1",
        transaction_id
    )
    .fetch_one(&*pool)
    .await
    .unwrap();

    assert_eq!(splits.count.unwrap(), 2);
}

#[tokio::test]
async fn test_lock_timeout_with_retry() {
    let pool = Arc::new(setup_test_pool().await);
    let repo = Arc::new(TransactionRepository::new(pool.clone()));

    let transaction_id =
        create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // First task: acquire lock and hold it for a while
    let pool_clone = pool.clone();
    let tid1 = transaction_id;
    let task1 = tokio::spawn(async move {
        let mut tx = pool_clone.begin().await.unwrap();

        // Lock the transaction
        sqlx::query!(
            "SELECT * FROM entries WHERE entryable_id = $1 AND entryable_type = 'Transaction' FOR UPDATE",
            tid1
        )
        .fetch_one(&mut *tx)
        .await
        .unwrap();

        // Hold lock for 2 seconds
        tokio::time::sleep(Duration::from_secs(2)).await;

        tx.commit().await.unwrap();
    });

    // Wait for first task to acquire lock
    tokio::time::sleep(Duration::from_millis(100)).await;

    // Second task: try to split (should trigger retry)
    let splits = vec![
        SplitRequest {
            description: Some("拆分1".to_string()),
            amount: Decimal::from_str("60.00").unwrap(),
            percentage: None,
            category_id: None,
        },
        SplitRequest {
            description: Some("拆分2".to_string()),
            amount: Decimal::from_str("40.00").unwrap(),
            percentage: None,
            category_id: None,
        },
    ];

    let start = std::time::Instant::now();
    let result = repo.split_transaction(transaction_id, splits).await;
    let elapsed = start.elapsed();

    // Should succeed after retry
    assert!(result.is_ok());

    // Due to retry, should take more than 2 seconds
    assert!(elapsed.as_secs() >= 2);

    task1.await.unwrap();
}
