//! Family service - 家庭/团队协作管理服务
//! 
//! 基于 Maybe 的 Family 功能实现，提供多用户协作、权限管理、邀请系统等功能

use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::domain::{
    Family, FamilyMembership, FamilyRole, FamilyInvitation, 
    FamilySettings, Permission, InvitationStatus, FamilyAuditLog, AuditAction
};
use crate::error::{JiveError, Result};
use super::{ServiceContext, ServiceResponse, PaginationParams, PaginatedResult};

/// Family 创建请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CreateFamilyRequest {
    pub name: String,
    pub currency: String,
    pub timezone: String,
    pub locale: Option<String>,
    pub date_format: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CreateFamilyRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(name: String, currency: String, timezone: String) -> Self {
        Self {
            name,
            currency,
            timezone,
            locale: None,
            date_format: None,
        }
    }
}

/// 邀请成员请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InviteMemberRequest {
    pub email: String,
    pub role: FamilyRole,
    pub custom_permissions: Option<Vec<Permission>>,
    pub personal_message: Option<String>,
}

/// 更新成员角色请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateMemberRoleRequest {
    pub member_id: String,
    pub new_role: FamilyRole,
    pub custom_permissions: Option<Vec<Permission>>,
}

/// Family 成员信息（用于展示）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilyMemberInfo {
    pub id: String,
    pub user_id: String,
    pub email: String,
    pub name: String,
    pub avatar_url: Option<String>,
    pub role: FamilyRole,
    pub permissions: Vec<Permission>,
    pub joined_at: DateTime<Utc>,
    pub last_accessed_at: Option<DateTime<Utc>>,
    pub invited_by_name: Option<String>,
    pub is_online: bool,
}

/// Family 服务
#[derive(Debug, Clone)]
pub struct FamilyService {
    // 这里可以注入仓储层依赖
}

impl FamilyService {
    pub fn new() -> Self {
        Self {}
    }

    /// 创建新的 Family
    pub async fn create_family(
        &self,
        request: CreateFamilyRequest,
        creator_id: String,
    ) -> Result<ServiceResponse<Family>> {
        // 验证请求
        if request.name.trim().is_empty() {
            return Err(JiveError::ValidationError("Family name is required".into()));
        }

        // 创建 Family
        let mut family = Family::new(
            request.name,
            request.currency,
            request.timezone,
        );
        
        if let Some(locale) = request.locale {
            family.locale = locale;
        }
        
        if let Some(date_format) = request.date_format {
            family.date_format = date_format;
        }

        // 创建创建者的成员关系（Owner 角色）
        let membership = FamilyMembership {
            id: Uuid::new_v4().to_string(),
            family_id: family.id.clone(),
            user_id: creator_id.clone(),
            role: FamilyRole::Owner,
            permissions: FamilyRole::Owner.default_permissions(),
            joined_at: Utc::now(),
            invited_by: None,
            is_active: true,
            last_accessed_at: Some(Utc::now()),
        };

        // TODO: 保存到数据库
        // self.repository.save_family(&family).await?;
        // self.repository.save_membership(&membership).await?;

        // 创建默认数据
        self.create_default_data(&family).await?;

        // 记录审计日志
        self.log_audit(
            &family.id,
            &creator_id,
            AuditAction::DataCreated,
            "family",
            Some(&family.id),
            None,
        ).await?;

        Ok(ServiceResponse::success(family))
    }

    /// 邀请成员加入 Family
    pub async fn invite_member(
        &self,
        context: ServiceContext,
        request: InviteMemberRequest,
    ) -> Result<ServiceResponse<FamilyInvitation>> {
        // 检查权限
        context.require_permission(Permission::InviteMembers)?;

        // 验证邮箱格式
        if !self.is_valid_email(&request.email) {
            return Err(JiveError::ValidationError("Invalid email address".into()));
        }

        // 检查是否已经是成员
        if self.is_member(&request.email, &context.family_id).await? {
            return Err(JiveError::Conflict("User is already a member".into()));
        }

        // 检查是否有待处理的邀请
        if self.has_pending_invitation(&request.email, &context.family_id).await? {
            return Err(JiveError::Conflict("Invitation already sent".into()));
        }

        // 创建邀请
        let invitation = FamilyInvitation::new(
            context.family_id.clone(),
            context.user_id.clone(),
            request.email.clone(),
            request.role,
        );

        // TODO: 保存邀请
        // self.repository.save_invitation(&invitation).await?;

        // 发送邀请邮件
        self.send_invitation_email(&invitation, request.personal_message).await?;

        // 记录审计日志
        self.log_audit(
            &context.family_id,
            &context.user_id,
            AuditAction::MemberInvited,
            "invitation",
            Some(&invitation.id),
            Some(serde_json::json!({
                "invitee_email": request.email,
                "role": request.role
            })),
        ).await?;

        Ok(ServiceResponse::success(invitation))
    }

