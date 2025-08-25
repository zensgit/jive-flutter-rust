//! Family Repository - Family 数据访问层
//! 
//! 提供 Family 相关的数据库操作

use async_trait::async_trait;
use chrono::{DateTime, Utc};
use sqlx::{PgPool, Row};
use uuid::Uuid;

use crate::domain::{
    Family, FamilyMembership, FamilyRole, FamilyInvitation,
    Permission, InvitationStatus, FamilyAuditLog, FamilySettings
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
            "Owner" => Ok(FamilyRole::Owner),
            "Admin" => Ok(FamilyRole::Admin),
            "Member" => Ok(FamilyRole::Member),
            "Viewer" => Ok(FamilyRole::Viewer),
            _ => Err(JiveError::InvalidData(format!("Unknown role: {}", s))),
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
        .bind(format!("{:?}", membership.role))
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
        .bind(format!("{:?}", membership.role))
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
        let custom_perms = invitation.custom_permissions.as_ref()
            .map(|p| Self::permissions_to_strings(p));
        
        let row = sqlx::query(
            r#"
            INSERT INTO family_invitations (
                id, family_id, inviter_id, invitee_email, role,
                custom_permissions, token, status, expires_at, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING *
            "#
        )
        .bind(&invitation.id)
        .bind(&invitation.family_id)
        .bind(&invitation.inviter_id)
        .bind(&invitation.invitee_email)
        .bind(format!("{:?}", invitation.role))
        .bind(&custom_perms)
        .bind(&invitation.token)
        .bind(format!("{:?}", invitation.status))
        .bind(&invitation.expires_at)
        .bind(&invitation.created_at)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        Ok(invitation.clone())
    }

    async fn get_invitation(&self, invitation_id: &str) -> Result<FamilyInvitation> {
        let row = sqlx::query(
            r#"
            SELECT * FROM family_invitations
            WHERE id = $1
            "#
        )
        .bind(invitation_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?
        .ok_or_else(|| JiveError::NotFound(format!("Invitation {} not found", invitation_id)))?;

        // TODO: 从 row 构建 FamilyInvitation
        Err(JiveError::NotImplemented("get_invitation".into()))
    }

    async fn get_invitation_by_token(&self, token: &str) -> Result<FamilyInvitation> {
        let row = sqlx::query(
            r#"
            SELECT * FROM family_invitations
            WHERE token = $1
            "#
        )
        .bind(token)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?
        .ok_or_else(|| JiveError::NotFound(format!("Invitation with token {} not found", token)))?;

        // TODO: 从 row 构建 FamilyInvitation
        Err(JiveError::NotImplemented("get_invitation_by_token".into()))
    }

    async fn update_invitation(&self, invitation: &FamilyInvitation) -> Result<FamilyInvitation> {
        let row = sqlx::query(
            r#"
            UPDATE family_invitations
            SET status = $2, accepted_at = $3
            WHERE id = $1
            RETURNING *
            "#
        )
        .bind(&invitation.id)
        .bind(format!("{:?}", invitation.status))
        .bind(&invitation.accepted_at)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?
        .ok_or_else(|| JiveError::NotFound(format!("Invitation {} not found", invitation.id)))?;

        Ok(invitation.clone())
    }

    async fn list_pending_invitations(&self, family_id: &str) -> Result<Vec<FamilyInvitation>> {
        let rows = sqlx::query(
            r#"
            SELECT * FROM family_invitations
            WHERE family_id = $1 AND status = 'Pending'
            AND expires_at > $2
            ORDER BY created_at DESC
            "#
        )
        .bind(family_id)
        .bind(&Utc::now())
        .fetch_all(&self.pool)
        .await
        .map_err(|e| JiveError::DatabaseError(e.to_string()))?;

        // TODO: 从 rows 构建 Vec<FamilyInvitation>
        Ok(vec![])
    }

    async fn create_audit_log(&self, log: &FamilyAuditLog) -> Result<()> {
        sqlx::query(
            r#"
            INSERT INTO family_audit_logs (
                id, family_id, user_id, action, resource_type,
                resource_id, changes, ip_address, user_agent, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            "#
        )
        .bind(&log.id)
        .bind(&log.family_id)
        .bind(&log.user_id)
        .bind(format!("{:?}", log.action))
        .bind(&log.resource_type)
        .bind(&log.resource_id)
        .bind(&log.changes)
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
            SELECT * FROM family_audit_logs
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

        // TODO: 从 rows 构建 Vec<FamilyAuditLog>
        Ok(vec![])
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
        assert_eq!(
            PgFamilyRepository::string_to_role("Owner").unwrap(),
            FamilyRole::Owner
        );
        assert_eq!(
            PgFamilyRepository::string_to_role("Admin").unwrap(),
            FamilyRole::Admin
        );
        assert!(PgFamilyRepository::string_to_role("Invalid").is_err());
    }
}