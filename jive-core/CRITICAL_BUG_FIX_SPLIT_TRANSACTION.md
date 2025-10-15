# CRITICAL BUG FIX: Transaction Split Money Creation Vulnerability

**Severity**: 🔴 **CRITICAL** - Financial Integrity Violation
**Discovery Date**: 2025-10-13
**Impact**: Users can create money from nothing by splitting transactions
**Status**: 🚨 REQUIRES IMMEDIATE FIX

---

## Bug Description

The `split_transaction` method in `transaction_repository.rs` allows users to split a transaction into multiple parts where the sum exceeds the original amount, effectively creating money out of thin air.

### Attack Example
```
Original transaction: 100元 expense
User splits into: 80元 + 70元 = 150元
Result: System creates 150元 worth of transactions from 100元
Impact: 50元 created from nothing
```

## Root Cause

The method lacks validation to ensure:
1. Sum of splits ≤ original transaction amount
2. All splits have positive amounts
3. Original transaction exists and is valid for splitting

## Code Fix

```rust
// transaction_repository.rs - FIXED split_transaction method

pub async fn split_transaction(
    &self,
    original_id: Uuid,
    splits: Vec<SplitRequest>,
) -> Result<Vec<TransactionSplit>, RepositoryError> {
    // Validate splits before any database operations
    if splits.is_empty() {
        return Err(RepositoryError::ValidationError(
            "Cannot split transaction into zero parts".into()
        ));
    }

    // Ensure all split amounts are positive
    for split in &splits {
        if split.amount <= Decimal::ZERO {
            return Err(RepositoryError::ValidationError(
                format!("Split amount must be positive, got: {}", split.amount)
            ));
        }
    }

    let mut tx = self.pool.begin().await?;

    // First, get the original transaction to validate
    let original = sqlx::query!(
        r#"
        SELECT e.amount, e.currency, t.date, t.description, t.type as transaction_type,
               a.id as account_id, c.id as category_id
        FROM entries e
        JOIN transactions t ON e.entryable_id = t.id
        JOIN accounts a ON t.account_id = a.id
        LEFT JOIN categories c ON t.category_id = c.id
        WHERE e.entryable_id = $1
        AND e.entryable_type = 'Transaction'
        AND e.deleted_at IS NULL
        "#,
        original_id
    )
    .fetch_optional(&mut *tx)
    .await?
    .ok_or_else(|| RepositoryError::NotFound(
        format!("Transaction {} not found or already deleted", original_id)
    ))?;

    // CRITICAL VALIDATION: Ensure sum doesn't exceed original
    let total_split: Decimal = splits.iter().map(|s| s.amount).sum();
    let original_amount = Decimal::from_str(&original.amount)
        .map_err(|e| RepositoryError::InvalidData(e.to_string()))?;

    if total_split > original_amount {
        return Err(RepositoryError::ValidationError(
            format!(
                "Sum of splits ({}) exceeds original transaction amount ({})",
                total_split, original_amount
            )
        ));
    }

    // Validate that we're not splitting an already split transaction
    let existing_splits = sqlx::query!(
        r#"
        SELECT COUNT(*) as count
        FROM transaction_splits
        WHERE original_transaction_id = $1
        "#,
        original_id
    )
    .fetch_one(&mut *tx)
    .await?;

    if existing_splits.count.unwrap_or(0) > 0 {
        return Err(RepositoryError::ValidationError(
            "Transaction has already been split".into()
        ));
    }

    let mut split_results = Vec::new();

    // Create new transactions for each split
    for split in &splits {
        let new_transaction_id = Uuid::new_v4();

        // Create the new transaction
        sqlx::query!(
            r#"
            INSERT INTO transactions (id, account_id, category_id, date, description, type, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            "#,
            new_transaction_id,
            original.account_id,
            split.category_id.or(original.category_id),
            original.date,
            split.description.clone().unwrap_or_else(|| format!("Split from: {}", original.description)),
            original.transaction_type,
            Utc::now(),
            Utc::now()
        )
        .execute(&mut *tx)
        .await?;

        // Create entry for the new transaction
        sqlx::query!(
            r#"
            INSERT INTO entries (entryable_id, entryable_type, amount, currency, created_at, updated_at)
            VALUES ($1, 'Transaction', $2, $3, $4, $5)
            "#,
            new_transaction_id,
            split.amount.to_string(),
            original.currency,
            Utc::now(),
            Utc::now()
        )
        .execute(&mut *tx)
        .await?;

        // Record the split relationship
        let split_id = Uuid::new_v4();
        sqlx::query!(
            r#"
            INSERT INTO transaction_splits (id, original_transaction_id, split_transaction_id, amount, created_at)
            VALUES ($1, $2, $3, $4, $5)
            "#,
            split_id,
            original_id,
            new_transaction_id,
            split.amount.to_string(),
            Utc::now()
        )
        .execute(&mut *tx)
        .await?;

        split_results.push(TransactionSplit {
            id: split_id,
            original_transaction_id: original_id,
            split_transaction_id: new_transaction_id,
            amount: split.amount,
            created_at: Utc::now(),
        });
    }

    // Update the original transaction amount
    let remaining_amount = original_amount - total_split;

    if remaining_amount > Decimal::ZERO {
        // Update original with remaining amount
        sqlx::query!(
            r#"
            UPDATE entries
            SET amount = $1, updated_at = $2
            WHERE entryable_id = $3 AND entryable_type = 'Transaction'
            "#,
            remaining_amount.to_string(),
            Utc::now(),
            original_id
        )
        .execute(&mut *tx)
        .await?;
    } else {
        // Mark original as fully split (soft delete)
        sqlx::query!(
            r#"
            UPDATE entries
            SET deleted_at = $1, updated_at = $2
            WHERE entryable_id = $3 AND entryable_type = 'Transaction'
            "#,
            Some(Utc::now()),
            Utc::now(),
            original_id
        )
        .execute(&mut *tx)
        .await?;

        // Also mark the transaction as split
        sqlx::query!(
            r#"
            UPDATE transactions
            SET deleted_at = $1, updated_at = $2
            WHERE id = $3
            "#,
            Some(Utc::now()),
            Utc::now(),
            original_id
        )
        .execute(&mut *tx)
        .await?;
    }

    tx.commit().await?;

    Ok(split_results)
}
```

