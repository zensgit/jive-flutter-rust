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
