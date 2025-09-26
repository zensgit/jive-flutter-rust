use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "PascalCase")]
pub enum Permission {
    // Family管理权限
    ViewFamilyInfo,
    UpdateFamilyInfo,
    DeleteFamily,

    // 成员管理权限
    ViewMembers,
    InviteMembers,
    RemoveMembers,
    UpdateMemberRoles,

    // 账户管理权限
    ViewAccounts,
    CreateAccounts,
    EditAccounts,
    DeleteAccounts,

    // 交易管理权限
    ViewTransactions,
    CreateTransactions,
    EditTransactions,
    DeleteTransactions,
    BulkEditTransactions,

    // 分类和预算权限
    ViewCategories,
    ManageCategories,
    ViewBudgets,
    ManageBudgets,

    // 报表和数据权限
    ViewReports,
    ExportData,

    // 系统管理权限
    ViewAuditLog,
    ManageIntegrations,
    ManageSettings,
}

impl Permission {
    #[allow(dead_code)]
    pub fn all() -> Vec<Permission> {
        vec![
            Permission::ViewFamilyInfo,
            Permission::UpdateFamilyInfo,
            Permission::DeleteFamily,
            Permission::ViewMembers,
            Permission::InviteMembers,
            Permission::RemoveMembers,
            Permission::UpdateMemberRoles,
            Permission::ViewAccounts,
            Permission::CreateAccounts,
            Permission::EditAccounts,
            Permission::DeleteAccounts,
            Permission::ViewTransactions,
            Permission::CreateTransactions,
            Permission::EditTransactions,
            Permission::DeleteTransactions,
            Permission::BulkEditTransactions,
            Permission::ViewCategories,
            Permission::ManageCategories,
            Permission::ViewBudgets,
            Permission::ManageBudgets,
            Permission::ViewReports,
            Permission::ExportData,
            Permission::ViewAuditLog,
            Permission::ManageIntegrations,
            Permission::ManageSettings,
        ]
    }

    #[allow(dead_code)]
    pub fn from_str_name(s: &str) -> Option<Permission> {
        match s {
            "ViewFamilyInfo" => Some(Permission::ViewFamilyInfo),
            "UpdateFamilyInfo" => Some(Permission::UpdateFamilyInfo),
            "DeleteFamily" => Some(Permission::DeleteFamily),
            "ViewMembers" => Some(Permission::ViewMembers),
            "InviteMembers" => Some(Permission::InviteMembers),
            "RemoveMembers" => Some(Permission::RemoveMembers),
            "UpdateMemberRoles" => Some(Permission::UpdateMemberRoles),
            "ViewAccounts" => Some(Permission::ViewAccounts),
            "CreateAccounts" => Some(Permission::CreateAccounts),
            "EditAccounts" => Some(Permission::EditAccounts),
            "DeleteAccounts" => Some(Permission::DeleteAccounts),
            "ViewTransactions" => Some(Permission::ViewTransactions),
            "CreateTransactions" => Some(Permission::CreateTransactions),
            "EditTransactions" => Some(Permission::EditTransactions),
            "DeleteTransactions" => Some(Permission::DeleteTransactions),
            "BulkEditTransactions" => Some(Permission::BulkEditTransactions),
            "ViewCategories" => Some(Permission::ViewCategories),
            "ManageCategories" => Some(Permission::ManageCategories),
            "ViewBudgets" => Some(Permission::ViewBudgets),
            "ManageBudgets" => Some(Permission::ManageBudgets),
            "ViewReports" => Some(Permission::ViewReports),
            "ExportData" => Some(Permission::ExportData),
            "ViewAuditLog" => Some(Permission::ViewAuditLog),
            "ManageIntegrations" => Some(Permission::ManageIntegrations),
            "ManageSettings" => Some(Permission::ManageSettings),
            _ => None,
        }
    }
}

