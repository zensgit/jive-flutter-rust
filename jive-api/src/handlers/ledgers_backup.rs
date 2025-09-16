use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::PgPool;
use uuid::Uuid;
use chrono::{DateTime, Utc};
use crate::{AppState, auth::Claims, error::{ApiError, ApiResult}};

#[derive(Debug, Serialize, Deserialize)]
pub struct Ledger {
    pub id: Uuid,
    pub family_id: Option<Uuid>,
    pub name: String,
    #[serde(rename = "type")]
    pub ledger_type: String,
    pub description: Option<String>,
    pub currency: Option<String>,
    pub is_default: Option<bool>,
    pub settings: Option<serde_json::Value>,
    pub owner_id: Option<Uuid>,
    pub created_at: Option<DateTime<Utc>>,
    pub updated_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize)]
pub struct CreateLedgerRequest {
    pub name: String,
    #[serde(rename = "type")]
    pub ledger_type: Option<String>,
    pub description: Option<String>,
    pub currency: String,
    pub is_default: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateLedgerRequest {
    pub name: Option<String>,
    pub currency: Option<String>,
    pub is_default: Option<bool>,
}

#[derive(Debug, Deserialize)]
pub struct ListLedgersQuery {
    pub page: Option<u32>,
    pub limit: Option<u32>,
}

pub async fn list_ledgers(
    State(state): State<AppState>,
    claims: Claims,
    Query(query): Query<ListLedgersQuery>,
) -> ApiResult<Json<serde_json::Value>> {
    let user_id = claims.user_id()?;
    let page = query.page.unwrap_or(1);
    let limit = query.limit.unwrap_or(20);
    let offset = (page - 1) * limit;

    let rows = sqlx::query!(
        r#"
        SELECT l.id, l.family_id, l.name, l.type, l.description,
               l.currency, l.is_default, l.settings, l.owner_id,
               l.created_at, l.updated_at
        FROM ledgers l
        LEFT JOIN family_members fm ON l.family_id = fm.family_id
        WHERE fm.user_id = $1 OR l.family_id IS NULL OR l.owner_id = $1
        ORDER BY l.created_at DESC
        LIMIT $2 OFFSET $3
        "#,
        user_id,
        limit as i64,
        offset as i64,
    )
    .fetch_all(&state.pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    let ledgers: Vec<Ledger> = rows.into_iter().map(|row| Ledger {
        id: row.id,
        family_id: row.family_id,
        name: row.name,
        ledger_type: row.r#type.unwrap_or_else(|| "family".to_string()),
        description: row.description,
        currency: row.currency,
        is_default: row.is_default,
        settings: row.settings,
        owner_id: row.owner_id,
        created_at: row.created_at,
        updated_at: row.updated_at,
    }).collect();

    let total = sqlx::query_scalar!(
        r#"
        SELECT COUNT(*) as "count!"
        FROM ledgers l
        LEFT JOIN family_members fm ON l.family_id = fm.family_id
        WHERE fm.user_id = $1 OR l.family_id IS NULL
        "#,
        user_id,
    )
    .fetch_one(&state.pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(json!({
        "items": ledgers,
        "pagination": {
            "page": page,
            "limit": limit,
            "total": total,
            "total_pages": (total as f64 / limit as f64).ceil() as u32,
        }
    })))
}

pub async fn get_current_ledger(
    State(state): State<AppState>,
    claims: Claims,
) -> ApiResult<Json<Ledger>> {
    let user_id = claims.user_id()?;

    let row = sqlx::query!(
        r#"
        SELECT l.id, l.family_id, l.name, l.currency, 
               l.is_default,
               l.created_at, l.updated_at
        FROM ledgers l
        LEFT JOIN family_members fm ON l.family_id = fm.family_id
        WHERE (fm.user_id = $1 OR l.family_id IS NULL) AND COALESCE(l.is_default, false) = true
        LIMIT 1
        "#,
        user_id,
    )
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    let ledger = row.map(|r| Ledger {
        id: r.id,
        family_id: r.family_id,
        name: r.name,
        ledger_type: "personal".to_string(),
        currency: r.currency,
        is_default: r.is_default,
        created_at: r.created_at,
        updated_at: r.updated_at,
    });

    if let Some(ledger) = ledger {
        Ok(Json(ledger))
    } else {
        // Create a default ledger if none exists
        let new_ledger = create_default_ledger(&state.pool, user_id, claims.family_id).await?;
        Ok(Json(new_ledger))
    }
}

pub async fn create_ledger(
    State(state): State<AppState>,
    claims: Claims,
    Json(req): Json<CreateLedgerRequest>,
) -> ApiResult<Json<Ledger>> {
    let _user_id = claims.user_id()?;
    let ledger_id = Uuid::new_v4();

    // If this is marked as default, unset other defaults
    if req.is_default.unwrap_or(false) {
        sqlx::query!(
            r#"
            UPDATE ledgers 
            SET is_default = false 
            WHERE family_id = $1 OR (family_id IS NULL AND $1 IS NULL)
            "#,
            claims.family_id
        )
        .execute(&state.pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    let row = sqlx::query!(
        r#"
        INSERT INTO ledgers (id, family_id, name, currency, is_default, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
        RETURNING id, family_id, name, currency, 
                  is_default,
                  created_at, updated_at
        "#,
        ledger_id,
        claims.family_id,
        req.name,
        req.currency,
        req.is_default.unwrap_or(false)
    )
    .fetch_one(&state.pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    let ledger = Ledger {
        id: row.id,
        family_id: row.family_id,
        name: row.name,
        ledger_type: "personal".to_string(),
        currency: row.currency,
        is_default: row.is_default,
        created_at: row.created_at,
        updated_at: row.updated_at,
    };

    Ok(Json(ledger))
}

pub async fn get_ledger(
    State(state): State<AppState>,
    claims: Claims,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<Ledger>> {
    let user_id = claims.user_id()?;

    let row = sqlx::query!(
        r#"
        SELECT l.id, l.family_id, l.name, l.currency, 
               l.is_default,
               l.created_at, l.updated_at
        FROM ledgers l
        LEFT JOIN family_members fm ON l.family_id = fm.family_id
        WHERE l.id = $1 AND (fm.user_id = $2 OR l.family_id IS NULL)
        "#,
        id,
        user_id,
    )
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound("Ledger not found".to_string()))?;
    
    let ledger = Ledger {
        id: row.id,
        family_id: row.family_id,
        name: row.name,
        ledger_type: "personal".to_string(),
        currency: row.currency,
        is_default: row.is_default,
        created_at: row.created_at,
        updated_at: row.updated_at,
    };

    Ok(Json(ledger))
}

pub async fn update_ledger(
    State(state): State<AppState>,
    claims: Claims,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateLedgerRequest>,
) -> ApiResult<Json<Ledger>> {
    let user_id = claims.user_id()?;

    // Verify user has access
    let _existing = sqlx::query!(
        r#"
        SELECT l.id
        FROM ledgers l
        LEFT JOIN family_members fm ON l.family_id = fm.family_id
        WHERE l.id = $1 AND (fm.user_id = $2 OR l.family_id IS NULL)
        "#,
        id,
        user_id,
    )
    .fetch_optional(&state.pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound("Ledger not found".to_string()))?;

    // If setting as default, unset others
    if req.is_default.unwrap_or(false) {
        sqlx::query!(
            r#"
            UPDATE ledgers 
            SET is_default = false 
            WHERE family_id = $1 OR (family_id IS NULL AND $1 IS NULL)
            "#,
            claims.family_id
        )
        .execute(&state.pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    // Update the ledger
    let row = sqlx::query!(
        r#"
        UPDATE ledgers
        SET name = COALESCE($2, name),
            currency = COALESCE($3, currency),
            is_default = COALESCE($4, is_default),
            updated_at = NOW()
        WHERE id = $1
        RETURNING id, family_id, name, currency, 
                  is_default,
                  created_at, updated_at
        "#,
        id,
        req.name,
        req.currency,
        req.is_default
    )
    .fetch_one(&state.pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    let ledger = Ledger {
        id: row.id,
        family_id: row.family_id,
        name: row.name,
        ledger_type: "personal".to_string(),
        currency: row.currency,
        is_default: row.is_default,
        created_at: row.created_at,
        updated_at: row.updated_at,
    };

    Ok(Json(ledger))
}

pub async fn delete_ledger(
    State(state): State<AppState>,
    claims: Claims,
    Path(id): Path<Uuid>,
) -> ApiResult<StatusCode> {
    let user_id = claims.user_id()?;

    // Verify user has access and check if this is the last ledger
    let count = sqlx::query_scalar!(
        r#"
        SELECT COUNT(*) as "count!"
        FROM ledgers l
        LEFT JOIN family_members fm ON l.family_id = fm.family_id
        WHERE (fm.user_id = $1 OR l.family_id IS NULL)
        "#,
        user_id
    )
    .fetch_one(&state.pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if count <= 1 {
        return Err(ApiError::BadRequest("Cannot delete the last ledger".to_string()));
    }

    let result = sqlx::query!(
        r#"
        DELETE FROM ledgers l
        USING family_members fm
        WHERE l.id = $1 AND (l.family_id = fm.family_id AND fm.user_id = $2 OR l.family_id IS NULL)
        "#,
        id,
        user_id,
    )
    .execute(&state.pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(ApiError::NotFound("Ledger not found".to_string()));
    }

    Ok(StatusCode::NO_CONTENT)
}

async fn create_default_ledger(
    pool: &PgPool,
    _user_id: Uuid,
    family_id: Option<Uuid>,
) -> ApiResult<Ledger> {
    let ledger_id = Uuid::new_v4();
    
    let row = sqlx::query!(
        r#"
        INSERT INTO ledgers (id, family_id, name, currency, is_default, created_at, updated_at)
        VALUES ($1, $2, '默认账本', 'CNY', true, NOW(), NOW())
        RETURNING id, family_id, name, currency, 
                  is_default,
                  created_at, updated_at
        "#,
        ledger_id,
        family_id
    )
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    let ledger = Ledger {
        id: row.id,
        family_id: row.family_id,
        name: row.name,
        ledger_type: "personal".to_string(),
        currency: row.currency,
        is_default: row.is_default,
        created_at: row.created_at,
        updated_at: row.updated_at,
    };

    Ok(ledger)
}