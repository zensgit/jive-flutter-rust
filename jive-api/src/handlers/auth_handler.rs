#![allow(dead_code)]
//! 认证处理器
//! 
//! 处理用户认证相关的API请求

use axum::{
    extract::{Json, State},
    http::StatusCode,
    response::Json as ResponseJson,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::PgPool;
use tracing::{info, warn, error};
use uuid::Uuid;
use chrono::{DateTime, Utc};

/// 登录请求
#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
    pub remember_me: Option<bool>,
}

/// 注册请求
#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    pub name: String,
    pub email: String,
    pub password: String,
}

/// 用户信息
#[derive(Debug, Serialize)]
pub struct User {
    pub id: String,
    pub name: String,
    pub email: String,
    pub role: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 认证响应
#[derive(Debug, Serialize)]
pub struct AuthResponse {
    pub success: bool,
    pub message: String,
    pub token: Option<String>,
    pub user: Option<User>,
}

/// 登录处理器
pub async fn login(
    State(pool): State<PgPool>,
    Json(request): Json<LoginRequest>,
) -> Result<ResponseJson<AuthResponse>, StatusCode> {
    info!("登录请求: email={}, remember_me={:?}", request.email, request.remember_me);

    // 简化的认证逻辑 - 生产环境应该进行真正的密码验证
    match authenticate_user(&pool, &request.email, &request.password).await {
        Ok(Some(user)) => {
            info!("用户认证成功: {}", user.email);
            
            // 生成简单的JWT token (生产环境应该使用真正的JWT库)
            let token = generate_simple_token(&user.id);
            
            Ok(ResponseJson(AuthResponse {
                success: true,
                message: "登录成功".to_string(),
                token: Some(token),
                user: Some(user),
            }))
        }
        Ok(None) => {
            warn!("认证失败: 用户名或密码错误 - {}", request.email);
            Ok(ResponseJson(AuthResponse {
                success: false,
                message: "用户名或密码错误".to_string(),
                token: None,
                user: None,
            }))
        }
        Err(e) => {
            error!("认证过程中发生错误: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

/// 注册处理器
pub async fn register(
    State(pool): State<PgPool>,
    Json(request): Json<RegisterRequest>,
) -> Result<ResponseJson<AuthResponse>, StatusCode> {
    info!("注册请求: name={}, email={}", request.name, request.email);

    // 检查用户是否已存在
    match check_user_exists(&pool, &request.email).await {
        Ok(true) => {
            warn!("注册失败: 邮箱已存在 - {}", request.email);
            return Ok(ResponseJson(AuthResponse {
                success: false,
                message: "该邮箱已被注册".to_string(),
                token: None,
                user: None,
            }));
        }
        Ok(false) => {
            // 用户不存在，可以注册
        }
        Err(e) => {
            error!("检查用户存在时发生错误: {}", e);
            return Err(StatusCode::INTERNAL_SERVER_ERROR);
        }
    }

    // 创建新用户
    match create_user(&pool, &request.name, &request.email, &request.password).await {
        Ok(user) => {
            info!("用户注册成功: {}", user.email);
            
            let token = generate_simple_token(&user.id);
            
            Ok(ResponseJson(AuthResponse {
                success: true,
                message: "注册成功".to_string(),
                token: Some(token),
                user: Some(user),
            }))
        }
        Err(e) => {
            error!("创建用户时发生错误: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}

/// 获取当前用户信息
pub async fn get_current_user(
    State(_pool): State<PgPool>,
) -> Result<ResponseJson<serde_json::Value>, StatusCode> {
    // 简化实现 - 生产环境应该从JWT token中获取用户ID
    let demo_user = User {
        id: "demo-user-id".to_string(),
        name: "演示用户".to_string(),
        email: "demo@jivemoney.app".to_string(),
        role: "user".to_string(),
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    Ok(ResponseJson(json!({
        "success": true,
        "user": demo_user
    })))
}

/// 验证用户凭据
async fn authenticate_user(
    _pool: &PgPool,
    email: &str,
    password: &str,
) -> Result<Option<User>, sqlx::Error> {
    // 简化的认证逻辑 - 接受任何非空的邮箱和密码
    if email.is_empty() || password.is_empty() {
        return Ok(None);
    }

    // 演示用户数据
    let user = User {
        id: Uuid::new_v4().to_string(),
        name: extract_name_from_email(email),
        email: email.to_string(),
        role: if email.contains("admin") { "admin".to_string() } else { "user".to_string() },
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    info!("演示认证成功: {}", email);
    Ok(Some(user))
}

/// 检查用户是否存在
async fn check_user_exists(_pool: &PgPool, email: &str) -> Result<bool, sqlx::Error> {
    // 简化实现 - 演示环境总是返回false允许注册
    info!("检查用户是否存在: {}", email);
    Ok(false)
}

/// 创建新用户
async fn create_user(
    _pool: &PgPool,
    name: &str,
    email: &str,
    _password: &str,
) -> Result<User, sqlx::Error> {
    let user = User {
        id: Uuid::new_v4().to_string(),
        name: name.to_string(),
        email: email.to_string(),
        role: "user".to_string(),
        created_at: Utc::now(),
        updated_at: Utc::now(),
    };

    info!("演示用户创建成功: {}", email);
    Ok(user)
}

/// 生成简单的token
fn generate_simple_token(user_id: &str) -> String {
    format!("jive_token_{}", user_id)
}

/// 从邮箱提取用户名
fn extract_name_from_email(email: &str) -> String {
    email.split('@').next().unwrap_or("用户").to_string()
}
