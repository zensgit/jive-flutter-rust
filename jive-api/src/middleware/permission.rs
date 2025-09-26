use axum::{extract::Request, http::StatusCode, middleware::Next, response::Response};
use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::RwLock;
use uuid::Uuid;

use crate::{
    models::permission::{MemberRole, Permission},
    services::ServiceContext,
};

/// 权限中间件 - 检查单个权限
pub async fn require_permission(
    required: Permission,
) -> impl Fn(
    Request,
    Next,
) -> std::pin::Pin<
    Box<dyn std::future::Future<Output = Result<Response, StatusCode>> + Send>,
> + Clone {
    move |request: Request, next: Next| {
        Box::pin(async move {
            // 从request extensions获取ServiceContext
            let context = request
                .extensions()
                .get::<ServiceContext>()
                .ok_or(StatusCode::UNAUTHORIZED)?;

            // 检查权限
            if !context.can_perform(required) {
                return Err(StatusCode::FORBIDDEN);
            }

            Ok(next.run(request).await)
        })
    }
}

/// 多权限中间件 - 检查多个权限（任一满足）
pub async fn require_any_permission(
    permissions: Vec<Permission>,
) -> impl Fn(
    Request,
    Next,
) -> std::pin::Pin<
    Box<dyn std::future::Future<Output = Result<Response, StatusCode>> + Send>,
> + Clone {
    move |request: Request, next: Next| {
        let value = permissions.clone();
        Box::pin(async move {
            let context = request
                .extensions()
                .get::<ServiceContext>()
                .ok_or(StatusCode::UNAUTHORIZED)?;

            // 检查是否有任一权限
            let has_permission = value.iter().any(|p| context.can_perform(*p));

            if !has_permission {
                return Err(StatusCode::FORBIDDEN);
            }

            Ok(next.run(request).await)
        })
    }
}

/// 多权限中间件 - 检查多个权限（全部满足）
pub async fn require_all_permissions(
    permissions: Vec<Permission>,
) -> impl Fn(
    Request,
    Next,
) -> std::pin::Pin<
    Box<dyn std::future::Future<Output = Result<Response, StatusCode>> + Send>,
> + Clone {
    move |request: Request, next: Next| {
        let value = permissions.clone();
        Box::pin(async move {
            let context = request
                .extensions()
                .get::<ServiceContext>()
                .ok_or(StatusCode::UNAUTHORIZED)?;

            // 检查是否有所有权限
            let has_all_permissions = value.iter().all(|p| context.can_perform(*p));

            if !has_all_permissions {
                return Err(StatusCode::FORBIDDEN);
            }

            Ok(next.run(request).await)
        })
    }
}

/// 角色中间件 - 检查最低角色要求
pub async fn require_minimum_role(
    minimum_role: MemberRole,
) -> impl Fn(
    Request,
    Next,
) -> std::pin::Pin<
    Box<dyn std::future::Future<Output = Result<Response, StatusCode>> + Send>,
> + Clone {
    move |request: Request, next: Next| {
        Box::pin(async move {
            let context = request
                .extensions()
                .get::<ServiceContext>()
                .ok_or(StatusCode::UNAUTHORIZED)?;

            // 检查角色级别
            let role_level = match context.role {
                MemberRole::Owner => 4,
                MemberRole::Admin => 3,
                MemberRole::Member => 2,
                MemberRole::Viewer => 1,
            };

            let required_level = match minimum_role {
                MemberRole::Owner => 4,
                MemberRole::Admin => 3,
                MemberRole::Member => 2,
                MemberRole::Viewer => 1,
            };

            if role_level < required_level {
                return Err(StatusCode::FORBIDDEN);
            }

            Ok(next.run(request).await)
        })
    }
}

/// Owner专用中间件
pub async fn require_owner(request: Request, next: Next) -> Result<Response, StatusCode> {
    let context = request
        .extensions()
        .get::<ServiceContext>()
        .ok_or(StatusCode::UNAUTHORIZED)?;

    if context.role != MemberRole::Owner {
        return Err(StatusCode::FORBIDDEN);
    }

    Ok(next.run(request).await)
}

/// Admin及以上中间件
pub async fn require_admin_or_owner(request: Request, next: Next) -> Result<Response, StatusCode> {
    let context = request
        .extensions()
        .get::<ServiceContext>()
        .ok_or(StatusCode::UNAUTHORIZED)?;

    if !matches!(context.role, MemberRole::Owner | MemberRole::Admin) {
        return Err(StatusCode::FORBIDDEN);
    }

    Ok(next.run(request).await)
}

/// 权限缓存
type PermissionKey = (Uuid, Uuid);
type PermissionValue = (Vec<Permission>, Instant);

pub struct PermissionCache {
    cache: Arc<RwLock<HashMap<PermissionKey, PermissionValue>>>,
    ttl: Duration,
}

impl PermissionCache {
    pub fn new(ttl_seconds: u64) -> Self {
        Self {
            cache: Arc::new(RwLock::new(HashMap::new())),
            ttl: Duration::from_secs(ttl_seconds),
        }
    }

