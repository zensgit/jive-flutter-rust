use argon2::{
    password_hash::{rand_core::OsRng, SaltString},
    Argon2, PasswordHasher,
};
use chrono::Utc;
use sqlx::PgPool;
use uuid::Uuid;

use crate::models::{family::CreateFamilyRequest, permission::MemberRole};
use crate::utils::password::{generate_argon2_hash, verify_and_maybe_rehash};

use super::{FamilyService, ServiceContext, ServiceError};

#[derive(Debug)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub name: Option<String>,
    pub username: Option<String>,
}

#[derive(Debug)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug)]
pub struct UserContext {
    pub user_id: Uuid,
    pub email: String,
    pub name: Option<String>,
    pub current_family_id: Option<Uuid>,
    pub families: Vec<FamilyInfo>,
}

#[derive(Debug)]
pub struct FamilyInfo {
    pub family_id: Uuid,
    pub family_name: String,
    pub role: MemberRole,
}

pub struct AuthService {
    pool: PgPool,
}

impl AuthService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    /// Register a new user with their personal family in a single atomic transaction
    ///
    /// This method ensures atomicity by executing all operations (user creation, family creation,
    /// membership creation, ledger creation) within a single database transaction. This prevents
    /// "orphan users" if family creation fails.
    ///
    /// # Arguments
    /// * `request` - Registration request containing email, password, optional name and username
    ///
    /// # Returns
    /// `UserContext` with user info and newly created family on success
    ///
    /// # Transaction Safety
    /// All operations are atomic: if any step fails, the entire transaction is rolled back.
    /// This prevents partial registrations where user exists but family creation failed.
    pub async fn register_with_family(
        &self,
        request: RegisterRequest,
    ) -> Result<UserContext, ServiceError> {
        tracing::info!(target: "auth_service", email = %request.email, username = ?request.username, "register_with_family: start");

        // Check if email already exists
        let exists =
            sqlx::query_scalar::<_, bool>("SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)")
                .bind(&request.email)
                .fetch_one(&self.pool)
                .await?;

        if exists {
            return Err(ServiceError::Conflict(
                "Email already registered".to_string(),
            ));
        }

        // If username provided, ensure uniqueness (case-insensitive)
        if let Some(ref username) = request.username {
            let username_exists = sqlx::query_scalar::<_, bool>(
                "SELECT EXISTS(SELECT 1 FROM users WHERE LOWER(username) = LOWER($1))",
            )
            .bind(username)
            .fetch_one(&self.pool)
            .await?;
            if username_exists {
                return Err(ServiceError::Conflict("Username already taken".to_string()));
            }
        }

        // Start single transaction for all operations (atomic)
        let mut tx = self.pool.begin().await?;

        // Hash password
        let password_hash = self.hash_password(&request.password)?;

        // Create user
        let user_id = Uuid::new_v4();
        let user_name = request.name.clone().unwrap_or_else(|| {
            request
                .email
                .split('@')
                .next()
                .unwrap_or("用户")
                .to_string()
        });

        sqlx::query(
            r#"
            INSERT INTO users (id, email, username, name, full_name, password_hash, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            "#
        )
        .bind(user_id)
        .bind(&request.email)
        .bind(&request.username)
        .bind(&user_name)
        .bind(&user_name)
        .bind(&password_hash)
        .bind(Utc::now())
        .bind(Utc::now())
        .execute(&mut *tx)
        .await?;

        tracing::info!(target: "auth_service", user_id = %user_id, "register_with_family: user created in transaction, creating family in same transaction");

        // Create personal family within the same transaction (atomic with user creation)
        let family_service = FamilyService::new(self.pool.clone());
        let family_request = CreateFamilyRequest {
            name: Some(format!("{}的家庭", user_name)),
            currency: Some("CNY".to_string()),
            timezone: Some("Asia/Shanghai".to_string()),
            locale: Some("zh-CN".to_string()),
        };

        // Use transaction-aware family creation method
        let family = family_service
            .create_family_in_tx(&mut tx, user_id, family_request)
            .await?;

        // Update user's current family within same transaction
        sqlx::query("UPDATE users SET current_family_id = $1 WHERE id = $2")
            .bind(family.id)
            .bind(user_id)
            .execute(&mut *tx)
            .await?;

        // Commit all operations atomically
        tx.commit().await?;

        tracing::info!(target: "auth_service", user_id = %user_id, family_id = %family.id, "register_with_family: atomic registration success");
        Ok(UserContext {
            user_id,
            email: request.email,
            name: request.name,
            current_family_id: Some(family.id),
            families: vec![FamilyInfo {
                family_id: family.id,
                family_name: family.name,
                role: MemberRole::Owner,
            }],
        })
    }

    pub async fn login(&self, request: LoginRequest) -> Result<UserContext, ServiceError> {
        // Get user
        #[derive(sqlx::FromRow)]
        struct UserRow {
            id: Uuid,
            email: String,
            full_name: Option<String>,
            password_hash: String,
            current_family_id: Option<Uuid>,
        }

        let user = sqlx::query_as::<_, UserRow>(
            r#"
            SELECT id, email, full_name, password_hash, current_family_id
            FROM users
            WHERE email = $1
            "#,
        )
        .bind(&request.email)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| ServiceError::AuthenticationError("Invalid credentials".to_string()))?;

        // Verify password
        self.verify_password(&request.password, &user.password_hash)?;

        // Get user's families
        #[derive(sqlx::FromRow)]
        struct FamilyRow {
            family_id: Uuid,
            family_name: String,
            role: String,
        }

        let families = sqlx::query_as::<_, FamilyRow>(
            r#"
            SELECT 
                f.id as family_id,
                f.name as family_name,
                fm.role
            FROM families f
            JOIN family_members fm ON f.id = fm.family_id
            WHERE fm.user_id = $1
            ORDER BY fm.joined_at DESC
            "#,
        )
        .bind(user.id)
        .fetch_all(&self.pool)
        .await?;

        let family_info: Vec<FamilyInfo> = families
            .into_iter()
            .map(|f| FamilyInfo {
                family_id: f.family_id,
                family_name: f.family_name,
                role: MemberRole::from_str_name(&f.role).unwrap_or(MemberRole::Member),
            })
            .collect();

        Ok(UserContext {
            user_id: user.id,
            email: user.email,
            name: user.full_name,
            current_family_id: user.current_family_id,
            families: family_info,
        })
    }

    pub async fn get_user_context(&self, user_id: Uuid) -> Result<UserContext, ServiceError> {
        #[derive(sqlx::FromRow)]
        struct UserInfoRow {
            id: Uuid,
            email: String,
            full_name: Option<String>,
            current_family_id: Option<Uuid>,
        }

        let user = sqlx::query_as::<_, UserInfoRow>(
            r#"
            SELECT id, email, full_name, current_family_id
            FROM users
            WHERE id = $1
            "#,
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| ServiceError::not_found("User", user_id))?;

        #[derive(sqlx::FromRow)]
        struct FamilyInfoRow {
            family_id: Uuid,
            family_name: String,
            role: String,
        }

        let families = sqlx::query_as::<_, FamilyInfoRow>(
            r#"
            SELECT 
                f.id as family_id,
                f.name as family_name,
                fm.role
            FROM families f
            JOIN family_members fm ON f.id = fm.family_id
            WHERE fm.user_id = $1
            ORDER BY fm.joined_at DESC
            "#,
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await?;

        let family_info: Vec<FamilyInfo> = families
            .into_iter()
            .map(|f| FamilyInfo {
                family_id: f.family_id,
                family_name: f.family_name,
                role: MemberRole::from_str_name(&f.role).unwrap_or(MemberRole::Member),
            })
            .collect();

        Ok(UserContext {
            user_id: user.id,
            email: user.email,
            name: user.full_name,
            current_family_id: user.current_family_id,
            families: family_info,
        })
    }

    pub async fn validate_family_access(
        &self,
        user_id: Uuid,
        family_id: Uuid,
    ) -> Result<ServiceContext, ServiceError> {
        #[derive(sqlx::FromRow)]
        struct AccessRow {
            role: String,
            permissions: serde_json::Value,
            email: String,
            full_name: Option<String>,
        }

        let row = sqlx::query_as::<_, AccessRow>(
            r#"
            SELECT 
                fm.role,
                fm.permissions,
                u.email,
                u.full_name
            FROM family_members fm
            JOIN users u ON fm.user_id = u.id
            WHERE fm.family_id = $1 AND fm.user_id = $2
            "#,
        )
        .bind(family_id)
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or(ServiceError::PermissionDenied)?;

        let role = MemberRole::from_str_name(&row.role)
            .ok_or_else(|| ServiceError::ValidationError("Invalid role".to_string()))?;

        let permissions = serde_json::from_value(row.permissions)?;

        Ok(ServiceContext::new(
            user_id,
            family_id,
            role,
            permissions,
            row.email,
            row.full_name,
        ))
    }

    /// Hash password using Argon2id algorithm (preferred format)
    fn hash_password(&self, password: &str) -> Result<String, ServiceError> {
        generate_argon2_hash(password).map_err(|_e| ServiceError::InternalError)
    }

    /// Verify password against hash (supports both Argon2id and bcrypt)
    ///
    /// This method uses the unified password verification helper that supports:
    /// - Argon2id format: `$argon2...` (preferred)
    /// - bcrypt format: `$2a$`, `$2b$`, `$2y$` (legacy)
    /// - Unknown formats: attempted as Argon2 (best-effort)
    ///
    /// Returns Ok if password verified successfully, Err otherwise.
    fn verify_password(&self, password: &str, hash: &str) -> Result<(), ServiceError> {
        let result = verify_and_maybe_rehash(password, hash, false);

        if result.verified {
            Ok(())
        } else {
            Err(ServiceError::AuthenticationError(
                "Invalid credentials".to_string(),
            ))
        }
    }
}
