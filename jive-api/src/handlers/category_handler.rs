//! 用户分类管理 API（最小可用版本）
use axum::{extract::{Path, Query, State}, http::StatusCode, response::Json};
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::auth::Claims;

#[derive(Debug, Deserialize)]
pub struct ListParams {
    pub ledger_id: Option<Uuid>,
    pub classification: Option<String>, // expense|income|transfer
}

#[derive(Debug, Serialize)]
pub struct CategoryDto {
    pub id: Uuid,
    pub ledger_id: Uuid,
    pub name: String,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub classification: String,
    pub parent_id: Option<Uuid>,
    pub position: i32,
    pub usage_count: i32,
    pub last_used_at: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Debug, Deserialize)]
pub struct CreateCategoryRequest {
    pub ledger_id: Uuid,
    pub name: String,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub classification: String,
    pub parent_id: Option<Uuid>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateCategoryRequest {
    pub name: Option<String>,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub classification: Option<String>,
    pub parent_id: Option<Uuid>,
}

#[derive(Debug, Deserialize)]
pub struct ReorderItem { pub id: Uuid, pub position: i32 }

#[derive(Debug, Deserialize)]
pub struct ReorderRequest { pub items: Vec<ReorderItem> }

pub async fn list_categories(
    claims: Claims,
    State(pool): State<PgPool>,
    Query(params): Query<ListParams>,
)-> Result<Json<Vec<CategoryDto>>, StatusCode> {
    let _user_id = claims.user_id().map_err(|_| StatusCode::UNAUTHORIZED)?;

    let mut query = sqlx::QueryBuilder::new(
        "SELECT id, ledger_id, name, color, icon, classification, parent_id, position, usage_count, last_used_at \
         FROM categories WHERE is_deleted = false"
    );
    if let Some(ledger) = params.ledger_id { query.push(" AND ledger_id = ").push_bind(ledger); }
    if let Some(classif) = params.classification { query.push(" AND classification = ").push_bind(classif); }
    query.push(" ORDER BY parent_id NULLS FIRST, position ASC, LOWER(name)");

    let rows = query.build().fetch_all(&pool).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    let mut items = Vec::with_capacity(rows.len());
    for r in rows {
        items.push(CategoryDto{
            id: r.get("id"),
            ledger_id: r.get("ledger_id"),
            name: r.get("name"),
            color: r.try_get("color").ok(),
            icon: r.try_get("icon").ok(),
            classification: r.get("classification"),
            parent_id: r.try_get("parent_id").ok(),
            position: r.try_get("position").unwrap_or(0),
            usage_count: r.try_get("usage_count").unwrap_or(0),
            last_used_at: r.try_get("last_used_at").ok(),
        });
    }
    Ok(Json(items))
}

pub async fn create_category(
    claims: Claims,
    State(pool): State<PgPool>,
    Json(req): Json<CreateCategoryRequest>,
) -> Result<Json<CategoryDto>, StatusCode> {
    let _user_id = claims.user_id().map_err(|_| StatusCode::UNAUTHORIZED)?;

    let rec = sqlx::query(
        r#"INSERT INTO categories (id, ledger_id, name, color, icon, classification, parent_id, position, usage_count)
           VALUES ($1,$2,$3,$4,$5,$6,$7, COALESCE((SELECT COALESCE(MAX(position),-1)+1 FROM categories WHERE ledger_id=$2 AND parent_id IS NOT DISTINCT FROM $7),0), 0)
           RETURNING id, ledger_id, name, color, icon, classification, parent_id, position, usage_count, last_used_at"#
    )
    .bind(Uuid::new_v4())
    .bind(&req.ledger_id)
    .bind(&req.name)
    .bind(&req.color)
    .bind(&req.icon)
    .bind(&req.classification)
    .bind(&req.parent_id)
    .fetch_one(&pool).await.map_err(|e|{ eprintln!("create_category err: {:?}", e); StatusCode::BAD_REQUEST })?;

    Ok(Json(CategoryDto{
        id: rec.get("id"), ledger_id: rec.get("ledger_id"), name: rec.get("name"),
        color: rec.try_get("color").ok(), icon: rec.try_get("icon").ok(), classification: rec.get("classification"),
        parent_id: rec.try_get("parent_id").ok(), position: rec.try_get("position").unwrap_or(0),
        usage_count: rec.try_get("usage_count").unwrap_or(0), last_used_at: rec.try_get("last_used_at").ok(),
    }))
}

pub async fn update_category(
    claims: Claims,
    State(pool): State<PgPool>,
    Path(id): Path<Uuid>,
    Json(req): Json<UpdateCategoryRequest>,
) -> Result<StatusCode, StatusCode> {
    let _user_id = claims.user_id().map_err(|_| StatusCode::UNAUTHORIZED)?;

    let mut qb = sqlx::QueryBuilder::new("UPDATE categories SET updated_at = NOW()");
    if let Some(name) = req.name { qb.push(", name = ").push_bind(name); }
    if let Some(color) = req.color { qb.push(", color = ").push_bind(color); }
    if let Some(icon) = req.icon { qb.push(", icon = ").push_bind(icon); }
    if let Some(cls) = req.classification { qb.push(", classification = ").push_bind(cls); }
    if let Some(pid) = req.parent_id { qb.push(", parent_id = ").push_bind(pid); }
    qb.push(" WHERE id = ").push_bind(id);
    let res = qb.build().execute(&pool).await.map_err(|_| StatusCode::BAD_REQUEST)?;
    if res.rows_affected() == 0 { return Err(StatusCode::NOT_FOUND); }
    Ok(StatusCode::NO_CONTENT)
}

pub async fn delete_category(
    claims: Claims,
    State(pool): State<PgPool>,
    Path(id): Path<Uuid>,
) -> Result<StatusCode, StatusCode> {
    let _user_id = claims.user_id().map_err(|_| StatusCode::UNAUTHORIZED)?;
    // MVP: forbid deletion if used
    let in_use: (i64,) = sqlx::query_as("SELECT COUNT(1) FROM transactions WHERE category_id = $1")
        .bind(id).fetch_one(&pool).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    if in_use.0 > 0 { return Err(StatusCode::CONFLICT); }
    let res = sqlx::query("UPDATE categories SET is_deleted=true, deleted_at=NOW() WHERE id=$1")
        .bind(id).execute(&pool).await.map_err(|_| StatusCode::BAD_REQUEST)?;
    if res.rows_affected() == 0 { return Err(StatusCode::NOT_FOUND); }
    Ok(StatusCode::NO_CONTENT)
}

pub async fn reorder_categories(
    claims: Claims,
    State(pool): State<PgPool>,
    Json(req): Json<ReorderRequest>,
) -> Result<StatusCode, StatusCode> {
    let _user_id = claims.user_id().map_err(|_| StatusCode::UNAUTHORIZED)?;
    let mut tx = pool.begin().await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    for item in req.items { sqlx::query("UPDATE categories SET position=$1, updated_at=NOW() WHERE id=$2").bind(item.position).bind(item.id).execute(&mut *tx).await.map_err(|_| StatusCode::BAD_REQUEST)?; }
    tx.commit().await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    Ok(StatusCode::NO_CONTENT)
}

#[derive(Debug, Deserialize)]
pub struct ImportTemplateRequest { pub ledger_id: Uuid, pub template_id: Uuid }

pub async fn import_template(
    claims: Claims,
    State(pool): State<PgPool>,
    Json(req): Json<ImportTemplateRequest>,
) -> Result<Json<CategoryDto>, StatusCode> {
    let _user_id = claims.user_id().map_err(|_| StatusCode::UNAUTHORIZED)?;

    let tpl = sqlx::query(
        r#"SELECT id, name, name_en, name_zh, classification, color, icon, version FROM system_category_templates WHERE id = $1 AND is_active = true"#
    ).bind(req.template_id).fetch_optional(&pool).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
     .ok_or(StatusCode::NOT_FOUND)?;

    let id = Uuid::new_v4();
    let rec = sqlx::query(
        r#"INSERT INTO categories (id, ledger_id, name, color, icon, classification, position, usage_count, source_type, template_id, template_version)
           VALUES ($1,$2,$3,$4,$5,$6,
                   COALESCE((SELECT COALESCE(MAX(position),-1)+1 FROM categories WHERE ledger_id=$2),0),
                   0,'system',$7,$8)
           RETURNING id, ledger_id, name, color, icon, classification, parent_id, position, usage_count, last_used_at"#
    )
    .bind(id)
    .bind(&req.ledger_id)
    .bind::<String>(tpl.get("name"))
    .bind::<Option<String>>(tpl.try_get("color").ok())
    .bind::<Option<String>>(tpl.try_get("icon").ok())
    .bind::<String>(tpl.get("classification"))
    .bind::<Uuid>(tpl.get("id"))
    .bind::<String>(tpl.get("version"))
    .fetch_one(&pool).await.map_err(|e|{ eprintln!("import_template err: {:?}", e); StatusCode::BAD_REQUEST })?;

    Ok(Json(CategoryDto{
        id: rec.get("id"), ledger_id: rec.get("ledger_id"), name: rec.get("name"),
        color: rec.try_get("color").ok(), icon: rec.try_get("icon").ok(), classification: rec.get("classification"),
        parent_id: rec.try_get("parent_id").ok(), position: rec.try_get("position").unwrap_or(0),
        usage_count: rec.try_get("usage_count").unwrap_or(0), last_used_at: rec.try_get("last_used_at").ok(),
    }))
}

// -------- Batch import from system templates --------

#[derive(Debug, Deserialize)]
pub struct ImportOverride {
    pub name: Option<String>,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub classification: Option<String>,
    pub parent_id: Option<Uuid>,
}

#[derive(Debug, Deserialize)]
pub struct ImportItem {
    pub template_id: Uuid,
    #[serde(default)]
    pub overrides: Option<ImportOverride>,
}

#[derive(Debug, Deserialize)]
pub struct BatchImportRequest {
    pub ledger_id: Uuid,
    #[serde(default)]
    pub items: Option<Vec<ImportItem>>, // Preferred shape
    // Back-compat shape used by some clients
    #[serde(default)]
    pub template_ids: Option<Vec<Uuid>>,
    #[serde(default)]
    pub on_conflict: Option<String>, // skip|rename|update (default: skip)
    // Back-compat nested options: { skip_existing: bool, customize: {..} }
    #[serde(default)]
    pub options: Option<serde_json::Value>,
    #[serde(default)]
    pub dry_run: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct BatchImportResult {
    pub imported: i32,
    pub skipped: i32,
    pub failed: i32,
    pub categories: Vec<CategoryDto>,
    #[serde(skip_serializing_if = "Vec::is_empty", default)]
    pub details: Vec<ImportActionDetail>,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ImportActionKind { Imported, Updated, Renamed, Skipped, Failed }

#[derive(Debug, Serialize)]
pub struct ImportActionDetail {
    pub template_id: Uuid,
    pub action: ImportActionKind,
    pub original_name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub final_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub category_id: Option<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub predicted_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub existing_category_id: Option<Uuid>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub existing_category_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub final_classification: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub final_parent_id: Option<Uuid>,
}

pub async fn batch_import_templates(
    claims: Claims,
    State(pool): State<PgPool>,
    Json(req): Json<BatchImportRequest>,
) -> Result<Json<BatchImportResult>, StatusCode> {
    let _user_id = claims.user_id().map_err(|_| StatusCode::UNAUTHORIZED)?;

    // Normalize request into items
    let mut items: Vec<ImportItem> = Vec::new();
    if let Some(list) = req.items {
        items = list;
    } else if let Some(ids) = req.template_ids.clone() {
        // Map template_ids to items without overrides
        items = ids.into_iter().map(|id| ImportItem { template_id: id, overrides: None }).collect();
    }
    if items.is_empty() { return Err(StatusCode::BAD_REQUEST); }

    // Resolve conflict strategy
    let mut strategy = req.on_conflict.unwrap_or_else(|| "skip".to_string());
    if let Some(opts) = &req.options {
        if let Some(skip) = opts.get("skip_existing").and_then(|v| v.as_bool()) {
            if skip { strategy = "skip".to_string(); }
        }
    }

    let dry_run = req.dry_run.unwrap_or(false);

    let mut imported = 0i32;
    let mut skipped = 0i32;
    let mut failed = 0i32;
    let mut result_items: Vec<CategoryDto> = Vec::new();
    let mut details: Vec<ImportActionDetail> = Vec::new();

    'outer: for it in items {
        // Load template
        let tpl = match sqlx::query(
            r#"SELECT id, name, name_en, name_zh, classification, color, icon, version FROM system_category_templates WHERE id = $1 AND is_active = true"#
        ).bind(it.template_id).fetch_optional(&pool).await {
            Ok(Some(row)) => row,
            Ok(None) => { failed += 1; details.push(ImportActionDetail{ template_id: it.template_id, action: ImportActionKind::Failed, original_name: "".into(), final_name: None, category_id: None, reason: Some("template_not_found".into())}); continue 'outer; },
            Err(_) => { failed += 1; details.push(ImportActionDetail{ template_id: it.template_id, action: ImportActionKind::Failed, original_name: "".into(), final_name: None, category_id: None, reason: Some("template_query_error".into())}); continue 'outer; }
        };

        // Resolve fields with overrides
        let mut name: String = it.overrides.as_ref().and_then(|o| o.name.clone()).unwrap_or_else(|| tpl.get::<String, _>("name"));
        let color: Option<String> = it.overrides.as_ref().and_then(|o| o.color.clone()).or_else(|| tpl.try_get("color").ok());
        let icon: Option<String> = it.overrides.as_ref().and_then(|o| o.icon.clone()).or_else(|| tpl.try_get("icon").ok());
        let classification: String = it.overrides.as_ref().and_then(|o| o.classification.clone()).unwrap_or_else(|| tpl.get::<String, _>("classification"));
        let parent_id: Option<Uuid> = it.overrides.as_ref().and_then(|o| o.parent_id);
        let template_version: String = tpl.get::<String, _>("version");
        let template_id: Uuid = tpl.get::<Uuid, _>("id");

        // Try insert; handle conflict strategy
        // First, check existence by name (case-insensitive) for active categories within ledger
        let exists: Option<(Uuid,)> = sqlx::query_as(
            "SELECT id FROM categories WHERE ledger_id=$1 AND LOWER(name)=LOWER($2) AND is_deleted=false LIMIT 1"
        ).bind(&req.ledger_id).bind(&name).fetch_optional(&pool).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

        if let Some((existing_id,)) = exists {
            match strategy.as_str() {
                "skip" => { skipped += 1; details.push(ImportActionDetail{ template_id, action: ImportActionKind::Skipped, original_name: name.clone(), final_name: Some(name.clone()), category_id: Some(existing_id), reason: Some("duplicate_name".into()), predicted_name: None, existing_category_id: Some(existing_id), existing_category_name: None, final_classification: Some(classification.clone()), final_parent_id: parent_id }); continue 'outer; }
                "update" => {
                    // Update existing entry fields
                    if !dry_run {
                        let _ = sqlx::query(
                            "UPDATE categories SET color=COALESCE($1,color), icon=COALESCE($2,icon), classification=$3, updated_at=NOW() WHERE id=$4"
                        )
                        .bind(&color)
                        .bind(&icon)
                        .bind(&classification)
                        .bind(existing_id)
                        .execute(&pool).await.map_err(|_| StatusCode::BAD_REQUEST)?;
                        // Return updated row
                        let row = sqlx::query(
                            "SELECT id, ledger_id, name, color, icon, classification, parent_id, position, usage_count, last_used_at FROM categories WHERE id=$1"
                        ).bind(existing_id).fetch_one(&pool).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
                        result_items.push(CategoryDto{
                            id: row.get("id"), ledger_id: row.get("ledger_id"), name: row.get("name"),
                            color: row.try_get("color").ok(), icon: row.try_get("icon").ok(), classification: row.get("classification"),
                            parent_id: row.try_get("parent_id").ok(), position: row.try_get("position").unwrap_or(0),
                            usage_count: row.try_get("usage_count").unwrap_or(0), last_used_at: row.try_get("last_used_at").ok(),
                        });
                    }
                    imported += 1; // treat update as success
                    details.push(ImportActionDetail{ template_id, action: ImportActionKind::Updated, original_name: name.clone(), final_name: Some(name.clone()), category_id: Some(existing_id), reason: None, predicted_name: None, existing_category_id: Some(existing_id), existing_category_name: None, final_classification: Some(classification.clone()), final_parent_id: parent_id });
                    continue 'outer;
                }
                "rename" => {
                    // Find unique name by suffix
                    let mut suffix = 2;
                    let base = name.clone();
                    loop {
                        let candidate = format!("{} ({})", base, suffix);
                        let taken: Option<(Uuid,)> = sqlx::query_as(
                            "SELECT id FROM categories WHERE ledger_id=$1 AND LOWER(name)=LOWER($2) AND is_deleted=false LIMIT 1"
                        ).bind(&req.ledger_id).bind(&candidate).fetch_optional(&pool).await.map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
                        if taken.is_none() { name = candidate; break; }
                        suffix += 1;
                        if suffix > 100 { failed += 1; details.push(ImportActionDetail{ template_id, action: ImportActionKind::Failed, original_name: base.clone(), final_name: None, category_id: None, reason: Some("rename_exhausted".into()), predicted_name: None, existing_category_id: Some(existing_id), existing_category_name: None, final_classification: Some(classification.clone()), final_parent_id: parent_id }); continue 'outer; }
                    }
                }
                _ => { skipped += 1; continue 'outer; }
            }
        }

        // Insert new row (or simulate in dry_run)
        let rec = if dry_run {
            // Skip actual DB write
            Err(sqlx::Error::Protocol("dry_run".into()))
        } else {
            Ok(sqlx::query(
                r#"INSERT INTO categories (id, ledger_id, name, color, icon, classification, parent_id, position, usage_count, source_type, template_id, template_version)
                   VALUES ($1,$2,$3,$4,$5,$6,$7,
                           COALESCE((SELECT COALESCE(MAX(position),-1)+1 FROM categories WHERE ledger_id=$2 AND parent_id IS NOT DISTINCT FROM $7),0),
                           0,'system',$8,$9)
                   RETURNING id, ledger_id, name, color, icon, classification, parent_id, position, usage_count, last_used_at"#
            ))
        };

        let query_result = match rec {
            Ok(query) => {
                query
                    .bind(Uuid::new_v4())
                    .bind(&req.ledger_id)
                    .bind(&name)
                    .bind(&color)
                    .bind(&icon)
                    .bind(&classification)
                    .bind(&parent_id)
                    .bind(template_id)
                    .bind(template_version)
                    .fetch_one(&pool).await
            },
            Err(e) => Err(e)
        };

        match query_result {
            Ok(row) => {
                result_items.push(CategoryDto{
                    id: row.get("id"), ledger_id: row.get("ledger_id"), name: row.get("name"),
                    color: row.try_get("color").ok(), icon: row.try_get("icon").ok(), classification: row.get("classification"),
                    parent_id: row.try_get("parent_id").ok(), position: row.try_get("position").unwrap_or(0),
                    usage_count: row.try_get("usage_count").unwrap_or(0), last_used_at: row.try_get("last_used_at").ok(),
                });
                imported += 1;
                details.push(ImportActionDetail{ template_id, action: if exists.is_some() { ImportActionKind::Renamed } else { ImportActionKind::Imported }, original_name: tpl.get::<String,_>("name"), final_name: Some(name.clone()), category_id: Some(row.get("id")), reason: None, predicted_name: None, existing_category_id: exists.map(|t| t.0), existing_category_name: None, final_classification: Some(classification.clone()), final_parent_id: parent_id });
            }
            Err(e) => {
                if dry_run {
                    imported += 1;
                    details.push(ImportActionDetail{ template_id, action: if exists.is_some() { ImportActionKind::Renamed } else { ImportActionKind::Imported }, original_name: tpl.get::<String,_>("name"), final_name: Some(name.clone()), category_id: None, reason: None, predicted_name: if exists.is_some() { Some(name.clone()) } else { None }, existing_category_id: exists.map(|t| t.0), existing_category_name: None, final_classification: Some(classification.clone()), final_parent_id: parent_id });
                } else {
                    eprintln!("batch_import insert error: {:?}", e);
                    failed += 1;
                    details.push(ImportActionDetail{ template_id, action: ImportActionKind::Failed, original_name: name.clone(), final_name: None, category_id: None, reason: Some("insert_error".into()), predicted_name: None, existing_category_id: exists.map(|t| t.0), existing_category_name: None, final_classification: Some(classification.clone()), final_parent_id: parent_id });
                }
            }
        }
    }

    Ok(Json(BatchImportResult{ imported, skipped, failed, categories: result_items, details }))
}