    pub async fn get(&self, user_id: Uuid, family_id: Uuid) -> Option<Vec<Permission>> {
        let cache = self.cache.read().await;

        if let Some((permissions, cached_at)) = cache.get(&(user_id, family_id)) {
            if cached_at.elapsed() < self.ttl {
                return Some(permissions.clone());
            }
        }

        None
    }

    pub async fn set(&self, user_id: Uuid, family_id: Uuid, permissions: Vec<Permission>) {
        let mut cache = self.cache.write().await;
        cache.insert((user_id, family_id), (permissions, Instant::now()));
    }

    pub async fn invalidate(&self, user_id: Uuid, family_id: Uuid) {
        let mut cache = self.cache.write().await;
        cache.remove(&(user_id, family_id));
    }

    pub async fn clear(&self) {
        let mut cache = self.cache.write().await;
        cache.clear();
    }
}

/// 权限错误响应
#[derive(serde::Serialize)]
pub struct PermissionError {
    pub code: String,
    pub message: String,
    pub required_permission: Option<String>,
    pub required_role: Option<String>,
}

impl PermissionError {
    pub fn insufficient_permissions(permission: Permission) -> Self {
        Self {
            code: "INSUFFICIENT_PERMISSIONS".to_string(),
            message: format!(
                "You need '{}' permission to perform this action",
                permission
            ),
            required_permission: Some(permission.to_string()),
            required_role: None,
        }
    }

    pub fn insufficient_role(role: MemberRole) -> Self {
        Self {
            code: "INSUFFICIENT_ROLE".to_string(),
            message: format!("You need at least '{}' role to perform this action", role),
            required_permission: None,
            required_role: Some(role.to_string()),
        }
    }
}

/// 条件权限检查
pub enum ResourceOwnership {
    OwnedBy(Uuid),
    SharedInFamily(Uuid),
    Public,
}

pub async fn check_resource_permission(
    context: &ServiceContext,
    resource: ResourceOwnership,
    permission: Permission,
) -> bool {
    match resource {
        ResourceOwnership::OwnedBy(owner_id) => {
            // 资源所有者或有权限的人可以访问
            context.user_id == owner_id || context.can_perform(permission)
        }
        ResourceOwnership::SharedInFamily(family_id) => {
            // 必须是Family成员且有权限
            context.family_id == family_id && context.can_perform(permission)
        }
        ResourceOwnership::Public => {
            // 公开资源，只要认证即可
            true
        }
    }
}

/// 权限组定义
pub enum PermissionGroup {
    AccountManagement,
    TransactionManagement,
    FamilyAdministration,
    DataViewing,
}

impl PermissionGroup {
    pub fn permissions(&self) -> Vec<Permission> {
        match self {
            PermissionGroup::AccountManagement => vec![
                Permission::ViewAccounts,
                Permission::CreateAccounts,
                Permission::EditAccounts,
                Permission::DeleteAccounts,
            ],
            PermissionGroup::TransactionManagement => vec![
                Permission::ViewTransactions,
                Permission::CreateTransactions,
                Permission::EditTransactions,
                Permission::DeleteTransactions,
                Permission::BulkEditTransactions,
            ],
            PermissionGroup::FamilyAdministration => vec![
                Permission::ViewFamilyInfo,
                Permission::UpdateFamilyInfo,
                Permission::DeleteFamily,
                Permission::ViewMembers,
                Permission::InviteMembers,
                Permission::RemoveMembers,
                Permission::UpdateMemberRoles,
            ],
            PermissionGroup::DataViewing => vec![
                Permission::ViewFamilyInfo,
                Permission::ViewMembers,
                Permission::ViewAccounts,
                Permission::ViewTransactions,
                Permission::ViewCategories,
                Permission::ViewBudgets,
                Permission::ViewReports,
            ],
        }
    }

    pub fn check_any(&self, context: &ServiceContext) -> bool {
        self.permissions().iter().any(|p| context.can_perform(*p))
    }

    pub fn check_all(&self, context: &ServiceContext) -> bool {
        self.permissions().iter().all(|p| context.can_perform(*p))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_permission_group() {
        let context = ServiceContext::new(
            Uuid::new_v4(),
            Uuid::new_v4(),
            MemberRole::Member,
            vec![Permission::ViewAccounts, Permission::CreateAccounts],
            "test@example.com".to_string(),
            None,
        );

        let group = PermissionGroup::AccountManagement;
        assert!(group.check_any(&context)); // Has some account permissions
        assert!(!group.check_all(&context)); // Doesn't have all
    }

    #[tokio::test]
    async fn test_permission_cache() {
        let cache = PermissionCache::new(5);
        let user_id = Uuid::new_v4();
        let family_id = Uuid::new_v4();
        let permissions = vec![Permission::ViewAccounts];

        // Set cache
        cache.set(user_id, family_id, permissions.clone()).await;

        // Get from cache
        let cached = cache.get(user_id, family_id).await;
        assert_eq!(cached, Some(permissions));

        // Invalidate
        cache.invalidate(user_id, family_id).await;
        let cached = cache.get(user_id, family_id).await;
        assert_eq!(cached, None);
    }
}
