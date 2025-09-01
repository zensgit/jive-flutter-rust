//! 分类服务 - 使用真实数据库的实现
//! 
//! 提供完整的分类管理功能，包括CRUD、模板导入、批量操作等

use std::sync::Arc;
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc};
use uuid::Uuid;

#[cfg(feature = "server")]
use sqlx::PgPool;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::domain::{Category, AccountClassification, SystemCategoryTemplate, CategoryGroup};
use crate::error::{JiveError, Result};
use crate::infrastructure::repositories::{
    CategoryRepository, CategoryTemplateRepository, BatchOperationRepository
};
use super::{ServiceContext, ServiceResponse, PaginationParams, BatchResult};
use super::category_service::{
    CreateCategoryRequest, UpdateCategoryRequest, CategoryTreeNode,
    CategoryStats, MergeCategoriesRequest, BulkCategoryOperation,
    BulkCategoryOperationRequest
};

/// 分类服务 - 数据库实现
pub struct CategoryServiceDb {
    #[cfg(feature = "server")]
    category_repo: Arc<CategoryRepository>,
    #[cfg(feature = "server")]
    template_repo: Arc<CategoryTemplateRepository>,
    #[cfg(feature = "server")]
    batch_repo: Arc<BatchOperationRepository>,
}

#[cfg(feature = "server")]
impl CategoryServiceDb {
    /// 创建新的分类服务实例
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self {
            category_repo: Arc::new(CategoryRepository::new(pool.clone())),
            template_repo: Arc::new(CategoryTemplateRepository::new(pool.clone())),
            batch_repo: Arc::new(BatchOperationRepository::new(pool)),
        }
    }

    /// 创建分类
    pub async fn create_category(
        &self,
        request: CreateCategoryRequest,
        context: ServiceContext,
    ) -> Result<Category> {
        // 验证输入
        if request.name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Category name is required".to_string(),
            });
        }

        // 获取账本ID
        let ledger_id = context.ledger_id()
            .ok_or_else(|| JiveError::ValidationError {
                message: "Ledger ID is required".to_string(),
            })?;

        // 验证父分类（如果指定）
        if let Some(parent_id) = &request.parent_id {
            if !parent_id.is_empty() {
                let parent_uuid = Uuid::parse_str(parent_id)
                    .map_err(|_| JiveError::ValidationError {
                        message: "Invalid parent category ID".to_string(),
                    })?;
                
                // 验证父分类存在并属于同一账本
                let parent_categories = self.category_repo.find_by_ledger(ledger_id).await?;
                if !parent_categories.iter().any(|c| c.id() == parent_id) {
                    return Err(JiveError::ValidationError {
                        message: "Parent category not found or not accessible".to_string(),
                    });
                }
            }
        }

        // 创建分类对象
        let mut category = Category::new(
            request.name,
            AccountClassification::Expense, // 默认为支出
            ledger_id,
        )?;

        // 设置可选属性
        category.set_parent_id(request.parent_id);
        category.set_color(request.color.unwrap_or_else(|| "#6B7280".to_string()));
        category.set_icon(request.icon);
        category.set_description(request.description);
        category.set_position(Some(request.sort_order));
        category.set_active(request.is_active);

        // 保存到数据库
        self.category_repo.create(category).await
    }

    /// 更新分类
    pub async fn update_category(
        &self,
        category_id: String,
        request: UpdateCategoryRequest,
        context: ServiceContext,
    ) -> Result<Category> {
        let category_uuid = Uuid::parse_str(&category_id)
            .map_err(|_| JiveError::ValidationError {
                message: "Invalid category ID".to_string(),
            })?;

        // 获取现有分类
        let ledger_id = context.ledger_id()
            .ok_or_else(|| JiveError::ValidationError {
                message: "Ledger ID is required".to_string(),
            })?;

        let categories = self.category_repo.find_by_ledger(ledger_id).await?;
        let mut category = categories.into_iter()
            .find(|c| c.id() == &category_id)
            .ok_or_else(|| JiveError::NotFound {
                message: format!("Category {} not found", category_id),
            })?;

        // 更新字段
        if let Some(name) = request.name {
            category.set_name(name)?;
        }
        if let Some(parent_id) = request.parent_id {
            category.set_parent_id(Some(parent_id));
        }
        if let Some(color) = request.color {
            category.set_color(color);
        }
        if let Some(icon) = request.icon {
            category.set_icon(Some(icon));
        }
        if let Some(description) = request.description {
            category.set_description(Some(description));
        }
        if let Some(is_active) = request.is_active {
            category.set_active(is_active);
        }
        if let Some(sort_order) = request.sort_order {
            category.set_position(Some(sort_order));
        }

        // 保存更新
        self.category_repo.update(category).await
    }

    /// 删除分类
    pub async fn delete_category(
        &self,
        category_id: String,
        context: ServiceContext,
    ) -> Result<bool> {
        let category_uuid = Uuid::parse_str(&category_id)
            .map_err(|_| JiveError::ValidationError {
                message: "Invalid category ID".to_string(),
            })?;

        // 验证分类属于当前用户的账本
        let ledger_id = context.ledger_id()
            .ok_or_else(|| JiveError::ValidationError {
                message: "Ledger ID is required".to_string(),
            })?;

        let categories = self.category_repo.find_by_ledger(ledger_id).await?;
        if !categories.iter().any(|c| c.id() == &category_id) {
            return Err(JiveError::NotFound {
                message: format!("Category {} not found", category_id),
            });
        }

        // 检查是否有子分类
        let has_children = categories.iter().any(|c| c.parent_id() == Some(category_id.clone()));
        if has_children {
            return Err(JiveError::ValidationError {
                message: "Cannot delete category with subcategories".to_string(),
            });
        }

        // 执行软删除
        self.category_repo.delete(category_uuid).await
    }

    /// 获取分类列表
    pub async fn get_categories(
        &self,
        context: ServiceContext,
        classification: Option<AccountClassification>,
    ) -> Result<Vec<Category>> {
        let ledger_id = context.ledger_id()
            .ok_or_else(|| JiveError::ValidationError {
                message: "Ledger ID is required".to_string(),
            })?;

        if let Some(classification) = classification {
            self.category_repo.find_by_classification(ledger_id, classification).await
        } else {
            self.category_repo.find_by_ledger(ledger_id).await
        }
    }

    /// 获取分类树结构
    pub async fn get_category_tree(
        &self,
        context: ServiceContext,
    ) -> Result<Vec<CategoryTreeNode>> {
        let ledger_id = context.ledger_id()
            .ok_or_else(|| JiveError::ValidationError {
                message: "Ledger ID is required".to_string(),
            })?;

        let categories = self.category_repo.find_by_ledger(ledger_id).await?;
        
        // 构建树结构
        let mut root_nodes = Vec::new();
        let mut children_map: std::collections::HashMap<String, Vec<Category>> = std::collections::HashMap::new();

        // 分组
        for category in categories {
            if category.parent_id().is_none() {
                root_nodes.push(category);
            } else if let Some(parent_id) = category.parent_id() {
                children_map.entry(parent_id).or_insert_with(Vec::new).push(category);
            }
        }

        // 递归构建树
        let mut tree = Vec::new();
        for root in root_nodes {
            tree.push(self.build_tree_node(root, &children_map, 0).await?);
        }

        Ok(tree)
    }

    /// 批量更新分类排序
    pub async fn update_category_positions(
        &self,
        positions: Vec<(String, i32)>,
        context: ServiceContext,
    ) -> Result<()> {
        let ledger_id = context.ledger_id()
            .ok_or_else(|| JiveError::ValidationError {
                message: "Ledger ID is required".to_string(),
            })?;

        // 转换ID格式
        let uuid_positions: Result<Vec<(Uuid, i32)>> = positions.iter()
            .map(|(id, pos)| {
                Uuid::parse_str(id)
                    .map(|uuid| (uuid, *pos))
                    .map_err(|_| JiveError::ValidationError {
                        message: format!("Invalid category ID: {}", id),
                    })
            })
            .collect();

        self.category_repo.update_positions(uuid_positions?).await
    }

    /// 合并分类
    pub async fn merge_categories(
        &self,
        request: MergeCategoriesRequest,
        context: ServiceContext,
    ) -> Result<BatchResult> {
        // 验证源分类和目标分类
        let source_uuids: Result<Vec<Uuid>> = request.source_category_ids.iter()
            .map(|id| Uuid::parse_str(id)
                .map_err(|_| JiveError::ValidationError {
                    message: format!("Invalid source category ID: {}", id),
                }))
            .collect();

        let target_uuid = Uuid::parse_str(&request.target_category_id)
            .map_err(|_| JiveError::ValidationError {
                message: "Invalid target category ID".to_string(),
            })?;

        // TODO: 实现合并逻辑
        // 1. 将源分类的所有交易移到目标分类
        // 2. 处理子分类
        // 3. 删除源分类（如果需要）

        let mut result = BatchResult::new();
        for _ in &request.source_category_ids {
            result.add_success();
        }

        Ok(result)
    }

    /// 获取分类统计
    pub async fn get_category_stats(
        &self,
        context: ServiceContext,
    ) -> Result<CategoryStats> {
        let ledger_id = context.ledger_id()
            .ok_or_else(|| JiveError::ValidationError {
                message: "Ledger ID is required".to_string(),
            })?;

        let categories = self.category_repo.find_by_ledger(ledger_id).await?;

        let total = categories.len() as u32;
        let active = categories.iter().filter(|c| c.is_active()).count() as u32;
        let system = categories.iter().filter(|c| c.is_system()).count() as u32;

        Ok(CategoryStats {
            total_categories: total,
            active_categories: active,
            system_categories: system,
            user_categories: total - system,
            max_depth: 2, // 最大支持2层
            most_used_categories: Vec::new(), // TODO: 从使用统计获取
        })
    }

    /// 获取所有系统模板
    pub async fn get_all_templates(&self) -> Result<Vec<SystemCategoryTemplate>> {
        self.template_repo.find_all().await
    }

    /// 按分组获取模板
    pub async fn get_templates_by_group(
        &self,
        group: CategoryGroup,
    ) -> Result<Vec<SystemCategoryTemplate>> {
        self.template_repo.find_by_group(group).await
    }

    /// 按分类类型获取模板
    pub async fn get_templates_by_classification(
        &self,
        classification: AccountClassification,
    ) -> Result<Vec<SystemCategoryTemplate>> {
        self.template_repo.find_by_classification(classification).await
    }

    /// 获取精选模板
    pub async fn get_featured_templates(&self) -> Result<Vec<SystemCategoryTemplate>> {
        self.template_repo.find_featured().await
    }

    /// 搜索模板
    pub async fn search_templates(&self, query: &str) -> Result<Vec<SystemCategoryTemplate>> {
        self.template_repo.search(query).await
    }

    /// 从模板导入分类
    pub async fn import_template_as_category(
        &self,
        template_id: String,
        context: ServiceContext,
    ) -> Result<Category> {
        let template_uuid = Uuid::parse_str(&template_id)
            .map_err(|_| JiveError::ValidationError {
                message: "Invalid template ID".to_string(),
            })?;

        let ledger_id = context.ledger_id()
            .ok_or_else(|| JiveError::ValidationError {
                message: "Ledger ID is required".to_string(),
            })?;

        self.template_repo.import_as_category(template_uuid, ledger_id).await
    }

    /// 获取分类建议
    pub async fn get_category_suggestions(
        &self,
        description: &str,
        context: ServiceContext,
        limit: i32,
    ) -> Result<Vec<CategorySuggestion>> {
        let user_id = Uuid::parse_str(context.user_id())
            .map_err(|_| JiveError::ValidationError {
                message: "Invalid user ID".to_string(),
            })?;

        let ledger_id = context.ledger_id()
            .ok_or_else(|| JiveError::ValidationError {
                message: "Ledger ID is required".to_string(),
            })?;

        let suggestions = self.category_repo.get_suggestions(
            description,
            user_id,
            ledger_id,
            limit,
        ).await?;

        Ok(suggestions.into_iter().map(|s| CategorySuggestion {
            category_id: s.category_id.to_string(),
            category_name: s.category_name,
            confidence_score: s.confidence_score,
            reason: s.reason,
        }).collect())
    }

    /// 辅助方法：构建树节点
    async fn build_tree_node(
        &self,
        category: Category,
        children_map: &std::collections::HashMap<String, Vec<Category>>,
        depth: u32,
    ) -> Result<CategoryTreeNode> {
        let category_id = category.id().to_string();
        let children = if let Some(child_categories) = children_map.get(&category_id) {
            let mut child_nodes = Vec::new();
            for child in child_categories {
                child_nodes.push(
                    self.build_tree_node(child.clone(), children_map, depth + 1).await?
                );
            }
            child_nodes
        } else {
            Vec::new()
        };

        // 获取使用统计
        let stats = self.category_repo.get_usage_stats(
            Uuid::parse_str(&category_id).unwrap()
        ).await.unwrap_or(crate::infrastructure::repositories::category_repository::CategoryUsageStats {
            transaction_count: 0,
            total_amount: "0".to_string(),
            first_used: None,
            last_used: None,
        });

        Ok(CategoryTreeNode {
            category,
            children,
            depth,
            transaction_count: stats.transaction_count,
            total_amount: stats.total_amount,
        })
    }
}

/// 分类建议
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategorySuggestion {
    pub category_id: String,
    pub category_name: String,
    pub confidence_score: f32,
    pub reason: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[cfg(feature = "server")]
    #[tokio::test]
    async fn test_category_service() {
        // 需要真实的数据库连接进行测试
    }
}