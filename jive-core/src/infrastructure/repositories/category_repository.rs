//! 分类仓储实现 - 提供分类的数据库访问层
//! 
//! 实现完整的分类CRUD操作、模板管理、批量操作等功能

use async_trait::async_trait;
use sqlx::{PgPool, Row, postgres::PgRow};
use std::sync::Arc;
use uuid::Uuid;
use chrono::{DateTime, Utc, NaiveDate};
use serde_json;

use crate::domain::{
    Category, AccountClassification, SystemCategoryTemplate, 
    CategoryGroup, Tag
};
use crate::application::{
    CategoryConversionService, ConversionOptions, ConversionResult,
    DeletionOptions, DeletionStrategy, BatchOperation, BatchOperationType,
    DeletionImpact, CategoryStatus
};
use crate::error::{JiveError, Result};
use super::{Repository, BaseRepository, RepositoryError};

/// 分类仓储实现
pub struct CategoryRepository {
    pool: Arc<PgPool>,
}

impl CategoryRepository {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }

    /// 获取用户的所有分类（包含层级关系）
    pub async fn find_by_ledger(&self, ledger_id: Uuid) -> Result<Vec<Category>> {
        let rows = sqlx::query(
            r#"
            WITH RECURSIVE category_tree AS (
                -- 根分类
                SELECT 
                    c.*,
                    0 as depth,
                    ARRAY[c.id] as path
                FROM categories c
                WHERE c.ledger_id = $1 
                    AND c.parent_id IS NULL 
                    AND c.deleted_at IS NULL
                
                UNION ALL
                
                -- 子分类
                SELECT 
                    c.*,
                    ct.depth + 1,
                    ct.path || c.id
                FROM categories c
                INNER JOIN category_tree ct ON c.parent_id = ct.id
                WHERE c.deleted_at IS NULL
            )
            SELECT * FROM category_tree
            ORDER BY depth, position, name
            "#
        )
        .bind(ledger_id)
        .fetch_all(&*self.pool)
        .await?;

        rows.into_iter()
            .map(|row| self.row_to_category(row))
            .collect()
    }

    /// 根据分类类型获取分类
    pub async fn find_by_classification(
        &self,
        ledger_id: Uuid,
        classification: AccountClassification,
    ) -> Result<Vec<Category>> {
        let classification_str = match classification {
            AccountClassification::Income => "income",
            AccountClassification::Expense => "expense",
            AccountClassification::Transfer => "transfer",
            _ => return Ok(vec![]),
        };

        let rows = sqlx::query(
            r#"
            SELECT * FROM categories
            WHERE ledger_id = $1 
                AND classification = $2
                AND deleted_at IS NULL
            ORDER BY position, name
            "#
        )
        .bind(ledger_id)
        .bind(classification_str)
        .fetch_all(&*self.pool)
        .await?;

        rows.into_iter()
            .map(|row| self.row_to_category(row))
            .collect()
    }

    /// 创建分类
    pub async fn create(&self, category: Category) -> Result<Category> {
        let classification_str = self.classification_to_string(&category.classification());

        let row = sqlx::query(
            r#"
            INSERT INTO categories (
                id, ledger_id, name, parent_id, classification,
                color, icon, description, position, is_active,
                source_type, template_id, template_version
            ) VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13
            )
            RETURNING *
            "#
        )
        .bind(category.id())
        .bind(category.ledger_id())
        .bind(category.name())
        .bind(category.parent_id())
        .bind(classification_str)
        .bind(category.color())
        .bind(category.icon())
        .bind(category.description())
        .bind(category.position().unwrap_or(0))
        .bind(category.is_active())
        .bind("custom")
        .bind(category.template_id())
        .bind(category.template_version())
        .fetch_one(&*self.pool)
        .await?;

        self.row_to_category(row)
    }

    /// 更新分类
    pub async fn update(&self, category: Category) -> Result<Category> {
        let classification_str = self.classification_to_string(&category.classification());

        let row = sqlx::query(
            r#"
            UPDATE categories SET
                name = $2,
                parent_id = $3,
                classification = $4,
                color = $5,
                icon = $6,
                description = $7,
                position = $8,
                is_active = $9,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $1 AND deleted_at IS NULL
            RETURNING *
            "#
        )
        .bind(category.id())
        .bind(category.name())
        .bind(category.parent_id())
        .bind(classification_str)
        .bind(category.color())
        .bind(category.icon())
        .bind(category.description())
        .bind(category.position().unwrap_or(0))
        .bind(category.is_active())
        .fetch_one(&*self.pool)
        .await?;

        self.row_to_category(row)
    }

    /// 删除分类（软删除）
    pub async fn delete(&self, id: Uuid) -> Result<bool> {
        let result = sqlx::query(
            r#"
            UPDATE categories 
            SET deleted_at = CURRENT_TIMESTAMP
            WHERE id = $1 AND deleted_at IS NULL
            "#
        )
        .bind(id)
        .execute(&*self.pool)
        .await?;

        Ok(result.rows_affected() > 0)
    }

    /// 批量更新分类排序
    pub async fn update_positions(&self, positions: Vec<(Uuid, i32)>) -> Result<()> {
        let mut tx = self.pool.begin().await?;

        for (id, position) in positions {
            sqlx::query(
                r#"
                UPDATE categories 
                SET position = $2, updated_at = CURRENT_TIMESTAMP
                WHERE id = $1
                "#
            )
            .bind(id)
            .bind(position)
            .execute(&mut *tx)
            .await?;
        }

        tx.commit().await?;
        Ok(())
    }

    /// 获取分类使用统计
    pub async fn get_usage_stats(&self, category_id: Uuid) -> Result<CategoryUsageStats> {
        let row = sqlx::query(
            r#"
            SELECT 
                COUNT(DISTINCT t.id) as transaction_count,
                COALESCE(SUM(t.amount), 0) as total_amount,
                MIN(t.date) as first_used,
                MAX(t.date) as last_used
            FROM transactions t
            WHERE t.category_id = $1
                AND t.deleted_at IS NULL
            "#
        )
        .bind(category_id)
        .fetch_one(&*self.pool)
        .await?;

        Ok(CategoryUsageStats {
            transaction_count: row.get::<i64, _>("transaction_count") as u32,
            total_amount: row.get::<rust_decimal::Decimal, _>("total_amount").to_string(),
            first_used: row.get("first_used"),
            last_used: row.get("last_used"),
        })
    }

    /// 将分类转换为标签
    pub async fn convert_to_tag(
        &self,
        category_id: Uuid,
        options: ConversionOptions,
    ) -> Result<ConversionResult> {
        let mut tx = self.pool.begin().await?;

        // 1. 获取分类信息
        let category_row = sqlx::query(
            "SELECT * FROM categories WHERE id = $1 AND deleted_at IS NULL"
        )
        .bind(category_id)
        .fetch_one(&mut *tx)
        .await?;

        let category_name: String = category_row.get("name");
        let tag_name = options.tag_name().unwrap_or(category_name.clone());

        // 2. 创建标签
        let tag_id = Uuid::new_v4();
        sqlx::query(
            r#"
            INSERT INTO tags (id, name, color, created_at)
            VALUES ($1, $2, $3, CURRENT_TIMESTAMP)
            "#
        )
        .bind(tag_id)
        .bind(&tag_name)
        .bind(category_row.get::<String, _>("color"))
        .execute(&mut *tx)
        .await?;

        // 3. 更新交易（如果需要）
        let mut transactions_updated = 0;
        if options.apply_to_transactions() {
            let result = sqlx::query(
                r#"
                UPDATE transactions 
                SET tags = array_append(tags, $1::uuid)
                WHERE category_id = $2
                    AND deleted_at IS NULL
                    AND ($3::date IS NULL OR date >= $3)
                    AND ($4::date IS NULL OR date <= $4)
                "#
            )
            .bind(tag_id)
            .bind(category_id)
            .bind(options.date_range_start())
            .bind(options.date_range_end())
            .execute(&mut *tx)
            .await?;

            transactions_updated = result.rows_affected() as u32;
        }

        // 4. 处理原分类
        let category_status = if options.delete_category() {
            sqlx::query(
                "UPDATE categories SET deleted_at = CURRENT_TIMESTAMP WHERE id = $1"
            )
            .bind(category_id)
            .execute(&mut *tx)
            .await?;
            CategoryStatus::Deleted
        } else {
            CategoryStatus::Retained
        };

        // 5. 创建批量操作记录
        let batch_operation_id = if options.create_batch_record() {
            let batch_id = Uuid::new_v4();
            let original_data = serde_json::json!({
                "category_id": category_id,
                "category_name": category_name,
                "tag_id": tag_id,
                "tag_name": tag_name,
                "transactions_updated": transactions_updated,
            });

            sqlx::query(
                r#"
                INSERT INTO category_batch_operations (
                    id, user_id, operation_type, original_data,
                    affected_transactions, can_revert
                ) VALUES ($1, $2, 'convert', $3, $4, true)
                "#
            )
            .bind(batch_id)
            .bind(Uuid::new_v4()) // TODO: Get actual user_id from context
            .bind(original_data)
            .bind(transactions_updated as i32)
            .execute(&mut *tx)
            .await?;

            Some(batch_id.to_string())
        } else {
            None
        };

        // 6. 记录转换历史
        sqlx::query(
            r#"
            INSERT INTO category_conversions (
                user_id, ledger_id, source_category_id, source_category_name,
                target_tag_id, target_tag_name, applied_to_transactions,
                transaction_count, date_range_start, date_range_end,
                category_deleted
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            "#
        )
        .bind(Uuid::new_v4()) // TODO: Get actual user_id
        .bind(category_row.get::<Uuid, _>("ledger_id"))
        .bind(category_id)
        .bind(&category_name)
        .bind(tag_id)
        .bind(&tag_name)
        .bind(options.apply_to_transactions())
        .bind(transactions_updated as i32)
        .bind(options.date_range_start())
        .bind(options.date_range_end())
        .bind(options.delete_category())
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;

        // Create Tag object
        let tag = Tag::new(tag_name)?;

        Ok(ConversionResult::new(
            tag,
            transactions_updated,
            category_status,
            batch_operation_id,
        ))
    }

    /// 分析分类删除影响
    pub async fn analyze_deletion_impact(&self, category_id: Uuid) -> Result<DeletionImpact> {
        // 获取分类信息和相关统计
        let impact_row = sqlx::query(
            r#"
            SELECT 
                c.id,
                c.name,
                COUNT(DISTINCT t.id) as transaction_count,
                COALESCE(SUM(t.amount), 0) as total_amount,
                MIN(t.date) as date_start,
                MAX(t.date) as date_end,
                (SELECT COUNT(*) FROM categories WHERE parent_id = c.id) as child_count
            FROM categories c
            LEFT JOIN transactions t ON t.category_id = c.id AND t.deleted_at IS NULL
            WHERE c.id = $1 AND c.deleted_at IS NULL
            GROUP BY c.id, c.name
            "#
        )
        .bind(category_id)
        .fetch_one(&*self.pool)
        .await?;

        let transaction_count = impact_row.get::<i64, _>("transaction_count") as u32;
        let has_children = impact_row.get::<i64, _>("child_count") > 0;

        // 建议策略
        let suggested_strategy = if transaction_count > 0 {
            DeletionStrategy::ConvertToTag
        } else if has_children {
            DeletionStrategy::Cancel
        } else {
            DeletionStrategy::Uncategorize
        };

        Ok(DeletionImpact::new(
            category_id.to_string(),
            impact_row.get("name"),
            transaction_count,
            impact_row.get::<rust_decimal::Decimal, _>("total_amount").to_string(),
            has_children,
            impact_row.get::<i64, _>("child_count") as u32,
            impact_row.get("date_start"),
            impact_row.get("date_end"),
            suggested_strategy,
        ))
    }

    /// 获取分类建议（基于使用历史和关键词）
    pub async fn get_suggestions(
        &self,
        description: &str,
        user_id: Uuid,
        ledger_id: Uuid,
        limit: i32,
    ) -> Result<Vec<CategorySuggestion>> {
        let rows = sqlx::query(
            r#"
            SELECT * FROM get_category_suggestions($1, $2, $3, $4)
            "#
        )
        .bind(description)
        .bind(user_id)
        .bind(ledger_id)
        .bind(limit)
        .fetch_all(&*self.pool)
        .await?;

        Ok(rows.into_iter().map(|row| CategorySuggestion {
            category_id: row.get("category_id"),
            category_name: row.get("category_name"),
            confidence_score: row.get("confidence_score"),
            reason: row.get("reason"),
        }).collect())
    }

    /// 辅助方法：将数据库行转换为Category对象
    fn row_to_category(&self, row: PgRow) -> Result<Category> {
        let classification = self.string_to_classification(row.get("classification"))?;
        
        let mut category = Category::new(
            row.get("name"),
            classification,
            row.get("ledger_id"),
        )?;

        // 设置其他属性
        if let Some(parent_id) = row.get::<Option<Uuid>, _>("parent_id") {
            category.set_parent_id(Some(parent_id.to_string()));
        }
        
        category.set_color(row.get("color"));
        category.set_icon(row.get("icon"));
        category.set_description(row.get("description"));
        category.set_position(row.get("position"));
        category.set_active(row.get("is_active"));

        Ok(category)
    }

    /// 辅助方法：分类类型转字符串
    fn classification_to_string(&self, classification: &AccountClassification) -> &str {
        match classification {
            AccountClassification::Income => "income",
            AccountClassification::Expense => "expense",
            AccountClassification::Transfer => "transfer",
            _ => "expense",
        }
    }

    /// 辅助方法：字符串转分类类型
    fn string_to_classification(&self, s: &str) -> Result<AccountClassification> {
        match s {
            "income" => Ok(AccountClassification::Income),
            "expense" => Ok(AccountClassification::Expense),
            "transfer" => Ok(AccountClassification::Transfer),
            _ => Err(JiveError::ValidationError {
                message: format!("Unknown classification: {}", s),
            }),
        }
    }
}

