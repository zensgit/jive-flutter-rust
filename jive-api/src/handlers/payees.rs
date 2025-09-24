//! 收款人管理API处理器
//! 提供收款人的CRUD操作和智能建议功能

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, QueryBuilder, Row};
use uuid::Uuid;

use crate::error::{ApiError, ApiResult};

/// 收款人查询参数
#[derive(Debug, Deserialize)]
pub struct PayeeQuery {
    pub ledger_id: Option<Uuid>,
    pub search: Option<String>,
    pub category_id: Option<Uuid>,
    pub page: Option<u32>,
    pub per_page: Option<u32>,
}

/// 创建收款人请求
#[derive(Debug, Deserialize)]
pub struct CreatePayeeRequest {
    pub ledger_id: Uuid,
    pub name: String,
    pub category_id: Option<Uuid>,
    pub default_category_id: Option<Uuid>,
    pub notes: Option<String>,
    pub is_vendor: Option<bool>,
    pub is_customer: Option<bool>,
    pub contact_info: Option<serde_json::Value>,
}

/// 更新收款人请求
#[derive(Debug, Deserialize)]
pub struct UpdatePayeeRequest {
    pub name: Option<String>,
    pub category_id: Option<Uuid>,
    pub default_category_id: Option<Uuid>,
    pub notes: Option<String>,
    pub is_vendor: Option<bool>,
    pub is_customer: Option<bool>,
    pub contact_info: Option<serde_json::Value>,
    pub is_active: Option<bool>,
}

