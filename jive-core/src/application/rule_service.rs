//! RuleService - 规则引擎服务
//!
//! 处理自动化规则，包括自动分类、智能识别、条件触发等
//! 支持复杂条件组合、多种动作类型、规则优先级等功能

use chrono::{NaiveDate, NaiveDateTime};
use regex::Regex;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::{
    domain::{Category, Transaction},
    error::{JiveError, Result},
};

use super::{PaginationParams, ServiceContext, ServiceResponse};

/// 规则引擎服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct RuleService {
    // 模拟规则存储
    rules: std::sync::Arc<std::sync::Mutex<Vec<Rule>>>,
    // 执行日志
    execution_logs: std::sync::Arc<std::sync::Mutex<Vec<RuleExecutionLog>>>,
    // 规则模板
    templates: std::sync::Arc<std::sync::Mutex<Vec<RuleTemplate>>>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl RuleService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        let mut service = Self {
            rules: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
            execution_logs: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
            templates: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
        };

        // 初始化默认模板
        service.init_default_templates();
        service
    }
}

impl RuleService {
    /// 创建规则
    pub async fn create_rule(
        &self,
        request: CreateRuleRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Rule> {
        // 验证请求
        if request.name.is_empty() {
            return ServiceResponse::error(JiveError::ValidationError {
                message: "Rule name is required".to_string(),
            });
        }

        if request.conditions.is_empty() {
            return ServiceResponse::error(JiveError::ValidationError {
                message: "At least one condition is required".to_string(),
            });
        }

        if request.actions.is_empty() {
            return ServiceResponse::error(JiveError::ValidationError {
                message: "At least one action is required".to_string(),
            });
        }

        // 验证条件和动作
        for condition in &request.conditions {
            if let Err(e) = self.validate_condition(condition) {
                return ServiceResponse::error(e);
            }
        }

        for action in &request.actions {
            if let Err(e) = self.validate_action(action) {
                return ServiceResponse::error(e);
            }
        }

        // 创建规则
        let rule = Rule {
            id: format!("rule_{}", uuid::Uuid::new_v4()),
            name: request.name,
            description: request.description,
            conditions: request.conditions,
            condition_logic: request.condition_logic,
            actions: request.actions,
            priority: request.priority,
            enabled: request.enabled,
            auto_apply: request.auto_apply,
            scope: request.scope,
            tags: request.tags,
            statistics: RuleStatistics::default(),
            created_at: chrono::Utc::now().naive_utc(),
            updated_at: chrono::Utc::now().naive_utc(),
            user_id: context.user_id.clone(),
            ledger_id: context.current_ledger_id.clone(),
        };

        // 保存规则
        let mut storage = self.rules.lock().unwrap();
        storage.push(rule.clone());

        // 按优先级排序
        storage.sort_by_key(|r| std::cmp::Reverse(r.priority));

        ServiceResponse::success_with_message(rule, "Rule created successfully".to_string())
    }

    /// 更新规则
    pub async fn update_rule(
        &self,
        id: String,
        request: UpdateRuleRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Rule> {
        let mut storage = self.rules.lock().unwrap();

        if let Some(rule) = storage.iter_mut().find(|r| r.id == id) {
            // 更新字段
            if let Some(name) = request.name {
                rule.name = name;
            }
            if let Some(description) = request.description {
                rule.description = Some(description);
            }
            if let Some(conditions) = request.conditions {
                for condition in &conditions {
                    if let Err(e) = self.validate_condition(condition) {
                        return ServiceResponse::error(e);
                    }
                }
                rule.conditions = conditions;
            }
            if let Some(actions) = request.actions {
                for action in &actions {
                    if let Err(e) = self.validate_action(action) {
                        return ServiceResponse::error(e);
                    }
                }
                rule.actions = actions;
            }
            if let Some(priority) = request.priority {
                rule.priority = priority;
            }
            if let Some(enabled) = request.enabled {
                rule.enabled = enabled;
            }
            if let Some(auto_apply) = request.auto_apply {
                rule.auto_apply = auto_apply;
            }

            rule.updated_at = chrono::Utc::now().naive_utc();

            // 重新排序
            let updated_rule = rule.clone();
            storage.sort_by_key(|r| std::cmp::Reverse(r.priority));

            ServiceResponse::success(updated_rule)
        } else {
            ServiceResponse::error(JiveError::NotFound {
                message: format!("Rule {} not found", id),
            })
        }
    }

    /// 删除规则
    pub async fn delete_rule(&self, id: String, context: ServiceContext) -> ServiceResponse<bool> {
        let mut storage = self.rules.lock().unwrap();
        let original_len = storage.len();
        storage.retain(|r| r.id != id);

        if storage.len() < original_len {
            ServiceResponse::success(true)
        } else {
            ServiceResponse::error(JiveError::NotFound {
                message: format!("Rule {} not found", id),
            })
        }
    }

    /// 获取规则列表
    pub async fn list_rules(
        &self,
        filter: RuleFilter,
        pagination: PaginationParams,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Rule>> {
        let storage = self.rules.lock().unwrap();

        let mut results: Vec<_> = storage
            .iter()
            .filter(|r| {
                // 应用过滤器
                if let Some(enabled) = filter.enabled {
                    if r.enabled != enabled {
                        return false;
                    }
                }
                if let Some(ref scope) = filter.scope {
                    if &r.scope != scope {
                        return false;
                    }
                }
                if let Some(auto_apply) = filter.auto_apply {
                    if r.auto_apply != auto_apply {
                        return false;
                    }
                }
                if let Some(ref search) = filter.search {
                    if !r.name.to_lowercase().contains(&search.to_lowercase())
                        && !r
                            .description
                            .as_ref()
                            .map_or(false, |d| d.to_lowercase().contains(&search.to_lowercase()))
                    {
                        return false;
                    }
                }
                true
            })
            .cloned()
            .collect();

        // 已经按优先级排序

        // 分页
        let start = pagination.offset as usize;
        let end = (start + pagination.per_page as usize).min(results.len());
        let page_results = results[start..end].to_vec();

        ServiceResponse::success(page_results)
    }

    /// 获取规则详情
    pub async fn get_rule(&self, id: String, context: ServiceContext) -> ServiceResponse<Rule> {
        let storage = self.rules.lock().unwrap();

        if let Some(rule) = storage.iter().find(|r| r.id == id) {
            ServiceResponse::success(rule.clone())
        } else {
            ServiceResponse::error(JiveError::NotFound {
                message: format!("Rule {} not found", id),
            })
        }
    }

    /// 执行单个规则
    pub async fn execute_rule(
        &self,
        rule_id: String,
        target: RuleTarget,
        context: ServiceContext,
    ) -> ServiceResponse<RuleExecutionResult> {
        let storage = self.rules.lock().unwrap();

        if let Some(rule) = storage.iter().find(|r| r.id == rule_id) {
            if !rule.enabled {
                return ServiceResponse::error(JiveError::ValidationError {
                    message: "Rule is disabled".to_string(),
                });
            }

            // 检查条件
            let conditions_met =
                self.evaluate_conditions(&rule.conditions, &rule.condition_logic, &target);

            if !conditions_met {
                return ServiceResponse::success(RuleExecutionResult {
                    rule_id: rule.id.clone(),
                    rule_name: rule.name.clone(),
                    matched: false,
                    actions_executed: Vec::new(),
                    changes_made: HashMap::new(),
                    execution_time_ms: 0,
                });
            }

            // 执行动作
            let mut changes = HashMap::new();
            let mut actions_executed = Vec::new();

            for action in &rule.actions {
                let change = self.execute_action(action, &target);
                if let Ok(change) = change {
                    changes.insert(action.action_type.to_string(), change);
                    actions_executed.push(action.clone());
                }
            }

            // 记录执行日志
            let mut logs = self.execution_logs.lock().unwrap();
            logs.push(RuleExecutionLog {
                id: format!("log_{}", uuid::Uuid::new_v4()),
                rule_id: rule.id.clone(),
                rule_name: rule.name.clone(),
                target_type: target.get_type(),
                target_id: target.get_id(),
                matched: true,
                actions_executed: actions_executed.clone(),
                changes_made: changes.clone(),
                executed_at: chrono::Utc::now().naive_utc(),
                execution_time_ms: 5, // 模拟执行时间
            });

            // 更新统计
            drop(storage);
            self.update_rule_statistics(&rule_id, true);

            ServiceResponse::success(RuleExecutionResult {
                rule_id: rule.id.clone(),
                rule_name: rule.name.clone(),
                matched: true,
                actions_executed,
                changes_made: changes,
                execution_time_ms: 5,
            })
        } else {
            ServiceResponse::error(JiveError::NotFound {
                message: format!("Rule {} not found", rule_id),
            })
        }
    }

    /// 批量执行规则
    pub async fn execute_rules(
        &self,
        target: RuleTarget,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<RuleExecutionResult>> {
        let storage = self.rules.lock().unwrap();
        let mut results = Vec::new();

        // 按优先级执行
        for rule in storage.iter() {
            if !rule.enabled {
                continue;
            }

            // 检查作用域
            if !self.check_scope(&rule.scope, &target) {
                continue;
            }

            // 检查条件
            let conditions_met =
                self.evaluate_conditions(&rule.conditions, &rule.condition_logic, &target);

            if conditions_met {
                let mut changes = HashMap::new();
                let mut actions_executed = Vec::new();

                // 执行动作
                for action in &rule.actions {
                    let change = self.execute_action(action, &target);
                    if let Ok(change) = change {
                        changes.insert(action.action_type.to_string(), change);
                        actions_executed.push(action.clone());
                    }
                }

                results.push(RuleExecutionResult {
                    rule_id: rule.id.clone(),
                    rule_name: rule.name.clone(),
                    matched: true,
                    actions_executed,
                    changes_made: changes,
                    execution_time_ms: 2,
                });

                // 如果规则设置了停止后续规则，则退出
                if rule.stop_on_match {
                    break;
                }
            }
        }

        ServiceResponse::success_with_message(results, format!("Executed rules for target"))
    }

    /// 测试规则
    pub async fn test_rule(
        &self,
        rule_id: String,
        test_target: RuleTarget,
        context: ServiceContext,
    ) -> ServiceResponse<RuleTestResult> {
        let storage = self.rules.lock().unwrap();

        if let Some(rule) = storage.iter().find(|r| r.id == rule_id) {
            // 评估条件
            let mut condition_results = Vec::new();
            for condition in &rule.conditions {
                let matched = self.evaluate_single_condition(condition, &test_target);
                condition_results.push(ConditionTestResult {
                    condition: condition.clone(),
                    matched,
                    actual_value: self.get_field_value(&condition.field, &test_target),
                });
            }

            let overall_match =
                self.evaluate_conditions(&rule.conditions, &rule.condition_logic, &test_target);

            // 预览动作
            let mut action_previews = Vec::new();
            if overall_match {
                for action in &rule.actions {
                    action_previews.push(ActionPreview {
                        action: action.clone(),
                        expected_change: self.preview_action(action, &test_target),
                    });
                }
            }

            ServiceResponse::success(RuleTestResult {
                rule_id: rule.id.clone(),
                rule_name: rule.name.clone(),
                would_match: overall_match,
                condition_results,
                action_previews,
            })
        } else {
            ServiceResponse::error(JiveError::NotFound {
                message: format!("Rule {} not found", rule_id),
            })
        }
    }

    /// 获取规则模板
    pub async fn get_rule_templates(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<RuleTemplate>> {
        let templates = self.templates.lock().unwrap();
        ServiceResponse::success(templates.clone())
    }

    /// 从模板创建规则
    pub async fn create_rule_from_template(
        &self,
        template_id: String,
        customization: HashMap<String, String>,
        context: ServiceContext,
    ) -> ServiceResponse<Rule> {
        let templates = self.templates.lock().unwrap();

        if let Some(template) = templates.iter().find(|t| t.id == template_id) {
            // 应用自定义参数
            let mut conditions = template.conditions.clone();
            let mut actions = template.actions.clone();

            // 替换模板变量
            for (key, value) in customization {
                // 替换条件中的变量
                for condition in &mut conditions {
                    if condition.value.contains(&format!("{{{{{}}}}}", key)) {
                        condition.value =
                            condition.value.replace(&format!("{{{{{}}}}}", key), &value);
                    }
                }

                // 替换动作中的变量
                for action in &mut actions {
                    if action.parameters.contains_key(&key) {
                        action.parameters.insert(key, value);
                    }
                }
            }

            let request = CreateRuleRequest {
                name: template.name.clone(),
                description: template.description.clone(),
                conditions,
                condition_logic: template.condition_logic.clone(),
                actions,
                priority: template.default_priority,
                enabled: true,
                auto_apply: template.auto_apply,
                scope: RuleScope::All,
                tags: template.tags.clone(),
            };

            self.create_rule(request, context).await
        } else {
            ServiceResponse::error(JiveError::NotFound {
                message: format!("Template {} not found", template_id),
            })
        }
    }

    /// 获取规则执行历史
    pub async fn get_execution_history(
        &self,
        rule_id: Option<String>,
        limit: u32,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<RuleExecutionLog>> {
        let logs = self.execution_logs.lock().unwrap();

        let mut results: Vec<_> = if let Some(id) = rule_id {
            logs.iter()
                .filter(|log| log.rule_id == id)
                .take(limit as usize)
                .cloned()
                .collect()
        } else {
            logs.iter().take(limit as usize).cloned().collect()
        };

        // 按时间倒序
        results.sort_by(|a, b| b.executed_at.cmp(&a.executed_at));

        ServiceResponse::success(results)
    }

    /// 获取规则统计
    pub async fn get_rule_statistics(
        &self,
        rule_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<RuleStatistics> {
        let storage = self.rules.lock().unwrap();

        if let Some(rule) = storage.iter().find(|r| r.id == rule_id) {
            ServiceResponse::success(rule.statistics.clone())
        } else {
            ServiceResponse::error(JiveError::NotFound {
                message: format!("Rule {} not found", rule_id),
            })
        }
    }

    /// 批量启用/禁用规则
    pub async fn bulk_toggle_rules(
        &self,
        rule_ids: Vec<String>,
        enabled: bool,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Rule>> {
        let mut storage = self.rules.lock().unwrap();
        let mut updated = Vec::new();

        for rule in storage.iter_mut() {
            if rule_ids.contains(&rule.id) {
                rule.enabled = enabled;
                rule.updated_at = chrono::Utc::now().naive_utc();
                updated.push(rule.clone());
            }
        }

        ServiceResponse::success_with_message(
            updated,
            format!(
                "{} {} rules",
                if enabled { "Enabled" } else { "Disabled" },
                rule_ids.len()
            ),
        )
    }

    /// 导入规则
    pub async fn import_rules(
        &self,
        rules_data: Vec<RuleImportData>,
        context: ServiceContext,
    ) -> ServiceResponse<ImportResult> {
        let mut imported = 0;
        let mut failed = 0;
        let mut errors = Vec::new();

        for data in rules_data {
            let request = CreateRuleRequest {
                name: data.name,
                description: data.description,
                conditions: data.conditions,
                condition_logic: data.condition_logic,
                actions: data.actions,
                priority: data.priority,
                enabled: data.enabled,
                auto_apply: data.auto_apply,
                scope: data.scope,
                tags: data.tags,
            };

            match self.create_rule(request, context.clone()).await {
                ServiceResponse { success: true, .. } => imported += 1,
                ServiceResponse { error: Some(e), .. } => {
                    failed += 1;
                    errors.push(e);
                }
                _ => failed += 1,
            }
        }

        ServiceResponse::success(ImportResult {
            total: imported + failed,
            imported,
            failed,
            errors,
        })
    }

    /// 导出规则
    pub async fn export_rules(
        &self,
        rule_ids: Option<Vec<String>>,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<RuleExportData>> {
        let storage = self.rules.lock().unwrap();

        let rules: Vec<_> = if let Some(ids) = rule_ids {
            storage
                .iter()
                .filter(|r| ids.contains(&r.id))
                .cloned()
                .collect()
        } else {
            storage.clone()
        };

        let export_data: Vec<RuleExportData> = rules
            .into_iter()
            .map(|r| RuleExportData {
                name: r.name,
                description: r.description,
                conditions: r.conditions,
                condition_logic: r.condition_logic,
                actions: r.actions,
                priority: r.priority,
                enabled: r.enabled,
                auto_apply: r.auto_apply,
                scope: r.scope,
                tags: r.tags,
            })
            .collect();

        ServiceResponse::success(export_data)
    }

    /// 优化规则顺序
    pub async fn optimize_rule_order(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<OptimizationResult> {
        let mut storage = self.rules.lock().unwrap();

        // 分析规则冲突和重叠
        let mut conflicts = Vec::new();
        let mut optimizations = Vec::new();

        for i in 0..storage.len() {
            for j in i + 1..storage.len() {
                if self.rules_conflict(&storage[i], &storage[j]) {
                    conflicts.push(format!(
                        "{} conflicts with {}",
                        storage[i].name, storage[j].name
                    ));
                }
            }
        }

        // 基于执行频率优化顺序
        storage.sort_by(|a, b| {
            // 首先按优先级
            let priority_cmp = b.priority.cmp(&a.priority);
            if priority_cmp != std::cmp::Ordering::Equal {
                return priority_cmp;
            }
            // 然后按执行次数
            b.statistics
                .total_executions
                .cmp(&a.statistics.total_executions)
        });

        optimizations.push("Rules reordered by priority and execution frequency".to_string());

        ServiceResponse::success(OptimizationResult {
            rules_reordered: true,
            conflicts_found: conflicts.len(),
            conflicts,
            optimizations,
        })
    }

    // 辅助方法：验证条件
    fn validate_condition(&self, condition: &RuleCondition) -> Result<()> {
        // 验证字段
        if condition.field.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Condition field is required".to_string(),
            });
        }

        // 验证操作符
        match condition.operator {
            ConditionOperator::Regex => {
                // 验证正则表达式
                if Regex::new(&condition.value).is_err() {
                    return Err(JiveError::ValidationError {
                        message: format!("Invalid regex pattern: {}", condition.value),
                    });
                }
            }
            _ => {}
        }

        Ok(())
    }

    // 辅助方法：验证动作
    fn validate_action(&self, action: &RuleAction) -> Result<()> {
        // 验证必需参数
        match &action.action_type {
            ActionType::SetCategory => {
                if !action.parameters.contains_key("category_id") {
                    return Err(JiveError::ValidationError {
                        message: "Category ID is required for SetCategory action".to_string(),
                    });
                }
            }
            ActionType::AddTag => {
                if !action.parameters.contains_key("tag") {
                    return Err(JiveError::ValidationError {
                        message: "Tag is required for AddTag action".to_string(),
                    });
                }
            }
            _ => {}
        }

        Ok(())
    }

    // 辅助方法：评估条件
    fn evaluate_conditions(
        &self,
        conditions: &[RuleCondition],
        logic: &ConditionLogic,
        target: &RuleTarget,
    ) -> bool {
        match logic {
            ConditionLogic::All => conditions
                .iter()
                .all(|c| self.evaluate_single_condition(c, target)),
            ConditionLogic::Any => conditions
                .iter()
                .any(|c| self.evaluate_single_condition(c, target)),
            ConditionLogic::Custom(expr) => {
                // 简单的自定义逻辑评估（实际实现需要表达式解析器）
                conditions
                    .iter()
                    .all(|c| self.evaluate_single_condition(c, target))
            }
        }
    }

    // 辅助方法：评估单个条件
    fn evaluate_single_condition(&self, condition: &RuleCondition, target: &RuleTarget) -> bool {
        let field_value = self.get_field_value(&condition.field, target);

        match &condition.operator {
            ConditionOperator::Equals => field_value == condition.value,
            ConditionOperator::NotEquals => field_value != condition.value,
            ConditionOperator::Contains => field_value.contains(&condition.value),
            ConditionOperator::StartsWith => field_value.starts_with(&condition.value),
            ConditionOperator::EndsWith => field_value.ends_with(&condition.value),
            ConditionOperator::GreaterThan => {
                if let (Ok(field), Ok(cond)) =
                    (field_value.parse::<f64>(), condition.value.parse::<f64>())
                {
                    field > cond
                } else {
                    false
                }
            }
            ConditionOperator::LessThan => {
                if let (Ok(field), Ok(cond)) =
                    (field_value.parse::<f64>(), condition.value.parse::<f64>())
                {
                    field < cond
                } else {
                    false
                }
            }
            ConditionOperator::Regex => {
                if let Ok(re) = Regex::new(&condition.value) {
                    re.is_match(&field_value)
                } else {
                    false
                }
            }
            ConditionOperator::In => {
                let values: Vec<&str> = condition.value.split(',').collect();
                values.contains(&field_value.as_str())
            }
            ConditionOperator::NotIn => {
                let values: Vec<&str> = condition.value.split(',').collect();
                !values.contains(&field_value.as_str())
            }
        }
    }

    // 辅助方法：获取字段值
    fn get_field_value(&self, field: &str, target: &RuleTarget) -> String {
        match target {
            RuleTarget::Transaction(t) => match field {
                "amount" => t.amount.to_string(),
                "description" => t.description.clone(),
                "merchant" => t.merchant.clone().unwrap_or_default(),
                "category" => t.category_id.clone().unwrap_or_default(),
                _ => String::new(),
            },
            RuleTarget::Account(a) => match field {
                "name" => a.name.clone(),
                "balance" => a.balance.to_string(),
                "type" => a.account_type.clone(),
                _ => String::new(),
            },
            _ => String::new(),
        }
    }

    // 辅助方法：执行动作
    fn execute_action(&self, action: &RuleAction, target: &RuleTarget) -> Result<String> {
        match &action.action_type {
            ActionType::SetCategory => {
                let category_id =
                    action
                        .parameters
                        .get("category_id")
                        .ok_or(JiveError::ValidationError {
                            message: "Category ID not found".to_string(),
                        })?;
                Ok(format!("Set category to {}", category_id))
            }
            ActionType::AddTag => {
                let tag = action
                    .parameters
                    .get("tag")
                    .ok_or(JiveError::ValidationError {
                        message: "Tag not found".to_string(),
                    })?;
                Ok(format!("Added tag: {}", tag))
            }
            ActionType::SetField => {
                let field = action
                    .parameters
                    .get("field")
                    .ok_or(JiveError::ValidationError {
                        message: "Field not specified".to_string(),
                    })?;
                let value = action
                    .parameters
                    .get("value")
                    .ok_or(JiveError::ValidationError {
                        message: "Value not specified".to_string(),
                    })?;
                Ok(format!("Set {} to {}", field, value))
            }
            ActionType::SendNotification => Ok("Notification sent".to_string()),
            ActionType::CreateTask => Ok("Task created".to_string()),
            ActionType::RunScript => Ok("Script executed".to_string()),
        }
    }

    // 辅助方法：预览动作
    fn preview_action(&self, action: &RuleAction, target: &RuleTarget) -> String {
        match &action.action_type {
            ActionType::SetCategory => {
                format!(
                    "Would set category to: {}",
                    action
                        .parameters
                        .get("category_id")
                        .unwrap_or(&"unknown".to_string())
                )
            }
            ActionType::AddTag => {
                format!(
                    "Would add tag: {}",
                    action
                        .parameters
                        .get("tag")
                        .unwrap_or(&"unknown".to_string())
                )
            }
            _ => "Action would be executed".to_string(),
        }
    }

    // 辅助方法：检查作用域
    fn check_scope(&self, scope: &RuleScope, target: &RuleTarget) -> bool {
        match scope {
            RuleScope::All => true,
            RuleScope::Transactions => matches!(target, RuleTarget::Transaction(_)),
            RuleScope::Accounts => matches!(target, RuleTarget::Account(_)),
            RuleScope::Custom(_) => true, // 简化处理
        }
    }

    // 辅助方法：检查规则冲突
    fn rules_conflict(&self, rule1: &Rule, rule2: &Rule) -> bool {
        // 简化的冲突检测
        if rule1.scope != rule2.scope {
            return false;
        }

        // 检查条件重叠
        for c1 in &rule1.conditions {
            for c2 in &rule2.conditions {
                if c1.field == c2.field && c1.operator == c2.operator {
                    return true;
                }
            }
        }

        false
    }

    // 辅助方法：更新规则统计
    fn update_rule_statistics(&self, rule_id: &str, matched: bool) {
        let mut storage = self.rules.lock().unwrap();
        if let Some(rule) = storage.iter_mut().find(|r| r.id == rule_id) {
            rule.statistics.total_executions += 1;
            if matched {
                rule.statistics.total_matches += 1;
            }
            rule.statistics.last_execution = Some(chrono::Utc::now().naive_utc());
        }
    }

    // 初始化默认模板
    fn init_default_templates(&mut self) {
        let mut templates = self.templates.lock().unwrap();

        // 自动分类模板
        templates.push(RuleTemplate {
            id: "auto_categorize_groceries".to_string(),
            name: "Auto-categorize Groceries".to_string(),
            description: Some("Automatically categorize grocery transactions".to_string()),
            conditions: vec![RuleCondition {
                field: "merchant".to_string(),
                operator: ConditionOperator::In,
                value: "Walmart,Target,Kroger,Safeway".to_string(),
            }],
            condition_logic: ConditionLogic::Any,
            actions: vec![RuleAction {
                action_type: ActionType::SetCategory,
                parameters: {
                    let mut params = HashMap::new();
                    params.insert("category_id".to_string(), "groceries".to_string());
                    params
                },
            }],
            default_priority: 100,
            auto_apply: true,
            tags: vec!["categorization".to_string()],
        });

        // 大额交易提醒模板
        templates.push(RuleTemplate {
            id: "large_transaction_alert".to_string(),
            name: "Large Transaction Alert".to_string(),
            description: Some("Alert for transactions over threshold".to_string()),
            conditions: vec![RuleCondition {
                field: "amount".to_string(),
                operator: ConditionOperator::GreaterThan,
                value: "{{threshold}}".to_string(), // 模板变量
            }],
            condition_logic: ConditionLogic::All,
            actions: vec![RuleAction {
                action_type: ActionType::SendNotification,
                parameters: HashMap::new(),
            }],
            default_priority: 200,
            auto_apply: true,
            tags: vec!["alert".to_string()],
        });
    }
}

/// 规则
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Rule {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub conditions: Vec<RuleCondition>,
    pub condition_logic: ConditionLogic,
    pub actions: Vec<RuleAction>,
    pub priority: u32,
    pub enabled: bool,
    pub auto_apply: bool,
    pub scope: RuleScope,
    pub tags: Vec<String>,
    pub statistics: RuleStatistics,
    pub stop_on_match: bool,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
    pub user_id: String,
    pub ledger_id: Option<String>,
}

/// 规则条件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleCondition {
    pub field: String,
    pub operator: ConditionOperator,
    pub value: String,
}

/// 条件操作符
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ConditionOperator {
    Equals,
    NotEquals,
    Contains,
    StartsWith,
    EndsWith,
    GreaterThan,
    LessThan,
    Regex,
    In,
    NotIn,
}

/// 条件逻辑
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ConditionLogic {
    All,            // AND
    Any,            // OR
    Custom(String), // 自定义表达式
}

/// 规则动作
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleAction {
    pub action_type: ActionType,
    pub parameters: HashMap<String, String>,
}

/// 动作类型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ActionType {
    SetCategory,
    AddTag,
    SetField,
    SendNotification,
    CreateTask,
    RunScript,
}

impl ActionType {
    fn to_string(&self) -> String {
        match self {
            ActionType::SetCategory => "SetCategory".to_string(),
            ActionType::AddTag => "AddTag".to_string(),
            ActionType::SetField => "SetField".to_string(),
            ActionType::SendNotification => "SendNotification".to_string(),
            ActionType::CreateTask => "CreateTask".to_string(),
            ActionType::RunScript => "RunScript".to_string(),
        }
    }
}

/// 规则作用域
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum RuleScope {
    All,
    Transactions,
    Accounts,
    Custom(String),
}

/// 规则目标
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RuleTarget {
    Transaction(TransactionTarget),
    Account(AccountTarget),
    Category(CategoryTarget),
}

impl RuleTarget {
    fn get_type(&self) -> String {
        match self {
            RuleTarget::Transaction(_) => "Transaction".to_string(),
            RuleTarget::Account(_) => "Account".to_string(),
            RuleTarget::Category(_) => "Category".to_string(),
        }
    }

    fn get_id(&self) -> String {
        match self {
            RuleTarget::Transaction(t) => t.id.clone(),
            RuleTarget::Account(a) => a.id.clone(),
            RuleTarget::Category(c) => c.id.clone(),
        }
    }
}

/// 交易目标
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionTarget {
    pub id: String,
    pub amount: Decimal,
    pub description: String,
    pub merchant: Option<String>,
    pub category_id: Option<String>,
    pub date: NaiveDate,
}

/// 账户目标
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountTarget {
    pub id: String,
    pub name: String,
    pub balance: Decimal,
    pub account_type: String,
}

/// 分类目标
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryTarget {
    pub id: String,
    pub name: String,
}

/// 规则执行结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleExecutionResult {
    pub rule_id: String,
    pub rule_name: String,
    pub matched: bool,
    pub actions_executed: Vec<RuleAction>,
    pub changes_made: HashMap<String, String>,
    pub execution_time_ms: u32,
}

/// 规则执行日志
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleExecutionLog {
    pub id: String,
    pub rule_id: String,
    pub rule_name: String,
    pub target_type: String,
    pub target_id: String,
    pub matched: bool,
    pub actions_executed: Vec<RuleAction>,
    pub changes_made: HashMap<String, String>,
    pub executed_at: NaiveDateTime,
    pub execution_time_ms: u32,
}

/// 规则统计
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct RuleStatistics {
    pub total_executions: u32,
    pub total_matches: u32,
    pub average_execution_time_ms: f64,
    pub last_execution: Option<NaiveDateTime>,
}

/// 规则模板
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleTemplate {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub conditions: Vec<RuleCondition>,
    pub condition_logic: ConditionLogic,
    pub actions: Vec<RuleAction>,
    pub default_priority: u32,
    pub auto_apply: bool,
    pub tags: Vec<String>,
}

/// 规则测试结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleTestResult {
    pub rule_id: String,
    pub rule_name: String,
    pub would_match: bool,
    pub condition_results: Vec<ConditionTestResult>,
    pub action_previews: Vec<ActionPreview>,
}

/// 条件测试结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConditionTestResult {
    pub condition: RuleCondition,
    pub matched: bool,
    pub actual_value: String,
}

/// 动作预览
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActionPreview {
    pub action: RuleAction,
    pub expected_change: String,
}

/// 优化结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptimizationResult {
    pub rules_reordered: bool,
    pub conflicts_found: usize,
    pub conflicts: Vec<String>,
    pub optimizations: Vec<String>,
}

/// 导入结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportResult {
    pub total: u32,
    pub imported: u32,
    pub failed: u32,
    pub errors: Vec<String>,
}

