//! 分类模板API处理器
//! 提供分类模板的CRUD操作和网络同步功能

use axum::{
    extract::{Query, State, Path},
    http::StatusCode,
    response::Json,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;
use std::collections::HashMap;

/// 模板查询参数
#[derive(Debug, Deserialize)]
pub struct TemplateQuery {
    #[allow(dead_code)]
    pub lang: Option<String>,
    pub r#type: Option<String>,
    pub group: Option<String>,
    pub featured: Option<bool>,
    pub since: Option<String>, // ISO8601 timestamp for incremental sync
}

/// 模板响应
#[derive(Debug, Serialize)]
pub struct TemplateResponse {
    pub templates: Vec<SystemTemplate>,
    pub version: String,
    pub last_updated: String,
    pub total: i64,
}

/// 图标响应
#[derive(Debug, Serialize)]
pub struct IconResponse {
    pub icons: HashMap<String, String>,
    pub cdn_base: String,
    pub version: String,
}

/// 更新响应
#[derive(Debug, Serialize)]
pub struct UpdateResponse {
    pub updates: Vec<TemplateUpdate>,
    pub has_more: bool,
}

/// 系统模板
#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct SystemTemplate {
    pub id: Uuid,
    pub name: String,
    pub name_en: Option<String>,
    pub name_zh: Option<String>,
    pub description: Option<String>,
    pub classification: String,
    pub color: String,
    pub icon: Option<String>,
    pub category_group: String,
    pub is_featured: bool,
    pub is_active: bool,
    pub global_usage_count: i32,
    pub tags: Vec<String>,
    pub version: String,
    pub created_at: chrono::DateTime<chrono::Utc>,
    pub updated_at: chrono::DateTime<chrono::Utc>,
}

/// 模板更新记录
#[derive(Debug, Serialize)]
pub struct TemplateUpdate {
    pub action: String, // "add", "update", "delete"
    pub template_id: Uuid,
    pub template: Option<SystemTemplate>,
    pub timestamp: chrono::DateTime<chrono::Utc>,
}

/// 创建模板请求
#[derive(Debug, Deserialize)]
pub struct CreateTemplateRequest {
    pub name: String,
    pub name_en: Option<String>,
    pub name_zh: Option<String>,
    pub description: Option<String>,
    pub classification: String,
    pub color: String,
    pub icon: Option<String>,
    pub category_group: String,
    pub is_featured: Option<bool>,
    pub tags: Option<Vec<String>>,
}

/// 更新模板请求
#[derive(Debug, Deserialize)]
pub struct UpdateTemplateRequest {
    pub name: Option<String>,
    pub name_en: Option<String>,
    pub name_zh: Option<String>,
    pub description: Option<String>,
    pub classification: Option<String>,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub category_group: Option<String>,
    pub is_featured: Option<bool>,
    pub is_active: Option<bool>,
    pub tags: Option<Vec<String>>,
}

