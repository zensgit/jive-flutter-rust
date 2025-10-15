//! Family Repository - Family 数据访问层
//! 
//! 提供 Family 相关的数据库操作

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::domain::{
    Family, FamilyMembership, FamilyRole, FamilyInvitation,
    Permission, InvitationStatus, FamilyAuditLog, FamilySettings, AuditAction
};
use crate::error::{JiveError, Result};

/// Family 仓储接口
#[async_trait]
pub trait FamilyRepository: Send + Sync {
    // Family CRUD
    async fn create_family(&self, family: &Family) -> Result<Family>;
    async fn get_family(&self, family_id: &str) -> Result<Family>;
    async fn update_family(&self, family: &Family) -> Result<Family>;
    async fn delete_family(&self, family_id: &str) -> Result<()>;
    async fn list_user_families(&self, user_id: &str) -> Result<Vec<Family>>;
    
    // Membership 管理
    async fn create_membership(&self, membership: &FamilyMembership) -> Result<FamilyMembership>;
    async fn get_membership(&self, membership_id: &str) -> Result<FamilyMembership>;
    async fn get_membership_by_user(&self, user_id: &str, family_id: &str) -> Result<FamilyMembership>;
    async fn update_membership(&self, membership: &FamilyMembership) -> Result<FamilyMembership>;
    async fn delete_membership(&self, membership_id: &str) -> Result<()>;
    async fn list_family_members(&self, family_id: &str) -> Result<Vec<FamilyMembership>>;
    
    // Invitation 管理
    async fn create_invitation(&self, invitation: &FamilyInvitation) -> Result<FamilyInvitation>;
    async fn get_invitation(&self, invitation_id: &str) -> Result<FamilyInvitation>;
    async fn get_invitation_by_token(&self, token: &str) -> Result<FamilyInvitation>;
    async fn update_invitation(&self, invitation: &FamilyInvitation) -> Result<FamilyInvitation>;
    async fn list_pending_invitations(&self, family_id: &str) -> Result<Vec<FamilyInvitation>>;
    
    // Audit 日志
    async fn create_audit_log(&self, log: &FamilyAuditLog) -> Result<()>;
    async fn list_audit_logs(&self, family_id: &str, limit: i32) -> Result<Vec<FamilyAuditLog>>;
    
    // 辅助查询
    async fn is_member(&self, user_id: &str, family_id: &str) -> Result<bool>;
    async fn get_user_permissions(&self, user_id: &str, family_id: &str) -> Result<Vec<Permission>>;
    async fn count_family_members(&self, family_id: &str) -> Result<i64>;
}

/// PostgreSQL 实现
pub struct PgFamilyRepository {
    pool: PgPool,
}

