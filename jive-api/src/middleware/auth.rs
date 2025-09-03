//! JWT 认证中间件

use axum::{
    extract::{Request, State},
    http::{header, StatusCode},
    middleware::Next,
    response::{IntoResponse, Response},
    Json,
};
use jsonwebtoken::{decode, encode, DecodingKey, EncodingKey, Header, Validation};
use serde::{Deserialize, Serialize};
use serde_json::json;
use std::sync::Arc;

/// JWT Claims
#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,       // 用户ID
    pub email: String,     // 用户邮箱
    pub role: String,      // 用户角色
    pub exp: usize,        // 过期时间
    pub iat: usize,        // 签发时间
}

/// JWT配置
#[derive(Clone)]
pub struct JwtConfig {
    pub secret: String,
    pub expiry: i64,
}

impl JwtConfig {
    pub fn from_env() -> Self {
        Self {
            secret: std::env::var("JWT_SECRET")
                .unwrap_or_else(|_| "your-secret-key-change-this-in-production".to_string()),
            expiry: std::env::var("JWT_EXPIRY")
                .unwrap_or_else(|_| "86400".to_string())
                .parse()
                .unwrap_or(86400),
        }
    }
}

/// 生成 JWT token
pub fn generate_token(user_id: &str, email: &str, role: &str, config: &JwtConfig) -> Result<String, jsonwebtoken::errors::Error> {
    let now = chrono::Utc::now();
    let iat = now.timestamp() as usize;
    let exp = (now + chrono::Duration::seconds(config.expiry)).timestamp() as usize;
    
    let claims = Claims {
        sub: user_id.to_string(),
        email: email.to_string(),
        role: role.to_string(),
        exp,
        iat,
    };
    
    encode(
        &Header::default(),
        &claims,
        &EncodingKey::from_secret(config.secret.as_bytes()),
    )
}

/// 验证 JWT token
pub fn verify_token(token: &str, config: &JwtConfig) -> Result<Claims, jsonwebtoken::errors::Error> {
    decode::<Claims>(
        token,
        &DecodingKey::from_secret(config.secret.as_bytes()),
        &Validation::default(),
    )
    .map(|data| data.claims)
}

/// JWT 认证中间件
pub async fn auth_middleware(
    State(jwt_config): State<Arc<JwtConfig>>,
    mut request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    // 获取 Authorization header
    let auth_header = request
        .headers()
        .get(header::AUTHORIZATION)
        .and_then(|h| h.to_str().ok());
    
    let token = match auth_header {
        Some(h) if h.starts_with("Bearer ") => &h[7..],
        _ => {
            return Ok(Json(json!({
                "error": "Missing or invalid authorization header"
            }))
            .into_response());
        }
    };
    
    // 验证 token
    match verify_token(token, &jwt_config) {
        Ok(claims) => {
            // 将用户信息添加到请求扩展中
            request.extensions_mut().insert(claims);
            Ok(next.run(request).await)
        }
        Err(_) => {
            Ok(Json(json!({
                "error": "Invalid or expired token"
            }))
            .into_response())
        }
    }
}

/// 管理员权限中间件
pub async fn admin_middleware(
    request: Request,
    next: Next,
) -> Result<Response, StatusCode> {
    // 从请求扩展中获取用户信息
    let claims = request.extensions().get::<Claims>().cloned();
    
    match claims {
        Some(claims) if claims.role == "admin" => {
            Ok(next.run(request).await)
        }
        _ => {
            Ok(Json(json!({
                "error": "Admin access required"
            }))
            .into_response())
        }
    }
}

/// 从请求中提取当前用户信息
pub fn get_current_user(request: &Request) -> Option<Claims> {
    request.extensions().get::<Claims>().cloned()
}