/// 获取模板列表
pub async fn get_templates(
    Query(params): Query<TemplateQuery>,
    State(pool): State<PgPool>,
) -> Result<Json<TemplateResponse>, StatusCode> {
    // 根据语言参数选择名称字段
    let name_field = match params.lang.as_deref() {
        Some("en") => "COALESCE(name_en, name)",
        Some("zh") => "COALESCE(name_zh, name)",
        _ => "name",
    };
    
    let query_str = format!(
        "SELECT id, {} as name, name_en, name_zh, description, classification, color, icon, 
         category_group, is_featured, is_active, global_usage_count, tags, version, 
         created_at, updated_at FROM system_category_templates WHERE is_active = true",
        name_field
    );
    
    let mut query = sqlx::QueryBuilder::new(query_str);
    
    // 添加过滤条件
    if let Some(classification) = &params.r#type {
        if classification != "all" {
            query.push(" AND classification = ");
            query.push_bind(classification);
        }
    }
    
    if let Some(group) = &params.group {
        query.push(" AND category_group = ");
        query.push_bind(group);
    }
    
    if let Some(featured) = params.featured {
        query.push(" AND is_featured = ");
        query.push_bind(featured);
    }
    
    // 增量同步支持
    if let Some(since) = &params.since {
        query.push(" AND updated_at > ");
        query.push_bind(since);
    }
    
    query.push(" ORDER BY is_featured DESC, global_usage_count DESC, name");
    
    let templates = query
        .build_query_as::<SystemTemplate>()
        .fetch_all(&pool)
        .await
        .map_err(|e| {
            eprintln!("Database query error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;
    
    // 获取总数
    let total: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM system_category_templates WHERE is_active = true")
        .fetch_one(&pool)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    let response = TemplateResponse {
        templates,
        version: "1.0.0".to_string(),
        last_updated: chrono::Utc::now().to_rfc3339(),
        total: total.0,
    };
    
    Ok(Json(response))
}

/// 获取图标列表
pub async fn get_icons(
    State(_pool): State<PgPool>,
) -> Json<IconResponse> {
    // 模拟图标映射
    let mut icons = HashMap::new();
    icons.insert("💰".to_string(), "salary.png".to_string());
    icons.insert("🍽️".to_string(), "dining.png".to_string());
    icons.insert("🚗".to_string(), "transport.png".to_string());
    icons.insert("🏠".to_string(), "housing.png".to_string());
    icons.insert("🏥".to_string(), "medical.png".to_string());
    icons.insert("🎬".to_string(), "entertainment.png".to_string());
    icons.insert("💳".to_string(), "finance.png".to_string());
    icons.insert("💼".to_string(), "business.png".to_string());
    
    Json(IconResponse {
        icons,
        cdn_base: "http://127.0.0.1:8080/static/icons".to_string(),
        version: "1.0.0".to_string(),
    })
}

/// 获取模板更新（增量同步）
pub async fn get_template_updates(
    Query(params): Query<TemplateQuery>,
    State(pool): State<PgPool>,
) -> Result<Json<UpdateResponse>, StatusCode> {
    let since = params.since.unwrap_or_else(|| "1970-01-01T00:00:00Z".to_string());
    
    let templates = sqlx::query_as::<_, SystemTemplate>(
        r#"
        SELECT id, name, name_en, name_zh, description, classification, 
               color, icon, category_group, is_featured, is_active, 
               global_usage_count, tags, version, created_at, updated_at
        FROM system_category_templates 
        WHERE updated_at > $1::timestamptz
        ORDER BY updated_at DESC
        LIMIT 100
        "#,
    )
    .bind(since)
    .fetch_all(&pool)
    .await
    .map_err(|e| {
        eprintln!("Database query error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    
    let updates: Vec<TemplateUpdate> = templates
        .into_iter()
        .map(|template| TemplateUpdate {
            action: "update".to_string(),
            template_id: template.id,
            timestamp: template.updated_at,
            template: Some(template),
        })
        .collect();
    
    Ok(Json(UpdateResponse {
        updates,
        has_more: false,
    }))
}

/// 创建新模板（超级管理员）
pub async fn create_template(
    State(pool): State<PgPool>,
    Json(req): Json<CreateTemplateRequest>,
) -> Result<Json<SystemTemplate>, StatusCode> {
    let id = Uuid::new_v4();
    
    let template = sqlx::query_as::<_, SystemTemplate>(
        r#"
        INSERT INTO system_category_templates 
        (id, name, name_en, name_zh, description, classification, color, icon, 
         category_group, is_featured, tags, version)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, '1.0.0')
        RETURNING id, name, name_en, name_zh, description, classification, 
                  color, icon, category_group, is_featured, is_active, 
                  global_usage_count, tags, version, created_at, updated_at
        "#,
    )
    .bind(id)
    .bind(req.name)
    .bind(req.name_en)
    .bind(req.name_zh)
    .bind(req.description)
    .bind(req.classification)
    .bind(req.color)
    .bind(req.icon)
    .bind(req.category_group)
    .bind(req.is_featured.unwrap_or(false))
    .bind(&req.tags.unwrap_or_default()[..])
    .fetch_one(&pool)
    .await
    .map_err(|e| {
        eprintln!("Create template error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    
    Ok(Json(template))
}

/// 更新模板（超级管理员）
pub async fn update_template(
    Path(template_id): Path<Uuid>,
    State(pool): State<PgPool>,
    Json(req): Json<UpdateTemplateRequest>,
) -> Result<Json<SystemTemplate>, StatusCode> {
    // 构建动态更新查询
    let mut query = sqlx::QueryBuilder::new("UPDATE system_category_templates SET updated_at = CURRENT_TIMESTAMP");
    let mut has_updates = false;
    
    if let Some(name) = &req.name {
        query.push(", name = ");
        query.push_bind(name);
        has_updates = true;
    }
    
    if let Some(name_en) = &req.name_en {
        query.push(", name_en = ");
        query.push_bind(name_en);
        has_updates = true;
    }
    
    if let Some(name_zh) = &req.name_zh {
        query.push(", name_zh = ");
        query.push_bind(name_zh);
        has_updates = true;
    }
    
    if let Some(description) = &req.description {
        query.push(", description = ");
        query.push_bind(description);
        has_updates = true;
    }
    
    if let Some(classification) = &req.classification {
        query.push(", classification = ");
        query.push_bind(classification);
        has_updates = true;
    }
    
    if let Some(color) = &req.color {
        query.push(", color = ");
        query.push_bind(color);
        has_updates = true;
    }
    
    if let Some(icon) = &req.icon {
        query.push(", icon = ");
        query.push_bind(icon);
        has_updates = true;
    }
    
    if let Some(category_group) = &req.category_group {
        query.push(", category_group = ");
        query.push_bind(category_group);
        has_updates = true;
    }
    
    if let Some(is_featured) = req.is_featured {
        query.push(", is_featured = ");
        query.push_bind(is_featured);
        has_updates = true;
    }
    
    if let Some(is_active) = req.is_active {
        query.push(", is_active = ");
        query.push_bind(is_active);
        has_updates = true;
    }
    
    if let Some(tags) = &req.tags {
        query.push(", tags = ");
        query.push_bind(&tags[..]);
        has_updates = true;
    }
    
    if !has_updates {
        return Err(StatusCode::BAD_REQUEST);
    }
    
    query.push(" WHERE id = ");
    query.push_bind(template_id);
    
    // 执行更新
    query.build()
        .execute(&pool)
        .await
        .map_err(|e| {
            eprintln!("Update template error: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;
    
    // 返回更新后的模板
    let template = sqlx::query_as::<_, SystemTemplate>(
        r#"
        SELECT id, name, name_en, name_zh, description, classification, 
               color, icon, category_group, is_featured, is_active, 
               global_usage_count, tags, version, created_at, updated_at
        FROM system_category_templates 
        WHERE id = $1
        "#,
    )
    .bind(template_id)
    .fetch_one(&pool)
    .await
    .map_err(|_| StatusCode::NOT_FOUND)?;
    
    Ok(Json(template))
}

/// 删除模板（超级管理员）
pub async fn delete_template(
    Path(template_id): Path<Uuid>,
    State(pool): State<PgPool>,
) -> Result<StatusCode, StatusCode> {
    let result = sqlx::query(
        "UPDATE system_category_templates SET is_active = false, updated_at = CURRENT_TIMESTAMP WHERE id = $1"
    )
    .bind(template_id)
    .execute(&pool)
    .await
    .map_err(|e| {
        eprintln!("Delete template error: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;
    
    if result.rows_affected() == 0 {
        Err(StatusCode::NOT_FOUND)
    } else {
        Ok(StatusCode::NO_CONTENT)
    }
}

/// 提交使用统计
pub async fn submit_usage(
    State(pool): State<PgPool>,
    Json(usage): Json<serde_json::Value>,
) -> StatusCode {
    if let Some(template_id) = usage.get("template_id").and_then(|v| v.as_str()) {
        if let Ok(id) = Uuid::parse_str(template_id) {
            let _ = sqlx::query(
                "UPDATE system_category_templates SET global_usage_count = global_usage_count + 1 WHERE id = $1"
            )
            .bind(id)
            .execute(&pool)
            .await;
        }
    }
    
    StatusCode::OK
}