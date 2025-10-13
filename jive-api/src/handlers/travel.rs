//! 旅行模式API处理器
//! 提供旅行事件管理、预算追踪、交易关联等功能接口

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
};
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, PgPool};
use uuid::Uuid;

use crate::{
    auth::Claims,
    error::{ApiError, ApiResult},
};

/// 旅行设置
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TravelSettings {
    pub auto_tag: Option<bool>,
    pub notify_budget: Option<bool>,
}

/// 交易过滤器
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionFilter {
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub categories: Option<Vec<Uuid>>,
    pub min_amount: Option<Decimal>,
    pub max_amount: Option<Decimal>,
}

/// 创建旅行事件输入
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTravelEventInput {
    pub trip_name: String,
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
    pub total_budget: Option<Decimal>,
    pub budget_currency_code: Option<String>,
    pub home_currency_code: String,
    pub settings: Option<TravelSettings>,
}

impl CreateTravelEventInput {
    pub fn validate(&self) -> Result<(), String> {
        if self.trip_name.trim().is_empty() {
            return Err("Trip name cannot be empty".to_string());
        }
        if self.start_date > self.end_date {
            return Err("Start date must be before end date".to_string());
        }
        Ok(())
    }
}

/// 更新旅行事件输入
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateTravelEventInput {
    pub trip_name: Option<String>,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub total_budget: Option<Decimal>,
    pub budget_currency_code: Option<String>,
    pub settings: Option<TravelSettings>,
}

impl UpdateTravelEventInput {
    pub fn validate(&self) -> Result<(), String> {
        if let Some(ref name) = self.trip_name {
            if name.trim().is_empty() {
                return Err("Trip name cannot be empty".to_string());
            }
        }
        Ok(())
    }
}

/// 附加交易输入
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AttachTransactionsInput {
    pub transaction_ids: Option<Vec<Uuid>>,
    pub filter: Option<TransactionFilter>,
}

/// 更新旅行预算输入
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpsertTravelBudgetInput {
    pub category_id: Uuid,
    pub budget_amount: Decimal,
    pub budget_currency_code: Option<String>,
    pub alert_threshold: Option<Decimal>,
}

impl UpsertTravelBudgetInput {
    pub fn validate(&self) -> Result<(), String> {
        if self.budget_amount < Decimal::ZERO {
            return Err("Budget amount cannot be negative".to_string());
        }
        if let Some(threshold) = self.alert_threshold {
            if threshold < Decimal::ZERO || threshold > Decimal::from(1) {
                return Err("Alert threshold must be between 0 and 1".to_string());
            }
        }
        Ok(())
    }
}

