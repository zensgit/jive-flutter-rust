use super::*;
use crate::error::TransactionSplitError;
use crate::infrastructure::entities::transaction::*;
use crate::infrastructure::entities::transaction::TransactionKind;
use crate::infrastructure::entities::{Entry, DateRange};
use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{PgPool, Row};
use std::str::FromStr;
use std::sync::Arc;
use std::time::Duration;
use uuid::Uuid;

pub struct TransactionRepository {
    pool: Arc<PgPool>,
}

impl TransactionRepository {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }
    
    // Create transaction with entry (following Maybe's Entry-Transaction pattern)
    pub async fn create_with_entry(
        &self,
        entry: Entry,
        transaction: Transaction,
    ) -> Result<TransactionWithEntry, RepositoryError> {
        let mut tx = self.pool.begin().await?;

        // First create the entry (runtime query)
        let created_entry = sqlx::query(
            r#"
            INSERT INTO entries (
                id, account_id, entryable_type, entryable_id,
                amount, currency, date, name, notes,
                excluded, pending, nature,
                created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
            RETURNING id, account_id, entryable_type, entryable_id,
                      amount, currency, date, name, notes,
                      excluded, pending, nature, created_at, updated_at
            "#,
        )
        .bind(entry.id)
        .bind(entry.account_id)
        .bind("Transaction")
        .bind(transaction.id)
        .bind(entry.amount)
        .bind(&entry.currency)
        .bind(entry.date)
        .bind(&entry.name)
        .bind(&entry.notes)
        .bind(entry.excluded)
        .bind(entry.pending)
        .bind(&entry.nature)
        .bind(entry.created_at)
        .bind(entry.updated_at)
        .fetch_one(&mut *tx)
        .await?;
        let created_entry: Entry = sqlx::FromRow::from_row(&created_entry)?;

        // Then create the transaction (runtime query)
        let created_transaction_row = sqlx::query(
            r#"
            INSERT INTO transactions (
                id, entry_id, category_id, payee_id,
                ledger_id, ledger_account_id,
                scheduled_transaction_id, original_transaction_id,
                reimbursement_batch_id, notes, kind, tags,
                reimbursable, reimbursed, reimbursed_at,
                is_refund, refund_amount,
                exclude_from_reports, exclude_from_budget,
                discount, created_at, updated_at
            )
            VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
                $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22
            )
            RETURNING id, entry_id, category_id, payee_id,
                      ledger_id, ledger_account_id,
                      scheduled_transaction_id, original_transaction_id,
                      reimbursement_batch_id, notes, kind, tags,
                      reimbursable, reimbursed, reimbursed_at,
                      is_refund, refund_amount,
                      exclude_from_reports, exclude_from_budget,
                      discount, created_at, updated_at
            "#,
        )
        .bind(transaction.id)
        .bind(created_entry.id)
        .bind(&transaction.category_id)
        .bind(&transaction.payee_id)
        .bind(&transaction.ledger_id)
        .bind(&transaction.ledger_account_id)
        .bind(&transaction.scheduled_transaction_id)
        .bind(&transaction.original_transaction_id)
        .bind(&transaction.reimbursement_batch_id)
        .bind(&transaction.notes)
        .bind(transaction.kind as TransactionKind)
        .bind(&transaction.tags)
        .bind(transaction.reimbursable)
        .bind(transaction.reimbursed)
        .bind(&transaction.reimbursed_at)
        .bind(transaction.is_refund)
        .bind(&transaction.refund_amount)
        .bind(transaction.exclude_from_reports)
        .bind(transaction.exclude_from_budget)
        .bind(&transaction.discount)
        .bind(transaction.created_at)
        .bind(transaction.updated_at)
        .fetch_one(&mut *tx)
        .await?;
        let created_transaction: Transaction = sqlx::FromRow::from_row(&created_transaction_row)?;
        
        tx.commit().await?;
        
        Ok(TransactionWithEntry {
            transaction: created_transaction,
            entry: created_entry,
        })
    }
    
    // Find transactions by account
    pub async fn find_by_account(
        &self,
        account_id: Uuid,
        date_range: Option<DateRange>,
    ) -> Result<Vec<TransactionWithEntry>, RepositoryError> {
        let query = if let Some(range) = date_range {
            sqlx::query(
                r#"
                SELECT 
                    t.*,
                    e.id as entry_id, e.account_id, e.amount, e.currency,
                    e.date, e.name as entry_name, e.notes as entry_notes,
                    e.excluded, e.pending, e.nature
                FROM transactions t
                JOIN entries e ON e.id = t.entry_id
                WHERE e.account_id = $1 
                    AND e.date >= $2 
                    AND e.date <= $3
                ORDER BY e.date DESC, t.created_at DESC
                "#,
            )
            .bind(account_id)
            .bind(range.start)
            .bind(range.end)
        } else {
            sqlx::query(
                r#"
                SELECT 
                    t.*,
                    e.id as entry_id, e.account_id, e.amount, e.currency,
                    e.date, e.name as entry_name, e.notes as entry_notes,
                    e.excluded, e.pending, e.nature
                FROM transactions t
                JOIN entries e ON e.id = t.entry_id
                WHERE e.account_id = $1
                ORDER BY e.date DESC, t.created_at DESC
                "#,
            )
            .bind(account_id)
        };
        
        let rows = query.fetch_all(&*self.pool).await?;
        // TODO: Properly map to TransactionWithEntry using manual row mapping
        let mut results = Vec::new();
        for row in rows {
            // Split into two structs by selecting columns explicitly above.
            let transaction: Transaction = sqlx::FromRow::from_row(&row)?;
            let entry = Entry {
                id: row.get("entry_id"),
                account_id: row.get("account_id"),
                entryable_type: "Transaction".to_string(),
                entryable_id: transaction.id,
                amount: row.get("amount"),
                currency: row.get("currency"),
                date: row.get("date"),
                name: row.get("entry_name"),
                notes: row.get("entry_notes"),
                excluded: row.get("excluded"),
                pending: row.get("pending"),
                nature: row.get("nature"),
                created_at: transaction.created_at,
                updated_at: transaction.updated_at,
            };
            results.push(TransactionWithEntry { transaction, entry });
        }
        Ok(results)
    }
    
    // Find transactions by category
    pub async fn find_by_category(
        &self,
        category_id: Uuid,
        family_id: Uuid,
    ) -> Result<Vec<TransactionWithEntry>, RepositoryError> {
        let rows = sqlx::query(
            r#"
            SELECT 
                t.*,
                e.id as entry_id, e.account_id, e.amount, e.currency,
                e.date, e.name as entry_name, e.notes as entry_notes,
                e.excluded, e.pending, e.nature
            FROM transactions t
            JOIN entries e ON e.id = t.entry_id
            JOIN accounts a ON a.id = e.account_id
            WHERE t.category_id = $1 AND a.family_id = $2
            ORDER BY e.date DESC
            "#,
        )
        .bind(category_id)
        .bind(family_id)
        .fetch_all(&*self.pool)
        .await?;

        let mut results = Vec::new();
        for row in rows {
            let transaction: Transaction = sqlx::FromRow::from_row(&row)?;
            let entry = Entry {
                id: row.get("entry_id"),
                account_id: row.get("account_id"),
                entryable_type: "Transaction".to_string(),
                entryable_id: transaction.id,
                amount: row.get("amount"),
                currency: row.get("currency"),
                date: row.get("date"),
                name: row.get("entry_name"),
                notes: row.get("entry_notes"),
                excluded: row.get("excluded"),
                pending: row.get("pending"),
                nature: row.get("nature"),
                created_at: transaction.created_at,
                updated_at: transaction.updated_at,
            };
            results.push(TransactionWithEntry { transaction, entry });
        }
        Ok(results)
    }
    
    // Find transactions by payee
    pub async fn find_by_payee(
        &self,
        payee_id: Uuid,
    ) -> Result<Vec<TransactionWithEntry>, RepositoryError> {
        let rows = sqlx::query(
            r#"
            SELECT 
                t.*,
                e.id as entry_id, e.account_id, e.amount, e.currency,
                e.date, e.name as entry_name, e.notes as entry_notes,
                e.excluded, e.pending, e.nature
            FROM transactions t
            JOIN entries e ON e.id = t.entry_id
            WHERE t.payee_id = $1
            ORDER BY e.date DESC
            "#,
        )
        .bind(payee_id)
        .fetch_all(&*self.pool)
        .await?;
        let mut results = Vec::new();
        for row in rows {
            let transaction: Transaction = sqlx::FromRow::from_row(&row)?;
            let entry = Entry {
                id: row.get("entry_id"),
                account_id: row.get("account_id"),
                entryable_type: "Transaction".to_string(),
                entryable_id: transaction.id,
                amount: row.get("amount"),
                currency: row.get("currency"),
                date: row.get("date"),
                name: row.get("entry_name"),
                notes: row.get("entry_notes"),
                excluded: row.get("excluded"),
                pending: row.get("pending"),
                nature: row.get("nature"),
                created_at: transaction.created_at,
                updated_at: transaction.updated_at,
            };
            results.push(TransactionWithEntry { transaction, entry });
        }
        Ok(results)
    }
    
    // Find reimbursable transactions
    pub async fn find_reimbursable(
        &self,
        family_id: Uuid,
        pending_only: bool,
    ) -> Result<Vec<TransactionWithEntry>, RepositoryError> {
        let query = if pending_only {
            sqlx::query(
                r#"
                SELECT 
                    t.*,
                    e.id as entry_id, e.account_id, e.amount, e.currency,
                    e.date, e.name as entry_name, e.notes as entry_notes,
                    e.excluded, e.pending, e.nature
                FROM transactions t
                JOIN entries e ON e.id = t.entry_id
                JOIN accounts a ON a.id = e.account_id
                WHERE a.family_id = $1 
                    AND t.reimbursable = true 
                    AND t.reimbursed = false
                ORDER BY e.date DESC
                "#,
            )
            .bind(family_id)
        } else {
            sqlx::query(
                r#"
                SELECT 
                    t.*,
                    e.id as entry_id, e.account_id, e.amount, e.currency,
                    e.date, e.name as entry_name, e.notes as entry_notes,
                    e.excluded, e.pending, e.nature
                FROM transactions t
                JOIN entries e ON e.id = t.entry_id
                JOIN accounts a ON a.id = e.account_id
                WHERE a.family_id = $1 AND t.reimbursable = true
                ORDER BY e.date DESC
                "#,
            )
            .bind(family_id)
        };
        
        let rows = query.fetch_all(&*self.pool).await?;
        let mut results = Vec::new();
        for row in rows {
            let transaction: Transaction = sqlx::FromRow::from_row(&row)?;
            let entry = Entry {
                id: row.get("entry_id"),
                account_id: row.get("account_id"),
                entryable_type: "Transaction".to_string(),
                entryable_id: transaction.id,
                amount: row.get("amount"),
                currency: row.get("currency"),
                date: row.get("date"),
                name: row.get("entry_name"),
                notes: row.get("entry_notes"),
                excluded: row.get("excluded"),
                pending: row.get("pending"),
                nature: row.get("nature"),
                created_at: transaction.created_at,
                updated_at: transaction.updated_at,
            };
            results.push(TransactionWithEntry { transaction, entry });
        }
        Ok(results)
    }
    
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
    pub async fn split_transaction(
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
        let original = match sqlx::query(
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
            "#
        )
        .bind(original_id)
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
        let existing_splits = sqlx::query(
            r#"
            SELECT split_transaction_id
            FROM transaction_splits
            WHERE original_transaction_id = $1
            FOR UPDATE
            "#
        )
        .bind(original_id)
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
            let split_name = split.description
                .clone()
                .unwrap_or_else(|| format!("Split from: {}", original.name));

            sqlx::query(
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
            )
            .bind(split_entry_id)
            .bind(split_transaction_id)
            .bind(split.amount)
            .bind(&split_name)
            .bind(Utc::now())
            .bind(original.entry_id)
            .execute(&mut *tx)
            .await?;

            // Create transaction for split
            sqlx::query(
                r#"
                INSERT INTO transactions (
                    id, entry_id, category_id, payee_id,
                    ledger_id, ledger_account_id,
                    original_transaction_id,
                    notes, kind,
                    created_at, updated_at
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'standard', $9, $9)
                "#
            )
            .bind(split_transaction_id)
            .bind(split_entry_id)
            .bind(&split.category_id.or(original.category_id))
            .bind(&original.payee_id)
            .bind(&original.ledger_id)
            .bind(&original.ledger_account_id)
            .bind(original_id)
            .bind(&split.description)
            .bind(Utc::now())
            .execute(&mut *tx)
            .await?;

            // Create split record
            let split_record_row = sqlx::query(
                r#"
                INSERT INTO transaction_splits (
                    id, original_transaction_id, split_transaction_id,
                    description, amount,
                    created_at, updated_at
                )
                VALUES ($1, $2, $3, $4, $5, $6, $6)
                RETURNING id, original_transaction_id, split_transaction_id,
                          description, amount, percentage, created_at, updated_at
                "#
            )
            .bind(Uuid::new_v4())
            .bind(original_id)
            .bind(split_transaction_id)
            .bind(&split.description)
            .bind(split.amount)
            .bind(Utc::now())
            .fetch_one(&mut *tx)
            .await?;
            let split_record: TransactionSplit = sqlx::FromRow::from_row(&split_record_row)?;
            created_splits.push(split_record);
        }

        // 7. Update or delete original transaction
        let remaining_amount = original_amount - total_split;

        if remaining_amount == Decimal::ZERO {
            // Complete split - soft delete original
            sqlx::query(
                r#"
                UPDATE entries
                SET deleted_at = $1, updated_at = $1
                WHERE id = $2
                "#
            )
            .bind(Some(Utc::now()))
            .bind(original.entry_id)
            .execute(&mut *tx)
            .await?;
        } else {
            // Partial split - update amount
            sqlx::query(
                r#"
                UPDATE entries
                SET amount = $1, updated_at = $2
                WHERE id = $3
                "#
            )
            .bind(remaining_amount)
            .bind(Utc::now())
            .bind(original.entry_id)
            .execute(&mut *tx)
            .await?;
        }

        // 8. Commit transaction
        tx.commit().await?;

        Ok(created_splits)
    }
    
    // Create a refund for a transaction
    pub async fn create_refund(
        &self,
        original_id: Uuid,
        refund_amount: Decimal,
        refund_date: NaiveDate,
    ) -> Result<TransactionWithEntry, RepositoryError> {
        // Get original transaction details
        let original = sqlx::query(
            r#"
            SELECT 
                e.account_id, e.currency, e.date, e.name,
                t.category_id, t.payee_id
            FROM entries e
            JOIN transactions t ON t.entry_id = e.id
            WHERE t.id = $1
            "#
        )
        .bind(original_id)
        .fetch_one(&*self.pool)
        .await?;
        
        // Create refund entry (with opposite sign)
        let refund_entry = Entry {
            id: Uuid::new_v4(),
            account_id: original.get::<Uuid, _>("account_id"),
            entryable_type: "Transaction".to_string(),
            entryable_id: Uuid::new_v4(),
            amount: -refund_amount,
            currency: original.get::<String, _>("currency"),
            date: refund_date,
            name: format!("Refund: {}", original.get::<String, _>("name")),
            notes: Some(format!(
                "Refund for transaction on {}",
                original.get::<chrono::NaiveDate, _>("date")
            )),
            excluded: false,
            pending: false,
            nature: if refund_amount > Decimal::ZERO { "inflow".to_string() } else { "outflow".to_string() },
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };
        
        // Create refund transaction
        let refund_transaction = Transaction {
            id: refund_entry.entryable_id,
            entry_id: refund_entry.id,
            category_id: original.get::<Option<Uuid>, _>("category_id"),
            payee_id: original.get::<Option<Uuid>, _>("payee_id"),
            original_transaction_id: Some(original_id),
            is_refund: true,
            refund_amount: Some(refund_amount),
            kind: TransactionKind::Standard,
            ..Transaction::new(refund_entry.id)
        };
        
        self.create_with_entry(refund_entry, refund_transaction).await
    }
    
    // Mark transactions as reimbursed
    pub async fn mark_as_reimbursed(
        &self,
        transaction_ids: Vec<Uuid>,
        batch_id: Option<Uuid>,
    ) -> Result<usize, RepositoryError> {
        let result = sqlx::query(
            r#"
            UPDATE transactions
            SET 
                reimbursed = true,
                reimbursed_at = $1,
                reimbursement_batch_id = $2,
                updated_at = $1
            WHERE id = ANY($3) AND reimbursable = true
            "#
        )
        .bind(Utc::now())
        .bind(batch_id)
        .bind(&transaction_ids)
        .execute(&*self.pool)
        .await?;
        
        Ok(result.rows_affected() as usize)
    }
}

