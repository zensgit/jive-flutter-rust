use crate::models::permission::{MemberRole, Permission};
use uuid::Uuid;

use super::ServiceError;

#[derive(Clone, Debug)]
pub struct ServiceContext {
    pub user_id: Uuid,
    pub family_id: Uuid,
    pub role: MemberRole,
    pub permissions: Vec<Permission>,
    pub user_email: String,
    pub user_name: Option<String>,
}

impl ServiceContext {
    pub fn new(
        user_id: Uuid,
        family_id: Uuid,
        role: MemberRole,
        permissions: Vec<Permission>,
        user_email: String,
        user_name: Option<String>,
    ) -> Self {
        Self {
            user_id,
            family_id,
            role,
            permissions,
            user_email,
            user_name,
        }
    }

    pub fn can_perform(&self, permission: Permission) -> bool {
        self.permissions.contains(&permission)
    }

    pub fn require_permission(&self, permission: Permission) -> Result<(), ServiceError> {
        if !self.can_perform(permission) {
            return Err(ServiceError::PermissionDenied);
        }
        Ok(())
    }

    pub fn require_owner(&self) -> Result<(), ServiceError> {
        if self.role != MemberRole::Owner {
            return Err(ServiceError::PermissionDenied);
        }
        Ok(())
    }

    pub fn require_admin_or_owner(&self) -> Result<(), ServiceError> {
        if !matches!(self.role, MemberRole::Owner | MemberRole::Admin) {
            return Err(ServiceError::PermissionDenied);
        }
        Ok(())
    }

    pub fn can_manage_role(&self, target_role: MemberRole) -> bool {
        match self.role {
            MemberRole::Owner => true,
            MemberRole::Admin => !matches!(target_role, MemberRole::Owner),
            _ => false,
        }
    }
}