/// 系统分类模板仓储
pub struct CategoryTemplateRepository {
    pool: Arc<PgPool>,
}

impl CategoryTemplateRepository {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }

    /// 获取所有系统模板
    pub async fn find_all(&self) -> Result<Vec<SystemCategoryTemplate>> {
        let rows = sqlx::query(
            r#"
            SELECT t.*, g.key as group_key, g.name as group_name
            FROM system_category_templates t
            LEFT JOIN category_groups g ON t.category_group = g.key
            WHERE t.is_active = true
            ORDER BY g.display_order, t.is_featured DESC, t.name
            "#
        )
        .fetch_all(&*self.pool)
        .await?;

        rows.into_iter()
            .map(|row| self.row_to_template(row))
            .collect()
    }

    /// 按分组获取模板
    pub async fn find_by_group(&self, group: CategoryGroup) -> Result<Vec<SystemCategoryTemplate>> {
        let group_key = group.key();
        
        let rows = sqlx::query(
            r#"
            SELECT t.*, g.key as group_key, g.name as group_name
            FROM system_category_templates t
            LEFT JOIN category_groups g ON t.category_group = g.key
            WHERE t.category_group = $1 AND t.is_active = true
            ORDER BY t.is_featured DESC, t.name
            "#
        )
        .bind(group_key)
        .fetch_all(&*self.pool)
        .await?;

        rows.into_iter()
            .map(|row| self.row_to_template(row))
            .collect()
    }

    /// 按分类类型获取模板
    pub async fn find_by_classification(
        &self,
        classification: AccountClassification,
    ) -> Result<Vec<SystemCategoryTemplate>> {
        let classification_str = match classification {
            AccountClassification::Income => "income",
            AccountClassification::Expense => "expense",
            AccountClassification::Transfer => "transfer",
            _ => return Ok(vec![]),
        };

        let rows = sqlx::query(
            r#"
            SELECT t.*, g.key as group_key, g.name as group_name
            FROM system_category_templates t
            LEFT JOIN category_groups g ON t.category_group = g.key
            WHERE t.classification = $1 AND t.is_active = true
            ORDER BY g.display_order, t.is_featured DESC, t.name
            "#
        )
        .bind(classification_str)
        .fetch_all(&*self.pool)
        .await?;

        rows.into_iter()
            .map(|row| self.row_to_template(row))
            .collect()
    }

    /// 获取精选模板
    pub async fn find_featured(&self) -> Result<Vec<SystemCategoryTemplate>> {
        let rows = sqlx::query(
            r#"
            SELECT t.*, g.key as group_key, g.name as group_name
            FROM system_category_templates t
            LEFT JOIN category_groups g ON t.category_group = g.key
            WHERE t.is_featured = true AND t.is_active = true
            ORDER BY t.global_usage_count DESC, t.name
            "#
        )
        .fetch_all(&*self.pool)
        .await?;

        rows.into_iter()
            .map(|row| self.row_to_template(row))
            .collect()
    }

    /// 搜索模板
    pub async fn search(&self, query: &str) -> Result<Vec<SystemCategoryTemplate>> {
        let search_pattern = format!("%{}%", query);
        
        let rows = sqlx::query(
            r#"
            SELECT t.*, g.key as group_key, g.name as group_name
            FROM system_category_templates t
            LEFT JOIN category_groups g ON t.category_group = g.key
            WHERE t.is_active = true
                AND (
                    t.name ILIKE $1
                    OR t.name_en ILIKE $1
                    OR t.name_zh ILIKE $1
                    OR $1 = ANY(t.tags)
                )
            ORDER BY 
                CASE WHEN t.name ILIKE $1 THEN 0 ELSE 1 END,
                t.is_featured DESC,
                t.global_usage_count DESC
            "#
        )
        .bind(&search_pattern)
        .fetch_all(&*self.pool)
        .await?;

        rows.into_iter()
            .map(|row| self.row_to_template(row))
            .collect()
    }

    /// 增加模板使用计数
    pub async fn increment_usage(&self, template_id: Uuid) -> Result<()> {
        sqlx::query(
            r#"
            UPDATE system_category_templates 
            SET global_usage_count = global_usage_count + 1,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $1
            "#
        )
        .bind(template_id)
        .execute(&*self.pool)
        .await?;

        Ok(())
    }

    /// 从模板导入为用户分类
    pub async fn import_as_category(
        &self,
        template_id: Uuid,
        ledger_id: Uuid,
    ) -> Result<Category> {
        let mut tx = self.pool.begin().await?;

        // 获取模板信息
        let template_row = sqlx::query(
            "SELECT * FROM system_category_templates WHERE id = $1"
        )
        .bind(template_id)
        .fetch_one(&mut *tx)
        .await?;

        // 创建分类
        let category_id = Uuid::new_v4();
        let classification = self.string_to_classification(template_row.get("classification"))?;
        
        let category_row = sqlx::query(
            r#"
            INSERT INTO categories (
                id, ledger_id, name, classification, color, icon,
                source_type, template_id, template_version
            ) VALUES (
                $1, $2, $3, $4, $5, $6, 'system', $7, $8
            )
            RETURNING *
            "#
        )
        .bind(category_id)
        .bind(ledger_id)
        .bind(template_row.get::<String, _>("name"))
        .bind(template_row.get::<String, _>("classification"))
        .bind(template_row.get::<String, _>("color"))
        .bind(template_row.get::<Option<String>, _>("icon"))
        .bind(template_id)
        .bind(template_row.get::<String, _>("version"))
        .fetch_one(&mut *tx)
        .await?;

        // 增加模板使用计数
        sqlx::query(
            r#"
            UPDATE system_category_templates 
            SET global_usage_count = global_usage_count + 1
            WHERE id = $1
            "#
        )
        .bind(template_id)
        .execute(&mut *tx)
        .await?;

        tx.commit().await?;

        self.row_to_category(category_row)
    }

    /// 辅助方法：将数据库行转换为模板对象
    fn row_to_template(&self, row: PgRow) -> Result<SystemCategoryTemplate> {
        let classification = self.string_to_classification(row.get("classification"))?;
        let group_key: String = row.get("category_group");
        let group = CategoryGroup::from_string(&group_key)
            .ok_or_else(|| JiveError::ValidationError {
                message: format!("Unknown category group: {}", group_key),
            })?;

        let template = SystemCategoryTemplate::new(
            row.get("name"),
            classification,
            row.get("color"),
            group,
        )?;

        // 设置其他属性
        // Note: 需要扩展 SystemCategoryTemplate 以支持更多设置方法

        Ok(template)
    }

    fn string_to_classification(&self, s: &str) -> Result<AccountClassification> {
        match s {
            "income" => Ok(AccountClassification::Income),
            "expense" => Ok(AccountClassification::Expense),
            "transfer" => Ok(AccountClassification::Transfer),
            _ => Err(JiveError::ValidationError {
                message: format!("Unknown classification: {}", s),
            }),
        }
    }
}

