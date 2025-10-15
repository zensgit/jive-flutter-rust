# Transaction Split - 完整测试套件

本文档包含 split_transaction 功能的完整测试用例。

## 测试文件结构

创建以下测试文件：

```
jive-core/tests/
├── split_transaction_test.rs        # 基础功能测试
├── split_concurrency_test.rs        # 并发安全测试
└── split_integration_test.rs        # 集成测试
```

## 1. 基础功能测试

```rust
// tests/split_transaction_test.rs

use jive_core::infrastructure::repositories::transaction_repository::*;
use jive_core::error::TransactionSplitError;
use rust_decimal::Decimal;
use std::str::FromStr;
use uuid::Uuid;
use sqlx::PgPool;

// 测试辅助函数
async fn setup_test_pool() -> PgPool {
    let database_url = std::env::var("TEST_DATABASE_URL")
        .expect("TEST_DATABASE_URL must be set");

    PgPool::connect(&database_url)
        .await
        .expect("Failed to connect to test database")
}

async fn create_test_transaction(pool: &PgPool, amount: Decimal) -> Uuid {
    // 创建测试账户
    let account_id = Uuid::new_v4();
    sqlx::query!(
        r#"
        INSERT INTO accounts (id, family_id, name, balance, currency)
        VALUES ($1, $2, 'Test Account', $3, 'USD')
        "#,
        account_id,
        Uuid::new_v4(),
        amount.to_string()
    )
    .execute(pool)
    .await
    .unwrap();

    // 创建测试交易
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

    // 创建100元交易
    let transaction_id = create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // 尝试拆分成150元 (80 + 70)
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

    let result = repo.split_transaction_safe(transaction_id, splits).await;

    // 应该失败
    assert!(result.is_err());

    // 检查错误类型
    match result.unwrap_err() {
        TransactionSplitError::ExceedsOriginal { original, requested, excess } => {
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

    // 创建100元交易
    let transaction_id = create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // 拆分成100元 (60 + 40)
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

    let result = repo.split_transaction_safe(transaction_id, splits).await;

    // 应该成功
    assert!(result.is_ok());
    let created_splits = result.unwrap();
    assert_eq!(created_splits.len(), 2);

    // 验证原交易被软删除
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

    // 验证新交易创建成功
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

    // 创建100元交易
    let transaction_id = create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // 部分拆分: 30 + 50 = 80, 保留20
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

    let result = repo.split_transaction_safe(transaction_id, splits).await;

    // 应该成功
    assert!(result.is_ok());

    // 验证原交易保留20元
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

    let transaction_id = create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // 包含负数金额
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

    let result = repo.split_transaction_safe(transaction_id, splits).await;

    // 应该失败
    assert!(result.is_err());
    match result.unwrap_err() {
        TransactionSplitError::InvalidAmount { amount, split_index } => {
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

    let transaction_id = create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // 只有一个拆分
    let splits = vec![
        SplitRequest {
            description: Some("单个拆分".to_string()),
            amount: Decimal::from_str("50.00").unwrap(),
            percentage: None,
            category_id: None,
        },
    ];

    let result = repo.split_transaction_safe(transaction_id, splits).await;

    // 应该失败
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

    let transaction_id = create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

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

    // 第一次拆分应该成功
    let result1 = repo.split_transaction_safe(transaction_id, splits.clone()).await;
    assert!(result1.is_ok());

    // 第二次拆分应该失败
    let result2 = repo.split_transaction_safe(transaction_id, splits).await;
    assert!(result.is_err());

    match result2.unwrap_err() {
        TransactionSplitError::AlreadySplit { id, existing_splits } => {
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

    let result = repo.split_transaction_safe(fake_id, splits).await;

    assert!(result.is_err());
    match result.unwrap_err() {
        TransactionSplitError::TransactionNotFound { id } => {
            assert_eq!(id, fake_id.to_string());
        }
        e => panic!("Wrong error type: {:?}", e),
    }
}
```

## 2. 并发安全测试

