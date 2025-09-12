use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
};
use serde::Deserialize;
use uuid::Uuid;

use crate::models::{
    membership::{FamilyMember},
    permission::{MemberRole, Permission},
};
use crate::services::{MemberService, ServiceError};
use sqlx::PgPool;
use sqlx;

use super::family_handler::ApiResponse;

// Add member request
#[derive(Debug, Deserialize)]
pub struct AddMemberRequest {
    pub user_id: Uuid,
    pub role: MemberRole,
}

// Update role request
#[derive(Debug, Deserialize)]
pub struct UpdateRoleRequest {
    pub role: MemberRole,
}

// Update permissions request
#[derive(Debug, Deserialize)]
pub struct UpdatePermissionsRequest {
    pub permissions: Vec<Permission>,
}

// Get family members
pub async fn get_family_members(
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
    claims: crate::auth::Claims,
) -> Result<Json<ApiResponse<Vec<serde_json::Value>>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };
    
    // Verify user is member of the family
    let is_member: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)"
    )
    .bind(family_id)
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;
    
    if !is_member {
        return Err(StatusCode::FORBIDDEN);
    }
    
    // Get all members with user info
    let members: Vec<serde_json::Value> = sqlx::query_as::<_, (Uuid, String, String, chrono::DateTime<chrono::Utc>, Option<String>, Option<String>)>(
        r#"
        SELECT 
            fm.user_id,
            fm.role,
            COALESCE(u.full_name, u.email) as display_name,
            fm.joined_at,
            u.email,
            u.avatar_url
        FROM family_members fm
        JOIN users u ON fm.user_id = u.id
        WHERE fm.family_id = $1
        ORDER BY fm.joined_at ASC
        "#
    )
    .bind(family_id)
    .fetch_all(&pool)
    .await
    .map_err(|e| {
        eprintln!("Error getting family members: {:?}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?
    .into_iter()
    .map(|(user_id, role, display_name, joined_at, email, avatar_url)| {
        serde_json::json!({
            "user_id": user_id,
            "role": role,
            "display_name": display_name,
            "joined_at": joined_at,
            "email": email,
            "avatar_url": avatar_url
        })
    })
    .collect();
    
    Ok(Json(ApiResponse::success(members)))
}

// Add member to family
pub async fn add_member(
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
    claims: crate::auth::Claims,
    Json(request): Json<AddMemberRequest>,
) -> Result<Json<ApiResponse<FamilyMember>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };
    
    // Verify user is member of the family and get their context
    let service = MemberService::new(pool.clone());
    
    // Get member context to check permissions
    let ctx = match service.get_member_context(user_id, family_id).await {
        Ok(context) => context,
        Err(_) => return Err(StatusCode::FORBIDDEN),
    };
    
    match service.add_member(&ctx, request.user_id, request.role).await {
        Ok(member) => Ok(Json(ApiResponse::success(member))),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(ServiceError::MemberAlreadyExists) => Err(StatusCode::CONFLICT),
        Err(e) => {
            eprintln!("Error adding member: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Remove member from family
pub async fn remove_member(
    State(pool): State<PgPool>,
    Path((family_id, member_id)): Path<(Uuid, Uuid)>,
    claims: crate::auth::Claims,
) -> Result<StatusCode, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };
    
    let service = MemberService::new(pool.clone());
    
    // Get member context to check permissions
    let ctx = match service.get_member_context(user_id, family_id).await {
        Ok(context) => context,
        Err(_) => return Err(StatusCode::FORBIDDEN),
    };
    
    match service.remove_member(&ctx, member_id).await {
        Ok(()) => Ok(StatusCode::NO_CONTENT),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(ServiceError::NotFound { .. }) => Err(StatusCode::NOT_FOUND),
        Err(ServiceError::CannotRemoveOwner) => Err(StatusCode::BAD_REQUEST),
        Err(e) => {
            eprintln!("Error removing member: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Update member role
pub async fn update_member_role(
    State(pool): State<PgPool>,
    Path((family_id, member_id)): Path<(Uuid, Uuid)>,
    claims: crate::auth::Claims,
    Json(request): Json<UpdateRoleRequest>,
) -> Result<Json<ApiResponse<FamilyMember>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };
    
    let service = MemberService::new(pool.clone());
    
    // Get member context to check permissions
    let ctx = match service.get_member_context(user_id, family_id).await {
        Ok(context) => context,
        Err(_) => return Err(StatusCode::FORBIDDEN),
    };
    
    match service.update_member_role(&ctx, member_id, request.role).await {
        Ok(member) => Ok(Json(ApiResponse::success(member))),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(ServiceError::NotFound { .. }) => Err(StatusCode::NOT_FOUND),
        Err(ServiceError::CannotChangeOwnerRole) => Err(StatusCode::BAD_REQUEST),
        Err(e) => {
            eprintln!("Error updating member role: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Update member permissions
pub async fn update_member_permissions(
    State(pool): State<PgPool>,
    Path((family_id, member_id)): Path<(Uuid, Uuid)>,
    claims: crate::auth::Claims,
    Json(request): Json<UpdatePermissionsRequest>,
) -> Result<Json<ApiResponse<FamilyMember>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };
    
    let service = MemberService::new(pool.clone());
    
    // Get member context to check permissions
    let ctx = match service.get_member_context(user_id, family_id).await {
        Ok(context) => context,
        Err(_) => return Err(StatusCode::FORBIDDEN),
    };
    
    match service.update_member_permissions(&ctx, member_id, request.permissions).await {
        Ok(member) => Ok(Json(ApiResponse::success(member))),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(ServiceError::NotFound { .. }) => Err(StatusCode::NOT_FOUND),
        Err(ServiceError::BusinessRuleViolation(_)) => Err(StatusCode::BAD_REQUEST),
        Err(e) => {
            eprintln!("Error updating member permissions: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