/// 收款人响应
#[derive(Debug, Serialize)]
pub struct PayeeResponse {
    pub id: Uuid,
    pub ledger_id: Uuid,
    pub name: String,
    pub category_id: Option<Uuid>,
    pub category_name: Option<String>,
    pub default_category_id: Option<Uuid>,
    pub default_category_name: Option<String>,
    pub notes: Option<String>,
    pub is_vendor: bool,
    pub is_customer: bool,
    pub is_active: bool,
    pub contact_info: Option<serde_json::Value>,
    pub transaction_count: i64,
    pub total_amount: Option<rust_decimal::Decimal>,
    pub last_transaction_date: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 收款人建议响应
#[derive(Debug, Serialize)]
pub struct PayeeSuggestion {
    pub id: Uuid,
    pub name: String,
    pub category_id: Option<Uuid>,
    pub category_name: Option<String>,
    pub usage_count: i64,
    pub confidence_score: f64,
}

/// 收款人统计
#[derive(Debug, Serialize)]
pub struct PayeeStatistics {
    pub total_payees: i64,
    pub active_payees: i64,
    pub vendors_count: i64,
    pub customers_count: i64,
    pub most_used_payees: Vec<PayeeUsageStats>,
    pub by_category: Vec<PayeeCategoryStats>,
}

#[derive(Debug, Serialize)]
pub struct PayeeUsageStats {
    pub payee_id: Uuid,
    pub payee_name: String,
    pub transaction_count: i64,
    pub total_amount: rust_decimal::Decimal,
    pub last_used: DateTime<Utc>,
}

#[derive(Debug, Serialize)]
pub struct PayeeCategoryStats {
    pub category_id: Option<Uuid>,
    pub category_name: Option<String>,
    pub payee_count: i64,
}

/// 获取收款人列表
pub async fn list_payees(
    Query(params): Query<PayeeQuery>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<Vec<PayeeResponse>>> {
    let mut query = QueryBuilder::new(
        r#"
        SELECT 
            p.*,
            c.name as category_name,
            dc.name as default_category_name,
            COUNT(t.id) as transaction_count,
            SUM(t.amount) as total_amount,
            MAX(t.transaction_date) as last_transaction_date
        FROM payees p
        LEFT JOIN categories c ON p.category_id = c.id
        LEFT JOIN categories dc ON p.default_category_id = dc.id
        LEFT JOIN transactions t ON p.id = t.payee_id AND t.deleted_at IS NULL
        WHERE p.deleted_at IS NULL
        "#,
    );

    // 添加过滤条件
    if let Some(ledger_id) = params.ledger_id {
        query.push(" AND p.ledger_id = ");
        query.push_bind(ledger_id);
    }

    if let Some(search) = params.search {
        query.push(" AND p.name ILIKE ");
        query.push_bind(format!("%{}%", search));
    }

    if let Some(category_id) = params.category_id {
        query.push(" AND (p.category_id = ");
        query.push_bind(category_id);
        query.push(" OR p.default_category_id = ");
        query.push_bind(category_id);
        query.push(")");
    }

    query.push(" GROUP BY p.id, c.name, dc.name");
    query.push(" ORDER BY COUNT(t.id) DESC, p.name");

    // 分页
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(50);
    let offset = ((page - 1) * per_page) as i64;

    query.push(" LIMIT ");
    query.push_bind(per_page as i64);
    query.push(" OFFSET ");
    query.push_bind(offset);

    let rows = query
        .build()
        .fetch_all(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut response = Vec::new();
    for row in rows {
        response.push(PayeeResponse {
            id: row.get("id"),
            ledger_id: row.get("ledger_id"),
            name: row.get("name"),
            category_id: row.get("category_id"),
            category_name: row.try_get("category_name").ok(),
            default_category_id: row.get("default_category_id"),
            default_category_name: row.try_get("default_category_name").ok(),
            notes: row.get("notes"),
            is_vendor: row.try_get("is_vendor").unwrap_or(false),
            is_customer: row.try_get("is_customer").unwrap_or(false),
            is_active: row.try_get("is_active").unwrap_or(true),
            contact_info: row.get("contact_info"),
            transaction_count: row.try_get("transaction_count").unwrap_or(0),
            total_amount: row.try_get("total_amount").ok(),
            last_transaction_date: row.try_get("last_transaction_date").ok(),
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
        });
    }

    Ok(Json(response))
}

/// 获取单个收款人
pub async fn get_payee(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<PayeeResponse>> {
    let row = sqlx::query(
        r#"
        SELECT 
            p.*,
            c.name as category_name,
            dc.name as default_category_name,
            COUNT(t.id) as transaction_count,
            SUM(t.amount) as total_amount,
            MAX(t.transaction_date) as last_transaction_date
        FROM payees p
        LEFT JOIN categories c ON p.category_id = c.id
        LEFT JOIN categories dc ON p.default_category_id = dc.id
        LEFT JOIN transactions t ON p.id = t.payee_id AND t.deleted_at IS NULL
        WHERE p.id = $1 AND p.deleted_at IS NULL
        GROUP BY p.id, c.name, dc.name
        "#,
    )
    .bind(id)
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound("Payee not found".to_string()))?;

    let response = PayeeResponse {
        id: row.get("id"),
        ledger_id: row.get("ledger_id"),
        name: row.get("name"),
        category_id: row.get("category_id"),
        category_name: row.try_get("category_name").ok(),
        default_category_id: row.get("default_category_id"),
        default_category_name: row.try_get("default_category_name").ok(),
        notes: row.get("notes"),
        is_vendor: row.try_get("is_vendor").unwrap_or(false),
        is_customer: row.try_get("is_customer").unwrap_or(false),
        is_active: row.try_get("is_active").unwrap_or(true),
        contact_info: row.get("contact_info"),
        transaction_count: row.try_get("transaction_count").unwrap_or(0),
        total_amount: row.try_get("total_amount").ok(),
        last_transaction_date: row.try_get("last_transaction_date").ok(),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    };

    Ok(Json(response))
}

/// 创建收款人
pub async fn create_payee(
    State(pool): State<PgPool>,
    Json(req): Json<CreatePayeeRequest>,
) -> ApiResult<Json<PayeeResponse>> {
    let id = Uuid::new_v4();

    // 检查是否已存在同名收款人
    let existing = sqlx::query(
        "SELECT id FROM payees WHERE ledger_id = $1 AND LOWER(name) = LOWER($2) AND deleted_at IS NULL"
    )
    .bind(req.ledger_id)
    .bind(&req.name)
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if existing.is_some() {
        return Err(ApiError::BadRequest(
            "Payee with this name already exists".to_string(),
        ));
    }

    // 创建收款人
    sqlx::query(
        r#"
        INSERT INTO payees (
            id, ledger_id, name, category_id, default_category_id,
            notes, is_vendor, is_customer, contact_info, is_active,
            created_at, updated_at
        ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, true, NOW(), NOW()
        )
        "#,
    )
    .bind(id)
    .bind(req.ledger_id)
    .bind(&req.name)
    .bind(req.category_id)
    .bind(req.default_category_id)
    .bind(req.notes)
    .bind(req.is_vendor.unwrap_or(false))
    .bind(req.is_customer.unwrap_or(false))
    .bind(req.contact_info)
    .execute(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 返回创建的收款人
    get_payee(Path(id), State(pool)).await
}

/// 更新收款人
pub async fn update_payee(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
    Json(req): Json<UpdatePayeeRequest>,
) -> ApiResult<Json<PayeeResponse>> {
    // 构建动态更新查询
    let mut query = QueryBuilder::new("UPDATE payees SET updated_at = NOW()");

    if let Some(name) = &req.name {
        query.push(", name = ");
        query.push_bind(name);
    }

    if let Some(category_id) = req.category_id {
        query.push(", category_id = ");
        query.push_bind(category_id);
    }

    if let Some(default_category_id) = req.default_category_id {
        query.push(", default_category_id = ");
        query.push_bind(default_category_id);
    }

    if let Some(notes) = &req.notes {
        query.push(", notes = ");
        query.push_bind(notes);
    }

    if let Some(is_vendor) = req.is_vendor {
        query.push(", is_vendor = ");
        query.push_bind(is_vendor);
    }

    if let Some(is_customer) = req.is_customer {
        query.push(", is_customer = ");
        query.push_bind(is_customer);
    }

    if let Some(contact_info) = req.contact_info {
        query.push(", contact_info = ");
        query.push_bind(contact_info);
    }

    if let Some(is_active) = req.is_active {
        query.push(", is_active = ");
        query.push_bind(is_active);
    }

    query.push(" WHERE id = ");
    query.push_bind(id);
    query.push(" AND deleted_at IS NULL");

    let result = query
        .build()
        .execute(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(ApiError::NotFound("Payee not found".to_string()));
    }

    // 返回更新后的收款人
    get_payee(Path(id), State(pool)).await
}

/// 删除收款人（软删除）
pub async fn delete_payee(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
) -> ApiResult<StatusCode> {
    let result = sqlx::query(
        "UPDATE payees SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(id)
    .execute(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(ApiError::NotFound("Payee not found".to_string()));
    }

    Ok(StatusCode::NO_CONTENT)
}

/// 获取收款人建议（基于输入文本）
pub async fn get_payee_suggestions(
    Query(params): Query<PayeeSuggestionQuery>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<Vec<PayeeSuggestion>>> {
    let text = params.text.ok_or(ApiError::BadRequest(
        "text parameter is required".to_string(),
    ))?;
    let ledger_id = params
        .ledger_id
        .ok_or(ApiError::BadRequest("ledger_id is required".to_string()))?;

    // 搜索匹配的收款人，按使用频率排序
    let suggestions = sqlx::query(
        r#"
        SELECT 
            p.id,
            p.name,
            p.default_category_id as category_id,
            c.name as category_name,
            COUNT(t.id) as usage_count,
            CASE 
                WHEN LOWER(p.name) = LOWER($2) THEN 1.0
                WHEN LOWER(p.name) LIKE LOWER($3) THEN 0.8
                WHEN LOWER(p.name) LIKE LOWER($4) THEN 0.6
                ELSE 0.4
            END as confidence_score
        FROM payees p
        LEFT JOIN categories c ON p.default_category_id = c.id
        LEFT JOIN transactions t ON p.id = t.payee_id AND t.deleted_at IS NULL
        WHERE p.ledger_id = $1 
            AND p.deleted_at IS NULL
            AND p.is_active = true
            AND LOWER(p.name) LIKE LOWER($4)
        GROUP BY p.id, p.name, p.default_category_id, c.name
        ORDER BY confidence_score DESC, usage_count DESC
        LIMIT 10
        "#,
    )
    .bind(ledger_id)
    .bind(&text)
    .bind(format!("{}%", text))
    .bind(format!("%{}%", text))
    .fetch_all(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut response = Vec::new();
    for row in suggestions {
        response.push(PayeeSuggestion {
            id: row.get("id"),
            name: row.get("name"),
            category_id: row.get("category_id"),
            category_name: row.try_get("category_name").ok(),
            usage_count: row.try_get("usage_count").unwrap_or(0),
            confidence_score: row.try_get("confidence_score").unwrap_or(0.0),
        });
    }

    Ok(Json(response))
}

/// 收款人建议查询参数
#[derive(Debug, Deserialize)]
pub struct PayeeSuggestionQuery {
    pub ledger_id: Option<Uuid>,
    pub text: Option<String>,
}

/// 获取收款人统计
pub async fn get_payee_statistics(
    Query(params): Query<PayeeQuery>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<PayeeStatistics>> {
    let ledger_id = params
        .ledger_id
        .ok_or(ApiError::BadRequest("ledger_id is required".to_string()))?;

    // 基本统计
    let stats = sqlx::query(
        r#"
        SELECT 
            COUNT(*) as total_payees,
            COUNT(CASE WHEN is_active = true THEN 1 END) as active_payees,
            COUNT(CASE WHEN is_vendor = true THEN 1 END) as vendors_count,
            COUNT(CASE WHEN is_customer = true THEN 1 END) as customers_count
        FROM payees
        WHERE ledger_id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(ledger_id)
    .fetch_one(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 最常用的收款人
    let most_used = sqlx::query(
        r#"
        SELECT 
            p.id as payee_id,
            p.name as payee_name,
            COUNT(t.id) as transaction_count,
            COALESCE(SUM(t.amount), 0) as total_amount,
            MAX(t.transaction_date) as last_used
        FROM payees p
        LEFT JOIN transactions t ON p.id = t.payee_id AND t.deleted_at IS NULL
        WHERE p.ledger_id = $1 AND p.deleted_at IS NULL
        GROUP BY p.id, p.name
        HAVING COUNT(t.id) > 0
        ORDER BY transaction_count DESC
        LIMIT 10
        "#,
    )
    .bind(ledger_id)
    .fetch_all(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut most_used_payees = Vec::new();
    for row in most_used {
        most_used_payees.push(PayeeUsageStats {
            payee_id: row.get("payee_id"),
            payee_name: row.get("payee_name"),
            transaction_count: row.try_get("transaction_count").unwrap_or(0),
            total_amount: row
                .try_get("total_amount")
                .unwrap_or(rust_decimal::Decimal::ZERO),
            last_used: row.get("last_used"),
        });
    }

    // 按分类统计
    let by_category = sqlx::query(
        r#"
        SELECT 
            c.id as category_id,
            c.name as category_name,
            COUNT(p.id) as payee_count
        FROM categories c
        LEFT JOIN payees p ON (p.category_id = c.id OR p.default_category_id = c.id) 
            AND p.deleted_at IS NULL
        WHERE c.ledger_id = $1
        GROUP BY c.id, c.name
        ORDER BY payee_count DESC
        "#,
    )
    .bind(ledger_id)
    .fetch_all(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut category_stats = Vec::new();
    for row in by_category {
        category_stats.push(PayeeCategoryStats {
            category_id: row.get("category_id"),
            category_name: row.try_get("category_name").ok(),
            payee_count: row.try_get("payee_count").unwrap_or(0),
        });
    }

    let response = PayeeStatistics {
        total_payees: stats.try_get("total_payees").unwrap_or(0),
        active_payees: stats.try_get("active_payees").unwrap_or(0),
        vendors_count: stats.try_get("vendors_count").unwrap_or(0),
        customers_count: stats.try_get("customers_count").unwrap_or(0),
        most_used_payees,
        by_category: category_stats,
    };

    Ok(Json(response))
}

/// 合并重复的收款人
pub async fn merge_payees(
    State(pool): State<PgPool>,
    Json(req): Json<MergePayeesRequest>,
) -> ApiResult<Json<PayeeResponse>> {
    // 开始事务
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 将所有交易从源收款人转移到目标收款人
    for source_id in &req.source_ids {
        sqlx::query(
            "UPDATE transactions SET payee_id = $1, updated_at = NOW() WHERE payee_id = $2",
        )
        .bind(req.target_id)
        .bind(source_id)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        // 软删除源收款人
        sqlx::query("UPDATE payees SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1")
            .bind(source_id)
            .execute(&mut *tx)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    // 提交事务
    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 返回目标收款人
    get_payee(Path(req.target_id), State(pool)).await
}

/// 合并收款人请求
#[derive(Debug, Deserialize)]
pub struct MergePayeesRequest {
    pub target_id: Uuid,
    pub source_ids: Vec<Uuid>,
}
