//! Rules Engine - 自定义规则引擎
//! 
//! 基于 Maybe 的规则系统实现，提供自动交易分类、标记和处理

use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc, NaiveDate};
use rust_decimal::Decimal;
use uuid::Uuid;
use regex::Regex;
use async_trait::async_trait;

use crate::domain::{Transaction, TransactionType, Category, Account, Payee};
use crate::error::{JiveError, Result};
use crate::application::{ServiceContext, ServiceResponse};

/// 规则
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Rule {
    pub id: String,
    pub family_id: String,
    pub name: String,
    pub description: Option<String>,
    pub resource_type: ResourceType,
    pub priority: i32,  // 规则优先级，数字越小优先级越高
    pub active: bool,
    pub conditions: Vec<Condition>,
    pub actions: Vec<Action>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub last_run_at: Option<DateTime<Utc>>,
    pub run_count: u32,
    pub match_count: u32,
}

/// 资源类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ResourceType {
    Transaction,
    Account,
    Budget,
}

/// 条件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Condition {
    pub id: String,
    pub condition_type: ConditionType,
    pub operator: Operator,
    pub value: ConditionValue,
    pub is_compound: bool,
    pub sub_conditions: Vec<Condition>,
    pub compound_operator: Option<CompoundOperator>,
}

/// 条件类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ConditionType {
    // 交易条件
    Amount,
    Description,
    Category,
    Payee,
    Account,
    Date,
    TransactionType,
    Tag,
    
    // 复合条件
    Compound,
}

/// 操作符
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum Operator {
    // 数值操作符
    Equals,
    NotEquals,
    GreaterThan,
    GreaterThanOrEqual,
    LessThan,
    LessThanOrEqual,
    Between,
    
    // 字符串操作符
    Contains,
    NotContains,
    StartsWith,
    EndsWith,
    Matches,  // 正则表达式
    
    // 列表操作符
    In,
    NotIn,
    
    // 日期操作符
    Before,
    After,
    OnOrBefore,
    OnOrAfter,
    LastNDays,
    NextNDays,
    
    // 布尔操作符
    IsTrue,
    IsFalse,
    IsNull,
    IsNotNull,
}

/// 复合操作符
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CompoundOperator {
    And,
    Or,
}

/// 条件值
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ConditionValue {
    String(String),
    Number(Decimal),
    Boolean(bool),
    Date(NaiveDate),
    List(Vec<String>),
    Range(Decimal, Decimal),
    Null,
}

/// 动作
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Action {
    pub id: String,
    pub action_type: ActionType,
    pub value: ActionValue,
}

/// 动作类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ActionType {
    // 分类动作
    SetCategory,
    
    // 标签动作
    AddTag,
    RemoveTag,
    SetTags,
    
    // 商户动作
    SetPayee,
    
    // 备注动作
    SetNote,
    AppendNote,
    
    // 标记动作
    MarkAsReimbursable,
    MarkAsTransfer,
    MarkAsIgnored,
    
    // 通知动作
    SendNotification,
    SendEmail,
    
    // Webhook
    CallWebhook,
    
    // 自定义字段
    SetCustomField,
}

/// 动作值
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ActionValue {
    String(String),
    Number(Decimal),
    Boolean(bool),
    List(Vec<String>),
    Map(HashMap<String, String>),
    Null,
}

/// 规则执行结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleExecutionResult {
    pub rule_id: String,
    pub rule_name: String,
    pub matched: bool,
    pub resources_matched: usize,
    pub actions_performed: Vec<ActionResult>,
    pub execution_time_ms: u64,
    pub errors: Vec<String>,
}

/// 动作执行结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActionResult {
    pub action_type: ActionType,
    pub success: bool,
    pub affected_count: usize,
    pub error: Option<String>,
}

/// 规则日志
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleLog {
    pub id: String,
    pub rule_id: String,
    pub family_id: String,
    pub batch_id: String,
    pub resource_type: ResourceType,
    pub resource_id: String,
    pub action_type: ActionType,
    pub old_value: Option<String>,
    pub new_value: Option<String>,
    pub created_at: DateTime<Utc>,
}

/// 规则服务
pub struct RuleService {
    // 依赖注入
}

impl RuleService {
    pub fn new() -> Self {
        Self {}
    }
    