```rust
// tests/split_concurrency_test.rs

use tokio::task::JoinSet;
use std::sync::Arc;

#[tokio::test]
async fn test_concurrent_split_same_transaction() {
    let pool = Arc::new(setup_test_pool().await);
    let repo = Arc::new(TransactionRepository::new(pool.clone()));

    // 创建一个100元交易
    let transaction_id = create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // 创建10个并发任务尝试拆分同一笔交易
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

            repo_clone.split_transaction_safe(tid, splits).await
        });
    }

    // 收集结果
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

    // 只应该有一个成功，其余全部失败
    assert_eq!(success_count, 1);
    assert_eq!(error_count, 9);

    // 验证数据库中只有2个拆分记录
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

    let transaction_id = create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // 第一个任务：获取锁并持有一段时间
    let repo1 = repo.clone();
    let tid1 = transaction_id;
    let task1 = tokio::spawn(async move {
        let mut tx = repo1.pool.begin().await.unwrap();

        // 锁定交易
        sqlx::query!(
            "SELECT * FROM entries WHERE entryable_id = $1 FOR UPDATE",
            tid1
        )
        .fetch_one(&mut *tx)
        .await
        .unwrap();

        // 持有锁2秒
        tokio::time::sleep(Duration::from_secs(2)).await;

        tx.commit().await.unwrap();
    });

    // 等待第一个任务获取锁
    tokio::time::sleep(Duration::from_millis(100)).await;

    // 第二个任务：尝试拆分（应该触发重试）
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
    let result = repo.split_transaction_safe(transaction_id, splits).await;
    let elapsed = start.elapsed();

    // 应该在重试后成功
    assert!(result.is_ok());

    // 由于重试，应该花费超过2秒
    assert!(elapsed.as_secs() >= 2);

    task1.await.unwrap();
}
```

## 3. 集成测试

```rust
// tests/split_integration_test.rs

#[tokio::test]
async fn test_split_with_categories() {
    let pool = setup_test_pool().await;
    let repo = TransactionRepository::new(Arc::new(pool.clone()));

    // 创建分类
    let food_category = Uuid::new_v4();
    let entertainment_category = Uuid::new_v4();

    sqlx::query!(
        "INSERT INTO categories (id, family_id, name, color, classification) VALUES ($1, $2, 'Food', '#FF0000', 'expense')",
        food_category,
        Uuid::new_v4()
    )
    .execute(&pool)
    .await
    .unwrap();

    sqlx::query!(
        "INSERT INTO categories (id, family_id, name, color, classification) VALUES ($1, $2, 'Entertainment', '#00FF00', 'expense')",
        entertainment_category,
        Uuid::new_v4()
    )
    .execute(&pool)
    .await
    .unwrap();

    // 创建交易
    let transaction_id = create_test_transaction(&pool, Decimal::from_str("100.00").unwrap()).await;

    // 拆分并指定分类
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

    let result = repo.split_transaction_safe(transaction_id, splits).await;
    assert!(result.is_ok());

    let created_splits = result.unwrap();

    // 验证分类正确关联
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
            transaction.category_id.unwrap() == food_category ||
            transaction.category_id.unwrap() == entertainment_category
        );
    }
}

#[tokio::test]
async fn test_split_preserves_account_balance() {
    let pool = setup_test_pool().await;
    let repo = TransactionRepository::new(Arc::new(pool.clone()));

    // 创建账户，初始余额1000元
    let account_id = Uuid::new_v4();
    sqlx::query!(
        "INSERT INTO accounts (id, family_id, name, balance, currency) VALUES ($1, $2, 'Test', '1000.00', 'USD')",
        account_id,
        Uuid::new_v4()
    )
    .execute(&pool)
    .await
    .unwrap();

    // 创建100元支出交易
    let transaction_id = create_test_transaction_with_account(&pool, account_id, Decimal::from_str("100.00").unwrap()).await;

    // 拆分
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

    repo.split_transaction_safe(transaction_id, splits).await.unwrap();

    // 验证总金额仍然是100元（拆分不改变总额）
    let entries_total: Decimal = sqlx::query_scalar!(
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
```

## 运行测试

```bash
# 设置测试数据库
export TEST_DATABASE_URL="postgresql://postgres:postgres@localhost:5433/jive_test"

# 运行所有拆分测试
cargo test --test split_

# 运行特定测试
cargo test --test split_transaction_test test_split_exceeds_original

# 运行并发测试
cargo test --test split_concurrency_test

# 显示详细输出
cargo test --test split_transaction_test -- --nocapture

# 设置 SQLX_OFFLINE 模式（离线编译）
SQLX_OFFLINE=true cargo test --test split_transaction_test
```

## 测试覆盖矩阵

| 测试类别 | 测试用例 | 状态 |
|---------|---------|------|
| 验证逻辑 | 超额拆分拒绝 | ✅ |
| 验证逻辑 | 负数金额拒绝 | ✅ |
| 验证逻辑 | 单拆分拒绝 | ✅ |
| 验证逻辑 | 不存在交易拒绝 | ✅ |
| 功能测试 | 完全拆分成功 | ✅ |
| 功能测试 | 部分拆分成功 | ✅ |
| 功能测试 | 重复拆分拒绝 | ✅ |
| 并发测试 | 并发拆分串行化 | ✅ |
| 并发测试 | 锁超时重试 | ✅ |
| 集成测试 | 分类关联正确 | ✅ |
| 集成测试 | 账户余额保持 | ✅ |

## 下一步

创建数据库约束和审计功能。
