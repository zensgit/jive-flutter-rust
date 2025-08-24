// Plaid Service - 银行数据同步服务
// Based on Maybe's Plaid integration patterns

use crate::domain::errors::DomainError;
use crate::infrastructure::entities::account::*;
use crate::infrastructure::entities::transaction::*;
use chrono::{DateTime, Utc, NaiveDate};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use sqlx::PgPool;
use uuid::Uuid;

pub struct PlaidService {
    pool: Arc<PgPool>,
    plaid_client_id: Option<String>,
    plaid_secret: Option<String>,
    plaid_environment: PlaidEnvironment,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PlaidEnvironment {
    Sandbox,
    Development,
    Production,
}

impl PlaidService {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self {
            pool,
            plaid_client_id: std::env::var("PLAID_CLIENT_ID").ok(),
            plaid_secret: std::env::var("PLAID_SECRET").ok(),
            plaid_environment: match std::env::var("PLAID_ENV").as_deref() {
                Ok("production") => PlaidEnvironment::Production,
                Ok("development") => PlaidEnvironment::Development,
                _ => PlaidEnvironment::Sandbox,
            },
        }
    }
    
    // 创建Link Token
    pub async fn create_link_token(
        &self,
        family_id: Uuid,
        user_id: Uuid,
    ) -> Result<PlaidLinkToken, DomainError> {
        if self.plaid_client_id.is_none() || self.plaid_secret.is_none() {
            return Err(DomainError::Configuration("Plaid credentials not configured".to_string()));
        }
        
        // 构建Plaid请求
        let request = PlaidLinkTokenRequest {
            client_id: self.plaid_client_id.clone().unwrap(),
            secret: self.plaid_secret.clone().unwrap(),
            client_name: "Jive Money".to_string(),
            language: "en".to_string(),
            country_codes: vec!["US".to_string()],
            user: PlaidUser {
                client_user_id: user_id.to_string(),
            },
            products: vec!["transactions".to_string(), "accounts".to_string()],
            webhook: Some(format!("https://api.jivemoney.app/plaid/webhook")),
        };
        
        // 调用Plaid API (模拟实现)
        let link_token = PlaidLinkToken {
            link_token: format!("link-sandbox-{}", Uuid::new_v4()),
            expiration: Utc::now() + chrono::Duration::minutes(30),
            request_id: Uuid::new_v4().to_string(),
        };
        
        Ok(link_token)
    }
    