    /// 创建规则
    pub async fn create_rule(
        &self,
        context: ServiceContext,
        request: CreateRuleRequest,
    ) -> Result<ServiceResponse<Rule>> {
        // 权限检查
        if !context.has_permission_str("manage_rules") {
            return Err(JiveError::Forbidden("No permission to manage rules".into()));
        }
        
        let rule = Rule {
            id: Uuid::new_v4().to_string(),
            family_id: context.family_id.clone(),
            name: request.name,
            description: request.description,
            resource_type: request.resource_type,
            priority: request.priority.unwrap_or(100),
            active: false,  // 默认不激活
            conditions: request.conditions,
            actions: request.actions,
            created_at: Utc::now(),
            updated_at: Utc::now(),
            last_run_at: None,
            run_count: 0,
            match_count: 0,
        };
        
        // 验证规则
        self.validate_rule(&rule)?;
        
        // TODO: 保存到数据库
        
        Ok(ServiceResponse::success_with_message(
            rule,
            "Rule created successfully".to_string()
        ))
    }
    
    /// 执行规则
    pub async fn execute_rule(
        &self,
        context: ServiceContext,
        rule_id: String,
    ) -> Result<RuleExecutionResult> {
        // 获取规则
        let rule = self.get_rule(&context.family_id, &rule_id).await?;
        
        if !rule.active {
            return Err(JiveError::ValidationError("Rule is not active".into()));
        }
        
        let start_time = std::time::Instant::now();
        let batch_id = Uuid::new_v4().to_string();
        
        // 获取匹配的资源
        let resources = self.get_matching_resources(&context, &rule).await?;
        let matched_count = resources.len();
        
        let mut action_results = Vec::new();
        let mut errors = Vec::new();
        
        // 执行动作
        for action in &rule.actions {
            match self.execute_action(&context, &rule, &action, &resources, &batch_id).await {
                Ok(result) => action_results.push(result),
                Err(e) => {
                    errors.push(format!("Action {} failed: {}", action.action_type.to_string(), e));
                    action_results.push(ActionResult {
                        action_type: action.action_type.clone(),
                        success: false,
                        affected_count: 0,
                        error: Some(e.to_string()),
                    });
                }
            }
        }
        
        // 更新规则统计
        self.update_rule_stats(&rule_id, matched_count).await?;
        
        Ok(RuleExecutionResult {
            rule_id: rule.id,
            rule_name: rule.name,
            matched: matched_count > 0,
            resources_matched: matched_count,
            actions_performed: action_results,
            execution_time_ms: start_time.elapsed().as_millis() as u64,
            errors,
        })
    }
    
    /// 批量执行规则
    pub async fn execute_all_rules(
        &self,
        context: ServiceContext,
    ) -> Result<Vec<RuleExecutionResult>> {
        // 获取所有激活的规则，按优先级排序
        let rules = self.get_active_rules(&context.family_id).await?;
        
        let mut results = Vec::new();
        
        for rule in rules {
            match self.execute_rule(context.clone(), rule.id.clone()).await {
                Ok(result) => results.push(result),
                Err(e) => {
                    results.push(RuleExecutionResult {
                        rule_id: rule.id,
                        rule_name: rule.name,
                        matched: false,
                        resources_matched: 0,
                        actions_performed: vec![],
                        execution_time_ms: 0,
                        errors: vec![e.to_string()],
                    });
                }
            }
        }
        
        Ok(results)
    }
    
    /// 测试规则（预览效果但不实际执行）
    pub async fn test_rule(
        &self,
        context: ServiceContext,
        rule: &Rule,
    ) -> Result<RuleTestResult> {
        // 获取匹配的资源
        let resources = self.get_matching_resources(&context, rule).await?;
        
        // 预览每个动作的效果
        let mut previews = Vec::new();
        
        for action in &rule.actions {
            let preview = self.preview_action(&context, action, &resources).await?;
            previews.push(preview);
        }
        
        Ok(RuleTestResult {
            matched_resources: resources.len(),
            sample_resources: resources.into_iter().take(10).collect(),
            action_previews: previews,
        })
    }
    
    /// 获取匹配的资源
    async fn get_matching_resources(
        &self,
        context: &ServiceContext,
        rule: &Rule,
    ) -> Result<Vec<ResourceInfo>> {
        match rule.resource_type {
            ResourceType::Transaction => {
                self.get_matching_transactions(context, &rule.conditions).await
            }
            ResourceType::Account => {
                self.get_matching_accounts(context, &rule.conditions).await
            }
            ResourceType::Budget => {
                self.get_matching_budgets(context, &rule.conditions).await
            }
        }
    }
    
