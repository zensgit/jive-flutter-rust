//! Family domain model - 多用户协作核心模型
//! 
//! 基于 Maybe 的 Family 模型设计，支持多用户共享财务数据

use chrono::{DateTime, Utc};
use serde::{Serialize, Deserialize};
use uuid::Uuid;
use rust_decimal::Decimal;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::error::{JiveError, Result};
use super::{Entity, SoftDeletable};

/// Family - 多用户协作的核心实体
/// 对应 Maybe 的 Family 模型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Family {
    pub id: String,
    pub name: String,
    pub currency: String,
    pub timezone: String,
    pub locale: String,
    pub date_format: String,
    pub settings: FamilySettings,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub deleted_at: Option<DateTime<Utc>>,
}

/// Family 设置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilySettings {
    // 自动化设置
    pub auto_categorize_enabled: bool,
    pub smart_defaults_enabled: bool,
    pub auto_detect_merchants: bool,
    pub use_last_selected_category: bool,
    
    // 审批设置
    pub require_approval_for_large_transactions: bool,
    pub large_transaction_threshold: Option<Decimal>,
    
    // 共享设置
    pub shared_categories: bool,
    pub shared_tags: bool,
    pub shared_payees: bool,
    pub shared_budgets: bool,
    
    // 通知设置
    pub notification_preferences: NotificationPreferences,
    
    // 货币设置
    pub multi_currency_enabled: bool,
    pub auto_update_exchange_rates: bool,
    
    // 隐私设置
    pub show_member_transactions: bool,
    pub allow_member_exports: bool,
}

impl Default for FamilySettings {
    fn default() -> Self {
        Self {
            auto_categorize_enabled: true,
            smart_defaults_enabled: true,
            auto_detect_merchants: true,
            use_last_selected_category: false,
            require_approval_for_large_transactions: false,
            large_transaction_threshold: None,
            shared_categories: true,
            shared_tags: true,
            shared_payees: true,
            shared_budgets: true,
            notification_preferences: NotificationPreferences::default(),
            multi_currency_enabled: false,
            auto_update_exchange_rates: true,
            show_member_transactions: true,
            allow_member_exports: true,
        }
    }
}

/// 通知偏好设置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NotificationPreferences {
    pub transaction_created: bool,
    pub transaction_updated: bool,
    pub member_joined: bool,
    pub member_left: bool,
    pub budget_exceeded: bool,
    pub large_transaction: bool,
    pub weekly_summary: bool,
    pub monthly_report: bool,
}

impl Default for NotificationPreferences {
    fn default() -> Self {
        Self {
            transaction_created: false,
            transaction_updated: false,
            member_joined: true,
            member_left: true,
            budget_exceeded: true,
            large_transaction: true,
            weekly_summary: true,
            monthly_report: true,
        }
    }
}

/// 用户与 Family 的关联（成员关系）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilyMembership {
    pub id: String,
    pub family_id: String,
    pub user_id: String,
    pub role: FamilyRole,
    pub permissions: Vec<Permission>,
    pub joined_at: DateTime<Utc>,
    pub invited_by: Option<String>,
    pub is_active: bool,
    pub last_accessed_at: Option<DateTime<Utc>>,
}

