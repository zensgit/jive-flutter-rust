use crate::error::{ApiError, ApiResult};
use crate::models::transaction::{Transaction, TransactionCreate, TransactionType};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use sqlx::PgPool;
use std::collections::HashMap;
use uuid::Uuid;

pub struct TransactionService {
    pool: PgPool,
}

impl TransactionService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    /// 创建交易并更新账户余额
    pub async fn create_transaction(&self, data: TransactionCreate) -> ApiResult<Transaction> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        // 生成交易ID
        let transaction_id = Uuid::new_v4();
        // 克隆一份数据快照，避免后续字段 move 影响对 &data 的借用
        let data_snapshot = data.clone();

        // 获取账户当前余额
        let current_balance: Option<(Decimal,)> =
            sqlx::query_as("SELECT current_balance FROM accounts WHERE id = $1 FOR UPDATE")
                .bind(data.account_id)
                .fetch_optional(&mut *tx)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let current_balance = current_balance
            .ok_or_else(|| ApiError::NotFound("Account not found".to_string()))?
            .0;

        // 计算新余额
        let new_balance = match data.transaction_type {
            TransactionType::Income => current_balance + data.amount,
            TransactionType::Expense => current_balance - data.amount,
            TransactionType::Transfer => current_balance - data.amount,
        };

        // 插入交易记录
        let transaction: Transaction = sqlx::query_as(
            r#"
            INSERT INTO transactions (
                id, ledger_id, account_id, transaction_date, amount,
                transaction_type, category_id, category_name, payee,
                notes, status, created_at, updated_at
            ) VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), NOW()
            )
            RETURNING *
            "#,
        )
        .bind(transaction_id)
        .bind(data.ledger_id)
        .bind(data.account_id)
        .bind(data.transaction_date)
        .bind(data.amount)
        .bind(data.transaction_type.clone())
        .bind(data.category_id)
        .bind(data.category_name)
        .bind(data.payee)
        .bind(data.notes)
        .bind(data.status.clone())
        .fetch_one(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        // 更新账户余额
        sqlx::query("UPDATE accounts SET current_balance = $1, updated_at = NOW() WHERE id = $2")
            .bind(new_balance)
            .bind(data.account_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        // 记录账户余额历史
        sqlx::query(
            r#"
            INSERT INTO account_balances (id, account_id, balance, balance_date, created_at)
            VALUES ($1, $2, $3, $4, NOW())
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(data.account_id)
        .bind(new_balance)
        .bind(data.transaction_date)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        // 如果是转账，创建对应的转入交易
        if data.transaction_type == TransactionType::Transfer {
            if let Some(target_account_id) = data.target_account_id {
                self.create_transfer_target(
                    &mut tx,
                    &transaction_id,
                    &data_snapshot,
                    target_account_id,
                )
                .await?;
            }
        }

        // 提交事务
        tx.commit()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        Ok(transaction)
    }

    /// 创建转账目标交易
    async fn create_transfer_target(
        &self,
        tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
        source_transaction_id: &Uuid,
        data: &TransactionCreate,
        target_account_id: Uuid,
    ) -> ApiResult<()> {
        // 获取目标账户余额
        let target_balance: Option<(Decimal,)> =
            sqlx::query_as("SELECT current_balance FROM accounts WHERE id = $1 FOR UPDATE")
                .bind(target_account_id)
                .fetch_optional(&mut **tx)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let target_balance = target_balance
            .ok_or_else(|| ApiError::NotFound("Target account not found".to_string()))?
            .0;

        let new_target_balance = target_balance + data.amount;

        // 创建转入交易
        sqlx::query(
            r#"
            INSERT INTO transactions (
                id, ledger_id, account_id, transaction_date, amount,
                transaction_type, category_name, payee, notes, status,
                related_transaction_id, created_at, updated_at
            ) VALUES (
                $1, $2, $3, $4, $5, 'income', '转账收入', '内部转账', $6, $7, $8, NOW(), NOW()
            )
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(data.ledger_id)
        .bind(target_account_id)
        .bind(data.transaction_date)
        .bind(data.amount)
        .bind(format!(
            "从账户转入: {}",
            data.notes.as_deref().unwrap_or("")
        ))
        .bind(data.status.clone())
        .bind(source_transaction_id)
        .execute(&mut **tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        // 更新目标账户余额
        sqlx::query("UPDATE accounts SET current_balance = $1, updated_at = NOW() WHERE id = $2")
            .bind(new_target_balance)
            .bind(target_account_id)
            .execute(&mut **tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    /// 批量导入交易
    pub async fn bulk_import(
        &self,
        transactions: Vec<TransactionCreate>,
    ) -> ApiResult<Vec<Transaction>> {
        let mut tx = self
            .pool
            .begin()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let mut created_transactions = Vec::new();
        let mut account_balances: HashMap<Uuid, Decimal> = HashMap::new();

        // 预加载所有相关账户的余额
        for trans in &transactions {
            if let std::collections::hash_map::Entry::Vacant(e) =
                account_balances.entry(trans.account_id)
            {
                let balance: Option<(Decimal,)> =
                    sqlx::query_as("SELECT current_balance FROM accounts WHERE id = $1")
                        .bind(trans.account_id)
                        .fetch_optional(&mut *tx)
                        .await
                        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

                if let Some(balance) = balance {
                    e.insert(balance.0);
                }
            }
        }

        // 按日期排序交易
        let mut sorted_transactions = transactions;
        sorted_transactions.sort_by_key(|t| t.transaction_date);

        // 处理每笔交易
        for trans_data in sorted_transactions {
            let account_balance = account_balances
                .get_mut(&trans_data.account_id)
                .ok_or_else(|| ApiError::NotFound("Account not found".to_string()))?;

            // 更新账户余额
            match trans_data.transaction_type {
                TransactionType::Income => *account_balance += trans_data.amount,
                TransactionType::Expense => *account_balance -= trans_data.amount,
                TransactionType::Transfer => *account_balance -= trans_data.amount,
            }

            // 插入交易
            let transaction: Transaction = sqlx::query_as(
                r#"
                INSERT INTO transactions (
                    id, ledger_id, account_id, transaction_date, amount,
                    transaction_type, category_id, category_name, payee,
                    notes, status, created_at, updated_at
                ) VALUES (
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, NOW(), NOW()
                )
                RETURNING *
                "#,
            )
            .bind(Uuid::new_v4())
            .bind(trans_data.ledger_id)
            .bind(trans_data.account_id)
            .bind(trans_data.transaction_date)
            .bind(trans_data.amount)
            .bind(trans_data.transaction_type)
            .bind(trans_data.category_id)
            .bind(trans_data.category_name)
            .bind(trans_data.payee)
            .bind(trans_data.notes)
            .bind(trans_data.status)
            .fetch_one(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            created_transactions.push(transaction);
        }

        // 批量更新账户余额
        for (account_id, new_balance) in account_balances {
            sqlx::query(
                "UPDATE accounts SET current_balance = $1, updated_at = NOW() WHERE id = $2",
            )
            .bind(new_balance)
            .bind(account_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        }

        tx.commit()
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        Ok(created_transactions)
    }

    /// 智能分类交易
    pub async fn auto_categorize(&self, transaction_id: Uuid) -> ApiResult<Option<Uuid>> {
        // 获取交易信息
        let transaction: Option<(String, Option<String>, f64)> =
            sqlx::query_as("SELECT payee, notes, amount FROM transactions WHERE id = $1")
                .bind(transaction_id)
                .fetch_optional(&self.pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let (payee, notes, amount) =
            transaction.ok_or_else(|| ApiError::NotFound("Transaction not found".to_string()))?;

        // 查找匹配的规则
        let rule: Option<(Uuid, Uuid)> = sqlx::query_as(
            r#"
            SELECT id, category_id FROM rules
            WHERE is_active = true
            AND (
                (rule_type = 'payee' AND conditions->>'payee' = $1)
                OR (rule_type = 'keyword' AND $2 LIKE '%' || conditions->>'keyword' || '%')
                OR (rule_type = 'amount' AND $3 BETWEEN 
                    (conditions->>'min_amount')::numeric AND 
                    (conditions->>'max_amount')::numeric)
            )
            ORDER BY priority DESC
            LIMIT 1
            "#,
        )
        .bind(payee)
        .bind(notes.unwrap_or_else(String::new))
        .bind(amount)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        if let Some((rule_id, category_id)) = rule {
            // 更新交易分类
            sqlx::query(
                "UPDATE transactions SET category_id = $1, updated_at = NOW() WHERE id = $2",
            )
            .bind(category_id)
            .bind(transaction_id)
            .execute(&self.pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            // 记录规则匹配
            sqlx::query(
                r#"
                INSERT INTO rule_matches (id, rule_id, transaction_id, matched_at)
                VALUES ($1, $2, $3, NOW())
                "#,
            )
            .bind(Uuid::new_v4())
            .bind(rule_id)
            .bind(transaction_id)
            .execute(&self.pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            Ok(Some(category_id))
        } else {
            Ok(None)
        }
    }

    /// 获取交易统计
    pub async fn get_statistics(
        &self,
        ledger_id: Uuid,
        start_date: DateTime<Utc>,
        end_date: DateTime<Utc>,
    ) -> ApiResult<TransactionStatistics> {
        let stats = sqlx::query_as::<_, TransactionStatistics>(
            r#"
            SELECT 
                COUNT(*) as total_count,
                SUM(CASE WHEN transaction_type = 'income' THEN amount ELSE 0 END) as total_income,
                SUM(CASE WHEN transaction_type = 'expense' THEN amount ELSE 0 END) as total_expense,
                SUM(CASE WHEN transaction_type = 'income' THEN amount ELSE -amount END) as net_amount,
                AVG(CASE WHEN transaction_type = 'expense' THEN amount END) as avg_expense,
                MAX(CASE WHEN transaction_type = 'expense' THEN amount END) as max_expense,
                COUNT(DISTINCT DATE(transaction_date)) as active_days
            FROM transactions
            WHERE ledger_id = $1
            AND transaction_date BETWEEN $2 AND $3
            AND status = 'cleared'
            "#
        )
        .bind(ledger_id)
        .bind(start_date)
        .bind(end_date)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        Ok(stats)
    }
}

#[derive(Debug, sqlx::FromRow)]
pub struct TransactionStatistics {
    pub total_count: i64,
    pub total_income: Option<f64>,
    pub total_expense: Option<f64>,
    pub net_amount: Option<f64>,
    pub avg_expense: Option<f64>,
    pub max_expense: Option<f64>,
    pub active_days: Option<i64>,
}
