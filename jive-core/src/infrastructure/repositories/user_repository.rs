use super::*;
use crate::infrastructure::entities::user::User;
use async_trait::async_trait;
use sqlx::{postgres::PgRow, PgPool, Row};
use std::sync::Arc;
use uuid::Uuid;

pub struct UserRepository {
    pool: Arc<PgPool>,
}

impl UserRepository {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }

    // Example method: find by email (runtime query to avoid .sqlx)
    pub async fn find_by_email(&self, email: &str) -> Result<Option<User>, RepositoryError> {
        let row = sqlx::query(
            r#"
            SELECT id, family_id, email, first_name, last_name, role,
                   preferences, last_seen_at, last_seen_version,
                   remember_created_at, confirmed_at, confirmation_sent_at,
                   confirmation_token, unconfirmed_email, created_at, updated_at
            FROM users WHERE email = $1
            "#,
        )
        .bind(email)
        .fetch_optional(&*self.pool)
        .await?;

        Ok(row.map(|r| map_user(r)))
    }
}

fn map_user(row: PgRow) -> User {
    User {
        id: row.get("id"),
        family_id: row.get("family_id"),
        email: row.get("email"),
        first_name: row.get("first_name"),
        last_name: row.get("last_name"),
        role: row.get("role"),
        preferences: row.get("preferences"),
        last_seen_at: row.get("last_seen_at"),
        last_seen_version: row.get("last_seen_version"),
        remember_created_at: row.get("remember_created_at"),
        confirmed_at: row.get("confirmed_at"),
        confirmation_sent_at: row.get("confirmation_sent_at"),
        confirmation_token: row.get("confirmation_token"),
        unconfirmed_email: row.get("unconfirmed_email"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    }
}

#[async_trait]
impl Repository<User> for UserRepository {
    type Error = RepositoryError;

    async fn find_by_id(&self, id: Uuid) -> Result<Option<User>, Self::Error> {
        let row = sqlx::query(
            r#"
            SELECT id, family_id, email, first_name, last_name, role,
                   preferences, last_seen_at, last_seen_version,
                   remember_created_at, confirmed_at, confirmation_sent_at,
                   confirmation_token, unconfirmed_email, created_at, updated_at
            FROM users WHERE id = $1
            "#,
        )
        .bind(id)
        .fetch_optional(&*self.pool)
        .await?;

        Ok(row.map(|r| map_user(r)))
    }

    async fn find_all(&self) -> Result<Vec<User>, Self::Error> {
        let rows = sqlx::query(
            r#"
            SELECT id, family_id, email, first_name, last_name, role,
                   preferences, last_seen_at, last_seen_version,
                   remember_created_at, confirmed_at, confirmation_sent_at,
                   confirmation_token, unconfirmed_email, created_at, updated_at
            FROM users ORDER BY created_at DESC
            "#,
        )
        .fetch_all(&*self.pool)
        .await?;

        Ok(rows.into_iter().map(map_user).collect())
    }

    async fn create(&self, entity: User) -> Result<User, Self::Error> {
        let row = sqlx::query(
            r#"
            INSERT INTO users (
              id, family_id, email, first_name, last_name, role,
              preferences, last_seen_at, last_seen_version,
              remember_created_at, confirmed_at, confirmation_sent_at,
              confirmation_token, unconfirmed_email, created_at, updated_at
            ) VALUES (
              $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16
            ) RETURNING id, family_id, email, first_name, last_name, role,
                     preferences, last_seen_at, last_seen_version,
                     remember_created_at, confirmed_at, confirmation_sent_at,
                     confirmation_token, unconfirmed_email, created_at, updated_at
            "#,
        )
        .bind(entity.id)
        .bind(entity.family_id)
        .bind(&entity.email)
        .bind(&entity.first_name)
        .bind(&entity.last_name)
        .bind(&entity.role)
        .bind(&entity.preferences)
        .bind(&entity.last_seen_at)
        .bind(&entity.last_seen_version)
        .bind(&entity.remember_created_at)
        .bind(&entity.confirmed_at)
        .bind(&entity.confirmation_sent_at)
        .bind(&entity.confirmation_token)
        .bind(&entity.unconfirmed_email)
        .bind(entity.created_at)
        .bind(entity.updated_at)
        .fetch_one(&*self.pool)
        .await?;

        Ok(map_user(row))
    }

    async fn update(&self, entity: User) -> Result<User, Self::Error> {
        let row = sqlx::query(
            r#"
            UPDATE users SET
              family_id=$2, email=$3, first_name=$4, last_name=$5, role=$6,
              preferences=$7, last_seen_at=$8, last_seen_version=$9,
              remember_created_at=$10, confirmed_at=$11, confirmation_sent_at=$12,
              confirmation_token=$13, unconfirmed_email=$14, updated_at=$15
            WHERE id=$1
            RETURNING id, family_id, email, first_name, last_name, role,
                     preferences, last_seen_at, last_seen_version,
                     remember_created_at, confirmed_at, confirmation_sent_at,
                     confirmation_token, unconfirmed_email, created_at, updated_at
            "#,
        )
        .bind(entity.id)
        .bind(entity.family_id)
        .bind(&entity.email)
        .bind(&entity.first_name)
        .bind(&entity.last_name)
        .bind(&entity.role)
        .bind(&entity.preferences)
        .bind(&entity.last_seen_at)
        .bind(&entity.last_seen_version)
        .bind(&entity.remember_created_at)
        .bind(&entity.confirmed_at)
        .bind(&entity.confirmation_sent_at)
        .bind(&entity.confirmation_token)
        .bind(&entity.unconfirmed_email)
        .bind(entity.updated_at)
        .fetch_one(&*self.pool)
        .await?;

        Ok(map_user(row))
    }

    async fn delete(&self, id: Uuid) -> Result<bool, Self::Error> {
        let result = sqlx::query("DELETE FROM users WHERE id = $1")
            .bind(id)
            .execute(&*self.pool)
            .await?;
        Ok(result.rows_affected() > 0)
    }
}

