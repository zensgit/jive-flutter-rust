//! Multi-Family Service - 多 Family 管理服务
//! 
//! 支持用户创建和管理多个 Family，在不同 Family 间切换

use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::domain::{
    User, Family, FamilyMembership, FamilyRole, Permission,
    FamilySettings, FamilyInvitation
};
use crate::error::{JiveError, Result};
use crate::application::{ServiceContext, ServiceResponse, FamilyService};
use crate::infrastructure::repositories::FamilyRepository;

/// 用户的 Family 信息（包含角色）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserFamilyInfo {
    pub family: Family,
    pub role: FamilyRole,
    pub permissions: Vec<Permission>,
    pub member_count: i64,
    pub joined_at: DateTime<Utc>,
    pub last_accessed_at: Option<DateTime<Utc>>,
    pub is_current: bool,
    pub can_delete: bool,  // 只有 Owner 且只有一个成员时可删除
}

/// Family 切换请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwitchFamilyRequest {
    pub user_id: String,
    pub target_family_id: String,
}

/// Family 切换响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwitchFamilyResponse {
    pub family: Family,
    pub role: FamilyRole,
    pub permissions: Vec<Permission>,
    pub context: ServiceContext,
}

/// 多 Family 服务
pub struct MultiFamilyService<R: FamilyRepository> {
    family_service: FamilyService,
    repository: R,
}

impl<R: FamilyRepository> MultiFamilyService<R> {
    pub fn new(family_service: FamilyService, repository: R) -> Self {
        Self {
            family_service,
            repository,
        }
    }

    /// 为已登录用户创建额外的 Family
    pub async fn create_additional_family(
        &self,
        user_id: String,
        request: CreateFamilyRequest,
    ) -> Result<ServiceResponse<UserFamilyInfo>> {
        // 1. 验证用户存在
        // TODO: 验证用户
        
        // 2. 创建新 Family
        let family = Family::new(
            request.name.clone(),
            request.currency.clone(),
            request.timezone.clone(),
        );

        // 3. 保存 Family
        let saved_family = self.repository.create_family(&family).await?;

        // 4. 创建 Owner 成员关系
        let membership = FamilyMembership {
            id: Uuid::new_v4().to_string(),
            family_id: saved_family.id.clone(),
            user_id: user_id.clone(),
            role: FamilyRole::Owner,  // ⭐ 创建者成为 Owner
            permissions: FamilyRole::Owner.default_permissions(),
            joined_at: Utc::now(),
            invited_by: None,
            is_active: true,
            last_accessed_at: Some(Utc::now()),
        };

        let saved_membership = self.repository.create_membership(&membership).await?;

        // 5. 创建默认数据（分类、标签等）
        self.create_default_family_data(&saved_family).await?;

        // 6. 构建响应
        let info = UserFamilyInfo {
            family: saved_family,
            role: FamilyRole::Owner,
            permissions: saved_membership.permissions,
            member_count: 1,
            joined_at: saved_membership.joined_at,
            last_accessed_at: saved_membership.last_accessed_at,
            is_current: false,  // 新创建的不自动切换
            can_delete: true,   // 只有自己一个人，可以删除
        };

        Ok(ServiceResponse::success_with_message(
            info,
            format!("Family '{}' created successfully", request.name)
        ))
    }

    /// 获取用户的所有 Family 列表（包含角色信息）
    pub async fn get_user_families_with_roles(
        &self,
        user_id: String,
        current_family_id: Option<String>,
    ) -> Result<ServiceResponse<Vec<UserFamilyInfo>>> {
        // 1. 获取用户的所有 Family
        let families = self.repository.list_user_families(&user_id).await?;
        
        // 2. 获取每个 Family 的详细信息
        let mut result = Vec::new();
        for family in families {
            // 获取成员关系
            let membership = self.repository
                .get_membership_by_user(&user_id, &family.id)
                .await?;
            
            // 获取成员数量
            let member_count = self.repository
                .count_family_members(&family.id)
                .await?;
            
            // 判断是否可以删除（Owner 且只有一个成员）
            let can_delete = membership.role == FamilyRole::Owner && member_count == 1;
            
            // 判断是否是当前 Family
            let is_current = current_family_id.as_ref()
                .map(|id| id == &family.id)
                .unwrap_or(false);
            
            result.push(UserFamilyInfo {
                family,
                role: membership.role.clone(),
                permissions: membership.permissions.clone(),
                member_count,
                joined_at: membership.joined_at,
                last_accessed_at: membership.last_accessed_at,
                is_current,
                can_delete,
            });
        }

        // 3. 按最近访问时间排序
        result.sort_by(|a, b| {
            b.last_accessed_at.cmp(&a.last_accessed_at)
        });

        Ok(ServiceResponse::success(result))
    }

