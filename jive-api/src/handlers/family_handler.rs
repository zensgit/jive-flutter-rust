use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::Json,
    Extension,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use uuid::Uuid;

use crate::models::family::{CreateFamilyRequest, Family, UpdateFamilyRequest};

#[derive(Debug, Deserialize)]
pub struct JoinFamilyRequest {
    pub invite_code: String,
}

use crate::services::{FamilyService, ServiceContext, ServiceError};
use sqlx::PgPool;

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
    State(pool): State<PgPool>,
    claims: crate::auth::Claims,
    Json(request): Json<CreateFamilyRequest>,
) -> Result<Json<ApiResponse<Family>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };

    let service = FamilyService::new(pool.clone());

    match service.create_family(user_id, request).await {
        Ok(family) => Ok(Json(ApiResponse::success(family))),
        Err(ServiceError::Conflict(msg)) => Ok(Json(ApiResponse::<Family> {
            success: false,
            data: None,
            error: Some(ApiError {
                code: "FAMILY_ALREADY_EXISTS".to_string(),
                message: msg,
                details: None,
            }),
            timestamp: chrono::Utc::now(),
        })),
        Err(e) => {
            eprintln!("Error creating family: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// List user's families
pub async fn list_families(
    State(pool): State<PgPool>,
    claims: crate::auth::Claims,
) -> Result<Json<ApiResponse<Vec<Family>>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };

    let service = FamilyService::new(pool.clone());

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
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<Json<ApiResponse<Family>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }

    let service = FamilyService::new(pool.clone());

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
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
    Extension(ctx): Extension<ServiceContext>,
    Json(request): Json<UpdateFamilyRequest>,
) -> Result<Json<ApiResponse<Family>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }

    let service = FamilyService::new(pool.clone());

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
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
    claims: crate::auth::Claims,
) -> Result<StatusCode, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };

    // Verify user is owner of the family
    let role: Option<String> =
        sqlx::query_scalar("SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2")
            .bind(family_id)
            .bind(user_id)
            .fetch_optional(&pool)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if role.as_deref() != Some("owner") {
        return Err(StatusCode::FORBIDDEN);
    }

    // Create a minimal context for the service
    let ctx = ServiceContext::new(
        user_id,
        family_id,
        crate::models::permission::MemberRole::Owner,
        vec![crate::models::permission::Permission::DeleteFamily],
        String::new(),
        None,
    );

    let service = FamilyService::new(pool.clone());

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

