//! 账户管理API处理器
//! 提供账户的CRUD操作接口

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
};
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, QueryBuilder, Row};
use std::str::FromStr;
use uuid::Uuid;

use crate::error::{ApiError, ApiResult};
use crate::models::{AccountMainType, AccountSubType};

/// 账户查询参数
#[derive(Debug, Deserialize)]
pub struct AccountQuery {
    pub ledger_id: Option<Uuid>,
    pub account_type: Option<String>,
    pub include_archived: Option<bool>,
    pub page: Option<u32>,
    pub per_page: Option<u32>,
}

/// 创建账户请求
#[derive(Debug, Deserialize)]
pub struct CreateAccountRequest {
    pub ledger_id: Uuid,
    pub bank_id: Option<Uuid>,
    pub name: String,
    pub account_main_type: String,
    pub account_sub_type: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub account_type: Option<String>,
    pub account_number: Option<String>,
    pub institution_name: Option<String>,
    pub currency: Option<String>,
    pub initial_balance: Option<Decimal>,
    pub color: Option<String>,
    #[allow(dead_code)]
    pub icon: Option<String>,
    pub notes: Option<String>,
}

/// 更新账户请求
#[derive(Debug, Deserialize)]
pub struct UpdateAccountRequest {
    pub bank_id: Option<Uuid>,
    pub name: Option<String>,
    pub account_number: Option<String>,
    pub institution_name: Option<String>,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub notes: Option<String>,
    pub is_archived: Option<bool>,
}

