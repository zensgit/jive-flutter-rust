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
use crate::{auth::Claims, error::{ApiError, ApiResult}};

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
    State(pool): State<PgPool>,
    claims: Claims,
    Query(query): Query<ListLedgersQuery>,
) -> ApiResult<Json<serde_json::Value>> {
    let user_id = claims.user_id()?;
    let page = query.page.unwrap_or(1);
    let limit = query.limit.unwrap_or(20);
    let offset = (page - 1) * limit;

    let rows = sqlx::query!(
        r#"
        SELECT l.id, l.family_id, l.name, l.currency, 
               l.is_default,
               l.created_at, l.updated_at
        FROM ledgers l
        LEFT JOIN family_members fm ON l.family_id = fm.family_id
        WHERE fm.user_id = $1 OR l.family_id IS NULL
        ORDER BY l.created_at DESC
        LIMIT $2 OFFSET $3
        "#,
        user_id,
        limit as i64,
        offset as i64,
    )
    .fetch_all(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    let ledgers: Vec<Ledger> = rows.into_iter().map(|row| Ledger {
        id: row.id,
        family_id: row.family_id,
        name: row.name,
        ledger_type: "family".to_string(),  // Default to family type
        description: None,
        currency: row.currency,
        is_default: row.is_default,
        settings: None,
        owner_id: None,
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
    .fetch_one(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(Json(json!({
        "data": ledgers,
        "pagination": {
            "page": page,
            "limit": limit,
            "total": total
        }
    })))
}

pub async fn get_current_ledger(
    State(pool): State<PgPool>,
    claims: Claims,
) -> ApiResult<Json<Ledger>> {
    let user_id = claims.user_id()?;
    
    // First try to get the default ledger for the user's current family
    let row = sqlx::query!(
        r#"
        SELECT l.id, l.family_id, l.name, l.currency, 
               l.is_default,
               l.created_at, l.updated_at
        FROM ledgers l
        LEFT JOIN family_members fm ON l.family_id = fm.family_id
        WHERE (fm.user_id = $1 OR l.family_id IS NULL) AND l.is_default = true
        LIMIT 1
        "#,
        user_id,
    )
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    let ledger = row.map(|r| Ledger {
        id: r.id,
        family_id: r.family_id,
        name: r.name,
        ledger_type: "family".to_string(),
        description: None,
        currency: r.currency,
        is_default: r.is_default,
        settings: None,
        owner_id: None,
        created_at: r.created_at,
        updated_at: r.updated_at,
    });

    if let Some(ledger) = ledger {
        Ok(Json(ledger))
    } else {
        // Create a default ledger if none exists
        let new_ledger = create_default_ledger(&pool, user_id, claims.family_id).await?;
        Ok(Json(new_ledger))
    }
}

pub async fn create_ledger(
    State(pool): State<PgPool>,
    claims: Claims,
    Json(req): Json<CreateLedgerRequest>,
) -> ApiResult<Json<Ledger>> {
    let user_id = claims.user_id()?;
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
        .execute(&pool)
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
    .fetch_one(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    let ledger = Ledger {
        id: row.id,
        family_id: row.family_id,
        name: row.name,
        ledger_type: req.ledger_type.unwrap_or_else(|| "family".to_string()),
        description: req.description,
        currency: row.currency,
        is_default: row.is_default,
        settings: None,
        owner_id: Some(user_id),
        created_at: row.created_at,
        updated_at: row.updated_at,
    };

    Ok(Json(ledger))
}

pub async fn get_ledger(
    State(pool): State<PgPool>,
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
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound("Ledger not found".to_string()))?;
    
    let ledger = Ledger {
        id: row.id,
        family_id: row.family_id,
        name: row.name,
        ledger_type: "family".to_string(),
        description: None,
        currency: row.currency,
        is_default: row.is_default,
        settings: None,
        owner_id: None,
        created_at: row.created_at,
        updated_at: row.updated_at,
    };

    Ok(Json(ledger))
}

pub async fn update_ledger(
    State(pool): State<PgPool>,
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
    .fetch_optional(&pool)
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
        .execute(&pool)
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
    .fetch_one(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    let ledger = Ledger {
        id: row.id,
        family_id: row.family_id,
        name: row.name,
        ledger_type: "family".to_string(),
        description: None,
        currency: row.currency,
        is_default: row.is_default,
        settings: None,
        owner_id: None,
        created_at: row.created_at,
        updated_at: row.updated_at,
    };

    Ok(Json(ledger))
}

pub async fn delete_ledger(
    State(pool): State<PgPool>,
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
    .fetch_one(&pool)
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
    .execute(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(ApiError::NotFound("Ledger not found".to_string()));
    }

    Ok(StatusCode::NO_CONTENT)
}

async fn create_default_ledger(
    pool: &PgPool,
    user_id: Uuid,
    family_id: Option<Uuid>,
) -> ApiResult<Ledger> {
    let ledger_id = Uuid::new_v4();
    
    let row = sqlx::query!(
        r#"
        INSERT INTO ledgers (id, family_id, name, currency, is_default, created_at, updated_at)
        VALUES ($1, $2, '默认家庭', 'CNY', true, NOW(), NOW())
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
        ledger_type: "family".to_string(),
        description: Some("默认的家庭账本".to_string()),
        currency: row.currency,
        is_default: row.is_default,
        settings: None,
        owner_id: Some(user_id),
        created_at: row.created_at,
        updated_at: row.updated_at,
    };

    Ok(ledger)
}

// Get ledger statistics
pub async fn get_ledger_statistics(
    State(pool): State<PgPool>,
    claims: Claims,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<serde_json::Value>> {
    let user_id = claims.user_id()?;
    
    // Verify user has access to this ledger
    let _ledger = sqlx::query!(
        r#"
        SELECT l.id
        FROM ledgers l
        LEFT JOIN family_members fm ON l.family_id = fm.family_id
        WHERE l.id = $1 AND (fm.user_id = $2 OR l.family_id IS NULL)
        "#,
        id,
        user_id,
    )
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound("Ledger not found".to_string()))?;
    
    // Get transaction statistics
    let stats = sqlx::query!(
        r#"
        SELECT 
            COUNT(*) as "total_transactions!",
            COALESCE(SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END), 0) as "total_income!",
            COALESCE(SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END), 0) as "total_expense!",
            COUNT(DISTINCT account_id) as "total_accounts!"
        FROM transactions
        WHERE ledger_id = $1
        "#,
        id
    )
    .fetch_one(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // Get account count
    let account_count = sqlx::query_scalar!(
        r#"
        SELECT COUNT(*) as "count!"
        FROM accounts
        WHERE ledger_id = $1
        "#,
        id
    )
    .fetch_one(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    Ok(Json(json!({
        "ledger_id": id,
        "total_transactions": stats.total_transactions,
        "total_income": stats.total_income,
        "total_expense": stats.total_expense,
        "balance": stats.total_income - stats.total_expense,
        "total_accounts": account_count,
        "currency": "CNY"
    })))
}

// Get ledger members
pub async fn get_ledger_members(
    State(pool): State<PgPool>,
    claims: Claims,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<serde_json::Value>> {
    let user_id = claims.user_id()?;
    
    // First verify the ledger exists and user has access
    let ledger = sqlx::query!(
        r#"
        SELECT l.id, l.family_id
        FROM ledgers l
        LEFT JOIN family_members fm ON l.family_id = fm.family_id
        WHERE l.id = $1 AND (fm.user_id = $2 OR l.family_id IS NULL)
        "#,
        id,
        user_id,
    )
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound("Ledger not found".to_string()))?;
    
    // Get family members (ledger always has family_id in the database)
    let family_id = ledger.family_id;
    {
        let members = sqlx::query!(
            r#"
            SELECT 
                u.id,
                u.name as full_name,
                u.email,
                fm.role,
                fm.joined_at as "joined_at!"
            FROM family_members fm
            JOIN users u ON fm.user_id = u.id
            WHERE fm.family_id = $1
            ORDER BY fm.joined_at
            "#,
            family_id
        )
        .fetch_all(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
        
        let member_list: Vec<serde_json::Value> = members.into_iter().map(|m| {
            json!({
                "user_id": m.id,
                "name": if !m.full_name.is_empty() { m.full_name.clone() } else { m.email.clone() },
                "email": m.email,
                "role": m.role.unwrap_or_else(|| "member".to_string()),
                "joined_at": m.joined_at,
                "is_active": true
            })
        }).collect();
        
        Ok(Json(json!({
            "ledger_id": id,
            "family_id": family_id,
            "members": member_list,
            "total": member_list.len()
        })))
    }
}
