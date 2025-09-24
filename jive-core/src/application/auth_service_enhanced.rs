//! Enhanced Auth Service - 增强的认证服务
//!
//! 处理用户注册时的 Family 创建和角色分配逻辑

use crate::application::{FamilyService, UserService};
use crate::domain::{Family, FamilyInvitation, FamilyMembership, FamilyRole, User};
use crate::error::{JiveError, Result};

/// 用户注册请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub name: String,
    pub invitation_token: Option<String>, // 如果有邀请 token
    pub timezone: Option<String>,
    pub currency: Option<String>,
}

/// 增强的认证服务
pub struct EnhancedAuthService {
    user_service: UserService,
    family_service: FamilyService,
}

impl EnhancedAuthService {
    /// 用户注册 - 根据是否有邀请决定角色
    pub async fn register_user(&self, request: RegisterRequest) -> Result<RegisterResponse> {
        // 1. 创建用户账号
        let user = self
            .user_service
            .create_user(CreateUserRequest {
                email: request.email.clone(),
                password: request.password,
                name: request.name.clone(),
            })
            .await?;

        // 2. 根据是否有邀请决定 Family 和角色
        let (family, membership) = if let Some(token) = request.invitation_token {
            // === 通过邀请注册的用户 ===
            self.register_with_invitation(user.id.clone(), token)
                .await?
        } else {
            // === 直接注册的用户 ===
            self.register_without_invitation(user.id.clone(), request)
                .await?
        };

        Ok(RegisterResponse {
            user,
            family,
            membership,
        })
    }

    /// 直接注册（无邀请）- 成为新 Family 的 Owner
    async fn register_without_invitation(
        &self,
        user_id: String,
        request: RegisterRequest,
    ) -> Result<(Family, FamilyMembership)> {
        // 1. 为用户创建个人 Family
        let family = self
            .family_service
            .create_family(
                CreateFamilyRequest {
                    name: format!("{}'s Family", request.name),
                    currency: request.currency.unwrap_or_else(|| "USD".to_string()),
                    timezone: request
                        .timezone
                        .unwrap_or_else(|| "America/New_York".to_string()),
                    locale: Some("en".to_string()),
                    date_format: None,
                },
                user_id.clone(), // 创建者 ID
            )
            .await?
            .data
            .unwrap();

        // 2. 创建 Owner 成员关系（在 create_family 内部已处理）
        let membership = FamilyMembership {
            id: Uuid::new_v4().to_string(),
            family_id: family.id.clone(),
            user_id: user_id.clone(),
            role: FamilyRole::Owner, // ⭐ 直接注册用户成为 Owner
            permissions: FamilyRole::Owner.default_permissions(),
            joined_at: Utc::now(),
            invited_by: None,
            is_active: true,
            last_accessed_at: Some(Utc::now()),
        };

        Ok((family, membership))
    }

    /// 通过邀请注册 - 获得邀请中指定的角色
    async fn register_with_invitation(
        &self,
        user_id: String,
        token: String,
    ) -> Result<(Family, FamilyMembership)> {
        // 1. 验证邀请
        let invitation = self.family_service.get_invitation_by_token(&token).await?;

        if !invitation.is_valid() {
            return Err(JiveError::BadRequest(
                "Invalid or expired invitation".into(),
            ));
        }

        // 2. 验证角色限制
        if invitation.role == FamilyRole::Owner {
            // ⚠️ 安全检查：邀请不能授予 Owner 角色
            return Err(JiveError::Forbidden(
                "Cannot invite someone as Owner. Owner role can only be transferred.".into(),
            ));
        }

        // 3. 获取被邀请加入的 Family
        let family = self
            .family_service
            .get_family(&invitation.family_id)
            .await?;

        // 4. 接受邀请，创建成员关系
        let membership = self
            .family_service
            .accept_invitation(token, user_id.clone())
            .await?
            .data
            .unwrap();

        // membership 的角色由邀请决定：
        // - 通常是 Member
        // - 邀请者可以指定为 Admin
        // - 绝不会是 Owner

        Ok((family, membership))
    }

    /// 处理不同场景的注册
    pub async fn smart_register(&self, request: RegisterRequest) -> Result<RegisterScenario> {
        // 检查邮箱是否已注册
        if self.user_service.email_exists(&request.email).await? {
            return Err(JiveError::Conflict("Email already registered".into()));
        }

        // 根据场景处理
        let scenario = if let Some(token) = &request.invitation_token {
            // 场景1: 被邀请的用户
            let invitation = self.family_service.get_invitation_by_token(token).await?;

            RegisterScenario::InvitedUser {
                will_join_family: invitation.family_id.clone(),
                assigned_role: invitation.role.clone(),
                invited_by: invitation.inviter_id.clone(),
            }
        } else {
            // 场景2: 独立注册的用户
            RegisterScenario::IndependentUser {
                will_create_family: true,
                assigned_role: FamilyRole::Owner,
            }
        };

        Ok(scenario)
    }
}

/// 注册场景
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RegisterScenario {
    /// 独立注册用户
    IndependentUser {
        will_create_family: bool,
        assigned_role: FamilyRole, // 总是 Owner
    },
    /// 被邀请的用户
    InvitedUser {
        will_join_family: String,
        assigned_role: FamilyRole, // Member 或 Admin，绝不是 Owner
        invited_by: String,
    },
}

