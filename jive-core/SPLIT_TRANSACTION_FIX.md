# Transaction Split Fix - 生产级实现

本文档包含修复后的 `split_transaction` 方法的完整实现，包含并发控制和完整验证。

## 修复的核心方法

```rust
// transaction_repository.rs - 添加到 TransactionRepository impl 中

/// Split a transaction into multiple parts with full validation and concurrency control
///
/// # Arguments
/// * `original_id` - The UUID of the transaction to split
/// * `splits` - Vector of split requests containing amount and category for each split
///
/// # Returns
/// * `Ok(Vec<TransactionSplit>)` - Successfully created splits
/// * `Err(TransactionSplitError)` - Validation or concurrency error
///
/// # Safety
/// This method uses SELECT FOR UPDATE NOWAIT and SERIALIZABLE isolation level
/// to prevent race conditions and ensure data consistency.
pub async fn split_transaction_safe(
    &self,
    original_id: Uuid,
    splits: Vec<SplitRequest>,
) -> Result<Vec<TransactionSplit>, TransactionSplitError> {
    // Implement retry logic for concurrency conflicts
    let mut retry_count = 0;
    const MAX_RETRIES: u32 = 3;

    loop {
        match self.try_split_transaction_internal(original_id, &splits).await {
            Ok(result) => return Ok(result),

            Err(TransactionSplitError::ConcurrencyConflict { retry_after_ms, .. })
                if retry_count < MAX_RETRIES => {
                retry_count += 1;
                tokio::time::sleep(Duration::from_millis(retry_after_ms * retry_count as u64)).await;
                continue;
            }

            Err(e) => return Err(e),
        }
    }
}

async fn try_split_transaction_internal(
    &self,
    original_id: Uuid,
    splits: &[SplitRequest],
) -> Result<Vec<TransactionSplit>, TransactionSplitError> {
    use rust_decimal::Decimal;
    use std::str::FromStr;

    // 1. Input validation
    if splits.is_empty() {
        return Err(TransactionSplitError::InsufficientSplits { count: 0 });
    }

    if splits.len() < 2 {
        return Err(TransactionSplitError::InsufficientSplits {
            count: splits.len()
        });
    }

    // Validate all split amounts are positive
    for (idx, split) in splits.iter().enumerate() {
        if split.amount <= Decimal::ZERO {
            return Err(TransactionSplitError::InvalidAmount {
                amount: split.amount.to_string(),
                split_index: idx,
            });
        }
    }

    // 2. Start transaction with SERIALIZABLE isolation level
    let mut tx = self.pool.begin().await?;

    // Set isolation level to prevent phantom reads
    sqlx::query("SET TRANSACTION ISOLATION LEVEL SERIALIZABLE")
        .execute(&mut *tx)
        .await?;

    // Set lock timeout to fail fast
    sqlx::query("SET LOCAL lock_timeout = '5s'")
        .execute(&mut *tx)
        .await?;

    // 3. Get and lock original transaction (Entry-Transaction model)
    let original = match sqlx::query!(
        r#"
        SELECT
            e.id as entry_id,
            e.amount,
            e.currency,
            e.date,
            e.name,
            e.account_id,
            e.deleted_at as entry_deleted_at,
            t.id as transaction_id,
            t.category_id,
            t.payee_id,
            t.ledger_id,
            t.ledger_account_id,
            a.family_id
        FROM entries e
        JOIN transactions t ON t.id = e.entryable_id AND e.entryable_type = 'Transaction'
        JOIN accounts a ON a.id = e.account_id
        WHERE e.entryable_id = $1
          AND e.entryable_type = 'Transaction'
        FOR UPDATE NOWAIT
        "#,
        original_id
    )
    .fetch_optional(&mut *tx)
    .await {
        Ok(Some(row)) => row,
        Ok(None) => {
            return Err(TransactionSplitError::TransactionNotFound {
                id: original_id.to_string()
            });
        }
        Err(sqlx::Error::Database(db_err)) if db_err.message().contains("lock") => {
            return Err(TransactionSplitError::ConcurrencyConflict {
                transaction_id: original_id.to_string(),
                retry_after_ms: 100,
            });
        }
        Err(e) => return Err(e.into()),
    };

    // Check if already deleted
    if original.entry_deleted_at.is_some() {
        return Err(TransactionSplitError::TransactionNotFound {
            id: original_id.to_string(),
        });
    }

    // 4. Check for existing splits (with lock)
    let existing_splits = sqlx::query!(
        r#"
        SELECT split_transaction_id
        FROM transaction_splits
        WHERE original_transaction_id = $1
        FOR UPDATE
        "#,
        original_id
    )
    .fetch_all(&mut *tx)
    .await?;

    if !existing_splits.is_empty() {
        let split_ids: Vec<String> = existing_splits
            .iter()
            .map(|r| r.split_transaction_id.to_string())
            .collect();

        return Err(TransactionSplitError::AlreadySplit {
            id: original_id.to_string(),
            existing_splits: split_ids,
        });
    }

    // 5. Validate sum doesn't exceed original
    let original_amount = Decimal::from_str(&original.amount)
        .map_err(|e| TransactionSplitError::DatabaseError {
            message: format!("Invalid amount format: {}", e),
        })?;

    let total_split: Decimal = splits.iter().map(|s| s.amount).sum();

    if total_split > original_amount {
        let excess = total_split - original_amount;
        return Err(TransactionSplitError::ExceedsOriginal {
            original: original_amount.to_string(),
            requested: total_split.to_string(),
            excess: excess.to_string(),
        });
    }

    // 6. Create split transactions
    let mut created_splits = Vec::new();

    for split in splits {
        let split_entry_id = Uuid::new_v4();
        let split_transaction_id = Uuid::new_v4();

        // Create entry for split
        sqlx::query!(
            r#"
            INSERT INTO entries (
                id, account_id, entryable_type, entryable_id,
                amount, currency, date, name,
                excluded, nature,
                created_at, updated_at
            )
            SELECT
                $1, account_id, 'Transaction', $2,
                $3, currency, date, $4,
                excluded, nature,
                $5, $5
            FROM entries WHERE id = $6
            "#,
            split_entry_id,
            split_transaction_id,
            split.amount.to_string(),
            split.description.clone().unwrap_or_else(||
                format!("Split from: {}", original.name)
            ),
            Utc::now(),
            original.entry_id
        )
        .execute(&mut *tx)
        .await?;

        // Create transaction for split
        sqlx::query!(
            r#"
            INSERT INTO transactions (
                id, entry_id, category_id, payee_id,
                ledger_id, ledger_account_id,
                original_transaction_id,
                notes, kind,
                created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'standard', $9, $9)
            "#,
            split_transaction_id,
            split_entry_id,
            split.category_id.or(original.category_id),
            original.payee_id,
            original.ledger_id,
            original.ledger_account_id,
            original_id,
            split.description.clone(),
            Utc::now()
        )
        .execute(&mut *tx)
        .await?;

        // Create split record
        let split_record = sqlx::query_as!(
            TransactionSplit,
            r#"
            INSERT INTO transaction_splits (
                id, original_transaction_id, split_transaction_id,
                description, amount,
                created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $6)
            RETURNING
                id,
                original_transaction_id,
                split_transaction_id,
                description,
                amount as "amount: Decimal",
                percentage as "percentage: Option<Decimal>",
                created_at,
                updated_at
            "#,
            Uuid::new_v4(),
            original_id,
            split_transaction_id,
            split.description,
            split.amount.to_string(),
            Utc::now()
        )
        .fetch_one(&mut *tx)
        .await?;

        created_splits.push(split_record);
    }

    // 7. Update or delete original transaction
    let remaining_amount = original_amount - total_split;

    if remaining_amount == Decimal::ZERO {
        // Complete split - soft delete original
        sqlx::query!(
            r#"
            UPDATE entries
            SET deleted_at = $1, updated_at = $1
            WHERE id = $2
            "#,
            Some(Utc::now()),
            original.entry_id
        )
        .execute(&mut *tx)
        .await?;
    } else {
        // Partial split - update amount
        sqlx::query!(
            r#"
            UPDATE entries
            SET amount = $1, updated_at = $2
            WHERE id = $3
            "#,
            remaining_amount.to_string(),
            Utc::now(),
            original.entry_id
        )
        .execute(&mut *tx)
        .await?;
    }

    // 8. Commit transaction
    tx.commit().await?;

    Ok(created_splits)
}
```

