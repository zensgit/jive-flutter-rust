use super::*;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// Balance entity - based on Maybe's balance.rb
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Balance {
    pub id: Uuid,
    pub account_id: Uuid,
    pub date: NaiveDate,
    pub balance: Decimal,
    pub currency: String,
    pub cash_balance: Option<Decimal>,
    pub holdings_value: Option<Decimal>, // For investment accounts
    pub is_materialized: bool,           // Whether this is a calculated or actual balance
    pub is_synced: bool,                 // Whether this came from external sync
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Entity for Balance {
    type Id = Uuid;

    fn id(&self) -> Self::Id {
        self.id
    }

    fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }

    fn updated_at(&self) -> DateTime<Utc> {
        self.updated_at
    }
}

impl Balance {
    pub fn new(account_id: Uuid, date: NaiveDate, balance: Decimal, currency: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            account_id,
            date,
            balance,
            currency,
            cash_balance: None,
            holdings_value: None,
            is_materialized: false,
            is_synced: false,
            created_at: now,
            updated_at: now,
        }
    }

    pub fn with_cash_balance(mut self, cash_balance: Decimal) -> Self {
        self.cash_balance = Some(cash_balance);
        self
    }

    pub fn with_holdings_value(mut self, holdings_value: Decimal) -> Self {
        self.holdings_value = Some(holdings_value);
        self
    }

    pub fn mark_as_materialized(mut self) -> Self {
        self.is_materialized = true;
        self
    }

    pub fn mark_as_synced(mut self) -> Self {
        self.is_synced = true;
        self
    }
}

// BalanceCalculator - implements Maybe's balance calculation strategies
pub enum BalanceStrategy {
    Forward, // Calculate from oldest to newest
    Reverse, // Calculate from newest to oldest (for linked accounts)
}

pub struct BalanceCalculator {
    pub account_id: Uuid,
    pub strategy: BalanceStrategy,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
}

impl BalanceCalculator {
    pub fn new(account_id: Uuid, strategy: BalanceStrategy) -> Self {
        Self {
            account_id,
            strategy,
            start_date: None,
            end_date: None,
        }
    }

    pub fn with_date_range(mut self, start: NaiveDate, end: NaiveDate) -> Self {
        self.start_date = Some(start);
        self.end_date = Some(end);
        self
    }

    // Calculate balances based on transactions
    pub async fn calculate(&self, pool: &sqlx::PgPool) -> Result<Vec<Balance>, sqlx::Error> {
        match self.strategy {
            BalanceStrategy::Forward => self.calculate_forward(pool).await,
            BalanceStrategy::Reverse => self.calculate_reverse(pool).await,
        }
    }

    async fn calculate_forward(&self, pool: &sqlx::PgPool) -> Result<Vec<Balance>, sqlx::Error> {
        // Forward calculation: Start from oldest known balance or zero
        // and add up transactions chronologically

        // Get starting balance
        let starting_balance = sqlx::query!(
            r#"
            SELECT balance, date, currency
            FROM balances
            WHERE account_id = $1
            ORDER BY date ASC
            LIMIT 1
            "#,
            self.account_id
        )
        .fetch_optional(pool)
        .await?;

        // Get transactions in chronological order
        let transactions = sqlx::query!(
            r#"
            SELECT e.date, e.amount, e.currency
            FROM entries e
            WHERE e.account_id = $1
            ORDER BY e.date ASC, e.created_at ASC
            "#,
            self.account_id
        )
        .fetch_all(pool)
        .await?;

        let mut balances = Vec::new();
        let mut running_balance = starting_balance
            .as_ref()
            .map(|b| b.balance)
            .unwrap_or(Decimal::ZERO);

        let currency = starting_balance
            .as_ref()
            .map(|b| b.currency.clone())
            .unwrap_or_else(|| "USD".to_string());

        // Calculate daily balances
        for transaction in transactions {
            running_balance += transaction.amount;

            let balance = Balance::new(
                self.account_id,
                transaction.date,
                running_balance,
                currency.clone(),
            )
            .mark_as_materialized();

            balances.push(balance);
        }

        Ok(balances)
    }

    async fn calculate_reverse(&self, pool: &sqlx::PgPool) -> Result<Vec<Balance>, sqlx::Error> {
        // Reverse calculation: Start from latest known balance
        // and subtract transactions going backwards

        // Get latest balance
        let latest_balance = sqlx::query!(
            r#"
            SELECT balance, date, currency
            FROM balances
            WHERE account_id = $1
            ORDER BY date DESC
            LIMIT 1
            "#,
            self.account_id
        )
        .fetch_optional(pool)
        .await?;

        // Get transactions in reverse chronological order
        let transactions = sqlx::query!(
            r#"
            SELECT e.date, e.amount, e.currency
            FROM entries e
            WHERE e.account_id = $1
            ORDER BY e.date DESC, e.created_at DESC
            "#,
            self.account_id
        )
        .fetch_all(pool)
        .await?;

        let mut balances = Vec::new();
        let mut running_balance = latest_balance
            .as_ref()
            .map(|b| b.balance)
            .unwrap_or(Decimal::ZERO);

        let currency = latest_balance
            .as_ref()
            .map(|b| b.currency.clone())
            .unwrap_or_else(|| "USD".to_string());

        // Calculate daily balances going backwards
        for transaction in transactions {
            running_balance -= transaction.amount;

            let balance = Balance::new(
                self.account_id,
                transaction.date,
                running_balance,
                currency.clone(),
            )
            .mark_as_materialized();

            balances.push(balance);
        }

        // Reverse to get chronological order
        balances.reverse();

        Ok(balances)
    }
}

// BalanceTrend - for calculating balance trends
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BalanceTrend {
    pub date: NaiveDate,
    pub balance: Decimal,
    pub change_amount: Decimal,
    pub change_percentage: Decimal,
    pub currency: String,
}

pub struct BalanceTrendCalculator {
    pub account_id: Uuid,
    pub period_days: i32,
}

impl BalanceTrendCalculator {
    pub fn new(account_id: Uuid, period_days: i32) -> Self {
        Self {
            account_id,
            period_days,
        }
    }

    pub async fn calculate(&self, pool: &sqlx::PgPool) -> Result<Vec<BalanceTrend>, sqlx::Error> {
        let balances = sqlx::query!(
            r#"
            SELECT date, balance, currency
            FROM balances
            WHERE account_id = $1
            ORDER BY date DESC
            LIMIT $2
            "#,
            self.account_id,
            self.period_days
        )
        .fetch_all(pool)
        .await?;

        let mut trends = Vec::new();

        for i in 0..balances.len() {
            let current = &balances[i];
            let previous = if i + 1 < balances.len() {
                Some(&balances[i + 1])
            } else {
                None
            };

            let change_amount = if let Some(prev) = previous {
                current.balance - prev.balance
            } else {
                Decimal::ZERO
            };

            let change_percentage = if let Some(prev) = previous {
                if prev.balance != Decimal::ZERO {
                    (change_amount / prev.balance) * Decimal::from(100)
                } else {
                    Decimal::ZERO
                }
            } else {
                Decimal::ZERO
            };

            trends.push(BalanceTrend {
                date: current.date,
                balance: current.balance,
                change_amount,
                change_percentage,
                currency: current.currency.clone(),
            });
        }

        trends.reverse();
        Ok(trends)
    }
}
