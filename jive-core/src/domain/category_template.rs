//! 系统分类模板领域模型
//! 
//! 实现三层分类架构中的第一层：系统预设分类模板

use chrono::{DateTime, Utc};
use serde::{Serialize, Deserialize};
use std::collections::HashMap;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::error::{JiveError, Result};
use super::{Entity, AccountClassification};

/// 分类组
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum CategoryGroup {
    Income,                // 收入类别
    DailyExpense,         // 日常消费
    Housing,              // 居住相关
    Transportation,       // 交通出行
    HealthEducation,      // 健康教育
    EntertainmentSocial,  // 娱乐社交
    Financial,            // 金融理财
    Business,             // 商务办公
    Other,                // 其他
}

impl CategoryGroup {
    pub fn key(&self) -> &str {
        match self {
            CategoryGroup::Income => "income",
            CategoryGroup::DailyExpense => "daily_expense",
            CategoryGroup::Housing => "housing",
            CategoryGroup::Transportation => "transportation",
            CategoryGroup::HealthEducation => "health_education",
            CategoryGroup::EntertainmentSocial => "entertainment_social",
            CategoryGroup::Financial => "financial",
            CategoryGroup::Business => "business",
            CategoryGroup::Other => "other",
        }
    }

    pub fn display_name(&self) -> &str {
        match self {
            CategoryGroup::Income => "收入类别",
            CategoryGroup::DailyExpense => "日常消费",
            CategoryGroup::Housing => "居住相关",
            CategoryGroup::Transportation => "交通出行",
            CategoryGroup::HealthEducation => "健康教育",
            CategoryGroup::EntertainmentSocial => "娱乐社交",
            CategoryGroup::Financial => "金融理财",
            CategoryGroup::Business => "商务办公",
            CategoryGroup::Other => "其他",
        }
    }

    pub fn display_name_en(&self) -> &str {
        match self {
            CategoryGroup::Income => "Income",
            CategoryGroup::DailyExpense => "Daily Expenses",
            CategoryGroup::Housing => "Housing",
            CategoryGroup::Transportation => "Transportation",
            CategoryGroup::HealthEducation => "Health & Education",
            CategoryGroup::EntertainmentSocial => "Entertainment & Social",
            CategoryGroup::Financial => "Financial",
            CategoryGroup::Business => "Business",
            CategoryGroup::Other => "Other",
        }
    }

    pub fn icon(&self) -> &str {
        match self {
            CategoryGroup::Income => "💰",
            CategoryGroup::DailyExpense => "🛒",
            CategoryGroup::Housing => "🏠",
            CategoryGroup::Transportation => "🚗",
            CategoryGroup::HealthEducation => "🏥",
            CategoryGroup::EntertainmentSocial => "🎬",
            CategoryGroup::Financial => "💳",
            CategoryGroup::Business => "💼",
            CategoryGroup::Other => "📦",
        }
    }

    pub fn from_string(s: &str) -> Option<CategoryGroup> {
        match s {
            "income" => Some(CategoryGroup::Income),
            "daily_expense" => Some(CategoryGroup::DailyExpense),
            "housing" => Some(CategoryGroup::Housing),
            "transportation" => Some(CategoryGroup::Transportation),
            "health_education" => Some(CategoryGroup::HealthEducation),
            "entertainment_social" => Some(CategoryGroup::EntertainmentSocial),
            "financial" => Some(CategoryGroup::Financial),
            "business" => Some(CategoryGroup::Business),
            "other" => Some(CategoryGroup::Other),
            _ => None,
        }
    }
}

