use super::*;
use crate::infrastructure::entities::transaction::*;
use crate::infrastructure::entities::{Entry, DateRange};
use async_trait::async_trait;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use sqlx::{PgPool, Row};
use std::sync::Arc;
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
        
        // First create the entry
        let created_entry = sqlx::query_as!(
            Entry,
            r#"
            INSERT INTO entries (
                id, account_id, entryable_type, entryable_id,
                amount, currency, date, name, notes,
                excluded, pending, nature,
                created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
            RETURNING *
            "#,
            entry.id,
            entry.account_id,
            "Transaction",
            transaction.id,
            entry.amount,
            entry.currency,
            entry.date,
            entry.name,
            entry.notes,
            entry.excluded,
            entry.pending,
            entry.nature,
            entry.created_at,
            entry.updated_at
        )
        .fetch_one(&mut *tx)
        .await?;
        
        // Then create the transaction
        let created_transaction = sqlx::query_as!(
            Transaction,
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
            RETURNING *
            "#,
            transaction.id,
            created_entry.id,
            transaction.category_id,
            transaction.payee_id,
            transaction.ledger_id,
            transaction.ledger_account_id,
            transaction.scheduled_transaction_id,
            transaction.original_transaction_id,
            transaction.reimbursement_batch_id,
            transaction.notes,
            transaction.kind as TransactionKind,
            serde_json::to_value(&transaction.tags).unwrap(),
            transaction.reimbursable,
            transaction.reimbursed,
            transaction.reimbursed_at,
            transaction.is_refund,
            transaction.refund_amount,
            transaction.exclude_from_reports,
            transaction.exclude_from_budget,
            transaction.discount,
            transaction.created_at,
            transaction.updated_at
        )
        .fetch_one(&mut *tx)
        .await?;
        
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
            sqlx::query!(
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
                account_id,
                range.start,
                range.end
            )
        } else {
            sqlx::query!(
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
                account_id
            )
        };
        
        let rows = query.fetch_all(&*self.pool).await?;
        
        // Map rows to TransactionWithEntry
        // Note: This is simplified - actual implementation would properly map all fields
        Ok(vec![])
    }
    
    // Find transactions by category
    pub async fn find_by_category(
        &self,
        category_id: Uuid,
        family_id: Uuid,
    ) -> Result<Vec<TransactionWithEntry>, RepositoryError> {
        let rows = sqlx::query!(
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
            category_id,
            family_id
        )
        .fetch_all(&*self.pool)
        .await?;
        
        // Map rows to TransactionWithEntry
        Ok(vec![])
    }
    
    // Find transactions by payee
    pub async fn find_by_payee(
        &self,
        payee_id: Uuid,
    ) -> Result<Vec<TransactionWithEntry>, RepositoryError> {
        let rows = sqlx::query!(
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
            payee_id
        )
        .fetch_all(&*self.pool)
        .await?;
        
        Ok(vec![])
    }
    
    // Find reimbursable transactions
    pub async fn find_reimbursable(
        &self,
        family_id: Uuid,
        pending_only: bool,
    ) -> Result<Vec<TransactionWithEntry>, RepositoryError> {
        let query = if pending_only {
            sqlx::query!(
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
                family_id
            )
        } else {
            sqlx::query!(
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
                family_id
            )
        };
        
        let rows = query.fetch_all(&*self.pool).await?;
        Ok(vec![])
    }
    
    // Split a transaction
    pub async fn split_transaction(
        &self,
        original_id: Uuid,
        splits: Vec<SplitRequest>,
    ) -> Result<Vec<TransactionSplit>, RepositoryError> {
        let mut tx = self.pool.begin().await?;
        let mut created_splits = Vec::new();
        
        for split in splits {
            // Create new entry for split
            let split_entry_id = Uuid::new_v4();
            let split_transaction_id = Uuid::new_v4();
            
            // Create split entry
            sqlx::query!(
                r#"
                INSERT INTO entries (
                    id, account_id, entryable_type, entryable_id,
                    amount, currency, date, name,
                    excluded, pending, nature,
                    created_at, updated_at
                )
                SELECT 
                    $1, account_id, 'Transaction', $2,
                    $3, currency, date, $4,
                    excluded, pending, nature,
                    $5, $5
                FROM entries WHERE entryable_id = $6 AND entryable_type = 'Transaction'
                "#,
                split_entry_id,
                split_transaction_id,
                split.amount,
                split.description,
                Utc::now(),
                original_id
            )
            .execute(&mut *tx)
            .await?;
            
            // Create split transaction
            sqlx::query!(
                r#"
                INSERT INTO transactions (
                    id, entry_id, category_id, original_transaction_id,
                    notes, kind, created_at, updated_at
                )
                VALUES ($1, $2, $3, $4, $5, 'standard', $6, $6)
                "#,
                split_transaction_id,
                split_entry_id,
                split.category_id,
                original_id,
                split.description,
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
                    description, amount, percentage,
                    created_at, updated_at
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $7)
                RETURNING *
                "#,
                Uuid::new_v4(),
                original_id,
                split_transaction_id,
                split.description,
                split.amount,
                split.percentage,
                Utc::now()
            )
            .fetch_one(&mut *tx)
            .await?;
            
            created_splits.push(split_record);
        }
        
        // Update original transaction amount
        let total_split: Decimal = splits.iter().map(|s| s.amount).sum();
        sqlx::query!(
            r#"
            UPDATE entries 
            SET amount = amount - $1, updated_at = $2
            WHERE entryable_id = $3 AND entryable_type = 'Transaction'
            "#,
            total_split,
            Utc::now(),
            original_id
        )
        .execute(&mut *tx)
        .await?;
        
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
        let original = sqlx::query!(
            r#"
            SELECT e.*, t.category_id, t.payee_id
            FROM entries e
            JOIN transactions t ON t.entry_id = e.id
            WHERE t.id = $1
            "#,
            original_id
        )
        .fetch_one(&*self.pool)
        .await?;
        
        // Create refund entry (with opposite sign)
        let refund_entry = Entry {
            id: Uuid::new_v4(),
            account_id: original.account_id,
            entryable_type: "Transaction".to_string(),
            entryable_id: Uuid::new_v4(),
            amount: -refund_amount,
            currency: original.currency,
            date: refund_date,
            name: format!("Refund: {}", original.name),
            notes: Some(format!("Refund for transaction on {}", original.date)),
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
            category_id: original.category_id,
            payee_id: original.payee_id,
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
        let result = sqlx::query!(
            r#"
            UPDATE transactions
            SET 
                reimbursed = true,
                reimbursed_at = $1,
                reimbursement_batch_id = $2,
                updated_at = $1
            WHERE id = ANY($3) AND reimbursable = true
            "#,
            Utc::now(),
            batch_id,
            &transaction_ids
        )
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
    pub description: String,
    pub amount: Decimal,
    pub percentage: Decimal,
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