/// 旅行事件实体（数据库映射）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct TravelEvent {
    pub id: Uuid,
    pub family_id: Uuid,
    pub trip_name: String,
    pub status: String,
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
    pub total_budget: Option<Decimal>,
    pub budget_currency_code: Option<String>,
    pub home_currency_code: String,
    pub tag_group_id: Option<Uuid>,
    pub settings: serde_json::Value,
    pub total_spent: Decimal,
    pub transaction_count: i32,
    pub last_transaction_at: Option<DateTime<Utc>>,
    pub created_by: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 旅行预算实体
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct TravelBudget {
    pub id: Uuid,
    pub travel_event_id: Uuid,
    pub category_id: Uuid,
    pub budget_amount: Decimal,
    pub budget_currency_code: Option<String>,
    pub spent_amount: Decimal,
    pub spent_amount_home_currency: Decimal,
    pub alert_threshold: Decimal,
    pub alert_sent: bool,
    pub alert_sent_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 旅行统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TravelStatistics {
    pub total_spent: Decimal,
    pub transaction_count: i32,
    pub daily_average: Decimal,
    pub by_category: Vec<CategorySpending>,
    pub budget_usage: Option<Decimal>,
}

/// 分类支出
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategorySpending {
    pub category_id: Uuid,
    pub category_name: String,
    pub amount: Decimal,
    pub percentage: Decimal,
    pub transaction_count: i32,
}

/// 查询参数
#[derive(Debug, Deserialize)]
pub struct ListTravelEventsQuery {
    pub status: Option<String>,
    pub page: Option<u32>,
    pub page_size: Option<u32>,
}

/// 创建旅行事件
pub async fn create_travel_event(
    State(pool): State<PgPool>,
    claims: Claims,
    Json(input): Json<CreateTravelEventInput>,
) -> ApiResult<Json<TravelEvent>> {
    // 验证输入
    if let Err(e) = input.validate() {
        return Err(ApiError::BadRequest(e));
    }

    // 检查是否已有活跃的旅行
    let active_count: i64 = sqlx::query_scalar(
        "SELECT COUNT(*) FROM travel_events
         WHERE family_id = $1 AND status = 'active'",
    )
    .bind(claims.family_id)
    .fetch_one(&pool)
    .await?;

    if active_count > 0 {
        return Err(ApiError::BadRequest(
            "Family already has an active travel event".to_string(),
        ));
    }

    // 创建旅行事件
    let settings_json = serde_json::to_value(input.settings.unwrap_or_default())
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let user_id = claims.user_id()?;

    let event = sqlx::query_as::<_, TravelEvent>(
        "INSERT INTO travel_events (
            family_id, trip_name, status, start_date, end_date,
            total_budget, budget_currency_code, home_currency_code,
            settings, created_by
        ) VALUES ($1, $2, 'planning', $3, $4, $5, $6, $7, $8, $9)
        RETURNING *",
    )
    .bind(claims.family_id)
    .bind(&input.trip_name)
    .bind(input.start_date)
    .bind(input.end_date)
    .bind(input.total_budget)
    .bind(&input.budget_currency_code)
    .bind(&input.home_currency_code)
    .bind(settings_json)
    .bind(user_id)
    .fetch_one(&pool)
    .await?;

    Ok(Json(event))
}

/// 更新旅行事件
pub async fn update_travel_event(
    State(pool): State<PgPool>,
    claims: Claims,
    Path(id): Path<Uuid>,
    Json(input): Json<UpdateTravelEventInput>,
) -> ApiResult<Json<TravelEvent>> {
    // 获取现有事件
    let mut event = sqlx::query_as::<_, TravelEvent>(
        "SELECT * FROM travel_events
         WHERE id = $1 AND family_id = $2",
    )
    .bind(id)
    .bind(claims.family_id)
    .fetch_optional(&pool)
    .await?
    .ok_or_else(|| ApiError::NotFound("Travel event not found".to_string()))?;

    // 应用更新
    if let Some(trip_name) = input.trip_name {
        event.trip_name = trip_name;
    }
    if let Some(start_date) = input.start_date {
        event.start_date = start_date;
    }
    if let Some(end_date) = input.end_date {
        event.end_date = end_date;
    }
    if let Some(total_budget) = input.total_budget {
        event.total_budget = Some(total_budget);
    }
    if let Some(budget_currency_code) = input.budget_currency_code {
        event.budget_currency_code = Some(budget_currency_code);
    }
    if let Some(settings) = input.settings {
        event.settings =
            serde_json::to_value(&settings).map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }

    // 更新数据库
    let updated = sqlx::query_as::<_, TravelEvent>(
        "UPDATE travel_events SET
            trip_name = $2,
            start_date = $3,
            end_date = $4,
            total_budget = $5,
            budget_currency_code = $6,
            settings = $7,
            updated_at = NOW()
        WHERE id = $1
        RETURNING *",
    )
    .bind(id)
    .bind(&event.trip_name)
    .bind(event.start_date)
    .bind(event.end_date)
    .bind(event.total_budget)
    .bind(&event.budget_currency_code)
    .bind(&event.settings)
    .fetch_one(&pool)
    .await?;

    Ok(Json(updated))
}

