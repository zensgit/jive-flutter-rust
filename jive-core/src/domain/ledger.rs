//! Ledger domain model

use chrono::{DateTime, Utc};
use serde::{Serialize, Deserialize};
use uuid::Uuid;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::error::{JiveError, Result};
use super::{Entity, SoftDeletable};

/// 账本类型枚举
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum LedgerType {
    Personal,
    Business,
    Family,
    Project,
    Travel,
    Investment,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl LedgerType {
    #[wasm_bindgen(getter)]
    pub fn as_string(&self) -> String {
        match self {
            LedgerType::Personal => "personal".to_string(),
            LedgerType::Business => "business".to_string(),
            LedgerType::Family => "family".to_string(),
            LedgerType::Project => "project".to_string(),
            LedgerType::Travel => "travel".to_string(),
            LedgerType::Investment => "investment".to_string(),
        }
    }

    #[wasm_bindgen]
    pub fn from_string(s: &str) -> Option<LedgerType> {
        match s {
            "personal" => Some(LedgerType::Personal),
            "business" => Some(LedgerType::Business),
            "family" => Some(LedgerType::Family),
            "project" => Some(LedgerType::Project),
            "travel" => Some(LedgerType::Travel),
            "investment" => Some(LedgerType::Investment),
            _ => None,
        }
    }
}

/// 账本显示设置
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct LedgerDisplaySettings {
    hide_all_categories: bool,
    show_transfer_flows: bool,
    show_investment_flows: bool,
    show_account_balances: bool,
    group_by_account_type: bool,
    default_currency: String,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl LedgerDisplaySettings {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            hide_all_categories: false,
            show_transfer_flows: true,
            show_investment_flows: true,
            show_account_balances: true,
            group_by_account_type: true,
            default_currency: "USD".to_string(),
        }
    }

    // Getters
    #[wasm_bindgen(getter)]
    pub fn hide_all_categories(&self) -> bool {
        self.hide_all_categories
    }

    #[wasm_bindgen(getter)]
    pub fn show_transfer_flows(&self) -> bool {
        self.show_transfer_flows
    }

    #[wasm_bindgen(getter)]
    pub fn show_investment_flows(&self) -> bool {
        self.show_investment_flows
    }

    #[wasm_bindgen(getter)]
    pub fn show_account_balances(&self) -> bool {
        self.show_account_balances
    }

    #[wasm_bindgen(getter)]
    pub fn group_by_account_type(&self) -> bool {
        self.group_by_account_type
    }

    #[wasm_bindgen(getter)]
    pub fn default_currency(&self) -> String {
        self.default_currency.clone()
    }

    // Setters
    #[wasm_bindgen(setter)]
    pub fn set_hide_all_categories(&mut self, hide: bool) {
        self.hide_all_categories = hide;
    }

    #[wasm_bindgen(setter)]
    pub fn set_show_transfer_flows(&mut self, show: bool) {
        self.show_transfer_flows = show;
    }

    #[wasm_bindgen(setter)]
    pub fn set_show_investment_flows(&mut self, show: bool) {
        self.show_investment_flows = show;
    }

    #[wasm_bindgen(setter)]
    pub fn set_show_account_balances(&mut self, show: bool) {
        self.show_account_balances = show;
    }

    #[wasm_bindgen(setter)]
    pub fn set_group_by_account_type(&mut self, group: bool) {
        self.group_by_account_type = group;
    }

    #[wasm_bindgen(setter)]
    pub fn set_default_currency(&mut self, currency: String) -> Result<()> {
        crate::error::validate_currency(&currency)?;
        self.default_currency = currency;
        Ok(())
    }
}

impl Default for LedgerDisplaySettings {
    fn default() -> Self {
        Self::new()
    }
}

