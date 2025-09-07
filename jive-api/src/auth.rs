//! JWT认证中间件和相关功能

use axum::{
    async_trait,
    extract::FromRequestParts,
    http::{request::Parts, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use std::fmt::Display;
use uuid::Uuid;

/// JWT密钥（实际生产中应该从环境变量读取）
const JWT_SECRET: &str = "your-secret-key-change-this-in-production";

/// JWT Claims
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Claims {
    /// 用户ID
    pub sub: String,
    /// 用户邮箱
    pub email: String,
    /// 家庭ID
    pub family_id: Option<Uuid>,
    /// 过期时间
    pub exp: usize,
    /// 颁发时间
    pub iat: usize,
}

impl Claims {
    /// 创建新的Claims
    pub fn new(user_id: Uuid, email: String, family_id: Option<Uuid>) -> Self {
        let now = chrono::Utc::now();
        let exp = (now + chrono::Duration::hours(24)).timestamp() as usize;
        let iat = now.timestamp() as usize;

        Self {
            sub: user_id.to_string(),
            email,
            family_id,
            exp,
            iat,
        }
    }

    /// 生成JWT令牌
    pub fn to_token(&self) -> Result<String, AuthError> {
        let token = encode(
            &Header::default(),
            self,
            &EncodingKey::from_secret(JWT_SECRET.as_ref()),
        )
        .map_err(|_| AuthError::TokenCreation)?;
        
        Ok(token)
    }

    /// 从JWT令牌解析Claims
    pub fn from_token(token: &str) -> Result<Self, AuthError> {
        let token_data = decode::<Claims>(
            token,
            &DecodingKey::from_secret(JWT_SECRET.as_ref()),
            &Validation::default(),
        )
        .map_err(|_| AuthError::InvalidToken)?;
        
        Ok(token_data.claims)
    }

    /// 获取用户ID
    pub fn user_id(&self) -> Result<Uuid, AuthError> {
        Uuid::parse_str(&self.sub).map_err(|_| AuthError::InvalidToken)
    }
}

/// 认证错误
#[derive(Debug)]
#[allow(dead_code)]
pub enum AuthError {
    WrongCredentials,
    MissingCredentials,
    TokenCreation,
    InvalidToken,
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let (status, error_message) = match self {
            AuthError::WrongCredentials => (StatusCode::UNAUTHORIZED, "Wrong credentials"),
            AuthError::MissingCredentials => (StatusCode::BAD_REQUEST, "Missing credentials"),
            AuthError::TokenCreation => (StatusCode::INTERNAL_SERVER_ERROR, "Token creation error"),
            AuthError::InvalidToken => (StatusCode::UNAUTHORIZED, "Invalid token"),
        };
        
        let body = Json(serde_json::json!({
            "error": error_message,
        }));
        
        (status, body).into_response()
    }
}

impl Display for AuthError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self)
    }
}

impl std::error::Error for AuthError {}

/// Axum提取器，用于从请求中提取JWT Claims
#[async_trait]
impl<S> FromRequestParts<S> for Claims
where
    S: Send + Sync,
{
    type Rejection = AuthError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        // 提取Authorization头
        let auth_header = parts
            .headers
            .get("Authorization")
            .and_then(|value| value.to_str().ok())
            .ok_or(AuthError::MissingCredentials)?;
        
        // 检查Bearer前缀
        if !auth_header.starts_with("Bearer ") {
            return Err(AuthError::InvalidToken);
        }
        
        // 提取token
        let token = &auth_header[7..];
        
        // 验证令牌并提取claims
        let claims = Claims::from_token(token)?;
        
        Ok(claims)
    }
}

/// 登录请求
#[derive(Debug, Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

/// 登录响应
#[derive(Debug, Serialize)]
pub struct LoginResponse {
    pub token: String,
    pub user_id: Uuid,
    pub email: String,
    pub family_id: Option<Uuid>,
}

/// 注册请求
#[derive(Debug, Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub name: String,
    #[serde(default = "default_country")]
    pub country: String,
    #[serde(default = "default_currency")]
    pub currency: String,
    #[serde(default = "default_language")]
    pub language: String,
    #[serde(default = "default_timezone")]
    pub timezone: String,
    #[serde(default = "default_date_format")]
    pub date_format: String,
}

// Default values for registration
fn default_country() -> String { "CN".to_string() }
fn default_currency() -> String { "CNY".to_string() }
fn default_language() -> String { "zh-CN".to_string() }
fn default_timezone() -> String { "Asia/Shanghai".to_string() }
fn default_date_format() -> String { "YYYY-MM-DD".to_string() }

/// 注册响应
#[derive(Debug, Serialize)]
pub struct RegisterResponse {
    pub user_id: Uuid,
    pub email: String,
    pub token: String,
}

/// 生成JWT令牌
pub fn generate_jwt(user_id: Uuid, family_id: Option<Uuid>) -> Result<String, AuthError> {
    let claims = Claims::new(user_id, String::new(), family_id);
    claims.to_token()
}

/// 解码JWT令牌
pub fn decode_jwt(token: &str) -> Result<Claims, AuthError> {
    Claims::from_token(token)
}