/// 账户响应
#[derive(Debug, Serialize)]
pub struct AccountResponse {
    pub id: Uuid,
    pub ledger_id: Uuid,
    pub bank_id: Option<Uuid>,
    pub name: String,
    pub account_type: String,
    pub account_number: Option<String>,
    pub institution_name: Option<String>,
    pub currency: String,
    pub current_balance: Decimal,
    pub available_balance: Option<Decimal>,
    pub credit_limit: Option<Decimal>,
    pub status: String,
    pub is_manual: bool,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub notes: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 账户统计响应
#[derive(Debug, Serialize)]
pub struct AccountStatistics {
    pub total_accounts: i64,
    pub total_assets: Decimal,
    pub total_liabilities: Decimal,
    pub net_worth: Decimal,
    pub by_type: Vec<TypeStatistics>,
}

#[derive(Debug, Serialize)]
pub struct TypeStatistics {
    pub account_type: String,
    pub count: i64,
    pub total_balance: Decimal,
}

/// 获取账户列表
pub async fn list_accounts(
    Query(params): Query<AccountQuery>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<Vec<AccountResponse>>> {
    // 构建查询
    let mut query = QueryBuilder::new(
        "SELECT id, ledger_id, bank_id, name, account_type, account_number, institution_name,
         currency,
         current_balance::numeric as current_balance,
         available_balance::numeric as available_balance,
         credit_limit::numeric as credit_limit,
         status, is_manual, color, icon, notes, created_at, updated_at
         FROM accounts WHERE 1=1",
    );

    // 添加过滤条件
    if let Some(ledger_id) = params.ledger_id {
        query.push(" AND ledger_id = ");
        query.push_bind(ledger_id);
    }

    if let Some(account_type) = params.account_type {
        query.push(" AND account_type = ");
        query.push_bind(account_type);
    }

    if !params.include_archived.unwrap_or(false) {
        query.push(" AND deleted_at IS NULL");
    }

    query.push(" ORDER BY name");

    // 分页
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(20);
    let offset = ((page - 1) * per_page) as i64;

    query.push(" LIMIT ");
    query.push_bind(per_page as i64);
    query.push(" OFFSET ");
    query.push_bind(offset);

    // 执行查询
    let accounts = query
        .build()
        .fetch_all(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 转换为响应格式
    let mut response = Vec::new();
    for row in accounts {
        response.push(AccountResponse {
            id: row.get("id"),
            ledger_id: row.get("ledger_id"),
            bank_id: row.get("bank_id"),
            name: row.get("name"),
            account_type: row.get("account_type"),
            account_number: row.get("account_number"),
            institution_name: row.get("institution_name"),
            currency: row.get("currency"),
            current_balance: row.get("current_balance"),
            available_balance: row.get("available_balance"),
            credit_limit: row.get("credit_limit"),
            status: row.get("status"),
            is_manual: row.get("is_manual"),
            color: row.get("color"),
            icon: row.get("icon"),
            notes: row.get("notes"),
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
        });
    }

    Ok(Json(response))
}

/// 获取单个账户
pub async fn get_account(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<AccountResponse>> {
    let row = sqlx::query(
        r#"
        SELECT id, ledger_id, bank_id, name, account_type, account_number, institution_name,
               currency,
<<<<<<< HEAD
               current_balance,
               available_balance,
               credit_limit,
=======
               current_balance::numeric as current_balance,
               available_balance::numeric as available_balance,
               credit_limit::numeric as credit_limit,
>>>>>>> origin/chore/invitations-audit-align-dev-mock
               status,
               is_manual, color, notes, created_at, updated_at
        FROM accounts
        WHERE id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(id)
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound("Account not found".to_string()))?;

    let response = AccountResponse {
        id: row.get("id"),
        ledger_id: row.get("ledger_id"),
        bank_id: row.get("bank_id"),
        name: row.get("name"),
        account_type: row.get("account_type"),
        account_number: row.get("account_number"),
        institution_name: row.get("institution_name"),
        currency: row
            .try_get::<Option<String>, _>("currency")
            .unwrap_or(None)
            .unwrap_or_else(|| "CNY".to_string()),
        current_balance: row
            .try_get::<Option<Decimal>, _>("current_balance")
            .unwrap_or(None)
            .unwrap_or(Decimal::ZERO),
        available_balance: row
            .try_get::<Option<Decimal>, _>("available_balance")
            .unwrap_or(None),
        credit_limit: row
            .try_get::<Option<Decimal>, _>("credit_limit")
            .unwrap_or(None),
        status: row
            .try_get::<Option<String>, _>("status")
            .unwrap_or(None)
            .unwrap_or_else(|| "active".to_string()),
        is_manual: row
            .try_get::<Option<bool>, _>("is_manual")
            .unwrap_or(None)
            .unwrap_or(true),
        color: row.get("color"),
        icon: row.get("icon"),
        notes: row.get("notes"),
        created_at: row
            .try_get::<Option<DateTime<Utc>>, _>("created_at")
            .unwrap_or(None)
            .unwrap_or_else(chrono::Utc::now),
        updated_at: row
            .try_get::<Option<DateTime<Utc>>, _>("updated_at")
            .unwrap_or(None)
            .unwrap_or_else(chrono::Utc::now),
    };

    Ok(Json(response))
}

/// 创建账户
pub async fn create_account(
    State(pool): State<PgPool>,
    Json(req): Json<CreateAccountRequest>,
) -> ApiResult<Json<AccountResponse>> {
    let main_type =
        AccountMainType::from_str(&req.account_main_type).map_err(ApiError::BadRequest)?;
    let sub_type = AccountSubType::from_str(&req.account_sub_type).map_err(ApiError::BadRequest)?;

    sub_type
        .validate_with_main_type(main_type)
        .map_err(ApiError::BadRequest)?;

    let id = Uuid::new_v4();
    let currency = req.currency.unwrap_or_else(|| "CNY".to_string());
    let initial_balance = req.initial_balance.unwrap_or(Decimal::ZERO);
    let legacy_type = req
        .account_type
        .unwrap_or_else(|| req.account_sub_type.clone());

    let row = sqlx::query(
        r#"
        INSERT INTO accounts (
            id, ledger_id, bank_id, name, account_type, account_main_type, account_sub_type,
            account_number, institution_name, currency, current_balance, status,
            is_manual, color, notes, created_at, updated_at
        ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11::numeric, 'active', true, $12, $13, NOW(), NOW()
        )
        RETURNING id, ledger_id, bank_id, name, account_type, account_number, institution_name,
<<<<<<< HEAD
<<<<<<< HEAD
                  currency, current_balance, available_balance, credit_limit, status,
=======
                  currency,
                  current_balance::numeric as current_balance,
                  available_balance::numeric as available_balance,
                  credit_limit::numeric as credit_limit,
                  status,
>>>>>>> origin/chore/invitations-audit-align-dev-mock
                  is_manual, color, notes, created_at, updated_at
=======
                  currency, current_balance, available_balance, credit_limit,
                  status, is_manual, color, notes, created_at, updated_at
>>>>>>> 46ef8086 (api: unify Decimal mapping in accounts handler; fix clippy in metrics and currency_service)
        "#,
    )
    .bind(id)
    .bind(req.ledger_id)
    .bind(req.bank_id)
    .bind(&req.name)
    .bind(&legacy_type)
    .bind(main_type.to_string())
    .bind(sub_type.to_string())
    .bind(&req.account_number)
    .bind(&req.institution_name)
    .bind(&currency)
    .bind(initial_balance)
    .bind(&req.color)
    .bind(&req.notes)
    .fetch_one(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 如果有初始余额，创建余额记录
    if initial_balance != Decimal::ZERO {
        sqlx::query!(
            r#"
            INSERT INTO account_balances (id, account_id, balance, balance_date)
            VALUES ($1, $2, $3, CURRENT_DATE)
            "#,
            Uuid::new_v4(),
            id,
            // 存入余额历史表使用 DECIMAL/numeric 字段，保持高精度
            initial_balance
        )
        .execute(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    // 响应里保持 Decimal，一致向前端输出
    let response = AccountResponse {
        id: row.get("id"),
        ledger_id: row.get("ledger_id"),
        bank_id: row.get("bank_id"),
        name: row.get("name"),
        account_type: row.get("account_type"),
        account_number: row.get("account_number"),
        institution_name: row.get("institution_name"),
        currency: row
            .try_get::<Option<String>, _>("currency")
            .unwrap_or(None)
            .unwrap_or_else(|| "CNY".to_string()),
        current_balance: row
            .try_get::<Option<Decimal>, _>("current_balance")
            .unwrap_or(None)
            .unwrap_or(Decimal::ZERO),
        available_balance: row
            .try_get::<Option<Decimal>, _>("available_balance")
            .unwrap_or(None),
        credit_limit: row
            .try_get::<Option<Decimal>, _>("credit_limit")
            .unwrap_or(None),
        status: row
            .try_get::<Option<String>, _>("status")
            .unwrap_or(None)
            .unwrap_or_else(|| "active".to_string()),
        is_manual: row
            .try_get::<Option<bool>, _>("is_manual")
            .unwrap_or(None)
            .unwrap_or(true),
        color: row.get("color"),
        icon: row.get("icon"),
        notes: row.get("notes"),
        created_at: row
            .try_get::<Option<DateTime<Utc>>, _>("created_at")
            .unwrap_or(None)
            .unwrap_or_else(chrono::Utc::now),
        updated_at: row
            .try_get::<Option<DateTime<Utc>>, _>("updated_at")
            .unwrap_or(None)
            .unwrap_or_else(chrono::Utc::now),
    };

    Ok(Json(response))
}

/// 更新账户
pub async fn update_account(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
    Json(req): Json<UpdateAccountRequest>,
) -> ApiResult<Json<AccountResponse>> {
    // 构建动态更新查询
    let mut query = QueryBuilder::new("UPDATE accounts SET updated_at = NOW()");

    if let Some(name) = &req.name {
        query.push(", name = ");
        query.push_bind(name);
    }

    if let Some(account_number) = &req.account_number {
        query.push(", account_number = ");
        query.push_bind(account_number);
    }

    if let Some(institution_name) = &req.institution_name {
        query.push(", institution_name = ");
        query.push_bind(institution_name);
    }

    if let Some(color) = &req.color {
        query.push(", color = ");
        query.push_bind(color);
    }

    if let Some(icon) = &req.icon {
        query.push(", icon = ");
        query.push_bind(icon);
    }

    if let Some(notes) = &req.notes {
        query.push(", notes = ");
        query.push_bind(notes);
    }

    if let Some(bank_id) = &req.bank_id {
        query.push(", bank_id = ");
        query.push_bind(bank_id);
    }

    if let Some(is_archived) = req.is_archived {
        if is_archived {
            query.push(", deleted_at = NOW()");
        } else {
            query.push(", deleted_at = NULL");
        }
    }

    query.push(" WHERE id = ");
    query.push_bind(id);
    query.push(" RETURNING id, ledger_id, bank_id, name, account_type, account_number, institution_name, currency, ");
    query.push(" current_balance::numeric as current_balance, available_balance::numeric as available_balance, credit_limit::numeric as credit_limit, ");
    query.push(" status, is_manual, color, icon, notes, created_at, updated_at");

    let account = query
        .build()
        .fetch_one(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let response = AccountResponse {
        id: account.get("id"),
        ledger_id: account.get("ledger_id"),
        bank_id: account.get("bank_id"),
        name: account.get("name"),
        account_type: account.get("account_type"),
        account_number: account.get("account_number"),
        institution_name: account.get("institution_name"),
        currency: account.get("currency"),
        current_balance: account.get("current_balance"),
        available_balance: account.get("available_balance"),
        credit_limit: account.get("credit_limit"),
        status: account.get("status"),
        is_manual: account.get("is_manual"),
        color: account.get("color"),
        icon: account.get("icon"),
        notes: account.get("notes"),
        created_at: account.get("created_at"),
        updated_at: account.get("updated_at"),
    };

    Ok(Json(response))
}

/// 删除账户（软删除）
pub async fn delete_account(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
) -> ApiResult<StatusCode> {
    let result = sqlx::query!(
        r#"
        UPDATE accounts 
        SET deleted_at = NOW(), updated_at = NOW()
        WHERE id = $1 AND deleted_at IS NULL
        "#,
        id
    )
    .execute(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(ApiError::NotFound("Account not found".to_string()));
    }

    Ok(StatusCode::NO_CONTENT)
}

/// 获取账户统计
pub async fn get_account_statistics(
    Query(params): Query<AccountQuery>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<AccountStatistics>> {
    let ledger_id = params
        .ledger_id
        .ok_or(ApiError::BadRequest("ledger_id is required".to_string()))?;

    // 获取总体统计（使用动态查询以避免 SQLx 离线缓存耦合）
    let stats_row = sqlx::query(
        r#"
        SELECT 
            COUNT(*) as total_accounts,
            SUM(CASE WHEN current_balance > 0 THEN current_balance ELSE 0 END)::numeric as total_assets,
            SUM(CASE WHEN current_balance < 0 THEN ABS(current_balance) ELSE 0 END)::numeric as total_liabilities
        FROM accounts
        WHERE ledger_id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(ledger_id)
    .fetch_one(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 按类型统计
    let type_rows = sqlx::query(
        r#"
        SELECT 
            account_type,
            COUNT(*) as count,
            SUM(current_balance)::numeric as total_balance
        FROM accounts
        WHERE ledger_id = $1 AND deleted_at IS NULL
        GROUP BY account_type
        ORDER BY account_type
        "#,
    )
    .bind(ledger_id)
    .fetch_all(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let by_type: Vec<TypeStatistics> = type_rows
        .into_iter()
        .map(|row| TypeStatistics {
            account_type: row.get::<String, _>("account_type"),
            count: row
                .try_get::<Option<i64>, _>("count")
                .unwrap_or(None)
                .unwrap_or(0),
            total_balance: row
                .try_get::<Option<Decimal>, _>("total_balance")
                .unwrap_or(None)
                .unwrap_or(Decimal::ZERO),
        })
        .collect();

    let total_assets = stats_row
        .try_get::<Option<Decimal>, _>("total_assets")
        .unwrap_or(None)
        .unwrap_or(Decimal::ZERO);
    let total_liabilities = stats_row
        .try_get::<Option<Decimal>, _>("total_liabilities")
        .unwrap_or(None)
        .unwrap_or(Decimal::ZERO);

    let response = AccountStatistics {
        total_accounts: stats_row
            .try_get::<Option<i64>, _>("total_accounts")
            .unwrap_or(None)
            .unwrap_or(0),
        total_assets,
        total_liabilities,
        net_worth: total_assets - total_liabilities,
        by_type,
    };

    Ok(Json(response))
}
