//! 认证相关API处理器
//! 提供用户注册、登录、令牌刷新等功能

use axum::{
    extract::State,
    http::StatusCode,
    response::Json,
    Extension,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;
use chrono::{DateTime, Utc};
use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};

use crate::auth::{Claims, LoginRequest, LoginResponse, RegisterRequest, RegisterResponse};
use crate::error::{ApiError, ApiResult};
use crate::services::AuthService;

/// 用户模型
#[derive(Debug, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub email: String,
    pub name: String,
    pub password_hash: String,
    pub family_id: Option<Uuid>,
    pub is_active: bool,
    pub is_verified: bool,
    pub last_login_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 增强的注册（创建个人Family）
pub async fn register_with_family(
    State(pool): State<PgPool>,
    Json(req): Json<RegisterRequest>,
) -> ApiResult<Json<RegisterResponse>> {
    
    let auth_service = AuthService::new(pool.clone());
    let register_req = crate::services::auth_service::RegisterRequest {
        email: req.email.clone(),
        password: req.password.clone(),
        name: Some(req.name.clone()),
    };
    
    match auth_service.register_with_family(register_req).await {
        Ok(user_ctx) => {
            // Generate JWT token
            let token = crate::auth::generate_jwt(user_ctx.user_id, user_ctx.current_family_id)?;
            
            Ok(Json(RegisterResponse {
                user_id: user_ctx.user_id,
                email: user_ctx.email,
                token,
            }))
        },
        Err(e) => {
            Err(ApiError::BadRequest(format!("Registration failed: {:?}", e)))
        }
    }
}

