//! Permission Middleware - 权限检查中间件
//!
//! 提供统一的权限检查机制，确保所有服务调用都经过权限验证

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;

use crate::application::ServiceContext;
use crate::domain::{AuditAction, FamilyAuditLog, FamilyRole, Permission};
use crate::error::{JiveError, Result};
#[cfg(feature = "db")]
use crate::infrastructure::repositories::FamilyRepository;

/// 权限检查中间件
#[cfg(feature = "db")]
pub struct PermissionMiddleware<R: FamilyRepository> {
    repository: Arc<R>,
    cache: Option<PermissionCache>,
}

#[cfg(feature = "db")]
impl<R: FamilyRepository> PermissionMiddleware<R> {
    pub fn new(repository: Arc<R>) -> Self {
        Self {
            repository,
            cache: Some(PermissionCache::new()),
        }
    }

    /// 检查单个权限
    pub async fn check_permission(
        &self,
        context: &ServiceContext,
        permission: Permission,
    ) -> Result<()> {
        // 1. 从上下文中检查权限（已缓存）
        if context.has_permission(permission.clone()) {
            return Ok(());
        }

        // 2. 从缓存中获取权限
        if let Some(ref cache) = self.cache {
            if let Some(permissions) = cache.get(&context.user_id, &context.family_id) {
                if permissions.contains(&permission) {
                    return Ok(());
                }
            }
        }

        // 3. 从数据库获取权限
        let permissions = self
            .repository
            .get_user_permissions(&context.user_id, &context.family_id)
            .await?;

        // 4. 更新缓存
        if let Some(ref cache) = self.cache {
            cache.set(&context.user_id, &context.family_id, permissions.clone());
        }

        // 5. 检查权限
        if permissions.contains(&permission) {
            Ok(())
        } else {
            // 记录未授权访问
            self.log_unauthorized_access(context, permission).await?;
            Err(JiveError::Unauthorized(format!(
                "Missing permission: {:?}",
                permission
            )))
        }
    }

    /// 检查多个权限（需要全部满足）
    pub async fn check_all_permissions(
        &self,
        context: &ServiceContext,
        permissions: &[Permission],
    ) -> Result<()> {
        for permission in permissions {
            self.check_permission(context, permission.clone()).await?;
        }
        Ok(())
    }

    /// 检查多个权限（满足任意一个即可）
    pub async fn check_any_permission(
        &self,
        context: &ServiceContext,
        permissions: &[Permission],
    ) -> Result<()> {
        for permission in permissions {
            if self
                .check_permission(context, permission.clone())
                .await
                .is_ok()
            {
                return Ok(());
            }
        }

        Err(JiveError::Unauthorized(format!(
            "Missing any of permissions: {:?}",
            permissions
        )))
    }

    /// 检查用户角色
    pub async fn check_role(
        &self,
        context: &ServiceContext,
        required_role: FamilyRole,
    ) -> Result<()> {
        let membership = self
            .repository
            .get_membership_by_user(&context.user_id, &context.family_id)
            .await?;

        // 角色层级检查
        let has_permission = match required_role {
            FamilyRole::Viewer => true, // 所有角色都满足 Viewer 要求
            FamilyRole::Member => matches!(
                membership.role,
                FamilyRole::Member | FamilyRole::Admin | FamilyRole::Owner
            ),
            FamilyRole::Admin => matches!(membership.role, FamilyRole::Admin | FamilyRole::Owner),
            FamilyRole::Owner => membership.role == FamilyRole::Owner,
        };

        if has_permission {
            Ok(())
        } else {
            Err(JiveError::Unauthorized(format!(
                "Requires {:?} role or higher",
                required_role
            )))
        }
    }

    /// 包装服务方法，自动进行权限检查
    pub async fn with_permission<F, T>(
        &self,
        context: &ServiceContext,
        permission: Permission,
        f: F,
    ) -> Result<T>
    where
        F: FnOnce() -> Pin<Box<dyn Future<Output = Result<T>> + Send>>,
    {
        // 检查权限
        self.check_permission(context, permission).await?;

        // 执行实际操作
        f().await
    }

    /// 包装服务方法，自动进行角色检查
    pub async fn with_role<F, T>(
        &self,
        context: &ServiceContext,
        role: FamilyRole,
        f: F,
    ) -> Result<T>
    where
        F: FnOnce() -> Pin<Box<dyn Future<Output = Result<T>> + Send>>,
    {
        // 检查角色
        self.check_role(context, role).await?;

        // 执行实际操作
        f().await
    }

    /// 记录未授权访问
    async fn log_unauthorized_access(
        &self,
        context: &ServiceContext,
        permission: Permission,
    ) -> Result<()> {
        let log = FamilyAuditLog {
            id: uuid::Uuid::new_v4().to_string(),
            family_id: context.family_id.clone(),
            user_id: context.user_id.clone(),
            action: AuditAction::PermissionDenied,
            resource_type: "permission".to_string(),
            resource_id: Some(format!("{:?}", permission)),
            changes: None,
            ip_address: context.ip_address.clone(),
            user_agent: context.user_agent.clone(),
            created_at: Utc::now(),
        };

        self.repository.create_audit_log(&log).await?;
        Ok(())
    }

    /// 清除用户的权限缓存
    pub fn invalidate_cache(&self, user_id: &str, family_id: &str) {
        if let Some(ref cache) = self.cache {
            cache.invalidate(user_id, family_id);
        }
    }