    // 交换Public Token获取Access Token
    pub async fn exchange_public_token(
        &self,
        family_id: Uuid,
        public_token: String,
        institution_id: String,
        accounts: Vec<PlaidAccountInfo>,
    ) -> Result<PlaidItem, DomainError> {
        // 调用Plaid API交换token (模拟实现)
        let access_token = format!("access-sandbox-{}", Uuid::new_v4());
        let item_id = format!("item-sandbox-{}", Uuid::new_v4());
        
        // 创建Plaid Item记录
        let plaid_item = sqlx::query_as!(
            PlaidItem,
            r#"
            INSERT INTO plaid_items (
                id, family_id, plaid_item_id, access_token, 
                institution_id, webhook, status, last_successful_sync,
                last_attempted_sync, created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, 'active', NULL, NULL, $7, $7)
            RETURNING *
            "#,
            Uuid::new_v4(),
            family_id,
            item_id,
            access_token,
            institution_id,
            "https://api.jivemoney.app/plaid/webhook",
            Utc::now()
        )
        .fetch_one(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        // 创建关联的账户
        for account_info in accounts {
            self.create_plaid_account(
                &plaid_item,
                account_info,
            ).await?;
        }
        
        Ok(plaid_item)
    }
    
    // 创建Plaid账户
    async fn create_plaid_account(
        &self,
        plaid_item: &PlaidItem,
        account_info: PlaidAccountInfo,
    ) -> Result<Account, DomainError> {
        // 创建主账户记录
        let account = sqlx::query_as!(
            Account,
            r#"
            INSERT INTO accounts (
                id, family_id, accountable_type, accountable_id, name,
                balance, currency, status, include_in_net_worth,
                created_at, updated_at
            )
            VALUES ($1, $2, 'PlaidAccount', $3, $4, $5, $6, 'active', true, $7, $7)
            RETURNING *
            "#,
            Uuid::new_v4(),
            plaid_item.family_id,
            Uuid::new_v4(),
            account_info.name,
            account_info.balance,
            "USD",
            Utc::now()
        )
        .fetch_one(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        // 创建PlaidAccount记录
        sqlx::query!(
            r#"
            INSERT INTO plaid_accounts (
                id, account_id, plaid_item_id, plaid_account_id,
                name, official_name, type, subtype, mask,
                available_balance, current_balance, currency,
                is_closed, created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, false, $13, $13)
            "#,
            account.accountable_id.unwrap(),
            account.id,
            plaid_item.id,
            account_info.account_id,
            account_info.name,
            account_info.official_name,
            account_info.account_type,
            account_info.subtype,
            account_info.mask,
            account_info.available,
            account_info.balance,
            "USD",
            Utc::now()
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(account)
    }
    
    // 同步账户数据
    pub async fn sync_accounts(
        &self,
        plaid_item_id: Uuid,
    ) -> Result<SyncResult, DomainError> {
        let plaid_item = self.get_plaid_item(plaid_item_id).await?;
        
        // 调用Plaid API获取账户信息
        let plaid_accounts = self.fetch_plaid_accounts(&plaid_item.access_token).await?;
        
        let mut updated_count = 0;
        let mut errors = Vec::new();
        
        for plaid_account in plaid_accounts {
            match self.update_account_balance(&plaid_item, &plaid_account).await {
                Ok(_) => updated_count += 1,
                Err(e) => errors.push(e.to_string()),
            }
        }
        
        // 更新同步状态
        self.update_plaid_item_sync_status(
            plaid_item_id,
            if errors.is_empty() { "success" } else { "partial_failure" },
        ).await?;
        
        Ok(SyncResult {
            total_accounts: plaid_accounts.len() as i32,
            updated_accounts: updated_count,
            total_transactions: 0,
            new_transactions: 0,
            errors,
        })
    }
    
    // 同步交易数据
    pub async fn sync_transactions(
        &self,
        plaid_item_id: Uuid,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
    ) -> Result<SyncResult, DomainError> {
        let plaid_item = self.get_plaid_item(plaid_item_id).await?;
        
        let start_date = start_date.unwrap_or_else(|| 
            chrono::Local::now().naive_local().date() - chrono::Duration::days(30)
        );
        let end_date = end_date.unwrap_or_else(|| 
            chrono::Local::now().naive_local().date()
        );
        
        // 获取Plaid账户
        let plaid_accounts = sqlx::query!(
            r#"
            SELECT pa.plaid_account_id, pa.account_id
            FROM plaid_accounts pa
            WHERE pa.plaid_item_id = $1
            "#,
            plaid_item.id
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let account_ids: Vec<String> = plaid_accounts.iter()
            .map(|pa| pa.plaid_account_id.clone())
            .collect();
        
        // 调用Plaid API获取交易
        let plaid_transactions = self.fetch_plaid_transactions(
            &plaid_item.access_token,
            &account_ids,
            start_date,
            end_date,
        ).await?;
        
        let mut new_transactions = 0;
        let mut errors = Vec::new();
        
        for plaid_transaction in plaid_transactions {
            match self.create_transaction_from_plaid(
                &plaid_item,
                &plaid_accounts,
                plaid_transaction,
            ).await {
                Ok(true) => new_transactions += 1, // 新交易
                Ok(false) => {}, // 已存在的交易
                Err(e) => errors.push(e.to_string()),
            }
        }
        
        Ok(SyncResult {
            total_accounts: plaid_accounts.len() as i32,
            updated_accounts: 0,
            total_transactions: plaid_transactions.len() as i32,
            new_transactions,
            errors,
        })
    }
    
    // 处理Webhook
    pub async fn handle_webhook(
        &self,
        webhook_data: PlaidWebhookData,
    ) -> Result<(), DomainError> {
        match webhook_data.webhook_type.as_str() {
            "TRANSACTIONS" => {
                match webhook_data.webhook_code.as_str() {
                    "INITIAL_UPDATE" | "HISTORICAL_UPDATE" | "DEFAULT_UPDATE" => {
                        // 触发交易同步
                        if let Some(item_id) = self.find_plaid_item_by_plaid_id(&webhook_data.item_id).await? {
                            self.sync_transactions(item_id, None, None).await?;
                        }
                    }
                    "TRANSACTIONS_REMOVED" => {
                        // 处理已删除的交易
                        self.handle_removed_transactions(&webhook_data).await?;
                    }
                    _ => {}
                }
            }
            "ITEM" => {
                match webhook_data.webhook_code.as_str() {
                    "ERROR" => {
                        // 处理Item错误
                        if let Some(item_id) = self.find_plaid_item_by_plaid_id(&webhook_data.item_id).await? {
                            self.update_plaid_item_sync_status(item_id, "error").await?;
                        }
                    }
                    "PENDING_EXPIRATION" => {
                        // 处理即将过期的访问令牌
                        // 在实际实现中，可能需要通知用户重新授权
                    }
                    _ => {}
                }
            }
            _ => {}
        }
        
        Ok(())
    }
    
    // 删除Plaid Item
    pub async fn remove_plaid_item(
        &self,
        plaid_item_id: Uuid,
    ) -> Result<(), DomainError> {
        let plaid_item = self.get_plaid_item(plaid_item_id).await?;
        
        // 调用Plaid API删除Item
        self.remove_plaid_item_api(&plaid_item.access_token).await?;
        
        // 软删除本地Plaid账户
        sqlx::query!(
            r#"
            UPDATE accounts 
            SET status = 'closed', updated_at = $1
            WHERE id IN (
                SELECT pa.account_id 
                FROM plaid_accounts pa 
                WHERE pa.plaid_item_id = $2
            )
            "#,
            Utc::now(),
            plaid_item_id
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        // 删除Plaid Item
        sqlx::query!(
            "UPDATE plaid_items SET status = 'deleted', updated_at = $1 WHERE id = $2",
            Utc::now(),
            plaid_item_id
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(())
    }
    
    // 获取机构信息
    pub async fn get_institution(
        &self,
        institution_id: &str,
    ) -> Result<PlaidInstitution, DomainError> {
        // 调用Plaid API获取机构信息 (模拟实现)
        Ok(PlaidInstitution {
            institution_id: institution_id.to_string(),
            name: "Chase Bank".to_string(),
            products: vec!["transactions".to_string(), "accounts".to_string()],
            country_codes: vec!["US".to_string()],
            url: Some("https://www.chase.com".to_string()),
            primary_color: Some("#117ACA".to_string()),
            logo: Some("https://plaid.com/assets/img/institution-logos/chase.png".to_string()),
        })
    }
    
    // 重新验证账户
    pub async fn refresh_accounts(
        &self,
        plaid_item_id: Uuid,
    ) -> Result<(), DomainError> {
        let plaid_item = self.get_plaid_item(plaid_item_id).await?;
        
        // 调用Plaid API刷新账户
        self.refresh_plaid_accounts(&plaid_item.access_token).await?;
        
        // 重新同步账户和交易
        self.sync_accounts(plaid_item_id).await?;
        self.sync_transactions(plaid_item_id, None, None).await?;
        
        Ok(())
    }
    
    // 获取账户持有信息（投资账户）
    pub async fn sync_holdings(
        &self,
        plaid_item_id: Uuid,
    ) -> Result<Vec<PlaidHolding>, DomainError> {
        let plaid_item = self.get_plaid_item(plaid_item_id).await?;
        
        // 调用Plaid API获取持仓信息
        let holdings = self.fetch_plaid_holdings(&plaid_item.access_token).await?;
        
        // 同步到本地数据库
        for holding in &holdings {
            self.create_or_update_holding(&plaid_item, holding).await?;
        }
        
        Ok(holdings)
    }
    
    // 辅助方法
    
    async fn get_plaid_item(&self, plaid_item_id: Uuid) -> Result<PlaidItem, DomainError> {
        sqlx::query_as!(
            PlaidItem,
            "SELECT * FROM plaid_items WHERE id = $1 AND status != 'deleted'",
            plaid_item_id
        )
        .fetch_one(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))
    }
    
    async fn find_plaid_item_by_plaid_id(&self, plaid_item_id: &str) -> Result<Option<Uuid>, DomainError> {
        let result = sqlx::query!(
            "SELECT id FROM plaid_items WHERE plaid_item_id = $1 AND status != 'deleted'",
            plaid_item_id
        )
        .fetch_optional(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(result.map(|r| r.id))
    }
    
    async fn fetch_plaid_accounts(&self, access_token: &str) -> Result<Vec<PlaidAccountData>, DomainError> {
        // 模拟Plaid API调用
        Ok(vec![
            PlaidAccountData {
                account_id: "plaid-acc-123".to_string(),
                name: "Chase Checking".to_string(),
                official_name: Some("Chase Total Checking®".to_string()),
                account_type: "depository".to_string(),
                subtype: "checking".to_string(),
                mask: Some("0000".to_string()),
                balances: PlaidBalance {
                    available: Some(Decimal::from_str("1234.56").unwrap()),
                    current: Decimal::from_str("1234.56").unwrap(),
                    limit: None,
                    iso_currency_code: "USD".to_string(),
                },
            }
        ])
    }
    
    async fn fetch_plaid_transactions(
        &self,
        _access_token: &str,
        _account_ids: &[String],
        _start_date: NaiveDate,
        _end_date: NaiveDate,
    ) -> Result<Vec<PlaidTransactionData>, DomainError> {
        // 模拟Plaid API调用
        Ok(vec![
            PlaidTransactionData {
                transaction_id: "plaid-txn-123".to_string(),
                account_id: "plaid-acc-123".to_string(),
                amount: Decimal::from_str("25.50").unwrap(),
                date: chrono::Local::now().naive_local().date(),
                name: "Starbucks Coffee".to_string(),
                merchant_name: Some("Starbucks".to_string()),
                category: vec!["Food and Drink".to_string(), "Restaurants".to_string(), "Coffee Shop".to_string()],
                account_owner: None,
                pending: false,
                transaction_type: "place".to_string(),
            }
        ])
    }
    
    async fn update_account_balance(
        &self,
        _plaid_item: &PlaidItem,
        plaid_account: &PlaidAccountData,
    ) -> Result<(), DomainError> {
        sqlx::query!(
            r#"
            UPDATE accounts 
            SET balance = $1, updated_at = $2
            FROM plaid_accounts pa
            WHERE accounts.id = pa.account_id
                AND pa.plaid_account_id = $3
            "#,
            plaid_account.balances.current,
            Utc::now(),
            plaid_account.account_id
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(())
    }
    
    async fn create_transaction_from_plaid(
        &self,
        plaid_item: &PlaidItem,
        plaid_accounts: &[sqlx::postgres::PgRow],
        plaid_transaction: PlaidTransactionData,
    ) -> Result<bool, DomainError> {
        // 查找对应的本地账户
        let account_id = plaid_accounts.iter()
            .find(|pa| pa.get::<String, _>("plaid_account_id") == plaid_transaction.account_id)
            .map(|pa| pa.get::<Uuid, _>("account_id"))
            .ok_or_else(|| DomainError::NotFound(
                format!("Account not found for Plaid account {}", plaid_transaction.account_id)
            ))?;
        
        // 检查交易是否已存在
        let existing = sqlx::query!(
            "SELECT id FROM plaid_transactions WHERE plaid_transaction_id = $1",
            plaid_transaction.transaction_id
        )
        .fetch_optional(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        if existing.is_some() {
            return Ok(false); // 交易已存在
        }
        
        // 创建Entry
        let entry_id = Uuid::new_v4();
        sqlx::query!(
            r#"
            INSERT INTO entries (
                id, account_id, name, amount, currency, date, 
                entryable_type, entryable_id, created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, 'USD', $5, 'Transaction', $6, $7, $7)
            "#,
            entry_id,
            account_id,
            plaid_transaction.name,
            -plaid_transaction.amount, // Plaid金额为正表示支出
            plaid_transaction.date,
            Uuid::new_v4(),
            Utc::now()
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        // 创建Transaction
        let transaction_id = Uuid::new_v4();
        sqlx::query!(
            r#"
            INSERT INTO transactions (
                id, entry_id, created_at, updated_at
            )
            VALUES ($1, $2, $3, $3)
            "#,
            transaction_id,
            entry_id,
            Utc::now()
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        // 创建PlaidTransaction记录
        sqlx::query!(
            r#"
            INSERT INTO plaid_transactions (
                id, plaid_item_id, plaid_account_id, plaid_transaction_id,
                transaction_id, name, amount, date, category,
                merchant_name, pending, created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $12)
            "#,
            Uuid::new_v4(),
            plaid_item.id,
            plaid_transaction.account_id,
            plaid_transaction.transaction_id,
            transaction_id,
            plaid_transaction.name,
            plaid_transaction.amount,
            plaid_transaction.date,
            plaid_transaction.category.join(", "),
            plaid_transaction.merchant_name,
            plaid_transaction.pending,
            Utc::now()
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(true) // 新交易
    }
    
    async fn update_plaid_item_sync_status(
        &self,
        plaid_item_id: Uuid,
        status: &str,
    ) -> Result<(), DomainError> {
        let now = Utc::now();
        
        sqlx::query!(
            r#"
            UPDATE plaid_items 
            SET status = $1, last_attempted_sync = $2, updated_at = $2
            WHERE id = $3
            "#,
            status,
            now,
            plaid_item_id
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        if status == "success" {
            sqlx::query!(
                "UPDATE plaid_items SET last_successful_sync = $1 WHERE id = $2",
                now,
                plaid_item_id
            )
            .execute(&*self.pool)
            .await
            .map_err(|e| DomainError::Database(e.to_string()))?;
        }
        
        Ok(())
    }
    
    async fn handle_removed_transactions(&self, _webhook_data: &PlaidWebhookData) -> Result<(), DomainError> {
        // 处理Plaid报告的已删除交易
        // 在实际实现中，需要根据webhook中的transaction_ids删除对应的本地交易
        Ok(())
    }
    
    async fn remove_plaid_item_api(&self, _access_token: &str) -> Result<(), DomainError> {
        // 调用Plaid API删除Item
        Ok(())
    }
    
    async fn refresh_plaid_accounts(&self, _access_token: &str) -> Result<(), DomainError> {
        // 调用Plaid API刷新账户
        Ok(())
    }
    
    async fn fetch_plaid_holdings(&self, _access_token: &str) -> Result<Vec<PlaidHolding>, DomainError> {
        // 模拟获取持仓数据
        Ok(vec![])
    }
    
    async fn create_or_update_holding(&self, _plaid_item: &PlaidItem, _holding: &PlaidHolding) -> Result<(), DomainError> {
        // 创建或更新持仓记录
        Ok(())
    }
}

// DTOs and Entities

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct PlaidItem {
    pub id: Uuid,
    pub family_id: Uuid,
    pub plaid_item_id: String,
    pub access_token: String,
    pub institution_id: String,
    pub webhook: Option<String>,
    pub status: String,
    pub last_successful_sync: Option<DateTime<Utc>>,
    pub last_attempted_sync: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaidLinkToken {
    pub link_token: String,
    pub expiration: DateTime<Utc>,
    pub request_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaidLinkTokenRequest {
    pub client_id: String,
    pub secret: String,
    pub client_name: String,
    pub language: String,
    pub country_codes: Vec<String>,
    pub user: PlaidUser,
    pub products: Vec<String>,
    pub webhook: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaidUser {
    pub client_user_id: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaidAccountInfo {
    pub account_id: String,
    pub name: String,
    pub official_name: Option<String>,
    pub account_type: String,
    pub subtype: String,
    pub mask: Option<String>,
    pub balance: Decimal,
    pub available: Option<Decimal>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaidAccountData {
    pub account_id: String,
    pub name: String,
    pub official_name: Option<String>,
    pub account_type: String,
    pub subtype: String,
    pub mask: Option<String>,
    pub balances: PlaidBalance,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaidBalance {
    pub available: Option<Decimal>,
    pub current: Decimal,
    pub limit: Option<Decimal>,
    pub iso_currency_code: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaidTransactionData {
    pub transaction_id: String,
    pub account_id: String,
    pub amount: Decimal,
    pub date: NaiveDate,
    pub name: String,
    pub merchant_name: Option<String>,
    pub category: Vec<String>,
    pub account_owner: Option<String>,
    pub pending: bool,
    pub transaction_type: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaidWebhookData {
    pub webhook_type: String,
    pub webhook_code: String,
    pub item_id: String,
    pub new_transactions: Option<i32>,
    pub removed_transactions: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaidInstitution {
    pub institution_id: String,
    pub name: String,
    pub products: Vec<String>,
    pub country_codes: Vec<String>,
    pub url: Option<String>,
    pub primary_color: Option<String>,
    pub logo: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlaidHolding {
    pub account_id: String,
    pub security_id: String,
    pub institution_security_id: Option<String>,
    pub quantity: Decimal,
    pub institution_value: Decimal,
    pub cost_basis: Option<Decimal>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SyncResult {
    pub total_accounts: i32,
    pub updated_accounts: i32,
    pub total_transactions: i32,
    pub new_transactions: i32,
    pub errors: Vec<String>,
}

use rust_decimal::prelude::FromStr;