impl fmt::Display for Permission {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            Permission::ViewFamilyInfo => "ViewFamilyInfo",
            Permission::UpdateFamilyInfo => "UpdateFamilyInfo",
            Permission::DeleteFamily => "DeleteFamily",
            Permission::ViewMembers => "ViewMembers",
            Permission::InviteMembers => "InviteMembers",
            Permission::RemoveMembers => "RemoveMembers",
            Permission::UpdateMemberRoles => "UpdateMemberRoles",
            Permission::ViewAccounts => "ViewAccounts",
            Permission::CreateAccounts => "CreateAccounts",
            Permission::EditAccounts => "EditAccounts",
            Permission::DeleteAccounts => "DeleteAccounts",
            Permission::ViewTransactions => "ViewTransactions",
            Permission::CreateTransactions => "CreateTransactions",
            Permission::EditTransactions => "EditTransactions",
            Permission::DeleteTransactions => "DeleteTransactions",
            Permission::BulkEditTransactions => "BulkEditTransactions",
            Permission::ViewCategories => "ViewCategories",
            Permission::ManageCategories => "ManageCategories",
            Permission::ViewBudgets => "ViewBudgets",
            Permission::ManageBudgets => "ManageBudgets",
            Permission::ViewReports => "ViewReports",
            Permission::ExportData => "ExportData",
            Permission::ViewAuditLog => "ViewAuditLog",
            Permission::ManageIntegrations => "ManageIntegrations",
            Permission::ManageSettings => "ManageSettings",
        };
        write!(f, "{}", s)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum MemberRole {
    Owner,
    Admin,
    Member,
    Viewer,
}

impl MemberRole {
    #[allow(dead_code)]
    pub fn default_permissions(&self) -> Vec<Permission> {
        match self {
            MemberRole::Owner => Permission::all(),
            MemberRole::Admin => vec![
                Permission::ViewFamilyInfo,
                Permission::UpdateFamilyInfo,
                Permission::ViewMembers,
                Permission::InviteMembers,
                Permission::RemoveMembers,
                Permission::UpdateMemberRoles,
                Permission::ViewAccounts,
                Permission::CreateAccounts,
                Permission::EditAccounts,
                Permission::DeleteAccounts,
                Permission::ViewTransactions,
                Permission::CreateTransactions,
                Permission::EditTransactions,
                Permission::DeleteTransactions,
                Permission::BulkEditTransactions,
                Permission::ViewCategories,
                Permission::ManageCategories,
                Permission::ViewBudgets,
                Permission::ManageBudgets,
                Permission::ViewReports,
                Permission::ExportData,
                Permission::ViewAuditLog,
                Permission::ManageIntegrations,
                Permission::ManageSettings,
            ],
            MemberRole::Member => vec![
                Permission::ViewFamilyInfo,
                Permission::ViewMembers,
                Permission::ViewAccounts,
                Permission::CreateAccounts,
                Permission::EditAccounts,
                Permission::ViewTransactions,
                Permission::CreateTransactions,
                Permission::EditTransactions,
                Permission::ViewCategories,
                Permission::ViewBudgets,
                Permission::ViewReports,
                Permission::ExportData,
            ],
            MemberRole::Viewer => vec![
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

    pub fn from_str_name(s: &str) -> Option<MemberRole> {
        match s.to_lowercase().as_str() {
            "owner" => Some(MemberRole::Owner),
            "admin" => Some(MemberRole::Admin),
            "member" => Some(MemberRole::Member),
            "viewer" => Some(MemberRole::Viewer),
            _ => None,
        }
    }
}

impl fmt::Display for MemberRole {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            MemberRole::Owner => "owner",
            MemberRole::Admin => "admin",
            MemberRole::Member => "member",
            MemberRole::Viewer => "viewer",
        };
        write!(f, "{}", s)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_permission_from_str() {
        assert_eq!(
            Permission::from_str_name("ViewFamilyInfo"),
            Some(Permission::ViewFamilyInfo)
        );
        assert_eq!(Permission::from_str_name("InvalidPermission"), None);
    }

    #[test]
    fn test_role_from_str() {
        assert_eq!(MemberRole::from_str_name("owner"), Some(MemberRole::Owner));
        assert_eq!(MemberRole::from_str_name("Owner"), Some(MemberRole::Owner));
        assert_eq!(MemberRole::from_str_name("invalid"), None);
    }

    #[test]
    fn test_owner_has_all_permissions() {
        let owner_perms = MemberRole::Owner.default_permissions();
        let all_perms = Permission::all();
        assert_eq!(owner_perms.len(), all_perms.len());
    }

    #[test]
    fn test_viewer_has_limited_permissions() {
        let viewer_perms = MemberRole::Viewer.default_permissions();
        assert!(viewer_perms.contains(&Permission::ViewFamilyInfo));
        assert!(!viewer_perms.contains(&Permission::DeleteFamily));
        assert!(!viewer_perms.contains(&Permission::CreateTransactions));
    }
}