## 重要的数据结构定义

```rust
// 确保 SplitRequest 包含所需字段
#[derive(Debug, Clone)]
pub struct SplitRequest {
    pub description: Option<String>,
    pub amount: Decimal,
    pub percentage: Option<Decimal>,
    pub category_id: Option<Uuid>,
}

// TransactionSplit 需要匹配数据库模式
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionSplit {
    pub id: Uuid,
    pub original_transaction_id: Uuid,
    pub split_transaction_id: Uuid,
    pub description: Option<String>,
    pub amount: Decimal,
    pub percentage: Option<Decimal>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
```

## 必需的依赖

在 transaction_repository.rs 文件开头添加：

```rust
use crate::error::TransactionSplitError;
use std::time::Duration;
use tokio::time::sleep;
```

## 使用示例

```rust
// 创建拆分请求
let splits = vec![
    SplitRequest {
        description: Some("餐饮部分".to_string()),
        amount: Decimal::from_str("60.00").unwrap(),
        percentage: None,
        category_id: Some(food_category_id),
    },
    SplitRequest {
        description: Some("娱乐部分".to_string()),
        amount: Decimal::from_str("40.00").unwrap(),
        percentage: None,
        category_id: Some(entertainment_category_id),
    },
];

// 执行拆分
match repo.split_transaction_safe(transaction_id, splits).await {
    Ok(created_splits) => {
        println!("成功创建 {} 个拆分", created_splits.len());
    }
    Err(TransactionSplitError::ExceedsOriginal { original, requested, excess }) => {
        eprintln!("拆分总额 {} 超过原金额 {}, 超出 {}", requested, original, excess);
    }
    Err(TransactionSplitError::ConcurrencyConflict { transaction_id, .. }) => {
        eprintln!("并发冲突: 交易 {} 正在被其他操作修改", transaction_id);
    }
    Err(e) => {
        eprintln!("拆分失败: {}", e);
    }
}
```

## 关键改进点

1. **并发安全**: 使用 `SELECT FOR UPDATE NOWAIT` + `SERIALIZABLE` 隔离级别
2. **自动重试**: 检测到锁冲突时自动重试最多3次
3. **完整验证**:
   - 拆分数量检查
   - 金额正数验证
   - 总额不超过原金额
   - 防止重复拆分
4. **精细错误**: 使用类型化的 `TransactionSplitError`
5. **部分拆分支持**: 正确处理剩余金额或完全删除
6. **Entry-Transaction模型**: 正确操作双表结构

## 测试要点

见 `SPLIT_TRANSACTION_TESTS.md` 文档。