impl PgFamilyRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    /// 将权限数组转换为字符串数组（用于存储）
    fn permissions_to_strings(permissions: &[Permission]) -> Vec<String> {
        permissions.iter().map(|p| format!("{:?}", p)).collect()
    }

    /// 将字符串数组转换为权限数组（从数据库读取）
    fn strings_to_permissions(strings: &[String]) -> Vec<Permission> {
        strings.iter().filter_map(|s| {
            // 这里需要实现字符串到 Permission 的转换
            serde_json::from_str(&format!("\"{}\"", s)).ok()
        }).collect()
    }

    /// 将角色字符串转换为枚举
    fn string_to_role(s: &str) -> Result<FamilyRole> {
        match s {
            // TitleCase（旧存储）
            "Owner" | "owner" => Ok(FamilyRole::Owner),
            "Admin" | "admin" => Ok(FamilyRole::Admin),
            "Member" | "member" => Ok(FamilyRole::Member),
            "Viewer" | "viewer" => Ok(FamilyRole::Viewer),
            _ => Err(JiveError::InvalidData(format!("Unknown role: {}", s))),
        }
    }

    /// 角色写入数据库使用小写
    fn role_to_db(role: &FamilyRole) -> &'static str {
        match role {
            FamilyRole::Owner => "owner",
            FamilyRole::Admin => "admin",
            FamilyRole::Member => "member",
            FamilyRole::Viewer => "viewer",
        }
    }

    /// 邀请状态从数据库字符串到枚举
    fn invitation_status_from_db(s: &str) -> Result<InvitationStatus> {
        match s {
            "pending" | "Pending" => Ok(InvitationStatus::Pending),
            "accepted" | "Accepted" => Ok(InvitationStatus::Accepted),
            "expired" | "Expired" => Ok(InvitationStatus::Expired),
            // DB 使用 cancelled，领域模型为 Declined
            "cancelled" | "Cancelled" | "declined" | "Declined" => Ok(InvitationStatus::Declined),
            _ => Err(JiveError::InvalidData(format!("Unknown invitation status: {}", s))),
        }
    }

    /// 邀请状态写入数据库使用小写字符串
    fn invitation_status_to_db(status: &InvitationStatus) -> &'static str {
        match status {
            InvitationStatus::Pending => "pending",
            InvitationStatus::Accepted => "accepted",
            InvitationStatus::Declined => "cancelled",
            InvitationStatus::Expired => "expired",
        }
    }

    /// 审计动作从字符串到枚举（与 Debug 名称保持一致）
    fn string_to_audit_action(s: &str) -> Result<AuditAction> {
        match s {
            // 成员管理
            "MemberInvited" => Ok(AuditAction::MemberInvited),
            "MemberJoined" => Ok(AuditAction::MemberJoined),
            "MemberRemoved" => Ok(AuditAction::MemberRemoved),
            "MemberRoleChanged" => Ok(AuditAction::MemberRoleChanged),
            // 数据操作
            "DataCreated" => Ok(AuditAction::DataCreated),
            "DataUpdated" => Ok(AuditAction::DataUpdated),
            "DataDeleted" => Ok(AuditAction::DataDeleted),
            "DataImported" => Ok(AuditAction::DataImported),
            "DataExported" => Ok(AuditAction::DataExported),
            // 设置变更
            "SettingsUpdated" => Ok(AuditAction::SettingsUpdated),
            "PermissionsChanged" => Ok(AuditAction::PermissionsChanged),
            // 安全事件
            "LoginAttempt" => Ok(AuditAction::LoginAttempt),
            "LoginSuccess" => Ok(AuditAction::LoginSuccess),
            "LoginFailed" => Ok(AuditAction::LoginFailed),
            "PasswordChanged" => Ok(AuditAction::PasswordChanged),
            "MfaEnabled" => Ok(AuditAction::MfaEnabled),
            "MfaDisabled" => Ok(AuditAction::MfaDisabled),
            // 集成
            "IntegrationConnected" => Ok(AuditAction::IntegrationConnected),
            "IntegrationDisconnected" => Ok(AuditAction::IntegrationDisconnected),
            "IntegrationSynced" => Ok(AuditAction::IntegrationSynced),
            _ => Err(JiveError::InvalidData(format!("Unknown audit action: {}", s))),
        }
    }
}

