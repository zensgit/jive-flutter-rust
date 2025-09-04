use axum::{
    routing::{delete, get, post, put},
    Router,
    middleware,
};

use crate::{
    handlers::{
        audit_handler::*,
        auth::*,
        family_handler::*,
        invitation_handler::*,
        member_handler::*,
    },
    middleware::{
        auth::{require_auth, family_context},
        permission::{require_permission, require_any_permission, require_owner, require_admin_or_owner},
    },
    models::permission::Permission,
    AppState,
};

/// Family路由（带权限控制）
pub fn family_routes_with_permissions() -> Router<AppState> {
    Router::new()
        // 创建Family（只需认证）
        .route("/families", post(create_family))
        .layer(middleware::from_fn(require_auth))
        
        // 获取用户的所有Family（只需认证）
        .route("/families", get(list_families))
        .layer(middleware::from_fn(require_auth))
        
        // Family详情（需要ViewFamilyInfo权限）
        .route("/families/:id", get(get_family))
        .layer(middleware::from_fn(move |req, next| {
            Box::pin(require_permission(Permission::ViewFamilyInfo)(req, next))
        }))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
        
        // 更新Family（需要UpdateFamilyInfo权限）
        .route("/families/:id", put(update_family))
        .layer(middleware::from_fn(move |req, next| {
            Box::pin(require_permission(Permission::UpdateFamilyInfo)(req, next))
        }))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
        
        // 删除Family（需要Owner角色）
        .route("/families/:id", delete(delete_family))
        .layer(middleware::from_fn(require_owner))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
}

/// 成员管理路由（带权限控制）
pub fn member_routes_with_permissions() -> Router<AppState> {
    Router::new()
        // 获取成员列表（需要ViewMembers权限）
        .route("/families/:id/members", get(get_family_members))
        .layer(middleware::from_fn(move |req, next| {
            Box::pin(require_permission(Permission::ViewMembers)(req, next))
        }))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
        
        // 添加成员（需要InviteMembers权限）
        .route("/families/:id/members", post(add_member))
        .layer(middleware::from_fn(move |req, next| {
            Box::pin(require_permission(Permission::InviteMembers)(req, next))
        }))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
        
        // 移除成员（需要RemoveMembers权限）
        .route("/families/:id/members/:user_id", delete(remove_member))
        .layer(middleware::from_fn(move |req, next| {
            Box::pin(require_permission(Permission::RemoveMembers)(req, next))
        }))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
        
        // 更新成员角色（需要Admin或Owner角色）
        .route("/families/:id/members/:user_id/role", put(update_member_role))
        .layer(middleware::from_fn(require_admin_or_owner))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
}

/// 邀请管理路由（带权限控制）
pub fn invitation_routes_with_permissions() -> Router<AppState> {
    Router::new()
        // 公开端点：验证邀请码（无需认证）
        .route("/invitations/validate/:code", get(validate_invite_code))
        
        // 创建邀请（需要InviteMembers权限）
        .route("/invitations", post(create_invitation))
        .layer(middleware::from_fn(move |req, next| {
            Box::pin(require_permission(Permission::InviteMembers)(req, next))
        }))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
        
        // 获取待处理邀请（需要ViewMembers权限）
        .route("/invitations", get(get_pending_invitations))
        .layer(middleware::from_fn(move |req, next| {
            Box::pin(require_permission(Permission::ViewMembers)(req, next))
        }))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
        
        // 接受邀请（只需认证）
        .route("/invitations/accept", post(accept_invitation))
        .layer(middleware::from_fn(require_auth))
        
        // 取消邀请（需要InviteMembers权限）
        .route("/invitations/:id", delete(cancel_invitation))
        .layer(middleware::from_fn(move |req, next| {
            Box::pin(require_permission(Permission::InviteMembers)(req, next))
        }))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
}

/// 审计日志路由（带权限控制）
pub fn audit_routes_with_permissions() -> Router<AppState> {
    Router::new()
        // 查看审计日志（需要ViewAuditLog权限或Admin角色）
        .route("/families/:id/audit-logs", get(get_audit_logs))
        .layer(middleware::from_fn(move |req, next| {
            Box::pin(require_any_permission(vec![
                Permission::ViewAuditLog,
                Permission::ManageSettings,
            ])(req, next))
        }))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
        
        // 导出审计日志（需要Admin或Owner角色）
        .route("/families/:id/audit-logs/export", get(export_audit_logs))
        .layer(middleware::from_fn(require_admin_or_owner))
        .layer(middleware::from_fn(family_context))
        .layer(middleware::from_fn(require_auth))
}

/// 组合所有路由（带完整权限控制）
pub fn create_protected_routes(app: Router<AppState>) -> Router<AppState> {
    app
        .nest("/api/v1", family_routes_with_permissions())
        .nest("/api/v1", member_routes_with_permissions())
        .nest("/api/v1", invitation_routes_with_permissions())
        .nest("/api/v1", audit_routes_with_permissions())
        .nest("/api/v1", auth_routes()) // 认证路由通常不需要额外权限
}

/// 创建一个权限检查的辅助宏
#[macro_export]
macro_rules! with_permission {
    ($router:expr, $path:expr, $method:ident($handler:expr), $permission:expr) => {
        $router.route(
            $path,
            $method($handler)
                .layer(middleware::from_fn(move |req, next| {
                    Box::pin(require_permission($permission)(req, next))
                }))
                .layer(middleware::from_fn(family_context))
                .layer(middleware::from_fn(require_auth))
        )
    };
}

/// 使用宏简化路由定义
pub fn simplified_routes() -> Router<AppState> {
    let mut router = Router::new();
    
    // 使用宏定义路由
    router = with_permission!(
        router,
        "/families/:id/settings",
        put(update_family),
        Permission::UpdateFamilyInfo
    );
    
    router
}