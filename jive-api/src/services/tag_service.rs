use sqlx::{PgPool, Row};
use uuid::Uuid;

use super::ServiceError;

#[derive(Debug, Clone, serde::Serialize)]
pub struct TagDto {
    pub id: Uuid,
    pub ledger_id: Uuid,
    pub name: String,
    pub color: Option<String>,
    pub description: Option<String>,
    pub usage_count: i32,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct TagSummary {
    pub id: Uuid,
    pub name: String,
    pub usage_count: i64,
}

pub struct TagService {
    pool: PgPool,
}

impl TagService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    async fn pick_ledger_for_family(&self, family_id: Uuid) -> Result<Uuid, ServiceError> {
        // Prefer default ledger, fallback to latest
        if let Some(id) = sqlx::query_scalar!(
            "SELECT id FROM ledgers WHERE family_id=$1 AND is_default=true LIMIT 1",
            family_id
        )
        .fetch_optional(&self.pool)
        .await?
        {
            return Ok(id);
        }
        let id = sqlx::query_scalar!(
            "SELECT id FROM ledgers WHERE family_id=$1 ORDER BY updated_at DESC LIMIT 1",
            family_id
        )
        .fetch_one(&self.pool)
        .await?;
        Ok(id)
    }

    pub async fn list_tags(
        &self,
        family_id: Uuid,
        q: Option<String>,
    ) -> Result<Vec<TagDto>, ServiceError> {
        let mut base = String::from("SELECT t.id, t.ledger_id, t.name, t.color, t.description, t.usage_count FROM tags t JOIN ledgers l ON t.ledger_id = l.id WHERE l.family_id = $1");
        let mut args: Vec<(usize, String)> = Vec::new();
        let bind_idx = 2;
        if let Some(q) = q {
            base.push_str(&format!(" AND t.name ILIKE ${}", bind_idx));
            args.push((bind_idx, format!("%{}%", q)));
        }
        base.push_str(" ORDER BY t.usage_count DESC, lower(t.name) ASC");
        let mut query = sqlx::query(&base).bind(family_id);
        for (_, v) in args {
            query = query.bind(v);
        }
        let rows = query.fetch_all(&self.pool).await?;
        Ok(rows
            .into_iter()
            .map(|r| TagDto {
                id: r.get("id"),
                ledger_id: r.get("ledger_id"),
                name: r.get("name"),
                color: r.try_get("color").ok(),
                description: r.try_get("description").ok(),
                usage_count: r.try_get("usage_count").unwrap_or(0),
            })
            .collect())
    }

    pub async fn create_tag(
        &self,
        family_id: Uuid,
        name: &str,
        color: Option<&str>,
        description: Option<&str>,
    ) -> Result<TagDto, ServiceError> {
        let ledger_id = self.pick_ledger_for_family(family_id).await?;
        let id = Uuid::new_v4();
        let row = sqlx::query!(
            r#"INSERT INTO tags (id, ledger_id, name, color, description, usage_count, created_at)
               VALUES ($1,$2,$3,$4,$5,0, NOW())
               RETURNING id, ledger_id, name, color, description, usage_count"#,
            id,
            ledger_id,
            name,
            color,
            description
        )
        .fetch_one(&self.pool)
        .await?;
        Ok(TagDto {
            id: row.id,
            ledger_id: row.ledger_id,
            name: row.name,
            color: row.color,
            description: row.description,
            usage_count: row.usage_count.unwrap_or(0),
        })
    }

    pub async fn update_tag(
        &self,
        id: Uuid,
        name: Option<&str>,
        color: Option<&str>,
        description: Option<&str>,
    ) -> Result<TagDto, ServiceError> {
        let row = sqlx::query!(
            r#"UPDATE tags SET
                  name = COALESCE($2, name),
                  color = COALESCE($3, color),
                  description = COALESCE($4, description)
               WHERE id = $1
               RETURNING id, ledger_id, name, color, description, usage_count"#,
            id,
            name,
            color,
            description
        )
        .fetch_one(&self.pool)
        .await?;
        Ok(TagDto {
            id: row.id,
            ledger_id: row.ledger_id,
            name: row.name,
            color: row.color,
            description: row.description,
            usage_count: row.usage_count.unwrap_or(0),
        })
    }

    pub async fn delete_tag(&self, id: Uuid) -> Result<(), ServiceError> {
        sqlx::query!("DELETE FROM tags WHERE id = $1", id)
            .execute(&self.pool)
            .await?;
        Ok(())
    }

    pub async fn merge_tags(
        &self,
        family_id: Uuid,
        from_ids: Vec<Uuid>,
        to_id: Uuid,
    ) -> Result<i64, ServiceError> {
        let mut tx = self.pool.begin().await?;
        let to_name: String = sqlx::query_scalar!("SELECT name FROM tags WHERE id = $1", to_id)
            .fetch_one(&mut *tx)
            .await?;
        let from_names: Vec<String> =
            sqlx::query!("SELECT name FROM tags WHERE id = ANY($1)", &from_ids)
                .fetch_all(&mut *tx)
                .await?
                .into_iter()
                .map(|r| r.name)
                .collect();
        if !from_names.is_empty() {
            let _ = sqlx::query!(
                r#"UPDATE transactions t SET tags = (
                        SELECT ARRAY(SELECT DISTINCT unnest(COALESCE(tags,'{}'::text[]))
                                     EXCEPT SELECT unnest($1::text[])) || $2::text[] )
                    FROM ledgers l
                    WHERE t.ledger_id = l.id AND l.family_id = $3"#,
                &from_names,
                &vec![to_name.clone()],
                family_id
            )
            .execute(&mut *tx)
            .await?;
        }
        let res = sqlx::query!(
            "DELETE FROM tags WHERE id = ANY($1) AND id <> $2",
            &from_ids,
            to_id
        )
        .execute(&mut *tx)
        .await?;
        tx.commit().await?;
        Ok(res.rows_affected() as i64)
    }

    pub async fn summary(&self, family_id: Uuid) -> Result<Vec<TagSummary>, ServiceError> {
        let rows = sqlx::query!(
            r#"SELECT t.id, t.name, t.usage_count FROM tags t JOIN ledgers l ON t.ledger_id=l.id WHERE l.family_id=$1 ORDER BY t.usage_count DESC, lower(t.name) ASC"#,
            family_id
        ).fetch_all(&self.pool).await?;
        Ok(rows
            .into_iter()
            .map(|r| TagSummary {
                id: r.id,
                name: r.name,
                usage_count: r.usage_count.unwrap_or(0) as i64,
            })
            .collect())
    }
}