    /// 切换当前 Family
    pub async fn switch_family(
        &self,
        request: SwitchFamilyRequest,
    ) -> Result<ServiceResponse<SwitchFamilyResponse>> {
        // 1. 验证用户是目标 Family 的成员
        let membership = self.repository
            .get_membership_by_user(&request.user_id, &request.target_family_id)
            .await
            .map_err(|_| JiveError::Forbidden("Not a member of this family".into()))?;

        if !membership.is_active {
            return Err(JiveError::Forbidden("Membership is not active".into()));
        }

        // 2. 获取 Family 信息
        let family = self.repository
            .get_family(&request.target_family_id)
            .await?;

        // 3. 更新用户的当前 Family
        // TODO: 更新 user.current_family_id
        
        // 4. 更新最后访问时间
        let mut updated_membership = membership.clone();
        updated_membership.last_accessed_at = Some(Utc::now());
        self.repository.update_membership(&updated_membership).await?;

        // 5. 创建新的服务上下文
        let context = ServiceContext::new(
            request.user_id.clone(),
            request.target_family_id.clone(),
        )
        .with_permissions(membership.permissions.clone());

        // 6. 构建响应
        let response = SwitchFamilyResponse {
            family,
            role: membership.role,
            permissions: membership.permissions,
            context,
        };

        Ok(ServiceResponse::success_with_message(
            response,
            "Switched family successfully".to_string()
        ))
    }

    /// 离开 Family（非 Owner）
    pub async fn leave_family(
        &self,
        user_id: String,
        family_id: String,
    ) -> Result<ServiceResponse<()>> {
        // 1. 获取成员关系
        let membership = self.repository
            .get_membership_by_user(&user_id, &family_id)
            .await?;

        // 2. Owner 不能直接离开（需要转让或删除）
        if membership.role == FamilyRole::Owner {
            let member_count = self.repository
                .count_family_members(&family_id)
                .await?;
            
            if member_count > 1 {
                return Err(JiveError::BadRequest(
                    "Owner must transfer ownership before leaving".into()
                ));
            } else {
                return Err(JiveError::BadRequest(
                    "Use delete_family to remove a family with only one member".into()
                ));
            }
        }

        // 3. 标记成员关系为非活跃
        self.repository.delete_membership(&membership.id).await?;

        Ok(ServiceResponse::success_with_message(
            (),
            "Left family successfully".to_string()
        ))
    }

    /// 删除 Family（只有 Owner 且只有一个成员时可以删除）
    pub async fn delete_family(
        &self,
        context: ServiceContext,
        family_id: String,
    ) -> Result<ServiceResponse<()>> {
        // 1. 验证用户是 Owner
        let membership = self.repository
            .get_membership_by_user(&context.user_id, &family_id)
            .await?;

        if membership.role != FamilyRole::Owner {
            return Err(JiveError::Forbidden("Only owner can delete family".into()));
        }

        // 2. 验证只有一个成员
        let member_count = self.repository
            .count_family_members(&family_id)
            .await?;

        if member_count > 1 {
            return Err(JiveError::BadRequest(
                "Cannot delete family with multiple members".into()
            ));
        }

        // 3. 删除 Family（软删除）
        self.repository.delete_family(&family_id).await?;

        // 4. 如果这是用户的当前 Family，需要切换到其他 Family
        // TODO: 处理 current_family_id 更新

        Ok(ServiceResponse::success_with_message(
            (),
            "Family deleted successfully".to_string()
        ))
    }