// Join family by invite code
pub async fn join_family(
    State(pool): State<PgPool>,
    claims: crate::auth::Claims,
    Json(request): Json<JoinFamilyRequest>,
) -> Result<Json<ApiResponse<Family>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };

    let service = FamilyService::new(pool.clone());

    match service
        .join_family_by_invite_code(user_id, request.invite_code)
        .await
    {
        Ok(family) => Ok(Json(ApiResponse::success(family))),
        Err(ServiceError::InvalidInvitation) => Ok(Json(ApiResponse::<Family> {
            success: false,
            data: None,
            error: Some(ApiError {
                code: "INVALID_INVITE_CODE".to_string(),
                message: "邀请码无效或已过期".to_string(),
                details: None,
            }),
            timestamp: chrono::Utc::now(),
        })),
        Err(ServiceError::Conflict(msg)) => Ok(Json(ApiResponse::<Family> {
            success: false,
            data: None,
            error: Some(ApiError {
                code: "ALREADY_MEMBER".to_string(),
                message: msg,
                details: None,
            }),
            timestamp: chrono::Utc::now(),
        })),
        Err(e) => {
            eprintln!("Error joining family: {:?}", e);
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
    State(pool): State<PgPool>,
    Extension(user_id): Extension<Uuid>,
    Json(request): Json<SwitchFamilyRequest>,
) -> Result<StatusCode, StatusCode> {
    let service = FamilyService::new(pool.clone());

    match service.switch_family(user_id, request.family_id).await {
        Ok(()) => Ok(StatusCode::OK),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(e) => {
            eprintln!("Error switching family: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Get family statistics
pub async fn get_family_statistics(
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
    claims: crate::auth::Claims,
) -> Result<Json<ApiResponse<serde_json::Value>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };

    // Verify user is member of the family
    let is_member: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)",
    )
    .bind(family_id)
    .bind(user_id)
    .fetch_one(&pool)
    .await
    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if !is_member {
        return Err(StatusCode::FORBIDDEN);
    }

    let service = FamilyService::new(pool.clone());

    match service.get_family_statistics(family_id).await {
        Ok(stats) => Ok(Json(ApiResponse::success(stats))),
        Err(e) => {
            eprintln!("Error getting family statistics: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Regenerate invite code
pub async fn regenerate_invite_code(
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
    Extension(ctx): Extension<ServiceContext>,
) -> Result<Json<ApiResponse<String>>, StatusCode> {
    if ctx.family_id != family_id {
        return Err(StatusCode::FORBIDDEN);
    }

    let service = FamilyService::new(pool.clone());

    match service.regenerate_invite_code(&ctx, family_id).await {
        Ok(code) => Ok(Json(ApiResponse::success(code))),
        Err(ServiceError::PermissionDenied) => Err(StatusCode::FORBIDDEN),
        Err(e) => {
            eprintln!("Error regenerating invite code: {:?}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

// Request verification code for sensitive operations
#[derive(Debug, Deserialize)]
pub struct RequestVerificationRequest {
    pub operation: String, // "leave_family" or "delete_user"
}

#[derive(Debug, Serialize)]
pub struct VerificationCodeResponse {
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub code: Option<String>, // Only for testing, remove in production
}

pub async fn request_verification_code(
    State(pool): State<PgPool>,
    State(redis): State<Option<redis::aio::ConnectionManager>>,
    claims: crate::auth::Claims,
    Json(request): Json<RequestVerificationRequest>,
) -> Result<Json<ApiResponse<VerificationCodeResponse>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };

    if let Some(redis_conn) = redis {
        let verification_service = crate::services::VerificationService::new(Some(redis_conn));

        // Get user email for sending code
        let email: Option<String> = sqlx::query_scalar("SELECT email FROM users WHERE id = $1")
            .bind(user_id)
            .fetch_optional(&pool)
            .await
            .unwrap_or(None);

        let email = email.unwrap_or_else(|| "user@example.com".to_string());

        match verification_service
            .send_verification_code(&user_id.to_string(), &request.operation, &email)
            .await
        {
            Ok(code) => {
                // In production, don't return the code
                Ok(Json(ApiResponse {
                    success: true,
                    data: Some(VerificationCodeResponse {
                        message: format!("验证码已发送至 {}", email),
                        code: Some(code), // Remove this in production
                    }),
                    error: None,
                    timestamp: chrono::Utc::now(),
                }))
            }
            Err(e) => {
                eprintln!("Error sending verification code: {:?}", e);
                Ok(Json(ApiResponse {
                    success: false,
                    data: None,
                    error: Some(ApiError {
                        code: "VERIFICATION_SERVICE_ERROR".to_string(),
                        message: "验证码服务暂时不可用".to_string(),
                        details: None,
                    }),
                    timestamp: chrono::Utc::now(),
                }))
            }
        }
    } else {
        // Redis not available, return mock response for development
        Ok(Json(ApiResponse {
            success: true,
            data: Some(VerificationCodeResponse {
                message: "验证码已发送 (开发模式 - Redis未启用)".to_string(),
                code: Some("123456".to_string()), // Mock code for testing
            }),
            error: None,
            timestamp: chrono::Utc::now(),
        }))
    }
}

// Leave family with verification
#[derive(Debug, Deserialize)]
pub struct LeaveFamilyRequest {
    pub family_id: Uuid,
    pub verification_code: String,
}

pub async fn leave_family(
    State(pool): State<PgPool>,
    State(redis): State<Option<redis::aio::ConnectionManager>>,
    claims: crate::auth::Claims,
    Json(request): Json<LeaveFamilyRequest>,
) -> Result<Json<ApiResponse<()>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };

    // Verify the code first
    if let Some(redis_conn) = redis {
        let verification_service = crate::services::VerificationService::new(Some(redis_conn));

        match verification_service
            .verify_code(
                &user_id.to_string(),
                "leave_family",
                &request.verification_code,
            )
            .await
        {
            Ok(true) => {
                // Code is valid, proceed with leaving family
                let service = FamilyService::new(pool.clone());

                match service.leave_family(user_id, request.family_id).await {
                    Ok(()) => Ok(Json(ApiResponse::success(()))),
                    Err(ServiceError::BusinessRuleViolation(msg)) => Ok(Json(ApiResponse::<()> {
                        success: false,
                        data: None,
                        error: Some(ApiError {
                            code: "CANNOT_LEAVE".to_string(),
                            message: msg,
                            details: None,
                        }),
                        timestamp: chrono::Utc::now(),
                    })),
                    Err(e) => {
                        eprintln!("Error leaving family: {:?}", e);
                        Err(StatusCode::INTERNAL_SERVER_ERROR)
                    }
                }
            }
            Ok(false) => Ok(Json(ApiResponse::<()> {
                success: false,
                data: None,
                error: Some(ApiError {
                    code: "INVALID_VERIFICATION_CODE".to_string(),
                    message: "验证码错误或已过期".to_string(),
                    details: None,
                }),
                timestamp: chrono::Utc::now(),
            })),
            Err(_) => Ok(Json(ApiResponse::<()> {
                success: false,
                data: None,
                error: Some(ApiError {
                    code: "VERIFICATION_SERVICE_ERROR".to_string(),
                    message: "验证码服务暂时不可用".to_string(),
                    details: None,
                }),
                timestamp: chrono::Utc::now(),
            })),
        }
    } else {
        // Redis not available, proceed without verification in development
        let service = FamilyService::new(pool.clone());

        match service.leave_family(user_id, request.family_id).await {
            Ok(()) => Ok(Json(ApiResponse::success(()))),
            Err(ServiceError::BusinessRuleViolation(msg)) => Ok(Json(ApiResponse::<()> {
                success: false,
                data: None,
                error: Some(ApiError {
                    code: "CANNOT_LEAVE".to_string(),
                    message: msg,
                    details: None,
                }),
                timestamp: chrono::Utc::now(),
            })),
            Err(e) => {
                eprintln!("Error leaving family: {:?}", e);
                Err(StatusCode::INTERNAL_SERVER_ERROR)
            }
        }
    }
}
// Get family action permissions
pub async fn get_family_actions(
    State(pool): State<PgPool>,
    Path(family_id): Path<Uuid>,
    claims: crate::auth::Claims,
) -> Result<Json<ApiResponse<serde_json::Value>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };

    // Get user's role in the family
    let role: Option<String> =
        sqlx::query_scalar("SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2")
            .bind(family_id)
            .bind(user_id)
            .fetch_optional(&pool)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    let is_owner = role.as_deref() == Some("owner");

    // Check if family has multiple members (for delete button visibility)
    let member_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM family_members WHERE family_id = $1")
            .bind(family_id)
            .fetch_one(&pool)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    // Determine available actions
    let can_leave = !is_owner; // Can leave if not owner
    let can_delete = is_owner && member_count > 1; // Can delete if owner and has invited others
    let can_invite = is_owner || role.as_deref() == Some("admin"); // Can invite if owner or admin
    let can_manage_members = is_owner || role.as_deref() == Some("admin");

    Ok(Json(ApiResponse::success(serde_json::json!({
        "can_leave": can_leave,
        "can_delete": can_delete,
        "can_invite": can_invite,
        "can_manage_members": can_manage_members,
        "is_owner": is_owner,
        "member_count": member_count,
        "role": role.unwrap_or_else(|| "none".to_string())
    }))))
}

// Get role descriptions
pub async fn get_role_descriptions() -> Result<Json<ApiResponse<serde_json::Value>>, StatusCode> {
    let roles = serde_json::json!({
        "roles": [
            {
                "role": "owner",
                "name": "拥有者",
                "name_en": "Owner",
                "description": "家庭创建者，拥有所有权限",
                "description_en": "Family creator with full permissions",
                "permissions": [
                    "管理所有成员",
                    "转让所有权",
                    "删除家庭",
                    "修改家庭设置",
                    "管理所有账本",
                    "查看所有数据"
                ],
                "permissions_en": [
                    "Manage all members",
                    "Transfer ownership",
                    "Delete family",
                    "Modify family settings",
                    "Manage all ledgers",
                    "View all data"
                ],
                "color": "#FF6B6B",
                "icon": "crown"
            },
            {
                "role": "admin",
                "name": "管理员",
                "name_en": "Administrator",
                "description": "协助管理家庭，拥有大部分权限",
                "description_en": "Assists in family management with most permissions",
                "permissions": [
                    "管理普通成员",
                    "邀请新成员",
                    "修改家庭设置",
                    "管理账本",
                    "查看所有数据"
                ],
                "permissions_en": [
                    "Manage regular members",
                    "Invite new members",
                    "Modify family settings",
                    "Manage ledgers",
                    "View all data"
                ],
                "color": "#4ECDC4",
                "icon": "shield"
            },
            {
                "role": "member",
                "name": "成员",
                "name_en": "Member",
                "description": "普通家庭成员，拥有基本权限",
                "description_en": "Regular family member with basic permissions",
                "permissions": [
                    "查看家庭数据",
                    "管理自己的交易",
                    "使用共享账本",
                    "查看报表"
                ],
                "permissions_en": [
                    "View family data",
                    "Manage own transactions",
                    "Use shared ledgers",
                    "View reports"
                ],
                "color": "#95E1D3",
                "icon": "user"
            },
            {
                "role": "viewer",
                "name": "观察者",
                "name_en": "Viewer",
                "description": "只读权限，仅可查看",
                "description_en": "Read-only permissions, view only",
                "permissions": [
                    "查看家庭数据",
                    "查看报表"
                ],
                "permissions_en": [
                    "View family data",
                    "View reports"
                ],
                "color": "#C9C9C9",
                "icon": "eye"
            }
        ],
        "comparison": {
            "features": [
                {
                    "feature": "邀请成员",
                    "feature_en": "Invite members",
                    "owner": true,
                    "admin": true,
                    "member": false,
                    "viewer": false
                },
                {
                    "feature": "管理成员角色",
                    "feature_en": "Manage member roles",
                    "owner": true,
                    "admin": true,
                    "member": false,
                    "viewer": false
                },
                {
                    "feature": "删除成员",
                    "feature_en": "Remove members",
                    "owner": true,
                    "admin": true,
                    "member": false,
                    "viewer": false
                },
                {
                    "feature": "创建账本",
                    "feature_en": "Create ledgers",
                    "owner": true,
                    "admin": true,
                    "member": false,
                    "viewer": false
                },
                {
                    "feature": "添加交易",
                    "feature_en": "Add transactions",
                    "owner": true,
                    "admin": true,
                    "member": true,
                    "viewer": false
                },
                {
                    "feature": "查看数据",
                    "feature_en": "View data",
                    "owner": true,
                    "admin": true,
                    "member": true,
                    "viewer": true
                },
                {
                    "feature": "删除家庭",
                    "feature_en": "Delete family",
                    "owner": true,
                    "admin": false,
                    "member": false,
                    "viewer": false
                },
                {
                    "feature": "转让所有权",
                    "feature_en": "Transfer ownership",
                    "owner": true,
                    "admin": false,
                    "member": false,
                    "viewer": false
                }
            ]
        }
    });

    Ok(Json(ApiResponse::success(roles)))
}

// Transfer family ownership
#[derive(Debug, Deserialize)]
pub struct TransferOwnershipRequest {
    pub new_owner_id: Uuid,
    pub verification_code: String,
}

pub async fn transfer_ownership(
    State(pool): State<PgPool>,
    State(redis): State<Option<redis::aio::ConnectionManager>>,
    Path(family_id): Path<Uuid>,
    claims: crate::auth::Claims,
    Json(request): Json<TransferOwnershipRequest>,
) -> Result<Json<ApiResponse<()>>, StatusCode> {
    let user_id = match claims.user_id() {
        Ok(id) => id,
        Err(_) => return Err(StatusCode::UNAUTHORIZED),
    };

    // Verify user is the current owner
    let role: Option<String> =
        sqlx::query_scalar("SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2")
            .bind(family_id)
            .bind(user_id)
            .fetch_optional(&pool)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

    if role.as_deref() != Some("owner") {
        return Ok(Json(ApiResponse::<()> {
            success: false,
            data: None,
            error: Some(ApiError {
                code: "NOT_OWNER".to_string(),
                message: "只有拥有者才能转让所有权".to_string(),
                details: None,
            }),
            timestamp: chrono::Utc::now(),
        }));
    }

    // Verify the verification code
    if let Some(redis_conn) = redis {
        let verification_service = crate::services::VerificationService::new(Some(redis_conn));

        match verification_service
            .verify_code(
                &user_id.to_string(),
                "transfer_ownership",
                &request.verification_code,
            )
            .await
        {
            Ok(true) => {
                // Verify new owner exists and is a member
                let new_owner_role: Option<String> = sqlx::query_scalar(
                    "SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2",
                )
                .bind(family_id)
                .bind(request.new_owner_id)
                .fetch_optional(&pool)
                .await
                .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                if new_owner_role.is_none() {
                    return Ok(Json(ApiResponse::<()> {
                        success: false,
                        data: None,
                        error: Some(ApiError {
                            code: "USER_NOT_MEMBER".to_string(),
                            message: "目标用户不是家庭成员".to_string(),
                            details: None,
                        }),
                        timestamp: chrono::Utc::now(),
                    }));
                }

                // Start transaction
                let mut tx = pool
                    .begin()
                    .await
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                // Update old owner to admin
                sqlx::query(
                "UPDATE family_members SET role = 'admin' WHERE family_id = $1 AND user_id = $2"
            )
            .bind(family_id)
            .bind(user_id)
            .execute(&mut *tx)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                // Update new owner
                let owner_permissions =
                    crate::models::permission::MemberRole::Owner.default_permissions();
                let permissions_json = serde_json::to_value(&owner_permissions)
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                sqlx::query(
                "UPDATE family_members SET role = 'owner', permissions = $1 WHERE family_id = $2 AND user_id = $3"
            )
            .bind(permissions_json)
            .bind(family_id)
            .bind(request.new_owner_id)
            .execute(&mut *tx)
            .await
            .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                // Commit transaction
                tx.commit()
                    .await
                    .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?;

                Ok(Json(ApiResponse::success(())))
            }
            Ok(false) => Ok(Json(ApiResponse::<()> {
                success: false,
                data: None,
                error: Some(ApiError {
                    code: "INVALID_VERIFICATION_CODE".to_string(),
                    message: "验证码错误或已过期".to_string(),
                    details: None,
                }),
                timestamp: chrono::Utc::now(),
            })),
            Err(_) => Ok(Json(ApiResponse::<()> {
                success: false,
                data: None,
                error: Some(ApiError {
                    code: "VERIFICATION_SERVICE_ERROR".to_string(),
                    message: "验证码服务暂时不可用".to_string(),
                    details: None,
                }),
                timestamp: chrono::Utc::now(),
            })),
        }
    } else {
        // Redis not available, return error for this sensitive operation
        Ok(Json(ApiResponse::<()> {
            success: false,
            data: None,
            error: Some(ApiError {
                code: "SERVICE_UNAVAILABLE".to_string(),
                message: "验证服务暂时不可用，无法进行所有权转让".to_string(),
                details: None,
            }),
            timestamp: chrono::Utc::now(),
        }))
    }
}
