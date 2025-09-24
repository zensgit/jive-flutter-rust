//! Category domain model

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use super::{AccountClassification, Entity, SoftDeletable};
use crate::error::{JiveError, Result};

/// 分类实体
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct Category {
    id: String,
    ledger_id: String,
    parent_id: Option<String>,
    name: String,
    description: Option<String>,
    classification: AccountClassification,
    color: String,
    icon: Option<String>,
    is_active: bool,
    is_system: bool, // 系统预置分类
    position: u32,   // 排序位置
    // 统计信息
    transaction_count: u32,
    // 审计字段
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    deleted_at: Option<DateTime<Utc>>,
}

#[cfg_attr(feature = "wasm", wasm_bindgen)]
impl Category {
    #[cfg_attr(feature = "wasm", wasm_bindgen(constructor))]
    pub fn new(
        ledger_id: String,
        name: String,
        classification: AccountClassification,
        color: String,
    ) -> Result<Category> {
        // 验证输入
        if name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Category name cannot be empty".to_string(),
            });
        }

        if name.trim().len() > 50 {
            return Err(JiveError::ValidationError {
                message: "Category name too long (max 50 characters)".to_string(),
            });
        }

        // 验证颜色格式
        if !color.starts_with('#') || color.len() != 7 {
            return Err(JiveError::ValidationError {
                message: "Color must be in hex format (#RRGGBB)".to_string(),
            });
        }

        let now = Utc::now();

        Ok(Category {
            id: crate::utils::generate_id(),
            ledger_id,
            parent_id: None,
            name: name.trim().to_string(),
            description: None,
            classification,
            color,
            icon: None,
            is_active: true,
            is_system: false,
            position: 0,
            transaction_count: 0,
            created_at: now,
            updated_at: now,
            deleted_at: None,
        })
    }

    // Getters
    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn id(&self) -> String {
        self.id.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn ledger_id(&self) -> String {
        self.ledger_id.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn parent_id(&self) -> Option<String> {
        self.parent_id.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn name(&self) -> String {
        self.name.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn description(&self) -> Option<String> {
        self.description.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn classification(&self) -> AccountClassification {
        self.classification.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn color(&self) -> String {
        self.color.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn icon(&self) -> Option<String> {
        self.icon.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn is_active(&self) -> bool {
        self.is_active
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn is_system(&self) -> bool {
        self.is_system
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn position(&self) -> u32 {
        self.position
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn transaction_count(&self) -> u32 {
        self.transaction_count
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn created_at(&self) -> String {
        self.created_at.to_rfc3339()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn updated_at(&self) -> String {
        self.updated_at.to_rfc3339()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn is_deleted(&self) -> bool {
        self.deleted_at.is_some()
    }

    // Setters
    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_name(&mut self, name: String) -> Result<()> {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Category name cannot be empty".to_string(),
            });
        }
        if trimmed.len() > 50 {
            return Err(JiveError::ValidationError {
                message: "Category name too long (max 50 characters)".to_string(),
            });
        }
        self.name = trimmed.to_string();
        self.updated_at = Utc::now();
        Ok(())
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_description(&mut self, description: Option<String>) -> Result<()> {
        if let Some(ref desc) = description {
            crate::utils::Validator::validate_description(desc)?;
        }
        self.description = description;
        self.updated_at = Utc::now();
        Ok(())
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_parent_id(&mut self, parent_id: Option<String>) {
        self.parent_id = parent_id;
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
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

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_icon(&mut self, icon: Option<String>) {
        self.icon = icon;
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_is_active(&mut self, is_active: bool) {
        self.is_active = is_active;
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_position(&mut self, position: u32) {
        self.position = position;
        self.updated_at = Utc::now();
    }

    // 业务方法
    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn increment_transaction_count(&mut self) {
        self.transaction_count += 1;
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn decrement_transaction_count(&mut self) {
        if self.transaction_count > 0 {
            self.transaction_count -= 1;
        }
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn is_income_category(&self) -> bool {
        matches!(self.classification, AccountClassification::Income)
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn is_expense_category(&self) -> bool {
        matches!(self.classification, AccountClassification::Expense)
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn is_parent_category(&self) -> bool {
        self.parent_id.is_none()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn is_child_category(&self) -> bool {
        self.parent_id.is_some()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn can_be_deleted(&self) -> bool {
        !self.is_system && self.transaction_count == 0
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn soft_delete(&mut self) -> Result<()> {
        if self.is_system {
            return Err(JiveError::ValidationError {
                message: "System categories cannot be deleted".to_string(),
            });
        }
        if self.transaction_count > 0 {
            return Err(JiveError::ValidationError {
                message: "Cannot delete category with transactions".to_string(),
            });
        }
        self.deleted_at = Some(Utc::now());
        self.is_active = false;
        self.updated_at = Utc::now();
        Ok(())
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn restore(&mut self) {
        self.deleted_at = None;
        self.is_active = true;
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn get_display_name(&self) -> String {
        if self.is_system {
            format!("{} (系统)", self.name)
        } else {
            self.name.clone()
        }
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn get_classification_display_name(&self) -> String {
        match self.classification {
            AccountClassification::Income => "收入".to_string(),
            AccountClassification::Expense => "支出".to_string(),
            AccountClassification::Asset => "资产".to_string(),
            AccountClassification::Liability => "负债".to_string(),
            AccountClassification::Equity => "权益".to_string(),
        }
    }
}

impl Category {
    /// 从 JSON 创建分类
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

    /// 创建分类的 builder 模式
    pub fn builder() -> CategoryBuilder {
        CategoryBuilder::new()
    }

    /// 创建系统预置分类
    pub fn create_system_category(
        ledger_id: String,
        name: String,
        classification: AccountClassification,
        color: String,
        icon: Option<String>,
        position: u32,
    ) -> Result<Self> {
        let mut category = Self::new(ledger_id, name, classification, color)?;
        category.is_system = true;
        category.icon = icon;
        category.position = position;
        Ok(category)
    }

    /// 获取默认收入分类
    pub fn default_income_categories(ledger_id: String) -> Vec<Self> {
        let categories = [
            ("薪资收入", "#10B981", Some("💰"), 1),
            ("奖金", "#059669", Some("🎁"), 2),
            ("投资收益", "#047857", Some("📈"), 3),
            ("副业收入", "#065F46", Some("💼"), 4),
            ("其他收入", "#064E3B", Some("🔄"), 5),
        ];

        categories
            .iter()
            .map(|(name, color, icon, position)| {
                Self::create_system_category(
                    ledger_id.clone(),
                    name.to_string(),
                    AccountClassification::Income,
                    color.to_string(),
                    icon.map(|s| s.to_string()),
                    *position,
                )
                .unwrap()
            })
            .collect()
    }

    /// 获取默认支出分类
    pub fn default_expense_categories(ledger_id: String) -> Vec<Self> {
        let categories = [
            ("餐饮", "#EF4444", Some("🍽️"), 1),
            ("交通", "#F97316", Some("🚗"), 2),
            ("购物", "#F59E0B", Some("🛍️"), 3),
            ("娱乐", "#EAB308", Some("🎬"), 4),
            ("住房", "#84CC16", Some("🏠"), 5),
            ("医疗", "#22C55E", Some("⚕️"), 6),
            ("教育", "#06B6D4", Some("📚"), 7),
            ("通讯", "#3B82F6", Some("📱"), 8),
            ("其他支出", "#6366F1", Some("🔄"), 9),
        ];

        categories
            .iter()
            .map(|(name, color, icon, position)| {
                Self::create_system_category(
                    ledger_id.clone(),
                    name.to_string(),
                    AccountClassification::Expense,
                    color.to_string(),
                    icon.map(|s| s.to_string()),
                    *position,
                )
                .unwrap()
            })
            .collect()
    }
}

impl Entity for Category {
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

impl SoftDeletable for Category {
    fn is_deleted(&self) -> bool {
        self.deleted_at.is_some()
    }
    fn deleted_at(&self) -> Option<DateTime<Utc>> {
        self.deleted_at
    }
    fn soft_delete(&mut self) {
        self.deleted_at = Some(Utc::now());
    }
    fn restore(&mut self) {
        self.deleted_at = None;
    }
}

/// 分类构建器
pub struct CategoryBuilder {
    ledger_id: Option<String>,
    parent_id: Option<String>,
    name: Option<String>,
    description: Option<String>,
    classification: Option<AccountClassification>,
    color: Option<String>,
    icon: Option<String>,
    position: u32,
    is_system: bool,
}

impl CategoryBuilder {
    pub fn new() -> Self {
        Self {
            ledger_id: None,
            parent_id: None,
            name: None,
            description: None,
            classification: None,
            color: None,
            icon: None,
            position: 0,
            is_system: false,
        }
    }

    pub fn ledger_id(mut self, ledger_id: String) -> Self {
        self.ledger_id = Some(ledger_id);
        self
    }

    pub fn parent_id(mut self, parent_id: String) -> Self {
        self.parent_id = Some(parent_id);
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

    pub fn classification(mut self, classification: AccountClassification) -> Self {
        self.classification = Some(classification);
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

    pub fn position(mut self, position: u32) -> Self {
        self.position = position;
        self
    }

    pub fn is_system(mut self, is_system: bool) -> Self {
        self.is_system = is_system;
        self
    }

    pub fn build(self) -> Result<Category> {
        let ledger_id = self.ledger_id.ok_or_else(|| JiveError::ValidationError {
            message: "Ledger ID is required".to_string(),
        })?;

        let name = self.name.ok_or_else(|| JiveError::ValidationError {
            message: "Category name is required".to_string(),
        })?;

        let classification = self
            .classification
            .ok_or_else(|| JiveError::ValidationError {
                message: "Classification is required".to_string(),
            })?;

        let color = self.color.unwrap_or_else(|| "#6B7280".to_string());

        let mut category = Category::new(ledger_id, name, classification, color)?;

        category.parent_id = self.parent_id;
        if let Some(description) = self.description {
            category.set_description(Some(description))?;
        }
        if let Some(icon) = self.icon {
            category.set_icon(Some(icon));
        }
        category.set_position(self.position);
        category.is_system = self.is_system;

        Ok(category)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_category_creation() {
        let category = Category::new(
            "ledger-123".to_string(),
            "Dining".to_string(),
            AccountClassification::Expense,
            "#EF4444".to_string(),
        )
        .unwrap();

        assert_eq!(category.name(), "Dining");
        assert!(matches!(
            category.classification(),
            AccountClassification::Expense
        ));
        assert_eq!(category.color(), "#EF4444");
        assert!(!category.is_system());
        assert!(category.is_active());
        assert!(category.is_expense_category());
    }

    #[test]
    fn test_category_hierarchy() {
        let parent = Category::new(
            "ledger-123".to_string(),
            "Transportation".to_string(),
            AccountClassification::Expense,
            "#F97316".to_string(),
        )
        .unwrap();

        let mut child = Category::new(
            "ledger-123".to_string(),
            "Gas".to_string(),
            AccountClassification::Expense,
            "#FB923C".to_string(),
        )
        .unwrap();

        child.set_parent_id(Some(parent.id()));

        assert!(parent.is_parent_category());
        assert!(child.is_child_category());
        assert_eq!(child.parent_id(), Some(parent.id()));
    }

    #[test]
    fn test_category_builder() {
        let category = Category::builder()
            .ledger_id("ledger-123".to_string())
            .name("Shopping".to_string())
            .classification(AccountClassification::Expense)
            .color("#F59E0B".to_string())
            .icon("🛍️".to_string())
            .description("Shopping expenses".to_string())
            .position(3)
            .build()
            .unwrap();

        assert_eq!(category.name(), "Shopping");
        assert_eq!(category.icon(), Some("🛍️".to_string()));
        assert_eq!(
            category.description(),
            Some("Shopping expenses".to_string())
        );
        assert_eq!(category.position(), 3);
    }

    #[test]
    fn test_system_categories() {
        let ledger_id = "ledger-123".to_string();

        let income_categories = Category::default_income_categories(ledger_id.clone());
        let expense_categories = Category::default_expense_categories(ledger_id);

        assert!(!income_categories.is_empty());
        assert!(!expense_categories.is_empty());

        for category in income_categories {
            assert!(category.is_system());
            assert!(category.is_income_category());
        }

        for category in expense_categories {
            assert!(category.is_system());
            assert!(category.is_expense_category());
        }
    }

    #[test]
    fn test_transaction_count() {
        let mut category = Category::new(
            "ledger-123".to_string(),
            "Test Category".to_string(),
            AccountClassification::Expense,
            "#6B7280".to_string(),
        )
        .unwrap();

        assert_eq!(category.transaction_count(), 0);
        assert!(category.can_be_deleted());

        category.increment_transaction_count();
        assert_eq!(category.transaction_count(), 1);
        assert!(!category.can_be_deleted());

        category.decrement_transaction_count();
        assert_eq!(category.transaction_count(), 0);
        assert!(category.can_be_deleted());
    }

    #[test]
    fn test_category_validation() {
        // 测试空名称
        assert!(Category::new(
            "ledger-123".to_string(),
            "".to_string(),
            AccountClassification::Expense,
            "#EF4444".to_string(),
        )
        .is_err());

        // 测试无效颜色
        assert!(Category::new(
            "ledger-123".to_string(),
            "Valid Name".to_string(),
            AccountClassification::Expense,
            "invalid-color".to_string(),
        )
        .is_err());
    }
}
