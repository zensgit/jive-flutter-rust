//! Quick Transaction Service - 快速记账服务
//! 
//! 基于 Maybe 的 QuickTransaction 实现，提供便捷的记账入口

use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc, NaiveDate};
use rust_decimal::Decimal;
use uuid::Uuid;

use crate::domain::{Transaction, TransactionType, Account, Category, Payee};
use crate::error::{JiveError, Result};
use crate::application::{ServiceContext, ServiceResponse};

/// 快速交易
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuickTransaction {
    pub id: String,
    pub family_id: String,
    pub user_id: String,
    pub amount: Decimal,
    pub currency: String,
    pub date: NaiveDate,
    pub description: String,
    pub transaction_type: QuickTransactionType,
    
    // 智能分类
    pub category_name: Option<String>,
    pub category_id: Option<String>,
    pub suggested_category_id: Option<String>,
    
    // 商户/收款人
    pub payee_name: Option<String>,
    pub payee_id: Option<String>,
    pub suggested_payee_id: Option<String>,
    
    // 标签
    pub tags: Vec<String>,
    
    // 附件
    pub attachments: Vec<String>,
    pub receipt_url: Option<String>,
    
    // 增强字段
    pub location: Option<String>,
    pub notes: Option<String>,
    pub is_reimbursable: bool,
    pub reimbursement_status: Option<String>,
    
    // 元数据
    pub created_at: DateTime<Utc>,
    pub converted_at: Option<DateTime<Utc>>,
    pub is_converted: bool,
}

/// 快速交易类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum QuickTransactionType {
    Expense,
    Income,
    Transfer,
}

/// 快速记账请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuickRecordRequest {
    pub amount: String,
    pub description: String,
    pub transaction_type: QuickTransactionType,
    pub date: Option<String>,  // 默认今天
    pub category_name: Option<String>,
    pub payee_name: Option<String>,
    pub tags: Option<Vec<String>>,
    pub account_id: Option<String>,  // 默认使用最常用账户
    pub notes: Option<String>,
    pub location: Option<String>,
    pub is_reimbursable: Option<bool>,
    pub attachment_urls: Option<Vec<String>>,
}