/// Family 角色 - 基于 Maybe 的角色系统
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum FamilyRole {
    Owner,    // 创建者，拥有所有权限（类似 Maybe 的第一个用户）
    Admin,    // 管理员，可以管理成员和设置（对应 Maybe 的 admin role）
    Member,   // 普通成员，可以查看和编辑数据（对应 Maybe 的 member role）
    Viewer,   // 只读成员，只能查看数据（扩展功能）
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl FamilyRole {
    #[wasm_bindgen(getter)]
    pub fn as_string(&self) -> String {
        match self {
            FamilyRole::Owner => "owner".to_string(),
            FamilyRole::Admin => "admin".to_string(),
            FamilyRole::Member => "member".to_string(),
            FamilyRole::Viewer => "viewer".to_string(),
        }
    }

    #[wasm_bindgen]
    pub fn from_string(s: &str) -> Option<FamilyRole> {
        match s {
            "owner" => Some(FamilyRole::Owner),
            "admin" => Some(FamilyRole::Admin),
            "member" => Some(FamilyRole::Member),
            "viewer" => Some(FamilyRole::Viewer),
            _ => None,
        }
    }
}

/// 细粒度权限 - 扩展 Maybe 的权限系统
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum Permission {
    // 账户权限
    ViewAccounts,
    CreateAccounts,
    EditAccounts,
    DeleteAccounts,
    ConnectBankAccounts,  // 对应 Maybe 的 Plaid 连接
    
    // 交易权限
    ViewTransactions,
    CreateTransactions,
    EditTransactions,
    DeleteTransactions,
    BulkEditTransactions,
    ImportTransactions,
    ExportTransactions,
    
    // 分类权限
    ViewCategories,
    ManageCategories,
    
    // 商户/收款人权限
    ViewPayees,
    ManagePayees,
    
    // 标签权限
    ViewTags,
    ManageTags,
    
    // 预算权限
    ViewBudgets,
    CreateBudgets,
    EditBudgets,
    DeleteBudgets,
    
    // 报表权限
    ViewReports,
    ExportReports,
    
    // 规则权限
    ViewRules,
    ManageRules,
    
    // 管理权限
    InviteMembers,
    RemoveMembers,
    ManageRoles,
    ManageFamilySettings,
    ManageLedgers,
    ManageIntegrations,
    
    // 高级权限
    ViewAuditLog,
    ManageSubscription,
    ImpersonateMembers,  // 对应 Maybe 的 impersonation
}

impl FamilyRole {
    /// 获取角色的默认权限 - 基于 Maybe 的权限模型
    pub fn default_permissions(&self) -> Vec<Permission> {
        use Permission::*;
        match self {
            FamilyRole::Owner => {
                // Owner 拥有所有权限
                vec![
                    ViewAccounts, CreateAccounts, EditAccounts, DeleteAccounts, ConnectBankAccounts,
                    ViewTransactions, CreateTransactions, EditTransactions, DeleteTransactions,
                    BulkEditTransactions, ImportTransactions, ExportTransactions,
                    ViewCategories, ManageCategories,
                    ViewPayees, ManagePayees,
                    ViewTags, ManageTags,
                    ViewBudgets, CreateBudgets, EditBudgets, DeleteBudgets,
                    ViewReports, ExportReports,
                    ViewRules, ManageRules,
                    InviteMembers, RemoveMembers, ManageRoles, ManageFamilySettings,
                    ManageLedgers, ManageIntegrations,
                    ViewAuditLog, ManageSubscription, ImpersonateMembers,
                ]
            }
            FamilyRole::Admin => {
                // Admin 拥有管理权限，但不能管理订阅和模拟用户
                vec![
                    ViewAccounts, CreateAccounts, EditAccounts, DeleteAccounts, ConnectBankAccounts,
                    ViewTransactions, CreateTransactions, EditTransactions, DeleteTransactions,
                    BulkEditTransactions, ImportTransactions, ExportTransactions,
                    ViewCategories, ManageCategories,
                    ViewPayees, ManagePayees,
                    ViewTags, ManageTags,
                    ViewBudgets, CreateBudgets, EditBudgets, DeleteBudgets,
                    ViewReports, ExportReports,
                    ViewRules, ManageRules,
                    InviteMembers, RemoveMembers, ManageFamilySettings, ManageLedgers,
                    ManageIntegrations, ViewAuditLog,
                ]
            }
            FamilyRole::Member => {
                // Member 可以查看和编辑数据，但不能管理
                vec![
                    ViewAccounts, CreateAccounts, EditAccounts,
                    ViewTransactions, CreateTransactions, EditTransactions,
                    ImportTransactions, ExportTransactions,
                    ViewCategories,
                    ViewPayees,
                    ViewTags,
                    ViewBudgets,
                    ViewReports, ExportReports,
                    ViewRules,
                ]
            }
            FamilyRole::Viewer => {
                // Viewer 只能查看，不能编辑
                vec![
                    ViewAccounts,
                    ViewTransactions,
                    ViewCategories,
                    ViewPayees,
                    ViewTags,
                    ViewBudgets,
                    ViewReports,
                    ViewRules,
                ]
            }
        }
    }

    /// 检查是否是管理角色
    pub fn is_admin(&self) -> bool {
        matches!(self, FamilyRole::Owner | FamilyRole::Admin)
    }

    /// 检查是否可以编辑数据
    pub fn can_edit(&self) -> bool {
        !matches!(self, FamilyRole::Viewer)
    }

    /// 检查是否可以导出数据
    pub fn can_export(&self) -> bool {
        matches!(self, FamilyRole::Owner | FamilyRole::Admin | FamilyRole::Member)
    }
}

/// 邀请状态
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum InvitationStatus {
    Pending,
    Accepted,
    Declined,
    Expired,
}

/// Family 邀请
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilyInvitation {
    pub id: String,
    pub family_id: String,
    pub inviter_id: String,
    pub invitee_email: String,
    pub role: FamilyRole,
    pub custom_permissions: Option<Vec<Permission>>,
    pub token: String,
    pub status: InvitationStatus,
    pub expires_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
    pub accepted_at: Option<DateTime<Utc>>,
}

impl FamilyInvitation {
    /// 创建新的邀请
    pub fn new(
        family_id: String,
        inviter_id: String,
        invitee_email: String,
        role: FamilyRole,
    ) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            family_id,
            inviter_id,
            invitee_email,
            role,
            custom_permissions: None,
            token: Self::generate_token(),
            status: InvitationStatus::Pending,
            expires_at: Utc::now() + chrono::Duration::days(7),
            created_at: Utc::now(),
            accepted_at: None,
        }
    }

    /// 生成安全的邀请 token
    fn generate_token() -> String {
        use rand::Rng;
        const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ\
                                abcdefghijklmnopqrstuvwxyz\
                                0123456789";
        let mut rng = rand::thread_rng();
        
        (0..32)
            .map(|_| {
                let idx = rng.gen_range(0..CHARSET.len());
                CHARSET[idx] as char
            })
            .collect()
    }

    /// 检查邀请是否有效
    pub fn is_valid(&self) -> bool {
        self.status == InvitationStatus::Pending && self.expires_at > Utc::now()
    }

    /// 接受邀请
    pub fn accept(&mut self) -> Result<()> {
        if !self.is_valid() {
            return Err(JiveError::BadRequest("Invalid or expired invitation".into()));
        }
        
        self.status = InvitationStatus::Accepted;
        self.accepted_at = Some(Utc::now());
        Ok(())
    }

    /// 拒绝邀请
    pub fn decline(&mut self) {
        self.status = InvitationStatus::Declined;
    }
}