/// 创建规则请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateRuleRequest {
    pub name: String,
    pub description: Option<String>,
    pub conditions: Vec<RuleCondition>,
    pub condition_logic: ConditionLogic,
    pub actions: Vec<RuleAction>,
    pub priority: u32,
    pub enabled: bool,
    pub auto_apply: bool,
    pub scope: RuleScope,
    pub tags: Vec<String>,
}

/// 更新规则请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateRuleRequest {
    pub name: Option<String>,
    pub description: Option<String>,
    pub conditions: Option<Vec<RuleCondition>>,
    pub actions: Option<Vec<RuleAction>>,
    pub priority: Option<u32>,
    pub enabled: Option<bool>,
    pub auto_apply: Option<bool>,
}

/// 规则过滤器
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct RuleFilter {
    pub enabled: Option<bool>,
    pub scope: Option<RuleScope>,
    pub auto_apply: Option<bool>,
    pub search: Option<String>,
}

/// 规则导入数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleImportData {
    pub name: String,
    pub description: Option<String>,
    pub conditions: Vec<RuleCondition>,
    pub condition_logic: ConditionLogic,
    pub actions: Vec<RuleAction>,
    pub priority: u32,
    pub enabled: bool,
    pub auto_apply: bool,
    pub scope: RuleScope,
    pub tags: Vec<String>,
}

