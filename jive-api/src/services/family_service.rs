use chrono::Utc;
use sqlx::PgPool;
use uuid::Uuid;

use crate::models::{
    family::{CreateFamilyRequest, Family, UpdateFamilyRequest},
    permission::{MemberRole, Permission},
};

use super::{ServiceContext, ServiceError};

pub struct FamilyService {
    pool: PgPool,
}

impl FamilyService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
    
    pub async fn create_family(
        &self,
        user_id: Uuid,
        request: CreateFamilyRequest,
    ) -> Result<Family, ServiceError> {
        let mut tx = self.pool.begin().await?;
        
        // Create family
        let family_id = Uuid::new_v4();
        let invite_code = Family::generate_invite_code();
        
        let family = sqlx::query_as::<_, Family>(
            r#"
            INSERT INTO families (id, name, owner_id, invite_code, currency, timezone, locale, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            RETURNING *
            "#
        )
        .bind(family_id)
        .bind(&request.name)
        .bind(user_id)
        .bind(&invite_code)
        .bind(request.currency.as_deref().unwrap_or("CNY"))
        .bind(request.timezone.as_deref().unwrap_or("Asia/Shanghai"))
        .bind(request.locale.as_deref().unwrap_or("zh-CN"))
        .bind(Utc::now())
        .bind(Utc::now())
        .fetch_one(&mut *tx)
        .await?;
        
        // Create owner membership
        let owner_permissions = MemberRole::Owner.default_permissions();
        let permissions_json = serde_json::to_value(&owner_permissions)?;
        
        sqlx::query(
            r#"
            INSERT INTO family_members (family_id, user_id, role, permissions, is_active, joined_at)
            VALUES ($1, $2, $3, $4, true, $5)
            "#
        )
        .bind(family_id)
        .bind(user_id)
        .bind("owner")
        .bind(permissions_json)
        .bind(Utc::now())
        .execute(&mut *tx)
        .await?;
        
        // Create default ledger
        sqlx::query(
            r#"
            INSERT INTO ledgers (id, family_id, name, currency, created_by, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            "#
        )
        .bind(Uuid::new_v4())
        .bind(family_id)
        .bind("默认账本")
        .bind(request.currency.as_deref().unwrap_or("CNY"))
        .bind(user_id)
        .bind(Utc::now())
        .bind(Utc::now())
        .execute(&mut *tx)
        .await?;
        
        tx.commit().await?;
        
        Ok(family)
    }
    
    pub async fn get_family(
        &self,
        ctx: &ServiceContext,
        family_id: Uuid,
    ) -> Result<Family, ServiceError> {
        ctx.require_permission(Permission::ViewFamilyInfo)?;
        
        let family = sqlx::query_as::<_, Family>(
            "SELECT * FROM families WHERE id = $1"
        )
        .bind(family_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| ServiceError::not_found("Family", family_id))?;
        
        Ok(family)
    }
    
    pub async fn update_family(
        &self,
        ctx: &ServiceContext,
        family_id: Uuid,
        request: UpdateFamilyRequest,
    ) -> Result<Family, ServiceError> {
        ctx.require_permission(Permission::UpdateFamilyInfo)?;
        
        let mut tx = self.pool.begin().await?;
        
        // Build dynamic update query
        let mut query = String::from("UPDATE families SET updated_at = $1");
        let mut bind_idx = 2;
        let mut binds = vec![];
        
        if let Some(name) = &request.name {
            query.push_str(&format!(", name = ${}", bind_idx));
            binds.push(name.clone());
            bind_idx += 1;
        }
        
        if let Some(currency) = &request.currency {
            query.push_str(&format!(", currency = ${}", bind_idx));
            binds.push(currency.clone());
            bind_idx += 1;
        }
        
        if let Some(timezone) = &request.timezone {
            query.push_str(&format!(", timezone = ${}", bind_idx));
            binds.push(timezone.clone());
            bind_idx += 1;
        }
        
        if let Some(locale) = &request.locale {
            query.push_str(&format!(", locale = ${}", bind_idx));
            binds.push(locale.clone());
            bind_idx += 1;
        }
        
        if let Some(date_format) = &request.date_format {
            query.push_str(&format!(", date_format = ${}", bind_idx));
            binds.push(date_format.clone());
            bind_idx += 1;
        }
        
        query.push_str(&format!(" WHERE id = ${} RETURNING *", bind_idx));
        
        // Execute update
        let mut query_builder = sqlx::query_as::<_, Family>(&query)
            .bind(Utc::now())
            .bind(family_id);
        
        for bind in binds {
            query_builder = query_builder.bind(bind);
        }
        
        let family = query_builder
            .fetch_one(&mut *tx)
            .await?;
        
        tx.commit().await?;
        
        Ok(family)
    }
    
    pub async fn delete_family(
        &self,
        ctx: &ServiceContext,
        family_id: Uuid,
    ) -> Result<(), ServiceError> {
        ctx.require_permission(Permission::DeleteFamily)?;
        ctx.require_owner()?;
        
        // Check if user has other families
        let count = sqlx::query_scalar::<_, i64>(
            r#"
            SELECT COUNT(*) FROM family_members
            WHERE user_id = $1 AND family_id != $2 AND is_active = true
            "#
        )
        .bind(ctx.user_id)
        .bind(family_id)
        .fetch_one(&self.pool)
        .await?;
        
        if count == 0 {
            return Err(ServiceError::BusinessRuleViolation(
                "Cannot delete your only family".to_string()
            ));
        }
        
        // Delete family (cascade will handle related records)
        sqlx::query("DELETE FROM families WHERE id = $1")
            .bind(family_id)
            .execute(&self.pool)
            .await?;
        
        Ok(())
    }
    
    pub async fn get_user_families(
        &self,
        user_id: Uuid,
    ) -> Result<Vec<Family>, ServiceError> {
        let families = sqlx::query_as::<_, Family>(
            r#"
            SELECT f.* FROM families f
            JOIN family_members fm ON f.id = fm.family_id
            WHERE fm.user_id = $1 AND fm.is_active = true
            ORDER BY fm.joined_at DESC
            "#
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?;
        
        Ok(families)
    }
    
    pub async fn switch_family(
        &self,
        user_id: Uuid,
        family_id: Uuid,
    ) -> Result<(), ServiceError> {
        // Verify user is member of the family
        let is_member = sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM family_members
                WHERE user_id = $1 AND family_id = $2 AND is_active = true
            )
            "#
        )
        .bind(user_id)
        .bind(family_id)
        .fetch_one(&self.pool)
        .await?;
        
        if !is_member {
            return Err(ServiceError::PermissionDenied);
        }
        
        // Update current family
        sqlx::query(
            "UPDATE users SET current_family_id = $1 WHERE id = $2"
        )
        .bind(family_id)
        .bind(user_id)
        .execute(&self.pool)
        .await?;
        
        Ok(())
    }
    
    pub async fn regenerate_invite_code(
        &self,
        ctx: &ServiceContext,
        family_id: Uuid,
    ) -> Result<String, ServiceError> {
        ctx.require_permission(Permission::InviteMembers)?;
        
        let new_code = Family::generate_invite_code();
        
        sqlx::query(
            "UPDATE families SET invite_code = $1, updated_at = $2 WHERE id = $3"
        )
        .bind(&new_code)
        .bind(Utc::now())
        .bind(family_id)
        .execute(&self.pool)
        .await?;
        
        Ok(new_code)
    }
}