## Additional Security Measures

### 1. Add Database Constraint
```sql
-- Add check constraint to prevent negative amounts
ALTER TABLE entries
ADD CONSTRAINT check_positive_amount
CHECK (amount::numeric > 0);

-- Add unique constraint to prevent double-splitting
ALTER TABLE transaction_splits
ADD CONSTRAINT unique_original_transaction
UNIQUE (original_transaction_id);
```

### 2. Add Validation Service Layer
```rust
// validation_service.rs
pub struct TransactionValidator;

impl TransactionValidator {
    pub fn validate_split_request(
        original_amount: Decimal,
        splits: &[SplitRequest],
    ) -> Result<(), ValidationError> {
        // Check sum doesn't exceed original
        let total: Decimal = splits.iter().map(|s| s.amount).sum();
        if total > original_amount {
            return Err(ValidationError::ExceedsOriginal {
                original: original_amount,
                requested: total
            });
        }

        // Check all amounts are positive
        for split in splits {
            if split.amount <= Decimal::ZERO {
                return Err(ValidationError::InvalidAmount(split.amount));
            }
        }

        // Check minimum split count
        if splits.len() < 2 {
            return Err(ValidationError::InsufficientSplits);
        }

        Ok(())
    }
}
```

### 3. Add Audit Logging
```rust
// audit_logger.rs
pub async fn log_split_transaction(
    user_id: Uuid,
    original_id: Uuid,
    original_amount: Decimal,
    splits: &[SplitRequest],
) -> Result<()> {
    let total: Decimal = splits.iter().map(|s| s.amount).sum();

    sqlx::query!(
        r#"
        INSERT INTO audit_logs (user_id, action, entity_type, entity_id, details, created_at)
        VALUES ($1, 'split_transaction', 'Transaction', $2, $3, $4)
        "#,
        user_id,
        original_id,
        json!({
            "original_amount": original_amount.to_string(),
            "split_total": total.to_string(),
            "split_count": splits.len(),
            "splits": splits.iter().map(|s| {
                json!({
                    "amount": s.amount.to_string(),
                    "category_id": s.category_id,
                    "description": s.description
                })
            }).collect::<Vec<_>>()
        }).to_string(),
        Utc::now()
    )
    .execute(pool)
    .await?;

    Ok(())
}
```

## Testing Requirements