#[async_trait]
impl FamilyRepository for PgFamilyRepository {
    async fn create_family(&self, family: &Family) -> Result<Family> {
        let settings_json = serde_json::to_value(&family.settings)?;
        
        let row = sqlx::query(
            r#"
            INSERT INTO families (
                id, name, currency, timezone, locale, date_format,
                settings, created_at, updated_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *
            "#
        )
        .bind(&family.id)
        .bind(&family.name)
        .bind(&family.currency)
        .bind(&family.timezone)
        .bind(&family.locale)
        .bind(&family.date_format)
        .bind(&settings_json)
        .bind(&family.created_at)
        .bind(&family.updated_at)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        Ok(Family {
            id: row.get("id"),
            name: row.get("name"),
            currency: row.get("currency"),
            timezone: row.get("timezone"),
            locale: row.get("locale"),
            date_format: row.get("date_format"),
            settings: serde_json::from_value(row.get("settings"))?,
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
            deleted_at: row.get("deleted_at"),
        })
    }

    async fn get_family(&self, family_id: &str) -> Result<Family> {
        let row = sqlx::query(
            r#"
            SELECT * FROM families
            WHERE id = $1 AND deleted_at IS NULL
            "#
        )
        .bind(family_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?
        .ok_or_else(|| JiveError::NotFound(format!("Family {} not found", family_id)))?;

        Ok(Family {
            id: row.get("id"),
            name: row.get("name"),
            currency: row.get("currency"),
            timezone: row.get("timezone"),
            locale: row.get("locale"),
            date_format: row.get("date_format"),
            settings: serde_json::from_value(row.get("settings"))?,
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
            deleted_at: row.get("deleted_at"),
        })
    }

    async fn update_family(&self, family: &Family) -> Result<Family> {
        let settings_json = serde_json::to_value(&family.settings)?;
        
        let row = sqlx::query(
            r#"
            UPDATE families
            SET name = $2, currency = $3, timezone = $4, locale = $5,
                date_format = $6, settings = $7, updated_at = $8
            WHERE id = $1 AND deleted_at IS NULL
            RETURNING *
            "#
        )
        .bind(&family.id)
        .bind(&family.name)
        .bind(&family.currency)
        .bind(&family.timezone)
        .bind(&family.locale)
        .bind(&family.date_format)
        .bind(&settings_json)
        .bind(&Utc::now())
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?
        .ok_or_else(|| JiveError::NotFound(format!("Family {} not found", family.id)))?;

        Ok(Family {
            id: row.get("id"),
            name: row.get("name"),
            currency: row.get("currency"),
            timezone: row.get("timezone"),
            locale: row.get("locale"),
            date_format: row.get("date_format"),
            settings: serde_json::from_value(row.get("settings"))?,
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
            deleted_at: row.get("deleted_at"),
        })
    }

    async fn delete_family(&self, family_id: &str) -> Result<()> {
        // 软删除
        sqlx::query(
            r#"
            UPDATE families
            SET deleted_at = $2
            WHERE id = $1 AND deleted_at IS NULL
            "#
        )
        .bind(family_id)
        .bind(&Utc::now())
        .execute(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    async fn list_user_families(&self, user_id: &str) -> Result<Vec<Family>> {
        let rows = sqlx::query(
            r#"
            SELECT f.* FROM families f
            INNER JOIN family_memberships fm ON f.id = fm.family_id
            WHERE fm.user_id = $1 AND fm.is_active = true
            AND f.deleted_at IS NULL
            ORDER BY fm.last_accessed_at DESC NULLS LAST
            "#
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        let families = rows.into_iter().map(|row| {
            Ok(Family {
                id: row.get("id"),
                name: row.get("name"),
                currency: row.get("currency"),
                timezone: row.get("timezone"),
                locale: row.get("locale"),
                date_format: row.get("date_format"),
                settings: serde_json::from_value(row.get("settings"))?,
                created_at: row.get("created_at"),
                updated_at: row.get("updated_at"),
                deleted_at: row.get("deleted_at"),
            })
        }).collect::<Result<Vec<_>>>()?;

        Ok(families)
    }

    async fn create_membership(&self, membership: &FamilyMembership) -> Result<FamilyMembership> {
        let permissions_strings = Self::permissions_to_strings(&membership.permissions);
        
        let row = sqlx::query(
            r#"
            INSERT INTO family_memberships (
                id, family_id, user_id, role, permissions,
                joined_at, invited_by, is_active, last_accessed_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            ON CONFLICT (family_id, user_id) DO UPDATE
            SET role = EXCLUDED.role,
                permissions = EXCLUDED.permissions,
                is_active = EXCLUDED.is_active,
                last_accessed_at = EXCLUDED.last_accessed_at
            RETURNING *
            "#
        )
        .bind(&membership.id)
        .bind(&membership.family_id)
        .bind(&membership.user_id)
        .bind(Self::role_to_db(&membership.role))
        .bind(&permissions_strings)
        .bind(&membership.joined_at)
        .bind(&membership.invited_by)
        .bind(&membership.is_active)
        .bind(&membership.last_accessed_at)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        Ok(FamilyMembership {
            id: row.get("id"),
            family_id: row.get("family_id"),
            user_id: row.get("user_id"),
            role: Self::string_to_role(row.get("role"))?,
            permissions: Self::strings_to_permissions(&row.get::<Vec<String>, _>("permissions")),
            joined_at: row.get("joined_at"),
            invited_by: row.get("invited_by"),
            is_active: row.get("is_active"),
            last_accessed_at: row.get("last_accessed_at"),
        })
    }

    async fn get_membership(&self, membership_id: &str) -> Result<FamilyMembership> {
        let row = sqlx::query(
            r#"
            SELECT * FROM family_memberships
            WHERE id = $1 AND is_active = true
            "#
        )
        .bind(membership_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?
        .ok_or_else(|| JiveError::NotFound(format!("Membership {} not found", membership_id)))?;

        Ok(FamilyMembership {
            id: row.get("id"),
            family_id: row.get("family_id"),
            user_id: row.get("user_id"),
            role: Self::string_to_role(row.get("role"))?,
            permissions: Self::strings_to_permissions(&row.get::<Vec<String>, _>("permissions")),
            joined_at: row.get("joined_at"),
            invited_by: row.get("invited_by"),
            is_active: row.get("is_active"),
            last_accessed_at: row.get("last_accessed_at"),
        })
    }

    async fn get_membership_by_user(&self, user_id: &str, family_id: &str) -> Result<FamilyMembership> {
        let row = sqlx::query(
            r#"
            SELECT * FROM family_memberships
            WHERE user_id = $1 AND family_id = $2 AND is_active = true
            "#
        )
        .bind(user_id)
        .bind(family_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?
        .ok_or_else(|| JiveError::NotFound(format!("Membership not found for user {} in family {}", user_id, family_id)))?;

        Ok(FamilyMembership {
            id: row.get("id"),
            family_id: row.get("family_id"),
            user_id: row.get("user_id"),
            role: Self::string_to_role(row.get("role"))?,
            permissions: Self::strings_to_permissions(&row.get::<Vec<String>, _>("permissions")),
            joined_at: row.get("joined_at"),
            invited_by: row.get("invited_by"),
            is_active: row.get("is_active"),
            last_accessed_at: row.get("last_accessed_at"),
        })
    }

    async fn update_membership(&self, membership: &FamilyMembership) -> Result<FamilyMembership> {
        let permissions_strings = Self::permissions_to_strings(&membership.permissions);
        
        let row = sqlx::query(
            r#"
            UPDATE family_memberships
            SET role = $3, permissions = $4, last_accessed_at = $5
            WHERE id = $1 AND is_active = $2
            RETURNING *
            "#
        )
        .bind(&membership.id)
        .bind(&membership.is_active)
        .bind(Self::role_to_db(&membership.role))
        .bind(&permissions_strings)
        .bind(&membership.last_accessed_at)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?
        .ok_or_else(|| JiveError::NotFound(format!("Membership {} not found", membership.id)))?;

        Ok(FamilyMembership {
            id: row.get("id"),
            family_id: row.get("family_id"),
            user_id: row.get("user_id"),
            role: Self::string_to_role(row.get("role"))?,
            permissions: Self::strings_to_permissions(&row.get::<Vec<String>, _>("permissions")),
            joined_at: row.get("joined_at"),
            invited_by: row.get("invited_by"),
            is_active: row.get("is_active"),
            last_accessed_at: row.get("last_accessed_at"),
        })
    }

    async fn delete_membership(&self, membership_id: &str) -> Result<()> {
        // 软删除（标记为不活跃）
        sqlx::query(
            r#"
            UPDATE family_memberships
            SET is_active = false
            WHERE id = $1
            "#
        )
        .bind(membership_id)
        .execute(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    async fn list_family_members(&self, family_id: &str) -> Result<Vec<FamilyMembership>> {
        let rows = sqlx::query(
            r#"
            SELECT * FROM family_memberships
            WHERE family_id = $1 AND is_active = true
            ORDER BY joined_at ASC
            "#
        )
        .bind(family_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        let members = rows.into_iter().map(|row| {
            Ok(FamilyMembership {
                id: row.get("id"),
                family_id: row.get("family_id"),
                user_id: row.get("user_id"),
                role: Self::string_to_role(row.get("role"))?,
                permissions: Self::strings_to_permissions(&row.get::<Vec<String>, _>("permissions")),
                joined_at: row.get("joined_at"),
                invited_by: row.get("invited_by"),
                is_active: row.get("is_active"),
                last_accessed_at: row.get("last_accessed_at"),
            })
        }).collect::<Result<Vec<_>>>()?;

        Ok(members)
    }

    async fn create_invitation(&self, invitation: &FamilyInvitation) -> Result<FamilyInvitation> {
        // 对齐 jive-api/migrations/007_enhance_family_system.sql 的 invitations 表
        // 将无连字符 token 解析为 UUID 存入 invite_token
        let token_uuid = Uuid::parse_str(&invitation.token)
            .map_err(|e| JiveError::InvalidData(format!("Invalid invitation token: {}", e)))?;

        sqlx::query(
            r#"
            INSERT INTO invitations (
                id, family_id, inviter_id, invitee_email, role,
                invite_token, status, expires_at, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            "#
        )
        .bind(&invitation.id)
        .bind(&invitation.family_id)
        .bind(&invitation.inviter_id)
        .bind(&invitation.invitee_email)
        .bind(Self::role_to_db(&invitation.role))
        .bind(&token_uuid)
        .bind(Self::invitation_status_to_db(&invitation.status))
        .bind(&invitation.expires_at)
        .bind(&invitation.created_at)
        .execute(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        Ok(invitation.clone())
    }

    async fn get_invitation(&self, invitation_id: &str) -> Result<FamilyInvitation> {
        let row = sqlx::query(
            r#"
            SELECT * FROM invitations
            WHERE id = $1
            "#
        )
        .bind(invitation_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?
        .ok_or_else(|| JiveError::NotFound(format!("Invitation {} not found", invitation_id)))?;

        let role_str: String = row.get("role");
        let status_str: String = row.get("status");
        let token_uuid: Uuid = row.get("invite_token");
        let token_clean = token_uuid.to_string().replace('-', "");

        Ok(FamilyInvitation {
            id: row.get("id"),
            family_id: row.get("family_id"),
            inviter_id: row.get("inviter_id"),
            invitee_email: row.get("invitee_email"),
            role: Self::string_to_role(&role_str)?,
            custom_permissions: None,
            token: token_clean,
            status: Self::invitation_status_from_db(&status_str)?,
            expires_at: row.get("expires_at"),
            created_at: row.get("created_at"),
            accepted_at: row.get("accepted_at"),
        })
    }

    async fn get_invitation_by_token(&self, token: &str) -> Result<FamilyInvitation> {
        let row = sqlx::query(
            r#"
            SELECT * FROM invitations
            WHERE invite_token = $1
            "#
        )
        .bind(token)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?
        .ok_or_else(|| JiveError::NotFound(format!("Invitation with token {} not found", token)))?;

        let role_str: String = row.get("role");
        let status_str: String = row.get("status");
        let token_uuid: Uuid = row.get("invite_token");
        let token_clean = token_uuid.to_string().replace('-', "");

        Ok(FamilyInvitation {
            id: row.get("id"),
            family_id: row.get("family_id"),
            inviter_id: row.get("inviter_id"),
            invitee_email: row.get("invitee_email"),
            role: Self::string_to_role(&role_str)?,
            custom_permissions: None,
            token: token_clean,
            status: Self::invitation_status_from_db(&status_str)?,
            expires_at: row.get("expires_at"),
            created_at: row.get("created_at"),
            accepted_at: row.get("accepted_at"),
        })
    }

    async fn update_invitation(&self, invitation: &FamilyInvitation) -> Result<FamilyInvitation> {
        sqlx::query(
            r#"
            UPDATE invitations
            SET status = $2, accepted_at = $3
            WHERE id = $1
            "#
        )
        .bind(&invitation.id)
        .bind(Self::invitation_status_to_db(&invitation.status))
        .bind(&invitation.accepted_at)
        .execute(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        Ok(invitation.clone())
    }

    async fn list_pending_invitations(&self, family_id: &str) -> Result<Vec<FamilyInvitation>> {
        let rows = sqlx::query(
            r#"
            SELECT * FROM invitations
            WHERE family_id = $1 AND status = 'pending'
              AND expires_at > $2
            ORDER BY created_at DESC
            "#
        )
        .bind(family_id)
        .bind(&Utc::now())
        .fetch_all(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        let invitations = rows
            .into_iter()
            .map(|row| {
                let role_str: String = row.get("role");
                let status_str: String = row.get("status");
                let token_uuid: Uuid = row.get("invite_token");
                let token_clean = token_uuid.to_string().replace('-', "");
                Ok(FamilyInvitation {
                    id: row.get("id"),
                    family_id: row.get("family_id"),
                    inviter_id: row.get("inviter_id"),
                    invitee_email: row.get("invitee_email"),
                    role: Self::string_to_role(&role_str)?,
                    custom_permissions: None,
                    token: token_clean,
                    status: Self::invitation_status_from_db(&status_str)?,
                    expires_at: row.get("expires_at"),
                    created_at: row.get("created_at"),
                    accepted_at: row.get("accepted_at"),
                })
            })
            .collect::<Result<Vec<_>>>()?;

        Ok(invitations)
    }

    async fn create_audit_log(&self, log: &FamilyAuditLog) -> Result<()> {
        sqlx::query(
            r#"
            INSERT INTO family_audit_logs (
                id, family_id, user_id, action, entity_type,
                entity_id, old_values, new_values, ip_address, user_agent, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            "#
        )
        .bind(&log.id)
        .bind(&log.family_id)
        .bind(&log.user_id)
        .bind(format!("{:?}", log.action))
        .bind(&log.resource_type)
        .bind(&log.resource_id)
        .bind(&serde_json::Value::Null) // old_values 暂时置空
        .bind(&log.changes) // new_values 对应 domain 的 changes
        .bind(&log.ip_address)
        .bind(&log.user_agent)
        .bind(&log.created_at)
        .execute(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        Ok(())
    }

    async fn list_audit_logs(&self, family_id: &str, limit: i32) -> Result<Vec<FamilyAuditLog>> {
        let rows = sqlx::query(
            r#"
            SELECT 
                id, family_id, user_id, action,
                entity_type, entity_id, new_values, ip_address, user_agent, created_at
            FROM family_audit_logs
            WHERE family_id = $1
            ORDER BY created_at DESC
            LIMIT $2
            "#
        )
        .bind(family_id)
        .bind(limit)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        let logs = rows
            .into_iter()
            .map(|row| {
                let action_str: String = row.get("action");
                Ok(FamilyAuditLog {
                    id: row.get("id"),
                    family_id: row.get("family_id"),
                    user_id: row.get("user_id"),
                    action: Self::string_to_audit_action(&action_str)?,
                    resource_type: row.get("entity_type"),
                    resource_id: row.get("entity_id"),
                    changes: row.get("new_values"),
                    ip_address: row.get("ip_address"),
                    user_agent: row.get("user_agent"),
                    created_at: row.get("created_at"),
                })
            })
            .collect::<Result<Vec<_>>>()?;

        Ok(logs)
    }

    async fn is_member(&self, user_id: &str, family_id: &str) -> Result<bool> {
        let count: i64 = sqlx::query_scalar(
            r#"
            SELECT COUNT(*) FROM family_memberships
            WHERE user_id = $1 AND family_id = $2 AND is_active = true
            "#
        )
        .bind(user_id)
        .bind(family_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        Ok(count > 0)
    }

    async fn get_user_permissions(&self, user_id: &str, family_id: &str) -> Result<Vec<Permission>> {
        let membership = self.get_membership_by_user(user_id, family_id).await?;
        Ok(membership.permissions)
    }

    async fn count_family_members(&self, family_id: &str) -> Result<i64> {
        let count: i64 = sqlx::query_scalar(
            r#"
            SELECT COUNT(*) FROM family_memberships
            WHERE family_id = $1 AND is_active = true
            "#
        )
        .bind(family_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        Ok(count)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_permissions_conversion() {
        let permissions = vec![
            Permission::ViewTransactions,
            Permission::CreateTransactions,
            Permission::EditTransactions,
        ];

        let strings = PgFamilyRepository::permissions_to_strings(&permissions);
        assert_eq!(strings.len(), 3);
        assert!(strings.contains(&"ViewTransactions".to_string()));
    }

    #[test]
    fn test_role_conversion() {
        assert_eq!(PgFamilyRepository::string_to_role("Owner").unwrap(), FamilyRole::Owner);
        assert_eq!(PgFamilyRepository::string_to_role("owner").unwrap(), FamilyRole::Owner);
        assert_eq!(PgFamilyRepository::string_to_role("Admin").unwrap(), FamilyRole::Admin);
        assert_eq!(PgFamilyRepository::string_to_role("admin").unwrap(), FamilyRole::Admin);
        assert_eq!(PgFamilyRepository::role_to_db(&FamilyRole::Owner), "owner");
        assert_eq!(PgFamilyRepository::role_to_db(&FamilyRole::Viewer), "viewer");
        assert!(PgFamilyRepository::string_to_role("Invalid").is_err());
    }

    #[test]
    fn test_invitation_status_mapping() {
        assert!(matches!(PgFamilyRepository::invitation_status_from_db("pending").unwrap(), InvitationStatus::Pending));
        assert!(matches!(PgFamilyRepository::invitation_status_from_db("accepted").unwrap(), InvitationStatus::Accepted));
        assert!(matches!(PgFamilyRepository::invitation_status_from_db("expired").unwrap(), InvitationStatus::Expired));
        assert!(matches!(PgFamilyRepository::invitation_status_from_db("cancelled").unwrap(), InvitationStatus::Declined));
        assert_eq!(PgFamilyRepository::invitation_status_to_db(&InvitationStatus::Declined), "cancelled");
    }

    #[test]
    fn test_audit_action_mapping() {
        assert!(matches!(PgFamilyRepository::string_to_audit_action("MemberInvited").unwrap(), AuditAction::MemberInvited));
        assert!(PgFamilyRepository::string_to_audit_action("Unknown").is_err());
    }
}
