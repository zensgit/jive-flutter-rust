use chrono::Utc;
use sqlx::PgPool;
use uuid::Uuid;

use crate::models::{
    membership::{FamilyMember, MemberWithUserInfo, UpdateMemberRequest},
    permission::{MemberRole, Permission},
};

use super::{ServiceContext, ServiceError};

pub struct MemberService {
    pool: PgPool,
}

impl MemberService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
    
    pub async fn add_member(
        &self,
        ctx: &ServiceContext,
        user_id: Uuid,
        role: MemberRole,
    ) -> Result<FamilyMember, ServiceError> {
        ctx.require_permission(Permission::InviteMembers)?;
        
        // Check if already member
        let exists = sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM family_members
                WHERE family_id = $1 AND user_id = $2
            )
            "#
        )
        .bind(ctx.family_id)
        .bind(user_id)
        .fetch_one(&self.pool)
        .await?;
        
        if exists {
            return Err(ServiceError::MemberAlreadyExists);
        }
        
        // Add member
        let permissions = role.default_permissions();
        let permissions_json = serde_json::to_value(&permissions)?;
        
        let member = sqlx::query_as::<_, FamilyMember>(
            r#"
            INSERT INTO family_members (
                family_id, user_id, role, permissions, invited_by, is_active, joined_at
            )
            VALUES ($1, $2, $3, $4, $5, true, $6)
            RETURNING *
            "#
        )
        .bind(ctx.family_id)
        .bind(user_id)
        .bind(role.to_string())
        .bind(permissions_json)
        .bind(ctx.user_id)
        .bind(Utc::now())
        .fetch_one(&self.pool)
        .await?;
        
        Ok(member)
    }
    
    pub async fn remove_member(
        &self,
        ctx: &ServiceContext,
        user_id: Uuid,
    ) -> Result<(), ServiceError> {
        ctx.require_permission(Permission::RemoveMembers)?;
        
        // Get member info
        let member_role = sqlx::query_scalar::<_, String>(
            "SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2"
        )
        .bind(ctx.family_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| ServiceError::not_found("Member", user_id))?;
        
        // Cannot remove owner
        if member_role == "owner" {
            return Err(ServiceError::CannotRemoveOwner);
        }
        
        // Check if actor can manage this role
        let target_role = MemberRole::from_str(&member_role)
            .ok_or_else(|| ServiceError::ValidationError("Invalid role".to_string()))?;
        
        if !ctx.can_manage_role(target_role) {
            return Err(ServiceError::PermissionDenied);
        }
        
        // Remove member
        sqlx::query(
            "DELETE FROM family_members WHERE family_id = $1 AND user_id = $2"
        )
        .bind(ctx.family_id)
        .bind(user_id)
        .execute(&self.pool)
        .await?;
        
        Ok(())
    }
    
    pub async fn update_member_role(
        &self,
        ctx: &ServiceContext,
        user_id: Uuid,
        new_role: MemberRole,
    ) -> Result<FamilyMember, ServiceError> {
        ctx.require_permission(Permission::UpdateMemberRoles)?;
        
        // Get current role
        let current_role = sqlx::query_scalar::<_, String>(
            "SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2"
        )
        .bind(ctx.family_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| ServiceError::not_found("Member", user_id))?;
        
        // Cannot change owner role
        if current_role == "owner" {
            return Err(ServiceError::CannotChangeOwnerRole);
        }
        
        // Check permissions
        if !ctx.can_manage_role(new_role) {
            return Err(ServiceError::PermissionDenied);
        }
        
        // Update role and permissions
        let permissions = new_role.default_permissions();
        let permissions_json = serde_json::to_value(&permissions)?;
        
        let member = sqlx::query_as::<_, FamilyMember>(
            r#"
            UPDATE family_members
            SET role = $1, permissions = $2
            WHERE family_id = $3 AND user_id = $4
            RETURNING *
            "#
        )
        .bind(new_role.to_string())
        .bind(permissions_json)
        .bind(ctx.family_id)
        .bind(user_id)
        .fetch_one(&self.pool)
        .await?;
        
        Ok(member)
    }
    
    pub async fn update_member_permissions(
        &self,
        ctx: &ServiceContext,
        user_id: Uuid,
        permissions: Vec<Permission>,
    ) -> Result<FamilyMember, ServiceError> {
        ctx.require_permission(Permission::UpdateMemberRoles)?;
        
        // Get member role
        let member_role = sqlx::query_scalar::<_, String>(
            "SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2"
        )
        .bind(ctx.family_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| ServiceError::not_found("Member", user_id))?;
        
        // Cannot change owner permissions
        if member_role == "owner" {
            return Err(ServiceError::BusinessRuleViolation(
                "Owner permissions cannot be customized".to_string()
            ));
        }
        
        // Update permissions
        let permissions_json = serde_json::to_value(&permissions)?;
        
        let member = sqlx::query_as::<_, FamilyMember>(
            r#"
            UPDATE family_members
            SET permissions = $1
            WHERE family_id = $2 AND user_id = $3
            RETURNING *
            "#
        )
        .bind(permissions_json)
        .bind(ctx.family_id)
        .bind(user_id)
        .fetch_one(&self.pool)
        .await?;
        
        Ok(member)
    }
    
    pub async fn get_family_members(
        &self,
        ctx: &ServiceContext,
    ) -> Result<Vec<MemberWithUserInfo>, ServiceError> {
        ctx.require_permission(Permission::ViewMembers)?;
        
        let members = sqlx::query_as::<_, MemberWithUserInfo>(
            r#"
            SELECT 
                fm.family_id,
                fm.user_id,
                u.name as user_name,
                u.email as user_email,
                fm.role,
                fm.permissions,
                fm.is_active,
                fm.joined_at,
                fm.last_active_at
            FROM family_members fm
            JOIN users u ON fm.user_id = u.id
            WHERE fm.family_id = $1
            ORDER BY fm.joined_at
            "#
        )
        .bind(ctx.family_id)
        .fetch_all(&self.pool)
        .await?;
        
        Ok(members)
    }
    
    pub async fn check_permission(
        &self,
        user_id: Uuid,
        family_id: Uuid,
        permission: Permission,
    ) -> Result<bool, ServiceError> {
        let permissions_json = sqlx::query_scalar::<_, serde_json::Value>(
            r#"
            SELECT permissions FROM family_members
            WHERE family_id = $1 AND user_id = $2 AND is_active = true
            "#
        )
        .bind(family_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?;
        
        if let Some(json) = permissions_json {
            let permissions: Vec<Permission> = serde_json::from_value(json)?;
            Ok(permissions.contains(&permission))
        } else {
            Ok(false)
        }
    }
    
    pub async fn get_member_context(
        &self,
        user_id: Uuid,
        family_id: Uuid,
    ) -> Result<ServiceContext, ServiceError> {
        #[derive(sqlx::FromRow)]
        struct MemberContextRow {
            role: String,
            permissions: serde_json::Value,
            email: String,
            name: Option<String>,
        }
        
        let row = sqlx::query_as::<_, MemberContextRow>(
            r#"
            SELECT 
                fm.role,
                fm.permissions,
                u.email,
                u.name
            FROM family_members fm
            JOIN users u ON fm.user_id = u.id
            WHERE fm.family_id = $1 AND fm.user_id = $2 AND fm.is_active = true
            "#
        )
        .bind(family_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or(ServiceError::PermissionDenied)?;
        
        let role = MemberRole::from_str(&row.role)
            .ok_or_else(|| ServiceError::ValidationError("Invalid role".to_string()))?;
        
        let permissions: Vec<Permission> = serde_json::from_value(row.permissions)?;
        
        Ok(ServiceContext::new(
            user_id,
            family_id,
            role,
            permissions,
            row.email,
            row.name,
        ))
    }
}