/// 获取旅行事件详情
pub async fn get_travel_event(
    State(pool): State<PgPool>,
    claims: Claims,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<TravelEvent>> {
    let event = sqlx::query_as::<_, TravelEvent>(
        "SELECT * FROM travel_events
         WHERE id = $1 AND family_id = $2",
    )
    .bind(id)
    .bind(claims.family_id)
    .fetch_optional(&pool)
    .await?
    .ok_or_else(|| ApiError::NotFound("Travel event not found".to_string()))?;

    Ok(Json(event))
}

/// 列出旅行事件
pub async fn list_travel_events(
    State(pool): State<PgPool>,
    claims: Claims,
    Query(query): Query<ListTravelEventsQuery>,
) -> ApiResult<Json<Vec<TravelEvent>>> {
    let mut sql = String::from("SELECT * FROM travel_events WHERE family_id = $1");

    if let Some(_status) = &query.status {
        sql.push_str(" AND status = $2");
    }
    sql.push_str(" ORDER BY created_at DESC");

    let page = query.page.unwrap_or(1);
    let page_size = query.page_size.unwrap_or(20);
    let offset = (page - 1) * page_size;
    sql.push_str(&format!(" LIMIT {} OFFSET {}", page_size, offset));

    let events = if let Some(status) = query.status {
        sqlx::query_as::<_, TravelEvent>(&sql)
            .bind(claims.family_id)
            .bind(status)
            .fetch_all(&pool)
            .await?
    } else {
        sqlx::query_as::<_, TravelEvent>(&sql)
            .bind(claims.family_id)
            .fetch_all(&pool)
            .await?
    };

    Ok(Json(events))
}

/// 获取活跃的旅行事件
pub async fn get_active_travel(
    State(pool): State<PgPool>,
    claims: Claims,
) -> ApiResult<Json<Option<TravelEvent>>> {
    let event = sqlx::query_as::<_, TravelEvent>(
        "SELECT * FROM travel_events
         WHERE family_id = $1 AND status = 'active'
         ORDER BY created_at DESC
         LIMIT 1",
    )
    .bind(claims.family_id)
    .fetch_optional(&pool)
    .await?;

    Ok(Json(event))
}

/// 激活旅行事件
pub async fn activate_travel(
    State(pool): State<PgPool>,
    claims: Claims,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<TravelEvent>> {
    // 检查事件状态
    let event: TravelEvent = sqlx::query_as(
        "SELECT * FROM travel_events
         WHERE id = $1 AND family_id = $2",
    )
    .bind(id)
    .bind(claims.family_id)
    .fetch_optional(&pool)
    .await?
    .ok_or_else(|| ApiError::NotFound("Travel event not found".to_string()))?;

    if event.status != "planning" {
        return Err(ApiError::BadRequest(
            "Travel event cannot be activated from current status".to_string(),
        ));
    }

    // 停用其他活跃旅行
    sqlx::query(
        "UPDATE travel_events
         SET status = 'completed', updated_at = NOW()
         WHERE family_id = $1 AND status = 'active' AND id != $2",
    )
    .bind(claims.family_id)
    .bind(id)
    .execute(&pool)
    .await?;

    // 激活当前旅行
    let activated = sqlx::query_as::<_, TravelEvent>(
        "UPDATE travel_events
         SET status = 'active', updated_at = NOW()
         WHERE id = $1
         RETURNING *",
    )
    .bind(id)
    .fetch_one(&pool)
    .await?;

    Ok(Json(activated))
}

/// 完成旅行事件
pub async fn complete_travel(
    State(pool): State<PgPool>,
    claims: Claims,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<TravelEvent>> {
    let event: TravelEvent = sqlx::query_as(
        "SELECT * FROM travel_events
         WHERE id = $1 AND family_id = $2",
    )
    .bind(id)
    .bind(claims.family_id)
    .fetch_optional(&pool)
    .await?
    .ok_or_else(|| ApiError::NotFound("Travel event not found".to_string()))?;

    if event.status != "active" {
        return Err(ApiError::BadRequest(
            "Travel event cannot be completed from current status".to_string(),
        ));
    }

    let completed = sqlx::query_as::<_, TravelEvent>(
        "UPDATE travel_events
         SET status = 'completed', updated_at = NOW()
         WHERE id = $1
         RETURNING *",
    )
    .bind(id)
    .fetch_one(&pool)
    .await?;

    Ok(Json(completed))
}

/// 取消旅行事件
pub async fn cancel_travel(
    State(pool): State<PgPool>,
    claims: Claims,
    Path(id): Path<Uuid>,
) -> ApiResult<Json<TravelEvent>> {
    let cancelled = sqlx::query_as::<_, TravelEvent>(
        "UPDATE travel_events
         SET status = 'cancelled', updated_at = NOW()
         WHERE id = $1 AND family_id = $2
         RETURNING *",
    )
    .bind(id)
    .bind(claims.family_id)
    .fetch_one(&pool)
    .await?;

    Ok(Json(cancelled))
}

/// 附加交易到旅行
pub async fn attach_transactions(
    State(pool): State<PgPool>,
    claims: Claims,
    Path(travel_id): Path<Uuid>,
    Json(input): Json<AttachTransactionsInput>,
) -> ApiResult<Json<serde_json::Value>> {
    // 验证旅行存在
    let _: (Uuid,) =
        sqlx::query_as("SELECT id FROM travel_events WHERE id = $1 AND family_id = $2")
            .bind(travel_id)
            .bind(claims.family_id)
            .fetch_optional(&pool)
            .await?
            .ok_or_else(|| ApiError::NotFound("Travel event not found".to_string()))?;

    let user_id = claims.user_id()?;
    let mut transaction_ids = Vec::new();

    // 使用提供的交易ID
    if let Some(ids) = input.transaction_ids {
        transaction_ids = ids;
    }
    // 或根据过滤器查找交易
    else if let Some(filter) = input.filter {
        let mut query = String::from("SELECT id FROM transactions WHERE family_id = $1");

        if let Some(start_date) = filter.start_date {
            query.push_str(&format!(" AND date >= '{}'", start_date));
        }
        if let Some(end_date) = filter.end_date {
            query.push_str(&format!(" AND date <= '{}'", end_date));
        }

        // TODO: 添加更多过滤条件

        let ids: Vec<(Uuid,)> = sqlx::query_as(&query)
            .bind(claims.family_id)
            .fetch_all(&pool)
            .await?;

        transaction_ids = ids.into_iter().map(|(id,)| id).collect();
    }

    // 附加交易
    let mut attached_count = 0;
    for transaction_id in transaction_ids {
        let result = sqlx::query(
            "INSERT INTO travel_transactions (travel_event_id, transaction_id, attached_by)
             VALUES ($1, $2, $3)
             ON CONFLICT (travel_event_id, transaction_id) DO NOTHING",
        )
        .bind(travel_id)
        .bind(transaction_id)
        .bind(user_id)
        .execute(&pool)
        .await?;

        attached_count += result.rows_affected();
    }

    // 更新旅行统计
    sqlx::query("SELECT update_travel_event_stats($1)")
        .bind(travel_id)
        .execute(&pool)
        .await?;

    Ok(Json(serde_json::json!({
        "attached_count": attached_count,
        "message": format!("{} transactions attached", attached_count)
    })))
}

/// 分离交易
pub async fn detach_transaction(
    State(pool): State<PgPool>,
    _claims: Claims,
    Path((travel_id, transaction_id)): Path<(Uuid, Uuid)>,
) -> ApiResult<StatusCode> {
    sqlx::query(
        "DELETE FROM travel_transactions
         WHERE travel_event_id = $1 AND transaction_id = $2",
    )
    .bind(travel_id)
    .bind(transaction_id)
    .execute(&pool)
    .await?;

    // 更新旅行统计
    sqlx::query("SELECT update_travel_event_stats($1)")
        .bind(travel_id)
        .execute(&pool)
        .await?;

    Ok(StatusCode::NO_CONTENT)
}

/// 设置或更新分类预算
pub async fn upsert_travel_budget(
    State(pool): State<PgPool>,
    claims: Claims,
    Path(travel_id): Path<Uuid>,
    Json(input): Json<UpsertTravelBudgetInput>,
) -> ApiResult<Json<TravelBudget>> {
    // 验证输入
    if let Err(e) = input.validate() {
        return Err(ApiError::BadRequest(e));
    }

    // 验证旅行存在
    let _: (Uuid,) =
        sqlx::query_as("SELECT id FROM travel_events WHERE id = $1 AND family_id = $2")
            .bind(travel_id)
            .bind(claims.family_id)
            .fetch_optional(&pool)
            .await?
            .ok_or_else(|| ApiError::NotFound("Travel event not found".to_string()))?;

    let budget = sqlx::query_as::<_, TravelBudget>(
        "INSERT INTO travel_budgets (
            travel_event_id, category_id, budget_amount,
            budget_currency_code, alert_threshold
        ) VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (travel_event_id, category_id)
        DO UPDATE SET
            budget_amount = EXCLUDED.budget_amount,
            budget_currency_code = EXCLUDED.budget_currency_code,
            alert_threshold = EXCLUDED.alert_threshold,
            updated_at = NOW()
        RETURNING *",
    )
    .bind(travel_id)
    .bind(input.category_id)
    .bind(input.budget_amount)
    .bind(&input.budget_currency_code)
    .bind(input.alert_threshold.unwrap_or(Decimal::new(8, 1))) // 0.8
    .fetch_one(&pool)
    .await?;

    Ok(Json(budget))
}

/// 获取旅行预算
pub async fn get_travel_budgets(
    State(pool): State<PgPool>,
    claims: Claims,
    Path(travel_id): Path<Uuid>,
) -> ApiResult<Json<Vec<TravelBudget>>> {
    let budgets = sqlx::query_as::<_, TravelBudget>(
        "SELECT tb.* FROM travel_budgets tb
         JOIN travel_events te ON tb.travel_event_id = te.id
         WHERE tb.travel_event_id = $1 AND te.family_id = $2
         ORDER BY tb.category_id",
    )
    .bind(travel_id)
    .bind(claims.family_id)
    .fetch_all(&pool)
    .await?;

    Ok(Json(budgets))
}

/// 获取旅行统计
pub async fn get_travel_statistics(
    State(pool): State<PgPool>,
    claims: Claims,
    Path(travel_id): Path<Uuid>,
) -> ApiResult<Json<TravelStatistics>> {
    let event: TravelEvent = sqlx::query_as(
        "SELECT * FROM travel_events
         WHERE id = $1 AND family_id = $2",
    )
    .bind(travel_id)
    .bind(claims.family_id)
    .fetch_optional(&pool)
    .await?
    .ok_or_else(|| ApiError::NotFound("Travel event not found".to_string()))?;

    // 分类支出查询结果结构
    #[derive(Debug, sqlx::FromRow)]
    struct CategorySpendingRow {
        category_id: Uuid,
        category_name: String,
        amount: Decimal,
        transaction_count: i64,
    }

    // 获取分类支出
    let category_spending: Vec<CategorySpendingRow> = sqlx::query_as(
        r#"
        SELECT
            c.id as category_id,
            c.name as category_name,
            COALESCE(SUM(t.amount), 0) as amount,
            COUNT(t.id) as transaction_count
        FROM categories c
        JOIN ledgers l ON c.ledger_id = l.id
        LEFT JOIN (
            SELECT t.* FROM transactions t
            JOIN travel_transactions tt ON t.id = tt.transaction_id
            WHERE tt.travel_event_id = $1 AND t.deleted_at IS NULL
        ) t ON c.id = t.category_id
        WHERE l.family_id = $2
        GROUP BY c.id, c.name
        HAVING COUNT(t.id) > 0
        ORDER BY amount DESC
        "#,
    )
    .bind(travel_id)
    .bind(claims.family_id)
    .fetch_all(&pool)
    .await?;

    let total = event.total_spent;
    let categories: Vec<CategorySpending> = category_spending
        .into_iter()
        .map(|row| {
            let amount = row.amount;
            let percentage = if total.is_zero() {
                Decimal::ZERO
            } else {
                (amount / total) * Decimal::from(100)
            };

            CategorySpending {
                category_id: row.category_id,
                category_name: row.category_name,
                amount,
                percentage,
                transaction_count: row.transaction_count as i32,
            }
        })
        .collect();

    // 计算日均花费
    let duration_days = (event.end_date - event.start_date).num_days() + 1;
    let daily_average = if duration_days > 0 {
        event.total_spent / Decimal::from(duration_days)
    } else {
        Decimal::ZERO
    };

    // 计算预算使用百分比
    let budget_usage = event.total_budget.map(|budget| {
        if budget.is_zero() {
            Decimal::ZERO
        } else {
            (event.total_spent / budget) * Decimal::from(100)
        }
    });

    let stats = TravelStatistics {
        total_spent: event.total_spent,
        transaction_count: event.transaction_count,
        daily_average,
        by_category: categories,
        budget_usage,
    };

    Ok(Json(stats))
}
