// tests/split_transaction_test.rs
// Basic functional tests for transaction splitting

use jive_core::error::TransactionSplitError;
use jive_core::infrastructure::repositories::transaction_repository::{
    SplitRequest, TransactionRepository,
};
use rust_decimal::Decimal;
use sqlx::PgPool;
use std::str::FromStr;
use std::sync::Arc;
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
    // Create test account
    let account_id = Uuid::new_v4();
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
async fn test_split_exceeds_original_should_fail() {
    let pool = setup_test_pool().await;
    let repo = TransactionRepository::new(Arc::new(pool.clone()));

    // Create 100元 transaction
    let transaction_id =
        create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // Try to split into 150元 (80 + 70)
    let splits = vec![
        SplitRequest {
            description: Some("拆分1".to_string()),
            amount: Decimal::from_str("80.00").unwrap(),
            percentage: None,
            category_id: None,
        },
        SplitRequest {
            description: Some("拆分2".to_string()),
            amount: Decimal::from_str("70.00").unwrap(),
            percentage: None,
            category_id: None,
        },
    ];

    let result = repo.split_transaction(transaction_id, splits).await;

    // Should fail
    assert!(result.is_err());

    // Check error type
    match result.unwrap_err() {
        TransactionSplitError::ExceedsOriginal {
            original,
            requested,
            excess,
        } => {
            assert_eq!(original, "100.00");
            assert_eq!(requested, "150.00");
            assert_eq!(excess, "50.00");
        }
        e => panic!("Wrong error type: {:?}", e),
    }
}

#[tokio::test]
async fn test_valid_complete_split_should_succeed() {
    let pool = setup_test_pool().await;
    let repo = TransactionRepository::new(Arc::new(pool.clone()));

    // Create 100元 transaction
    let transaction_id =
        create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // Split into 100元 (60 + 40)
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

    let result = repo.split_transaction(transaction_id, splits).await;

    // Should succeed
    assert!(result.is_ok());
    let created_splits = result.unwrap();
    assert_eq!(created_splits.len(), 2);

    // Verify original transaction is soft deleted
    let original_entry = sqlx::query!(
        r#"
        SELECT deleted_at
        FROM entries
        WHERE entryable_id = $1 AND entryable_type = 'Transaction'
        "#,
        transaction_id
    )
    .fetch_one(&pool)
    .await
    .unwrap();

    assert!(original_entry.deleted_at.is_some());

    // Verify new transactions created successfully
    for split in &created_splits {
        let split_entry = sqlx::query!(
            r#"
            SELECT amount
            FROM entries
            WHERE entryable_id = $1 AND entryable_type = 'Transaction'
            "#,
            split.split_transaction_id
        )
        .fetch_one(&pool)
        .await
        .unwrap();

        let amount = Decimal::from_str(&split_entry.amount).unwrap();
        assert_eq!(amount, split.amount);
    }
}

#[tokio::test]
async fn test_valid_partial_split_should_preserve_remainder() {
    let pool = setup_test_pool().await;
    let repo = TransactionRepository::new(Arc::new(pool.clone()));

    // Create 100元 transaction
    let transaction_id =
        create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // Partial split: 30 + 50 = 80, keep 20
    let splits = vec![
        SplitRequest {
            description: Some("拆分1".to_string()),
            amount: Decimal::from_str("30.00").unwrap(),
            percentage: None,
            category_id: None,
        },
        SplitRequest {
            description: Some("拆分2".to_string()),
            amount: Decimal::from_str("50.00").unwrap(),
            percentage: None,
            category_id: None,
        },
    ];

    let result = repo.split_transaction(transaction_id, splits).await;

    // Should succeed
    assert!(result.is_ok());

    // Verify original transaction keeps 20元
    let original_entry = sqlx::query!(
        r#"
        SELECT amount, deleted_at
        FROM entries
        WHERE entryable_id = $1 AND entryable_type = 'Transaction'
        "#,
        transaction_id
    )
    .fetch_one(&pool)
    .await
    .unwrap();

    assert!(original_entry.deleted_at.is_none());
    let remaining = Decimal::from_str(&original_entry.amount).unwrap();
    assert_eq!(remaining, Decimal::from_str("20.00").unwrap());
}

#[tokio::test]
async fn test_negative_amount_should_fail() {
    let pool = setup_test_pool().await;
    let repo = TransactionRepository::new(Arc::new(pool.clone()));

    let transaction_id =
        create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // Contains negative amount
    let splits = vec![
        SplitRequest {
            description: Some("拆分1".to_string()),
            amount: Decimal::from_str("60.00").unwrap(),
            percentage: None,
            category_id: None,
        },
        SplitRequest {
            description: Some("拆分2".to_string()),
            amount: Decimal::from_str("-10.00").unwrap(),
            percentage: None,
            category_id: None,
        },
    ];

    let result = repo.split_transaction(transaction_id, splits).await;

    // Should fail
    assert!(result.is_err());
    match result.unwrap_err() {
        TransactionSplitError::InvalidAmount {
            amount,
            split_index,
        } => {
            assert_eq!(amount, "-10.00");
            assert_eq!(split_index, 1);
        }
        e => panic!("Wrong error type: {:?}", e),
    }
}

#[tokio::test]
async fn test_insufficient_splits_should_fail() {
    let pool = setup_test_pool().await;
    let repo = TransactionRepository::new(Arc::new(pool.clone()));

    let transaction_id =
        create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // Only one split
    let splits = vec![SplitRequest {
        description: Some("单个拆分".to_string()),
        amount: Decimal::from_str("50.00").unwrap(),
        percentage: None,
        category_id: None,
    }];

    let result = repo.split_transaction(transaction_id, splits).await;

    // Should fail
    assert!(result.is_err());
    match result.unwrap_err() {
        TransactionSplitError::InsufficientSplits { count } => {
            assert_eq!(count, 1);
        }
        e => panic!("Wrong error type: {:?}", e),
    }
}

#[tokio::test]
async fn test_double_split_should_fail() {
    let pool = setup_test_pool().await;
    let repo = TransactionRepository::new(Arc::new(pool.clone()));

    let transaction_id =
        create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

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

    // First split should succeed
    let result1 = repo
        .split_transaction(transaction_id, splits.clone())
        .await;
    assert!(result1.is_ok());

    // Second split should fail
    let result2 = repo.split_transaction(transaction_id, splits).await;
    assert!(result2.is_err());

    match result2.unwrap_err() {
        TransactionSplitError::AlreadySplit {
            id,
            existing_splits,
        } => {
            assert_eq!(id, transaction_id.to_string());
            assert_eq!(existing_splits.len(), 2);
        }
        e => panic!("Wrong error type: {:?}", e),
    }
}

#[tokio::test]
async fn test_nonexistent_transaction_should_fail() {
    let pool = setup_test_pool().await;
    let repo = TransactionRepository::new(Arc::new(pool.clone()));

    let fake_id = Uuid::new_v4();

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

    let result = repo.split_transaction(fake_id, splits).await;

    assert!(result.is_err());
    match result.unwrap_err() {
        TransactionSplitError::TransactionNotFound { id } => {
            assert_eq!(id, fake_id.to_string());
        }
        e => panic!("Wrong error type: {:?}", e),
    }
}
