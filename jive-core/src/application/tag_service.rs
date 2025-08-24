//! TagService - 标签管理服务
//! 
//! 处理标签的创建、管理、分组以及标签与各种实体的关联
//! 支持标签层级、颜色、图标、使用统计等功能

use serde::{Serialize, Deserialize};
use chrono::NaiveDateTime;
use std::collections::{HashMap, HashSet};

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::{
    error::{JiveError, Result},
};

use super::{ServiceContext, ServiceResponse, PaginationParams};

/// 标签管理服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct TagService {
    // 模拟标签存储
    tags: std::sync::Arc<std::sync::Mutex<Vec<Tag>>>,
    // 标签组存储
    tag_groups: std::sync::Arc<std::sync::Mutex<Vec<TagGroup>>>,
    // 标签关联存储
    tag_associations: std::sync::Arc<std::sync::Mutex<Vec<TagAssociation>>>,
    // 标签统计缓存
    tag_statistics: std::sync::Arc<std::sync::Mutex<HashMap<String, TagStatistics>>>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl TagService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        let mut service = Self {
            tags: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
            tag_groups: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
            tag_associations: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
            tag_statistics: std::sync::Arc::new(std::sync::Mutex::new(HashMap::new())),
        };
        
        // 初始化默认标签组
        service.init_default_groups();
        service
    }
}

