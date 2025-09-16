use chrono::{Duration, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::models::{
    invitation::{CreateInvitationRequest, Invitation, InvitationResponse},
    permission::Permission,
};

use super::{ServiceContext, ServiceError};

pub struct InvitationService {
    pool: PgPool,
}

impl InvitationService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
    
    pub async fn create_invitation(
        &self,
        ctx: &ServiceContext,
        request: CreateInvitationRequest,
    ) -> Result<InvitationResponse, ServiceError> {
        ctx.require_permission(Permission::InviteMembers)?;
        
        // Check if user already invited
        let existing = sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM invitations
                WHERE family_id = $1 AND invitee_email = $2 AND status = 'pending'
            )
            "#
        )
        .bind(ctx.family_id)
        .bind(&request.invitee_email)
        .fetch_one(&self.pool)
        .await?;
        
        if existing {
            return Err(ServiceError::Conflict("User already invited".to_string()));
        }
        
        // Create invitation
        let expires_at = Utc::now() + Duration::days(request.expires_in_days.unwrap_or(7));
        let invite_code = Invitation::generate_invite_code();
        let invite_token = Uuid::new_v4();
        
        let invitation = sqlx::query_as::<_, Invitation>(
            r#"
            INSERT INTO invitations (
                id, family_id, inviter_id, invitee_email, role, 
                invite_code, invite_token, expires_at, status, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'pending', $9)
            RETURNING *
            "#
        )
        .bind(Uuid::new_v4())
        .bind(ctx.family_id)
        .bind(ctx.user_id)
        .bind(&request.invitee_email)
        .bind(request.role.to_string())
        .bind(&invite_code)
        .bind(invite_token)
        .bind(expires_at)
        .bind(Utc::now())
        .fetch_one(&self.pool)
        .await?;
        
        // Get family name for response
        let family_name = sqlx::query_scalar::<_, String>(
            "SELECT name FROM families WHERE id = $1"
        )
        .bind(ctx.family_id)
        .fetch_one(&self.pool)
        .await?;
        
        Ok(InvitationResponse {
            id: invitation.id,
            family_id: invitation.family_id,
            family_name,
            inviter_name: ctx.user_name.clone(),
            invitee_email: invitation.invitee_email,
            role: invitation.role,
            invite_code: invitation.invite_code,
            invite_link: format!("/invite/{}", invitation.invite_token),
            expires_at: invitation.expires_at,
            status: invitation.status,
        })
    }
    
    pub async fn accept_invitation(
        &self,
        invite_code: Option<String>,
        invite_token: Option<Uuid>,
        user_id: Uuid,
    ) -> Result<Uuid, ServiceError> {
        if invite_code.is_none() && invite_token.is_none() {
            return Err(ServiceError::ValidationError(
                "Either invite_code or invite_token required".to_string()
            ));
        }
        
        let mut tx = self.pool.begin().await?;
        
        // Find and validate invitation
        let invitation = if let Some(code) = invite_code {
            sqlx::query_as::<_, Invitation>(
                r#"
                SELECT * FROM invitations
                WHERE invite_code = $1 AND status = 'pending'
                FOR UPDATE
                "#
            )
            .bind(code)
            .fetch_optional(&mut *tx)
            .await?
        } else if let Some(token) = invite_token {
            sqlx::query_as::<_, Invitation>(
                r#"
                SELECT * FROM invitations
                WHERE invite_token = $1 AND status = 'pending'
                FOR UPDATE
                "#
            )
            .bind(token)
            .fetch_optional(&mut *tx)
            .await?
        } else {
            None
        };
        
        let invitation = invitation.ok_or(ServiceError::InvalidInvitation)?;
        
        // Check expiration
        if invitation.expires_at < Utc::now() {
            // Update status to expired
            sqlx::query(
                "UPDATE invitations SET status = 'expired' WHERE id = $1"
            )
            .bind(invitation.id)
            .execute(&mut *tx)
            .await?;
            
            return Err(ServiceError::InvitationExpired);
        }
        
        // Check if user already member
        let is_member = sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM family_members
                WHERE family_id = $1 AND user_id = $2
            )
            "#
        )
        .bind(invitation.family_id)
        .bind(user_id)
        .fetch_one(&mut *tx)
        .await?;
        
        if is_member {
            return Err(ServiceError::MemberAlreadyExists);
        }
        
        // Accept invitation
        sqlx::query(
            r#"
            UPDATE invitations 
            SET status = 'accepted', accepted_at = $1, accepted_by = $2
            WHERE id = $3
            "#
        )
        .bind(Utc::now())
        .bind(user_id)
        .bind(invitation.id)
        .execute(&mut *tx)
        .await?;
        
        // Add member
        let permissions = invitation.role.default_permissions();
        let permissions_json = serde_json::to_value(&permissions)?;
        
        sqlx::query(
            r#"
            INSERT INTO family_members (
                family_id, user_id, role, permissions, invited_by, is_active, joined_at
            )
            VALUES ($1, $2, $3, $4, $5, true, $6)
            "#
        )
        .bind(invitation.family_id)
        .bind(user_id)
        .bind(invitation.role.to_string())
        .bind(permissions_json)
        .bind(invitation.inviter_id)
        .bind(Utc::now())
        .execute(&mut *tx)
        .await?;
        
        // Update user's current family if they don't have one
        sqlx::query(
            r#"
            UPDATE users
            SET current_family_id = $1
            WHERE id = $2 AND current_family_id IS NULL
            "#
        )
        .bind(invitation.family_id)
        .bind(user_id)
        .execute(&mut *tx)
        .await?;
        
        tx.commit().await?;
        
        Ok(invitation.family_id)
    }
    
    pub async fn cancel_invitation(
        &self,
        ctx: &ServiceContext,
        invitation_id: Uuid,
    ) -> Result<(), ServiceError> {
        ctx.require_permission(Permission::InviteMembers)?;
        
        let result = sqlx::query(
            r#"
            UPDATE invitations
            SET status = 'cancelled'
            WHERE id = $1 AND family_id = $2 AND status = 'pending'
            "#
        )
        .bind(invitation_id)
        .bind(ctx.family_id)
        .execute(&self.pool)
        .await?;
        
        if result.rows_affected() == 0 {
            return Err(ServiceError::not_found("Invitation", invitation_id));
        }
        
        Ok(())
    }
    
    pub async fn get_pending_invitations(
        &self,
        ctx: &ServiceContext,
    ) -> Result<Vec<InvitationResponse>, ServiceError> {
        ctx.require_permission(Permission::ViewMembers)?;
        
        let invitations = sqlx::query_as::<_, InvitationResponse>(
            r#"
            SELECT 
                i.id,
                i.family_id,
                f.name as family_name,
                u.name as inviter_name,
                i.invitee_email,
                i.role,
                i.invite_code,
                i.invite_token as invite_link,
                i.expires_at,
                i.status
            FROM invitations i
            JOIN families f ON i.family_id = f.id
            LEFT JOIN users u ON i.inviter_id = u.id
            WHERE i.family_id = $1 AND i.status = 'pending'
            ORDER BY i.created_at DESC
            "#
        )
        .bind(ctx.family_id)
        .fetch_all(&self.pool)
        .await?;
        
        Ok(invitations)
    }
    
    pub async fn validate_invite_code(
        &self,
        code: &str,
    ) -> Result<InvitationResponse, ServiceError> {
        let invitation = sqlx::query_as::<_, InvitationResponse>(
            r#"
            SELECT 
                i.id,
                i.family_id,
                f.name as family_name,
                u.name as inviter_name,
                i.invitee_email,
                i.role,
                i.invite_code,
                i.invite_token as invite_link,
                i.expires_at,
                i.status
            FROM invitations i
            JOIN families f ON i.family_id = f.id
            LEFT JOIN users u ON i.inviter_id = u.id
            WHERE i.invite_code = $1 AND i.status = 'pending'
            "#
        )
        .bind(code)
        .fetch_optional(&self.pool)
        .await?
        .ok_or(ServiceError::InvalidInvitation)?;
        
        if invitation.expires_at < Utc::now() {
            return Err(ServiceError::InvitationExpired);
        }
        
        Ok(invitation)
    }
    
    pub async fn cleanup_expired(&self) -> Result<u64, ServiceError> {
        let result = sqlx::query(
            r#"
            UPDATE invitations
            SET status = 'expired'
            WHERE status = 'pending' AND expires_at < $1
            "#
        )
        .bind(Utc::now())
        .execute(&self.pool)
        .await?;
        
        Ok(result.rows_affected())
    }
}