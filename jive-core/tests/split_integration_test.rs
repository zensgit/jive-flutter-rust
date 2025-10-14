// tests/split_integration_test.rs
// Integration tests for transaction splitting

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

async fn create_test_transaction_with_account(
    pool: &PgPool,
    account_id: Uuid,
    amount: Decimal,
) -> Uuid {
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

    create_test_transaction_with_account(pool, account_id, amount).await
}

#[tokio::test]
async fn test_split_with_categories() {
    let pool = setup_test_pool().await;
    let repo = TransactionRepository::new(Arc::new(pool.clone()));

    // Create test family
    let family_id = Uuid::new_v4();
    sqlx::query!(
        r#"
        INSERT INTO families (id, name, created_at, updated_at)
        VALUES ($1, 'Test Family', NOW(), NOW())
        "#,
        family_id
    )
    .execute(&pool)
    .await
    .unwrap();

    // Create categories
    let food_category = Uuid::new_v4();
    let entertainment_category = Uuid::new_v4();

    sqlx::query!(
        r#"
        INSERT INTO categories (id, family_id, name, color, classification, created_at, updated_at)
        VALUES ($1, $2, 'Food', '#FF0000', 'expense', NOW(), NOW())
        "#,
        food_category,
        family_id
    )
    .execute(&pool)
    .await
    .unwrap();

    sqlx::query!(
        r#"
        INSERT INTO categories (id, family_id, name, color, classification, created_at, updated_at)
        VALUES ($1, $2, 'Entertainment', '#00FF00', 'expense', NOW(), NOW())
        "#,
        entertainment_category,
        family_id
    )
    .execute(&pool)
    .await
    .unwrap();

    // Create transaction
    let transaction_id =
        create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // Split with categories
    let splits = vec![
        SplitRequest {
            description: Some("餐饮".to_string()),
            amount: Decimal::from_str("60.00").unwrap(),
            percentage: None,
            category_id: Some(food_category),
        },
        SplitRequest {
            description: Some("娱乐".to_string()),
            amount: Decimal::from_str("40.00").unwrap(),
            percentage: None,
            category_id: Some(entertainment_category),
        },
    ];

    let result = repo.split_transaction(transaction_id, splits).await;
    assert!(result.is_ok());

    let created_splits = result.unwrap();

    // Verify categories are correctly associated
    for split in created_splits {
        let transaction = sqlx::query!(
            "SELECT category_id FROM transactions WHERE id = $1",
            split.split_transaction_id
        )
        .fetch_one(&pool)
        .await
        .unwrap();

        assert!(transaction.category_id.is_some());
        assert!(
            transaction.category_id.unwrap() == food_category
                || transaction.category_id.unwrap() == entertainment_category
        );
    }
}

#[tokio::test]
async fn test_split_preserves_account_balance() {
    let pool = setup_test_pool().await;
    let repo = TransactionRepository::new(Arc::new(pool.clone()));

    // Create test family
    let family_id = Uuid::new_v4();
    sqlx::query!(
        r#"
        INSERT INTO families (id, name, created_at, updated_at)
        VALUES ($1, 'Test Family', NOW(), NOW())
        "#,
        family_id
    )
    .execute(&pool)
    .await
    .unwrap();

    // Create account with initial balance 1000元
    let account_id = Uuid::new_v4();
    sqlx::query!(
        r#"
        INSERT INTO accounts (id, family_id, name, balance, currency, created_at, updated_at)
        VALUES ($1, $2, 'Test', '1000.00', 'USD', NOW(), NOW())
        "#,
        account_id,
        family_id
    )
    .execute(&pool)
    .await
    .unwrap();

    // Create 100元 expense transaction
    let transaction_id = create_test_transaction_with_account(
        &pool,
        account_id,
        Decimal::from_str("100.00").unwrap(),
    )
    .await;

    // Split
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

    repo.split_transaction(transaction_id, splits)
        .await
        .unwrap();

    // Verify total amount is still 100元 (split doesn't change total)
    let entries_total = sqlx::query_scalar!(
        r#"
        SELECT COALESCE(SUM(amount::numeric), 0) as "total!"
        FROM entries
        WHERE account_id = $1 AND deleted_at IS NULL
        "#,
        account_id
    )
    .fetch_one(&pool)
    .await
    .unwrap();

    assert_eq!(entries_total, Decimal::from_str("100.00").unwrap());
}
