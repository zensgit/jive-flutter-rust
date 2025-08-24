use super::*;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// Rule entity - based on Maybe's rule.rb
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Rule {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: Option<String>,
    pub resource_type: String, // 'transaction', 'account', etc.
    pub is_active: bool,
    pub priority: i32, // Rules are applied in priority order
    pub stop_processing: bool, // Stop processing other rules if this matches
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Entity for Rule {
    type Id = Uuid;
    
    fn id(&self) -> Self::Id {
        self.id
    }
    
    fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }
    
    fn updated_at(&self) -> DateTime<Utc> {
        self.updated_at
    }
}

impl Rule {
    pub fn new(family_id: Uuid, resource_type: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            family_id,
            name: None,
            resource_type,
            is_active: true,
            priority: 0,
            stop_processing: false,
            created_at: now,
            updated_at: now,
        }
    }
}

// RuleCondition - conditions that must be met for rule to apply
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct RuleCondition {
    pub id: Uuid,
    pub rule_id: Uuid,
    pub parent_id: Option<Uuid>, // For nested conditions
    pub field: String, // Field to check (e.g., 'name', 'amount', 'date')
    pub operator: ConditionOperator,
    pub value: Option<String>, // Stored as string, parsed based on field type
    pub value_type: ValueType,
    pub logic_operator: LogicOperator, // AND/OR with other conditions
    pub position: i32, // Order of evaluation
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "condition_operator", rename_all = "snake_case")]
pub enum ConditionOperator {
    Equals,
    NotEquals,
    Contains,
    NotContains,
    StartsWith,
    EndsWith,
    GreaterThan,
    LessThan,
    GreaterThanOrEqual,
    LessThanOrEqual,
    Between,
    In,
    NotIn,
    IsNull,
    IsNotNull,
    Matches, // Regex match
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "value_type", rename_all = "snake_case")]
pub enum ValueType {
    String,
    Number,
    Date,
    Boolean,
    Array,
    Regex,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "logic_operator", rename_all = "snake_case")]
pub enum LogicOperator {
    And,
    Or,
}

impl RuleCondition {
    pub fn new(rule_id: Uuid, field: String, operator: ConditionOperator) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            rule_id,
            parent_id: None,
            field,
            operator,
            value: None,
            value_type: ValueType::String,
            logic_operator: LogicOperator::And,
            position: 0,
            created_at: now,
            updated_at: now,
        }
    }
    
    // Check if condition matches a value
    pub fn matches(&self, field_value: &str) -> bool {
        let condition_value = self.value.as_deref().unwrap_or("");
        
        match self.operator {
            ConditionOperator::Equals => field_value == condition_value,
            ConditionOperator::NotEquals => field_value != condition_value,
            ConditionOperator::Contains => field_value.contains(condition_value),
            ConditionOperator::NotContains => !field_value.contains(condition_value),
            ConditionOperator::StartsWith => field_value.starts_with(condition_value),
            ConditionOperator::EndsWith => field_value.ends_with(condition_value),
            ConditionOperator::IsNull => field_value.is_empty(),
            ConditionOperator::IsNotNull => !field_value.is_empty(),
            _ => false, // Other operators need type-specific handling
        }
    }
}

// RuleAction - actions to take when rule conditions are met
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct RuleAction {
    pub id: Uuid,
    pub rule_id: Uuid,
    pub action_type: ActionType,
    pub field: Option<String>, // Field to modify
    pub value: Option<String>, // Value to set
    pub position: i32, // Order of execution
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "action_type", rename_all = "snake_case")]
pub enum ActionType {
    SetCategory,
    SetPayee,
    AddTag,
    RemoveTag,
    SetName,
    SetNotes,
    MarkReimbursable,
    ExcludeFromBudget,
    ExcludeFromReports,
    AutoCategorize,
    AutoDetectMerchant,
    SetTransferAccount,
}

impl RuleAction {
    pub fn new(rule_id: Uuid, action_type: ActionType) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            rule_id,
            action_type,
            field: None,
            value: None,
            position: 0,
            created_at: now,
            updated_at: now,
        }
    }
}

// RuleLog - track rule applications
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct RuleLog {
    pub id: Uuid,
    pub rule_id: Uuid,
    pub resource_type: String,
    pub resource_id: Uuid,
    pub action_type: String,
    pub field_changed: Option<String>,
    pub old_value: Option<String>,
    pub new_value: Option<String>,
    pub applied_at: DateTime<Utc>,
    pub success: bool,
    pub error_message: Option<String>,
    pub created_at: DateTime<Utc>,
}

impl RuleLog {
    pub fn new(rule_id: Uuid, resource_type: String, resource_id: Uuid) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            rule_id,
            resource_type,
            resource_id,
            action_type: String::new(),
            field_changed: None,
            old_value: None,
            new_value: None,
            applied_at: now,
            success: true,
            error_message: None,
            created_at: now,
        }
    }
    
    pub fn with_change(mut self, field: String, old: Option<String>, new: Option<String>) -> Self {
        self.field_changed = Some(field);
        self.old_value = old;
        self.new_value = new;
        self
    }
    
    pub fn with_error(mut self, error: String) -> Self {
        self.success = false;
        self.error_message = Some(error);
        self
    }
}

// Rule templates for common scenarios
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleTemplate {
    pub name: String,
    pub description: String,
    pub resource_type: String,
    pub conditions: Vec<RuleConditionTemplate>,
    pub actions: Vec<RuleActionTemplate>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleConditionTemplate {
    pub field: String,
    pub operator: String,
    pub value: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleActionTemplate {
    pub action_type: String,
    pub value: Option<String>,
}

impl RuleTemplate {
    pub fn auto_categorize_groceries() -> Self {
        Self {
            name: "Auto-categorize Groceries".to_string(),
            description: "Automatically categorize transactions from grocery stores".to_string(),
            resource_type: "transaction".to_string(),
            conditions: vec![
                RuleConditionTemplate {
                    field: "name".to_string(),
                    operator: "contains".to_string(),
                    value: Some("grocery".to_string()),
                },
            ],
            actions: vec![
                RuleActionTemplate {
                    action_type: "set_category".to_string(),
                    value: Some("Groceries".to_string()),
                },
            ],
        }
    }
    
    pub fn mark_business_expenses() -> Self {
        Self {
            name: "Mark Business Expenses".to_string(),
            description: "Mark transactions as reimbursable business expenses".to_string(),
            resource_type: "transaction".to_string(),
            conditions: vec![
                RuleConditionTemplate {
                    field: "category".to_string(),
                    operator: "equals".to_string(),
                    value: Some("Business".to_string()),
                },
            ],
            actions: vec![
                RuleActionTemplate {
                    action_type: "mark_reimbursable".to_string(),
                    value: None,
                },
                RuleActionTemplate {
                    action_type: "add_tag".to_string(),
                    value: Some("business-expense".to_string()),
                },
            ],
        }
    }
    
    pub fn exclude_transfers() -> Self {
        Self {
            name: "Exclude Transfers from Budget".to_string(),
            description: "Exclude internal transfers from budget calculations".to_string(),
            resource_type: "transaction".to_string(),
            conditions: vec![
                RuleConditionTemplate {
                    field: "kind".to_string(),
                    operator: "in".to_string(),
                    value: Some("funds_movement,cc_payment".to_string()),
                },
            ],
            actions: vec![
                RuleActionTemplate {
                    action_type: "exclude_from_budget".to_string(),
                    value: None,
                },
            ],
        }
    }
}