    /// 获取 Family 切换建议
    pub async fn get_family_suggestions(
        &self,
        user_id: String,
    ) -> Result<ServiceResponse<FamilySuggestions>> {
        let families = self.get_user_families_with_roles(user_id.clone(), None)
            .await?
            .data
            .unwrap_or_default();

        let suggestions = FamilySuggestions {
            personal_family: families.iter()
                .find(|f| f.role == FamilyRole::Owner && f.member_count == 1)
                .cloned(),
            shared_families: families.iter()
                .filter(|f| f.member_count > 1)
                .cloned()
                .collect(),
            recent_family: families.first().cloned(),
            total_families: families.len(),
        };

        Ok(ServiceResponse::success(suggestions))
    }

    /// 创建默认的 Family 数据
    async fn create_default_family_data(&self, family: &Family) -> Result<()> {
        // TODO: 创建默认分类
        // - 收入：工资、奖金、投资收益、其他收入
        // - 支出：餐饮、交通、购物、娱乐、教育、医疗、住房、其他
        
        // TODO: 创建默认标签
        // - 必需、可选、紧急、计划中
        
        Ok(())
    }
}

/// Family 切换建议
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilySuggestions {
    pub personal_family: Option<UserFamilyInfo>,  // 个人 Family（单人 Owner）
    pub shared_families: Vec<UserFamilyInfo>,     // 共享 Family（多人）
    pub recent_family: Option<UserFamilyInfo>,    // 最近使用的 Family
    pub total_families: usize,
}

/// Family 快速创建模板
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FamilyTemplate {
    Personal,       // 个人理财
    Couple,         // 夫妻共同
    Family,         // 家庭账本
    Roommates,      // 室友 AA
    Travel,         // 旅行基金
    Business,       // 小生意
    Custom,         // 自定义
}

impl FamilyTemplate {
    /// 根据模板生成 Family 设置
    pub fn to_settings(&self) -> FamilySettings {
        match self {
            FamilyTemplate::Personal => FamilySettings {
                shared_categories: false,
                shared_tags: false,
                shared_payees: false,
                shared_budgets: false,
                show_member_transactions: false,
                ..Default::default()
            },
            FamilyTemplate::Couple | FamilyTemplate::Family => FamilySettings {
                shared_categories: true,
                shared_tags: true,
                shared_payees: true,
                shared_budgets: true,
                show_member_transactions: true,
                ..Default::default()
            },
            FamilyTemplate::Roommates => FamilySettings {
                shared_categories: true,
                shared_tags: true,
                shared_payees: true,
                shared_budgets: false,  // 各自预算
                show_member_transactions: false,  // 隐私
                ..Default::default()
            },
            _ => FamilySettings::default(),
        }
    }

    /// 获取模板的默认名称
    pub fn default_name(&self, user_name: &str) -> String {
        match self {
            FamilyTemplate::Personal => format!("{}'s Personal Finance", user_name),
            FamilyTemplate::Couple => format!("{}'s Couple Finance", user_name),
            FamilyTemplate::Family => format!("{}'s Family", user_name),
            FamilyTemplate::Roommates => "Roommates Shared Expenses".to_string(),
            FamilyTemplate::Travel => "Travel Fund".to_string(),
            FamilyTemplate::Business => format!("{}'s Business", user_name),
            FamilyTemplate::Custom => "New Family".to_string(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_family_template_settings() {
        let personal = FamilyTemplate::Personal.to_settings();
        assert!(!personal.shared_categories);
        assert!(!personal.show_member_transactions);

        let family = FamilyTemplate::Family.to_settings();
        assert!(family.shared_categories);
        assert!(family.show_member_transactions);

        let roommates = FamilyTemplate::Roommates.to_settings();
        assert!(roommates.shared_categories);
        assert!(!roommates.show_member_transactions);  // 隐私
    }

    #[test]
    fn test_template_names() {
        assert_eq!(
            FamilyTemplate::Personal.default_name("John"),
            "John's Personal Finance"
        );
        assert_eq!(
            FamilyTemplate::Roommates.default_name("John"),
            "Roommates Shared Expenses"
        );
    }
}