/// 智能建议
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SmartSuggestions {
    pub suggested_category: Option<CategorySuggestion>,
    pub suggested_payee: Option<PayeeSuggestion>,
    pub suggested_account: Option<AccountSuggestion>,
    pub suggested_tags: Vec<String>,
    pub recent_similar_transactions: Vec<SimilarTransaction>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategorySuggestion {
    pub category_id: String,
    pub category_name: String,
    pub confidence: f32,  // 0.0 - 1.0
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PayeeSuggestion {
    pub payee_id: String,
    pub payee_name: String,
    pub last_used: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountSuggestion {
    pub account_id: String,
    pub account_name: String,
    pub usage_frequency: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimilarTransaction {
    pub id: String,
    pub date: NaiveDate,
    pub amount: Decimal,
    pub description: String,
    pub category_name: String,
    pub similarity_score: f32,
}

/// 快速记账服务
pub struct QuickTransactionService {
    // 依赖注入
}

impl QuickTransactionService {
    pub fn new() -> Self {
        Self {}
    }
    
    /// 快速记录交易
    pub async fn quick_record(
        &self,
        context: ServiceContext,
        request: QuickRecordRequest,
    ) -> Result<ServiceResponse<QuickTransaction>> {
        // 1. 解析金额
        let amount = Decimal::from_str_exact(&request.amount)
            .map_err(|_| JiveError::ValidationError("Invalid amount format".into()))?;
        
        // 2. 获取智能建议
        let suggestions = self.get_smart_suggestions(&context, &request).await?;
        
        // 3. 创建快速交易记录
        let quick_tx = QuickTransaction {
            id: Uuid::new_v4().to_string(),
            family_id: context.family_id.clone(),
            user_id: context.user_id.clone(),
            amount,
            currency: "USD".to_string(),  // TODO: 从 Family 设置获取
            date: request.date
                .and_then(|d| NaiveDate::parse_from_str(&d, "%Y-%m-%d").ok())
                .unwrap_or_else(|| Utc::now().date_naive()),
            description: request.description.clone(),
            transaction_type: request.transaction_type,
            category_name: request.category_name.clone(),
            category_id: suggestions.suggested_category.as_ref().map(|c| c.category_id.clone()),
            suggested_category_id: suggestions.suggested_category.as_ref().map(|c| c.category_id.clone()),
            payee_name: request.payee_name.clone(),
            payee_id: suggestions.suggested_payee.as_ref().map(|p| p.payee_id.clone()),
            suggested_payee_id: suggestions.suggested_payee.as_ref().map(|p| p.payee_id.clone()),
            tags: request.tags.unwrap_or_default(),
            attachments: request.attachment_urls.unwrap_or_default(),
            receipt_url: None,
            location: request.location,
            notes: request.notes,
            is_reimbursable: request.is_reimbursable.unwrap_or(false),
            reimbursement_status: None,
            created_at: Utc::now(),
            converted_at: None,
            is_converted: false,
        };
        
        // 4. 保存快速交易
        // TODO: 保存到数据库
        
        // 5. 自动转换为正式交易（如果启用）
        if self.should_auto_convert(&context).await? {
            self.convert_to_transaction(&context, &quick_tx).await?;
        }
        
        Ok(ServiceResponse::success_with_message(
            quick_tx,
            "Transaction recorded successfully".to_string()
        ))
    }
    
    /// 获取智能建议
    async fn get_smart_suggestions(
        &self,
        context: &ServiceContext,
        request: &QuickRecordRequest,
    ) -> Result<SmartSuggestions> {
        // 1. 基于描述文本分析
        let text_analysis = self.analyze_description(&request.description).await?;
        
        // 2. 基于历史交易模式
        let history_patterns = self.analyze_history_patterns(
            &context.family_id,
            &request.description,
        ).await?;
        
        // 3. 基于规则匹配
        let rule_matches = self.match_rules(context, request).await?;
        
        // 4. 综合建议
        Ok(SmartSuggestions {
            suggested_category: self.suggest_category(
                &text_analysis,
                &history_patterns,
                &rule_matches,
            ),
            suggested_payee: self.suggest_payee(&request.description, &context.family_id).await?,
            suggested_account: self.suggest_account(&context.user_id).await?,
            suggested_tags: self.suggest_tags(&request.description).await?,
            recent_similar_transactions: self.find_similar_transactions(
                &context.family_id,
                &request.description,
                5,
            ).await?,
        })
    }
    
    /// 分析描述文本
    async fn analyze_description(&self, description: &str) -> Result<TextAnalysis> {
        let keywords = self.extract_keywords(description);
        let merchant = self.detect_merchant(description);
        let location = self.detect_location(description);
        
        Ok(TextAnalysis {
            keywords,
            merchant,
            location,
            category_hints: self.get_category_hints(&keywords),
        })
    }
    
    /// 提取关键词
    fn extract_keywords(&self, text: &str) -> Vec<String> {
        // 简单的关键词提取
        text.to_lowercase()
            .split_whitespace()
            .filter(|w| w.len() > 2)
            .map(|w| w.to_string())
            .collect()
    }
    
    /// 检测商户
    fn detect_merchant(&self, text: &str) -> Option<String> {
        // 常见商户模式匹配
        let merchants = vec![
            "starbucks", "amazon", "walmart", "target", "costco",
            "uber", "lyft", "netflix", "spotify", "apple",
        ];
        
        let text_lower = text.to_lowercase();
        merchants.into_iter()
            .find(|m| text_lower.contains(m))
            .map(|m| m.to_string())
    }
    
    /// 检测位置
    fn detect_location(&self, text: &str) -> Option<String> {
        // 简单的位置检测
        if text.contains(" at ") {
            text.split(" at ").nth(1).map(|s| s.to_string())
        } else {
            None
        }
    }
    
    /// 获取分类提示
    fn get_category_hints(&self, keywords: &[String]) -> Vec<String> {
        let mut hints = Vec::new();
        
        // 餐饮关键词
        let food_keywords = ["lunch", "dinner", "breakfast", "coffee", "restaurant", "food"];
        if keywords.iter().any(|k| food_keywords.contains(&k.as_str())) {
            hints.push("Food & Dining".to_string());
        }
        
        // 交通关键词
        let transport_keywords = ["uber", "lyft", "taxi", "bus", "train", "gas", "parking"];
        if keywords.iter().any(|k| transport_keywords.contains(&k.as_str())) {
            hints.push("Transportation".to_string());
        }
        
        // 购物关键词
        let shopping_keywords = ["amazon", "walmart", "target", "store", "shop", "buy"];
        if keywords.iter().any(|k| shopping_keywords.contains(&k.as_str())) {
            hints.push("Shopping".to_string());
        }
        
        hints
    }
    
    /// 转换为正式交易
    pub async fn convert_to_transaction(
        &self,
        context: &ServiceContext,
        quick_tx: &QuickTransaction,
    ) -> Result<Transaction> {
        // TODO: 创建正式交易
        // 1. 确定账户
        // 2. 确定分类
        // 3. 创建交易
        // 4. 标记快速交易为已转换
        
        Err(JiveError::NotImplemented("convert_to_transaction".into()))
    }
    
    /// 批量转换快速交易
    pub async fn batch_convert(
        &self,
        context: ServiceContext,
        quick_tx_ids: Vec<String>,
    ) -> Result<BatchConvertResult> {
        let mut successful = 0;
        let mut failed = 0;
        let mut errors = Vec::new();
        
        for id in quick_tx_ids {
            match self.convert_quick_transaction(&context, &id).await {
                Ok(_) => successful += 1,
                Err(e) => {
                    failed += 1;
                    errors.push(format!("{}: {}", id, e));
                }
            }
        }
        
        Ok(BatchConvertResult {
            total: successful + failed,
            successful,
            failed,
            errors,
        })
    }
    
    /// 转换单个快速交易
    async fn convert_quick_transaction(
        &self,
        context: &ServiceContext,
        quick_tx_id: &str,
    ) -> Result<Transaction> {
        // TODO: 实现转换逻辑
        Err(JiveError::NotImplemented("convert_quick_transaction".into()))
    }
    
    /// 是否应该自动转换
    async fn should_auto_convert(&self, context: &ServiceContext) -> Result<bool> {
        // TODO: 从用户设置或 Family 设置获取
        Ok(false)
    }
    
    /// 建议分类
    fn suggest_category(
        &self,
        text_analysis: &TextAnalysis,
        history_patterns: &HistoryPatterns,
        rule_matches: &RuleMatches,
    ) -> Option<CategorySuggestion> {
        // TODO: 实现分类建议逻辑
        None
    }
    
    /// 建议收款人
    async fn suggest_payee(
        &self,
        description: &str,
        family_id: &str,
    ) -> Result<Option<PayeeSuggestion>> {
        // TODO: 基于描述和历史记录建议收款人
        Ok(None)
    }
    
    /// 建议账户
    async fn suggest_account(&self, user_id: &str) -> Result<Option<AccountSuggestion>> {
        // TODO: 基于使用频率建议账户
        Ok(None)
    }
    
    /// 建议标签
    async fn suggest_tags(&self, description: &str) -> Result<Vec<String>> {
        // TODO: 基于描述建议标签
        Ok(Vec::new())
    }
    
    /// 查找相似交易
    async fn find_similar_transactions(
        &self,
        family_id: &str,
        description: &str,
        limit: usize,
    ) -> Result<Vec<SimilarTransaction>> {
        // TODO: 实现相似交易查找
        Ok(Vec::new())
    }
    
    /// 分析历史模式
    async fn analyze_history_patterns(
        &self,
        family_id: &str,
        description: &str,
    ) -> Result<HistoryPatterns> {
        Ok(HistoryPatterns::default())
    }
    
    /// 匹配规则
    async fn match_rules(
        &self,
        context: &ServiceContext,
        request: &QuickRecordRequest,
    ) -> Result<RuleMatches> {
        Ok(RuleMatches::default())
    }
}

/// 文本分析结果
#[derive(Debug)]
struct TextAnalysis {
    keywords: Vec<String>,
    merchant: Option<String>,
    location: Option<String>,
    category_hints: Vec<String>,
}

/// 历史模式
#[derive(Debug, Default)]
struct HistoryPatterns {
    // TODO: 定义历史模式结构
}

/// 规则匹配结果
#[derive(Debug, Default)]
struct RuleMatches {
    // TODO: 定义规则匹配结构
}

/// 批量转换结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchConvertResult {
    pub total: usize,
    pub successful: usize,
    pub failed: usize,
    pub errors: Vec<String>,
}

/// 快速记账配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuickRecordSettings {
    pub auto_convert: bool,
    pub default_account_id: Option<String>,
    pub smart_suggestions: bool,
    pub require_category: bool,
    pub allow_future_dates: bool,
    pub max_days_in_future: i32,
    pub default_tags: Vec<String>,
}

impl Default for QuickRecordSettings {
    fn default() -> Self {
        Self {
            auto_convert: true,
            default_account_id: None,
            smart_suggestions: true,
            require_category: false,
            allow_future_dates: false,
            max_days_in_future: 7,
            default_tags: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_keyword_extraction() {
        let service = QuickTransactionService::new();
        let keywords = service.extract_keywords("Lunch at Starbucks with friends");
        assert!(keywords.contains(&"lunch".to_string()));
        assert!(keywords.contains(&"starbucks".to_string()));
        assert!(keywords.contains(&"friends".to_string()));
    }

    #[test]
    fn test_merchant_detection() {
        let service = QuickTransactionService::new();
        assert_eq!(
            service.detect_merchant("Coffee at Starbucks"),
            Some("starbucks".to_string())
        );
        assert_eq!(
            service.detect_merchant("Order from Amazon"),
            Some("amazon".to_string())
        );
        assert_eq!(
            service.detect_merchant("Random text"),
            None
        );
    }

    #[test]
    fn test_category_hints() {
        let service = QuickTransactionService::new();
        let food_keywords = vec!["lunch".to_string(), "restaurant".to_string()];
        let hints = service.get_category_hints(&food_keywords);
        assert!(hints.contains(&"Food & Dining".to_string()));
    }
}