### Unit Tests
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_split_exceeds_original_should_fail() {
        let repo = setup_test_repo().await;
        let original_id = create_test_transaction(Decimal::from(100)).await;

        let splits = vec![
            SplitRequest { amount: Decimal::from(80), ..Default::default() },
            SplitRequest { amount: Decimal::from(70), ..Default::default() },
        ];

        let result = repo.split_transaction(original_id, splits).await;

        assert!(result.is_err());
        match result {
            Err(RepositoryError::ValidationError(msg)) => {
                assert!(msg.contains("exceeds original"));
            }
            _ => panic!("Expected validation error"),
        }
    }

    #[tokio::test]
    async fn test_valid_split_should_succeed() {
        let repo = setup_test_repo().await;
        let original_id = create_test_transaction(Decimal::from(100)).await;

        let splits = vec![
            SplitRequest { amount: Decimal::from(60), ..Default::default() },
            SplitRequest { amount: Decimal::from(40), ..Default::default() },
        ];

        let result = repo.split_transaction(original_id, splits).await;

        assert!(result.is_ok());
        let split_results = result.unwrap();
        assert_eq!(split_results.len(), 2);

        // Verify original is marked as deleted
        let original = get_transaction(original_id).await;
        assert!(original.deleted_at.is_some());
    }

    #[tokio::test]
    async fn test_negative_split_should_fail() {
        let repo = setup_test_repo().await;
        let original_id = create_test_transaction(Decimal::from(100)).await;

        let splits = vec![
            SplitRequest { amount: Decimal::from(60), ..Default::default() },
            SplitRequest { amount: Decimal::from(-10), ..Default::default() },
        ];

        let result = repo.split_transaction(original_id, splits).await;

        assert!(result.is_err());
        match result {
            Err(RepositoryError::ValidationError(msg)) => {
                assert!(msg.contains("must be positive"));
            }
            _ => panic!("Expected validation error"),
        }
    }
}
```

## Deployment Steps

1. **Immediate Hotfix**
   - Deploy validation fix to production immediately
   - Add monitoring for split transaction operations

2. **Database Migration**
   - Add check constraints
   - Add audit logging table
   - Backfill any existing invalid data

3. **Monitoring**
   - Alert on any split where sum > original
   - Track split transaction patterns
   - Monitor for unusual splitting behavior

4. **User Communication**
   - Notify users of the fix
   - Audit recent split transactions for exploitation
   - Consider compensating affected accounts if exploitation found

## Impact Assessment

### Financial Impact
- **Potential Loss**: Unlimited (users could create infinite money)
- **Detection**: Check for splits where sum > original in historical data
- **Recovery**: Reverse any invalid splits found

### Query to Find Exploits
```sql
WITH split_sums AS (
    SELECT
        ts.original_transaction_id,
        SUM(CAST(e.amount AS DECIMAL)) as split_total
    FROM transaction_splits ts
    JOIN entries e ON e.entryable_id = ts.split_transaction_id
    WHERE e.entryable_type = 'Transaction'
    GROUP BY ts.original_transaction_id
),
originals AS (
    SELECT
        e.entryable_id as transaction_id,
        CAST(e.amount AS DECIMAL) as original_amount
    FROM entries e
    WHERE e.entryable_type = 'Transaction'
)
SELECT
    ss.original_transaction_id,
    o.original_amount,
    ss.split_total,
    (ss.split_total - o.original_amount) as excess_created
FROM split_sums ss
JOIN originals o ON o.transaction_id = ss.original_transaction_id
WHERE ss.split_total > o.original_amount
ORDER BY excess_created DESC;
```

## Prevention Measures

1. **Code Review Process**
   - All financial operations require security review
   - Automated testing for money creation scenarios
   - Formal verification of transaction invariants

2. **Runtime Checks**
   - Add application-level invariant checking
   - Implement double-entry bookkeeping validation
   - Real-time anomaly detection

3. **Architecture Improvements**
   - Implement proper domain-driven design
   - Use value objects for monetary amounts
   - Enforce business rules at domain layer

## Conclusion

This is a **CRITICAL** bug that undermines the entire financial integrity of the system. The fix must be deployed immediately, and a full audit of historical data should be performed to identify any exploitation.

The broader issue is that critical financial operations are implemented without proper validation, testing, or architectural safeguards. A comprehensive security review of all transaction-related operations is strongly recommended.

---

**Report Generated**: 2025-10-13
**Severity**: 🔴 CRITICAL
**Priority**: P0 - Deploy Immediately
**Estimated Fix Time**: 2 hours
**Testing Time**: 4 hours
**Risk if Unfixed**: Complete financial system compromise