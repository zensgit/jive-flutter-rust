//! PayeeService - 收款方/商家管理服务
//! 
//! 提供全面的收款方管理功能，包括：
//! - 收款方信息管理
//! - 智能合并和去重
//! - 自动检测和建议
//! - 使用统计和分析
//! - 批量操作支持

use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{NaiveDateTime, Utc};
use std::collections::HashMap;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::{
    error::{JiveError, Result},
    models::{ServiceContext, ServiceResponse, PaginationParams, PaginatedResult}
};

/// 收款方信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct Payee {
    pub id: String,
    pub name: String,
    pub display_name: Option<String>,
    pub category: Option<String>,
    pub description: Option<String>,
    pub website: Option<String>,
    pub phone: Option<String>,
    pub email: Option<String>,
    pub address: Option<String>,
    pub logo_url: Option<String>,
    pub is_active: bool,
    pub is_verified: bool,
    pub usage_count: u32,
    pub last_used_at: Option<NaiveDateTime>,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl Payee {
    #[wasm_bindgen(getter)]
    pub fn id(&self) -> String { self.id.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String { self.name.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn display_name(&self) -> Option<String> { self.display_name.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn category(&self) -> Option<String> { self.category.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn is_active(&self) -> bool { self.is_active }
    
    #[wasm_bindgen(getter)]
    pub fn usage_count(&self) -> u32 { self.usage_count }
}

/// 收款方类别枚举
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum PayeeCategory {
    Restaurant,    // 餐厅
    Retail,       // 零售
    Utility,      // 公用事业
    Insurance,    // 保险
    Healthcare,   // 医疗
    Education,    // 教育
    Transportation, // 交通
    Entertainment, // 娱乐
    Finance,      // 金融
    Government,   // 政府
    Other,        // 其他
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl PayeeCategory {
    #[wasm_bindgen(getter)]
    pub fn as_string(&self) -> String {
        match self {
            PayeeCategory::Restaurant => "restaurant".to_string(),
            PayeeCategory::Retail => "retail".to_string(),
            PayeeCategory::Utility => "utility".to_string(),
            PayeeCategory::Insurance => "insurance".to_string(),
            PayeeCategory::Healthcare => "healthcare".to_string(),
            PayeeCategory::Education => "education".to_string(),
            PayeeCategory::Transportation => "transportation".to_string(),
            PayeeCategory::Entertainment => "entertainment".to_string(),
            PayeeCategory::Finance => "finance".to_string(),
            PayeeCategory::Government => "government".to_string(),
            PayeeCategory::Other => "other".to_string(),
        }
    }
}

/// 创建收款方请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CreatePayeeRequest {
    pub name: String,
    pub display_name: Option<String>,
    pub category: Option<String>,
    pub description: Option<String>,
    pub website: Option<String>,
    pub phone: Option<String>,
    pub email: Option<String>,
    pub address: Option<String>,
    pub logo_url: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CreatePayeeRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(name: String) -> Self {
        Self {
            name,
            display_name: None,
            category: None,
            description: None,
            website: None,
            phone: None,
            email: None,
            address: None,
            logo_url: None,
        }
    }
    
    #[wasm_bindgen(setter)]
    pub fn set_display_name(&mut self, display_name: Option<String>) {
        self.display_name = display_name;
    }
    
    #[wasm_bindgen(setter)]
    pub fn set_category(&mut self, category: Option<String>) {
        self.category = category;
    }
}

/// 更新收款方请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UpdatePayeeRequest {
    pub name: Option<String>,
    pub display_name: Option<String>,
    pub category: Option<String>,
    pub description: Option<String>,
    pub website: Option<String>,
    pub phone: Option<String>,
    pub email: Option<String>,
    pub address: Option<String>,
    pub logo_url: Option<String>,
    pub is_active: Option<bool>,
}

/// 收款方查询过滤器
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct PayeeFilter {
    pub category: Option<String>,
    pub is_active: Option<bool>,
    pub is_verified: Option<bool>,
    pub name_contains: Option<String>,
    pub min_usage_count: Option<u32>,
    pub created_after: Option<NaiveDateTime>,
    pub created_before: Option<NaiveDateTime>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl PayeeFilter {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            category: None,
            is_active: None,
            is_verified: None,
            name_contains: None,
            min_usage_count: None,
            created_after: None,
            created_before: None,
        }
    }
}

impl Default for PayeeFilter {
    fn default() -> Self {
        Self::new()
    }
}

/// 收款方使用统计
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct PayeeStats {
    pub payee_id: String,
    pub name: String,
    pub total_transactions: u32,
    pub total_amount: rust_decimal::Decimal,
    pub avg_amount: rust_decimal::Decimal,
    pub first_transaction_date: Option<NaiveDateTime>,
    pub last_transaction_date: Option<NaiveDateTime>,
    pub frequency_score: f64,
    pub category_distribution: HashMap<String, u32>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl PayeeStats {
    #[wasm_bindgen(getter)]
    pub fn payee_id(&self) -> String { self.payee_id.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String { self.name.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn total_transactions(&self) -> u32 { self.total_transactions }
    
    #[wasm_bindgen(getter)]
    pub fn frequency_score(&self) -> f64 { self.frequency_score }
}

/// 收款方合并请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct MergePayeesRequest {
    pub source_payee_ids: Vec<String>,
    pub target_payee_id: String,
    pub keep_source_data: bool,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl MergePayeesRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(target_payee_id: String) -> Self {
        Self {
            source_payee_ids: Vec::new(),
            target_payee_id,
            keep_source_data: false,
        }
    }
    
    #[wasm_bindgen]
    pub fn add_source_payee(&mut self, payee_id: String) {
        self.source_payee_ids.push(payee_id);
    }
}

/// 收款方建议
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct PayeeSuggestion {
    pub payee_id: String,
    pub name: String,
    pub confidence_score: f64,
    pub match_reason: String,
    pub similar_payees: Vec<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl PayeeSuggestion {
    #[wasm_bindgen(getter)]
    pub fn payee_id(&self) -> String { self.payee_id.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String { self.name.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn confidence_score(&self) -> f64 { self.confidence_score }
    
    #[wasm_bindgen(getter)]
    pub fn match_reason(&self) -> String { self.match_reason.clone() }
}

/// 收款方管理服务
#[derive(Debug)]
pub struct PayeeService {
    payees: HashMap<String, Payee>,
    usage_stats: HashMap<String, PayeeStats>,
}

impl PayeeService {
    pub fn new() -> Self {
        Self {
            payees: HashMap::new(),
            usage_stats: HashMap::new(),
        }
    }

    /// 创建新收款方
    pub async fn create_payee(
        &mut self,
        request: CreatePayeeRequest,
        _context: &ServiceContext,
    ) -> Result<Payee> {
        // 验证收款方名称
        if request.name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "收款方名称不能为空".to_string(),
            });
        }

        // 检查重复名称
        if self.payees.values().any(|p| p.name.to_lowercase() == request.name.to_lowercase()) {
            return Err(JiveError::ValidationError {
                message: format!("收款方 '{}' 已存在", request.name),
            });
        }

        // 验证电子邮件格式
        if let Some(email) = &request.email {
            if !email.contains('@') || !email.contains('.') {
                return Err(JiveError::ValidationError {
                    message: "电子邮件格式无效".to_string(),
                });
            }
        }

        // 验证网站URL
        if let Some(website) = &request.website {
            if !website.starts_with("http://") && !website.starts_with("https://") {
                return Err(JiveError::ValidationError {
                    message: "网站URL必须以http://或https://开头".to_string(),
                });
            }
        }

        let now = Utc::now().naive_utc();
        let payee = Payee {
            id: Uuid::new_v4().to_string(),
            name: request.name.trim().to_string(),
            display_name: request.display_name.map(|s| s.trim().to_string()),
            category: request.category,
            description: request.description,
            website: request.website,
            phone: request.phone,
            email: request.email,
            address: request.address,
            logo_url: request.logo_url,
            is_active: true,
            is_verified: false,
            usage_count: 0,
            last_used_at: None,
            created_at: now,
            updated_at: now,
        };

        self.payees.insert(payee.id.clone(), payee.clone());
        Ok(payee)
    }

    /// 更新收款方
    pub async fn update_payee(
        &mut self,
        payee_id: &str,
        request: UpdatePayeeRequest,
        _context: &ServiceContext,
    ) -> Result<Payee> {
        let payee = self.payees.get_mut(payee_id)
            .ok_or_else(|| JiveError::NotFound {
                message: format!("收款方 {} 不存在", payee_id),
            })?;

        // 更新字段
        if let Some(name) = request.name {
            if name.trim().is_empty() {
                return Err(JiveError::ValidationError {
                    message: "收款方名称不能为空".to_string(),
                });
            }
            
            // 检查重复名称（排除自己）
            if self.payees.values()
                .any(|p| p.id != payee_id && p.name.to_lowercase() == name.to_lowercase()) {
                return Err(JiveError::ValidationError {
                    message: format!("收款方 '{}' 已存在", name),
                });
            }
            
            payee.name = name.trim().to_string();
        }

        if let Some(display_name) = request.display_name {
            payee.display_name = Some(display_name);
        }

        if let Some(category) = request.category {
            payee.category = Some(category);
        }

        if let Some(description) = request.description {
            payee.description = Some(description);
        }

        if let Some(website) = request.website {
            if !website.starts_with("http://") && !website.starts_with("https://") {
                return Err(JiveError::ValidationError {
                    message: "网站URL必须以http://或https://开头".to_string(),
                });
            }
            payee.website = Some(website);
        }

        if let Some(phone) = request.phone {
            payee.phone = Some(phone);
        }

        if let Some(email) = request.email {
            if !email.contains('@') || !email.contains('.') {
                return Err(JiveError::ValidationError {
                    message: "电子邮件格式无效".to_string(),
                });
            }
            payee.email = Some(email);
        }

        if let Some(address) = request.address {
            payee.address = Some(address);
        }

        if let Some(logo_url) = request.logo_url {
            payee.logo_url = Some(logo_url);
        }

        if let Some(is_active) = request.is_active {
            payee.is_active = is_active;
        }

        payee.updated_at = Utc::now().naive_utc();

        Ok(payee.clone())
    }

    /// 获取收款方详情
    pub async fn get_payee(
        &self,
        payee_id: &str,
        _context: &ServiceContext,
    ) -> Result<Payee> {
        self.payees.get(payee_id)
            .cloned()
            .ok_or_else(|| JiveError::NotFound {
                message: format!("收款方 {} 不存在", payee_id),
            })
    }

    /// 查询收款方列表
    pub async fn get_payees(
        &self,
        filter: Option<PayeeFilter>,
        pagination: PaginationParams,
        _context: &ServiceContext,
    ) -> Result<PaginatedResult<Payee>> {
        let mut payees: Vec<_> = self.payees.values().collect();

        // 应用过滤器
        if let Some(filter) = filter {
            payees.retain(|payee| {
                if let Some(category) = &filter.category {
                    if payee.category.as_ref() != Some(category) {
                        return false;
                    }
                }

                if let Some(is_active) = filter.is_active {
                    if payee.is_active != is_active {
                        return false;
                    }
                }

                if let Some(is_verified) = filter.is_verified {
                    if payee.is_verified != is_verified {
                        return false;
                    }
                }

                if let Some(name_contains) = &filter.name_contains {
                    if !payee.name.to_lowercase().contains(&name_contains.to_lowercase()) {
                        return false;
                    }
                }

                if let Some(min_usage_count) = filter.min_usage_count {
                    if payee.usage_count < min_usage_count {
                        return false;
                    }
                }

                if let Some(created_after) = filter.created_after {
                    if payee.created_at < created_after {
                        return false;
                    }
                }

                if let Some(created_before) = filter.created_before {
                    if payee.created_at > created_before {
                        return false;
                    }
                }

                true
            });
        }

        // 按使用次数降序排序
        payees.sort_by(|a, b| b.usage_count.cmp(&a.usage_count));

        let total_count = payees.len() as u32;
        let start = pagination.offset as usize;
        let end = (start + pagination.per_page as usize).min(payees.len());
        
        let page_items = payees[start..end].iter().map(|p| (*p).clone()).collect();

        Ok(PaginatedResult::new(page_items, total_count, &pagination))
    }

    /// 删除收款方
    pub async fn delete_payee(
        &mut self,
        payee_id: &str,
        _context: &ServiceContext,
    ) -> Result<()> {
        if !self.payees.contains_key(payee_id) {
            return Err(JiveError::NotFound {
                message: format!("收款方 {} 不存在", payee_id),
            });
        }

        // 检查是否有关联交易（在实际实现中需要检查）
        let usage_count = self.payees.get(payee_id).unwrap().usage_count;
        if usage_count > 0 {
            return Err(JiveError::ValidationError {
                message: "无法删除有关联交易的收款方，请先处理相关交易".to_string(),
            });
        }

        self.payees.remove(payee_id);
        self.usage_stats.remove(payee_id);
        Ok(())
    }

    /// 搜索收款方
    pub async fn search_payees(
        &self,
        query: &str,
        limit: u32,
        _context: &ServiceContext,
    ) -> Result<Vec<Payee>> {
        if query.trim().is_empty() {
            return Ok(Vec::new());
        }

        let query_lower = query.to_lowercase();
        let mut matches: Vec<_> = self.payees.values()
            .filter_map(|payee| {
                let name_match = payee.name.to_lowercase().contains(&query_lower);
                let display_name_match = payee.display_name.as_ref()
                    .map(|dn| dn.to_lowercase().contains(&query_lower))
                    .unwrap_or(false);

                if name_match || display_name_match {
                    let score = if payee.name.to_lowercase().starts_with(&query_lower) {
                        1.0
                    } else if name_match {
                        0.8
                    } else {
                        0.6
                    };
                    Some((payee.clone(), score))
                } else {
                    None
                }
            })
            .collect();

        // 按相关性和使用次数排序
        matches.sort_by(|a, b| {
            b.1.partial_cmp(&a.1).unwrap()
                .then_with(|| b.0.usage_count.cmp(&a.0.usage_count))
        });

        Ok(matches.into_iter()
            .map(|(payee, _)| payee)
            .take(limit as usize)
            .collect())
    }

    /// 合并收款方
    pub async fn merge_payees(
        &mut self,
        request: MergePayeesRequest,
        _context: &ServiceContext,
    ) -> Result<Payee> {
        // 验证目标收款方存在
        let target_payee = self.payees.get(&request.target_payee_id)
            .ok_or_else(|| JiveError::NotFound {
                message: format!("目标收款方 {} 不存在", request.target_payee_id),
            })?.clone();

        // 验证源收款方都存在
        for source_id in &request.source_payee_ids {
            if !self.payees.contains_key(source_id) {
                return Err(JiveError::NotFound {
                    message: format!("源收款方 {} 不存在", source_id),
                });
            }
        }

        // 计算合并后的统计数据
        let mut total_usage = target_payee.usage_count;
        let mut earliest_last_used = target_payee.last_used_at;

        for source_id in &request.source_payee_ids {
            if let Some(source_payee) = self.payees.get(source_id) {
                total_usage += source_payee.usage_count;
                
                match (earliest_last_used, source_payee.last_used_at) {
                    (None, Some(date)) => earliest_last_used = Some(date),
                    (Some(current), Some(date)) if date > current => earliest_last_used = Some(date),
                    _ => {}
                }
            }
        }

        // 更新目标收款方
        if let Some(target) = self.payees.get_mut(&request.target_payee_id) {
            target.usage_count = total_usage;
            target.last_used_at = earliest_last_used;
            target.updated_at = Utc::now().naive_utc();
        }

        // 删除源收款方（除非保留数据）
        if !request.keep_source_data {
            for source_id in &request.source_payee_ids {
                self.payees.remove(source_id);
                self.usage_stats.remove(source_id);
            }
        }

        Ok(self.payees.get(&request.target_payee_id).unwrap().clone())
    }

    /// 获取收款方统计信息
    pub async fn get_payee_stats(
        &self,
        payee_id: &str,
        _context: &ServiceContext,
    ) -> Result<PayeeStats> {
        let payee = self.payees.get(payee_id)
            .ok_or_else(|| JiveError::NotFound {
                message: format!("收款方 {} 不存在", payee_id),
            })?;

        // 模拟统计数据（实际实现需要从数据库计算）
        let stats = PayeeStats {
            payee_id: payee_id.to_string(),
            name: payee.name.clone(),
            total_transactions: payee.usage_count,
            total_amount: rust_decimal::Decimal::new(10000 * payee.usage_count as i64, 2),
            avg_amount: rust_decimal::Decimal::new(10000, 2),
            first_transaction_date: payee.created_at.into(),
            last_transaction_date: payee.last_used_at,
            frequency_score: (payee.usage_count as f64) * 0.1,
            category_distribution: HashMap::new(),
        };

        Ok(stats)
    }

    /// 获取热门收款方
    pub async fn get_popular_payees(
        &self,
        limit: u32,
        _context: &ServiceContext,
    ) -> Result<Vec<Payee>> {
        let mut payees: Vec<_> = self.payees.values()
            .filter(|p| p.is_active && p.usage_count > 0)
            .cloned()
            .collect();

        payees.sort_by(|a, b| {
            b.usage_count.cmp(&a.usage_count)
                .then_with(|| b.last_used_at.cmp(&a.last_used_at))
        });

        Ok(payees.into_iter().take(limit as usize).collect())
    }

    /// 获取收款方建议
    pub async fn suggest_payees(
        &self,
        transaction_description: &str,
        limit: u32,
        _context: &ServiceContext,
    ) -> Result<Vec<PayeeSuggestion>> {
        if transaction_description.trim().is_empty() {
            return Ok(Vec::new());
        }

        let desc_lower = transaction_description.to_lowercase();
        let mut suggestions: Vec<_> = self.payees.values()
            .filter_map(|payee| {
                let name_similarity = self.calculate_similarity(&payee.name.to_lowercase(), &desc_lower);
                
                if name_similarity > 0.3 {
                    let confidence = name_similarity * 0.7 + (payee.usage_count as f64 * 0.01).min(0.3);
                    
                    let suggestion = PayeeSuggestion {
                        payee_id: payee.id.clone(),
                        name: payee.name.clone(),
                        confidence_score: confidence,
                        match_reason: if name_similarity > 0.8 {
                            "名称高度匹配".to_string()
                        } else if name_similarity > 0.5 {
                            "名称部分匹配".to_string()
                        } else {
                            "名称相似".to_string()
                        },
                        similar_payees: Vec::new(),
                    };
                    
                    Some(suggestion)
                } else {
                    None
                }
            })
            .collect();

        suggestions.sort_by(|a, b| b.confidence_score.partial_cmp(&a.confidence_score).unwrap());
        Ok(suggestions.into_iter().take(limit as usize).collect())
    }

    /// 批量更新收款方状态
    pub async fn batch_update_status(
        &mut self,
        payee_ids: Vec<String>,
        is_active: bool,
        _context: &ServiceContext,
    ) -> Result<u32> {
        let mut updated_count = 0;
        let now = Utc::now().naive_utc();

        for payee_id in payee_ids {
            if let Some(payee) = self.payees.get_mut(&payee_id) {
                payee.is_active = is_active;
                payee.updated_at = now;
                updated_count += 1;
            }
        }

        Ok(updated_count)
    }

    /// 记录收款方使用
    pub async fn record_usage(
        &mut self,
        payee_id: &str,
        _context: &ServiceContext,
    ) -> Result<()> {
        let payee = self.payees.get_mut(payee_id)
            .ok_or_else(|| JiveError::NotFound {
                message: format!("收款方 {} 不存在", payee_id),
            })?;

        payee.usage_count += 1;
        payee.last_used_at = Some(Utc::now().naive_utc());
        payee.updated_at = Utc::now().naive_utc();

        Ok(())
    }

    // 辅助方法：计算字符串相似度
    fn calculate_similarity(&self, s1: &str, s2: &str) -> f64 {
        // 简单的相似度计算（基于公共子串）
        let s1_words: Vec<&str> = s1.split_whitespace().collect();
        let s2_words: Vec<&str> = s2.split_whitespace().collect();
        
        if s1_words.is_empty() || s2_words.is_empty() {
            return 0.0;
        }

        let mut matches = 0;
        for word1 in &s1_words {
            for word2 in &s2_words {
                if word1.contains(word2) || word2.contains(word1) {
                    matches += 1;
                    break;
                }
            }
        }

        matches as f64 / s1_words.len().max(s2_words.len()) as f64
    }
}

impl Default for PayeeService {
    fn default() -> Self {
        Self::new()
    }
}

// WASM 绑定
#[cfg(feature = "wasm")]
#[wasm_bindgen]
pub struct WasmPayeeService {
    service: PayeeService,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl WasmPayeeService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            service: PayeeService::new(),
        }
    }

    #[wasm_bindgen]
    pub async fn create_payee(
        &mut self,
        request: CreatePayeeRequest,
        context: &ServiceContext,
    ) -> Result<ServiceResponse<Payee>, JsValue> {
        let result = self.service.create_payee(request, context).await;
        Ok(ServiceResponse::from(result))
    }

    #[wasm_bindgen]
    pub async fn get_payee(
        &self,
        payee_id: &str,
        context: &ServiceContext,
    ) -> Result<ServiceResponse<Payee>, JsValue> {
        let result = self.service.get_payee(payee_id, context).await;
        Ok(ServiceResponse::from(result))
    }

    #[wasm_bindgen]
    pub async fn search_payees(
        &self,
        query: &str,
        limit: u32,
        context: &ServiceContext,
    ) -> Result<ServiceResponse<Vec<Payee>>, JsValue> {
        let result = self.service.search_payees(query, limit, context).await;
        Ok(ServiceResponse::from(result))
    }

    #[wasm_bindgen]
    pub async fn get_popular_payees(
        &self,
        limit: u32,
        context: &ServiceContext,
    ) -> Result<ServiceResponse<Vec<Payee>>, JsValue> {
        let result = self.service.get_popular_payees(limit, context).await;
        Ok(ServiceResponse::from(result))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_context() -> ServiceContext {
        ServiceContext {
            user_id: "test-user".to_string(),
            current_ledger_id: Some("test-ledger".to_string()),
            request_id: Some("test-request".to_string()),
            timestamp: Utc::now(),
        }
    }

    #[tokio::test]
    async fn test_create_payee() {
        let mut service = PayeeService::new();
        let context = create_test_context();

        let request = CreatePayeeRequest {
            name: "星巴克".to_string(),
            display_name: Some("Starbucks".to_string()),
            category: Some("restaurant".to_string()),
            description: Some("咖啡连锁店".to_string()),
            website: Some("https://www.starbucks.com".to_string()),
            phone: Some("+1-800-STARBUC".to_string()),
            email: Some("info@starbucks.com".to_string()),
            address: Some("Seattle, WA".to_string()),
            logo_url: Some("https://logo.starbucks.com/logo.png".to_string()),
        };

        let payee = service.create_payee(request, &context).await.unwrap();
        assert_eq!(payee.name, "星巴克");
        assert_eq!(payee.display_name, Some("Starbucks".to_string()));
        assert_eq!(payee.category, Some("restaurant".to_string()));
        assert!(payee.is_active);
        assert!(!payee.is_verified);
        assert_eq!(payee.usage_count, 0);
    }

    #[tokio::test]
    async fn test_payee_validation() {
        let mut service = PayeeService::new();
        let context = create_test_context();

        // 测试空名称
        let empty_name_request = CreatePayeeRequest {
            name: "".to_string(),
            display_name: None,
            category: None,
            description: None,
            website: None,
            phone: None,
            email: None,
            address: None,
            logo_url: None,
        };

        let result = service.create_payee(empty_name_request, &context).await;
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("名称不能为空"));

        // 测试无效邮箱
        let invalid_email_request = CreatePayeeRequest {
            name: "Test Payee".to_string(),
            email: Some("invalid-email".to_string()),
            display_name: None,
            category: None,
            description: None,
            website: None,
            phone: None,
            address: None,
            logo_url: None,
        };

        let result = service.create_payee(invalid_email_request, &context).await;
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("电子邮件格式无效"));

        // 测试无效网址
        let invalid_website_request = CreatePayeeRequest {
            name: "Test Payee".to_string(),
            website: Some("invalid-url".to_string()),
            display_name: None,
            category: None,
            description: None,
            phone: None,
            email: None,
            address: None,
            logo_url: None,
        };

        let result = service.create_payee(invalid_website_request, &context).await;
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("网站URL必须"));
    }

    #[tokio::test]
    async fn test_search_payees() {
        let mut service = PayeeService::new();
        let context = create_test_context();

        // 创建测试收款方
        let payees_data = vec![
            ("星巴克", "Starbucks", "restaurant"),
            ("麦当劳", "McDonald's", "restaurant"),
            ("苹果商店", "Apple Store", "retail"),
            ("星期天超市", "Sunday Market", "retail"),
        ];

        for (name, display_name, category) in payees_data {
            let request = CreatePayeeRequest {
                name: name.to_string(),
                display_name: Some(display_name.to_string()),
                category: Some(category.to_string()),
                description: None,
                website: None,
                phone: None,
                email: None,
                address: None,
                logo_url: None,
            };
            service.create_payee(request, &context).await.unwrap();
        }

        // 测试搜索
        let results = service.search_payees("星", 10, &context).await.unwrap();
        assert_eq!(results.len(), 2); // 星巴克 和 星期天超市

        let results = service.search_payees("Starbucks", 10, &context).await.unwrap();
        assert_eq!(results.len(), 1);
        assert_eq!(results[0].name, "星巴克");

        // 测试空查询
        let results = service.search_payees("", 10, &context).await.unwrap();
        assert_eq!(results.len(), 0);
    }

    #[tokio::test]
    async fn test_merge_payees() {
        let mut service = PayeeService::new();
        let context = create_test_context();

        // 创建目标收款方
        let target_request = CreatePayeeRequest {
            name: "星巴克".to_string(),
            display_name: Some("Starbucks".to_string()),
            category: Some("restaurant".to_string()),
            description: None,
            website: None,
            phone: None,
            email: None,
            address: None,
            logo_url: None,
        };
        let target_payee = service.create_payee(target_request, &context).await.unwrap();

        // 创建源收款方
        let source_request1 = CreatePayeeRequest {
            name: "Starbucks Coffee".to_string(),
            display_name: None,
            category: Some("restaurant".to_string()),
            description: None,
            website: None,
            phone: None,
            email: None,
            address: None,
            logo_url: None,
        };
        let source_payee1 = service.create_payee(source_request1, &context).await.unwrap();

        let source_request2 = CreatePayeeRequest {
            name: "星巴克咖啡".to_string(),
            display_name: None,
            category: Some("restaurant".to_string()),
            description: None,
            website: None,
            phone: None,
            email: None,
            address: None,
            logo_url: None,
        };
        let source_payee2 = service.create_payee(source_request2, &context).await.unwrap();

        // 记录一些使用次数
        service.record_usage(&source_payee1.id, &context).await.unwrap();
        service.record_usage(&source_payee2.id, &context).await.unwrap();
        service.record_usage(&source_payee2.id, &context).await.unwrap();

        // 合并收款方
        let merge_request = MergePayeesRequest {
            source_payee_ids: vec![source_payee1.id.clone(), source_payee2.id.clone()],
            target_payee_id: target_payee.id.clone(),
            keep_source_data: false,
        };

        let merged_payee = service.merge_payees(merge_request, &context).await.unwrap();
        assert_eq!(merged_payee.usage_count, 3); // 0 + 1 + 2

        // 验证源收款方已被删除
        assert!(service.get_payee(&source_payee1.id, &context).await.is_err());
        assert!(service.get_payee(&source_payee2.id, &context).await.is_err());

        // 验证目标收款方仍存在
        assert!(service.get_payee(&target_payee.id, &context).await.is_ok());
    }

    #[tokio::test]
    async fn test_payee_categories() {
        let categories = vec![
            PayeeCategory::Restaurant,
            PayeeCategory::Retail,
            PayeeCategory::Utility,
            PayeeCategory::Insurance,
            PayeeCategory::Healthcare,
            PayeeCategory::Education,
            PayeeCategory::Transportation,
            PayeeCategory::Entertainment,
            PayeeCategory::Finance,
            PayeeCategory::Government,
            PayeeCategory::Other,
        ];

        // 验证所有类别都有有效的字符串表示
        for category in categories {
            let category_str = category.as_string();
            assert!(!category_str.is_empty());
            assert!(category_str.chars().all(|c| c.is_ascii_lowercase()));
        }
    }
}