/// 审计日志条目
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilyAuditLog {
    pub id: String,
    pub family_id: String,
    pub user_id: String,
    pub action: AuditAction,
    pub resource_type: String,
    pub resource_id: Option<String>,
    pub changes: Option<serde_json::Value>,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub created_at: DateTime<Utc>,
}

/// 审计动作类型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AuditAction {
    // 成员管理
    MemberInvited,
    MemberJoined,
    MemberRemoved,
    MemberRoleChanged,
    
    // 数据操作
    DataCreated,
    DataUpdated,
    DataDeleted,
    DataImported,
    DataExported,
    
    // 设置变更
    SettingsUpdated,
    PermissionsChanged,
    
    // 安全事件
    LoginAttempt,
    LoginSuccess,
    LoginFailed,
    PasswordChanged,
    MfaEnabled,
    MfaDisabled,
    
    // 集成操作
    IntegrationConnected,
    IntegrationDisconnected,
    IntegrationSynced,
}

impl Family {
    /// 创建新的 Family
    pub fn new(name: String, currency: String, timezone: String) -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name,
            currency,
            timezone,
            locale: "en".to_string(),
            date_format: "%Y-%m-%d".to_string(),
            settings: FamilySettings::default(),
            created_at: Utc::now(),
            updated_at: Utc::now(),
            deleted_at: None,
        }
    }

    /// 更新 Family 设置
    pub fn update_settings(&mut self, settings: FamilySettings) {
        self.settings = settings;
        self.updated_at = Utc::now();
    }

    /// 检查是否启用了某个功能
    pub fn is_feature_enabled(&self, feature: &str) -> bool {
        match feature {
            "auto_categorize" => self.settings.auto_categorize_enabled,
            "smart_defaults" => self.settings.smart_defaults_enabled,
            "multi_currency" => self.settings.multi_currency_enabled,
            "large_transaction_approval" => self.settings.require_approval_for_large_transactions,
            _ => false,
        }
    }
}