/// 系统分类模板
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct SystemCategoryTemplate {
    id: String,
    // 基础信息
    name: String,
    name_en: Option<String>,
    name_zh: Option<String>,
    description: Option<String>,
    
    // 分类属性
    classification: AccountClassification,
    color: String,
    icon: Option<String>,
    category_group: CategoryGroup,
    
    // 元数据
    version: String,
    is_active: bool,
    is_featured: bool,
    global_usage_count: u32,
    tags: Vec<String>,
    
    // 审计字段
    created_by: Option<String>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

#[cfg_attr(feature = "wasm", wasm_bindgen)]
impl SystemCategoryTemplate {
    #[cfg_attr(feature = "wasm", wasm_bindgen(constructor))]
    pub fn new(
        name: String,
        classification: AccountClassification,
        color: String,
        category_group: CategoryGroup,
    ) -> Result<SystemCategoryTemplate> {
        // 验证输入
        if name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Template name cannot be empty".to_string(),
            });
        }

        // 验证颜色格式
        if !color.starts_with('#') || color.len() != 7 {
            return Err(JiveError::ValidationError {
                message: "Color must be in hex format (#RRGGBB)".to_string(),
            });
        }

        let now = Utc::now();

        Ok(SystemCategoryTemplate {
            id: crate::utils::generate_id(),
            name: name.trim().to_string(),
            name_en: None,
            name_zh: None,
            description: None,
            classification,
            color,
            icon: None,
            category_group,
            version: "1.0.0".to_string(),
            is_active: true,
            is_featured: false,
            global_usage_count: 0,
            tags: Vec::new(),
            created_by: None,
            created_at: now,
            updated_at: now,
        })
    }

    // Getters
    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn id(&self) -> String {
        self.id.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn name(&self) -> String {
        self.name.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn name_en(&self) -> Option<String> {
        self.name_en.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn name_zh(&self) -> Option<String> {
        self.name_zh.clone()
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
    pub fn category_group(&self) -> CategoryGroup {
        self.category_group.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn version(&self) -> String {
        self.version.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn is_active(&self) -> bool {
        self.is_active
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn is_featured(&self) -> bool {
        self.is_featured
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn global_usage_count(&self) -> u32 {
        self.global_usage_count
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn tags(&self) -> Vec<String> {
        self.tags.clone()
    }

    // 业务方法
    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn increment_usage_count(&mut self) {
        self.global_usage_count += 1;
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn set_featured(&mut self, featured: bool) {
        self.is_featured = featured;
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn add_tag(&mut self, tag: String) {
        if !self.tags.contains(&tag) {
            self.tags.push(tag);
            self.updated_at = Utc::now();
        }
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn remove_tag(&mut self, tag: &str) {
        self.tags.retain(|t| t != tag);
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn has_tag(&self, tag: &str) -> bool {
        self.tags.iter().any(|t| t == tag)
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn get_display_name(&self, language: &str) -> String {
        match language {
            "en" => self.name_en.clone().unwrap_or_else(|| self.name.clone()),
            "zh" => self.name_zh.clone().unwrap_or_else(|| self.name.clone()),
            _ => self.name.clone(),
        }
    }
}

impl SystemCategoryTemplate {
    /// 创建模板构建器
    pub fn builder() -> TemplateBuilder {
        TemplateBuilder::new()
    }

    /// 获取所有预设模板
    pub fn get_all_templates() -> Vec<SystemCategoryTemplate> {
        let mut templates = Vec::new();
        
        // 收入类模板
        templates.extend(Self::get_income_templates());
        
        // 日常消费模板
        templates.extend(Self::get_daily_expense_templates());
        
        // 交通出行模板
        templates.extend(Self::get_transportation_templates());
        
        // 居住相关模板
        templates.extend(Self::get_housing_templates());
        
        // 健康教育模板
        templates.extend(Self::get_health_education_templates());
        
        // 娱乐社交模板
        templates.extend(Self::get_entertainment_templates());
        
        // 金融理财模板
        templates.extend(Self::get_financial_templates());
        
        templates
    }

    /// 获取收入类模板
    pub fn get_income_templates() -> Vec<SystemCategoryTemplate> {
        vec![
            Self::builder()
                .name("工资收入".to_string())
                .name_en("Salary".to_string())
                .classification(AccountClassification::Income)
                .color("#10B981".to_string())
                .icon("💰".to_string())
                .category_group(CategoryGroup::Income)
                .is_featured(true)
                .tags(vec!["必备".to_string(), "常用".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("奖金收入".to_string())
                .name_en("Bonus".to_string())
                .classification(AccountClassification::Income)
                .color("#059669".to_string())
                .icon("🎁".to_string())
                .category_group(CategoryGroup::Income)
                .is_featured(true)
                .tags(vec!["常用".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("投资收益".to_string())
                .name_en("Investment Income".to_string())
                .classification(AccountClassification::Income)
                .color("#047857".to_string())
                .icon("📈".to_string())
                .category_group(CategoryGroup::Income)
                .tags(vec!["理财".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("副业收入".to_string())
                .name_en("Side Income".to_string())
                .classification(AccountClassification::Income)
                .color("#065F46".to_string())
                .icon("💼".to_string())
                .category_group(CategoryGroup::Income)
                .tags(vec!["兼职".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("其他收入".to_string())
                .name_en("Other Income".to_string())
                .classification(AccountClassification::Income)
                .color("#134E4A".to_string())
                .icon("📥".to_string())
                .category_group(CategoryGroup::Income)
                .tags(vec!["其他".to_string()])
                .build().unwrap(),
        ]
    }

    /// 获取日常消费模板
    pub fn get_daily_expense_templates() -> Vec<SystemCategoryTemplate> {
        vec![
            Self::builder()
                .name("餐饮美食".to_string())
                .name_en("Food & Dining".to_string())
                .classification(AccountClassification::Expense)
                .color("#EF4444".to_string())
                .icon("🍽️".to_string())
                .category_group(CategoryGroup::DailyExpense)
                .is_featured(true)
                .tags(vec!["热门".to_string(), "必备".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("买菜".to_string())
                .name_en("Groceries".to_string())
                .classification(AccountClassification::Expense)
                .color("#FCD34D".to_string())
                .icon("🥬".to_string())
                .category_group(CategoryGroup::DailyExpense)
                .is_featured(true)
                .tags(vec!["必备".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("日用品".to_string())
                .name_en("Daily Necessities".to_string())
                .classification(AccountClassification::Expense)
                .color("#FDE047".to_string())
                .icon("🧻".to_string())
                .category_group(CategoryGroup::DailyExpense)
                .is_featured(true)
                .tags(vec!["必备".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("服装鞋包".to_string())
                .name_en("Clothing & Shoes".to_string())
                .classification(AccountClassification::Expense)
                .color("#FACC15".to_string())
                .icon("👔".to_string())
                .category_group(CategoryGroup::DailyExpense)
                .is_featured(true)
                .tags(vec!["购物".to_string()])
                .build().unwrap(),
        ]
    }

    /// 获取交通出行模板
    pub fn get_transportation_templates() -> Vec<SystemCategoryTemplate> {
        vec![
            Self::builder()
                .name("公共交通".to_string())
                .name_en("Public Transport".to_string())
                .classification(AccountClassification::Expense)
                .color("#F97316".to_string())
                .icon("🚇".to_string())
                .category_group(CategoryGroup::Transportation)
                .is_featured(true)
                .tags(vec!["必备".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("打车".to_string())
                .name_en("Taxi/Ride".to_string())
                .classification(AccountClassification::Expense)
                .color("#FB923C".to_string())
                .icon("🚕".to_string())
                .category_group(CategoryGroup::Transportation)
                .is_featured(true)
                .tags(vec!["热门".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("加油".to_string())
                .name_en("Gas/Fuel".to_string())
                .classification(AccountClassification::Expense)
                .color("#FDBA74".to_string())
                .icon("⛽".to_string())
                .category_group(CategoryGroup::Transportation)
                .is_featured(true)
                .tags(vec!["车辆".to_string()])
                .build().unwrap(),
        ]
    }

    /// 获取居住相关模板
    pub fn get_housing_templates() -> Vec<SystemCategoryTemplate> {
        vec![
            Self::builder()
                .name("房租".to_string())
                .name_en("Rent".to_string())
                .classification(AccountClassification::Expense)
                .color("#8B5CF6".to_string())
                .icon("🏠".to_string())
                .category_group(CategoryGroup::Housing)
                .is_featured(true)
                .tags(vec!["必备".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("水电费".to_string())
                .name_en("Utilities".to_string())
                .classification(AccountClassification::Expense)
                .color("#C4B5FD".to_string())
                .icon("💡".to_string())
                .category_group(CategoryGroup::Housing)
                .is_featured(true)
                .tags(vec!["必备".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("网费".to_string())
                .name_en("Internet".to_string())
                .classification(AccountClassification::Expense)
                .color("#EDE9FE".to_string())
                .icon("🌐".to_string())
                .category_group(CategoryGroup::Housing)
                .is_featured(true)
                .tags(vec!["必备".to_string()])
                .build().unwrap(),
        ]
    }

    /// 获取健康教育模板
    pub fn get_health_education_templates() -> Vec<SystemCategoryTemplate> {
        vec![
            Self::builder()
                .name("医疗费".to_string())
                .name_en("Medical".to_string())
                .classification(AccountClassification::Expense)
                .color("#DC2626".to_string())
                .icon("🏥".to_string())
                .category_group(CategoryGroup::HealthEducation)
                .is_featured(true)
                .tags(vec!["重要".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("教育培训".to_string())
                .name_en("Education".to_string())
                .classification(AccountClassification::Expense)
                .color("#0EA5E9".to_string())
                .icon("📚".to_string())
                .category_group(CategoryGroup::HealthEducation)
                .is_featured(true)
                .tags(vec!["学习".to_string()])
                .build().unwrap(),
        ]
    }

    /// 获取娱乐社交模板
    pub fn get_entertainment_templates() -> Vec<SystemCategoryTemplate> {
        vec![
            Self::builder()
                .name("电影".to_string())
                .name_en("Movies".to_string())
                .classification(AccountClassification::Expense)
                .color("#7C3AED".to_string())
                .icon("🎬".to_string())
                .category_group(CategoryGroup::EntertainmentSocial)
                .is_featured(true)
                .tags(vec!["热门".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("旅游".to_string())
                .name_en("Travel".to_string())
                .classification(AccountClassification::Expense)
                .color("#C4B5FD".to_string())
                .icon("🌍".to_string())
                .category_group(CategoryGroup::EntertainmentSocial)
                .is_featured(true)
                .tags(vec!["热门".to_string()])
                .build().unwrap(),
        ]
    }

    /// 获取金融理财模板
    pub fn get_financial_templates() -> Vec<SystemCategoryTemplate> {
        vec![
            Self::builder()
                .name("投资理财".to_string())
                .name_en("Investment".to_string())
                .classification(AccountClassification::Expense)
                .color("#059669".to_string())
                .icon("📈".to_string())
                .category_group(CategoryGroup::Financial)
                .is_featured(true)
                .tags(vec!["理财".to_string()])
                .build().unwrap(),
            
            Self::builder()
                .name("保险".to_string())
                .name_en("Insurance".to_string())
                .classification(AccountClassification::Expense)
                .color("#10B981".to_string())
                .icon("🛡️".to_string())
                .category_group(CategoryGroup::Financial)
                .is_featured(true)
                .tags(vec!["保障".to_string()])
                .build().unwrap(),
        ]
    }

    /// 根据分组获取模板
    pub fn get_templates_by_group(group: CategoryGroup) -> Vec<SystemCategoryTemplate> {
        Self::get_all_templates()
            .into_iter()
            .filter(|t| t.category_group == group)
            .collect()
    }

    /// 根据分类类型获取模板
    pub fn get_templates_by_classification(classification: AccountClassification) -> Vec<SystemCategoryTemplate> {
        Self::get_all_templates()
            .into_iter()
            .filter(|t| t.classification == classification)
            .collect()
    }

    /// 获取推荐模板
    pub fn get_featured_templates() -> Vec<SystemCategoryTemplate> {
        Self::get_all_templates()
            .into_iter()
            .filter(|t| t.is_featured)
            .collect()
    }

    /// 搜索模板
    pub fn search_templates(query: &str) -> Vec<SystemCategoryTemplate> {
        let query_lower = query.to_lowercase();
        Self::get_all_templates()
            .into_iter()
            .filter(|t| {
                t.name.to_lowercase().contains(&query_lower) ||
                t.name_en.as_ref().map_or(false, |n| n.to_lowercase().contains(&query_lower)) ||
                t.tags.iter().any(|tag| tag.to_lowercase().contains(&query_lower))
            })
            .collect()
    }
}

impl Entity for SystemCategoryTemplate {
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

/// 模板构建器
pub struct TemplateBuilder {
    name: Option<String>,
    name_en: Option<String>,
    name_zh: Option<String>,
    description: Option<String>,
    classification: Option<AccountClassification>,
    color: Option<String>,
    icon: Option<String>,
    category_group: Option<CategoryGroup>,
    version: String,
    is_featured: bool,
    tags: Vec<String>,
}

impl TemplateBuilder {
    pub fn new() -> Self {
        Self {
            name: None,
            name_en: None,
            name_zh: None,
            description: None,
            classification: None,
            color: None,
            icon: None,
            category_group: None,
            version: "1.0.0".to_string(),
            is_featured: false,
            tags: Vec::new(),
        }
    }

    pub fn name(mut self, name: String) -> Self {
        self.name = Some(name);
        self
    }

    pub fn name_en(mut self, name_en: String) -> Self {
        self.name_en = Some(name_en);
        self
    }

    pub fn name_zh(mut self, name_zh: String) -> Self {
        self.name_zh = Some(name_zh);
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

    pub fn category_group(mut self, group: CategoryGroup) -> Self {
        self.category_group = Some(group);
        self
    }

    pub fn version(mut self, version: String) -> Self {
        self.version = version;
        self
    }

    pub fn is_featured(mut self, featured: bool) -> Self {
        self.is_featured = featured;
        self
    }

    pub fn tags(mut self, tags: Vec<String>) -> Self {
        self.tags = tags;
        self
    }

    pub fn build(self) -> Result<SystemCategoryTemplate> {
        let name = self.name.ok_or_else(|| JiveError::ValidationError {
            message: "Template name is required".to_string(),
        })?;

        let classification = self.classification.ok_or_else(|| JiveError::ValidationError {
            message: "Classification is required".to_string(),
        })?;

        let color = self.color.unwrap_or_else(|| "#6B7280".to_string());

        let category_group = self.category_group.ok_or_else(|| JiveError::ValidationError {
            message: "Category group is required".to_string(),
        })?;

        let template = SystemCategoryTemplate::new(name, classification, color, category_group)?;
        
        Ok(SystemCategoryTemplate {
            name_en: self.name_en,
            name_zh: self.name_zh.or_else(|| Some(template.name.clone())),
            description: self.description,
            icon: self.icon,
            version: self.version,
            is_featured: self.is_featured,
            tags: self.tags,
            ..template
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_template_creation() {
        let template = SystemCategoryTemplate::new(
            "Test Template".to_string(),
            AccountClassification::Expense,
            "#FF0000".to_string(),
            CategoryGroup::DailyExpense,
        ).unwrap();

        assert_eq!(template.name(), "Test Template");
        assert_eq!(template.color(), "#FF0000");
        assert!(matches!(template.category_group(), CategoryGroup::DailyExpense));
    }

    #[test]
    fn test_template_builder() {
        let template = SystemCategoryTemplate::builder()
            .name("餐饮美食".to_string())
            .name_en("Food & Dining".to_string())
            .classification(AccountClassification::Expense)
            .color("#EF4444".to_string())
            .icon("🍽️".to_string())
            .category_group(CategoryGroup::DailyExpense)
            .is_featured(true)
            .tags(vec!["热门".to_string(), "必备".to_string()])
            .build()
            .unwrap();

        assert_eq!(template.name(), "餐饮美食");
        assert_eq!(template.name_en(), Some("Food & Dining".to_string()));
        assert!(template.is_featured());
        assert_eq!(template.tags().len(), 2);
    }

    #[test]
    fn test_get_all_templates() {
        let templates = SystemCategoryTemplate::get_all_templates();
        assert!(!templates.is_empty());
        
        // 验证包含各种类型的模板
        let has_income = templates.iter().any(|t| matches!(t.classification, AccountClassification::Income));
        let has_expense = templates.iter().any(|t| matches!(t.classification, AccountClassification::Expense));
        
        assert!(has_income);
        assert!(has_expense);
    }

    #[test]
    fn test_get_templates_by_group() {
        let income_templates = SystemCategoryTemplate::get_templates_by_group(CategoryGroup::Income);
        assert!(!income_templates.is_empty());
        
        for template in income_templates {
            assert!(matches!(template.category_group, CategoryGroup::Income));
        }
    }

    #[test]
    fn test_search_templates() {
        let results = SystemCategoryTemplate::search_templates("餐饮");
        assert!(!results.is_empty());
        
        let results_en = SystemCategoryTemplate::search_templates("food");
        assert!(!results_en.is_empty());
    }

    #[test]
    fn test_featured_templates() {
        let featured = SystemCategoryTemplate::get_featured_templates();
        assert!(!featured.is_empty());
        
        for template in featured {
            assert!(template.is_featured());
        }
    }

    #[test]
    fn test_category_group_conversion() {
        let group = CategoryGroup::from_string("income");
        assert!(matches!(group, Some(CategoryGroup::Income)));
        
        let group = CategoryGroup::from_string("invalid");
        assert!(group.is_none());
    }
}