/// 用户注册（保留原版本以兼容）
pub async fn register(
    State(pool): State<PgPool>,
    Json(req): Json<RegisterRequest>,
) -> ApiResult<Json<RegisterResponse>> {
    // 验证邮箱格式
    if !req.email.contains('@') {
        return Err(ApiError::ValidationError("Invalid email format".to_string()));
    }
    
    // 检查邮箱是否已存在
    let existing = sqlx::query(
        "SELECT id FROM users WHERE LOWER(email) = LOWER($1)"
    )
    .bind(&req.email)
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    if existing.is_some() {
        return Err(ApiError::BadRequest("Email already registered".to_string()));
    }
    
    // 生成密码哈希
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let password_hash = argon2
        .hash_password(req.password.as_bytes(), &salt)
        .map_err(|_| ApiError::InternalServerError)?
        .to_string();
    
    // 创建用户
    let user_id = Uuid::new_v4();
    let family_id = Uuid::new_v4(); // 为新用户创建默认家庭
    
    // 开始事务
    let mut tx = pool.begin().await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // 创建家庭
    sqlx::query(
        r#"
        INSERT INTO families (id, name, created_at, updated_at)
        VALUES ($1, $2, NOW(), NOW())
        "#
    )
    .bind(family_id)
    .bind(format!("{}'s Family", req.name))
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // 创建用户
    sqlx::query(
        r#"
        INSERT INTO users (
            id, email, name, password_hash, family_id,
            is_active, is_verified, created_at, updated_at
        ) VALUES (
            $1, $2, $3, $4, $5, true, false, NOW(), NOW()
        )
        "#
    )
    .bind(user_id)
    .bind(&req.email)
    .bind(&req.name)
    .bind(password_hash)
    .bind(family_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // 创建默认账本
    let ledger_id = Uuid::new_v4();
    sqlx::query(
        r#"
        INSERT INTO ledgers (id, family_id, name, currency, created_at, updated_at)
        VALUES ($1, $2, '默认账本', 'CNY', NOW(), NOW())
        "#
    )
    .bind(ledger_id)
    .bind(family_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // 提交事务
    tx.commit().await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // 生成JWT令牌
    let claims = Claims::new(user_id, req.email.clone(), Some(family_id));
    let token = claims.to_token()?;
    
    Ok(Json(RegisterResponse {
        user_id,
        email: req.email,
        token,
    }))
}

/// 用户登录
pub async fn login(
    State(pool): State<PgPool>,
    Json(req): Json<LoginRequest>,
) -> ApiResult<Json<LoginResponse>> {
    // 查找用户
    let row = sqlx::query(
        r#"
        SELECT id, email, name, password_hash,
               is_active, email_verified, last_login_at,
               created_at, updated_at
        FROM users
        WHERE LOWER(email) = LOWER($1)
        "#
    )
    .bind(&req.email)
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::Unauthorized)?;
    
    use sqlx::Row;
    let user = User {
        id: row.try_get("id").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
        email: row.try_get("email").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
        name: row.try_get("name").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
        password_hash: row.try_get("password_hash").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
        family_id: None, // Will fetch from family_members table if needed
        is_active: row.try_get("is_active").unwrap_or(false),
        is_verified: row.try_get("email_verified").unwrap_or(false),
        last_login_at: row.try_get("last_login_at").ok(),
        created_at: row.try_get("created_at").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
        updated_at: row.try_get("updated_at").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
    };
    
    // 检查用户状态
    if !user.is_active {
        return Err(ApiError::Forbidden);
    }
    
    // 验证密码
    let parsed_hash = PasswordHash::new(&user.password_hash)
        .map_err(|_| ApiError::InternalServerError)?;
    
    let argon2 = Argon2::default();
    argon2
        .verify_password(req.password.as_bytes(), &parsed_hash)
        .map_err(|_| ApiError::Unauthorized)?;
    
    // 获取用户的family_id（如果有）
    let family_row = sqlx::query(
        "SELECT family_id FROM family_members WHERE user_id = $1 LIMIT 1"
    )
    .bind(user.id)
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    let family_id = if let Some(row) = family_row {
        row.try_get("family_id").ok()
    } else {
        None
    };
    
    // 更新最后登录时间
    sqlx::query(
        "UPDATE users SET last_login_at = NOW() WHERE id = $1"
    )
    .bind(user.id)
    .execute(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // 生成JWT令牌
    let claims = Claims::new(user.id, user.email.clone(), family_id);
    let token = claims.to_token()?;
    
    Ok(Json(LoginResponse {
        token,
        user_id: user.id,
        email: user.email,
        family_id,
    }))
}

/// 刷新令牌
pub async fn refresh_token(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<LoginResponse>> {
    let user_id = claims.user_id()?;
    
    // 验证用户是否仍然有效
    let user = sqlx::query("SELECT email, family_id, is_active FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?
        .ok_or(ApiError::Unauthorized)?;
    
    use sqlx::Row;
    
    let is_active: bool = user.try_get("is_active").unwrap_or(false);
    if !is_active {
        return Err(ApiError::Forbidden);
    }
    
    let email: String = user.try_get("email").map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    let family_id: Option<Uuid> = user.try_get("family_id").ok();
    
    // 生成新令牌
    let new_claims = Claims::new(user_id, email.clone(), family_id);
    let token = new_claims.to_token()?;
    
    Ok(Json(LoginResponse {
        token,
        user_id,
        email,
        family_id,
    }))
}

/// 获取当前用户信息
pub async fn get_current_user(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<UserProfile>> {
    let user_id = claims.user_id()?;
    
    let user = sqlx::query(
        r#"
        SELECT u.*, f.name as family_name
        FROM users u
        LEFT JOIN families f ON u.family_id = f.id
        WHERE u.id = $1
        "#
    )
    .bind(user_id)
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound("User not found".to_string()))?;
    
    use sqlx::Row;
    
    Ok(Json(UserProfile {
        id: user.try_get("id").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
        email: user.try_get("email").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
        name: user.try_get("name").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
        family_id: user.try_get("family_id").ok(),
        family_name: user.try_get("family_name").ok(),
        is_verified: user.try_get("is_verified").unwrap_or(false),
        created_at: user.try_get("created_at").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
    }))
}

/// 更新用户信息
pub async fn update_user(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(req): Json<UpdateUserRequest>,
) -> ApiResult<StatusCode> {
    let user_id = claims.user_id()?;
    
    if let Some(name) = req.name {
        sqlx::query(
            "UPDATE users SET name = $1, updated_at = NOW() WHERE id = $2"
        )
        .bind(name)
        .bind(user_id)
        .execute(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    }
    
    Ok(StatusCode::OK)
}

/// 修改密码
pub async fn change_password(
    Extension(claims): Extension<Claims>,
    State(pool): State<PgPool>,
    Json(req): Json<ChangePasswordRequest>,
) -> ApiResult<StatusCode> {
    let user_id = claims.user_id()?;
    
    // 获取当前密码哈希
    let row = sqlx::query("SELECT password_hash FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_one(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    use sqlx::Row;
    let current_hash: String = row.try_get("password_hash")
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // 验证旧密码
    let parsed_hash = PasswordHash::new(&current_hash)
        .map_err(|_| ApiError::InternalServerError)?;
    
    let argon2 = Argon2::default();
    argon2
        .verify_password(req.old_password.as_bytes(), &parsed_hash)
        .map_err(|_| ApiError::Unauthorized)?;
    
    // 生成新密码哈希
    let salt = SaltString::generate(&mut OsRng);
    let new_hash = argon2
        .hash_password(req.new_password.as_bytes(), &salt)
        .map_err(|_| ApiError::InternalServerError)?
        .to_string();
    
    // 更新密码
    sqlx::query(
        "UPDATE users SET password_hash = $1, updated_at = NOW() WHERE id = $2"
    )
    .bind(new_hash)
    .bind(user_id)
    .execute(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    Ok(StatusCode::OK)
}

/// 获取用户上下文（包含所有Family）
pub async fn get_user_context(
    State(pool): State<PgPool>,
    Extension(user_id): Extension<Uuid>,
) -> ApiResult<Json<crate::services::auth_service::UserContext>> {
    
    let auth_service = AuthService::new(pool);
    
    match auth_service.get_user_context(user_id).await {
        Ok(context) => Ok(Json(context)),
        Err(e) => {
            Err(ApiError::InternalServerError)
        }
    }
}

/// 用户信息响应
#[derive(Debug, Serialize)]
pub struct UserProfile {
    pub id: Uuid,
    pub email: String,
    pub name: String,
    pub family_id: Option<Uuid>,
    pub family_name: Option<String>,
    pub is_verified: bool,
    pub created_at: DateTime<Utc>,
}

/// 更新用户请求
#[derive(Debug, Deserialize)]
pub struct UpdateUserRequest {
    pub name: Option<String>,
}

/// 修改密码请求
#[derive(Debug, Deserialize)]
pub struct ChangePasswordRequest {
    pub old_password: String,
    pub new_password: String,
}