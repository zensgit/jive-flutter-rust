use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    Extension,
};
use serde::Deserialize;
use uuid::Uuid;

use crate::models::{
    membership::{FamilyMember, MemberWithUserInfo},
    permission::{MemberRole, Permission},
};
use crate::services::{MemberService, ServiceContext, ServiceError};
use crate::AppState;

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
    State(state): State<AppState>,
    Path(family_id): Path<Uuid>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<Json<ApiResponse<Vec<MemberWithUserInfo>>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let service = MemberService::new(state.pool.clone());
    
    match service.get_family_members(&ctx).await {
        Ok(members) => Ok(Json(ApiResponse::success(members))),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(e) => {
            eprintln!("Error getting members: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Add member to family
pub async fn add_member(
    State(state): State<AppState>,
    Path(family_id): Path<Uuid>,
    Extension(ctx): Extension<ServiceContext>,
    Json(request): Json<AddMemberRequest>,
) -> Result<Json<ApiResponse<FamilyMember>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let service = MemberService::new(state.pool.clone());
    
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
    State(state): State<AppState>,
    Path((family_id, user_id)): Path<(Uuid, Uuid)>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<StatusCode, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let service = MemberService::new(state.pool.clone());
    
    match service.remove_member(&ctx, user_id).await {
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
    State(state): State<AppState>,
    Path((family_id, user_id)): Path<(Uuid, Uuid)>,
    Extension(ctx): Extension<ServiceContext>,
    Json(request): Json<UpdateRoleRequest>,
) -> Result<Json<ApiResponse<FamilyMember>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let service = MemberService::new(state.pool.clone());
    
    match service.update_member_role(&ctx, user_id, request.role).await {
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
    State(state): State<AppState>,
    Path((family_id, user_id)): Path<(Uuid, Uuid)>,
    Extension(ctx): Extension<ServiceContext>,
    Json(request): Json<UpdatePermissionsRequest>,
) -> Result<Json<ApiResponse<FamilyMember>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let service = MemberService::new(state.pool.clone());
    
    match service.update_member_permissions(&ctx, user_id, request.permissions).await {
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