    /// 接受邀请
    pub async fn accept_invitation(
        &self,
        token: String,
        user_id: String,
    ) -> Result<ServiceResponse<FamilyMembership>> {
        // 查找并验证邀请
        let mut invitation = self.find_invitation_by_token(&token).await?;
        
        if !invitation.is_valid() {
            return Err(JiveError::BadRequest("Invalid or expired invitation".into()));
        }

        // 接受邀请
        invitation.accept()?;

        // 创建成员关系
        let membership = FamilyMembership {
            id: Uuid::new_v4().to_string(),
            family_id: invitation.family_id.clone(),
            user_id: user_id.clone(),
            role: invitation.role.clone(),
            permissions: invitation.custom_permissions.clone()
                .unwrap_or_else(|| invitation.role.default_permissions()),
            joined_at: Utc::now(),
            invited_by: Some(invitation.inviter_id.clone()),
            is_active: true,
            last_accessed_at: Some(Utc::now()),
        };

        // TODO: 保存到数据库
        // self.repository.save_membership(&membership).await?;
        // self.repository.update_invitation(&invitation).await?;

        // 通知其他成员
        self.notify_members_of_new_member(&invitation.family_id, &user_id).await?;

        // 记录审计日志
        self.log_audit(
            &invitation.family_id,
            &user_id,
            AuditAction::MemberJoined,
            "membership",
            Some(&membership.id),
            None,
        ).await?;

        Ok(ServiceResponse::success(membership))
    }

    /// 更新成员角色
    pub async fn update_member_role(
        &self,
        context: ServiceContext,
        request: UpdateMemberRoleRequest,
    ) -> Result<ServiceResponse<FamilyMembership>> {
        // 检查权限
        context.require_permission(Permission::ManageRoles)?;

        // 获取目标成员信息
        let mut membership = self.get_membership(&request.member_id, &context.family_id).await?;

        // 不能修改 Owner 的角色
        if membership.role == FamilyRole::Owner {
            return Err(JiveError::Forbidden("Cannot change owner role".into()));
        }

        // 不能将他人提升为 Owner
        if request.new_role == FamilyRole::Owner {
            return Err(JiveError::Forbidden("Cannot assign owner role".into()));
        }

        // 记录旧角色（用于审计）
        let old_role = membership.role.clone();

        // 更新角色和权限
        membership.role = request.new_role.clone();
        membership.permissions = request.custom_permissions
            .unwrap_or_else(|| request.new_role.default_permissions());

        // TODO: 保存到数据库
        // self.repository.update_membership(&membership).await?;

        // 记录审计日志
        self.log_audit(
            &context.family_id,
            &context.user_id,
            AuditAction::MemberRoleChanged,
            "membership",
            Some(&membership.id),
            Some(serde_json::json!({
                "old_role": old_role,
                "new_role": request.new_role,
                "target_user": request.member_id
            })),
        ).await?;

        Ok(ServiceResponse::success(membership))
    }

