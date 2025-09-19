//! 规则引擎API处理器
//! 提供自动分类规则的管理和执行

use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    response::Json,
};
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row, QueryBuilder};
use uuid::Uuid;
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;

use crate::error::{ApiError, ApiResult};

/// 规则查询参数
#[derive(Debug, Deserialize)]
pub struct RuleQuery {
    pub ledger_id: Option<Uuid>,
    pub is_active: Option<bool>,
    pub rule_type: Option<String>,
    pub page: Option<u32>,
    pub per_page: Option<u32>,
}

/// 创建规则请求
#[derive(Debug, Deserialize)]
pub struct CreateRuleRequest {
    pub ledger_id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub rule_type: String, // categorization, tagging, payee_assignment
    pub conditions: serde_json::Value,
    pub actions: serde_json::Value,
    pub priority: Option<i32>,
    pub is_active: Option<bool>,
    pub apply_to_existing: Option<bool>,
}

/// 更新规则请求
#[derive(Debug, Deserialize)]
pub struct UpdateRuleRequest {
    pub name: Option<String>,
    pub description: Option<String>,
    pub conditions: Option<serde_json::Value>,
    pub actions: Option<serde_json::Value>,
    pub priority: Option<i32>,
    pub is_active: Option<bool>,
}

/// 规则响应
#[derive(Debug, Serialize)]
pub struct RuleResponse {
    pub id: Uuid,
    pub ledger_id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub rule_type: String,
    pub conditions: serde_json::Value,
    pub actions: serde_json::Value,
    pub priority: i32,
    pub is_active: bool,
    pub match_count: i64,
    pub last_applied_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 规则执行结果
#[derive(Debug, Serialize)]
pub struct RuleExecutionResult {
    pub rule_id: Uuid,
    pub rule_name: String,
    pub matched_transactions: Vec<Uuid>,
    pub applied_count: i64,
    pub failed_count: i64,
    pub errors: Vec<String>,
}

/// 规则条件
#[derive(Debug, Deserialize, Serialize)]
pub struct RuleCondition {
    pub field: String, // amount, description, payee_name, etc.
    pub operator: String, // equals, contains, greater_than, less_than, regex
    pub value: serde_json::Value,
    pub case_sensitive: Option<bool>,
}

/// 规则动作
#[derive(Debug, Deserialize, Serialize)]
pub struct RuleAction {
    pub action_type: String, // set_category, add_tag, set_payee
    pub target_field: String,
    pub target_value: serde_json::Value,
}

/// 批量规则执行请求
#[derive(Debug, Deserialize)]
pub struct ExecuteRulesRequest {
    pub transaction_ids: Option<Vec<Uuid>>,
    pub rule_ids: Option<Vec<Uuid>>,
    pub dry_run: Option<bool>,
}

/// 获取规则列表
pub async fn list_rules(
    Query(params): Query<RuleQuery>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<Vec<RuleResponse>>> {
    let mut query = QueryBuilder::new(
        r#"
        SELECT 
            r.*,
            COUNT(rm.id) as match_count,
            MAX(rm.applied_at) as last_applied_at
        FROM rules r
        LEFT JOIN rule_matches rm ON r.id = rm.rule_id
        WHERE r.deleted_at IS NULL
        "#
    );
    
    // 添加过滤条件
    if let Some(ledger_id) = params.ledger_id {
        query.push(" AND r.ledger_id = ");
        query.push_bind(ledger_id);
    }
    
    if let Some(is_active) = params.is_active {
        query.push(" AND r.is_active = ");
        query.push_bind(is_active);
    }
    
    if let Some(rule_type) = params.rule_type {
        query.push(" AND r.rule_type = ");
        query.push_bind(rule_type);
    }
    
    query.push(" GROUP BY r.id");
    query.push(" ORDER BY r.priority ASC, r.name");
    
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
        response.push(RuleResponse {
            id: row.get("id"),
            ledger_id: row.get("ledger_id"),
            name: row.get("name"),
            description: row.get("description"),
            rule_type: row.get("rule_type"),
            conditions: row.get("conditions"),
            actions: row.get("actions"),
            priority: row.get("priority"),
            is_active: row.get("is_active"),
            match_count: row.try_get("match_count").unwrap_or(0),
            last_applied_at: row.try_get("last_applied_at").ok(),
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
        });
    }
    
    Ok(Json(response))
}

/// 获取单个规则
pub async fn get_rule(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<RuleResponse>> {
    let row = sqlx::query(
        r#"
        SELECT 
            r.*,
            COUNT(rm.id) as match_count,
            MAX(rm.applied_at) as last_applied_at
        FROM rules r
        LEFT JOIN rule_matches rm ON r.id = rm.rule_id
        WHERE r.id = $1 AND r.deleted_at IS NULL
        GROUP BY r.id
        "#
    )
    .bind(id)
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound("Rule not found".to_string()))?;
    
    let response = RuleResponse {
        id: row.get("id"),
        ledger_id: row.get("ledger_id"),
        name: row.get("name"),
        description: row.get("description"),
        rule_type: row.get("rule_type"),
        conditions: row.get("conditions"),
        actions: row.get("actions"),
        priority: row.get("priority"),
        is_active: row.get("is_active"),
        match_count: row.try_get("match_count").unwrap_or(0),
        last_applied_at: row.try_get("last_applied_at").ok(),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    };
    
    Ok(Json(response))
}

/// 创建规则
pub async fn create_rule(
    State(pool): State<PgPool>,
    Json(req): Json<CreateRuleRequest>,
) -> ApiResult<Json<RuleResponse>> {
    let id = Uuid::new_v4();
    
    // 创建规则
    sqlx::query(
        r#"
        INSERT INTO rules (
            id, ledger_id, name, description, rule_type,
            conditions, actions, priority, is_active,
            created_at, updated_at
        ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW()
        )
        "#
    )
    .bind(id)
    .bind(req.ledger_id)
    .bind(&req.name)
    .bind(req.description)
    .bind(&req.rule_type)
    .bind(&req.conditions)
    .bind(&req.actions)
    .bind(req.priority.unwrap_or(100))
    .bind(req.is_active.unwrap_or(true))
    .execute(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // 如果需要应用到现有交易
    if req.apply_to_existing.unwrap_or(false) {
        execute_rule_on_existing(id, req.ledger_id, &pool).await?;
    }
    
    // 返回创建的规则
    get_rule(Path(id), State(pool)).await
}

/// 更新规则
pub async fn update_rule(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
    Json(req): Json<UpdateRuleRequest>,
) -> ApiResult<Json<RuleResponse>> {
    // 构建动态更新查询
    let mut query = QueryBuilder::new("UPDATE rules SET updated_at = NOW()");
    
    if let Some(name) = &req.name {
        query.push(", name = ");
        query.push_bind(name);
    }
    
    if let Some(description) = &req.description {
        query.push(", description = ");
        query.push_bind(description);
    }
    
    if let Some(conditions) = &req.conditions {
        query.push(", conditions = ");
        query.push_bind(conditions);
    }
    
    if let Some(actions) = &req.actions {
        query.push(", actions = ");
        query.push_bind(actions);
    }
    
    if let Some(priority) = req.priority {
        query.push(", priority = ");
        query.push_bind(priority);
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
        return Err(ApiError::NotFound("Rule not found".to_string()));
    }
    
    // 返回更新后的规则
    get_rule(Path(id), State(pool)).await
}

/// 删除规则（软删除）
pub async fn delete_rule(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
) -> ApiResult<StatusCode> {
    let result = sqlx::query(
        "UPDATE rules SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(id)
    .execute(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    if result.rows_affected() == 0 {
        return Err(ApiError::NotFound("Rule not found".to_string()));
    }
    
    Ok(StatusCode::NO_CONTENT)
}

/// 执行规则
pub async fn execute_rules(
    State(pool): State<PgPool>,
    Json(req): Json<ExecuteRulesRequest>,
) -> ApiResult<Json<Vec<RuleExecutionResult>>> {
    let mut results = Vec::new();
    
    // 获取要执行的规则
    let mut rule_query = QueryBuilder::new(
        "SELECT * FROM rules WHERE deleted_at IS NULL AND is_active = true"
    );
    
    if let Some(rule_ids) = &req.rule_ids {
        rule_query.push(" AND id IN (");
        let mut separated = rule_query.separated(", ");
        for id in rule_ids {
            separated.push_bind(id);
        }
        rule_query.push(")");
    }
    
    rule_query.push(" ORDER BY priority ASC");
    
    let rules = rule_query
        .build()
        .fetch_all(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // 获取要处理的交易
    let mut tx_query = QueryBuilder::new(
        "SELECT * FROM transactions WHERE deleted_at IS NULL"
    );
    
    if let Some(transaction_ids) = &req.transaction_ids {
        tx_query.push(" AND id IN (");
        let mut separated = tx_query.separated(", ");
        for id in transaction_ids {
            separated.push_bind(id);
        }
        tx_query.push(")");
    }
    
    let transactions = tx_query
        .build()
        .fetch_all(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // 对每个规则执行匹配和应用
    for rule in rules {
        let rule_id: Uuid = rule.get("id");
        let rule_name: String = rule.get("name");
        let conditions: serde_json::Value = rule.get("conditions");
        let actions: serde_json::Value = rule.get("actions");
        
        let mut matched_transactions = Vec::new();
        let mut applied_count = 0;
        let mut failed_count = 0;
        let mut errors = Vec::new();
        
        // 检查每个交易是否匹配规则
        for tx in &transactions {
            if check_rule_match(tx, &conditions) {
                let tx_id: Uuid = tx.get("id");
                matched_transactions.push(tx_id);
                
                if !req.dry_run.unwrap_or(false) {
                    // 应用规则动作
                    match apply_rule_actions(&tx_id, &actions, &pool).await {
                        Ok(_) => {
                            applied_count += 1;
                            // 记录规则匹配
                            record_rule_match(rule_id, tx_id, &pool).await?;
                        }
                        Err(e) => {
                            failed_count += 1;
                            errors.push(format!("Transaction {}: {}", tx_id, e));
                        }
                    }
                }
            }
        }
        
        results.push(RuleExecutionResult {
            rule_id,
            rule_name,
            matched_transactions,
            applied_count,
            failed_count,
            errors,
        });
    }
    
    Ok(Json(results))
}

/// 检查交易是否匹配规则条件
fn check_rule_match(tx: &sqlx::postgres::PgRow, conditions: &serde_json::Value) -> bool {
    // 解析条件
    if let Some(conds) = conditions.as_array() {
        for cond in conds {
            if let Ok(condition) = serde_json::from_value::<RuleCondition>(cond.clone()) {
                if !check_single_condition(tx, &condition) {
                    return false;
                }
            }
        }
        true
    } else {
        false
    }
}

/// 检查单个条件
fn check_single_condition(tx: &sqlx::postgres::PgRow, condition: &RuleCondition) -> bool {
    match condition.field.as_str() {
        "amount" => {
            let amount: Decimal = tx.get("amount");
            match condition.operator.as_str() {
                "equals" => {
                    if let Some(val) = condition.value.as_f64() {
                        amount == Decimal::from_f64_retain(val).unwrap_or(Decimal::ZERO)
                    } else {
                        false
                    }
                }
                "greater_than" => {
                    if let Some(val) = condition.value.as_f64() {
                        amount > Decimal::from_f64_retain(val).unwrap_or(Decimal::ZERO)
                    } else {
                        false
                    }
                }
                "less_than" => {
                    if let Some(val) = condition.value.as_f64() {
                        amount < Decimal::from_f64_retain(val).unwrap_or(Decimal::MAX)
                    } else {
                        false
                    }
                }
                _ => false,
            }
        }
        "payee" => {
            let payee: Option<String> = tx.get("payee");
            if let Some(payee_str) = payee {
                match condition.operator.as_str() {
                    "equals" => {
                        if let Some(val) = condition.value.as_str() {
                            if condition.case_sensitive.unwrap_or(false) {
                                payee_str == val
                            } else {
                                payee_str.to_lowercase() == val.to_lowercase()
                            }
                        } else {
                            false
                        }
                    }
                    "contains" => {
                        if let Some(val) = condition.value.as_str() {
                            if condition.case_sensitive.unwrap_or(false) {
                                payee_str.contains(val)
                            } else {
                                payee_str.to_lowercase().contains(&val.to_lowercase())
                            }
                        } else {
                            false
                        }
                    }
                    _ => false,
                }
            } else {
                false
            }
        }
        _ => false,
    }
}

/// 应用规则动作到交易
async fn apply_rule_actions(
    transaction_id: &Uuid,
    actions: &serde_json::Value,
    pool: &PgPool,
) -> ApiResult<()> {
    if let Some(acts) = actions.as_array() {
        for act in acts {
            if let Ok(action) = serde_json::from_value::<RuleAction>(act.clone()) {
                match action.action_type.as_str() {
                    "set_category" => {
                        if let Some(category_id) = action.target_value.as_str() {
                            if let Ok(uuid) = Uuid::parse_str(category_id) {
                                sqlx::query(
                                    "UPDATE transactions SET category_id = $1, updated_at = NOW() WHERE id = $2"
                                )
                                .bind(uuid)
                                .bind(transaction_id)
                                .execute(pool)
                                .await
                                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
                            }
                        }
                    }
                    "add_tag" => {
                        if let Some(tag) = action.target_value.as_str() {
                            sqlx::query(
                                r#"
                                UPDATE transactions 
                                SET tags = CASE 
                                    WHEN tags IS NULL THEN '[]'::jsonb 
                                    ELSE tags 
                                END || $1::jsonb,
                                updated_at = NOW() 
                                WHERE id = $2
                                "#
                            )
                            .bind(serde_json::json!([tag]))
                            .bind(transaction_id)
                            .execute(pool)
                            .await
                            .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
                        }
                    }
                    _ => {}
                }
            }
        }
    }
    
    Ok(())
}

/// 记录规则匹配
async fn record_rule_match(
    rule_id: Uuid,
    transaction_id: Uuid,
    pool: &PgPool,
) -> ApiResult<()> {
    sqlx::query(
        r#"
        INSERT INTO rule_matches (id, rule_id, transaction_id, applied_at)
        VALUES ($1, $2, $3, NOW())
        ON CONFLICT (rule_id, transaction_id) DO UPDATE SET applied_at = NOW()
        "#
    )
    .bind(Uuid::new_v4())
    .bind(rule_id)
    .bind(transaction_id)
    .execute(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    Ok(())
}

/// 在现有交易上执行规则
async fn execute_rule_on_existing(
    rule_id: Uuid,
    ledger_id: Uuid,
    pool: &PgPool,
) -> ApiResult<()> {
    // 获取规则
    let rule = sqlx::query(
        "SELECT * FROM rules WHERE id = $1"
    )
    .bind(rule_id)
    .fetch_one(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    let conditions: serde_json::Value = rule.get("conditions");
    let actions: serde_json::Value = rule.get("actions");
    
    // 获取账本的所有交易
    let transactions = sqlx::query(
        "SELECT * FROM transactions WHERE ledger_id = $1 AND deleted_at IS NULL"
    )
    .bind(ledger_id)
    .fetch_all(pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // 应用规则到每个匹配的交易
    for tx in transactions {
        if check_rule_match(&tx, &conditions) {
            let tx_id: Uuid = tx.get("id");
            apply_rule_actions(&tx_id, &actions, pool).await?;
            record_rule_match(rule_id, tx_id, pool).await?;
        }
    }
    
    Ok(())
}