impl Entity for Family {
    fn id(&self) -> &str {
        &self.id
    }

    fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }

    fn updated_at(&self) -> DateTime<Utc> {
        self.updated_at
    }
}

impl SoftDeletable for Family {
    fn deleted_at(&self) -> Option<DateTime<Utc>> {
        self.deleted_at
    }

    fn soft_delete(&mut self) {
        self.deleted_at = Some(Utc::now());
    }

    fn restore(&mut self) {
        self.deleted_at = None;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_family_role_permissions() {
        // Owner should have all permissions
        let owner_perms = FamilyRole::Owner.default_permissions();
        assert!(owner_perms.contains(&Permission::ManageSubscription));
        assert!(owner_perms.contains(&Permission::ImpersonateMembers));

        // Admin should not have subscription and impersonation permissions
        let admin_perms = FamilyRole::Admin.default_permissions();
        assert!(!admin_perms.contains(&Permission::ManageSubscription));
        assert!(!admin_perms.contains(&Permission::ImpersonateMembers));
        assert!(admin_perms.contains(&Permission::InviteMembers));

        // Member should have basic edit permissions
        let member_perms = FamilyRole::Member.default_permissions();
        assert!(member_perms.contains(&Permission::CreateTransactions));
        assert!(!member_perms.contains(&Permission::ManageRoles));

        // Viewer should only have view permissions
        let viewer_perms = FamilyRole::Viewer.default_permissions();
        assert!(viewer_perms.contains(&Permission::ViewTransactions));
        assert!(!viewer_perms.contains(&Permission::CreateTransactions));
    }

    #[test]
    fn test_invitation_validity() {
        let mut invitation = FamilyInvitation::new(
            "family123".to_string(),
            "user123".to_string(),
            "newuser@example.com".to_string(),
            FamilyRole::Member,
        );

        assert!(invitation.is_valid());
        assert_eq!(invitation.status, InvitationStatus::Pending);

        // Test accepting invitation
        invitation.accept().unwrap();
        assert_eq!(invitation.status, InvitationStatus::Accepted);
        assert!(invitation.accepted_at.is_some());

        // Cannot accept twice
        assert!(invitation.accept().is_err());
    }

    #[test]
    fn test_family_settings() {
        let mut family = Family::new(
            "Test Family".to_string(),
            "USD".to_string(),
            "America/New_York".to_string(),
        );

        assert!(family.is_feature_enabled("auto_categorize"));
        
        let mut settings = family.settings.clone();
        settings.auto_categorize_enabled = false;
        family.update_settings(settings);
        
        assert!(!family.is_feature_enabled("auto_categorize"));
    }
}