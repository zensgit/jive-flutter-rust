use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    Extension,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use uuid::Uuid;

use crate::models::{
    family::{CreateFamilyRequest, Family, UpdateFamilyRequest},
    permission::Permission,
};
use crate::services::{FamilyService, ServiceContext, ServiceError};
use crate::AppState;

#[derive(Debug, Serialize)]
pub struct ApiResponse<T> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<ApiError>,
    pub timestamp: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Serialize)]
pub struct ApiError {
    pub code: String,
    pub message: String,
    pub details: Option<Value>,
}

impl<T> ApiResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
            timestamp: chrono::Utc::now(),
        }
    }
    
    pub fn error(code: String, message: String) -> ApiResponse<()> {
        ApiResponse {
            success: false,
            data: None,
            error: Some(ApiError {
                code,
                message,
                details: None,
            }),
            timestamp: chrono::Utc::now(),
        }
    }
}

// Create new family
pub async fn create_family(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Json(request): Json<CreateFamilyRequest>,
) -> Result<Json<ApiResponse<Family>>, StatusCode> {
    let service = FamilyService::new(state.pool.clone());
    
    match service.create_family(user_id, request).await {
        Ok(family) => Ok(Json(ApiResponse::success(family))),
        Err(e) => {
            eprintln!("Error creating family: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// List user's families
pub async fn list_families(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
) -> Result<Json<ApiResponse<Vec<Family>>>, StatusCode> {
    let service = FamilyService::new(state.pool.clone());
    
    match service.get_user_families(user_id).await {
        Ok(families) => Ok(Json(ApiResponse::success(families))),
        Err(e) => {
            eprintln!("Error listing families: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Get family details
pub async fn get_family(
    State(state): State<AppState>,
    Path(family_id): Path<Uuid>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<Json<ApiResponse<Family>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let service = FamilyService::new(state.pool.clone());
    
    match service.get_family(&ctx, family_id).await {
        Ok(family) => Ok(Json(ApiResponse::success(family))),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(ServiceError::NotFound { .. }) => Err(StatusCode::NOT_FOUND),
        Err(e) => {
            eprintln!("Error getting family: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Update family
pub async fn update_family(
    State(state): State<AppState>,
    Path(family_id): Path<Uuid>,
    Extension(ctx): Extension<ServiceContext>,
    Json(request): Json<UpdateFamilyRequest>,
) -> Result<Json<ApiResponse<Family>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let service = FamilyService::new(state.pool.clone());
    
    match service.update_family(&ctx, family_id, request).await {
        Ok(family) => Ok(Json(ApiResponse::success(family))),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(ServiceError::NotFound { .. }) => Err(StatusCode::NOT_FOUND),
        Err(e) => {
            eprintln!("Error updating family: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Delete family
pub async fn delete_family(
    State(state): State<AppState>,
    Path(family_id): Path<Uuid>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<StatusCode, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let service = FamilyService::new(state.pool.clone());
    
    match service.delete_family(&ctx, family_id).await {
        Ok(()) => Ok(StatusCode::NO_CONTENT),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(ServiceError::BusinessRuleViolation(_)) => Err(StatusCode::BAD_REQUEST),
        Err(e) => {
            eprintln!("Error deleting family: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Switch current family
#[derive(Debug, Deserialize)]
pub struct SwitchFamilyRequest {
    pub family_id: Uuid,
}

pub async fn switch_family(
    State(state): State<AppState>,
    Extension(user_id): Extension<Uuid>,
    Json(request): Json<SwitchFamilyRequest>,
) -> Result<StatusCode, StatusCode> {
    let service = FamilyService::new(state.pool.clone());
    
    match service.switch_family(user_id, request.family_id).await {
        Ok(()) => Ok(StatusCode::OK),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(e) => {
            eprintln!("Error switching family: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Regenerate invite code
pub async fn regenerate_invite_code(
    State(state): State<AppState>,
    Path(family_id): Path<Uuid>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<Json<ApiResponse<String>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }
    
    let service = FamilyService::new(state.pool.clone());
    
    match service.regenerate_invite_code(&ctx, family_id).await {
        Ok(code) => Ok(Json(ApiResponse::success(code))),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(e) => {
            eprintln!("Error regenerating invite code: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}