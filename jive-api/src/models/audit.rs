use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sqlx::FromRow;
use uuid::Uuid;

#[allow(dead_code)]
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct AuditLog {
    pub id: Uuid,
    pub family_id: Uuid,
    pub user_id: Uuid,
    #[sqlx(try_from = "String")]
    pub action: AuditAction,
    pub entity_type: String,
    pub entity_id: Option<Uuid>,
    pub old_values: Option<Value>,
    pub new_values: Option<Value>,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "UPPERCASE")]
pub enum AuditAction {
    Create,
    Update,
    Delete,
    View,
    Export,
    Login,
    Logout,
    InviteSent,
    InviteAccepted,
    InviteCancelled,
    MemberAdded,
    MemberRemoved,
    RoleChanged,
    PermissionChanged,
}

impl TryFrom<String> for AuditAction {
    type Error = String;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        match value.to_uppercase().as_str() {
            "CREATE" => Ok(AuditAction::Create),
            "UPDATE" => Ok(AuditAction::Update),
            "DELETE" => Ok(AuditAction::Delete),
            "VIEW" => Ok(AuditAction::View),
            "EXPORT" => Ok(AuditAction::Export),
            "LOGIN" => Ok(AuditAction::Login),
            "LOGOUT" => Ok(AuditAction::Logout),
            "INVITESENT" | "INVITE_SENT" => Ok(AuditAction::InviteSent),
            "INVITEACCEPTED" | "INVITE_ACCEPTED" => Ok(AuditAction::InviteAccepted),
            "INVITECANCELLED" | "INVITE_CANCELLED" => Ok(AuditAction::InviteCancelled),
            "MEMBERADDED" | "MEMBER_ADDED" => Ok(AuditAction::MemberAdded),
            "MEMBERREMOVED" | "MEMBER_REMOVED" => Ok(AuditAction::MemberRemoved),
            "ROLECHANGED" | "ROLE_CHANGED" => Ok(AuditAction::RoleChanged),
            "PERMISSIONCHANGED" | "PERMISSION_CHANGED" => Ok(AuditAction::PermissionChanged),
            _ => Err(format!("Invalid audit action: {}", value)),
        }
    }
}

impl std::fmt::Display for AuditAction {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            AuditAction::Create => "CREATE",
            AuditAction::Update => "UPDATE",
            AuditAction::Delete => "DELETE",
            AuditAction::View => "VIEW",
            AuditAction::Export => "EXPORT",
            AuditAction::Login => "LOGIN",
            AuditAction::Logout => "LOGOUT",
            AuditAction::InviteSent => "INVITE_SENT",
            AuditAction::InviteAccepted => "INVITE_ACCEPTED",
            AuditAction::InviteCancelled => "INVITE_CANCELLED",
            AuditAction::MemberAdded => "MEMBER_ADDED",
            AuditAction::MemberRemoved => "MEMBER_REMOVED",
            AuditAction::RoleChanged => "ROLE_CHANGED",
            AuditAction::PermissionChanged => "PERMISSION_CHANGED",
        };
        write!(f, "{}", s)
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateAuditLogRequest {
    pub action: AuditAction,
    pub entity_type: String,
    pub entity_id: Option<Uuid>,
    pub old_values: Option<Value>,
    pub new_values: Option<Value>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AuditLogFilter {
    pub family_id: Option<Uuid>,
    pub user_id: Option<Uuid>,
    pub action: Option<AuditAction>,
    pub entity_type: Option<String>,
    pub from_date: Option<DateTime<Utc>>,
    pub to_date: Option<DateTime<Utc>>,
    pub limit: Option<i64>,
    pub offset: Option<i64>,
}

impl AuditLog {
    pub fn new(
        family_id: Uuid,
        user_id: Uuid,
        action: AuditAction,
        entity_type: String,
        entity_id: Option<Uuid>,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            family_id,
            user_id,
            action,
            entity_type,
            entity_id,
            old_values: None,
            new_values: None,
            ip_address: None,
            user_agent: None,
            created_at: Utc::now(),
        }
    }

    pub fn with_values(mut self, old_values: Option<Value>, new_values: Option<Value>) -> Self {
        self.old_values = old_values;
        self.new_values = new_values;
        self
    }

    pub fn with_request_info(mut self, ip_address: Option<String>, user_agent: Option<String>) -> Self {
        self.ip_address = ip_address;
        self.user_agent = user_agent;
        self
    }

    pub fn log_family_created(family_id: Uuid, user_id: Uuid, family_name: &str) -> Self {
        Self::new(
            family_id,
            user_id,
            AuditAction::Create,
            "family".to_string(),
            Some(family_id),
        ).with_values(
            None,
            Some(serde_json::json!({ "name": family_name })),
        )
    }

    pub fn log_member_added(
        family_id: Uuid,
        actor_id: Uuid,
        member_id: Uuid,
        role: &str,
    ) -> Self {
        Self::new(
            family_id,
            actor_id,
            AuditAction::MemberAdded,
            "member".to_string(),
            Some(member_id),
        ).with_values(
            None,
            Some(serde_json::json!({ "role": role })),
        )
    }

    pub fn log_role_changed(
        family_id: Uuid,
        actor_id: Uuid,
        member_id: Uuid,
        old_role: &str,
        new_role: &str,
    ) -> Self {
        Self::new(
            family_id,
            actor_id,
            AuditAction::RoleChanged,
            "member".to_string(),
            Some(member_id),
        ).with_values(
            Some(serde_json::json!({ "role": old_role })),
            Some(serde_json::json!({ "role": new_role })),
        )
    }

    pub fn log_invitation_sent(
        family_id: Uuid,
        inviter_id: Uuid,
        invitation_id: Uuid,
        invitee_email: &str,
    ) -> Self {
        Self::new(
            family_id,
            inviter_id,
            AuditAction::InviteSent,
            "invitation".to_string(),
            Some(invitation_id),
        ).with_values(
            None,
            Some(serde_json::json!({ "invitee_email": invitee_email })),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_audit_log() {
        let family_id = Uuid::new_v4();
        let user_id = Uuid::new_v4();
        let log = AuditLog::new(
            family_id,
            user_id,
            AuditAction::Create,
            "test_entity".to_string(),
            None,
        );
        
        assert_eq!(log.family_id, family_id);
        assert_eq!(log.user_id, user_id);
        assert_eq!(log.action, AuditAction::Create);
        assert_eq!(log.entity_type, "test_entity");
    }

    #[test]
    fn test_audit_action_conversion() {
        assert_eq!(
            AuditAction::try_from("CREATE".to_string()).unwrap(),
            AuditAction::Create
        );
        assert_eq!(
            AuditAction::try_from("member_added".to_string()).unwrap(),
            AuditAction::MemberAdded
        );
        assert_eq!(AuditAction::Create.to_string(), "CREATE");
    }

    #[test]
    fn test_log_builders() {
        let family_id = Uuid::new_v4();
        let user_id = Uuid::new_v4();
        
        let log = AuditLog::log_family_created(family_id, user_id, "Test Family");
        assert_eq!(log.action, AuditAction::Create);
        assert_eq!(log.entity_type, "family");
        assert!(log.new_values.is_some());
        
        let member_id = Uuid::new_v4();
        let log = AuditLog::log_member_added(family_id, user_id, member_id, "member");
        assert_eq!(log.action, AuditAction::MemberAdded);
        assert_eq!(log.entity_id, Some(member_id));
    }
}
