use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

use super::permission::MemberRole;

#[allow(dead_code)]
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Invitation {
    pub id: Uuid,
    pub family_id: Uuid,
    pub inviter_id: Uuid,
    pub invitee_email: String,
    #[sqlx(try_from = "String")]
    pub role: MemberRole,
    pub invite_code: String,
    pub invite_token: Uuid,
    pub expires_at: DateTime<Utc>,
    #[sqlx(try_from = "String")]
    pub status: InvitationStatus,
    pub accepted_at: Option<DateTime<Utc>>,
    pub accepted_by: Option<Uuid>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum InvitationStatus {
    Pending,
    Accepted,
    Expired,
    Cancelled,
}

impl TryFrom<String> for InvitationStatus {
    type Error = String;

    fn try_from(value: String) -> Result<Self, Self::Error> {
        match value.to_lowercase().as_str() {
            "pending" => Ok(InvitationStatus::Pending),
            "accepted" => Ok(InvitationStatus::Accepted),
            "expired" => Ok(InvitationStatus::Expired),
            "cancelled" => Ok(InvitationStatus::Cancelled),
            _ => Err(format!("Invalid invitation status: {}", value)),
        }
    }
}

impl std::fmt::Display for InvitationStatus {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let s = match self {
            InvitationStatus::Pending => "pending",
            InvitationStatus::Accepted => "accepted",
            InvitationStatus::Expired => "expired",
            InvitationStatus::Cancelled => "cancelled",
        };
        write!(f, "{}", s)
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateInvitationRequest {
    pub invitee_email: String,
    pub role: MemberRole,
    pub expires_in_days: Option<i64>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AcceptInvitationRequest {
    pub invite_code: Option<String>,
    pub invite_token: Option<Uuid>,
}

#[derive(Debug, Serialize, Deserialize, FromRow)]
pub struct InvitationResponse {
    pub id: Uuid,
    pub family_id: Uuid,
    pub family_name: String,
    pub inviter_name: Option<String>,
    pub invitee_email: String,
    #[sqlx(try_from = "String")]
    pub role: MemberRole,
    pub invite_code: String,
    pub invite_link: String,
    pub expires_at: DateTime<Utc>,
    #[sqlx(try_from = "String")]
    pub status: InvitationStatus,
}

impl Invitation {
    pub fn new(
        family_id: Uuid,
        inviter_id: Uuid,
        invitee_email: String,
        role: MemberRole,
        expires_in_days: Option<i64>,
    ) -> Self {
        let now = Utc::now();
        let expires_at = now + Duration::days(expires_in_days.unwrap_or(7));

        Self {
            id: Uuid::new_v4(),
            family_id,
            inviter_id,
            invitee_email,
            role,
            invite_code: Self::generate_invite_code(),
            invite_token: Uuid::new_v4(),
            expires_at,
            status: InvitationStatus::Pending,
            accepted_at: None,
            accepted_by: None,
            created_at: now,
        }
    }

    pub fn generate_invite_code() -> String {
        use rand::Rng;
        const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        let mut rng = rand::thread_rng();

        (0..8)
            .map(|_| {
                let idx = rng.gen_range(0..CHARSET.len());
                CHARSET[idx] as char
            })
            .collect()
    }

    pub fn is_valid(&self) -> bool {
        self.status == InvitationStatus::Pending && !self.is_expired()
    }

    pub fn is_expired(&self) -> bool {
        Utc::now() > self.expires_at
    }

    pub fn accept(&mut self, user_id: Uuid) -> Result<(), String> {
        if !self.is_valid() {
            return Err("Invitation is not valid".to_string());
        }

        self.status = InvitationStatus::Accepted;
        self.accepted_at = Some(Utc::now());
        self.accepted_by = Some(user_id);
        Ok(())
    }

    pub fn cancel(&mut self) -> Result<(), String> {
        if self.status != InvitationStatus::Pending {
            return Err("Can only cancel pending invitations".to_string());
        }

        self.status = InvitationStatus::Cancelled;
        Ok(())
    }

    pub fn mark_expired(&mut self) {
        if self.status == InvitationStatus::Pending && self.is_expired() {
            self.status = InvitationStatus::Expired;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_invitation() {
        let family_id = Uuid::new_v4();
        let inviter_id = Uuid::new_v4();
        let invitation = Invitation::new(
            family_id,
            inviter_id,
            "test@example.com".to_string(),
            MemberRole::Member,
            None,
        );

        assert_eq!(invitation.family_id, family_id);
        assert_eq!(invitation.inviter_id, inviter_id);
        assert_eq!(invitation.invitee_email, "test@example.com");
        assert_eq!(invitation.role, MemberRole::Member);
        assert_eq!(invitation.status, InvitationStatus::Pending);
        assert!(invitation.is_valid());
    }

    #[test]
    fn test_accept_invitation() {
        let family_id = Uuid::new_v4();
        let inviter_id = Uuid::new_v4();
        let user_id = Uuid::new_v4();

        let mut invitation = Invitation::new(
            family_id,
            inviter_id,
            "test@example.com".to_string(),
            MemberRole::Member,
            None,
        );

        assert!(invitation.accept(user_id).is_ok());
        assert_eq!(invitation.status, InvitationStatus::Accepted);
        assert_eq!(invitation.accepted_by, Some(user_id));
        assert!(!invitation.is_valid());
    }

    #[test]
    fn test_cancel_invitation() {
        let family_id = Uuid::new_v4();
        let inviter_id = Uuid::new_v4();

        let mut invitation = Invitation::new(
            family_id,
            inviter_id,
            "test@example.com".to_string(),
            MemberRole::Member,
            None,
        );

        assert!(invitation.cancel().is_ok());
        assert_eq!(invitation.status, InvitationStatus::Cancelled);
        assert!(!invitation.is_valid());
    }

    #[test]
    fn test_expired_invitation() {
        let family_id = Uuid::new_v4();
        let inviter_id = Uuid::new_v4();

        let mut invitation = Invitation::new(
            family_id,
            inviter_id,
            "test@example.com".to_string(),
            MemberRole::Member,
            Some(-1), // Expired 1 day ago
        );

        assert!(invitation.is_expired());
        invitation.mark_expired();
        assert_eq!(invitation.status, InvitationStatus::Expired);
    }
}
