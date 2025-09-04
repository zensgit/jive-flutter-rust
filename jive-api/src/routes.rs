use axum::{
    routing::{delete, get, post, put},
    Router,
};

use crate::{
    handlers::{
        audit_handler::*,
        auth::*,
        family_handler::*,
        invitation_handler::*,
        member_handler::*,
    },
    middleware::auth::{require_auth, family_context},
    AppState,
};

/// Family相关路由
pub fn family_routes() -> Router<AppState> {
    Router::new()
        // Family管理
        .route("/families", post(create_family).get(list_families))
        .route("/families/:id", get(get_family).put(update_family).delete(delete_family))
        .route("/families/switch", post(switch_family))
        .route("/families/:id/invite-code", post(regenerate_invite_code))
        // 需要认证
        .layer(axum::middleware::from_fn(require_auth))
}

/// 成员管理路由
pub fn member_routes() -> Router<AppState> {
    Router::new()
        .route("/families/:id/members", get(get_family_members).post(add_member))
        .route("/families/:id/members/:user_id", delete(remove_member))
        .route("/families/:id/members/:user_id/role", put(update_member_role))
        .route("/families/:id/members/:user_id/permissions", put(update_member_permissions))
        // 需要认证和Family上下文
        .layer(axum::middleware::from_fn(family_context))
        .layer(axum::middleware::from_fn(require_auth))
}

/// 邀请管理路由
pub fn invitation_routes() -> Router<AppState> {
    Router::new()
        // 公开端点
        .route("/invitations/validate/:code", get(validate_invite_code))
        // 需要认证的端点
        .route("/invitations", post(create_invitation).get(get_pending_invitations))
        .route("/invitations/accept", post(accept_invitation))
        .route("/invitations/:id", delete(cancel_invitation))
        .layer(axum::middleware::from_fn_with_state(
            AppState::default(),
            require_auth,
        ))
}

/// 审计日志路由
pub fn audit_routes() -> Router<AppState> {
    Router::new()
        .route("/families/:id/audit-logs", get(get_audit_logs))
        .route("/families/:id/audit-logs/export", get(export_audit_logs))
        // 需要认证和Family上下文
        .layer(axum::middleware::from_fn(family_context))
        .layer(axum::middleware::from_fn(require_auth))
}

/// 增强的认证路由
pub fn auth_routes() -> Router<AppState> {
    Router::new()
        // 公开端点
        .route("/auth/register", post(register_with_family))
        .route("/auth/login", post(login))
        // 需要认证的端点
        .route("/auth/me", get(get_current_user))
        .route("/auth/context", get(get_user_context))
        .route("/auth/refresh", post(refresh_token))
}

/// 注册所有路由
pub fn register_all_routes(app: Router<AppState>) -> Router<AppState> {
    app
        .nest("/api/v1", family_routes())
        .nest("/api/v1", member_routes())
        .nest("/api/v1", invitation_routes())
        .nest("/api/v1", audit_routes())
        .nest("/api/v1", auth_routes())
}