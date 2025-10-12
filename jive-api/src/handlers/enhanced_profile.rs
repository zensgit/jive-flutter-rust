use axum::{
    extract::State,
    http::StatusCode,
    response::Json,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;
use chrono::{DateTime, Utc};
use argon2::{
    password_hash::{rand_core::OsRng, PasswordHasher, SaltString},
    Argon2,
};

use crate::auth::{Claims, RegisterRequest};
use crate::error::{ApiError, ApiResult};
use crate::services::{FamilyService, AvatarService};
use crate::models::family::CreateFamilyRequest;
use super::family_handler::ApiResponse;

/// Enhanced User Profile with preferences
#[derive(Debug, Serialize, Deserialize)]
pub struct EnhancedUserProfile {
    pub id: Uuid,
    pub email: String,
    pub name: String,
    pub avatar_url: Option<String>,
    pub avatar_style: Option<String>,
    pub avatar_color: Option<String>,
    pub avatar_background: Option<String>,
    pub country: String,
    pub preferred_currency: String,
    pub preferred_language: String,
    pub preferred_timezone: String,
    pub preferred_date_format: String,
    pub family_id: Option<Uuid>,
    pub family_name: Option<String>,
    pub is_verified: bool,
    pub created_at: DateTime<Utc>,
}

/// Update user preferences request
#[derive(Debug, Deserialize)]
pub struct UpdatePreferencesRequest {
    pub name: Option<String>,
    pub country: Option<String>,
    pub preferred_currency: Option<String>,
    pub preferred_language: Option<String>,
    pub preferred_timezone: Option<String>,
    pub preferred_date_format: Option<String>,
}

/// Enhanced registration with user preferences
pub async fn register_with_preferences(
    State(pool): State<PgPool>,
    Json(req): Json<RegisterRequest>,
) -> ApiResult<Json<ApiResponse<serde_json::Value>>> {
    // Check if email already exists
    let exists: bool = sqlx::query_scalar(
        "SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)"
    )
    .bind(&req.email)
    .fetch_one(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    if exists {
        return Ok(Json(ApiResponse::<serde_json::Value> {
            success: false,
            data: None,
            error: Some(super::family_handler::ApiError {
                code: "EMAIL_EXISTS".to_string(),
                message: "该邮箱已被注册".to_string(),
                details: None,
            }),
            timestamp: chrono::Utc::now(),
        }));
    }
    
    let mut tx = pool.begin().await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // Hash password
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let password_hash = argon2
        .hash_password(req.password.as_bytes(), &salt)
        .map_err(|_| ApiError::InternalServerError)?
        .to_string();
    
    // Create user with preferences
    let user_id = Uuid::new_v4();
    
    // Generate random avatar for the user
    let avatar = AvatarService::generate_random_avatar(&req.name, &req.email);
    
    // First, try to add columns if they don't exist (safe operation)
    let _ = sqlx::query(
        r#"
        ALTER TABLE users 
        ADD COLUMN IF NOT EXISTS country VARCHAR(10) DEFAULT 'CN',
        ADD COLUMN IF NOT EXISTS preferred_currency VARCHAR(10) DEFAULT 'CNY',
        ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(10) DEFAULT 'zh-CN',
        ADD COLUMN IF NOT EXISTS preferred_timezone VARCHAR(50) DEFAULT 'Asia/Shanghai',
        ADD COLUMN IF NOT EXISTS preferred_date_format VARCHAR(20) DEFAULT 'YYYY-MM-DD',
        ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(500),
        ADD COLUMN IF NOT EXISTS avatar_style VARCHAR(20) DEFAULT 'initials',
        ADD COLUMN IF NOT EXISTS avatar_color VARCHAR(20) DEFAULT '#4ECDC4',
        ADD COLUMN IF NOT EXISTS avatar_background VARCHAR(20) DEFAULT '#E3FFF8'
        "#
    )
    .execute(&mut *tx)
    .await;
    
    // Insert user with preferences and avatar
    sqlx::query(
        r#"
        INSERT INTO users (
            id, email, full_name, password_hash, 
            country, preferred_currency, preferred_language, 
            preferred_timezone, preferred_date_format,
            avatar_url, avatar_style, avatar_color, avatar_background,
            created_at, updated_at
        )
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
        "#
    )
    .bind(user_id)
    .bind(&req.email)
    .bind(&req.name)
    .bind(&password_hash)
    .bind(&req.country)
    .bind(&req.currency)
    .bind(&req.language)
    .bind(&req.timezone)
    .bind(&req.date_format)
    .bind(&avatar.url)
    .bind(format!("{:?}", avatar.style).to_lowercase())
    .bind(&avatar.color)
    .bind(&avatar.background)
    .bind(Utc::now())
    .bind(Utc::now())
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // Commit user creation
    tx.commit().await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // Create family with user's preferences
    let family_service = FamilyService::new(pool.clone());
    let family_request = CreateFamilyRequest {
        name: Some(format!("{}的家庭", req.name)),
        currency: Some(req.currency.clone()),
        timezone: Some(req.timezone.clone()),
        locale: Some(req.language.clone()),
    };
    
    let family = family_service.create_family(user_id, family_request).await
        .map_err(|_e| ApiError::InternalServerError)?;
    
    // Update user's current family
    sqlx::query(
        "UPDATE users SET current_family_id = $1 WHERE id = $2"
    )
    .bind(family.id)
    .bind(user_id)
    .execute(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    // Generate JWT token
    let token = crate::auth::generate_jwt(user_id, Some(family.id))?;
    
    Ok(Json(ApiResponse::success(serde_json::json!({
        "user_id": user_id,
        "email": req.email,
        "token": token,
        "preferences": {
            "country": req.country,
            "currency": req.currency,
            "language": req.language,
            "timezone": req.timezone,
            "date_format": req.date_format
        }
    }))))
}

/// Get enhanced user profile with preferences
pub async fn get_enhanced_profile(
    State(pool): State<PgPool>,
    claims: Claims,
) -> ApiResult<Json<ApiResponse<EnhancedUserProfile>>> {
    let user_id = claims.user_id()?;
    
    // Try to get user with preferences (handle missing columns gracefully)
    let result = sqlx::query(
        r#"
        SELECT 
            u.id, u.email, u.name,
            u.avatar_url, u.avatar_style, u.avatar_color, u.avatar_background,
            COALESCE(u.country, 'CN') as country,
            COALESCE(u.preferred_currency, 'CNY') as preferred_currency,
            COALESCE(u.preferred_language, 'zh-CN') as preferred_language,
            COALESCE(u.preferred_timezone, 'Asia/Shanghai') as preferred_timezone,
            COALESCE(u.preferred_date_format, 'YYYY-MM-DD') as preferred_date_format,
            u.current_family_id,
            f.name as family_name,
            COALESCE(u.email_verified, false) as is_verified,
            u.created_at
        FROM users u
        LEFT JOIN families f ON u.current_family_id = f.id
        WHERE u.id = $1
        "#
    )
    .bind(user_id)
    .fetch_optional(&pool)
    .await;
    
    match result {
        Ok(Some(row)) => {
            use sqlx::Row;
            
            let profile = EnhancedUserProfile {
                id: row.try_get("id").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
                email: row.try_get("email").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
                name: row.try_get("name").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
                avatar_url: row.try_get("avatar_url").ok(),
                avatar_style: row.try_get("avatar_style").ok(),
                avatar_color: row.try_get("avatar_color").ok(),
                avatar_background: row.try_get("avatar_background").ok(),
                country: row.try_get("country").unwrap_or_else(|_| "CN".to_string()),
                preferred_currency: row.try_get("preferred_currency").unwrap_or_else(|_| "CNY".to_string()),
                preferred_language: row.try_get("preferred_language").unwrap_or_else(|_| "zh-CN".to_string()),
                preferred_timezone: row.try_get("preferred_timezone").unwrap_or_else(|_| "Asia/Shanghai".to_string()),
                preferred_date_format: row.try_get("preferred_date_format").unwrap_or_else(|_| "YYYY-MM-DD".to_string()),
                family_id: row.try_get("current_family_id").ok(),
                family_name: row.try_get("family_name").ok(),
                is_verified: row.try_get("is_verified").unwrap_or(false),
                created_at: row.try_get("created_at").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
            };
            
            Ok(Json(ApiResponse::success(profile)))
        },
        Ok(None) => Err(ApiError::NotFound("User not found".to_string())),
        Err(_) => {
            // If columns don't exist, return basic profile with defaults
            let basic_user = sqlx::query(
                r#"
                SELECT 
                    u.id, u.email, u.full_name,
                    u.current_family_id,
                    f.name as family_name,
                    COALESCE(u.email_verified, false) as is_verified,
                    u.created_at
                FROM users u
                LEFT JOIN families f ON u.current_family_id = f.id
                WHERE u.id = $1
                "#
            )
            .bind(user_id)
            .fetch_optional(&pool)
            .await
            .map_err(|e| ApiError::DatabaseError(e.to_string()))?
            .ok_or_else(|| ApiError::NotFound("User not found".to_string()))?;
            
            use sqlx::Row;
            
            let user_id: Uuid = basic_user.try_get("id").map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            let email: String = basic_user.try_get("email").map_err(|e| ApiError::DatabaseError(e.to_string()))?;
            let name: String = basic_user.try_get("name").unwrap_or_else(|_| "User".to_string());
            
            // Generate default avatar if not present
            let avatar = AvatarService::generate_deterministic_avatar(&user_id.to_string(), &name);
            
            let profile = EnhancedUserProfile {
                id: user_id,
                email,
                name,
                avatar_url: Some(avatar.url),
                avatar_style: Some(format!("{:?}", avatar.style).to_lowercase()),
                avatar_color: Some(avatar.color),
                avatar_background: Some(avatar.background),
                country: "CN".to_string(),
                preferred_currency: "CNY".to_string(),
                preferred_language: "zh-CN".to_string(),
                preferred_timezone: "Asia/Shanghai".to_string(),
                preferred_date_format: "YYYY-MM-DD".to_string(),
                family_id: basic_user.try_get("current_family_id").ok(),
                family_name: basic_user.try_get("family_name").ok(),
                is_verified: basic_user.try_get("is_verified").unwrap_or(false),
                created_at: basic_user.try_get("created_at").map_err(|e| ApiError::DatabaseError(e.to_string()))?,
            };
            
            Ok(Json(ApiResponse::success(profile)))
        }
    }
}

/// Update user preferences
pub async fn update_preferences(
    State(pool): State<PgPool>,
    claims: Claims,
    Json(req): Json<UpdatePreferencesRequest>,
) -> ApiResult<StatusCode> {
    let user_id = claims.user_id()?;
    
    // Build dynamic update query
    let mut updates = vec!["updated_at = NOW()".to_string()];
    let mut bind_values: Vec<String> = vec![];
    let mut bind_idx = 2;
    
    if let Some(name) = req.name {
        updates.push(format!("full_name = ${}", bind_idx));
        bind_values.push(name);
        bind_idx += 1;
    }
    
    if let Some(country) = req.country {
        updates.push(format!("country = ${}", bind_idx));
        bind_values.push(country);
        bind_idx += 1;
    }
    
    if let Some(currency) = req.preferred_currency {
        updates.push(format!("preferred_currency = ${}", bind_idx));
        bind_values.push(currency);
        bind_idx += 1;
    }
    
    if let Some(language) = req.preferred_language {
        updates.push(format!("preferred_language = ${}", bind_idx));
        bind_values.push(language);
        bind_idx += 1;
    }
    
    if let Some(timezone) = req.preferred_timezone {
        updates.push(format!("preferred_timezone = ${}", bind_idx));
        bind_values.push(timezone);
        bind_idx += 1;
    }
    
    if let Some(date_format) = req.preferred_date_format {
        updates.push(format!("preferred_date_format = ${}", bind_idx));
        bind_values.push(date_format);
    }
    
    if bind_values.is_empty() {
        return Ok(StatusCode::OK);
    }
    
    // First try to add columns if they don't exist
    let _ = sqlx::query(
        r#"
        ALTER TABLE users 
        ADD COLUMN IF NOT EXISTS country VARCHAR(10) DEFAULT 'CN',
        ADD COLUMN IF NOT EXISTS preferred_currency VARCHAR(10) DEFAULT 'CNY',
        ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(10) DEFAULT 'zh-CN',
        ADD COLUMN IF NOT EXISTS preferred_timezone VARCHAR(50) DEFAULT 'Asia/Shanghai',
        ADD COLUMN IF NOT EXISTS preferred_date_format VARCHAR(20) DEFAULT 'YYYY-MM-DD'
        "#
    )
    .execute(&pool)
    .await;
    
    // Build and execute update query
    let query = format!("UPDATE users SET {} WHERE id = $1", updates.join(", "));
    let mut query_builder = sqlx::query(&query).bind(user_id);
    
    for value in bind_values {
        query_builder = query_builder.bind(value);
    }
    
    query_builder
        .execute(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;
    
    Ok(StatusCode::OK)
}

/// Get supported locales
pub async fn get_supported_locales() -> Json<ApiResponse<serde_json::Value>> {
    let locales = serde_json::json!({
        "countries": [
            {"code": "CN", "name": "中国", "name_en": "China"},
            {"code": "US", "name": "美国", "name_en": "United States"},
            {"code": "GB", "name": "英国", "name_en": "United Kingdom"},
            {"code": "JP", "name": "日本", "name_en": "Japan"},
            {"code": "KR", "name": "韩国", "name_en": "South Korea"},
            {"code": "DE", "name": "德国", "name_en": "Germany"},
            {"code": "FR", "name": "法国", "name_en": "France"},
            {"code": "CA", "name": "加拿大", "name_en": "Canada"},
            {"code": "AU", "name": "澳大利亚", "name_en": "Australia"},
            {"code": "SG", "name": "新加坡", "name_en": "Singapore"}
        ],
        "currencies": [
            {"code": "CNY", "name": "人民币", "symbol": "¥"},
            {"code": "USD", "name": "美元", "symbol": "$"},
            {"code": "EUR", "name": "欧元", "symbol": "€"},
            {"code": "GBP", "name": "英镑", "symbol": "£"},
            {"code": "JPY", "name": "日元", "symbol": "¥"},
            {"code": "KRW", "name": "韩元", "symbol": "₩"},
            {"code": "HKD", "name": "港币", "symbol": "HK$"},
            {"code": "TWD", "name": "新台币", "symbol": "NT$"},
            {"code": "SGD", "name": "新加坡元", "symbol": "S$"},
            {"code": "AUD", "name": "澳元", "symbol": "A$"},
            {"code": "CAD", "name": "加元", "symbol": "C$"}
        ],
        "languages": [
            {"code": "zh-CN", "name": "简体中文"},
            {"code": "zh-TW", "name": "繁體中文"},
            {"code": "en-US", "name": "English (US)"},
            {"code": "en-GB", "name": "English (UK)"},
            {"code": "ja-JP", "name": "日本語"},
            {"code": "ko-KR", "name": "한국어"},
            {"code": "de-DE", "name": "Deutsch"},
            {"code": "fr-FR", "name": "Français"},
            {"code": "es-ES", "name": "Español"},
            {"code": "pt-BR", "name": "Português"}
        ],
        "timezones": [
            {"value": "Asia/Shanghai", "name": "中国标准时间 (UTC+8)"},
            {"value": "Asia/Tokyo", "name": "日本标准时间 (UTC+9)"},
            {"value": "Asia/Seoul", "name": "韩国标准时间 (UTC+9)"},
            {"value": "Asia/Singapore", "name": "新加坡标准时间 (UTC+8)"},
            {"value": "Asia/Hong_Kong", "name": "香港标准时间 (UTC+8)"},
            {"value": "America/New_York", "name": "美国东部时间 (UTC-5/-4)"},
            {"value": "America/Los_Angeles", "name": "美国太平洋时间 (UTC-8/-7)"},
            {"value": "Europe/London", "name": "英国时间 (UTC+0/+1)"},
            {"value": "Europe/Paris", "name": "中欧时间 (UTC+1/+2)"},
            {"value": "Australia/Sydney", "name": "澳大利亚东部时间 (UTC+10/+11)"}
        ],
        "date_formats": [
            {"value": "YYYY-MM-DD", "name": "2024-12-31", "description": "年-月-日"},
            {"value": "DD/MM/YYYY", "name": "31/12/2024", "description": "日/月/年"},
            {"value": "MM/DD/YYYY", "name": "12/31/2024", "description": "月/日/年"},
            {"value": "YYYY年MM月DD日", "name": "2024年12月31日", "description": "中文格式"},
            {"value": "DD.MM.YYYY", "name": "31.12.2024", "description": "欧洲格式"},
            {"value": "MMM DD, YYYY", "name": "Dec 31, 2024", "description": "英文格式"}
        ]
    });
    
    Json(ApiResponse::success(locales))
}