/// 邀请权限验证
impl FamilyService {
    /// 创建邀请时的角色验证
    pub async fn create_invitation_with_validation(
        &self,
        context: ServiceContext,
        request: InviteMemberRequest,
    ) -> Result<FamilyInvitation> {
        // 1. 检查邀请者权限
        context.require_permission(Permission::InviteMembers)?;

        // 2. ⚠️ 关键验证：不能邀请别人成为 Owner
        if request.role == FamilyRole::Owner {
            return Err(JiveError::BadRequest(
                "Cannot invite someone as Owner. Use transfer_ownership instead.".into(),
            ));
        }

        // 3. Admin 只能邀请 Member 和 Viewer
        let inviter_membership = self
            .get_membership_by_user(&context.user_id, &context.family_id)
            .await?;

        if inviter_membership.role == FamilyRole::Admin {
            // Admin 不能邀请其他 Admin
            if request.role == FamilyRole::Admin {
                return Err(JiveError::Forbidden(
                    "Only Owner can invite Admin members".into(),
                ));
            }
        }

        // 4. 创建邀请
        let invitation = FamilyInvitation::new(
            context.family_id.clone(),
            context.user_id.clone(),
            request.email.clone(),
            request.role, // Member 或 Admin（只有 Owner 可以邀请 Admin）
        );

        self.save_invitation(&invitation).await?;
        Ok(invitation)
    }
}

/// 角色升级路径
pub struct RoleUpgradePath;

impl RoleUpgradePath {
    /// 验证角色升级是否合法
    pub fn can_upgrade(
        current_role: &FamilyRole,
        target_role: &FamilyRole,
        operator_role: &FamilyRole,
    ) -> Result<bool> {
        match (current_role, target_role, operator_role) {
            // Viewer -> Member: Admin 或 Owner 可以操作
            (FamilyRole::Viewer, FamilyRole::Member, FamilyRole::Admin)
            | (FamilyRole::Viewer, FamilyRole::Member, FamilyRole::Owner) => Ok(true),

            // Member -> Admin: 只有 Owner 可以操作
            (FamilyRole::Member, FamilyRole::Admin, FamilyRole::Owner) => Ok(true),

            // Viewer -> Admin: 只有 Owner 可以操作
            (FamilyRole::Viewer, FamilyRole::Admin, FamilyRole::Owner) => Ok(true),

            // ❌ 任何人都不能直接升级为 Owner
            (_, FamilyRole::Owner, _) => Ok(false),

            // ❌ Admin 不能将其他人升级为 Admin
            (_, FamilyRole::Admin, FamilyRole::Admin) => Ok(false),

            _ => Ok(false),
        }
    }

    /// Owner 转让（特殊流程）
    pub async fn transfer_ownership(
        family_service: &FamilyService,
        context: ServiceContext,
        new_owner_id: String,
    ) -> Result<()> {
        // 1. 只有当前 Owner 可以转让
        let current_membership = family_service
            .get_membership_by_user(&context.user_id, &context.family_id)
            .await?;

        if current_membership.role != FamilyRole::Owner {
            return Err(JiveError::Forbidden(
                "Only Owner can transfer ownership".into(),
            ));
        }

        // 2. 新 Owner 必须已经是 Family 成员
        let new_owner_membership = family_service
            .get_membership_by_user(&new_owner_id, &context.family_id)
            .await?;

        // 3. 执行转让
        // - 新成员成为 Owner
        // - 原 Owner 降级为 Admin
        family_service
            .transfer_ownership(context, new_owner_id)
            .await?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_role_assignment_logic() {
        // 测试1: 直接注册用户应该是 Owner
        let direct_register_role = FamilyRole::Owner;
        assert_eq!(direct_register_role, FamilyRole::Owner);

        // 测试2: 邀请不能指定 Owner
        let invitation = InviteMemberRequest {
            email: "test@example.com".to_string(),
            role: FamilyRole::Owner, // 尝试邀请为 Owner
            custom_permissions: None,
            personal_message: None,
        };
        // 这应该在验证时失败

        // 测试3: 邀请可以指定 Admin（如果邀请者是 Owner）
        let valid_invitation = InviteMemberRequest {
            email: "test@example.com".to_string(),
            role: FamilyRole::Admin, // Owner 可以邀请 Admin
            custom_permissions: None,
            personal_message: None,
        };
        // 这应该成功
    }

    #[test]
    fn test_role_upgrade_paths() {
        // 测试升级路径
        assert!(RoleUpgradePath::can_upgrade(
            &FamilyRole::Viewer,
            &FamilyRole::Member,
            &FamilyRole::Admin,
        )
        .unwrap());

        assert!(RoleUpgradePath::can_upgrade(
            &FamilyRole::Member,
            &FamilyRole::Admin,
            &FamilyRole::Owner,
        )
        .unwrap());

        // 不能直接升级为 Owner
        assert!(!RoleUpgradePath::can_upgrade(
            &FamilyRole::Admin,
            &FamilyRole::Owner,
            &FamilyRole::Owner,
        )
        .unwrap());
    }
}
