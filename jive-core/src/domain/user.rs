//! User domain model - 用户领域模型
//! 
//! 基于 Maybe 的 User 模型转换而来，包含用户基本信息、偏好设置、安全设置等

use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc};

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::error::{JiveError, Result};

/// 用户状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum UserStatus {
    Active,      // 活跃
    Inactive,    // 未激活
    Suspended,   // 暂停
    Deleted,     // 已删除
}

/// 用户角色
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum UserRole {
    User,        // 普通用户
    Premium,     // 高级用户
    Admin,       // 管理员
    SuperAdmin,  // 超级管理员
}

/// 用户偏好设置
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UserPreferences {
    language: String,
    timezone: String,
    currency: String,
    date_format: String,
    theme: String,
    notifications_enabled: bool,
}

impl Default for UserPreferences {
    fn default() -> Self {
        Self {
            language: "en".to_string(),
            timezone: "UTC".to_string(),
            currency: "USD".to_string(),
            date_format: "YYYY-MM-DD".to_string(),
            theme: "system".to_string(),
            notifications_enabled: true,
        }
    }
}

/// 用户实体
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct User {
    id: String,
    email: String,
    name: String,
    avatar_url: Option<String>,
    status: UserStatus,
    role: UserRole,
    preferences: UserPreferences,
    current_ledger_id: Option<String>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    last_login_at: Option<DateTime<Utc>>,
    email_verified_at: Option<DateTime<Utc>>,
    metadata: HashMap<String, String>,
}

impl User {
    pub fn new(email: String, name: String) -> Result<Self> {
        // 验证邮箱格式
        crate::utils::Validator::validate_email(&email)?;

        // 验证名称
        if name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Name cannot be empty".to_string(),
            });
        }

        let now = Utc::now();
        
        Ok(Self {
            id: uuid::Uuid::new_v4().to_string(),
            email,
            name,
            avatar_url: None,
            status: UserStatus::Inactive,
            role: UserRole::User,
            preferences: UserPreferences::default(),
            current_ledger_id: None,
            created_at: now,
            updated_at: now,
            last_login_at: None,
            email_verified_at: None,
            metadata: HashMap::new(),
        })
    }

    // Getters
    pub fn id(&self) -> String { self.id.clone() }
    pub fn email(&self) -> String { self.email.clone() }
    pub fn name(&self) -> String { self.name.clone() }
    pub fn status(&self) -> UserStatus { self.status.clone() }
    pub fn role(&self) -> UserRole { self.role.clone() }
    pub fn preferences(&self) -> UserPreferences { self.preferences.clone() }

    // Business methods
    pub fn is_active(&self) -> bool {
        self.status == UserStatus::Active
    }

    pub fn activate(&mut self) {
        self.status = UserStatus::Active;
        self.update_timestamp();
    }

    pub fn verify_email(&mut self) {
        self.email_verified_at = Some(Utc::now());
        self.update_timestamp();
    }

    fn update_timestamp(&mut self) {
        self.updated_at = Utc::now();
    }
}