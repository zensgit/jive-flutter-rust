use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    Extension,
};
use serde::Serialize;
use uuid::Uuid;

use crate::models::invitation::{
    AcceptInvitationRequest, CreateInvitationRequest, InvitationResponse,
};
use crate::services::{InvitationService, ServiceContext, ServiceError};
use sqlx::PgPool;

use super::family_handler::ApiResponse;

// Create invitation
pub async fn create_invitation(
    State(pool): State<PgPool>,
    Extension(ctx): Extension<ServiceContext>,
    Json(request): Json<CreateInvitationRequest>,
) -> Result<Json<ApiResponse<InvitationResponse>>, StatusCode> {
    let service = InvitationService::new(pool.clone());

    match service.create_invitation(&ctx, request).await {
        Ok(invitation) => Ok(Json(ApiResponse::success(invitation))),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(ServiceError::Conflict(_)) => Err(StatusCode::CONFLICT),
        Err(e) => {
            eprintln!("Error creating invitation: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Get pending invitations
pub async fn get_pending_invitations(
    State(pool): State<PgPool>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<Json<ApiResponse<Vec<InvitationResponse>>>, StatusCode> {
    let service = InvitationService::new(pool.clone());

    match service.get_pending_invitations(&ctx).await {
        Ok(invitations) => Ok(Json(ApiResponse::success(invitations))),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(e) => {
            eprintln!("Error getting invitations: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Accept invitation response
#[derive(Debug, Serialize)]
pub struct AcceptInvitationResponse {
    pub family_id: Uuid,
    pub message: String,
}

// Accept invitation
pub async fn accept_invitation(
    State(pool): State<PgPool>,
    Extension(user_id): Extension<Uuid>,
    Json(request): Json<AcceptInvitationRequest>,
) -> Result<Json<ApiResponse<AcceptInvitationResponse>>, StatusCode> {
    let service = InvitationService::new(pool.clone());

    match service
        .accept_invitation(request.invite_code, request.invite_token, user_id)
        .await
    {
        Ok(family_id) => Ok(Json(ApiResponse::success(AcceptInvitationResponse {
            family_id,
            message: "Successfully joined family".to_string(),
        }))),
        Err(ServiceError::InvalidInvitation) => Err(StatusCode::BAD_REQUEST),
        Err(ServiceError::InvitationExpired) => Err(StatusCode::GONE),
        Err(ServiceError::MemberAlreadyExists) => Err(StatusCode::CONFLICT),
        Err(e) => {
            eprintln!("Error accepting invitation: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Cancel invitation
pub async fn cancel_invitation(
    State(pool): State<PgPool>,
    Path(invitation_id): Path<Uuid>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<StatusCode, StatusCode> {
    let service = InvitationService::new(pool.clone());

    match service.cancel_invitation(&ctx, invitation_id).await {
        Ok(()) => Ok(StatusCode::NO_CONTENT),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(ServiceError::NotFound { .. }) => Err(StatusCode::NOT_FOUND),
        Err(e) => {
            eprintln!("Error cancelling invitation: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Validate invite code
pub async fn validate_invite_code(
    State(pool): State<PgPool>,
    Path(code): Path<String>,
) -> Result<Json<ApiResponse<InvitationResponse>>, StatusCode> {
    let service = InvitationService::new(pool.clone());

    match service.validate_invite_code(&code).await {
        Ok(invitation) => Ok(Json(ApiResponse::success(invitation))),
        Err(ServiceError::InvalidInvitation) => Err(StatusCode::NOT_FOUND),
        Err(ServiceError::InvitationExpired) => Err(StatusCode::GONE),
        Err(e) => {
            eprintln!("Error validating invite code: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