    /// 获取匹配的交易
    async fn get_matching_transactions(
        &self,
        context: &ServiceContext,
        conditions: &[Condition],
    ) -> Result<Vec<ResourceInfo>> {
        // TODO: 从数据库查询交易
        // 这里应该构建查询条件并执行
        
        let mut resources = Vec::new();
        
        // 模拟数据
        // 实际应该根据条件查询数据库
        
        Ok(resources)
    }
    
    /// 获取匹配的账户
    async fn get_matching_accounts(
        &self,
        context: &ServiceContext,
        conditions: &[Condition],
    ) -> Result<Vec<ResourceInfo>> {
        Ok(Vec::new())
    }
    
    /// 获取匹配的预算
    async fn get_matching_budgets(
        &self,
        context: &ServiceContext,
        conditions: &[Condition],
    ) -> Result<Vec<ResourceInfo>> {
        Ok(Vec::new())
    }
    
    /// 执行动作
    async fn execute_action(
        &self,
        context: &ServiceContext,
        rule: &Rule,
        action: &Action,
        resources: &[ResourceInfo],
        batch_id: &str,
    ) -> Result<ActionResult> {
        let mut affected_count = 0;
        
        for resource in resources {
            // 记录日志
            self.log_action(
                &context.family_id,
                &rule.id,
                batch_id,
                &rule.resource_type,
                &resource.id,
                &action.action_type,
                None,  // old_value
                None,  // new_value
            ).await?;
            
            // 执行具体动作
            match &action.action_type {
                ActionType::SetCategory => {
                    if let ActionValue::String(category_id) = &action.value {
                        // TODO: 更新交易分类
                        affected_count += 1;
                    }
                }
                ActionType::AddTag => {
                    if let ActionValue::String(tag) = &action.value {
                        // TODO: 添加标签
                        affected_count += 1;
                    }
                }
                ActionType::SendNotification => {
                    // TODO: 发送通知
                    affected_count += 1;
                }
                _ => {
                    // TODO: 实现其他动作类型
                }
            }
        }
        
        Ok(ActionResult {
            action_type: action.action_type.clone(),
            success: true,
            affected_count,
            error: None,
        })
    }
    
    /// 预览动作效果
    async fn preview_action(
        &self,
        context: &ServiceContext,
        action: &Action,
        resources: &[ResourceInfo],
    ) -> Result<ActionPreview> {
        Ok(ActionPreview {
            action_type: action.action_type.clone(),
            affected_resources: resources.len(),
            sample_changes: vec![],
        })
    }
    
    /// 验证规则
    fn validate_rule(&self, rule: &Rule) -> Result<()> {
        // 验证至少有一个条件
        if rule.conditions.is_empty() {
            return Err(JiveError::ValidationError("Rule must have at least one condition".into()));
        }
        
        // 验证至少有一个动作
        if rule.actions.is_empty() {
            return Err(JiveError::ValidationError("Rule must have at least one action".into()));
        }
        
        // 验证条件
        for condition in &rule.conditions {
            self.validate_condition(condition)?;
        }
        
        // 验证动作
        for action in &rule.actions {
            self.validate_action(action)?;
        }
        
        Ok(())
    }
    
    /// 验证条件
    fn validate_condition(&self, condition: &Condition) -> Result<()> {
        // 如果是复合条件，验证子条件
        if condition.is_compound {
            if condition.sub_conditions.is_empty() {
                return Err(JiveError::ValidationError("Compound condition must have sub-conditions".into()));
            }
            
            // 递归验证子条件，但不允许嵌套复合条件
            for sub in &condition.sub_conditions {
                if sub.is_compound {
                    return Err(JiveError::ValidationError("Nested compound conditions are not allowed".into()));
                }
                self.validate_condition(sub)?;
            }
        }
        
        Ok(())
    }
    