// Helper structs
#[derive(Debug, Clone)]
pub struct TransactionWithEntry {
    pub transaction: Transaction,
    pub entry: Entry,
}

#[derive(Debug, Clone)]
pub struct SplitRequest {
    pub description: Option<String>,
    pub amount: Decimal,
    pub percentage: Option<Decimal>,
    pub category_id: Option<Uuid>,
}

#[async_trait]
impl Repository<Transaction> for TransactionRepository {
    type Error = RepositoryError;
    
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Transaction>, Self::Error> {
        let transaction = sqlx::query_as!(
            Transaction,
            "SELECT * FROM transactions WHERE id = $1",
            id
        )
        .fetch_optional(&*self.pool)
        .await?;
        
        Ok(transaction)
    }
    
    async fn find_all(&self) -> Result<Vec<Transaction>, Self::Error> {
        let transactions = sqlx::query_as!(
            Transaction,
            "SELECT * FROM transactions ORDER BY created_at DESC"
        )
        .fetch_all(&*self.pool)
        .await?;
        
        Ok(transactions)
    }
    
    async fn create(&self, entity: Transaction) -> Result<Transaction, Self::Error> {
        let created = sqlx::query_as!(
            Transaction,
            r#"
            INSERT INTO transactions (
                id, entry_id, category_id, payee_id, notes, kind,
                tags, reimbursable, exclude_from_reports, exclude_from_budget,
                created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            RETURNING *
            "#,
            entity.id,
            entity.entry_id,
            entity.category_id,
            entity.payee_id,
            entity.notes,
            entity.kind as TransactionKind,
            serde_json::to_value(&entity.tags).unwrap(),
            entity.reimbursable,
            entity.exclude_from_reports,
            entity.exclude_from_budget,
            entity.created_at,
            entity.updated_at
        )
        .fetch_one(&*self.pool)
        .await?;
        
        Ok(created)
    }
    
    async fn update(&self, entity: Transaction) -> Result<Transaction, Self::Error> {
        let updated = sqlx::query_as!(
            Transaction,
            r#"
            UPDATE transactions
            SET 
                category_id = $2,
                payee_id = $3,
                notes = $4,
                kind = $5,
                tags = $6,
                reimbursable = $7,
                reimbursed = $8,
                exclude_from_reports = $9,
                exclude_from_budget = $10,
                updated_at = $11
            WHERE id = $1
            RETURNING *
            "#,
            entity.id,
            entity.category_id,
            entity.payee_id,
            entity.notes,
            entity.kind as TransactionKind,
            serde_json::to_value(&entity.tags).unwrap(),
            entity.reimbursable,
            entity.reimbursed,
            entity.exclude_from_reports,
            entity.exclude_from_budget,
            Utc::now()
        )
        .fetch_one(&*self.pool)
        .await?;
        
        Ok(updated)
    }
    
    async fn delete(&self, id: Uuid) -> Result<bool, Self::Error> {
        // Delete transaction and its entry (cascade)
        let result = sqlx::query!(
            "DELETE FROM entries WHERE entryable_id = $1 AND entryable_type = 'Transaction'",
            id
        )
        .execute(&*self.pool)
        .await?;
        
        Ok(result.rows_affected() > 0)
    }
}
