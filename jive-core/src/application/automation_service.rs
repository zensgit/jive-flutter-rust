// Automation Service - Based on Maybe's auto-matching and auto-categorization
// References: family/auto_transfer_matchable.rb, family/auto_categorizer.rb

use crate::domain::errors::DomainError;
use crate::infrastructure::entities::transaction::*;
use crate::infrastructure::entities::ledger::*;
use crate::infrastructure::entities::{Entry, DateRange};
use chrono::{DateTime, NaiveDate, Utc, Duration};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::sync::Arc;
use sqlx::PgPool;
use uuid::Uuid;

pub struct AutomationService {
    pool: Arc<PgPool>,
}

impl AutomationService {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }
    
    // Auto-match transfers - Based on Maybe's auto_match_transfers!
    pub async fn auto_match_transfers(
        &self,
        family_id: Uuid,
        date_window: i64, // Days to look for matching transactions
    ) -> Result<Vec<TransferMatch>, DomainError> {
        // Based on Maybe's logic:
        // 1. Find inflow/outflow pairs within date window
        // 2. Match by amount (same currency) or with exchange rate tolerance
        // 3. Create Transfer records for matches
        
        let candidates = self.find_transfer_candidates(family_id, date_window).await?;
        let mut matches = Vec::new();
        let mut used_transaction_ids = HashSet::new();
        
        for candidate in candidates {
            // Skip if already matched
            if used_transaction_ids.contains(&candidate.inflow_id) ||
               used_transaction_ids.contains(&candidate.outflow_id) {
                continue;
            }
            
            // Check if already matched or rejected
            if self.is_already_matched_or_rejected(&candidate).await? {
                continue;
            }
            
            // Calculate confidence score
            let confidence = self.calculate_match_confidence(&candidate);
            
            if confidence >= Decimal::from_str("0.8").unwrap() {
                // Create transfer record
                let transfer = self.create_transfer_match(
                    candidate.inflow_id,
                    candidate.outflow_id,
                    confidence,
                ).await?;
                
                // Update transaction kinds
                self.update_transaction_kinds(
                    candidate.inflow_id,
                    candidate.outflow_id,
                ).await?;
                
                matches.push(TransferMatch {
                    transfer_id: transfer.id,
                    inflow_transaction_id: candidate.inflow_id,
                    outflow_transaction_id: candidate.outflow_id,
                    confidence_score: confidence,
                    matched_at: Utc::now(),
                });
                
                used_transaction_ids.insert(candidate.inflow_id);
                used_transaction_ids.insert(candidate.outflow_id);
            }
        }
        
        Ok(matches)
    }
    
    // Find potential transfer pairs
    async fn find_transfer_candidates(
        &self,
        family_id: Uuid,
        date_window: i64,
    ) -> Result<Vec<TransferCandidate>, DomainError> {
        // SQL based on Maybe's transfer_match_candidates query
        let rows = sqlx::query!(
            r#"
            SELECT DISTINCT
                inflow.entryable_id as inflow_id,
                outflow.entryable_id as outflow_id,
                inflow.amount as inflow_amount,
                outflow.amount as outflow_amount,
                inflow.currency as inflow_currency,
                outflow.currency as outflow_currency,
                inflow.date as inflow_date,
                outflow.date as outflow_date,
                ABS(EXTRACT(EPOCH FROM (inflow.date - outflow.date))/86400) as date_diff
            FROM entries inflow
            JOIN entries outflow ON (
                inflow.amount < 0 
                AND outflow.amount > 0
                AND inflow.account_id != outflow.account_id
                AND inflow.date BETWEEN outflow.date - INTERVAL '%s days' 
                    AND outflow.date + INTERVAL '%s days'
            )
            JOIN accounts inflow_acc ON inflow_acc.id = inflow.account_id
            JOIN accounts outflow_acc ON outflow_acc.id = outflow.account_id
            WHERE inflow_acc.family_id = $1 
                AND outflow_acc.family_id = $1
                AND inflow.entryable_type = 'Transaction'
                AND outflow.entryable_type = 'Transaction'
                AND (
                    (inflow.currency = outflow.currency 
                     AND ABS(inflow.amount + outflow.amount) < 0.01)
                    OR 
                    (inflow.currency != outflow.currency)
                )
            ORDER BY date_diff ASC
            LIMIT 100
            "#,
            family_id
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut candidates = Vec::new();
        for row in rows {
            candidates.push(TransferCandidate {
                inflow_id: row.inflow_id,
                outflow_id: row.outflow_id,
                inflow_amount: row.inflow_amount,
                outflow_amount: row.outflow_amount,
                inflow_currency: row.inflow_currency,
                outflow_currency: row.outflow_currency,
                inflow_date: row.inflow_date,
                outflow_date: row.outflow_date,
                date_diff_days: row.date_diff.unwrap_or(0.0) as i32,
            });
        }
        
        Ok(candidates)
    }
    
    // Calculate confidence score for transfer match
    fn calculate_match_confidence(&self, candidate: &TransferCandidate) -> Decimal {
        let mut score = Decimal::from_str("0.5").unwrap();
        
        // Same currency exact match = high confidence
        if candidate.inflow_currency == candidate.outflow_currency {
            let amount_diff = (candidate.inflow_amount + candidate.outflow_amount).abs();
            if amount_diff < Decimal::from_str("0.01").unwrap() {
                score += Decimal::from_str("0.5").unwrap();
            } else if amount_diff < Decimal::from_str("1.0").unwrap() {
                score += Decimal::from_str("0.3").unwrap();
            }
        } else {
            // Different currency - check with exchange rate tolerance
            // TODO: Implement exchange rate checking
            score += Decimal::from_str("0.2").unwrap();
        }
        
        // Date proximity bonus
        match candidate.date_diff_days {
            0 => score += Decimal::from_str("0.2").unwrap(),
            1 => score += Decimal::from_str("0.15").unwrap(),
            2 => score += Decimal::from_str("0.1").unwrap(),
            3..=4 => score += Decimal::from_str("0.05").unwrap(),
            _ => {}
        }
        
        score.min(Decimal::ONE)
    }
    
    // Check if transfer pair is already matched or rejected
    async fn is_already_matched_or_rejected(
        &self,
        candidate: &TransferCandidate,
    ) -> Result<bool, DomainError> {
        let exists = sqlx::query!(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM transfers 
                WHERE (inflow_transaction_id = $1 AND outflow_transaction_id = $2)
                   OR inflow_transaction_id = $1 
                   OR outflow_transaction_id = $2
            ) OR EXISTS(
                SELECT 1 FROM rejected_transfers
                WHERE inflow_transaction_id = $1 AND outflow_transaction_id = $2
            ) as exists
            "#,
            candidate.inflow_id,
            candidate.outflow_id
        )
        .fetch_one(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(exists.exists.unwrap_or(false))
    }
    
    // Create transfer match record
    async fn create_transfer_match(
        &self,
        inflow_id: Uuid,
        outflow_id: Uuid,
        confidence: Decimal,
    ) -> Result<Transfer, DomainError> {
        let transfer = sqlx::query_as!(
            Transfer,
            r#"
            INSERT INTO transfers (
                id, inflow_transaction_id, outflow_transaction_id,
                matched_at, confidence_score, is_confirmed,
                created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, false, $4, $4)
            RETURNING *
            "#,
            Uuid::new_v4(),
            inflow_id,
            outflow_id,
            Utc::now(),
            confidence
        )
        .fetch_one(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(transfer)
    }
    
    // Update transaction kinds for matched transfers
    async fn update_transaction_kinds(
        &self,
        inflow_id: Uuid,
        outflow_id: Uuid,
    ) -> Result<(), DomainError> {
        // Update inflow as funds_movement
        sqlx::query!(
            "UPDATE transactions SET kind = 'funds_movement' WHERE id = $1",
            inflow_id
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        // Determine outflow kind based on account type
        let account_type = sqlx::query!(
            r#"
            SELECT a.accountable_type
            FROM transactions t
            JOIN entries e ON e.id = t.entry_id
            JOIN accounts a ON a.id = e.account_id
            WHERE t.id = $1
            "#,
            outflow_id
        )
        .fetch_one(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let kind = match account_type.accountable_type.as_str() {
            "CreditCard" => "cc_payment",
            "Loan" => "loan_payment",
            _ => "funds_movement",
        };
        
        sqlx::query!(
            "UPDATE transactions SET kind = $1 WHERE id = $2",
            kind,
            outflow_id
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(())
    }
    
    // Auto-categorize transactions - Based on Maybe's auto_categorize
    pub async fn auto_categorize_transactions(
        &self,
        family_id: Uuid,
    ) -> Result<Vec<CategoryAssignment>, DomainError> {
        let mut assignments = Vec::new();
        
        // Get uncategorized transactions
        let uncategorized = self.get_uncategorized_transactions(family_id).await?;
        
        for transaction in uncategorized {
            // Try different categorization strategies
            
            // 1. Payee-based categorization
            if let Some(category_id) = self.categorize_by_payee(&transaction).await? {
                self.assign_category(transaction.id, category_id).await?;
                assignments.push(CategoryAssignment {
                    transaction_id: transaction.id,
                    category_id,
                    method: "payee".to_string(),
                    confidence: Decimal::from_str("0.9").unwrap(),
                });
                continue;
            }
            
            // 2. Pattern-based categorization
            if let Some(category_id) = self.categorize_by_pattern(&transaction).await? {
                self.assign_category(transaction.id, category_id).await?;
                assignments.push(CategoryAssignment {
                    transaction_id: transaction.id,
                    category_id,
                    method: "pattern".to_string(),
                    confidence: Decimal::from_str("0.8").unwrap(),
                });
                continue;
            }
            
            // 3. Historical pattern categorization
            if let Some(category_id) = self.categorize_by_history(&transaction, family_id).await? {
                self.assign_category(transaction.id, category_id).await?;
                assignments.push(CategoryAssignment {
                    transaction_id: transaction.id,
                    category_id,
                    method: "history".to_string(),
                    confidence: Decimal::from_str("0.7").unwrap(),
                });
            }
        }
        
        Ok(assignments)
    }
    
    // Get uncategorized transactions
    async fn get_uncategorized_transactions(
        &self,
        family_id: Uuid,
    ) -> Result<Vec<TransactionInfo>, DomainError> {
        let rows = sqlx::query!(
            r#"
            SELECT t.id, t.payee_id, e.name, e.amount
            FROM transactions t
            JOIN entries e ON e.id = t.entry_id
            JOIN accounts a ON a.id = e.account_id
            WHERE a.family_id = $1
                AND t.category_id IS NULL
                AND e.date >= CURRENT_DATE - INTERVAL '30 days'
            ORDER BY e.date DESC
            LIMIT 100
            "#,
            family_id
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut transactions = Vec::new();
        for row in rows {
            transactions.push(TransactionInfo {
                id: row.id,
                payee_id: row.payee_id,
                name: row.name,
                amount: row.amount,
            });
        }
        
        Ok(transactions)
    }
    
    // Categorize by payee
    async fn categorize_by_payee(
        &self,
        transaction: &TransactionInfo,
    ) -> Result<Option<Uuid>, DomainError> {
        if let Some(payee_id) = transaction.payee_id {
            // Check PayeeCategory mapping
            let category = sqlx::query!(
                r#"
                SELECT category_id
                FROM payee_categories
                WHERE payee_id = $1
                ORDER BY created_at DESC
                LIMIT 1
                "#,
                payee_id
            )
            .fetch_optional(&*self.pool)
            .await
            .map_err(|e| DomainError::Database(e.to_string()))?;
            
            if let Some(cat) = category {
                return Ok(Some(cat.category_id));
            }
        }
        
        Ok(None)
    }
    
    // Categorize by pattern matching
    async fn categorize_by_pattern(
        &self,
        transaction: &TransactionInfo,
    ) -> Result<Option<Uuid>, DomainError> {
        let name_lower = transaction.name.to_lowercase();
        
        // Common patterns (based on Maybe's patterns)
        let patterns = vec![
            ("grocery", "Groceries"),
            ("supermarket", "Groceries"),
            ("restaurant", "Dining"),
            ("coffee", "Dining"),
            ("gas station", "Transportation"),
            ("uber", "Transportation"),
            ("lyft", "Transportation"),
            ("netflix", "Entertainment"),
            ("spotify", "Entertainment"),
            ("amazon", "Shopping"),
            ("pharmacy", "Healthcare"),
            ("clinic", "Healthcare"),
            ("insurance", "Insurance"),
            ("rent", "Housing"),
            ("mortgage", "Housing"),
            ("utility", "Utilities"),
            ("electric", "Utilities"),
            ("water", "Utilities"),
        ];
        
        for (pattern, category_name) in patterns {
            if name_lower.contains(pattern) {
                // Find or create category
                let category = sqlx::query!(
                    r#"
                    SELECT id FROM categories
                    WHERE name = $1
                    LIMIT 1
                    "#,
                    category_name
                )
                .fetch_optional(&*self.pool)
                .await
                .map_err(|e| DomainError::Database(e.to_string()))?;
                
                if let Some(cat) = category {
                    return Ok(Some(cat.id));
                }
            }
        }
        
        Ok(None)
    }
    
    // Categorize by historical patterns
    async fn categorize_by_history(
        &self,
        transaction: &TransactionInfo,
        family_id: Uuid,
    ) -> Result<Option<Uuid>, DomainError> {
        // Find similar transactions with categories
        let similar = sqlx::query!(
            r#"
            SELECT t.category_id, COUNT(*) as count
            FROM transactions t
            JOIN entries e ON e.id = t.entry_id
            JOIN accounts a ON a.id = e.account_id
            WHERE a.family_id = $1
                AND t.category_id IS NOT NULL
                AND LOWER(e.name) LIKE '%' || $2 || '%'
            GROUP BY t.category_id
            ORDER BY count DESC
            LIMIT 1
            "#,
            family_id,
            transaction.name.split_whitespace().next().unwrap_or("").to_lowercase()
        )
        .fetch_optional(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        if let Some(row) = similar {
            if row.count.unwrap_or(0) >= 3 {
                return Ok(row.category_id);
            }
        }
        
        Ok(None)
    }
    
    // Assign category to transaction
    async fn assign_category(
        &self,
        transaction_id: Uuid,
        category_id: Uuid,
    ) -> Result<(), DomainError> {
        sqlx::query!(
            "UPDATE transactions SET category_id = $1 WHERE id = $2",
            category_id,
            transaction_id
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(())
    }
    
    // Auto-detect merchants - Based on Maybe's auto_detect_merchants
    pub async fn auto_detect_merchants(
        &self,
        family_id: Uuid,
    ) -> Result<Vec<MerchantDetection>, DomainError> {
        let mut detections = Vec::new();
        
        // Get transactions without payees
        let transactions = sqlx::query!(
            r#"
            SELECT t.id, e.name
            FROM transactions t
            JOIN entries e ON e.id = t.entry_id
            JOIN accounts a ON a.id = e.account_id
            WHERE a.family_id = $1
                AND t.payee_id IS NULL
                AND e.date >= CURRENT_DATE - INTERVAL '30 days'
            LIMIT 100
            "#,
            family_id
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        for transaction in transactions {
            if let Some(merchant_name) = self.extract_merchant_name(&transaction.name) {
                // Find or create payee
                let payee_id = self.find_or_create_payee(family_id, &merchant_name).await?;
                
                // Update transaction
                sqlx::query!(
                    "UPDATE transactions SET payee_id = $1 WHERE id = $2",
                    payee_id,
                    transaction.id
                )
                .execute(&*self.pool)
                .await
                .map_err(|e| DomainError::Database(e.to_string()))?;
                
                detections.push(MerchantDetection {
                    transaction_id: transaction.id,
                    original_name: transaction.name.clone(),
                    detected_merchant: merchant_name,
                    payee_id,
                });
            }
        }
        
        Ok(detections)
    }
    
    // Extract merchant name from transaction description
    fn extract_merchant_name(&self, description: &str) -> Option<String> {
        // Remove common prefixes and suffixes
        let cleaned = description
            .replace("PURCHASE AUTHORIZED ON", "")
            .replace("CARD PURCHASE", "")
            .replace("DEBIT CARD PURCHASE", "")
            .replace("POS PURCHASE", "")
            .replace("CHECKCARD", "")
            .trim()
            .to_string();
        
        // Remove dates and transaction IDs (common patterns)
        let re = regex::Regex::new(r"\d{2}/\d{2}|\d{4,}|#\d+").unwrap();
        let cleaned = re.replace_all(&cleaned, "").trim().to_string();
        
        // Extract first meaningful part (usually merchant name)
        let parts: Vec<&str> = cleaned.split_whitespace().collect();
        if parts.len() >= 2 {
            Some(parts[0..2.min(parts.len())].join(" "))
        } else if !parts.is_empty() {
            Some(parts[0].to_string())
        } else {
            None
        }
    }
    
    // Find or create payee
    async fn find_or_create_payee(
        &self,
        family_id: Uuid,
        name: &str,
    ) -> Result<Uuid, DomainError> {
        // Try to find existing
        let existing = sqlx::query!(
            "SELECT id FROM payees WHERE family_id = $1 AND name = $2",
            family_id,
            name
        )
        .fetch_optional(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        if let Some(payee) = existing {
            return Ok(payee.id);
        }
        
        // Create new
        let new_payee = sqlx::query!(
            r#"
            INSERT INTO payees (id, family_id, name, transactions_count, created_at, updated_at)
            VALUES ($1, $2, $3, 0, $4, $4)
            RETURNING id
            "#,
            Uuid::new_v4(),
            family_id,
            name,
            Utc::now()
        )
        .fetch_one(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(new_payee.id)
    }
    
    // Detect duplicate transactions
    pub async fn detect_duplicates(
        &self,
        family_id: Uuid,
        date_range: DateRange,
    ) -> Result<Vec<DuplicateGroup>, DomainError> {
        let duplicates = sqlx::query!(
            r#"
            SELECT 
                e1.entryable_id as id1,
                e2.entryable_id as id2,
                e1.amount,
                e1.date,
                e1.name
            FROM entries e1
            JOIN entries e2 ON (
                e1.account_id = e2.account_id
                AND e1.amount = e2.amount
                AND e1.date = e2.date
                AND e1.entryable_id < e2.entryable_id
                AND e1.entryable_type = 'Transaction'
                AND e2.entryable_type = 'Transaction'
            )
            JOIN accounts a ON a.id = e1.account_id
            WHERE a.family_id = $1
                AND e1.date BETWEEN $2 AND $3
            "#,
            family_id,
            date_range.start,
            date_range.end
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut groups: HashMap<String, DuplicateGroup> = HashMap::new();
        
        for dup in duplicates {
            let key = format!("{}-{}-{}", dup.date, dup.amount, dup.name);
            let group = groups.entry(key.clone()).or_insert_with(|| {
                DuplicateGroup {
                    transactions: Vec::new(),
                    amount: dup.amount,
                    date: dup.date,
                    name: dup.name.clone(),
                }
            });
            
            group.transactions.push(dup.id1);
            group.transactions.push(dup.id2);
        }
        
        Ok(groups.into_values().collect())
    }
}

// DTOs
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransferCandidate {
    pub inflow_id: Uuid,
    pub outflow_id: Uuid,
    pub inflow_amount: Decimal,
    pub outflow_amount: Decimal,
    pub inflow_currency: String,
    pub outflow_currency: String,
    pub inflow_date: NaiveDate,
    pub outflow_date: NaiveDate,
    pub date_diff_days: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransferMatch {
    pub transfer_id: Uuid,
    pub inflow_transaction_id: Uuid,
    pub outflow_transaction_id: Uuid,
    pub confidence_score: Decimal,
    pub matched_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionInfo {
    pub id: Uuid,
    pub payee_id: Option<Uuid>,
    pub name: String,
    pub amount: Decimal,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryAssignment {
    pub transaction_id: Uuid,
    pub category_id: Uuid,
    pub method: String,
    pub confidence: Decimal,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MerchantDetection {
    pub transaction_id: Uuid,
    pub original_name: String,
    pub detected_merchant: String,
    pub payee_id: Uuid,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DuplicateGroup {
    pub transactions: Vec<Uuid>,
    pub amount: Decimal,
    pub date: NaiveDate,
    pub name: String,
}

use rust_decimal::prelude::FromStr;