use axum::{
    extract::{Path, Query, State},
    http::{header, StatusCode},
    response::Response,
    Extension, Json,
};
use chrono::{DateTime, Utc};
use serde::Deserialize;
use uuid::Uuid;

use crate::models::audit::{AuditLog, AuditLogFilter};
use crate::services::{AuditService, ServiceContext};
use sqlx::PgPool;

use super::family_handler::ApiResponse;

// Query parameters for audit logs
#[derive(Debug, Deserialize)]
pub struct AuditLogQuery {
    pub user_id: Option<Uuid>,
    pub action: Option<String>,
    pub entity_type: Option<String>,
    pub from_date: Option<DateTime<Utc>>,
    pub to_date: Option<DateTime<Utc>>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

// Get audit logs
pub async fn get_audit_logs(
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
    Query(query): Query<AuditLogQuery>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<Json<ApiResponse<Vec<AuditLog>>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    
    // Check permission
    if ctx.require_permission(crate::models::permission::Permission::ViewAuditLog).is_err() {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let service = AuditService::new(pool.clone());
    
    let filter = AuditLogFilter {
        family_id: Some(family_id),
        user_id: query.user_id,
        action: query.action.and_then(|a| {
            use crate::models::audit::AuditAction;
            AuditAction::try_from(a).ok()
        }),
        entity_type: query.entity_type,
        from_date: query.from_date,
        to_date: query.to_date,
        limit: query.limit,
        offset: query.offset,
    };
    
    match service.get_audit_logs(filter).await {
        Ok(logs) => Ok(Json(ApiResponse::success(logs))),
        Err(e) => {
            eprintln!("Error getting audit logs: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Optional: delete old audit logs (admin only). Use with caution.
#[derive(Debug, Deserialize)]
pub struct CleanupAuditQuery {
    pub older_than_days: Option<i64>,
    pub limit: Option<i64>,
}

pub async fn cleanup_audit_logs(
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
    Query(query): Query<CleanupAuditQuery>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<Json<ApiResponse<serde_json::Value>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    // Require admin-level permission
    use crate::models::permission::Permission;
    if ctx.require_permission(Permission::ManageSettings).is_err() {
        return Err(StatusCode::FORBIDDEN);
    }

    let days = query.older_than_days.unwrap_or(90);
    let limit = query.limit.unwrap_or(1000).clamp(1, 10_000);

    // Enforce a hard limit by selecting candidate IDs first, then deleting by ID
    let deleted: i64 = sqlx::query_scalar(
        r#"
        WITH to_del AS (
            SELECT id
            FROM family_audit_logs
            WHERE family_id = $1 AND created_at < NOW() - ($2 || ' days')::interval
            ORDER BY created_at
            LIMIT $3
        ), del AS (
            DELETE FROM family_audit_logs
            WHERE id IN (SELECT id FROM to_del)
            RETURNING 1
        )
        SELECT COUNT(*) FROM del
        "#
    )
    .bind(family_id)
    .bind(days)
    .bind(limit)
    .fetch_one(&pool)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Log this cleanup operation into audit trail (best-effort)
    let _ = AuditService::new(pool.clone()).log_action(
        family_id,
        ctx.user_id,
        crate::models::audit::CreateAuditLogRequest {
            action: crate::models::audit::AuditAction::Delete,
            entity_type: "audit_logs".to_string(),
            entity_id: None,
            old_values: None,
            new_values: Some(serde_json::json!({
                "older_than_days": days,
                "limit": limit,
                "deleted": deleted,
            })),
        },
        None,
        None,
    ).await;

    Ok(Json(ApiResponse::success(serde_json::json!({
        "deleted": deleted,
        "older_than_days": days,
    }))))
}

// Export query parameters
#[derive(Debug, Deserialize)]
pub struct ExportQuery {
    pub from_date: DateTime<Utc>,
    pub to_date: DateTime<Utc>,
}

// Export audit logs as CSV
pub async fn export_audit_logs(
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
    Query(query): Query<ExportQuery>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<Response, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    
    // Check permission
    if ctx.require_permission(crate::models::permission::Permission::ViewAuditLog).is_err() {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let service = AuditService::new(pool.clone());
    
    match service.export_audit_report(family_id, query.from_date, query.to_date).await {
        Ok(csv) => {
            Ok(Response::builder()
                .status(StatusCode::OK)
                .header(header::CONTENT_TYPE, "text/csv")
                .header(
                    header::CONTENT_DISPOSITION,
                    format!("attachment; filename=\"audit_log_{}_{}.csv\"", 
                        query.from_date.format("%Y%m%d"),
                        query.to_date.format("%Y%m%d")
                    )
                )
                .body(csv.into())
                .unwrap())
        },
        Err(e) => {
            eprintln!("Error exporting audit logs: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
