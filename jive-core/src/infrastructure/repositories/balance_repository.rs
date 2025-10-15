use super::*;
use crate::infrastructure::entities::balance::Balance;
use async_trait::async_trait;
use sqlx::{postgres::PgRow, PgPool, Row};
use std::sync::Arc;
use uuid::Uuid;

pub struct BalanceRepository {
    pool: Arc<PgPool>,
}

impl BalanceRepository {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }

    pub async fn find_by_account(&self, account_id: Uuid) -> Result<Vec<Balance>, RepositoryError> {
        let rows = sqlx::query(
            r#"
            SELECT id, account_id, date, balance, currency,
                   cash_balance, holdings_value, is_materialized, is_synced,
                   created_at, updated_at
            FROM balances WHERE account_id = $1 ORDER BY date DESC
            "#,
        )
        .bind(account_id)
        .fetch_all(&*self.pool)
        .await?;

        Ok(rows.into_iter().map(map_balance).collect())
    }
}

fn map_balance(row: PgRow) -> Balance {
    Balance {
        id: row.get("id"),
        account_id: row.get("account_id"),
        date: row.get("date"),
        balance: row.get("balance"),
        currency: row.get("currency"),
        cash_balance: row.get("cash_balance"),
        holdings_value: row.get("holdings_value"),
        is_materialized: row.get("is_materialized"),
        is_synced: row.get("is_synced"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    }
}

#[async_trait]
impl Repository<Balance> for BalanceRepository {
    type Error = RepositoryError;

    async fn find_by_id(&self, id: Uuid) -> Result<Option<Balance>, Self::Error> {
        let row = sqlx::query(
            r#"
            SELECT id, account_id, date, balance, currency,
                   cash_balance, holdings_value, is_materialized, is_synced,
                   created_at, updated_at
            FROM balances WHERE id = $1
            "#,
        )
        .bind(id)
        .fetch_optional(&*self.pool)
        .await?;

        Ok(row.map(map_balance))
    }

    async fn find_all(&self) -> Result<Vec<Balance>, Self::Error> {
        let rows = sqlx::query(
            r#"
            SELECT id, account_id, date, balance, currency,
                   cash_balance, holdings_value, is_materialized, is_synced,
                   created_at, updated_at
            FROM balances ORDER BY date DESC
            "#,
        )
        .fetch_all(&*self.pool)
        .await?;
        Ok(rows.into_iter().map(map_balance).collect())
    }

    async fn create(&self, entity: Balance) -> Result<Balance, Self::Error> {
        let row = sqlx::query(
            r#"
            INSERT INTO balances (
              id, account_id, date, balance, currency,
              cash_balance, holdings_value, is_materialized, is_synced,
              created_at, updated_at
            ) VALUES (
              $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11
            ) RETURNING id, account_id, date, balance, currency,
                      cash_balance, holdings_value, is_materialized, is_synced,
                      created_at, updated_at
            "#,
        )
        .bind(entity.id)
        .bind(entity.account_id)
        .bind(entity.date)
        .bind(entity.balance)
        .bind(&entity.currency)
        .bind(&entity.cash_balance)
        .bind(&entity.holdings_value)
        .bind(entity.is_materialized)
        .bind(entity.is_synced)
        .bind(entity.created_at)
        .bind(entity.updated_at)
        .fetch_one(&*self.pool)
        .await?;
        Ok(map_balance(row))
    }

    async fn update(&self, entity: Balance) -> Result<Balance, Self::Error> {
        let row = sqlx::query(
            r#"
            UPDATE balances SET
              account_id=$2, date=$3, balance=$4, currency=$5,
              cash_balance=$6, holdings_value=$7, is_materialized=$8, is_synced=$9,
              updated_at=$10
            WHERE id=$1
            RETURNING id, account_id, date, balance, currency,
                      cash_balance, holdings_value, is_materialized, is_synced,
                      created_at, updated_at
            "#,
        )
        .bind(entity.id)
        .bind(entity.account_id)
        .bind(entity.date)
        .bind(entity.balance)
        .bind(&entity.currency)
        .bind(&entity.cash_balance)
        .bind(&entity.holdings_value)
        .bind(entity.is_materialized)
        .bind(entity.is_synced)
        .bind(entity.updated_at)
        .fetch_one(&*self.pool)
        .await?;
        Ok(map_balance(row))
    }

    async fn delete(&self, id: Uuid) -> Result<bool, Self::Error> {
        let result = sqlx::query("DELETE FROM balances WHERE id = $1")
            .bind(id)
            .execute(&*self.pool)
            .await?;
        Ok(result.rows_affected() > 0)
    }
}

