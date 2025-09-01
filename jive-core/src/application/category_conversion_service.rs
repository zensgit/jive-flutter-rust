//! 分类转换服务 - 实现分类到标签的转换功能
//! 
//! 提供分类转标签、分类合并、批量操作等高级功能

use std::collections::{HashMap, HashSet};
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc, NaiveDate};

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::domain::{Category, Tag};
use crate::error::{JiveError, Result};
use super::{ServiceContext, ServiceResponse, BatchResult};

/// 分类转换选项
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ConversionOptions {
    /// 标签名称（如果不提供，使用原分类名称）
    tag_name: Option<String>,
    /// 是否应用到历史交易
    apply_to_transactions: bool,
    /// 是否删除原分类
    delete_category: bool,
    /// 交易日期范围（如果应用到交易）
    date_range_start: Option<NaiveDate>,
    date_range_end: Option<NaiveDate>,
    /// 是否创建批量操作记录（用于撤销）
    create_batch_record: bool,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl ConversionOptions {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            tag_name: None,
            apply_to_transactions: false,
            delete_category: false,
            date_range_start: None,
            date_range_end: None,
            create_batch_record: true,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_tag_name(&mut self, name: Option<String>) {
        self.tag_name = name;
    }

    #[wasm_bindgen(setter)]
    pub fn set_apply_to_transactions(&mut self, apply: bool) {
        self.apply_to_transactions = apply;
    }

    #[wasm_bindgen(setter)]
    pub fn set_delete_category(&mut self, delete: bool) {
        self.delete_category = delete;
    }

    #[wasm_bindgen(setter)]
    pub fn set_create_batch_record(&mut self, create: bool) {
        self.create_batch_record = create;
    }

    #[wasm_bindgen]
    pub fn set_date_range(&mut self, start: Option<String>, end: Option<String>) -> Result<()> {
        if let Some(start_str) = start {
            self.date_range_start = Some(NaiveDate::parse_from_str(&start_str, "%Y-%m-%d")
                .map_err(|e| JiveError::ValidationError {
                    message: format!("Invalid start date: {}", e),
                })?);
        }
        
        if let Some(end_str) = end {
            self.date_range_end = Some(NaiveDate::parse_from_str(&end_str, "%Y-%m-%d")
                .map_err(|e| JiveError::ValidationError {
                    message: format!("Invalid end date: {}", e),
                })?);
        }
        
        Ok(())
    }
}

impl Default for ConversionOptions {
    fn default() -> Self {
        Self::new()
    }
}

/// 分类转换结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ConversionResult {
    /// 创建的标签
    tag: Tag,
    /// 更新的交易数量
    transactions_updated: u32,
    /// 原分类状态
    category_status: CategoryStatus,
    /// 批量操作ID（如果创建了）
    batch_operation_id: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl ConversionResult {
    #[wasm_bindgen(getter)]
    pub fn tag(&self) -> Tag {
        self.tag.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn transactions_updated(&self) -> u32 {
        self.transactions_updated
    }

    #[wasm_bindgen(getter)]
    pub fn category_status(&self) -> CategoryStatus {
        self.category_status.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn batch_operation_id(&self) -> Option<String> {
        self.batch_operation_id.clone()
    }
}

/// 分类状态
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum CategoryStatus {
    Retained,  // 保留
    Deleted,   // 已删除
    Archived,  // 已归档
}

/// 分类删除策略
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum DeletionStrategy {
    MoveToCategory(String),  // 移动到其他分类
    ConvertToTag,           // 转换为标签
    Uncategorize,          // 设为未分类
    Cancel,                // 取消删除
}

/// 分类删除选项
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct DeletionOptions {
    strategy: DeletionStrategy,
    target_category_id: Option<String>,
    tag_name: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl DeletionOptions {
    #[wasm_bindgen(constructor)]
    pub fn new(strategy: DeletionStrategy) -> Self {
        Self {
            strategy,
            target_category_id: None,
            tag_name: None,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_target_category_id(&mut self, id: Option<String>) {
        self.target_category_id = id;
    }

    #[wasm_bindgen(setter)]
    pub fn set_tag_name(&mut self, name: Option<String>) {
        self.tag_name = name;
    }
}

/// 批量操作类型
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum BatchOperationType {
    Recategorize,    // 批量重分类
    ConvertToTag,    // 批量转标签
    Merge,          // 合并分类
    Delete,         // 批量删除
}

/// 批量操作记录
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BatchOperation {
    id: String,
    user_id: String,
    operation_type: BatchOperationType,
    original_data: serde_json::Value,
    affected_transactions: u32,
    can_revert: bool,
    created_at: DateTime<Utc>,
    expires_at: DateTime<Utc>,
    reverted_at: Option<DateTime<Utc>>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl BatchOperation {
    #[wasm_bindgen(getter)]
    pub fn id(&self) -> String {
        self.id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn operation_type(&self) -> BatchOperationType {
        self.operation_type.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn affected_transactions(&self) -> u32 {
        self.affected_transactions
    }

    #[wasm_bindgen(getter)]
    pub fn can_revert(&self) -> bool {
        self.can_revert && self.reverted_at.is_none() && Utc::now() < self.expires_at
    }

    #[wasm_bindgen(getter)]
    pub fn is_expired(&self) -> bool {
        Utc::now() >= self.expires_at
    }

    #[wasm_bindgen(getter)]
    pub fn is_reverted(&self) -> bool {
        self.reverted_at.is_some()
    }

    #[wasm_bindgen(getter)]
    pub fn created_at(&self) -> String {
        self.created_at.to_rfc3339()
    }

    #[wasm_bindgen(getter)]
    pub fn expires_at(&self) -> String {
        self.expires_at.to_rfc3339()
    }
}

/// 分类转换服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CategoryConversionService {
    // 在实际实现中，这里会包含数据库连接或仓储接口
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CategoryConversionService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {}
    }

    /// 将分类转换为标签
    #[wasm_bindgen]
    pub async fn convert_category_to_tag(
        &self,
        category_id: String,
        options: ConversionOptions,
        context: ServiceContext,
    ) -> ServiceResponse<ConversionResult> {
        let result = self._convert_category_to_tag(category_id, options, context).await;
        result.into()
    }

    /// 合并多个分类
    #[wasm_bindgen]
    pub async fn merge_categories(
        &self,
        source_category_ids: Vec<String>,
        target_category_id: String,
        delete_sources: bool,
        context: ServiceContext,
    ) -> ServiceResponse<BatchResult> {
        let result = self._merge_categories(
            source_category_ids,
            target_category_id,
            delete_sources,
            context
        ).await;
        result.into()
    }

    /// 批量重分类交易
    #[wasm_bindgen]
    pub async fn batch_recategorize(
        &self,
        transaction_ids: Vec<String>,
        target_category_id: String,
        add_tag: Option<String>,
        context: ServiceContext,
    ) -> ServiceResponse<BatchOperation> {
        let result = self._batch_recategorize(
            transaction_ids,
            target_category_id,
            add_tag,
            context
        ).await;
        result.into()
    }

    /// 撤销批量操作
    #[wasm_bindgen]
    pub async fn revert_batch_operation(
        &self,
        batch_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._revert_batch_operation(batch_id, context).await;
        result.into()
    }

    /// 获取批量操作历史
    #[wasm_bindgen]
    pub async fn get_batch_operations(
        &self,
        limit: u32,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<BatchOperation>> {
        let result = self._get_batch_operations(limit, context).await;
        result.into()
    }

    /// 删除分类（带策略）
    #[wasm_bindgen]
    pub async fn delete_category_with_strategy(
        &self,
        category_id: String,
        options: DeletionOptions,
        context: ServiceContext,
    ) -> ServiceResponse<BatchResult> {
        let result = self._delete_category_with_strategy(category_id, options, context).await;
        result.into()
    }

    /// 获取分类删除影响分析
    #[wasm_bindgen]
    pub async fn analyze_category_deletion_impact(
        &self,
        category_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<DeletionImpact> {
        let result = self._analyze_deletion_impact(category_id, context).await;
        result.into()
    }
}

/// 删除影响分析
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct DeletionImpact {
    category_id: String,
    category_name: String,
    transaction_count: u32,
    total_amount: String,
    has_children: bool,
    child_count: u32,
    date_range: Option<DateRange>,
    suggested_strategy: DeletionStrategy,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DateRange {
    start: NaiveDate,
    end: NaiveDate,
}

impl CategoryConversionService {
    /// 内部实现：分类转标签
    async fn _convert_category_to_tag(
        &self,
        category_id: String,
        options: ConversionOptions,
        _context: ServiceContext,
    ) -> Result<ConversionResult> {
        // 在实际实现中，这里会：
        // 1. 获取分类信息
        // 2. 创建对应的标签
        // 3. 更新相关交易
        // 4. 处理原分类
        // 5. 创建批量操作记录

        // 模拟实现
        let tag_name = options.tag_name.unwrap_or_else(|| "Converted Tag".to_string());
        let tag = Tag::new(tag_name)?;
        
        let mut transactions_updated = 0;
        
        if options.apply_to_transactions {
            // 在实际实现中，查询并更新交易
            transactions_updated = 10; // 模拟值
        }
        
        let category_status = if options.delete_category {
            CategoryStatus::Deleted
        } else {
            CategoryStatus::Retained
        };
        
        let batch_operation_id = if options.create_batch_record {
            Some(crate::utils::generate_id())
        } else {
            None
        };
        
        Ok(ConversionResult {
            tag,
            transactions_updated,
            category_status,
            batch_operation_id,
        })
    }

    /// 内部实现：合并分类
    async fn _merge_categories(
        &self,
        source_category_ids: Vec<String>,
        target_category_id: String,
        delete_sources: bool,
        _context: ServiceContext,
    ) -> Result<BatchResult> {
        let mut result = BatchResult::new();
        
        // 验证目标分类存在
        if target_category_id.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Target category ID is required".to_string(),
            });
        }
        
        // 验证源分类
        if source_category_ids.is_empty() {
            return Err(JiveError::ValidationError {
                message: "At least one source category is required".to_string(),
            });
        }
        
        // 确保目标分类不在源分类列表中
        if source_category_ids.contains(&target_category_id) {
            return Err(JiveError::ValidationError {
                message: "Target category cannot be in source categories".to_string(),
            });
        }
        
        // 处理每个源分类
        for source_id in source_category_ids {
            // 在实际实现中：
            // 1. 将源分类的所有交易重新分配到目标分类
            // 2. 更新子分类的父级（如果有）
            // 3. 如果需要，删除源分类
            
            result.add_success();
        }
        
        Ok(result)
    }

    /// 内部实现：批量重分类
    async fn _batch_recategorize(
        &self,
        transaction_ids: Vec<String>,
        target_category_id: String,
        add_tag: Option<String>,
        context: ServiceContext,
    ) -> Result<BatchOperation> {
        // 创建批量操作记录
        let batch_op = BatchOperation {
            id: crate::utils::generate_id(),
            user_id: context.user_id().to_string(),
            operation_type: BatchOperationType::Recategorize,
            original_data: serde_json::json!({
                "transaction_ids": transaction_ids,
                "original_categories": HashMap::<String, String>::new(), // 在实际实现中记录原始分类
                "target_category_id": target_category_id,
                "add_tag": add_tag,
            }),
            affected_transactions: transaction_ids.len() as u32,
            can_revert: true,
            created_at: Utc::now(),
            expires_at: Utc::now() + chrono::Duration::hours(24),
            reverted_at: None,
        };
        
        // 在实际实现中：
        // 1. 批量更新交易分类
        // 2. 如果指定，添加标签
        // 3. 保存批量操作记录
        
        Ok(batch_op)
    }

    /// 内部实现：撤销批量操作
    async fn _revert_batch_operation(
        &self,
        batch_id: String,
        _context: ServiceContext,
    ) -> Result<bool> {
        // 在实际实现中：
        // 1. 获取批量操作记录
        // 2. 验证是否可以撤销
        // 3. 根据原始数据恢复
        // 4. 标记操作为已撤销
        
        if batch_id.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Batch operation ID is required".to_string(),
            });
        }
        
        // 模拟成功撤销
        Ok(true)
    }

    /// 内部实现：获取批量操作历史
    async fn _get_batch_operations(
        &self,
        limit: u32,
        context: ServiceContext,
    ) -> Result<Vec<BatchOperation>> {
        // 在实际实现中，从数据库查询
        let mut operations = Vec::new();
        
        // 模拟数据
        for i in 0..limit.min(5) {
            let op = BatchOperation {
                id: format!("batch-{}", i),
                user_id: context.user_id().to_string(),
                operation_type: if i % 2 == 0 {
                    BatchOperationType::Recategorize
                } else {
                    BatchOperationType::ConvertToTag
                },
                original_data: serde_json::json!({}),
                affected_transactions: (i + 1) * 10,
                can_revert: i < 2, // 只有最近的操作可以撤销
                created_at: Utc::now() - chrono::Duration::hours(i as i64),
                expires_at: Utc::now() + chrono::Duration::hours(24 - i as i64),
                reverted_at: None,
            };
            operations.push(op);
        }
        
        Ok(operations)
    }

    /// 内部实现：带策略的分类删除
    async fn _delete_category_with_strategy(
        &self,
        category_id: String,
        options: DeletionOptions,
        _context: ServiceContext,
    ) -> Result<BatchResult> {
        let mut result = BatchResult::new();
        
        match options.strategy {
            DeletionStrategy::MoveToCategory(ref target_id) => {
                // 移动所有交易到目标分类
                if let Some(target) = options.target_category_id {
                    // 在实际实现中，批量更新交易
                    result.add_success();
                } else {
                    result.add_error("Target category ID is required".to_string());
                }
            }
            DeletionStrategy::ConvertToTag => {
                // 转换为标签
                let tag_name = options.tag_name.unwrap_or_else(|| "Converted".to_string());
                // 在实际实现中，创建标签并更新交易
                result.add_success();
            }
            DeletionStrategy::Uncategorize => {
                // 清除分类
                // 在实际实现中，将交易设为未分类
                result.add_success();
            }
            DeletionStrategy::Cancel => {
                // 取消删除
                return Ok(result);
            }
        }
        
        // 删除分类
        // 在实际实现中，执行软删除
        
        Ok(result)
    }

    /// 内部实现：分析删除影响
    async fn _analyze_deletion_impact(
        &self,
        category_id: String,
        _context: ServiceContext,
    ) -> Result<DeletionImpact> {
        // 在实际实现中，查询相关数据
        
        let impact = DeletionImpact {
            category_id: category_id.clone(),
            category_name: "Test Category".to_string(),
            transaction_count: 25,
            total_amount: "1250.00".to_string(),
            has_children: false,
            child_count: 0,
            date_range: Some(DateRange {
                start: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
                end: NaiveDate::from_ymd_opt(2024, 12, 31).unwrap(),
            }),
            suggested_strategy: if 25 > 0 {
                DeletionStrategy::ConvertToTag
            } else {
                DeletionStrategy::Uncategorize
            },
        };
        
        Ok(impact)
    }
}

impl Default for CategoryConversionService {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_convert_category_to_tag() {
        let service = CategoryConversionService::new();
        let context = ServiceContext::new("user-123".to_string());
        
        let mut options = ConversionOptions::new();
        options.set_tag_name(Some("Test Tag".to_string()));
        options.set_apply_to_transactions(true);
        options.set_delete_category(true);
        
        let result = service._convert_category_to_tag(
            "category-123".to_string(),
            options,
            context,
        ).await;
        
        assert!(result.is_ok());
        let conversion = result.unwrap();
        assert_eq!(conversion.tag.name(), "Test Tag");
        assert!(matches!(conversion.category_status, CategoryStatus::Deleted));
        assert!(conversion.batch_operation_id.is_some());
    }

    #[tokio::test]
    async fn test_merge_categories() {
        let service = CategoryConversionService::new();
        let context = ServiceContext::new("user-123".to_string());
        
        let source_ids = vec!["cat-1".to_string(), "cat-2".to_string()];
        let target_id = "cat-target".to_string();
        
        let result = service._merge_categories(
            source_ids,
            target_id,
            true,
            context,
        ).await;
        
        assert!(result.is_ok());
        let batch_result = result.unwrap();
        assert_eq!(batch_result.success_count(), 2);
    }

    #[tokio::test]
    async fn test_merge_categories_validation() {
        let service = CategoryConversionService::new();
        let context = ServiceContext::new("user-123".to_string());
        
        // 测试空源分类列表
        let result = service._merge_categories(
            vec![],
            "target".to_string(),
            true,
            context.clone(),
        ).await;
        assert!(result.is_err());
        
        // 测试目标分类在源列表中
        let result = service._merge_categories(
            vec!["cat-1".to_string(), "target".to_string()],
            "target".to_string(),
            true,
            context,
        ).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_batch_recategorize() {
        let service = CategoryConversionService::new();
        let context = ServiceContext::new("user-123".to_string());
        
        let transaction_ids = vec!["tx-1".to_string(), "tx-2".to_string(), "tx-3".to_string()];
        
        let result = service._batch_recategorize(
            transaction_ids.clone(),
            "new-category".to_string(),
            Some("original-category".to_string()),
            context,
        ).await;
        
        assert!(result.is_ok());
        let batch_op = result.unwrap();
        assert_eq!(batch_op.affected_transactions, 3);
        assert!(batch_op.can_revert());
        assert!(matches!(batch_op.operation_type, BatchOperationType::Recategorize));
    }

    #[tokio::test]
    async fn test_deletion_impact_analysis() {
        let service = CategoryConversionService::new();
        let context = ServiceContext::new("user-123".to_string());
        
        let result = service._analyze_deletion_impact(
            "category-123".to_string(),
            context,
        ).await;
        
        assert!(result.is_ok());
        let impact = result.unwrap();
        assert_eq!(impact.transaction_count, 25);
        assert!(matches!(impact.suggested_strategy, DeletionStrategy::ConvertToTag));
    }

    #[test]
    fn test_conversion_options_date_range() {
        let mut options = ConversionOptions::new();
        
        let result = options.set_date_range(
            Some("2024-01-01".to_string()),
            Some("2024-12-31".to_string()),
        );
        
        assert!(result.is_ok());
        assert!(options.date_range_start.is_some());
        assert!(options.date_range_end.is_some());
        
        // 测试无效日期
        let result = options.set_date_range(
            Some("invalid-date".to_string()),
            None,
        );
        assert!(result.is_err());
    }

    #[test]
    fn test_batch_operation_expiry() {
        let op = BatchOperation {
            id: "test".to_string(),
            user_id: "user".to_string(),
            operation_type: BatchOperationType::Recategorize,
            original_data: serde_json::json!({}),
            affected_transactions: 10,
            can_revert: true,
            created_at: Utc::now(),
            expires_at: Utc::now() - chrono::Duration::hours(1), // 已过期
            reverted_at: None,
        };
        
        assert!(op.is_expired());
        assert!(!op.can_revert()); // 过期后不能撤销
    }
}