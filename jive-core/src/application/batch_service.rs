// Batch Service - 批量操作功能
// Based on Maybe's bulk operations

use crate::domain::errors::DomainError;
use crate::infrastructure::entities::transaction::*;
use crate::infrastructure::entities::{Entry};
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::sync::Arc;
use sqlx::{PgPool, Transaction as SqlTransaction};
use uuid::Uuid;

pub struct BatchService {
    pool: Arc<PgPool>,
}

impl BatchService {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }
    
    // 批量更新交易分类
    pub async fn batch_update_category(
        &self,
        transaction_ids: Vec<Uuid>,
        category_id: Option<Uuid>,
    ) -> Result<BatchUpdateResult, DomainError> {
        let mut tx = self.pool.begin().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut success_count = 0;
        let mut failed_ids = Vec::new();
        
        for transaction_id in &transaction_ids {
            let result = sqlx::query!(
                "UPDATE transactions SET category_id = $1, updated_at = $2 WHERE id = $3",
                category_id,
                Utc::now(),
                transaction_id
            )
            .execute(&mut *tx)
            .await;
            
            match result {
                Ok(r) if r.rows_affected() > 0 => success_count += 1,
                _ => failed_ids.push(*transaction_id),
            }
        }
        
        tx.commit().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(BatchUpdateResult {
            total: transaction_ids.len(),
            success: success_count,
            failed: failed_ids,
            operation: "update_category".to_string(),
        })
    }
    
    // 批量添加标签
    pub async fn batch_add_tags(
        &self,
        transaction_ids: Vec<Uuid>,
        tag_ids: Vec<Uuid>,
    ) -> Result<BatchUpdateResult, DomainError> {
        let mut tx = self.pool.begin().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut success_count = 0;
        let mut failed_ids = Vec::new();
        
        for transaction_id in &transaction_ids {
            // Get existing tags
            let existing = sqlx::query!(
                "SELECT tags FROM transactions WHERE id = $1",
                transaction_id
            )
            .fetch_optional(&mut *tx)
            .await
            .map_err(|e| DomainError::Database(e.to_string()))?;
            
            if let Some(row) = existing {
                let mut current_tags: Vec<String> = row.tags
                    .and_then(|t| serde_json::from_value(t).ok())
                    .unwrap_or_default();
                
                // Add new tags
                for tag_id in &tag_ids {
                    let tag_name = format!("tag_{}", tag_id); // Should fetch actual tag name
                    if !current_tags.contains(&tag_name) {
                        current_tags.push(tag_name);
                    }
                }
                
                // Update tags
                let result = sqlx::query!(
                    "UPDATE transactions SET tags = $1, updated_at = $2 WHERE id = $3",
                    serde_json::to_value(&current_tags).unwrap(),
                    Utc::now(),
                    transaction_id
                )
                .execute(&mut *tx)
                .await;
                
                match result {
                    Ok(r) if r.rows_affected() > 0 => success_count += 1,
                    _ => failed_ids.push(*transaction_id),
                }
            } else {
                failed_ids.push(*transaction_id);
            }
        }
        
        tx.commit().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(BatchUpdateResult {
            total: transaction_ids.len(),
            success: success_count,
            failed: failed_ids,
            operation: "add_tags".to_string(),
        })
    }
    
    // 批量删除交易
    pub async fn batch_delete_transactions(
        &self,
        transaction_ids: Vec<Uuid>,
    ) -> Result<BatchUpdateResult, DomainError> {
        let mut tx = self.pool.begin().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut success_count = 0;
        let mut failed_ids = Vec::new();
        
        for transaction_id in &transaction_ids {
            // Delete entry (will cascade to transaction)
            let result = sqlx::query!(
                r#"
                DELETE FROM entries 
                WHERE entryable_id = $1 AND entryable_type = 'Transaction'
                "#,
                transaction_id
            )
            .execute(&mut *tx)
            .await;
            
            match result {
                Ok(r) if r.rows_affected() > 0 => success_count += 1,
                _ => failed_ids.push(*transaction_id),
            }
        }
        
        tx.commit().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(BatchUpdateResult {
            total: transaction_ids.len(),
            success: success_count,
            failed: failed_ids,
            operation: "delete".to_string(),
        })
    }
    
    // 批量标记为可报销
    pub async fn batch_mark_reimbursable(
        &self,
        transaction_ids: Vec<Uuid>,
        reimbursable: bool,
    ) -> Result<BatchUpdateResult, DomainError> {
        let result = sqlx::query!(
            r#"
            UPDATE transactions 
            SET reimbursable = $1, updated_at = $2 
            WHERE id = ANY($3)
            "#,
            reimbursable,
            Utc::now(),
            &transaction_ids
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(BatchUpdateResult {
            total: transaction_ids.len(),
            success: result.rows_affected() as usize,
            failed: Vec::new(),
            operation: "mark_reimbursable".to_string(),
        })
    }
    
    // 批量排除/包含在预算中
    pub async fn batch_exclude_from_budget(
        &self,
        transaction_ids: Vec<Uuid>,
        exclude: bool,
    ) -> Result<BatchUpdateResult, DomainError> {
        let result = sqlx::query!(
            r#"
            UPDATE transactions 
            SET exclude_from_budget = $1, updated_at = $2 
            WHERE id = ANY($3)
            "#,
            exclude,
            Utc::now(),
            &transaction_ids
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(BatchUpdateResult {
            total: transaction_ids.len(),
            success: result.rows_affected() as usize,
            failed: Vec::new(),
            operation: "exclude_from_budget".to_string(),
        })
    }
    
    // 批量更新交易日期
    pub async fn batch_update_dates(
        &self,
        updates: Vec<DateUpdate>,
    ) -> Result<BatchUpdateResult, DomainError> {
        let mut tx = self.pool.begin().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut success_count = 0;
        let mut failed_ids = Vec::new();
        
        for update in &updates {
            let result = sqlx::query!(
                r#"
                UPDATE entries 
                SET date = $1, updated_at = $2 
                WHERE entryable_id = $3 AND entryable_type = 'Transaction'
                "#,
                update.new_date,
                Utc::now(),
                update.transaction_id
            )
            .execute(&mut *tx)
            .await;
            
            match result {
                Ok(r) if r.rows_affected() > 0 => success_count += 1,
                _ => failed_ids.push(update.transaction_id),
            }
        }
        
        tx.commit().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(BatchUpdateResult {
            total: updates.len(),
            success: success_count,
            failed: failed_ids,
            operation: "update_dates".to_string(),
        })
    }
    
    // 批量创建交易
    pub async fn batch_create_transactions(
        &self,
        transactions: Vec<CreateTransactionBatch>,
    ) -> Result<BatchCreateResult, DomainError> {
        let mut tx = self.pool.begin().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut created_ids = Vec::new();
        let mut failed_count = 0;
        
        for transaction_data in &transactions {
            let transaction_id = Uuid::new_v4();
            let entry_id = Uuid::new_v4();
            
            // Create entry
            let entry_result = sqlx::query!(
                r#"
                INSERT INTO entries (
                    id, account_id, entryable_type, entryable_id,
                    amount, currency, date, name, notes,
                    excluded, pending, nature, created_at, updated_at
                )
                VALUES ($1, $2, 'Transaction', $3, $4, $5, $6, $7, $8, false, false, $9, $10, $10)
                "#,
                entry_id,
                transaction_data.account_id,
                transaction_id,
                transaction_data.amount,
                transaction_data.currency,
                transaction_data.date,
                transaction_data.description,
                transaction_data.notes,
                if transaction_data.amount < Decimal::ZERO { "outflow" } else { "inflow" },
                Utc::now()
            )
            .execute(&mut *tx)
            .await;
            
            if entry_result.is_err() {
                failed_count += 1;
                continue;
            }
            
            // Create transaction
            let transaction_result = sqlx::query!(
                r#"
                INSERT INTO transactions (
                    id, entry_id, category_id, payee_id, notes,
                    kind, tags, reimbursable, exclude_from_reports,
                    exclude_from_budget, created_at, updated_at
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, false, false, $9, $9)
                "#,
                transaction_id,
                entry_id,
                transaction_data.category_id,
                transaction_data.payee_id,
                transaction_data.notes,
                "standard",
                serde_json::to_value(&transaction_data.tags).unwrap(),
                transaction_data.reimbursable,
                Utc::now()
            )
            .execute(&mut *tx)
            .await;
            
            match transaction_result {
                Ok(_) => created_ids.push(transaction_id),
                Err(_) => failed_count += 1,
            }
        }
        
        tx.commit().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(BatchCreateResult {
            total: transactions.len(),
            created: created_ids,
            failed: failed_count,
        })
    }
    
    // 批量应用规则
    pub async fn batch_apply_rules(
        &self,
        transaction_ids: Vec<Uuid>,
        rule_ids: Vec<Uuid>,
    ) -> Result<BatchRuleResult, DomainError> {
        let mut results = Vec::new();
        
        for rule_id in &rule_ids {
            // Get rule details
            let rule = sqlx::query!(
                "SELECT * FROM rules WHERE id = $1",
                rule_id
            )
            .fetch_optional(&*self.pool)
            .await
            .map_err(|e| DomainError::Database(e.to_string()))?;
            
            if let Some(_rule) = rule {
                // Apply rule to each transaction
                // This would integrate with the rule engine
                let mut applied_count = 0;
                
                for _transaction_id in &transaction_ids {
                    // Apply rule logic here
                    applied_count += 1;
                }
                
                results.push(RuleApplicationResult {
                    rule_id: *rule_id,
                    applied_to: applied_count,
                    success: true,
                });
            }
        }
        
        Ok(BatchRuleResult {
            total_transactions: transaction_ids.len(),
            total_rules: rule_ids.len(),
            results,
        })
    }
    
    // 批量合并重复交易
    pub async fn batch_merge_duplicates(
        &self,
        duplicate_groups: Vec<DuplicateGroup>,
    ) -> Result<BatchMergeResult, DomainError> {
        let mut tx = self.pool.begin().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut merged_count = 0;
        let mut kept_ids = Vec::new();
        let mut deleted_ids = Vec::new();
        
        for group in &duplicate_groups {
            if group.transaction_ids.len() < 2 {
                continue;
            }
            
            // Keep the first, delete the rest
            let keep_id = group.transaction_ids[0];
            kept_ids.push(keep_id);
            
            for i in 1..group.transaction_ids.len() {
                let delete_id = group.transaction_ids[i];
                
                // Delete duplicate
                let result = sqlx::query!(
                    r#"
                    DELETE FROM entries 
                    WHERE entryable_id = $1 AND entryable_type = 'Transaction'
                    "#,
                    delete_id
                )
                .execute(&mut *tx)
                .await;
                
                if result.is_ok() {
                    deleted_ids.push(delete_id);
                    merged_count += 1;
                }
            }
        }
        
        tx.commit().await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(BatchMergeResult {
            groups_processed: duplicate_groups.len(),
            transactions_merged: merged_count,
            kept: kept_ids,
            deleted: deleted_ids,
        })
    }
}

// DTOs

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchUpdateResult {
    pub total: usize,
    pub success: usize,
    pub failed: Vec<Uuid>,
    pub operation: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchCreateResult {
    pub total: usize,
    pub created: Vec<Uuid>,
    pub failed: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DateUpdate {
    pub transaction_id: Uuid,
    pub new_date: NaiveDate,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTransactionBatch {
    pub account_id: Uuid,
    pub date: NaiveDate,
    pub amount: Decimal,
    pub currency: String,
    pub description: String,
    pub category_id: Option<Uuid>,
    pub payee_id: Option<Uuid>,
    pub notes: Option<String>,
    pub tags: Vec<String>,
    pub reimbursable: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchRuleResult {
    pub total_transactions: usize,
    pub total_rules: usize,
    pub results: Vec<RuleApplicationResult>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleApplicationResult {
    pub rule_id: Uuid,
    pub applied_to: usize,
    pub success: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DuplicateGroup {
    pub transaction_ids: Vec<Uuid>,
    pub amount: Decimal,
    pub date: NaiveDate,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchMergeResult {
    pub groups_processed: usize,
    pub transactions_merged: usize,
    pub kept: Vec<Uuid>,
    pub deleted: Vec<Uuid>,
}