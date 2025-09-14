use axum::{extract::{State, Query}, response::{Json, IntoResponse, Response}, http::{HeaderMap, HeaderValue, StatusCode}};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use crate::{auth::Claims, error::{ApiError, ApiResult}};
use crate::services::TagService;
use super::family_handler::ApiResponse;

#[derive(Debug, Deserialize)]
pub struct ListQuery { pub q: Option<String>, pub archived: Option<bool> }

#[derive(Debug, Deserialize)]
pub struct CreateTag { pub name: String, pub color: Option<String>, pub icon: Option<String>, pub group_id: Option<Uuid> }

#[derive(Debug, Deserialize)]
pub struct UpdateTag { pub name: Option<String>, pub color: Option<String>, pub icon: Option<String>, pub group_id: Option<Uuid>, pub archived: Option<bool> }

#[derive(Debug, Deserialize)]
pub struct MergeTags { pub from_ids: Vec<Uuid>, pub to_id: Uuid }

pub async fn list_tags(
    State(pool): State<PgPool>,
    claims: Claims,
    Query(q): Query<ListQuery>,
    headers: HeaderMap,
) -> ApiResult<Response> {
    let family_id = claims.family_id.ok_or(ApiError::BadRequest("No family selected".into()))?;

    // Compute ETag based on latest updated_at across family's tags
    // Use created_at since legacy tags table may not have updated_at
    let current_etag: String = sqlx::query_scalar!(
        r#"SELECT COALESCE(to_char(MAX(t.created_at), 'YYYYMMDDHH24MISS'), '0') as "max_ts!"
            FROM tags t
            JOIN ledgers l ON t.ledger_id = l.id
           WHERE l.family_id = $1"#,
        family_id
    )
    .fetch_one(&pool)
    .await
    .map_err(|_| ApiError::InternalServerError)?;
    let current_etag_value = format!("W/\"tags-{}\"", current_etag);

    if let Some(if_none_match) = headers.get("if-none-match").and_then(|v| v.to_str().ok()) {
        if if_none_match == current_etag_value {
            let mut resp = Response::builder()
                .status(StatusCode::NOT_MODIFIED)
                .header("ETag", HeaderValue::from_str(&current_etag_value).unwrap())
                .body(axum::body::Body::empty())
                .unwrap();
            return Ok(resp);
        }
    }

    let service = TagService::new(pool);
    let items = service.list_tags(family_id, q.q).await.map_err(|_| ApiError::InternalServerError)?;
    let body = Json(ApiResponse::success(serde_json::json!({"items": items})));
    let mut resp = body.into_response();
    resp.headers_mut().insert("ETag", HeaderValue::from_str(&current_etag_value).unwrap());
    Ok(resp)
}

pub async fn create_tag(State(pool): State<PgPool>, claims: Claims, Json(body): Json<CreateTag>) -> ApiResult<Json<ApiResponse<serde_json::Value>>> {
    let family_id = claims.family_id.ok_or(ApiError::BadRequest("No family selected".into()))?;
    if body.name.trim().is_empty() { return Err(ApiError::ValidationError("Empty tag name".into())); }
    let service = TagService::new(pool);
    let tag = service.create_tag(family_id, &body.name, body.color.as_deref(), None)
        .await.map_err(|e| ApiError::BadRequest(format!("Failed to create tag: {:?}", e)))?;
    Ok(Json(ApiResponse::success(serde_json::json!({"tag": tag}))))
}

pub async fn update_tag(State(pool): State<PgPool>, _claims: Claims, axum::extract::Path(id): axum::extract::Path<Uuid>, Json(body): Json<UpdateTag>) -> ApiResult<Json<ApiResponse<serde_json::Value>>> {
    let service = TagService::new(pool);
    let tag = service.update_tag(id, body.name.as_deref(), body.color.as_deref(), None).await.map_err(|e| ApiError::BadRequest(format!("Failed to update tag: {:?}", e)))?;
    Ok(Json(ApiResponse::success(serde_json::json!({"tag": tag}))))
}

pub async fn delete_tag(State(pool): State<PgPool>, _claims: Claims, axum::extract::Path(id): axum::extract::Path<Uuid>) -> ApiResult<Json<ApiResponse<serde_json::Value>>> {
    let service = TagService::new(pool);
    service.delete_tag(id).await.map_err(|e| ApiError::BadRequest(format!("Failed to delete tag: {:?}", e)))?;
    Ok(Json(ApiResponse::success(serde_json::json!({"ok": true}))))
}

pub async fn merge_tags(State(pool): State<PgPool>, claims: Claims, Json(body): Json<MergeTags>) -> ApiResult<Json<ApiResponse<serde_json::Value>>> {
    let family_id = claims.family_id.ok_or(ApiError::BadRequest("No family selected".into()))?;
    let service = TagService::new(pool);
    let merged = service.merge_tags(family_id, body.from_ids, body.to_id).await.map_err(|e| ApiError::BadRequest(format!("Failed to merge tags: {:?}", e)))?;
    Ok(Json(ApiResponse::success(serde_json::json!({"merged": merged}))))
}

pub async fn tag_summary(
    State(pool): State<PgPool>,
    claims: Claims,
) -> ApiResult<Json<ApiResponse<serde_json::Value>>> {
    let family_id = claims.family_id.ok_or(ApiError::BadRequest("No family selected".into()))?;
    let service = TagService::new(pool);
    let summary = service.summary(family_id).await.map_err(|_| ApiError::InternalServerError)?;
    Ok(Json(ApiResponse::success(serde_json::json!({"items": summary}))))
}
