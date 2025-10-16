use super::*;
use crate::infrastructure::entities::account::*;
use crate::infrastructure::entities::{AccountClassification, AccountStatus, Entity};
use async_trait::async_trait;
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde_json;
use sqlx::{PgConnection, PgPool, Row};
use uuid::Uuid;

pub struct AccountRepository {
    pool: Arc<PgPool>,
}

impl AccountRepository {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }
    
    // Find all accounts for a family
    pub async fn find_by_family(&self, family_id: Uuid) -> Result<Vec<Account>, RepositoryError> {
        let accounts = sqlx::query_as::<_, Account>(
            r#"
            SELECT 
                a.id,
                a.ledger_id as ledger_id,
                a.name,
                a.accountable_type,
                a.accountable_id,
                a.subtype,
                a.balance,
                a.balance_currency,
                a.currency,
                a.cash_balance,
                a.status,
                a.description,
                a.include_in_net_worth,
                a.plaid_account_id,
                a.import_id,
                a.locked_attributes,
                a.created_at,
                a.updated_at
            FROM accounts a
            JOIN ledgers l ON l.id = a.ledger_id
            WHERE l.family_id = $1
            ORDER BY a.name
            "#,
            family_id
        )
        .fetch_all(&*self.pool)
        .await?;
        
        Ok(accounts)
    }
    
    // Find accounts by type
    pub async fn find_by_type(
        &self, 
        family_id: Uuid, 
        accountable_type: &str
    ) -> Result<Vec<Account>, RepositoryError> {
        let accounts = sqlx::query_as::<_, Account>(
            r#"
            SELECT 
                a.id,
                a.ledger_id as ledger_id,
                a.name,
                a.accountable_type,
                a.accountable_id,
                a.subtype,
                a.balance,
                a.balance_currency,
                a.currency,
                a.cash_balance,
                a.status,
                a.description,
                a.include_in_net_worth,
                a.plaid_account_id,
                a.import_id,
                a.locked_attributes,
                a.created_at,
                a.updated_at
            FROM accounts a
            JOIN ledgers l ON l.id = a.ledger_id
            WHERE l.family_id = $1 AND a.accountable_type = $2
            ORDER BY a.name
            "#,
            family_id,
            accountable_type
        )
        .fetch_all(&*self.pool)
        .await?;
        
        Ok(accounts)
    }
    
    // Create account with polymorphic accountable
    pub async fn create_with_depository(
        &self,
        account: Account,
        depository: Depository,
    ) -> Result<Account, RepositoryError> {
        let mut tx = self.pool.begin().await?;
        
        // First create the depository
        let depository_id = depository.save(&mut tx).await?;
        
        // Then create the account
        let created_account = sqlx::query_as::<_, Account>(
            r#"
            INSERT INTO accounts (
                id, family_id, name, accountable_type, accountable_id,
                subtype, balance, balance_currency, currency,
                cash_balance, status, description, include_in_net_worth,
                locked_attributes, created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
            RETURNING *
            "#,
            account.id,
            account.family_id,
            account.name,
            Depository::TYPE_NAME,
            depository_id,
            account.subtype,
            account.balance,
            account.balance_currency,
            account.currency,
            account.cash_balance,
            account.status,
            account.description,
            account.include_in_net_worth,
            account.locked_attributes,
            account.created_at,
            account.updated_at
        )
        .fetch_one(&mut *tx)
        .await?;
        
        tx.commit().await?;
        
        Ok(created_account)
    }
    
    // Create account with credit card
    pub async fn create_with_credit_card(
        &self,
        account: Account,
        credit_card: CreditCard,
    ) -> Result<Account, RepositoryError> {
        let mut tx = self.pool.begin().await?;
        
        let credit_card_id = credit_card.save(&mut tx).await?;
        
        let created_account = sqlx::query_as::<_, Account>(
            r#"
            INSERT INTO accounts (
                id, family_id, name, accountable_type, accountable_id,
                subtype, balance, balance_currency, currency,
                cash_balance, status, description, include_in_net_worth,
                locked_attributes, created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
            RETURNING *
            "#,
            account.id,
            account.family_id,
            account.name,
            CreditCard::TYPE_NAME,
            credit_card_id,
            account.subtype,
            account.balance,
            account.balance_currency,
            account.currency,
            account.cash_balance,
            account.status,
            account.description,
            account.include_in_net_worth,
            account.locked_attributes,
            account.created_at,
            account.updated_at
        )
        .fetch_one(&mut *tx)
        .await?;
        
        tx.commit().await?;
        
        Ok(created_account)
    }
    
    // Create account with investment
    pub async fn create_with_investment(
        &self,
        account: Account,
        investment: Investment,
    ) -> Result<Account, RepositoryError> {
        let mut tx = self.pool.begin().await?;
        
        let investment_id = investment.save(&mut tx).await?;
        
        let created_account = sqlx::query_as::<_, Account>(
            r#"
            INSERT INTO accounts (
                id, family_id, name, accountable_type, accountable_id,
                subtype, balance, balance_currency, currency,
                cash_balance, status, description, include_in_net_worth,
                locked_attributes, created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
            RETURNING *
            "#,
            account.id,
            account.family_id,
            account.name,
            Investment::TYPE_NAME,
            investment_id,
            account.subtype,
            account.balance,
            account.balance_currency,
            account.currency,
            account.cash_balance,
            account.status,
            account.description,
            account.include_in_net_worth,
            account.locked_attributes,
            account.created_at,
            account.updated_at
        )
        .fetch_one(&mut *tx)
        .await?;
        
        tx.commit().await?;
        
        Ok(created_account)
    }
    
    // Update account balance
    pub async fn update_balance(
        &self,
        account_id: Uuid,
        new_balance: Decimal,
        _currency: Option<String>,
    ) -> Result<Account, RepositoryError> {
        // Align with API schema: write to current_balance; rebuild Account via projection
        let now = Utc::now();
        let updated = sqlx::query_as!(
            Account,
            r#"
            WITH updated AS (
                UPDATE accounts
                SET current_balance = $2,
                    updated_at = $3
                WHERE id = $1
                RETURNING *
            )
            SELECT 
                u.id,
                u.ledger_id as "ledger_id: Uuid",
                u.name,
                ''::text as accountable_type,
                gen_random_uuid() as "accountable_id: Uuid",
                NULL::text as subtype,
                u.current_balance as "balance: Option<Decimal>",
                NULL::text as balance_currency,
                u.currency,
                NULL::numeric as "cash_balance: Option<Decimal>",
                u.status,
                u.description,
                TRUE as include_in_net_worth,
                NULL::uuid as "plaid_account_id: Option<Uuid>",
                NULL::uuid as "import_id: Option<Uuid>",
                '{}'::jsonb as locked_attributes,
                u.created_at,
                u.updated_at
            FROM updated u
            "#,
            account_id,
            new_balance,
            now
        )
        .fetch_one(&*self.pool)
        .await?;

        Ok(updated)
    }
    
    // Update account status
    pub async fn update_status(
        &self,
        account_id: Uuid,
        status: &str,
    ) -> Result<Account, RepositoryError> {
        // Align with API schema: update status; rebuild Account via projection
        let now = Utc::now();
        let updated = sqlx::query_as!(
            Account,
            r#"
            WITH updated AS (
                UPDATE accounts
                SET status = $2,
                    updated_at = $3
                WHERE id = $1
                RETURNING *
            )
            SELECT 
                u.id,
                u.ledger_id as "ledger_id: Uuid",
                u.name,
                ''::text as accountable_type,
                gen_random_uuid() as "accountable_id: Uuid",
                NULL::text as subtype,
                u.current_balance as "balance: Option<Decimal>",
                NULL::text as balance_currency,
                u.currency,
                NULL::numeric as "cash_balance: Option<Decimal>",
                u.status,
                u.description,
                TRUE as include_in_net_worth,
                NULL::uuid as "plaid_account_id: Option<Uuid>",
                NULL::uuid as "import_id: Option<Uuid>",
                '{}'::jsonb as locked_attributes,
                u.created_at,
                u.updated_at
            FROM updated u
            "#,
            account_id,
            status,
            now
        )
        .fetch_one(&*self.pool)
        .await?;

        Ok(updated)
    }
    
    // Get account with accountable details
    pub async fn find_with_details(&self, account_id: Uuid) -> Result<AccountWithDetails, RepositoryError> {
        let account = sqlx::query_as::<_, Account>(
            "SELECT * FROM accounts WHERE id = $1",
            account_id
        )
        .fetch_optional(&*self.pool)
        .await?
        .ok_or(RepositoryError::NotFound)?;
        
        let details = match account.accountable_type.as_str() {
            "Depository" => {
                let depository = Depository::load(account.accountable_id, &self.pool).await?;
                AccountDetails::Depository(depository)
            }
            "CreditCard" => {
                let credit_card = CreditCard::load(account.accountable_id, &self.pool).await?;
                AccountDetails::CreditCard(credit_card)
            }
            "Investment" => {
                let investment = Investment::load(account.accountable_id, &self.pool).await?;
                AccountDetails::Investment(investment)
            }
            "Property" => {
                let property = Property::load(account.accountable_id, &self.pool).await?;
                AccountDetails::Property(property)
            }
            "Loan" => {
                let loan = Loan::load(account.accountable_id, &self.pool).await?;
                AccountDetails::Loan(loan)
            }
            _ => AccountDetails::Other,
        };
        
        Ok(AccountWithDetails { account, details })
    }
    
    // Calculate net worth for a family
    pub async fn calculate_net_worth(&self, family_id: Uuid) -> Result<NetWorth, RepositoryError> {
        let result = sqlx::query!(
            r#"
            SELECT 
                COALESCE(SUM(CASE WHEN a.accountable_type IN ('Depository', 'Investment', 'Property', 'Crypto', 'OtherAsset') 
                    THEN a.balance ELSE 0 END), 0) as assets,
                COALESCE(SUM(CASE WHEN a.accountable_type IN ('CreditCard', 'Loan', 'OtherLiability') 
                    THEN ABS(a.balance) ELSE 0 END), 0) as liabilities
            FROM accounts a
            JOIN ledgers l ON l.id = a.ledger_id
            WHERE l.family_id = $1 
                AND a.include_in_net_worth = true
                AND a.status != 'error'
            "#,
            family_id
        )
        .fetch_one(&*self.pool)
        .await?;
        
        let assets = Decimal::from_str(&result.assets.unwrap_or(0).to_string()).unwrap_or(Decimal::ZERO);
        let liabilities = Decimal::from_str(&result.liabilities.unwrap_or(0).to_string()).unwrap_or(Decimal::ZERO);
        
        Ok(NetWorth {
            assets,
            liabilities,
            total: assets - liabilities,
        })
    }
}

#[async_trait]
impl Repository<Account> for AccountRepository {
    type Error = RepositoryError;
    
    async fn find_by_id(&self, id: Uuid) -> Result<Option<Account>, Self::Error> {
        let account = sqlx::query_as!(
            Account,
            "SELECT * FROM accounts WHERE id = $1",
            id
        )
        .fetch_optional(&*self.pool)
        .await?;
        
        Ok(account)
    }
    
    async fn find_all(&self) -> Result<Vec<Account>, Self::Error> {
        let accounts = sqlx::query_as::<_, Account>(
            "SELECT * FROM accounts ORDER BY name"
        )
        .fetch_all(&*self.pool)
        .await?;
        
        Ok(accounts)
    }
    
    async fn create(&self, entity: Account) -> Result<Account, Self::Error> {
        let created = sqlx::query_as!(
            Account,
            r#"
            INSERT INTO accounts (
                id, family_id, name, accountable_type, accountable_id,
                subtype, balance, balance_currency, currency,
                cash_balance, status, description, include_in_net_worth,
                locked_attributes, created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
            RETURNING *
            "#,
            entity.id,
            entity.family_id,
            entity.name,
            entity.accountable_type,
            entity.accountable_id,
            entity.subtype,
            entity.balance,
            entity.balance_currency,
            entity.currency,
            entity.cash_balance,
            entity.status,
            entity.description,
            entity.include_in_net_worth,
            entity.locked_attributes,
            entity.created_at,
            entity.updated_at
        )
        .fetch_one(&*self.pool)
        .await?;
        
        Ok(created)
    }
    
    async fn update(&self, entity: Account) -> Result<Account, Self::Error> {
        let updated = sqlx::query_as!(
            Account,
            r#"
            UPDATE accounts 
            SET 
                name = $2,
                subtype = $3,
                balance = $4,
                balance_currency = $5,
                currency = $6,
                cash_balance = $7,
                status = $8,
                description = $9,
                include_in_net_worth = $10,
                locked_attributes = $11,
                updated_at = $12
            WHERE id = $1
            RETURNING *
            "#,
            entity.id,
            entity.name,
            entity.subtype,
            entity.balance,
            entity.balance_currency,
            entity.currency,
            entity.cash_balance,
            entity.status,
            entity.description,
            entity.include_in_net_worth,
            entity.locked_attributes,
            Utc::now()
        )
        .fetch_one(&*self.pool)
        .await?;
        
        Ok(updated)
    }
    
    async fn delete(&self, id: Uuid) -> Result<bool, Self::Error> {
        let result = sqlx::query!(
            "DELETE FROM accounts WHERE id = $1",
            id
        )
        .execute(&*self.pool)
        .await?;
        
        Ok(result.rows_affected() > 0)
    }
}

// Helper structs
#[derive(Debug, Clone)]
pub struct AccountWithDetails {
    pub account: Account,
    pub details: AccountDetails,
}

#[derive(Debug, Clone)]
pub enum AccountDetails {
    Depository(Depository),
    CreditCard(CreditCard),
    Investment(Investment),
    Property(Property),
    Loan(Loan),
    Other,
}

#[derive(Debug, Clone)]
pub struct NetWorth {
    pub assets: Decimal,
    pub liabilities: Decimal,
    pub total: Decimal,
}

use rust_decimal::prelude::FromStr;