/// 规则导出数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleExportData {
    pub name: String,
    pub description: Option<String>,
    pub conditions: Vec<RuleCondition>,
    pub condition_logic: ConditionLogic,
    pub actions: Vec<RuleAction>,
    pub priority: u32,
    pub enabled: bool,
    pub auto_apply: bool,
    pub scope: RuleScope,
    pub tags: Vec<String>,
}

// 外部依赖
use uuid;

impl Default for Rule {
    fn default() -> Self {
        Self {
            id: format!("rule_{}", uuid::Uuid::new_v4()),
            name: String::new(),
            description: None,
            conditions: Vec::new(),
            condition_logic: ConditionLogic::All,
            actions: Vec::new(),
            priority: 100,
            enabled: true,
            auto_apply: false,
            scope: RuleScope::All,
            tags: Vec::new(),
            statistics: RuleStatistics::default(),
            stop_on_match: false,
            created_at: chrono::Utc::now().naive_utc(),
            updated_at: chrono::Utc::now().naive_utc(),
            user_id: String::new(),
            ledger_id: None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_rule() {
        let service = RuleService::new();
        let context = ServiceContext::new("test-user".to_string());

        let request = CreateRuleRequest {
            name: "Auto-categorize groceries".to_string(),
            description: Some("Categorize grocery store transactions".to_string()),
            conditions: vec![RuleCondition {
                field: "merchant".to_string(),
                operator: ConditionOperator::Contains,
                value: "Walmart".to_string(),
            }],
            condition_logic: ConditionLogic::Any,
            actions: vec![RuleAction {
                action_type: ActionType::SetCategory,
                parameters: {
                    let mut params = HashMap::new();
                    params.insert("category_id".to_string(), "groceries".to_string());
                    params
                },
            }],
            priority: 100,
            enabled: true,
            auto_apply: true,
            scope: RuleScope::Transactions,
            tags: vec!["auto".to_string()],
        };

        let result = service.create_rule(request, context).await;
        assert!(result.success);
        assert!(result.data.is_some());

        let rule = result.data.unwrap();
        assert_eq!(rule.name, "Auto-categorize groceries");
        assert_eq!(rule.priority, 100);
    }

    #[tokio::test]
    async fn test_execute_rule() {
        let service = RuleService::new();
        let context = ServiceContext::new("test-user".to_string());

        // Create a rule first
        let request = CreateRuleRequest {
            name: "Test Rule".to_string(),
            description: None,
            conditions: vec![RuleCondition {
                field: "amount".to_string(),
                operator: ConditionOperator::GreaterThan,
                value: "100".to_string(),
            }],
            condition_logic: ConditionLogic::All,
            actions: vec![RuleAction {
                action_type: ActionType::AddTag,
                parameters: {
                    let mut params = HashMap::new();
                    params.insert("tag".to_string(), "large".to_string());
                    params
                },
            }],
            priority: 100,
            enabled: true,
            auto_apply: false,
            scope: RuleScope::Transactions,
            tags: vec![],
        };

        let created = service.create_rule(request, context.clone()).await;
        let rule_id = created.data.unwrap().id;

        // Test with matching target
        let target = RuleTarget::Transaction(TransactionTarget {
            id: "txn_123".to_string(),
            amount: Decimal::from(150),
            description: "Test transaction".to_string(),
            merchant: Some("Test Store".to_string()),
            category_id: None,
            date: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
        });

        let execution = service.execute_rule(rule_id, target, context).await;
        assert!(execution.success);
        assert!(execution.data.unwrap().matched);
    }

    #[tokio::test]
    async fn test_rule_templates() {
        let service = RuleService::new();
        let context = ServiceContext::new("test-user".to_string());

        let templates = service.get_rule_templates(context).await;
        assert!(templates.success);
        assert!(!templates.data.unwrap().is_empty());
    }

    #[test]
    fn test_condition_operators() {
        let service = RuleService::new();

        // Test Equals
        let condition = RuleCondition {
            field: "amount".to_string(),
            operator: ConditionOperator::Equals,
            value: "100".to_string(),
        };

        let target = RuleTarget::Transaction(TransactionTarget {
            id: "test".to_string(),
            amount: Decimal::from(100),
            description: String::new(),
            merchant: None,
            category_id: None,
            date: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
        });

        assert!(service.evaluate_single_condition(&condition, &target));
    }

    #[test]
    fn test_rule_scope() {
        let service = RuleService::new();

        let transaction_target = RuleTarget::Transaction(TransactionTarget {
            id: "test".to_string(),
            amount: Decimal::from(100),
            description: String::new(),
            merchant: None,
            category_id: None,
            date: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
        });

        assert!(service.check_scope(&RuleScope::All, &transaction_target));
        assert!(service.check_scope(&RuleScope::Transactions, &transaction_target));
        assert!(!service.check_scope(&RuleScope::Accounts, &transaction_target));
    }
}