    /// 清除整个 Family 的权限缓存
    pub fn invalidate_family_cache(&self, family_id: &str) {
        if let Some(ref cache) = self.cache {
            cache.invalidate_family(family_id);
        }
    }
}

/// 权限缓存
pub struct PermissionCache {
    cache: Arc<parking_lot::RwLock<lru::LruCache<(String, String), Vec<Permission>>>>,
    ttl: std::time::Duration,
}

impl PermissionCache {
    pub fn new() -> Self {
        Self {
            cache: Arc::new(parking_lot::RwLock::new(lru::LruCache::new(
                std::num::NonZeroUsize::new(1000).unwrap(),
            ))),
            ttl: std::time::Duration::from_secs(300), // 5分钟缓存
        }
    }

    pub fn get(&self, user_id: &str, family_id: &str) -> Option<Vec<Permission>> {
        let cache = self.cache.read();
        cache
            .peek(&(user_id.to_string(), family_id.to_string()))
            .cloned()
    }

    pub fn set(&self, user_id: &str, family_id: &str, permissions: Vec<Permission>) {
        let mut cache = self.cache.write();
        cache.put((user_id.to_string(), family_id.to_string()), permissions);
    }

    pub fn invalidate(&self, user_id: &str, family_id: &str) {
        let mut cache = self.cache.write();
        cache.pop(&(user_id.to_string(), family_id.to_string()));
    }

    pub fn invalidate_family(&self, family_id: &str) {
        let mut cache = self.cache.write();
        let keys_to_remove: Vec<_> = cache
            .iter()
            .filter(|((_, fid), _)| fid == family_id)
            .map(|((uid, fid), _)| (uid.clone(), fid.clone()))
            .collect();

        for key in keys_to_remove {
            cache.pop(&key);
        }
    }
}

/// 权限守卫 - 用于方法级别的权限注解
#[async_trait]
pub trait PermissionGuard {
    async fn require_permission(
        &self,
        context: &ServiceContext,
        permission: Permission,
    ) -> Result<()>;
    async fn require_role(&self, context: &ServiceContext, role: FamilyRole) -> Result<()>;
    async fn require_any_permission(
        &self,
        context: &ServiceContext,
        permissions: &[Permission],
    ) -> Result<()>;
    async fn require_all_permissions(
        &self,
        context: &ServiceContext,
        permissions: &[Permission],
    ) -> Result<()>;
}

/// 宏：简化权限检查
#[macro_export]
macro_rules! require_permission {
    ($context:expr, $permission:expr) => {
        $context.require_permission($permission)?
    };
    ($context:expr, $permission:expr, $message:expr) => {
        $context
            .require_permission($permission)
            .map_err(|_| JiveError::Unauthorized($message.into()))?
    };
}

#[macro_export]
macro_rules! require_role {
    ($middleware:expr, $context:expr, $role:expr) => {
        $middleware.check_role($context, $role).await?
    };
}

/// 权限装饰器（用于服务方法）
pub struct PermissionDecorator<S> {
    inner: S,
    middleware: Arc<dyn PermissionGuard + Send + Sync>,
}

impl<S> PermissionDecorator<S> {
    pub fn new(inner: S, middleware: Arc<dyn PermissionGuard + Send + Sync>) -> Self {
        Self { inner, middleware }
    }

    /// 装饰需要权限的方法
    pub async fn with_permission<F, R>(
        &self,
        context: &ServiceContext,
        permission: Permission,
        f: F,
    ) -> Result<R>
    where
        F: FnOnce(&S) -> Pin<Box<dyn Future<Output = Result<R>> + Send + '_>>,
    {
        // 检查权限
        self.middleware
            .require_permission(context, permission)
            .await?;

        // 执行原方法
        f(&self.inner).await
    }

    /// 装饰需要角色的方法
    pub async fn with_role<F, R>(
        &self,
        context: &ServiceContext,
        role: FamilyRole,
        f: F,
    ) -> Result<R>
    where
        F: FnOnce(&S) -> Pin<Box<dyn Future<Output = Result<R>> + Send + '_>>,
    {
        // 检查角色
        self.middleware.require_role(context, role).await?;

        // 执行原方法
        f(&self.inner).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_permission_cache() {
        let cache = PermissionCache::new();
        let permissions = vec![Permission::ViewTransactions, Permission::CreateTransactions];

        // 设置缓存
        cache.set("user1", "family1", permissions.clone());

        // 获取缓存
        let cached = cache.get("user1", "family1");
        assert!(cached.is_some());
        assert_eq!(cached.unwrap(), permissions);

        // 清除缓存
        cache.invalidate("user1", "family1");
        assert!(cache.get("user1", "family1").is_none());
    }

    #[test]
    fn test_invalidate_family_cache() {
        let cache = PermissionCache::new();

        // 设置多个用户的缓存
        cache.set("user1", "family1", vec![Permission::ViewTransactions]);
        cache.set("user2", "family1", vec![Permission::CreateTransactions]);
        cache.set("user3", "family2", vec![Permission::EditTransactions]);

        // 清除 family1 的所有缓存
        cache.invalidate_family("family1");

        assert!(cache.get("user1", "family1").is_none());
        assert!(cache.get("user2", "family1").is_none());
        assert!(cache.get("user3", "family2").is_some()); // family2 不受影响
    }
}
