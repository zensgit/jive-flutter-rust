//! Category service - 分类管理服务
//!
//! 基于 Maybe 的分类功能转换而来，包括分类CRUD、分组、自动分类等功能

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use super::{BatchResult, PaginationParams, ServiceContext, ServiceResponse};
use crate::domain::Category;
use crate::error::{JiveError, Result};

/// 分类创建请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CreateCategoryRequest {
    name: String,
    parent_id: Option<String>,
    color: Option<String>,
    icon: Option<String>,
    description: Option<String>,
    is_system: bool,
    is_active: bool,
    sort_order: i32,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CreateCategoryRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(name: String) -> Self {
        Self {
            name,
            parent_id: None,
            color: None,
            icon: None,
            description: None,
            is_system: false,
            is_active: true,
            sort_order: 0,
        }
    }

    // Getters
    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String {
        self.name.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn parent_id(&self) -> Option<String> {
        self.parent_id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn is_active(&self) -> bool {
        self.is_active
    }

    // Setters
    #[wasm_bindgen(setter)]
    pub fn set_parent_id(&mut self, parent_id: Option<String>) {
        self.parent_id = parent_id;
    }

    #[wasm_bindgen(setter)]
    pub fn set_color(&mut self, color: Option<String>) {
        self.color = color;
    }

    #[wasm_bindgen(setter)]
    pub fn set_icon(&mut self, icon: Option<String>) {
        self.icon = icon;
    }

    #[wasm_bindgen(setter)]
    pub fn set_description(&mut self, description: Option<String>) {
        self.description = description;
    }

    #[wasm_bindgen(setter)]
    pub fn set_sort_order(&mut self, sort_order: i32) {
        self.sort_order = sort_order;
    }
}

/// 分类更新请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UpdateCategoryRequest {
    name: Option<String>,
    parent_id: Option<String>,
    color: Option<String>,
    icon: Option<String>,
    description: Option<String>,
    is_active: Option<bool>,
    sort_order: Option<i32>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl UpdateCategoryRequest {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            name: None,
            parent_id: None,
            color: None,
            icon: None,
            description: None,
            is_active: None,
            sort_order: None,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_name(&mut self, name: Option<String>) {
        self.name = name;
    }

    #[wasm_bindgen(setter)]
    pub fn set_parent_id(&mut self, parent_id: Option<String>) {
        self.parent_id = parent_id;
    }

    #[wasm_bindgen(setter)]
    pub fn set_is_active(&mut self, is_active: Option<bool>) {
        self.is_active = is_active;
    }

    #[wasm_bindgen(setter)]
    pub fn set_sort_order(&mut self, sort_order: Option<i32>) {
        self.sort_order = sort_order;
    }
}

/// 分类筛选器
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CategoryFilter {
    parent_id: Option<String>,
    is_active: Option<bool>,
    is_system: Option<bool>,
    search_query: Option<String>,
    include_children: bool,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CategoryFilter {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            parent_id: None,
            is_active: None,
            is_system: None,
            search_query: None,
            include_children: true,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_parent_id(&mut self, parent_id: Option<String>) {
        self.parent_id = parent_id;
    }

    #[wasm_bindgen(setter)]
    pub fn set_is_active(&mut self, is_active: Option<bool>) {
        self.is_active = is_active;
    }

    #[wasm_bindgen(setter)]
    pub fn set_search_query(&mut self, query: Option<String>) {
        self.search_query = query;
    }

    #[wasm_bindgen(setter)]
    pub fn set_include_children(&mut self, include: bool) {
        self.include_children = include;
    }
}

impl Default for CategoryFilter {
    fn default() -> Self {
        Self::new()
    }
}

/// 分类树节点
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CategoryTreeNode {
    category: Category,
    children: Vec<CategoryTreeNode>,
    depth: u32,
    transaction_count: u32,
    total_amount: String,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CategoryTreeNode {
    #[wasm_bindgen(getter)]
    pub fn category(&self) -> Category {
        self.category.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn children(&self) -> Vec<CategoryTreeNode> {
        self.children.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn depth(&self) -> u32 {
        self.depth
    }

    #[wasm_bindgen(getter)]
    pub fn transaction_count(&self) -> u32 {
        self.transaction_count
    }

    #[wasm_bindgen(getter)]
    pub fn total_amount(&self) -> String {
        self.total_amount.clone()
    }

    #[wasm_bindgen]
    pub fn has_children(&self) -> bool {
        !self.children.is_empty()
    }

    #[wasm_bindgen]
    pub fn is_leaf(&self) -> bool {
        self.children.is_empty()
    }
}

/// 分类统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CategoryStats {
    total_categories: u32,
    active_categories: u32,
    system_categories: u32,
    user_categories: u32,
    max_depth: u32,
    most_used_categories: Vec<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CategoryStats {
    #[wasm_bindgen(getter)]
    pub fn total_categories(&self) -> u32 {
        self.total_categories
    }

    #[wasm_bindgen(getter)]
    pub fn active_categories(&self) -> u32 {
        self.active_categories
    }

    #[wasm_bindgen(getter)]
    pub fn system_categories(&self) -> u32 {
        self.system_categories
    }

    #[wasm_bindgen(getter)]
    pub fn user_categories(&self) -> u32 {
        self.user_categories
    }

    #[wasm_bindgen(getter)]
    pub fn max_depth(&self) -> u32 {
        self.max_depth
    }

    #[wasm_bindgen(getter)]
    pub fn most_used_categories(&self) -> Vec<String> {
        self.most_used_categories.clone()
    }
}

/// 分类合并请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct MergeCategoriesRequest {
    source_category_ids: Vec<String>,
    target_category_id: String,
    delete_source_categories: bool,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl MergeCategoriesRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(target_category_id: String) -> Self {
        Self {
            source_category_ids: Vec::new(),
            target_category_id,
            delete_source_categories: true,
        }
    }

    #[wasm_bindgen]
    pub fn add_source_category(&mut self, category_id: String) {
        if !self.source_category_ids.contains(&category_id) {
            self.source_category_ids.push(category_id);
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_delete_source_categories(&mut self, delete: bool) {
        self.delete_source_categories = delete;
    }
}

/// 批量分类操作
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum BulkCategoryOperation {
    Activate,
    Deactivate,
    Delete,
    ChangeParent,
    UpdateColor,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl BulkCategoryOperation {
    #[wasm_bindgen(getter)]
    pub fn as_string(&self) -> String {
        match self {
            BulkCategoryOperation::Activate => "activate".to_string(),
            BulkCategoryOperation::Deactivate => "deactivate".to_string(),
            BulkCategoryOperation::Delete => "delete".to_string(),
            BulkCategoryOperation::ChangeParent => "change_parent".to_string(),
            BulkCategoryOperation::UpdateColor => "update_color".to_string(),
        }
    }
}

/// 批量分类操作请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BulkCategoryRequest {
    category_ids: Vec<String>,
    operation: BulkCategoryOperation,
    new_parent_id: Option<String>,
    new_color: Option<String>,
}

/// 分类服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CategoryService {
    // 在实际实现中，这里会包含数据库连接或仓储接口
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CategoryService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {}
    }

    /// 创建分类
    #[wasm_bindgen]
    pub async fn create_category(
        &self,
        request: CreateCategoryRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Category> {
        let result = self._create_category(request, context).await;
        result.into()
    }

    /// 更新分类
    #[wasm_bindgen]
    pub async fn update_category(
        &self,
        category_id: String,
        request: UpdateCategoryRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Category> {
        let result = self._update_category(category_id, request, context).await;
        result.into()
    }

    /// 获取分类详情
    #[wasm_bindgen]
    pub async fn get_category(
        &self,
        category_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Category> {
        let result = self._get_category(category_id, context).await;
        result.into()
    }

    /// 删除分类
    #[wasm_bindgen]
    pub async fn delete_category(
        &self,
        category_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._delete_category(category_id, context).await;
        result.into()
    }

    /// 搜索分类
    #[wasm_bindgen]
    pub async fn search_categories(
        &self,
        filter: CategoryFilter,
        pagination: PaginationParams,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Category>> {
        let result = self._search_categories(filter, pagination, context).await;
        result.into()
    }

    /// 获取分类树
    #[wasm_bindgen]
    pub async fn get_category_tree(
        &self,
        root_id: Option<String>,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<CategoryTreeNode>> {
        let result = self._get_category_tree(root_id, context).await;
        result.into()
    }

    /// 移动分类
    #[wasm_bindgen]
    pub async fn move_category(
        &self,
        category_id: String,
        new_parent_id: Option<String>,
        context: ServiceContext,
    ) -> ServiceResponse<Category> {
        let result = self
            ._move_category(category_id, new_parent_id, context)
            .await;
        result.into()
    }

    /// 合并分类
    #[wasm_bindgen]
    pub async fn merge_categories(
        &self,
        request: MergeCategoriesRequest,
        context: ServiceContext,
    ) -> ServiceResponse<BatchResult> {
        let result = self._merge_categories(request, context).await;
        result.into()
    }

    /// 批量操作分类
    #[wasm_bindgen]
    pub async fn bulk_update_categories(
        &self,
        request: BulkCategoryRequest,
        context: ServiceContext,
    ) -> ServiceResponse<BatchResult> {
        let result = self._bulk_update_categories(request, context).await;
        result.into()
    }

    /// 复制分类
    #[wasm_bindgen]
    pub async fn duplicate_category(
        &self,
        category_id: String,
        new_name: String,
        context: ServiceContext,
    ) -> ServiceResponse<Category> {
        let result = self
            ._duplicate_category(category_id, new_name, context)
            .await;
        result.into()
    }

    /// 获取分类统计信息
    #[wasm_bindgen]
    pub async fn get_category_stats(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<CategoryStats> {
        let result = self._get_category_stats(context).await;
        result.into()
    }

    /// 获取热门分类
    #[wasm_bindgen]
    pub async fn get_popular_categories(
        &self,
        limit: u32,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Category>> {
        let result = self._get_popular_categories(limit, context).await;
        result.into()
    }

    /// 获取未分类的交易数量
    #[wasm_bindgen]
    pub async fn get_uncategorized_transaction_count(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<u32> {
        let result = self._get_uncategorized_transaction_count(context).await;
        result.into()
    }

    /// 建议分类（基于交易描述）
    #[wasm_bindgen]
    pub async fn suggest_category(
        &self,
        transaction_description: String,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Category>> {
        let result = self
            ._suggest_category(transaction_description, context)
            .await;
        result.into()
    }
}

impl CategoryService {
    /// 创建分类的内部实现
    async fn _create_category(
        &self,
        request: CreateCategoryRequest,
        _context: ServiceContext,
    ) -> Result<Category> {
        // 验证输入
        if request.name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Category name is required".to_string(),
            });
        }

        // 验证父分类是否存在
        if let Some(parent_id) = &request.parent_id {
            if !parent_id.is_empty() {
                // 在实际实现中，检查父分类是否存在
                // let _parent = repository.find_by_id(parent_id).await?;
            }
        }

        // 创建分类
        let mut category = Category::builder()
            .name(request.name)
            .is_system(request.is_system)
            .is_active(request.is_active)
            .build()?;

        // 设置可选字段
        if let Some(parent_id) = request.parent_id {
            category.set_parent_id(Some(parent_id));
        }

        if let Some(color) = request.color {
            category.set_color(Some(color))?;
        }

        if let Some(icon) = request.icon {
            category.set_icon(Some(icon));
        }

        if let Some(description) = request.description {
            category.set_description(Some(description));
        }

        category.set_sort_order(request.sort_order);

        // 在实际实现中，这里会保存到数据库
        // let saved_category = repository.save(category).await?;

        Ok(category)
    }

    /// 更新分类的内部实现
    async fn _update_category(
        &self,
        category_id: String,
        request: UpdateCategoryRequest,
        _context: ServiceContext,
    ) -> Result<Category> {
        // 获取现有分类
        let mut category = self._get_category(category_id, _context).await?;

        // 应用更新
        if let Some(name) = request.name {
            category.set_name(name)?;
        }

        if let Some(parent_id) = request.parent_id {
            category.set_parent_id(Some(parent_id));
        }

        if let Some(color) = request.color {
            category.set_color(Some(color))?;
        }

        if let Some(icon) = request.icon {
            category.set_icon(Some(icon));
        }

        if let Some(description) = request.description {
            category.set_description(Some(description));
        }

        if let Some(is_active) = request.is_active {
            category.set_is_active(is_active);
        }

        if let Some(sort_order) = request.sort_order {
            category.set_sort_order(sort_order);
        }

        // 在实际实现中，这里会保存到数据库
        // let updated_category = repository.save(category).await?;

        Ok(category)
    }

    /// 获取分类的内部实现
    async fn _get_category(
        &self,
        category_id: String,
        _context: ServiceContext,
    ) -> Result<Category> {
        // 在实际实现中，从数据库获取分类
        if category_id.is_empty() {
            return Err(JiveError::CategoryNotFound { id: category_id });
        }

        // 模拟分类获取
        let category = Category::new("Test Category".to_string())?;

        Ok(category)
    }

    /// 删除分类的内部实现
    async fn _delete_category(
        &self,
        category_id: String,
        _context: ServiceContext,
    ) -> Result<bool> {
        // 检查分类是否存在
        let mut category = self._get_category(category_id, _context).await?;

        // 检查是否有子分类
        // let child_count = repository.count_children(category.id()).await?;
        // if child_count > 0 {
        //     return Err(JiveError::ValidationError {
        //         message: "Cannot delete category with children".to_string(),
        //     });
        // }

        // 检查是否有关联交易
        // let transaction_count = transaction_repository.count_by_category_id(category.id()).await?;
        // if transaction_count > 0 {
        //     return Err(JiveError::ValidationError {
        //         message: "Cannot delete category with transactions".to_string(),
        //     });
        // }

        // 执行软删除
        category.soft_delete();

        // 在实际实现中，这里会保存到数据库
        // repository.save(category).await?;

        Ok(true)
    }

    /// 搜索分类的内部实现
    async fn _search_categories(
        &self,
        filter: CategoryFilter,
        _pagination: PaginationParams,
        _context: ServiceContext,
    ) -> Result<Vec<Category>> {
        // 在实际实现中，构建查询并执行
        let mut categories = Vec::new();

        // 模拟一些分类数据
        for i in 1..=5 {
            let mut category = Category::new(format!("Category {}", i))?;
            if i % 2 == 0 {
                category.set_parent_id(Some("parent-category".to_string()));
            }
            categories.push(category);
        }

        // 应用过滤器
        if let Some(_parent_id) = filter.parent_id {
            // 按父分类过滤
        }

        if let Some(_is_active) = filter.is_active {
            // 按活跃状态过滤
        }

        if let Some(_is_system) = filter.is_system {
            // 按系统分类过滤
        }

        if let Some(_search_query) = filter.search_query {
            // 按搜索查询过滤
        }

        Ok(categories)
    }

    /// 获取分类树的内部实现
    async fn _get_category_tree(
        &self,
        _root_id: Option<String>,
        context: ServiceContext,
    ) -> Result<Vec<CategoryTreeNode>> {
        // 获取所有分类
        let categories = self
            ._search_categories(
                CategoryFilter::default(),
                PaginationParams::new(1, 1000),
                context,
            )
            .await?;

        // 构建分类树
        let mut tree = Vec::new();
        let mut category_map = HashMap::new();

        // 建立分类映射
        for category in categories {
            category_map.insert(category.id(), category);
        }

        // 构建树结构
        for (_, category) in category_map {
            if category.parent_id().is_none() {
                let node = CategoryTreeNode {
                    category: category.clone(),
                    children: Vec::new(), // 在实际实现中会递归构建子节点
                    depth: 0,
                    transaction_count: 0,             // 从数据库查询
                    total_amount: "0.00".to_string(), // 从数据库聚合
                };
                tree.push(node);
            }
        }

        Ok(tree)
    }

    /// 移动分类的内部实现
    async fn _move_category(
        &self,
        category_id: String,
        new_parent_id: Option<String>,
        context: ServiceContext,
    ) -> Result<Category> {
        let mut category = self._get_category(category_id, context).await?;

        // 验证新父分类
        if let Some(ref parent_id) = new_parent_id {
            if !parent_id.is_empty() {
                // 检查父分类是否存在
                let _parent = self._get_category(parent_id.clone(), context).await?;

                // 检查是否会形成循环引用
                // if self._would_create_cycle(&category, parent_id).await? {
                //     return Err(JiveError::ValidationError {
                //         message: "Would create circular reference".to_string(),
                //     });
                // }
            }
        }

        category.set_parent_id(new_parent_id);

        // 在实际实现中，这里会保存到数据库
        // let updated_category = repository.save(category).await?;

        Ok(category)
    }

    /// 合并分类的内部实现
    async fn _merge_categories(
        &self,
        request: MergeCategoriesRequest,
        context: ServiceContext,
    ) -> Result<BatchResult> {
        let mut result = BatchResult::new();

        // 检查目标分类是否存在
        let _target_category = self
            ._get_category(request.target_category_id.clone(), context.clone())
            .await?;

        for source_id in request.source_category_ids {
            match self
                ._merge_single_category(
                    &source_id,
                    &request.target_category_id,
                    request.delete_source_categories,
                    &context,
                )
                .await
            {
                Ok(_) => result.add_success(),
                Err(error) => result.add_error(error.to_string()),
            }
        }

        Ok(result)
    }

    /// 合并单个分类
    async fn _merge_single_category(
        &self,
        source_id: &str,
        target_id: &str,
        delete_source: bool,
        _context: &ServiceContext,
    ) -> Result<()> {
        // 在实际实现中：
        // 1. 将源分类的所有交易重新分配到目标分类
        // 2. 如果需要，删除源分类
        // 3. 更新相关统计信息

        // transaction_repository.update_category_bulk(source_id, target_id).await?;
        //
        // if delete_source {
        //     self._delete_category(source_id.to_string(), context.clone()).await?;
        // }

        Ok(())
    }

    /// 批量更新分类的内部实现
    async fn _bulk_update_categories(
        &self,
        request: BulkCategoryRequest,
        context: ServiceContext,
    ) -> Result<BatchResult> {
        let mut result = BatchResult::new();

        for category_id in request.category_ids {
            match self
                ._apply_bulk_operation(&category_id, &request, &context)
                .await
            {
                Ok(_) => result.add_success(),
                Err(error) => result.add_error(error.to_string()),
            }
        }

        Ok(result)
    }

    /// 应用批量操作
    async fn _apply_bulk_operation(
        &self,
        category_id: &str,
        request: &BulkCategoryRequest,
        context: &ServiceContext,
    ) -> Result<()> {
        let mut category = self
            ._get_category(category_id.to_string(), context.clone())
            .await?;

        match request.operation {
            BulkCategoryOperation::Activate => {
                category.set_is_active(true);
            }
            BulkCategoryOperation::Deactivate => {
                category.set_is_active(false);
            }
            BulkCategoryOperation::Delete => {
                category.soft_delete();
            }
            BulkCategoryOperation::ChangeParent => {
                if let Some(ref new_parent_id) = request.new_parent_id {
                    category.set_parent_id(Some(new_parent_id.clone()));
                }
            }
            BulkCategoryOperation::UpdateColor => {
                if let Some(ref new_color) = request.new_color {
                    category.set_color(Some(new_color.clone()))?;
                }
            }
        }

        // 在实际实现中，这里会保存到数据库
        // repository.save(category).await?;

        Ok(())
    }

    /// 复制分类的内部实现
    async fn _duplicate_category(
        &self,
        category_id: String,
        new_name: String,
        context: ServiceContext,
    ) -> Result<Category> {
        let original_category = self._get_category(category_id, context.clone()).await?;

        let request = CreateCategoryRequest {
            name: new_name,
            parent_id: original_category.parent_id(),
            color: original_category.color(),
            icon: original_category.icon(),
            description: original_category.description(),
            is_system: false, // 复制的分类不是系统分类
            is_active: true,
            sort_order: original_category.sort_order(),
        };

        self._create_category(request, context).await
    }

    /// 获取统计信息的内部实现
    async fn _get_category_stats(&self, _context: ServiceContext) -> Result<CategoryStats> {
        // 在实际实现中，从数据库聚合统计数据
        let stats = CategoryStats {
            total_categories: 25,
            active_categories: 22,
            system_categories: 10,
            user_categories: 15,
            max_depth: 3,
            most_used_categories: vec![
                "Food & Dining".to_string(),
                "Transportation".to_string(),
                "Shopping".to_string(),
            ],
        };

        Ok(stats)
    }

    /// 获取热门分类的内部实现
    async fn _get_popular_categories(
        &self,
        limit: u32,
        _context: ServiceContext,
    ) -> Result<Vec<Category>> {
        // 在实际实现中，按交易数量或金额排序
        let mut categories = Vec::new();

        for i in 1..=limit.min(5) {
            let category = Category::new(format!("Popular Category {}", i))?;
            categories.push(category);
        }

        Ok(categories)
    }

    /// 获取未分类交易数量的内部实现
    async fn _get_uncategorized_transaction_count(&self, _context: ServiceContext) -> Result<u32> {
        // 在实际实现中，从数据库查询
        // transaction_repository.count_uncategorized().await
        Ok(42)
    }

    /// 建议分类的内部实现
    async fn _suggest_category(
        &self,
        transaction_description: String,
        context: ServiceContext,
    ) -> Result<Vec<Category>> {
        // 在实际实现中，可以使用机器学习或规则引擎
        let mut suggestions = Vec::new();

        // 简单的关键词匹配示例
        let description_lower = transaction_description.to_lowercase();

        if description_lower.contains("food") || description_lower.contains("restaurant") {
            let category = Category::new("Food & Dining".to_string())?;
            suggestions.push(category);
        }

        if description_lower.contains("gas") || description_lower.contains("fuel") {
            let category = Category::new("Transportation".to_string())?;
            suggestions.push(category);
        }

        if description_lower.contains("store") || description_lower.contains("shop") {
            let category = Category::new("Shopping".to_string())?;
            suggestions.push(category);
        }

        // 如果没有匹配到，返回热门分类
        if suggestions.is_empty() {
            suggestions = self._get_popular_categories(3, context).await?;
        }

        Ok(suggestions)
    }
}

impl Default for CategoryService {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_category() {
        let service = CategoryService::new();
        let context = ServiceContext::new("user-123".to_string());

        let request = CreateCategoryRequest::new("Test Category".to_string());

        let result = service._create_category(request, context).await;
        assert!(result.is_ok());

        let category = result.unwrap();
        assert_eq!(category.name(), "Test Category");
        assert!(category.is_active());
    }

    #[tokio::test]
    async fn test_category_validation() {
        let service = CategoryService::new();
        let context = ServiceContext::new("user-123".to_string());

        let request = CreateCategoryRequest::new("".to_string()); // 空名称应该失败

        let result = service._create_category(request, context).await;
        assert!(result.is_err());
    }

    #[tokio::test]
    async fn test_suggest_category() {
        let service = CategoryService::new();
        let context = ServiceContext::new("user-123".to_string());

        let result = service
            ._suggest_category("McDonald's restaurant".to_string(), context)
            .await;
        assert!(result.is_ok());

        let suggestions = result.unwrap();
        assert!(!suggestions.is_empty());
        assert_eq!(suggestions[0].name(), "Food & Dining");
    }

    #[test]
    fn test_bulk_operation_string() {
        let op = BulkCategoryOperation::Activate;
        assert_eq!(op.as_string(), "activate");

        let op = BulkCategoryOperation::Delete;
        assert_eq!(op.as_string(), "delete");
    }
}