/// 批量操作仓储
pub struct BatchOperationRepository {
    pool: Arc<PgPool>,
}

impl BatchOperationRepository {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }

    /// 获取用户的批量操作历史
    pub async fn find_by_user(
        &self,
        user_id: Uuid,
        limit: i32,
    ) -> Result<Vec<BatchOperation>> {
        let rows = sqlx::query(
            r#"
            SELECT * FROM category_batch_operations
            WHERE user_id = $1
            ORDER BY created_at DESC
            LIMIT $2
            "#
        )
        .bind(user_id)
        .bind(limit)
        .fetch_all(&*self.pool)
        .await?;

        rows.into_iter()
            .map(|row| self.row_to_batch_operation(row))
            .collect()
    }

    /// 撤销批量操作
    pub async fn revert(&self, batch_id: Uuid) -> Result<bool> {
        let mut tx = self.pool.begin().await?;

        // 获取批量操作记录
        let batch_row = sqlx::query(
            r#"
            SELECT * FROM category_batch_operations
            WHERE id = $1 
                AND can_revert = true 
                AND reverted_at IS NULL
                AND expires_at > CURRENT_TIMESTAMP
            "#
        )
        .bind(batch_id)
        .fetch_optional(&mut *tx)
        .await?;

        if let Some(row) = batch_row {
            let original_data: serde_json::Value = row.get("original_data");
            let operation_type: String = row.get("operation_type");

            // 根据操作类型执行撤销逻辑
            match operation_type.as_str() {
                "convert" => {
                    // 撤销分类转标签操作
                    if let Some(category_id) = original_data.get("category_id") {
                        // 恢复分类
                        sqlx::query(
                            "UPDATE categories SET deleted_at = NULL WHERE id = $1"
                        )
                        .bind(category_id.as_str().unwrap().parse::<Uuid>().unwrap())
                        .execute(&mut *tx)
                        .await?;
                    }
                }
                "recategorize" => {
                    // 撤销批量重分类
                    // 需要根据original_data恢复原始分类
                }
                _ => {}
            }

            // 标记操作为已撤销
            sqlx::query(
                r#"
                UPDATE category_batch_operations 
                SET reverted_at = CURRENT_TIMESTAMP
                WHERE id = $1
                "#
            )
            .bind(batch_id)
            .execute(&mut *tx)
            .await?;

            tx.commit().await?;
            Ok(true)
        } else {
            Ok(false)
        }
    }

    fn row_to_batch_operation(&self, row: PgRow) -> Result<BatchOperation> {
        let operation_type = match row.get::<String, _>("operation_type").as_str() {
            "recategorize" => BatchOperationType::Recategorize,
            "convert" => BatchOperationType::ConvertToTag,
            "merge" => BatchOperationType::Merge,
            "delete" => BatchOperationType::Delete,
            _ => BatchOperationType::Recategorize,
        };

        Ok(BatchOperation::new(
            row.get::<Uuid, _>("id").to_string(),
            row.get::<Uuid, _>("user_id").to_string(),
            operation_type,
            row.get("original_data"),
            row.get::<i32, _>("affected_transactions") as u32,
            row.get("can_revert"),
            row.get("created_at"),
            row.get("expires_at"),
            row.get("reverted_at"),
        ))
    }
}

// 辅助结构体
#[derive(Debug, Clone)]
pub struct CategoryUsageStats {
    pub transaction_count: u32,
    pub total_amount: String,
    pub first_used: Option<NaiveDate>,
    pub last_used: Option<NaiveDate>,
}

#[derive(Debug, Clone)]
pub struct CategorySuggestion {
    pub category_id: Uuid,
    pub category_name: String,
    pub confidence_score: f32,
    pub reason: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_category_repository() {
        // 测试需要真实的数据库连接
        // 这里只是示例结构
    }
}