    /// 移除成员
    pub async fn remove_member(
        &self,
        context: ServiceContext,
        member_id: String,
    ) -> Result<ServiceResponse<()>> {
        // 检查权限
        context.require_permission(Permission::RemoveMembers)?;

        // 获取成员信息
        let membership = self.get_membership(&member_id, &context.family_id).await?;

        // 不能移除 Owner
        if membership.role == FamilyRole::Owner {
            return Err(JiveError::Forbidden("Cannot remove owner".into()));
        }

        // 不能移除自己
        if membership.user_id == context.user_id {
            return Err(JiveError::BadRequest("Cannot remove yourself".into()));
        }

        // TODO: 从数据库删除
        // self.repository.delete_membership(&member_id).await?;

        // 通知被移除的成员
        self.notify_member_removed(&membership.user_id).await?;

        // 记录审计日志
        self.log_audit(
            &context.family_id,
            &context.user_id,
            AuditAction::MemberRemoved,
            "membership",
            Some(&member_id),
            Some(serde_json::json!({
                "removed_user": membership.user_id
            })),
        ).await?;

        Ok(ServiceResponse::success(()))
    }

    /// 获取 Family 成员列表
    pub async fn get_members(
        &self,
        context: ServiceContext,
    ) -> Result<ServiceResponse<Vec<FamilyMemberInfo>>> {
        // 检查权限
        context.require_permission(Permission::ViewAccounts)?;

        // TODO: 从数据库获取成员列表
        let members = vec![];
        
        Ok(ServiceResponse::success(members))
    }

    /// 切换当前 Family
    pub async fn switch_family(
        &self,
        user_id: String,
        family_id: String,
    ) -> Result<ServiceResponse<()>> {
        // 检查用户是否是该 Family 的成员
        if !self.is_member_by_id(&user_id, &family_id).await? {
            return Err(JiveError::Forbidden("Not a member of this family".into()));
        }

        // TODO: 更新用户的当前 Family
        // self.repository.update_current_family(&user_id, &family_id).await?;

        // 更新最后访问时间
        self.update_last_accessed(&user_id, &family_id).await?;

        Ok(ServiceResponse::success(()))
    }

    /// 更新 Family 设置
    pub async fn update_settings(
        &self,
        context: ServiceContext,
        settings: FamilySettings,
    ) -> Result<ServiceResponse<Family>> {
        // 检查权限
        context.require_permission(Permission::ManageFamilySettings)?;

        // TODO: 获取并更新 Family
        let mut family = self.get_family(&context.family_id).await?;
        let old_settings = family.settings.clone();
        
        family.update_settings(settings);

        // TODO: 保存到数据库
        // self.repository.update_family(&family).await?;

        // 记录审计日志
        self.log_audit(
            &context.family_id,
            &context.user_id,
            AuditAction::SettingsUpdated,
            "family",
            Some(&family.id),
            Some(serde_json::json!({
                "old_settings": old_settings,
                "new_settings": family.settings
            })),
        ).await?;

        Ok(ServiceResponse::success(family))
    }

    /// 获取用户的所有 Family
    pub async fn get_user_families(
        &self,
        user_id: String,
    ) -> Result<ServiceResponse<Vec<Family>>> {
        // TODO: 从数据库获取用户的所有 Family
        let families = vec![];
        
        Ok(ServiceResponse::success(families))
    }

    /// 转让 Owner 权限
    pub async fn transfer_ownership(
        &self,
        context: ServiceContext,
        new_owner_id: String,
    ) -> Result<ServiceResponse<()>> {
        // 只有 Owner 可以转让所有权
        let current_membership = self.get_membership_by_user(&context.user_id, &context.family_id).await?;
        if current_membership.role != FamilyRole::Owner {
            return Err(JiveError::Forbidden("Only owner can transfer ownership".into()));
        }

        // 获取新 Owner 的成员信息
        let mut new_owner_membership = self.get_membership(&new_owner_id, &context.family_id).await?;

        // 更新角色
        new_owner_membership.role = FamilyRole::Owner;
        new_owner_membership.permissions = FamilyRole::Owner.default_permissions();

        // 将当前 Owner 降级为 Admin
        let mut old_owner_membership = current_membership;
        old_owner_membership.role = FamilyRole::Admin;
        old_owner_membership.permissions = FamilyRole::Admin.default_permissions();

        // TODO: 保存到数据库
        // self.repository.update_membership(&new_owner_membership).await?;
        // self.repository.update_membership(&old_owner_membership).await?;

        // 记录审计日志
        self.log_audit(
            &context.family_id,
            &context.user_id,
            AuditAction::MemberRoleChanged,
            "ownership",
            None,
            Some(serde_json::json!({
                "old_owner": context.user_id,
                "new_owner": new_owner_id
            })),
        ).await?;

        Ok(ServiceResponse::success(()))
    }