    /// 验证动作
    fn validate_action(&self, action: &Action) -> Result<()> {
        // 验证动作值与动作类型匹配
        match &action.action_type {
            ActionType::SetCategory | ActionType::SetPayee | ActionType::SetNote => {
                if !matches!(&action.value, ActionValue::String(_)) {
                    return Err(JiveError::ValidationError("Action value type mismatch".into()));
                }
            }
            ActionType::AddTag | ActionType::RemoveTag => {
                if !matches!(&action.value, ActionValue::String(_)) {
                    return Err(JiveError::ValidationError("Tag action requires string value".into()));
                }
            }
            ActionType::SetTags => {
                if !matches!(&action.value, ActionValue::List(_)) {
                    return Err(JiveError::ValidationError("SetTags action requires list value".into()));
                }
            }
            _ => {}
        }
        
        Ok(())
    }
    
    /// 获取规则
    async fn get_rule(&self, family_id: &str, rule_id: &str) -> Result<Rule> {
        // TODO: 从数据库获取规则
        Err(JiveError::NotImplemented("get_rule".into()))
    }
    
    /// 获取激活的规则
    async fn get_active_rules(&self, family_id: &str) -> Result<Vec<Rule>> {
        // TODO: 从数据库获取激活的规则，按优先级排序
        Ok(Vec::new())
    }
    
    /// 更新规则统计
    async fn update_rule_stats(&self, rule_id: &str, matched_count: usize) -> Result<()> {
        // TODO: 更新数据库中的规则统计
        Ok(())
    }
    
    /// 记录动作日志
    async fn log_action(
        &self,
        family_id: &str,
        rule_id: &str,
        batch_id: &str,
        resource_type: &ResourceType,
        resource_id: &str,
        action_type: &ActionType,
        old_value: Option<String>,
        new_value: Option<String>,
    ) -> Result<()> {
        let log = RuleLog {
            id: Uuid::new_v4().to_string(),
            rule_id: rule_id.to_string(),
            family_id: family_id.to_string(),
            batch_id: batch_id.to_string(),
            resource_type: resource_type.clone(),
            resource_id: resource_id.to_string(),
            action_type: action_type.clone(),
            old_value,
            new_value,
            created_at: Utc::now(),
        };
        
        // TODO: 保存到数据库
        
        Ok(())
    }
    
    /// 撤销规则执行
    pub async fn undo_rule_execution(
        &self,
        context: ServiceContext,
        batch_id: String,
    ) -> Result<()> {
        // 权限检查
        if !context.has_permission_str("manage_rules") {
            return Err(JiveError::Forbidden("No permission to manage rules".into()));
        }
        
        // 获取批次的所有日志
        let logs = self.get_logs_by_batch(&context.family_id, &batch_id).await?;
        
        // 按时间倒序撤销每个动作
        for log in logs.iter().rev() {
            self.undo_action(&log).await?;
        }
        
        Ok(())
    }
    
    /// 撤销单个动作
    async fn undo_action(&self, log: &RuleLog) -> Result<()> {
        // TODO: 根据日志恢复原值
        Ok(())
    }
    
    /// 获取批次日志
    async fn get_logs_by_batch(&self, family_id: &str, batch_id: &str) -> Result<Vec<RuleLog>> {
        // TODO: 从数据库获取日志
        Ok(Vec::new())
    }
}

/// 资源信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResourceInfo {
    pub id: String,
    pub resource_type: ResourceType,
    pub display_name: String,
    pub metadata: HashMap<String, String>,
}

/// 创建规则请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateRuleRequest {
    pub name: String,
    pub description: Option<String>,
    pub resource_type: ResourceType,
    pub priority: Option<i32>,
    pub conditions: Vec<Condition>,
    pub actions: Vec<Action>,
}

/// 规则测试结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleTestResult {
    pub matched_resources: usize,
    pub sample_resources: Vec<ResourceInfo>,
    pub action_previews: Vec<ActionPreview>,
}

/// 动作预览
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActionPreview {
    pub action_type: ActionType,
    pub affected_resources: usize,
    pub sample_changes: Vec<ChangePreview>,
}

/// 变更预览
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChangePreview {
    pub resource_id: String,
    pub field: String,
    pub old_value: String,
    pub new_value: String,
}

// ActionType 的 ToString 实现
impl ToString for ActionType {
    fn to_string(&self) -> String {
        match self {
            ActionType::SetCategory => "set_category",
            ActionType::AddTag => "add_tag",
            ActionType::RemoveTag => "remove_tag",
            ActionType::SetTags => "set_tags",
            ActionType::SetPayee => "set_payee",
            ActionType::SetNote => "set_note",
            ActionType::AppendNote => "append_note",
            ActionType::MarkAsReimbursable => "mark_as_reimbursable",
            ActionType::MarkAsTransfer => "mark_as_transfer",
            ActionType::MarkAsIgnored => "mark_as_ignored",
            ActionType::SendNotification => "send_notification",
            ActionType::SendEmail => "send_email",
            ActionType::CallWebhook => "call_webhook",
            ActionType::SetCustomField => "set_custom_field",
        }.to_string()
    }
}