/// 账本实体
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct Ledger {
    id: String,
    user_id: String,
    name: String,
    description: Option<String>,
    ledger_type: LedgerType,
    color: String, // 十六进制颜色代码
    icon: Option<String>, // 图标名称或表情符号
    is_default: bool,
    is_active: bool,
    is_hidden: bool,
    display_settings: LedgerDisplaySettings,
    // 元数据
    transaction_count: u32,
    last_transaction_date: Option<chrono::NaiveDate>,
    // 审计字段
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    deleted_at: Option<DateTime<Utc>>,
    // 权限相关
    is_shared: bool,
    shared_with_users: Vec<String>, // 共享用户ID列表
    permission_level: String, // "read", "write", "admin"
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl Ledger {
    #[wasm_bindgen(constructor)]
    pub fn new(
        user_id: String,
        name: String,
        ledger_type: LedgerType,
        color: String,
    ) -> Result<Ledger> {
        // 验证输入
        if name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Ledger name cannot be empty".to_string(),
            });
        }

        if name.trim().len() > 100 {
            return Err(JiveError::ValidationError {
                message: "Ledger name too long (max 100 characters)".to_string(),
            });
        }

        // 验证颜色格式
        if !color.starts_with('#') || color.len() != 7 {
            return Err(JiveError::ValidationError {
                message: "Color must be in hex format (#RRGGBB)".to_string(),
            });
        }

        let now = Utc::now();

        Ok(Ledger {
            id: crate::utils::generate_id(),
            user_id,
            name: name.trim().to_string(),
            description: None,
            ledger_type,
            color,
            icon: None,
            is_default: false,
            is_active: true,
            is_hidden: false,
            display_settings: LedgerDisplaySettings::default(),
            transaction_count: 0,
            last_transaction_date: None,
            created_at: now,
            updated_at: now,
            deleted_at: None,
            is_shared: false,
            shared_with_users: Vec::new(),
            permission_level: "admin".to_string(),
        })
    }

    // Getters
    #[wasm_bindgen(getter)]
    pub fn id(&self) -> String {
        self.id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn user_id(&self) -> String {
        self.user_id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String {
        self.name.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn description(&self) -> Option<String> {
        self.description.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn ledger_type(&self) -> LedgerType {
        self.ledger_type.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn color(&self) -> String {
        self.color.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn icon(&self) -> Option<String> {
        self.icon.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn is_default(&self) -> bool {
        self.is_default
    }

    #[wasm_bindgen(getter)]
    pub fn is_active(&self) -> bool {
        self.is_active
    }

    #[wasm_bindgen(getter)]
    pub fn is_hidden(&self) -> bool {
        self.is_hidden
    }

    #[wasm_bindgen(getter)]
    pub fn display_settings(&self) -> LedgerDisplaySettings {
        self.display_settings.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn transaction_count(&self) -> u32 {
        self.transaction_count
    }

    #[wasm_bindgen(getter)]
    pub fn last_transaction_date(&self) -> Option<String> {
        self.last_transaction_date.map(|d| d.to_string())
    }

    #[wasm_bindgen(getter)]
    pub fn created_at(&self) -> String {
        self.created_at.to_rfc3339()
    }

    #[wasm_bindgen(getter)]
    pub fn updated_at(&self) -> String {
        self.updated_at.to_rfc3339()
    }

    #[wasm_bindgen(getter)]
    pub fn is_deleted(&self) -> bool {
        self.deleted_at.is_some()
    }

    #[wasm_bindgen(getter)]
    pub fn is_shared(&self) -> bool {
        self.is_shared
    }

    #[wasm_bindgen(getter)]
    pub fn shared_with_users(&self) -> Vec<String> {
        self.shared_with_users.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn permission_level(&self) -> String {
        self.permission_level.clone()
    }

    // Setters
    #[wasm_bindgen(setter)]
    pub fn set_name(&mut self, name: String) -> Result<()> {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Ledger name cannot be empty".to_string(),
            });
        }
        if trimmed.len() > 100 {
            return Err(JiveError::ValidationError {
                message: "Ledger name too long (max 100 characters)".to_string(),
            });
        }
        self.name = trimmed.to_string();
        self.updated_at = Utc::now();
        Ok(())
    }

    #[wasm_bindgen(setter)]
    pub fn set_description(&mut self, description: Option<String>) -> Result<()> {
        if let Some(ref desc) = description {
            crate::utils::Validator::validate_description(desc)?;
        }
        self.description = description;
        self.updated_at = Utc::now();
        Ok(())
    }

    #[wasm_bindgen(setter)]
    pub fn set_color(&mut self, color: String) -> Result<()> {
        if !color.starts_with('#') || color.len() != 7 {
            return Err(JiveError::ValidationError {
                message: "Color must be in hex format (#RRGGBB)".to_string(),
            });
        }
        self.color = color;
        self.updated_at = Utc::now();
        Ok(())
    }

    #[wasm_bindgen(setter)]
    pub fn set_icon(&mut self, icon: Option<String>) {
        self.icon = icon;
        self.updated_at = Utc::now();
    }

    #[wasm_bindgen(setter)]
    pub fn set_is_default(&mut self, is_default: bool) {
        self.is_default = is_default;
        self.updated_at = Utc::now();
    }

    #[wasm_bindgen(setter)]
    pub fn set_is_active(&mut self, is_active: bool) {
        self.is_active = is_active;
        self.updated_at = Utc::now();
    }

    #[wasm_bindgen(setter)]
    pub fn set_is_hidden(&mut self, is_hidden: bool) {
        self.is_hidden = is_hidden;
        self.updated_at = Utc::now();
    }

    #[wasm_bindgen(setter)]
    pub fn set_display_settings(&mut self, settings: LedgerDisplaySettings) {
        self.display_settings = settings;
        self.updated_at = Utc::now();
    }

    // 业务方法
    #[wasm_bindgen]
    pub fn increment_transaction_count(&mut self) {
        self.transaction_count += 1;
        self.updated_at = Utc::now();
    }

    #[wasm_bindgen]
    pub fn decrement_transaction_count(&mut self) {
        if self.transaction_count > 0 {
            self.transaction_count -= 1;
        }
        self.updated_at = Utc::now();
    }

    #[wasm_bindgen]
    pub fn update_last_transaction_date(&mut self, date: String) -> Result<()> {
        let parsed_date = chrono::NaiveDate::parse_from_str(&date, "%Y-%m-%d")
            .map_err(|_| JiveError::InvalidDate { date })?;
        self.last_transaction_date = Some(parsed_date);
        self.updated_at = Utc::now();
        Ok(())
    }

    #[wasm_bindgen]
    pub fn share_with_user(&mut self, user_id: String, permission: String) -> Result<()> {
        if !["read", "write", "admin"].contains(&permission.as_str()) {
            return Err(JiveError::ValidationError {
                message: "Invalid permission level".to_string(),
            });
        }

        if !self.shared_with_users.contains(&user_id) {
            self.shared_with_users.push(user_id);
            self.is_shared = true;
            self.updated_at = Utc::now();
        }
        Ok(())
    }

    #[wasm_bindgen]
    pub fn unshare_with_user(&mut self, user_id: String) {
        if let Some(pos) = self.shared_with_users.iter().position(|u| u == &user_id) {
            self.shared_with_users.remove(pos);
            if self.shared_with_users.is_empty() {
                self.is_shared = false;
            }
            self.updated_at = Utc::now();
        }
    }

    #[wasm_bindgen]
    pub fn can_user_access(&self, user_id: String) -> bool {
        self.user_id == user_id || self.shared_with_users.contains(&user_id)
    }

    #[wasm_bindgen]
    pub fn can_user_write(&self, user_id: String) -> bool {
        if self.user_id == user_id {
            return true;
        }
        self.shared_with_users.contains(&user_id) && 
        (self.permission_level == "write" || self.permission_level == "admin")
    }

    #[wasm_bindgen]
    pub fn soft_delete(&mut self) {
        self.deleted_at = Some(Utc::now());
        self.is_active = false;
        self.updated_at = Utc::now();
    }

    #[wasm_bindgen]
    pub fn restore(&mut self) {
        self.deleted_at = None;
        self.is_active = true;
        self.updated_at = Utc::now();
    }

    #[wasm_bindgen]
    pub fn is_visible(&self) -> bool {
        self.is_active && !self.is_hidden && !self.is_deleted()
    }

    #[wasm_bindgen]
    pub fn get_display_name(&self) -> String {
        if self.is_default {
            format!("{} (默认)", self.name)
        } else {
            self.name.clone()
        }
    }

    #[wasm_bindgen]
    pub fn get_type_display_name(&self) -> String {
        match self.ledger_type {
            LedgerType::Personal => "个人账本".to_string(),
            LedgerType::Business => "商务账本".to_string(),
            LedgerType::Family => "家庭账本".to_string(),
            LedgerType::Project => "项目账本".to_string(),
            LedgerType::Travel => "旅行账本".to_string(),
            LedgerType::Investment => "投资账本".to_string(),
        }
    }

    /// 获取统计摘要
    #[wasm_bindgen]
    pub fn get_summary(&self) -> String {
        format!(
            "{} transactions, last activity: {}",
            self.transaction_count,
            self.last_transaction_date
                .map(|d| d.to_string())
                .unwrap_or_else(|| "never".to_string())
        )
    }
}

impl Ledger {
    /// 从 JSON 创建账本
    pub fn from_json(json: &str) -> Result<Self> {
        serde_json::from_str(json).map_err(|e| JiveError::SerializationError {
            message: e.to_string(),
        })
    }

    /// 转换为 JSON
    pub fn to_json(&self) -> Result<String> {
        serde_json::to_string(self).map_err(|e| JiveError::SerializationError {
            message: e.to_string(),
        })
    }

    /// 创建账本的 builder 模式
    pub fn builder() -> LedgerBuilder {
        LedgerBuilder::new()
    }

    /// 复制账本（新ID）
    pub fn duplicate(&self, new_name: String) -> Result<Self> {
        let mut duplicate = self.clone();
        duplicate.id = crate::utils::generate_id();
        duplicate.name = new_name;
        duplicate.is_default = false;
        duplicate.transaction_count = 0;
        duplicate.last_transaction_date = None;
        duplicate.created_at = Utc::now();
        duplicate.updated_at = Utc::now();
        duplicate.deleted_at = None;
        duplicate.is_shared = false;
        duplicate.shared_with_users.clear();
        Ok(duplicate)
    }
}

impl Entity for Ledger {
    type Id = String;

    fn id(&self) -> &Self::Id {
        &self.id
    }

    fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }

    fn updated_at(&self) -> DateTime<Utc> {
        self.updated_at
    }
}

impl SoftDeletable for Ledger {
    fn is_deleted(&self) -> bool {
        self.deleted_at.is_some()
    }

    fn deleted_at(&self) -> Option<DateTime<Utc>> {
        self.deleted_at
    }

    fn soft_delete(&mut self) {
        self.soft_delete();
    }

    fn restore(&mut self) {
        self.restore();
    }
}

/// 账本构建器
pub struct LedgerBuilder {
    user_id: Option<String>,
    name: Option<String>,
    description: Option<String>,
    ledger_type: Option<LedgerType>,
    color: Option<String>,
    icon: Option<String>,
    is_default: bool,
    display_settings: Option<LedgerDisplaySettings>,
}

impl LedgerBuilder {
    pub fn new() -> Self {
        Self {
            user_id: None,
            name: None,
            description: None,
            ledger_type: None,
            color: None,
            icon: None,
            is_default: false,
            display_settings: None,
        }
    }

    pub fn user_id(mut self, user_id: String) -> Self {
        self.user_id = Some(user_id);
        self
    }

    pub fn name(mut self, name: String) -> Self {
        self.name = Some(name);
        self
    }

    pub fn description(mut self, description: String) -> Self {
        self.description = Some(description);
        self
    }

    pub fn ledger_type(mut self, ledger_type: LedgerType) -> Self {
        self.ledger_type = Some(ledger_type);
        self
    }

    pub fn color(mut self, color: String) -> Self {
        self.color = Some(color);
        self
    }

    pub fn icon(mut self, icon: String) -> Self {
        self.icon = Some(icon);
        self
    }

    pub fn is_default(mut self, is_default: bool) -> Self {
        self.is_default = is_default;
        self
    }

    pub fn display_settings(mut self, settings: LedgerDisplaySettings) -> Self {
        self.display_settings = Some(settings);
        self
    }

    pub fn build(self) -> Result<Ledger> {
        let user_id = self.user_id.ok_or_else(|| JiveError::ValidationError {
            message: "User ID is required".to_string(),
        })?;

        let name = self.name.ok_or_else(|| JiveError::ValidationError {
            message: "Ledger name is required".to_string(),
        })?;

        let ledger_type = self.ledger_type.ok_or_else(|| JiveError::ValidationError {
            message: "Ledger type is required".to_string(),
        })?;

        let color = self.color.unwrap_or_else(|| "#3B82F6".to_string());

        let mut ledger = Ledger::new(user_id, name, ledger_type, color)?;
        
        if let Some(description) = self.description {
            ledger.set_description(Some(description))?;
        }

        if let Some(icon) = self.icon {
            ledger.set_icon(Some(icon));
        }

        ledger.set_is_default(self.is_default);

        if let Some(settings) = self.display_settings {
            ledger.set_display_settings(settings);
        }

        Ok(ledger)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ledger_creation() {
        let ledger = Ledger::new(
            "user-123".to_string(),
            "My Personal Ledger".to_string(),
            LedgerType::Personal,
            "#3B82F6".to_string(),
        ).unwrap();

        assert_eq!(ledger.name(), "My Personal Ledger");
        assert!(matches!(ledger.ledger_type(), LedgerType::Personal));
        assert_eq!(ledger.color(), "#3B82F6");
        assert!(!ledger.is_default());
        assert!(ledger.is_active());
        assert!(!ledger.is_hidden());
    }

    #[test]
    fn test_ledger_display_settings() {
        let mut settings = LedgerDisplaySettings::new();
        assert!(!settings.hide_all_categories());
        assert!(settings.show_transfer_flows());

        settings.set_hide_all_categories(true);
        settings.set_show_transfer_flows(false);
        assert!(settings.hide_all_categories());
        assert!(!settings.show_transfer_flows());

        settings.set_default_currency("EUR".to_string()).unwrap();
        assert_eq!(settings.default_currency(), "EUR");
    }

    #[test]
    fn test_ledger_sharing() {
        let mut ledger = Ledger::new(
            "user-123".to_string(),
            "Shared Ledger".to_string(),
            LedgerType::Family,
            "#FF6B6B".to_string(),
        ).unwrap();

        assert!(!ledger.is_shared());
        
        ledger.share_with_user("user-456".to_string(), "write".to_string()).unwrap();
        assert!(ledger.is_shared());
        assert!(ledger.can_user_access("user-456".to_string()));
        assert!(ledger.can_user_write("user-456".to_string()));

        ledger.unshare_with_user("user-456".to_string());
        assert!(!ledger.is_shared());
        assert!(!ledger.can_user_access("user-456".to_string()));
    }

    #[test]
    fn test_ledger_builder() {
        let ledger = Ledger::builder()
            .user_id("user-123".to_string())
            .name("Project Alpha".to_string())
            .ledger_type(LedgerType::Project)
            .color("#FF6B6B".to_string())
            .description("Project tracking ledger".to_string())
            .icon("📊".to_string())
            .is_default(true)
            .build()
            .unwrap();

        assert_eq!(ledger.name(), "Project Alpha");
        assert!(matches!(ledger.ledger_type(), LedgerType::Project));
        assert_eq!(ledger.description(), Some("Project tracking ledger".to_string()));
        assert_eq!(ledger.icon(), Some("📊".to_string()));
        assert!(ledger.is_default());
    }

    #[test]
    fn test_transaction_count() {
        let mut ledger = Ledger::new(
            "user-123".to_string(),
            "Test Ledger".to_string(),
            LedgerType::Personal,
            "#3B82F6".to_string(),
        ).unwrap();

        assert_eq!(ledger.transaction_count(), 0);

        ledger.increment_transaction_count();
        assert_eq!(ledger.transaction_count(), 1);

        ledger.increment_transaction_count();
        assert_eq!(ledger.transaction_count(), 2);

        ledger.decrement_transaction_count();
        assert_eq!(ledger.transaction_count(), 1);
    }

    #[test]
    fn test_ledger_validation() {
        // 测试空名称
        assert!(Ledger::new(
            "user-123".to_string(),
            "".to_string(),
            LedgerType::Personal,
            "#3B82F6".to_string(),
        ).is_err());

        // 测试无效颜色
        assert!(Ledger::new(
            "user-123".to_string(),
            "Valid Name".to_string(),
            LedgerType::Personal,
            "invalid-color".to_string(),
        ).is_err());
    }
}