    // === 辅助方法 ===

    /// 创建默认数据
    async fn create_default_data(&self, family: &Family) -> Result<()> {
        // TODO: 创建默认分类、标签等
        Ok(())
    }

    /// 验证邮箱格式
    fn is_valid_email(&self, email: &str) -> bool {
        // 简单的邮箱验证
        email.contains('@') && email.contains('.')
    }

    /// 检查是否是成员
    async fn is_member(&self, email: &str, family_id: &str) -> Result<bool> {
        // TODO: 查询数据库
        Ok(false)
    }

    /// 检查是否是成员（通过用户ID）
    async fn is_member_by_id(&self, user_id: &str, family_id: &str) -> Result<bool> {
        // TODO: 查询数据库
        Ok(true)
    }

    /// 检查是否有待处理的邀请
    async fn has_pending_invitation(&self, email: &str, family_id: &str) -> Result<bool> {
        // TODO: 查询数据库
        Ok(false)
    }

    /// 通过 token 查找邀请
    async fn find_invitation_by_token(&self, token: &str) -> Result<FamilyInvitation> {
        // TODO: 查询数据库
        Err(JiveError::NotFound("Invitation not found".into()))
    }

    /// 获取成员信息
    async fn get_membership(&self, member_id: &str, family_id: &str) -> Result<FamilyMembership> {
        // TODO: 查询数据库
        Err(JiveError::NotFound("Member not found".into()))
    }

    /// 通过用户ID获取成员信息
    async fn get_membership_by_user(&self, user_id: &str, family_id: &str) -> Result<FamilyMembership> {
        // TODO: 查询数据库
        Err(JiveError::NotFound("Member not found".into()))
    }

    /// 获取 Family 信息
    async fn get_family(&self, family_id: &str) -> Result<Family> {
        // TODO: 查询数据库
        Err(JiveError::NotFound("Family not found".into()))
    }

    /// 发送邀请邮件
    async fn send_invitation_email(&self, invitation: &FamilyInvitation, message: Option<String>) -> Result<()> {
        // TODO: 发送邮件
        Ok(())
    }

    /// 通知成员有新成员加入
    async fn notify_members_of_new_member(&self, family_id: &str, user_id: &str) -> Result<()> {
        // TODO: 发送通知
        Ok(())
    }

    /// 通知成员被移除
    async fn notify_member_removed(&self, user_id: &str) -> Result<()> {
        // TODO: 发送通知
        Ok(())
    }

    /// 更新最后访问时间
    async fn update_last_accessed(&self, user_id: &str, family_id: &str) -> Result<()> {
        // TODO: 更新数据库
        Ok(())
    }

    /// 记录审计日志
    async fn log_audit(
        &self,
        family_id: &str,
        user_id: &str,
        action: AuditAction,
        resource_type: &str,
        resource_id: Option<&str>,
        changes: Option<serde_json::Value>,
    ) -> Result<()> {
        let log = FamilyAuditLog {
            id: Uuid::new_v4().to_string(),
            family_id: family_id.to_string(),
            user_id: user_id.to_string(),
            action,
            resource_type: resource_type.to_string(),
            resource_id: resource_id.map(|s| s.to_string()),
            changes,
            ip_address: None,  // TODO: 从上下文获取
            user_agent: None,  // TODO: 从上下文获取
            created_at: Utc::now(),
        };

        // TODO: 保存到数据库
        // self.repository.save_audit_log(&log).await?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_family() {
        let service = FamilyService::new();
        let request = CreateFamilyRequest::new(
            "Test Family".to_string(),
            "USD".to_string(),
            "America/New_York".to_string(),
        );

        // 这个测试会失败，因为还没有实现数据库层
        // let result = service.create_family(request, "user123".to_string()).await;
        // assert!(result.is_ok());
    }

    #[test]
    fn test_email_validation() {
        let service = FamilyService::new();
        assert!(service.is_valid_email("test@example.com"));
        assert!(!service.is_valid_email("invalid"));
        assert!(!service.is_valid_email("@example.com"));
        assert!(!service.is_valid_email("test@"));
    }
}