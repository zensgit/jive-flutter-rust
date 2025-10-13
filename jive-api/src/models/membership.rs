use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

use super::permission::{MemberRole, Permission};

#[allow(dead_code)]
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct FamilyMember {
    pub family_id: Uuid,
    pub user_id: Uuid,
    #[sqlx(try_from = "String")]
    pub role: MemberRole,
    #[sqlx(json)]
    pub permissions: Vec<Permission>,
    pub invited_by: Option<Uuid>,
    #[sqlx(default)]
    pub is_active: bool,
    pub joined_at: DateTime<Utc>,
    pub last_active_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateMemberRequest {
    pub user_id: Uuid,
    pub role: MemberRole,
    pub invited_by: Option<Uuid>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateMemberRequest {
    pub role: Option<MemberRole>,
    pub permissions: Option<Vec<Permission>>,
    pub is_active: Option<bool>,
}

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct MemberWithUserInfo {
    pub family_id: Uuid,
    pub user_id: Uuid,
    pub user_name: Option<String>,
    pub user_email: String,
    #[sqlx(try_from = "String")]
    pub role: MemberRole,
    #[sqlx(json)]
    pub permissions: Vec<Permission>,
    pub is_active: bool,
    pub joined_at: DateTime<Utc>,
    pub last_active_at: Option<DateTime<Utc>>,
}

impl FamilyMember {
    pub fn new(family_id: Uuid, user_id: Uuid, role: MemberRole, invited_by: Option<Uuid>) -> Self {
        Self {
            family_id,
            user_id,
            role,
            permissions: role.default_permissions(),
            invited_by,
            is_active: true,
            joined_at: Utc::now(),
            last_active_at: None,
        }
    }

    pub fn change_role(&mut self, new_role: MemberRole) {
        self.role = new_role;
        self.permissions = new_role.default_permissions();
    }

    pub fn grant_permission(&mut self, permission: Permission) {
        if !self.permissions.contains(&permission) {
            self.permissions.push(permission);
        }
    }

    pub fn revoke_permission(&mut self, permission: Permission) {
        self.permissions.retain(|&p| p != permission);
    }

    pub fn deactivate(&mut self) {
        self.is_active = false;
    }

    pub fn reactivate(&mut self) {
        self.is_active = true;
        self.last_active_at = Some(Utc::now());
    }

    pub fn can_perform(&self, permission: Permission) -> bool {
        self.is_active && self.permissions.contains(&permission)
    }

    pub fn can_manage_member(&self, target_role: MemberRole) -> bool {
        match self.role {
            MemberRole::Owner => true,
            MemberRole::Admin => !matches!(target_role, MemberRole::Owner),
            _ => false,
        }
    }

    pub fn update_last_active(&mut self) {
        self.last_active_at = Some(Utc::now());
    }
}

impl TryFrom<String> for MemberRole {
    type Error = String;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        MemberRole::from_str_name(&value).ok_or_else(|| format!("Invalid role: {}", value))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_member() {
        let family_id = Uuid::new_v4();
        let user_id = Uuid::new_v4();
        let member = FamilyMember::new(family_id, user_id, MemberRole::Member, None);

        assert_eq!(member.family_id, family_id);
        assert_eq!(member.user_id, user_id);
        assert_eq!(member.role, MemberRole::Member);
        assert!(member.is_active);
        assert_eq!(member.permissions, MemberRole::Member.default_permissions());
    }

    #[test]
    fn test_change_role() {
        let family_id = Uuid::new_v4();
        let user_id = Uuid::new_v4();
        let mut member = FamilyMember::new(family_id, user_id, MemberRole::Member, None);

        member.change_role(MemberRole::Admin);
        assert_eq!(member.role, MemberRole::Admin);
        assert_eq!(member.permissions, MemberRole::Admin.default_permissions());
    }

    #[test]
    fn test_grant_and_revoke_permission() {
        let family_id = Uuid::new_v4();
        let user_id = Uuid::new_v4();
        let mut member = FamilyMember::new(family_id, user_id, MemberRole::Viewer, None);

        member.grant_permission(Permission::CreateTransactions);
        assert!(member.permissions.contains(&Permission::CreateTransactions));

        member.revoke_permission(Permission::CreateTransactions);
        assert!(!member.permissions.contains(&Permission::CreateTransactions));
    }

    #[test]
    fn test_can_perform() {
        let family_id = Uuid::new_v4();
        let user_id = Uuid::new_v4();
        let mut member = FamilyMember::new(family_id, user_id, MemberRole::Member, None);

        assert!(member.can_perform(Permission::ViewTransactions));
        assert!(member.can_perform(Permission::CreateTransactions));
        assert!(!member.can_perform(Permission::DeleteFamily));

        member.deactivate();
        assert!(!member.can_perform(Permission::ViewTransactions));
    }

    #[test]
    fn test_can_manage_member() {
        let family_id = Uuid::new_v4();
        let user_id = Uuid::new_v4();

        let owner = FamilyMember::new(family_id, user_id, MemberRole::Owner, None);
        assert!(owner.can_manage_member(MemberRole::Owner));
        assert!(owner.can_manage_member(MemberRole::Admin));
        assert!(owner.can_manage_member(MemberRole::Member));

        let admin = FamilyMember::new(family_id, user_id, MemberRole::Admin, None);
        assert!(!admin.can_manage_member(MemberRole::Owner));
        assert!(admin.can_manage_member(MemberRole::Admin));
        assert!(admin.can_manage_member(MemberRole::Member));

        let member = FamilyMember::new(family_id, user_id, MemberRole::Member, None);
        assert!(!member.can_manage_member(MemberRole::Member));
    }
}
