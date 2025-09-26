use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// 用户实体 - 核心用户模型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub email: String,
    pub username: Option<String>,
    pub password_hash: String,
    pub full_name: Option<String>,
    pub phone: Option<String>,
    pub avatar_url: Option<String>,

    // 认证相关
    pub email_verified: bool,
    pub mfa_enabled: bool,
    pub mfa_secret: Option<String>,

    // 用户状态
    pub status: UserStatus,
    pub role: UserRole,

    // 偏好设置
    pub preferences: UserPreferences,

    // 时间戳
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub last_login_at: Option<DateTime<Utc>>,
}

/// 用户状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum UserStatus {
    Pending,   // 待激活
    Active,    // 活跃
    Suspended, // 暂停
    Deleted,   // 已删除
}

/// 用户角色
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum UserRole {
    SuperAdmin, // 超级管理员
    Admin,      // 管理员
    Member,     // 普通成员
    Guest,      // 访客
}

/// 用户偏好设置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserPreferences {
    pub theme: ThemeMode,
    pub language: String,
    pub currency: String,
    pub timezone: String,
    pub date_format: String,
    pub number_format: String,
    pub first_day_of_week: u8, // 0=Sunday, 1=Monday
    pub fiscal_year_start: u8, // 1-12

    // 通知设置
    pub email_notifications: bool,
    pub push_notifications: bool,
    pub budget_alerts: bool,
    pub transaction_alerts: bool,

    // 界面设置
    pub sidebar_collapsed: bool,
    pub default_account_id: Option<Uuid>,
    pub default_ledger_id: Option<Uuid>,
}

/// 主题模式
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ThemeMode {
    Light,
    Dark,
    System,
}

/// 会话信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Session {
    pub id: Uuid,
    pub user_id: Uuid,
    pub token: String,
    pub refresh_token: Option<String>,
    pub device_info: Option<DeviceInfo>,
    pub ip_address: Option<String>,
    pub expires_at: DateTime<Utc>,
    pub created_at: DateTime<Utc>,
}

/// 设备信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeviceInfo {
    pub device_type: String,     // mobile/desktop/tablet
    pub os: String,              // iOS/Android/Windows/macOS/Linux
    pub browser: Option<String>, // Chrome/Safari/Firefox
    pub app_version: String,
}

impl User {
    /// 创建新用户
    pub fn new(email: String, password_hash: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            email,
            username: None,
            password_hash,
            full_name: None,
            phone: None,
            avatar_url: None,
            email_verified: false,
            mfa_enabled: false,
            mfa_secret: None,
            status: UserStatus::Pending,
            role: UserRole::Member,
            preferences: UserPreferences::default(),
            created_at: now,
            updated_at: now,
            last_login_at: None,
        }
    }

    /// 激活用户
    pub fn activate(&mut self) {
        self.status = UserStatus::Active;
        self.email_verified = true;
        self.updated_at = Utc::now();
    }

    /// 暂停用户
    pub fn suspend(&mut self) {
        self.status = UserStatus::Suspended;
        self.updated_at = Utc::now();
    }

    /// 更新登录时间
    pub fn update_last_login(&mut self) {
        self.last_login_at = Some(Utc::now());
        self.updated_at = Utc::now();
    }

    /// 启用MFA
    pub fn enable_mfa(&mut self, secret: String) {
        self.mfa_enabled = true;
        self.mfa_secret = Some(secret);
        self.updated_at = Utc::now();
    }

    /// 禁用MFA
    pub fn disable_mfa(&mut self) {
        self.mfa_enabled = false;
        self.mfa_secret = None;
        self.updated_at = Utc::now();
    }

    /// 更新偏好设置
    pub fn update_preferences(&mut self, preferences: UserPreferences) {
        self.preferences = preferences;
        self.updated_at = Utc::now();
    }
}

impl Default for UserPreferences {
    fn default() -> Self {
        Self {
            theme: ThemeMode::System,
            language: "zh-CN".to_string(),
            currency: "CNY".to_string(),
            timezone: "Asia/Shanghai".to_string(),
            date_format: "YYYY-MM-DD".to_string(),
            number_format: "1,234.56".to_string(),
            first_day_of_week: 1,
            fiscal_year_start: 1,
            email_notifications: true,
            push_notifications: true,
            budget_alerts: true,
            transaction_alerts: true,
            sidebar_collapsed: false,
            default_account_id: None,
            default_ledger_id: None,
        }
    }
}

impl Session {
    /// 创建新会话
    pub fn new(user_id: Uuid, token: String, expires_in_hours: i64) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            user_id,
            token,
            refresh_token: None,
            device_info: None,
            ip_address: None,
            expires_at: now + chrono::Duration::hours(expires_in_hours),
            created_at: now,
        }
    }

    /// 检查会话是否过期
    pub fn is_expired(&self) -> bool {
        Utc::now() > self.expires_at
    }

    /// 刷新会话
    pub fn refresh(&mut self, new_token: String, expires_in_hours: i64) {
        self.token = new_token;
        self.expires_at = Utc::now() + chrono::Duration::hours(expires_in_hours);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_user_creation() {
        let user = User::new(
            "test@example.com".to_string(),
            "hashed_password".to_string(),
        );

        assert_eq!(user.email, "test@example.com");
        assert_eq!(user.status, UserStatus::Pending);
        assert_eq!(user.role, UserRole::Member);
        assert!(!user.email_verified);
        assert!(!user.mfa_enabled);
    }

    #[test]
    fn test_user_activation() {
        let mut user = User::new(
            "test@example.com".to_string(),
            "hashed_password".to_string(),
        );

        user.activate();

        assert_eq!(user.status, UserStatus::Active);
        assert!(user.email_verified);
    }

    #[test]
    fn test_session_expiry() {
        let session = Session::new(
            Uuid::new_v4(),
            "token".to_string(),
            -1, // 已过期
        );

        assert!(session.is_expired());
    }
}