/// 规则构建器 - 方便创建规则
pub struct RuleBuilder {
    name: String,
    description: Option<String>,
    resource_type: ResourceType,
    priority: Option<i32>,
    conditions: Vec<Condition>,
    actions: Vec<Action>,
}

impl RuleBuilder {
    pub fn new(name: impl Into<String>, resource_type: ResourceType) -> Self {
        Self {
            name: name.into(),
            description: None,
            resource_type,
            priority: None,
            conditions: Vec::new(),
            actions: Vec::new(),
        }
    }
    
    pub fn description(mut self, desc: impl Into<String>) -> Self {
        self.description = Some(desc.into());
        self
    }
    
    pub fn priority(mut self, priority: i32) -> Self {
        self.priority = Some(priority);
        self
    }
    
    pub fn when_amount_greater_than(mut self, amount: Decimal) -> Self {
        self.conditions.push(Condition {
            id: Uuid::new_v4().to_string(),
            condition_type: ConditionType::Amount,
            operator: Operator::GreaterThan,
            value: ConditionValue::Number(amount),
            is_compound: false,
            sub_conditions: Vec::new(),
            compound_operator: None,
        });
        self
    }
    
    pub fn when_description_contains(mut self, text: impl Into<String>) -> Self {
        self.conditions.push(Condition {
            id: Uuid::new_v4().to_string(),
            condition_type: ConditionType::Description,
            operator: Operator::Contains,
            value: ConditionValue::String(text.into()),
            is_compound: false,
            sub_conditions: Vec::new(),
            compound_operator: None,
        });
        self
    }
    
    pub fn when_payee_is(mut self, payee: impl Into<String>) -> Self {
        self.conditions.push(Condition {
            id: Uuid::new_v4().to_string(),
            condition_type: ConditionType::Payee,
            operator: Operator::Equals,
            value: ConditionValue::String(payee.into()),
            is_compound: false,
            sub_conditions: Vec::new(),
            compound_operator: None,
        });
        self
    }
    
    pub fn then_set_category(mut self, category_id: impl Into<String>) -> Self {
        self.actions.push(Action {
            id: Uuid::new_v4().to_string(),
            action_type: ActionType::SetCategory,
            value: ActionValue::String(category_id.into()),
        });
        self
    }
    
    pub fn then_add_tag(mut self, tag: impl Into<String>) -> Self {
        self.actions.push(Action {
            id: Uuid::new_v4().to_string(),
            action_type: ActionType::AddTag,
            value: ActionValue::String(tag.into()),
        });
        self
    }
    
    pub fn then_mark_as_reimbursable(mut self) -> Self {
        self.actions.push(Action {
            id: Uuid::new_v4().to_string(),
            action_type: ActionType::MarkAsReimbursable,
            value: ActionValue::Boolean(true),
        });
        self
    }
    
    pub fn build(self) -> CreateRuleRequest {
        CreateRuleRequest {
            name: self.name,
            description: self.description,
            resource_type: self.resource_type,
            priority: self.priority,
            conditions: self.conditions,
            actions: self.actions,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal_macros::dec;
    
    #[test]
    fn test_rule_builder() {
        let rule = RuleBuilder::new("Large Expense Alert", ResourceType::Transaction)
            .description("Alert for expenses over $1000")
            .priority(1)
            .when_amount_greater_than(dec!(1000))
            .then_add_tag("large-expense")
            .then_mark_as_reimbursable()
            .build();
        
        assert_eq!(rule.name, "Large Expense Alert");
        assert_eq!(rule.conditions.len(), 1);
        assert_eq!(rule.actions.len(), 2);
    }
    
    #[test]
    fn test_starbucks_rule() {
        let rule = RuleBuilder::new("Starbucks Coffee", ResourceType::Transaction)
            .when_description_contains("starbucks")
            .then_set_category("food_dining")
            .then_add_tag("coffee")
            .build();
        
        assert_eq!(rule.conditions.len(), 1);
        assert_eq!(rule.actions.len(), 2);
    }
}