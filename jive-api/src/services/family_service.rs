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

    /// Create family within an existing transaction (for atomic operations)
    ///
    /// This method accepts a transaction parameter to allow atomic multi-step operations
    /// where family creation is part of a larger transaction (e.g., user registration + family creation).
    ///
    /// # Arguments
    /// * `tx` - Mutable reference to an existing database transaction
    /// * `user_id` - ID of the user creating the family (will become owner)
    /// * `request` - Family creation request with optional name, currency, timezone, locale
    ///
    /// # Returns
    /// Created `Family` instance on success, or `ServiceError` on failure
    ///
    /// # Transaction Safety
    /// This method does NOT commit the transaction. The caller is responsible for:
    /// - Committing the transaction on success
    /// - Rolling back on error
    pub async fn create_family_in_tx(
        &self,
        tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
        user_id: Uuid,
        request: CreateFamilyRequest,
    ) -> Result<Family, ServiceError> {
        // Check if user already owns a family by checking if they are an owner in any family
        let existing_family_count = sqlx::query_scalar::<_, i64>(
            r#"
            SELECT COUNT(*)
            FROM family_members
            WHERE user_id = $1 AND role = 'owner'
            "#,
        )
        .bind(user_id)
        .fetch_one(&mut **tx)
        .await?;

        if existing_family_count > 0 {
            return Err(ServiceError::Conflict(
                "用户已创建家庭，每个用户只能创建一个家庭".to_string(),
            ));
        }

        // Get user's name for default family name
        let user_name: Option<String> =
            sqlx::query_scalar("SELECT COALESCE(full_name, email) FROM users WHERE id = $1")
                .bind(user_id)
                .fetch_one(&mut **tx)
                .await?;

        // Use provided name or default to "用户名的家庭"
        let family_name = if let Some(name) = request.name {
            if name.trim().is_empty() {
                format!("{}的家庭", user_name.unwrap_or_else(|| "我".to_string()))
            } else {
                name
            }
        } else {
            format!("{}的家庭", user_name.unwrap_or_else(|| "我".to_string()))
        };

        // Create family
        tracing::info!(target: "family_service", user_id = %user_id, name = %family_name, "Inserting family with owner_id");
        let family_id = Uuid::new_v4();
        let invite_code = Family::generate_invite_code();

        let family = sqlx::query_as::<_, Family>(
            r#"
            INSERT INTO families (id, name, owner_id, currency, timezone, locale, invite_code, member_count, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, 1, $8, $9)
            RETURNING *
            "#
        )
        .bind(family_id)
        .bind(&family_name)
        .bind(user_id)
        .bind(request.currency.as_deref().unwrap_or("CNY"))
        .bind(request.timezone.as_deref().unwrap_or("Asia/Shanghai"))
        .bind(request.locale.as_deref().unwrap_or("zh-CN"))
        .bind(&invite_code)
        .bind(Utc::now())
        .bind(Utc::now())
        .fetch_one(&mut **tx)
        .await?;

        // Create owner membership
        let owner_permissions = MemberRole::Owner.default_permissions();
        let permissions_json = serde_json::to_value(&owner_permissions)?;

        sqlx::query(
            r#"
            INSERT INTO family_members (family_id, user_id, role, permissions, joined_at)
            VALUES ($1, $2, $3, $4, $5)
            "#,
        )
        .bind(family_id)
        .bind(user_id)
        .bind("owner")
        .bind(permissions_json)
        .bind(Utc::now())
        .execute(&mut **tx)
        .await?;

        // Create default ledger (mark as default and attribute creator)
        sqlx::query(
            r#"
            INSERT INTO ledgers (id, family_id, name, currency, created_by, is_default, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, true, $6, $7)
            "#
        )
        .bind(Uuid::new_v4())
        .bind(family_id)
        .bind("默认账本")
        .bind(request.currency.as_deref().unwrap_or("CNY"))
        .bind(user_id)
        .bind(Utc::now())
        .bind(Utc::now())
        .execute(&mut **tx)
        .await?;

        Ok(family)
    }

    /// Create family (convenience method that opens its own transaction)
    ///
    /// For standalone family creation. If family creation is part of a larger atomic operation,
    /// use `create_family_in_tx()` instead with an existing transaction.
    pub async fn create_family(
        &self,
        user_id: Uuid,
        request: CreateFamilyRequest,
    ) -> Result<Family, ServiceError> {
        let mut tx = self.pool.begin().await?;
        let family = self.create_family_in_tx(&mut tx, user_id, request).await?;
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
            "SELECT * FROM families WHERE id = $1 AND deleted_at IS NULL",
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

        let family = query_builder.fetch_one(&mut *tx).await?;

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

        // Soft delete - just mark as deleted
        sqlx::query("UPDATE families SET deleted_at = $1, updated_at = $1 WHERE id = $2")
            .bind(Utc::now())
            .bind(family_id)
            .execute(&self.pool)
            .await?;

        // Update user's current family if this was their current one
        sqlx::query(
            "UPDATE users SET current_family_id = NULL 
             WHERE current_family_id = $1",
        )
        .bind(family_id)
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    pub async fn get_user_families(&self, user_id: Uuid) -> Result<Vec<Family>, ServiceError> {
        // Only show families that:
        // 1. Have more than 1 member (multi-person families)
        // 2. Or the user is the owner (even if single-person)
        // 3. Not deleted
        let families = sqlx::query_as::<_, Family>(
            r#"
            SELECT f.* FROM families f
            JOIN family_members fm ON f.id = fm.family_id
            WHERE fm.user_id = $1
                AND f.deleted_at IS NULL
                AND (f.member_count > 1 OR fm.role = 'owner')
            ORDER BY fm.joined_at DESC
            "#,
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?;

        Ok(families)
    }

    pub async fn switch_family(&self, user_id: Uuid, family_id: Uuid) -> Result<(), ServiceError> {
        // Verify user is member of the family
        let is_member = sqlx::query_scalar::<_, bool>(
            r#"
            SELECT EXISTS(
                SELECT 1 FROM family_members
                WHERE user_id = $1 AND family_id = $2
            )
            "#,
        )
        .bind(user_id)
        .bind(family_id)
        .fetch_one(&self.pool)
        .await?;

        if !is_member {
            return Err(ServiceError::PermissionDenied);
        }

        // Update current family
        sqlx::query("UPDATE users SET current_family_id = $1 WHERE id = $2")
            .bind(family_id)
            .bind(user_id)
            .execute(&self.pool)
            .await?;

        Ok(())
    }

    pub async fn join_family_by_invite_code(
        &self,
        user_id: Uuid,
        invite_code: String,
    ) -> Result<Family, ServiceError> {
        let mut tx = self.pool.begin().await?;

        // Find family by invite code
        let family = sqlx::query_as::<_, Family>("SELECT * FROM families WHERE invite_code = $1")
            .bind(&invite_code)
            .fetch_optional(&mut *tx)
            .await?
            .ok_or_else(|| ServiceError::InvalidInvitation)?;

        // Check if user is already a member
        let existing_member: Option<i64> = sqlx::query_scalar(
            "SELECT COUNT(*) FROM family_members WHERE family_id = $1 AND user_id = $2",
        )
        .bind(family.id)
        .bind(user_id)
        .fetch_one(&mut *tx)
        .await?;

        if existing_member.unwrap_or(0) > 0 {
            return Err(ServiceError::Conflict("您已经是该家庭的成员".to_string()));
        }

        // Add user as a member
        let member_permissions = MemberRole::Member.default_permissions();
        let permissions_json = serde_json::to_value(&member_permissions)?;

        sqlx::query(
            r#"
            INSERT INTO family_members (family_id, user_id, role, permissions, joined_at)
            VALUES ($1, $2, $3, $4, $5)
            "#,
        )
        .bind(family.id)
        .bind(user_id)
        .bind("member")
        .bind(permissions_json)
        .bind(Utc::now())
        .execute(&mut *tx)
        .await?;

        // Update member count
        sqlx::query("UPDATE families SET member_count = member_count + 1 WHERE id = $1")
            .bind(family.id)
            .execute(&mut *tx)
            .await?;

        tx.commit().await?;

        Ok(family)
    }

    pub async fn get_family_statistics(
        &self,
        family_id: Uuid,
    ) -> Result<serde_json::Value, ServiceError> {
        // Get member count
        let member_count: i64 =
            sqlx::query_scalar("SELECT COUNT(*) FROM family_members WHERE family_id = $1")
                .bind(family_id)
                .fetch_one(&self.pool)
                .await?;

        // Get ledger count
        let ledger_count: i64 =
            sqlx::query_scalar("SELECT COUNT(*) FROM ledgers WHERE family_id = $1")
                .bind(family_id)
                .fetch_one(&self.pool)
                .await?;

        // Get account count
        let account_count: i64 =
            sqlx::query_scalar("SELECT COUNT(*) FROM accounts WHERE family_id = $1")
                .bind(family_id)
                .fetch_one(&self.pool)
                .await?;

        // Get transaction count
        let transaction_count: i64 =
            sqlx::query_scalar("SELECT COUNT(*) FROM transactions WHERE family_id = $1")
                .bind(family_id)
                .fetch_one(&self.pool)
                .await?;

        // Get total balance
        let total_balance: Option<rust_decimal::Decimal> = sqlx::query_scalar(
            "SELECT SUM(current_balance) FROM accounts a 
             JOIN ledgers l ON a.ledger_id = l.id 
             WHERE l.family_id = $1",
        )
        .bind(family_id)
        .fetch_one(&self.pool)
        .await?;

        Ok(serde_json::json!({
            "member_count": member_count,
            "ledger_count": ledger_count,
            "account_count": account_count,
            "transaction_count": transaction_count,
            "total_balance": total_balance.unwrap_or(rust_decimal::Decimal::ZERO),
        }))
    }

    pub async fn regenerate_invite_code(
        &self,
        ctx: &ServiceContext,
        family_id: Uuid,
    ) -> Result<String, ServiceError> {
        ctx.require_permission(Permission::InviteMembers)?;

        let new_code = Family::generate_invite_code();

        sqlx::query("UPDATE families SET invite_code = $1, updated_at = $2 WHERE id = $3")
            .bind(&new_code)
            .bind(Utc::now())
            .bind(family_id)
            .execute(&self.pool)
            .await?;

        Ok(new_code)
    }

    pub async fn leave_family(&self, user_id: Uuid, family_id: Uuid) -> Result<(), ServiceError> {
        let mut tx = self.pool.begin().await?;

        // Check if user is the owner
        let role: Option<String> = sqlx::query_scalar(
            "SELECT role FROM family_members WHERE family_id = $1 AND user_id = $2",
        )
        .bind(family_id)
        .bind(user_id)
        .fetch_optional(&mut *tx)
        .await?;

        match role.as_deref() {
            Some("owner") => {
                // Owner cannot leave, must transfer ownership or delete family
                Err(ServiceError::BusinessRuleViolation(
                    "家庭所有者不能退出家庭，请先转让所有权或删除家庭".to_string(),
                ))
            }
            Some(_) => {
                // Remove member from family
                sqlx::query("DELETE FROM family_members WHERE family_id = $1 AND user_id = $2")
                    .bind(family_id)
                    .bind(user_id)
                    .execute(&mut *tx)
                    .await?;

                // Update member count
                sqlx::query(
                    "UPDATE families SET member_count = GREATEST(member_count - 1, 0) WHERE id = $1"
                )
                .bind(family_id)
                .execute(&mut *tx)
                .await?;

                // Update user's current family if this was their current one
                sqlx::query(
                    "UPDATE users SET current_family_id = NULL 
                     WHERE id = $1 AND current_family_id = $2",
                )
                .bind(user_id)
                .bind(family_id)
                .execute(&mut *tx)
                .await?;

                tx.commit().await?;
                Ok(())
            }
            None => Err(ServiceError::NotFound {
                resource_type: "FamilyMember".to_string(),
                id: user_id.to_string(),
            }),
        }
    }
}