impl TagService {
    /// 创建标签
    pub async fn create_tag(
        &self,
        request: CreateTagRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Tag> {
        // 验证请求
        if request.name.is_empty() {
            return ServiceResponse::error(
                JiveError::ValidationError { message: "Tag name is required".to_string() }
            );
        }

        // 检查重复
        let storage = self.tags.lock().unwrap();
        if storage.iter().any(|t| t.name == request.name && t.user_id == context.user_id) {
            return ServiceResponse::error(
                JiveError::ValidationError { message: format!("Tag '{}' already exists", request.name) }
            );
        }
        drop(storage);

        // 验证颜色格式
        if let Some(ref color) = request.color {
            if !self.is_valid_color(color) {
                return ServiceResponse::error(
                    JiveError::ValidationError { message: "Invalid color format".to_string() }
                );
            }
        }

        // 创建标签
        let tag = Tag {
            id: format!("tag_{}", uuid::Uuid::new_v4()),
            name: request.name,
            display_name: request.display_name,
            description: request.description,
            color: request.color.unwrap_or_else(|| self.generate_color()),
            icon: request.icon,
            group_id: request.group_id,
            parent_id: request.parent_id,
            order_index: request.order_index.unwrap_or(0),
            is_system: false,
            is_archived: false,
            usage_count: 0,
            last_used: None,
            created_at: chrono::Utc::now().naive_utc(),
            updated_at: chrono::Utc::now().naive_utc(),
            user_id: context.user_id.clone(),
            ledger_id: context.current_ledger_id.clone(),
        };

        // 保存标签
        let mut storage = self.tags.lock().unwrap();
        storage.push(tag.clone());

        // 初始化统计
        let mut stats = self.tag_statistics.lock().unwrap();
        stats.insert(tag.id.clone(), TagStatistics::default());

        ServiceResponse::success_with_message(
            tag,
            "Tag created successfully".to_string()
        )
    }

    /// 更新标签
    pub async fn update_tag(
        &self,
        id: String,
        request: UpdateTagRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Tag> {
        let mut storage = self.tags.lock().unwrap();
        
        if let Some(tag) = storage.iter_mut().find(|t| t.id == id && t.user_id == context.user_id) {
            // 系统标签不能修改
            if tag.is_system {
                return ServiceResponse::error(
                    JiveError::ValidationError { message: "System tags cannot be modified".to_string() }
                );
            }

            // 更新字段
            if let Some(name) = request.name {
                // 检查重复
                if storage.iter().any(|t| t.id != id && t.name == name && t.user_id == context.user_id) {
                    return ServiceResponse::error(
                        JiveError::ValidationError { message: format!("Tag '{}' already exists", name) }
                    );
                }
                tag.name = name;
            }
            
            if let Some(display_name) = request.display_name {
                tag.display_name = Some(display_name);
            }
            
            if let Some(description) = request.description {
                tag.description = Some(description);
            }
            
            if let Some(color) = request.color {
                if !self.is_valid_color(&color) {
                    return ServiceResponse::error(
                        JiveError::ValidationError { message: "Invalid color format".to_string() }
                    );
                }
                tag.color = color;
            }
            
            if let Some(icon) = request.icon {
                tag.icon = Some(icon);
            }
            
            if let Some(group_id) = request.group_id {
                tag.group_id = Some(group_id);
            }
            
            if let Some(parent_id) = request.parent_id {
                // 防止循环引用
                if parent_id == tag.id {
                    return ServiceResponse::error(
                        JiveError::ValidationError { message: "Tag cannot be its own parent".to_string() }
                    );
                }
                tag.parent_id = Some(parent_id);
            }
            
            if let Some(order_index) = request.order_index {
                tag.order_index = order_index;
            }

            tag.updated_at = chrono::Utc::now().naive_utc();

            ServiceResponse::success(tag.clone())
        } else {
            ServiceResponse::error(
                JiveError::NotFound { message: format!("Tag {} not found", id) }
            )
        }
    }

    /// 删除标签
    pub async fn delete_tag(
        &self,
        id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let mut storage = self.tags.lock().unwrap();
        
        // 检查是否是系统标签
        if let Some(tag) = storage.iter().find(|t| t.id == id) {
            if tag.is_system {
                return ServiceResponse::error(
                    JiveError::ValidationError { message: "System tags cannot be deleted".to_string() }
                );
            }
        }

        let original_len = storage.len();
        storage.retain(|t| t.id != id || t.user_id != context.user_id);

        if storage.len() < original_len {
            // 删除关联
            let mut associations = self.tag_associations.lock().unwrap();
            associations.retain(|a| a.tag_id != id);

            // 删除统计
            let mut stats = self.tag_statistics.lock().unwrap();
            stats.remove(&id);

            ServiceResponse::success(true)
        } else {
            ServiceResponse::error(
                JiveError::NotFound { message: format!("Tag {} not found", id) }
            )
        }
    }

    /// 获取标签列表
    pub async fn list_tags(
        &self,
        filter: TagFilter,
        pagination: PaginationParams,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Tag>> {
        let storage = self.tags.lock().unwrap();
        
        let mut results: Vec<_> = storage.iter()
            .filter(|t| t.user_id == context.user_id)
            .filter(|t| {
                // 应用过滤器
                if let Some(ref group_id) = filter.group_id {
                    if t.group_id.as_ref() != Some(group_id) {
                        return false;
                    }
                }
                
                if let Some(ref parent_id) = filter.parent_id {
                    if t.parent_id.as_ref() != Some(parent_id) {
                        return false;
                    }
                }
                
                if let Some(is_archived) = filter.is_archived {
                    if t.is_archived != is_archived {
                        return false;
                    }
                }
                
                if let Some(ref search) = filter.search {
                    let search_lower = search.to_lowercase();
                    if !t.name.to_lowercase().contains(&search_lower) &&
                       !t.display_name.as_ref().map_or(false, |d| 
                           d.to_lowercase().contains(&search_lower)) {
                        return false;
                    }
                }
                
                true
            })
            .cloned()
            .collect();

        // 排序
        results.sort_by_key(|t| (t.order_index, t.name.clone()));

        // 分页
        let start = pagination.offset as usize;
        let end = (start + pagination.per_page as usize).min(results.len());
        let page_results = results[start..end].to_vec();

        ServiceResponse::success(page_results)
    }

    /// 获取标签详情
    pub async fn get_tag(
        &self,
        id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Tag> {
        let storage = self.tags.lock().unwrap();
        
        if let Some(tag) = storage.iter().find(|t| t.id == id && t.user_id == context.user_id) {
            ServiceResponse::success(tag.clone())
        } else {
            ServiceResponse::error(
                JiveError::NotFound { message: format!("Tag {} not found", id) }
            )
        }
    }

    /// 获取标签树
    pub async fn get_tag_tree(
        &self,
        group_id: Option<String>,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<TagNode>> {
        let storage = self.tags.lock().unwrap();
        
        // 过滤标签
        let tags: Vec<_> = storage.iter()
            .filter(|t| t.user_id == context.user_id)
            .filter(|t| {
                if let Some(ref gid) = group_id {
                    t.group_id.as_ref() == Some(gid)
                } else {
                    true
                }
            })
            .cloned()
            .collect();

        // 构建树
        let tree = self.build_tag_tree(tags);

        ServiceResponse::success(tree)
    }

    /// 创建标签组
    pub async fn create_tag_group(
        &self,
        request: CreateTagGroupRequest,
        context: ServiceContext,
    ) -> ServiceResponse<TagGroup> {
        // 验证请求
        if request.name.is_empty() {
            return ServiceResponse::error(
                JiveError::ValidationError { message: "Group name is required".to_string() }
            );
        }

        // 检查重复
        let storage = self.tag_groups.lock().unwrap();
        if storage.iter().any(|g| g.name == request.name && g.user_id == context.user_id) {
            return ServiceResponse::error(
                JiveError::ValidationError { message: format!("Group '{}' already exists", request.name) }
            );
        }
        drop(storage);

        // 创建标签组
        let group = TagGroup {
            id: format!("group_{}", uuid::Uuid::new_v4()),
            name: request.name,
            description: request.description,
            color: request.color.unwrap_or_else(|| self.generate_color()),
            icon: request.icon,
            order_index: request.order_index.unwrap_or(0),
            is_system: false,
            tag_count: 0,
            created_at: chrono::Utc::now().naive_utc(),
            updated_at: chrono::Utc::now().naive_utc(),
            user_id: context.user_id.clone(),
        };

        // 保存标签组
        let mut storage = self.tag_groups.lock().unwrap();
        storage.push(group.clone());

        ServiceResponse::success_with_message(
            group,
            "Tag group created successfully".to_string()
        )
    }

    /// 获取标签组列表
    pub async fn list_tag_groups(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<TagGroup>> {
        let mut groups = self.tag_groups.lock().unwrap();
        
        // 更新标签计数
        let tags = self.tags.lock().unwrap();
        for group in groups.iter_mut() {
            group.tag_count = tags.iter()
                .filter(|t| t.group_id.as_ref() == Some(&group.id))
                .count() as u32;
        }

        let results: Vec<_> = groups.iter()
            .filter(|g| g.user_id == context.user_id)
            .cloned()
            .collect();

        ServiceResponse::success(results)
    }

    /// 添加标签到实体
    pub async fn add_tags_to_entity(
        &self,
        entity_type: EntityType,
        entity_id: String,
        tag_ids: Vec<String>,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<TagAssociation>> {
        let mut associations = self.tag_associations.lock().unwrap();
        let mut new_associations = Vec::new();

        for tag_id in tag_ids {
            // 检查标签是否存在
            let tags = self.tags.lock().unwrap();
            if !tags.iter().any(|t| t.id == tag_id && t.user_id == context.user_id) {
                continue;
            }
            drop(tags);

            // 检查是否已关联
            if associations.iter().any(|a| 
                a.tag_id == tag_id && 
                a.entity_id == entity_id && 
                a.entity_type == entity_type) {
                continue;
            }

            // 创建关联
            let association = TagAssociation {
                id: format!("assoc_{}", uuid::Uuid::new_v4()),
                tag_id: tag_id.clone(),
                entity_type: entity_type.clone(),
                entity_id: entity_id.clone(),
                created_at: chrono::Utc::now().naive_utc(),
                user_id: context.user_id.clone(),
            };

            associations.push(association.clone());
            new_associations.push(association);

            // 更新使用统计
            self.update_tag_usage(&tag_id, true);
        }

        ServiceResponse::success_with_message(
            new_associations,
            format!("Added {} tags to entity", new_associations.len())
        )
    }

    /// 从实体移除标签
    pub async fn remove_tags_from_entity(
        &self,
        entity_type: EntityType,
        entity_id: String,
        tag_ids: Vec<String>,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let mut associations = self.tag_associations.lock().unwrap();
        let original_len = associations.len();

        for tag_id in &tag_ids {
            associations.retain(|a| 
                !(a.tag_id == *tag_id && 
                  a.entity_id == entity_id && 
                  a.entity_type == entity_type &&
                  a.user_id == context.user_id)
            );

            // 更新使用统计
            self.update_tag_usage(tag_id, false);
        }

        ServiceResponse::success(associations.len() < original_len)
    }

    /// 获取实体的标签
    pub async fn get_entity_tags(
        &self,
        entity_type: EntityType,
        entity_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Tag>> {
        let associations = self.tag_associations.lock().unwrap();
        let tags = self.tags.lock().unwrap();

        let tag_ids: HashSet<_> = associations.iter()
            .filter(|a| 
                a.entity_type == entity_type && 
                a.entity_id == entity_id &&
                a.user_id == context.user_id)
            .map(|a| a.tag_id.clone())
            .collect();

        let entity_tags: Vec<_> = tags.iter()
            .filter(|t| tag_ids.contains(&t.id))
            .cloned()
            .collect();

        ServiceResponse::success(entity_tags)
    }

    /// 获取标签的实体
    pub async fn get_tag_entities(
        &self,
        tag_id: String,
        entity_type: Option<EntityType>,
        limit: u32,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<TaggedEntity>> {
        let associations = self.tag_associations.lock().unwrap();

        let mut entities: Vec<_> = associations.iter()
            .filter(|a| a.tag_id == tag_id && a.user_id == context.user_id)
            .filter(|a| {
                if let Some(ref et) = entity_type {
                    &a.entity_type == et
                } else {
                    true
                }
            })
            .map(|a| TaggedEntity {
                entity_type: a.entity_type.clone(),
                entity_id: a.entity_id.clone(),
                tagged_at: a.created_at,
            })
            .take(limit as usize)
            .collect();

        // 按时间倒序
        entities.sort_by(|a, b| b.tagged_at.cmp(&a.tagged_at));

        ServiceResponse::success(entities)
    }

    /// 合并标签
    pub async fn merge_tags(
        &self,
        source_tag_ids: Vec<String>,
        target_tag_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<MergeResult> {
        // 验证目标标签存在
        let tags = self.tags.lock().unwrap();
        if !tags.iter().any(|t| t.id == target_tag_id && t.user_id == context.user_id) {
            return ServiceResponse::error(
                JiveError::NotFound { message: format!("Target tag {} not found", target_tag_id) }
            );
        }
        drop(tags);

        let mut associations = self.tag_associations.lock().unwrap();
        let mut merged_count = 0;
        let mut conflict_count = 0;

        for source_id in &source_tag_ids {
            if source_id == &target_tag_id {
                continue;
            }

            // 移动所有关联到目标标签
            let source_associations: Vec<_> = associations.iter()
                .filter(|a| a.tag_id == *source_id)
                .cloned()
                .collect();

            for assoc in source_associations {
                // 检查冲突
                if associations.iter().any(|a| 
                    a.tag_id == target_tag_id && 
                    a.entity_id == assoc.entity_id && 
                    a.entity_type == assoc.entity_type) {
                    conflict_count += 1;
                    continue;
                }

                // 创建新关联
                associations.push(TagAssociation {
                    id: format!("assoc_{}", uuid::Uuid::new_v4()),
                    tag_id: target_tag_id.clone(),
                    entity_type: assoc.entity_type,
                    entity_id: assoc.entity_id,
                    created_at: chrono::Utc::now().naive_utc(),
                    user_id: context.user_id.clone(),
                });
                merged_count += 1;
            }

            // 删除源关联
            associations.retain(|a| a.tag_id != *source_id);
        }

        // 删除源标签
        let mut tags = self.tags.lock().unwrap();
        tags.retain(|t| !source_tag_ids.contains(&t.id));

        ServiceResponse::success(MergeResult {
            target_tag_id,
            merged_tags: source_tag_ids.len() as u32,
            associations_moved: merged_count,
            conflicts_resolved: conflict_count,
        })
    }

    /// 获取标签统计
    pub async fn get_tag_statistics(
        &self,
        tag_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<TagStatistics> {
        let stats = self.tag_statistics.lock().unwrap();
        
        if let Some(stat) = stats.get(&tag_id) {
            ServiceResponse::success(stat.clone())
        } else {
            // 计算统计
            let associations = self.tag_associations.lock().unwrap();
            let usage_count = associations.iter()
                .filter(|a| a.tag_id == tag_id)
                .count() as u32;

            let mut by_type = HashMap::new();
            for assoc in associations.iter().filter(|a| a.tag_id == tag_id) {
                *by_type.entry(assoc.entity_type.clone()).or_insert(0) += 1;
            }

            let statistics = TagStatistics {
                tag_id: tag_id.clone(),
                total_usage: usage_count,
                usage_by_type: by_type,
                last_30_days: 0, // 简化处理
                trend: 0.0,
                related_tags: Vec::new(), // 可以通过共同出现计算
            };

            ServiceResponse::success(statistics)
        }
    }

    /// 获取热门标签
    pub async fn get_popular_tags(
        &self,
        limit: u32,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<PopularTag>> {
        let tags = self.tags.lock().unwrap();
        let mut popular: Vec<_> = tags.iter()
            .filter(|t| t.user_id == context.user_id)
            .map(|t| PopularTag {
                tag: t.clone(),
                usage_count: t.usage_count,
                trend: 0.0, // 简化处理
            })
            .collect();

        // 按使用次数排序
        popular.sort_by(|a, b| b.usage_count.cmp(&a.usage_count));
        popular.truncate(limit as usize);

        ServiceResponse::success(popular)
    }

    /// 搜索标签
    pub async fn search_tags(
        &self,
        query: String,
        limit: u32,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Tag>> {
        let storage = self.tags.lock().unwrap();
        let query_lower = query.to_lowercase();

        let mut results: Vec<_> = storage.iter()
            .filter(|t| t.user_id == context.user_id)
            .filter(|t| {
                t.name.to_lowercase().contains(&query_lower) ||
                t.display_name.as_ref().map_or(false, |d| 
                    d.to_lowercase().contains(&query_lower))
            })
            .cloned()
            .collect();

        // 按相关性排序（简化：按名称长度）
        results.sort_by_key(|t| t.name.len());
        results.truncate(limit as usize);

        ServiceResponse::success(results)
    }

    /// 批量操作标签
    pub async fn bulk_update_tags(
        &self,
        tag_ids: Vec<String>,
        update: BulkTagUpdate,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Tag>> {
        let mut storage = self.tags.lock().unwrap();
        let mut updated = Vec::new();

        for tag in storage.iter_mut() {
            if tag_ids.contains(&tag.id) && tag.user_id == context.user_id {
                if !tag.is_system {
                    if let Some(ref group_id) = update.group_id {
                        tag.group_id = Some(group_id.clone());
                    }
                    if let Some(ref color) = update.color {
                        tag.color = color.clone();
                    }
                    if let Some(is_archived) = update.is_archived {
                        tag.is_archived = is_archived;
                    }

                    tag.updated_at = chrono::Utc::now().naive_utc();
                    updated.push(tag.clone());
                }
            }
        }

        ServiceResponse::success_with_message(
            updated,
            format!("Updated {} tags", updated.len())
        )
    }

    /// 导入标签
    pub async fn import_tags(
        &self,
        tags_data: Vec<ImportTagData>,
        context: ServiceContext,
    ) -> ServiceResponse<ImportResult> {
        let mut imported = 0;
        let mut skipped = 0;
        let mut errors = Vec::new();

        for data in tags_data {
            // 检查是否已存在
            let storage = self.tags.lock().unwrap();
            if storage.iter().any(|t| t.name == data.name && t.user_id == context.user_id) {
                skipped += 1;
                continue;
            }
            drop(storage);

            let request = CreateTagRequest {
                name: data.name,
                display_name: data.display_name,
                description: data.description,
                color: data.color,
                icon: data.icon,
                group_id: data.group_id,
                parent_id: data.parent_id,
                order_index: data.order_index,
            };

            match self.create_tag(request, context.clone()).await {
                ServiceResponse { success: true, .. } => imported += 1,
                ServiceResponse { error: Some(e), .. } => {
                    errors.push(e);
                }
                _ => {}
            }
        }

        ServiceResponse::success(ImportResult {
            total: (imported + skipped) as u32,
            imported,
            skipped,
            errors,
        })
    }

    /// 导出标签
    pub async fn export_tags(
        &self,
        group_id: Option<String>,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ExportTagData>> {
        let storage = self.tags.lock().unwrap();
        
        let export_data: Vec<ExportTagData> = storage.iter()
            .filter(|t| t.user_id == context.user_id)
            .filter(|t| {
                if let Some(ref gid) = group_id {
                    t.group_id.as_ref() == Some(gid)
                } else {
                    true
                }
            })
            .map(|t| ExportTagData {
                name: t.name.clone(),
                display_name: t.display_name.clone(),
                description: t.description.clone(),
                color: t.color.clone(),
                icon: t.icon.clone(),
                group_name: None, // 可以通过group_id查找
                parent_name: None, // 可以通过parent_id查找
            })
            .collect();

        ServiceResponse::success(export_data)
    }

    // 辅助方法：验证颜色格式
    fn is_valid_color(&self, color: &str) -> bool {
        // 简单的十六进制颜色验证
        color.starts_with('#') && color.len() == 7 &&
        color[1..].chars().all(|c| c.is_ascii_hexdigit())
    }

    // 辅助方法：生成颜色
    fn generate_color(&self) -> String {
        // 预定义颜色列表
        let colors = vec![
            "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4", "#FFEAA7",
            "#DDA0DD", "#98D8C8", "#FFD700", "#FF69B4", "#87CEEB",
        ];
        
        let index = (chrono::Utc::now().timestamp() % colors.len() as i64) as usize;
        colors[index].to_string()
    }

    // 辅助方法：构建标签树
    fn build_tag_tree(&self, tags: Vec<Tag>) -> Vec<TagNode> {
        let mut nodes = Vec::new();
        let mut tag_map: HashMap<String, Vec<Tag>> = HashMap::new();

        // 按父ID分组
        for tag in tags {
            let parent_id = tag.parent_id.clone().unwrap_or_else(|| "root".to_string());
            tag_map.entry(parent_id).or_insert_with(Vec::new).push(tag);
        }

        // 递归构建树
        if let Some(root_tags) = tag_map.get("root") {
            for tag in root_tags {
                nodes.push(self.build_tag_node(tag.clone(), &tag_map));
            }
        }

        nodes
    }

    // 辅助方法：构建标签节点
    fn build_tag_node(&self, tag: Tag, tag_map: &HashMap<String, Vec<Tag>>) -> TagNode {
        let mut children = Vec::new();
        
        if let Some(child_tags) = tag_map.get(&tag.id) {
            for child in child_tags {
                children.push(self.build_tag_node(child.clone(), tag_map));
            }
        }

        TagNode {
            tag,
            children,
        }
    }

    // 辅助方法：更新标签使用统计
    fn update_tag_usage(&self, tag_id: &str, increment: bool) {
        let mut tags = self.tags.lock().unwrap();
        if let Some(tag) = tags.iter_mut().find(|t| t.id == tag_id) {
            if increment {
                tag.usage_count += 1;
            } else if tag.usage_count > 0 {
                tag.usage_count -= 1;
            }
            tag.last_used = Some(chrono::Utc::now().naive_utc());
        }

        // 更新统计缓存
        let mut stats = self.tag_statistics.lock().unwrap();
        let stat = stats.entry(tag_id.to_string()).or_insert_with(TagStatistics::default);
        if increment {
            stat.total_usage += 1;
        } else if stat.total_usage > 0 {
            stat.total_usage -= 1;
        }
    }

    // 初始化默认标签组
    fn init_default_groups(&mut self) {
        let mut groups = self.tag_groups.lock().unwrap();
        
        groups.push(TagGroup {
            id: "group_general".to_string(),
            name: "General".to_string(),
            description: Some("General purpose tags".to_string()),
            color: "#4ECDC4".to_string(),
            icon: Some("📌".to_string()),
            order_index: 0,
            is_system: true,
            tag_count: 0,
            created_at: chrono::Utc::now().naive_utc(),
            updated_at: chrono::Utc::now().naive_utc(),
            user_id: "system".to_string(),
        });

        groups.push(TagGroup {
            id: "group_priority".to_string(),
            name: "Priority".to_string(),
            description: Some("Priority and importance tags".to_string()),
            color: "#FF6B6B".to_string(),
            icon: Some("⭐".to_string()),
            order_index: 1,
            is_system: true,
            tag_count: 0,
            created_at: chrono::Utc::now().naive_utc(),
            updated_at: chrono::Utc::now().naive_utc(),
            user_id: "system".to_string(),
        });
    }
}

/// 标签
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tag {
    pub id: String,
    pub name: String,
    pub display_name: Option<String>,
    pub description: Option<String>,
    pub color: String,
    pub icon: Option<String>,
    pub group_id: Option<String>,
    pub parent_id: Option<String>,
    pub order_index: u32,
    pub is_system: bool,
    pub is_archived: bool,
    pub usage_count: u32,
    pub last_used: Option<NaiveDateTime>,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
    pub user_id: String,
    pub ledger_id: Option<String>,
}

/// 标签组
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagGroup {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub color: String,
    pub icon: Option<String>,
    pub order_index: u32,
    pub is_system: bool,
    pub tag_count: u32,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
    pub user_id: String,
}

/// 标签关联
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagAssociation {
    pub id: String,
    pub tag_id: String,
    pub entity_type: EntityType,
    pub entity_id: String,
    pub created_at: NaiveDateTime,
    pub user_id: String,
}

/// 实体类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum EntityType {
    Transaction,
    Account,
    Budget,
    Category,
    Contact,
    Document,
    Note,
}

/// 标签节点（用于树形结构）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagNode {
    pub tag: Tag,
    pub children: Vec<TagNode>,
}

/// 标签统计
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TagStatistics {
    pub tag_id: String,
    pub total_usage: u32,
    pub usage_by_type: HashMap<EntityType, u32>,
    pub last_30_days: u32,
    pub trend: f64,
    pub related_tags: Vec<String>,
}

/// 热门标签
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PopularTag {
    pub tag: Tag,
    pub usage_count: u32,
    pub trend: f64,
}

/// 已标记实体
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaggedEntity {
    pub entity_type: EntityType,
    pub entity_id: String,
    pub tagged_at: NaiveDateTime,
}

/// 合并结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MergeResult {
    pub target_tag_id: String,
    pub merged_tags: u32,
    pub associations_moved: u32,
    pub conflicts_resolved: u32,
}

/// 导入结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportResult {
    pub total: u32,
    pub imported: u32,
    pub skipped: u32,
    pub errors: Vec<String>,
}

/// 创建标签请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTagRequest {
    pub name: String,
    pub display_name: Option<String>,
    pub description: Option<String>,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub group_id: Option<String>,
    pub parent_id: Option<String>,
    pub order_index: Option<u32>,
}

/// 更新标签请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateTagRequest {
    pub name: Option<String>,
    pub display_name: Option<String>,
    pub description: Option<String>,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub group_id: Option<String>,
    pub parent_id: Option<String>,
    pub order_index: Option<u32>,
}

/// 创建标签组请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTagGroupRequest {
    pub name: String,
    pub description: Option<String>,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub order_index: Option<u32>,
}

/// 标签过滤器
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct TagFilter {
    pub group_id: Option<String>,
    pub parent_id: Option<String>,
    pub is_archived: Option<bool>,
    pub search: Option<String>,
}

/// 批量更新
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BulkTagUpdate {
    pub group_id: Option<String>,
    pub color: Option<String>,
    pub is_archived: Option<bool>,
}

/// 导入标签数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportTagData {
    pub name: String,
    pub display_name: Option<String>,
    pub description: Option<String>,
    pub color: Option<String>,
    pub icon: Option<String>,
    pub group_id: Option<String>,
    pub parent_id: Option<String>,
    pub order_index: Option<u32>,
}

/// 导出标签数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportTagData {
    pub name: String,
    pub display_name: Option<String>,
    pub description: Option<String>,
    pub color: String,
    pub icon: Option<String>,
    pub group_name: Option<String>,
    pub parent_name: Option<String>,
}

// 外部依赖
use uuid;

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_tag() {
        let service = TagService::new();
        let context = ServiceContext::new("test-user".to_string());

        let request = CreateTagRequest {
            name: "Important".to_string(),
            display_name: Some("⭐ Important".to_string()),
            description: Some("Important items".to_string()),
            color: Some("#FF6B6B".to_string()),
            icon: Some("⭐".to_string()),
            group_id: None,
            parent_id: None,
            order_index: Some(1),
        };

        let result = service.create_tag(request, context).await;
        assert!(result.success);
        assert!(result.data.is_some());
        
        let tag = result.data.unwrap();
        assert_eq!(tag.name, "Important");
        assert_eq!(tag.color, "#FF6B6B");
    }

    #[tokio::test]
    async fn test_tag_association() {
        let service = TagService::new();
        let context = ServiceContext::new("test-user".to_string());

        // Create a tag first
        let request = CreateTagRequest {
            name: "Test Tag".to_string(),
            display_name: None,
            description: None,
            color: None,
            icon: None,
            group_id: None,
            parent_id: None,
            order_index: None,
        };

        let tag = service.create_tag(request, context.clone()).await;
        let tag_id = tag.data.unwrap().id;

        // Add tag to entity
        let associations = service.add_tags_to_entity(
            EntityType::Transaction,
            "txn_123".to_string(),
            vec![tag_id.clone()],
            context.clone()
        ).await;
        
        assert!(associations.success);
        assert_eq!(associations.data.unwrap().len(), 1);

        // Get entity tags
        let entity_tags = service.get_entity_tags(
            EntityType::Transaction,
            "txn_123".to_string(),
            context
        ).await;
        
        assert!(entity_tags.success);
        assert_eq!(entity_tags.data.unwrap().len(), 1);
    }

    #[tokio::test]
    async fn test_tag_groups() {
        let service = TagService::new();
        let context = ServiceContext::new("test-user".to_string());

        let groups = service.list_tag_groups(context).await;
        assert!(groups.success);
        assert!(!groups.data.unwrap().is_empty()); // Should have default groups
    }

    #[test]
    fn test_color_validation() {
        let service = TagService::new();
        
        assert!(service.is_valid_color("#FF6B6B"));
        assert!(service.is_valid_color("#000000"));
        assert!(!service.is_valid_color("FF6B6B")); // Missing #
        assert!(!service.is_valid_color("#FF6B")); // Too short
        assert!(!service.is_valid_color("#GGGGGG")); // Invalid hex
    }

    #[test]
    fn test_entity_types() {
        assert_eq!(
            serde_json::to_string(&EntityType::Transaction).unwrap(),
            "\"Transaction\""
        );
        assert_eq!(
            serde_json::to_string(&EntityType::Account).unwrap(),
            "\"Account\""
        );
    }
}