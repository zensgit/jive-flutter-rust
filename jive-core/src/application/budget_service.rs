//! Budget service - 预算管理服务
//!
//! 基于 Maybe 的预算功能转换而来，提供预算设置、跟踪、提醒等功能

use chrono::{DateTime, Datelike, Month, NaiveDate, Utc};
use rust_decimal::prelude::FromStr;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use super::{PaginationParams, ServiceContext, ServiceResponse};
use crate::domain::{Category, Transaction};
use crate::error::{JiveError, Result};

/// 预算类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum BudgetType {
    Monthly,   // 月度预算
    Quarterly, // 季度预算
    Yearly,    // 年度预算
    Weekly,    // 周预算
    Custom,    // 自定义周期
    OneTime,   // 一次性预算
    Project,   // 项目预算
}

/// 预算状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum BudgetStatus {
    Active,    // 活跃
    Paused,    // 暂停
    Completed, // 完成
    Cancelled, // 取消
    Draft,     // 草稿
}

/// 预算
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Budget {
    pub id: String,
    pub user_id: String,
    pub ledger_id: String,
    pub name: String,
    pub description: Option<String>,
    pub budget_type: BudgetType,
    pub status: BudgetStatus,
    pub amount: Decimal,
    pub spent: Decimal,
    pub remaining: Decimal,
    pub period_start: NaiveDate,
    pub period_end: NaiveDate,
    pub categories: Vec<String>,
    pub tags: Vec<String>,
    pub rollover: bool,
    pub alert_enabled: bool,
    pub alert_threshold: Decimal,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 预算分类
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BudgetCategory {
    id: String,
    budget_id: String,
    category_id: String,
    category_name: String,
    allocated_amount: Decimal,
    spent_amount: Decimal,
    remaining_amount: Decimal,
    percentage_used: Decimal,
    transaction_count: u32,
}

/// 预算期间
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetPeriod {
    pub id: String,
    pub budget_id: String,
    pub period_start: NaiveDate,
    pub period_end: NaiveDate,
    pub allocated_amount: Decimal,
    pub spent_amount: Decimal,
    pub rollover_amount: Decimal,
    pub is_current: bool,
}

/// 预算进度
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BudgetProgress {
    budget_id: String,
    budget_name: String,
    total_budget: Decimal,
    total_spent: Decimal,
    total_remaining: Decimal,
    percentage_used: Decimal,
    days_elapsed: u32,
    days_remaining: u32,
    projected_spending: Decimal,
    on_track: bool,
    categories: Vec<CategoryProgress>,
}

/// 分类进度
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryProgress {
    pub category_id: String,
    pub category_name: String,
    pub budget: Decimal,
    pub spent: Decimal,
    pub remaining: Decimal,
    pub percentage: Decimal,
    pub status: ProgressStatus,
}

/// 进度状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ProgressStatus {
    UnderBudget, // 预算内
    OnTrack,     // 正常
    NearLimit,   // 接近限额
    OverBudget,  // 超支
}

/// 预算提醒
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BudgetAlert {
    id: String,
    budget_id: String,
    alert_type: AlertType,
    threshold: Decimal,
    message: String,
    triggered_at: DateTime<Utc>,
    acknowledged: bool,
}

/// 提醒类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum AlertType {
    ThresholdReached, // 达到阈值
    BudgetExceeded,   // 超出预算
    PeriodEnding,     // 周期即将结束
    UnusualSpending,  // 异常支出
}

/// 创建预算请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateBudgetRequest {
    pub name: String,
    pub budget_type: BudgetType,
    pub amount: Decimal,
    pub period_start: NaiveDate,
    pub period_end: NaiveDate,
    pub categories: Vec<String>,
    pub tags: Vec<String>,
    pub rollover: bool,
    pub alert_enabled: bool,
    pub alert_threshold: Decimal,
}

/// 更新预算请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UpdateBudgetRequest {
    name: Option<String>,
    amount: Option<Decimal>,
    categories: Option<Vec<String>>,
    tags: Option<Vec<String>>,
    rollover: Option<bool>,
    alert_enabled: Option<bool>,
    alert_threshold: Option<Decimal>,
}

/// 预算历史
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetHistory {
    pub budget_id: String,
    pub periods: Vec<BudgetPeriod>,
    pub total_allocated: Decimal,
    pub total_spent: Decimal,
    pub average_spending: Decimal,
    pub best_period: Option<BudgetPeriod>,
    pub worst_period: Option<BudgetPeriod>,
}

/// 预算建议
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BudgetSuggestion {
    category_id: String,
    category_name: String,
    suggested_amount: Decimal,
    current_average: Decimal,
    historical_average: Decimal,
    confidence: Decimal,
    reason: String,
}

/// 预算模板
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BudgetTemplate {
    id: String,
    name: String,
    description: String,
    budget_type: BudgetType,
    categories: Vec<BudgetTemplateCategory>,
    is_public: bool,
    created_by: String,
    created_at: DateTime<Utc>,
}

/// 模板分类
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetTemplateCategory {
    pub category_name: String,
    pub percentage: Decimal,
    pub fixed_amount: Option<Decimal>,
}

/// 预算对比
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetComparison {
    pub current_period: BudgetPeriod,
    pub previous_period: Option<BudgetPeriod>,
    pub change_amount: Decimal,
    pub change_percentage: Decimal,
    pub categories_comparison: Vec<CategoryComparison>,
}

/// 分类对比
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryComparison {
    pub category_id: String,
    pub category_name: String,
    pub current_spent: Decimal,
    pub previous_spent: Decimal,
    pub change: Decimal,
    pub change_percentage: Decimal,
}

/// 预算服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BudgetService {}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl BudgetService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {}
    }

    /// 创建预算
    #[wasm_bindgen]
    pub async fn create_budget(
        &self,
        request: CreateBudgetRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Budget> {
        let result = self._create_budget(request, context).await;
        result.into()
    }

    /// 更新预算
    #[wasm_bindgen]
    pub async fn update_budget(
        &self,
        budget_id: String,
        request: UpdateBudgetRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Budget> {
        let result = self._update_budget(budget_id, request, context).await;
        result.into()
    }

    /// 删除预算
    #[wasm_bindgen]
    pub async fn delete_budget(
        &self,
        budget_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._delete_budget(budget_id, context).await;
        result.into()
    }

    /// 获取预算
    #[wasm_bindgen]
    pub async fn get_budget(
        &self,
        budget_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Budget> {
        let result = self._get_budget(budget_id, context).await;
        result.into()
    }

    /// 获取预算列表
    #[wasm_bindgen]
    pub async fn list_budgets(
        &self,
        pagination: PaginationParams,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Budget>> {
        let result = self._list_budgets(pagination, context).await;
        result.into()
    }

    /// 获取预算进度
    #[wasm_bindgen]
    pub async fn get_budget_progress(
        &self,
        budget_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<BudgetProgress> {
        let result = self._get_budget_progress(budget_id, context).await;
        result.into()
    }

    /// 获取预算历史
    #[wasm_bindgen]
    pub async fn get_budget_history(
        &self,
        budget_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<BudgetHistory> {
        let result = self._get_budget_history(budget_id, context).await;
        result.into()
    }

    /// 获取预算建议
    #[wasm_bindgen]
    pub async fn get_budget_suggestions(
        &self,
        period: BudgetType,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<BudgetSuggestion>> {
        let result = self._get_budget_suggestions(period, context).await;
        result.into()
    }

    /// 复制预算
    #[wasm_bindgen]
    pub async fn copy_budget(
        &self,
        budget_id: String,
        new_period_start: NaiveDate,
        context: ServiceContext,
    ) -> ServiceResponse<Budget> {
        let result = self
            ._copy_budget(budget_id, new_period_start, context)
            .await;
        result.into()
    }

    /// 从模板创建预算
    #[wasm_bindgen]
    pub async fn create_from_template(
        &self,
        template_id: String,
        amount: Decimal,
        period_start: NaiveDate,
        context: ServiceContext,
    ) -> ServiceResponse<Budget> {
        let result = self
            ._create_from_template(template_id, amount, period_start, context)
            .await;
        result.into()
    }

    /// 获取预算模板
    #[wasm_bindgen]
    pub async fn get_budget_templates(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<BudgetTemplate>> {
        let result = self._get_budget_templates(context).await;
        result.into()
    }

    /// 保存为模板
    #[wasm_bindgen]
    pub async fn save_as_template(
        &self,
        budget_id: String,
        template_name: String,
        context: ServiceContext,
    ) -> ServiceResponse<BudgetTemplate> {
        let result = self
            ._save_as_template(budget_id, template_name, context)
            .await;
        result.into()
    }

    /// 获取预算提醒
    #[wasm_bindgen]
    pub async fn get_budget_alerts(
        &self,
        budget_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<BudgetAlert>> {
        let result = self._get_budget_alerts(budget_id, context).await;
        result.into()
    }

    /// 确认提醒
    #[wasm_bindgen]
    pub async fn acknowledge_alert(
        &self,
        alert_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._acknowledge_alert(alert_id, context).await;
        result.into()
    }

    /// 对比预算期间
    #[wasm_bindgen]
    pub async fn compare_periods(
        &self,
        budget_id: String,
        period1: NaiveDate,
        period2: NaiveDate,
        context: ServiceContext,
    ) -> ServiceResponse<BudgetComparison> {
        let result = self
            ._compare_periods(budget_id, period1, period2, context)
            .await;
        result.into()
    }

    /// 调整预算金额
    #[wasm_bindgen]
    pub async fn adjust_budget_amount(
        &self,
        budget_id: String,
        new_amount: Decimal,
        context: ServiceContext,
    ) -> ServiceResponse<Budget> {
        let result = self
            ._adjust_budget_amount(budget_id, new_amount, context)
            .await;
        result.into()
    }

    /// 自动分配预算
    #[wasm_bindgen]
    pub async fn auto_allocate_budget(
        &self,
        total_amount: Decimal,
        period: BudgetType,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<BudgetCategory>> {
        let result = self
            ._auto_allocate_budget(total_amount, period, context)
            .await;
        result.into()
    }
}

impl BudgetService {
    /// 创建预算的内部实现
    async fn _create_budget(
        &self,
        request: CreateBudgetRequest,
        context: ServiceContext,
    ) -> Result<Budget> {
        // 验证请求
        if request.amount <= Decimal::ZERO {
            return Err(JiveError::ValidationError {
                message: "Budget amount must be positive".to_string(),
            });
        }

        if request.period_start >= request.period_end {
            return Err(JiveError::ValidationError {
                message: "Invalid budget period".to_string(),
            });
        }

        let budget = Budget {
            id: Uuid::new_v4().to_string(),
            user_id: context.user_id.clone(),
            ledger_id: context.current_ledger_id.unwrap_or_default(),
            name: request.name,
            description: None,
            budget_type: request.budget_type,
            status: BudgetStatus::Active,
            amount: request.amount,
            spent: Decimal::ZERO,
            remaining: request.amount,
            period_start: request.period_start,
            period_end: request.period_end,
            categories: request.categories,
            tags: request.tags,
            rollover: request.rollover,
            alert_enabled: request.alert_enabled,
            alert_threshold: request.alert_threshold,
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };

        // 在实际实现中，保存到数据库
        Ok(budget)
    }

    /// 更新预算的内部实现
    async fn _update_budget(
        &self,
        budget_id: String,
        request: UpdateBudgetRequest,
        context: ServiceContext,
    ) -> Result<Budget> {
        let mut budget = self._get_budget(budget_id, context.clone()).await?;

        if let Some(name) = request.name {
            budget.name = name;
        }
        if let Some(amount) = request.amount {
            if amount <= Decimal::ZERO {
                return Err(JiveError::ValidationError {
                    message: "Budget amount must be positive".to_string(),
                });
            }
            budget.amount = amount;
            budget.remaining = amount - budget.spent;
        }
        if let Some(categories) = request.categories {
            budget.categories = categories;
        }
        if let Some(tags) = request.tags {
            budget.tags = tags;
        }
        if let Some(rollover) = request.rollover {
            budget.rollover = rollover;
        }
        if let Some(alert_enabled) = request.alert_enabled {
            budget.alert_enabled = alert_enabled;
        }
        if let Some(alert_threshold) = request.alert_threshold {
            budget.alert_threshold = alert_threshold;
        }

        budget.updated_at = Utc::now();

        // 在实际实现中，更新数据库
        Ok(budget)
    }

    /// 删除预算的内部实现
    async fn _delete_budget(&self, _budget_id: String, _context: ServiceContext) -> Result<bool> {
        // 在实际实现中，从数据库删除
        Ok(true)
    }

    /// 获取预算的内部实现
    async fn _get_budget(&self, budget_id: String, context: ServiceContext) -> Result<Budget> {
        // 在实际实现中，从数据库获取
        Ok(Budget {
            id: budget_id,
            user_id: context.user_id,
            ledger_id: context.current_ledger_id.unwrap_or_default(),
            name: "Monthly Budget".to_string(),
            description: Some("Monthly household budget".to_string()),
            budget_type: BudgetType::Monthly,
            status: BudgetStatus::Active,
            amount: Decimal::from(5000),
            spent: Decimal::from(2500),
            remaining: Decimal::from(2500),
            period_start: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
            period_end: NaiveDate::from_ymd_opt(2024, 1, 31).unwrap(),
            categories: vec!["cat-1".to_string(), "cat-2".to_string()],
            tags: Vec::new(),
            rollover: false,
            alert_enabled: true,
            alert_threshold: Decimal::from(80),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        })
    }

    /// 获取预算列表的内部实现
    async fn _list_budgets(
        &self,
        _pagination: PaginationParams,
        context: ServiceContext,
    ) -> Result<Vec<Budget>> {
        // 在实际实现中，从数据库获取列表
        let budget = self._get_budget("budget-1".to_string(), context).await?;
        Ok(vec![budget])
    }

    /// 获取预算进度的内部实现
    async fn _get_budget_progress(
        &self,
        budget_id: String,
        context: ServiceContext,
    ) -> Result<BudgetProgress> {
        let budget = self._get_budget(budget_id.clone(), context).await?;

        let percentage_used = if budget.amount > Decimal::ZERO {
            (budget.spent / budget.amount) * Decimal::from(100)
        } else {
            Decimal::ZERO
        };

        let today = Utc::now().naive_utc().date();
        let days_elapsed = (today - budget.period_start).num_days() as u32;
        let days_total = (budget.period_end - budget.period_start).num_days() as u32;
        let days_remaining = days_total.saturating_sub(days_elapsed);

        // 计算预计支出
        let daily_rate = if days_elapsed > 0 {
            budget.spent / Decimal::from(days_elapsed)
        } else {
            Decimal::ZERO
        };
        let projected_spending = daily_rate * Decimal::from(days_total);

        let on_track = projected_spending <= budget.amount;

        let categories = vec![CategoryProgress {
            category_id: "cat-1".to_string(),
            category_name: "Food".to_string(),
            budget: Decimal::from(1000),
            spent: Decimal::from(800),
            remaining: Decimal::from(200),
            percentage: Decimal::from(80),
            status: ProgressStatus::NearLimit,
        }];

        Ok(BudgetProgress {
            budget_id,
            budget_name: budget.name,
            total_budget: budget.amount,
            total_spent: budget.spent,
            total_remaining: budget.remaining,
            percentage_used,
            days_elapsed,
            days_remaining,
            projected_spending,
            on_track,
            categories,
        })
    }

    /// 获取预算历史的内部实现
    async fn _get_budget_history(
        &self,
        budget_id: String,
        _context: ServiceContext,
    ) -> Result<BudgetHistory> {
        let periods = vec![BudgetPeriod {
            id: Uuid::new_v4().to_string(),
            budget_id: budget_id.clone(),
            period_start: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
            period_end: NaiveDate::from_ymd_opt(2024, 1, 31).unwrap(),
            allocated_amount: Decimal::from(5000),
            spent_amount: Decimal::from(4800),
            rollover_amount: Decimal::ZERO,
            is_current: false,
        }];

        Ok(BudgetHistory {
            budget_id,
            periods: periods.clone(),
            total_allocated: Decimal::from(5000),
            total_spent: Decimal::from(4800),
            average_spending: Decimal::from(4800),
            best_period: periods.first().cloned(),
            worst_period: periods.first().cloned(),
        })
    }

    /// 获取预算建议的内部实现
    async fn _get_budget_suggestions(
        &self,
        _period: BudgetType,
        _context: ServiceContext,
    ) -> Result<Vec<BudgetSuggestion>> {
        let suggestions = vec![
            BudgetSuggestion {
                category_id: "cat-1".to_string(),
                category_name: "Food".to_string(),
                suggested_amount: Decimal::from(1200),
                current_average: Decimal::from(1100),
                historical_average: Decimal::from(1050),
                confidence: Decimal::from(85),
                reason: "Based on 3-month average with 10% buffer".to_string(),
            },
            BudgetSuggestion {
                category_id: "cat-2".to_string(),
                category_name: "Transport".to_string(),
                suggested_amount: Decimal::from(500),
                current_average: Decimal::from(450),
                historical_average: Decimal::from(480),
                confidence: Decimal::from(90),
                reason: "Stable spending pattern detected".to_string(),
            },
        ];

        Ok(suggestions)
    }

    /// 复制预算的内部实现
    async fn _copy_budget(
        &self,
        budget_id: String,
        new_period_start: NaiveDate,
        context: ServiceContext,
    ) -> Result<Budget> {
        let mut original = self._get_budget(budget_id, context.clone()).await?;

        // 计算新的结束日期
        let period_length = (original.period_end - original.period_start).num_days();
        let new_period_end = new_period_start + chrono::Duration::days(period_length);

        original.id = Uuid::new_v4().to_string();
        original.period_start = new_period_start;
        original.period_end = new_period_end;
        original.spent = Decimal::ZERO;
        original.remaining = original.amount;
        original.created_at = Utc::now();
        original.updated_at = Utc::now();

        // 在实际实现中，保存到数据库
        Ok(original)
    }

    /// 从模板创建预算的内部实现
    async fn _create_from_template(
        &self,
        template_id: String,
        amount: Decimal,
        period_start: NaiveDate,
        context: ServiceContext,
    ) -> Result<Budget> {
        // 获取模板
        let template = self.get_template(template_id)?;

        // 计算结束日期
        let period_end = match template.budget_type {
            BudgetType::Monthly => {
                let next_month = if period_start.month() == 12 {
                    NaiveDate::from_ymd_opt(period_start.year() + 1, 1, period_start.day())
                } else {
                    NaiveDate::from_ymd_opt(
                        period_start.year(),
                        period_start.month() + 1,
                        period_start.day(),
                    )
                };
                next_month.unwrap() - chrono::Duration::days(1)
            }
            _ => period_start + chrono::Duration::days(30),
        };

        let budget = Budget {
            id: Uuid::new_v4().to_string(),
            user_id: context.user_id,
            ledger_id: context.current_ledger_id.unwrap_or_default(),
            name: template.name,
            description: Some(template.description),
            budget_type: template.budget_type,
            status: BudgetStatus::Active,
            amount,
            spent: Decimal::ZERO,
            remaining: amount,
            period_start,
            period_end,
            categories: template
                .categories
                .iter()
                .map(|c| c.category_name.clone())
                .collect(),
            tags: Vec::new(),
            rollover: false,
            alert_enabled: true,
            alert_threshold: Decimal::from(80),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };

        Ok(budget)
    }

    /// 获取预算模板的内部实现
    async fn _get_budget_templates(&self, _context: ServiceContext) -> Result<Vec<BudgetTemplate>> {
        let templates = vec![BudgetTemplate {
            id: "tpl-1".to_string(),
            name: "50/30/20 Rule".to_string(),
            description: "50% needs, 30% wants, 20% savings".to_string(),
            budget_type: BudgetType::Monthly,
            categories: vec![
                BudgetTemplateCategory {
                    category_name: "Needs".to_string(),
                    percentage: Decimal::from(50),
                    fixed_amount: None,
                },
                BudgetTemplateCategory {
                    category_name: "Wants".to_string(),
                    percentage: Decimal::from(30),
                    fixed_amount: None,
                },
                BudgetTemplateCategory {
                    category_name: "Savings".to_string(),
                    percentage: Decimal::from(20),
                    fixed_amount: None,
                },
            ],
            is_public: true,
            created_by: "system".to_string(),
            created_at: Utc::now(),
        }];

        Ok(templates)
    }

    /// 保存为模板的内部实现
    async fn _save_as_template(
        &self,
        budget_id: String,
        template_name: String,
        context: ServiceContext,
    ) -> Result<BudgetTemplate> {
        let budget = self._get_budget(budget_id, context.clone()).await?;

        let template = BudgetTemplate {
            id: Uuid::new_v4().to_string(),
            name: template_name,
            description: budget.description.unwrap_or_default(),
            budget_type: budget.budget_type,
            categories: budget
                .categories
                .iter()
                .map(|c| BudgetTemplateCategory {
                    category_name: c.clone(),
                    percentage: Decimal::from(0),
                    fixed_amount: None,
                })
                .collect(),
            is_public: false,
            created_by: context.user_id,
            created_at: Utc::now(),
        };

        // 在实际实现中，保存到数据库
        Ok(template)
    }

    /// 获取预算提醒的内部实现
    async fn _get_budget_alerts(
        &self,
        budget_id: String,
        _context: ServiceContext,
    ) -> Result<Vec<BudgetAlert>> {
        let alerts = vec![BudgetAlert {
            id: Uuid::new_v4().to_string(),
            budget_id,
            alert_type: AlertType::ThresholdReached,
            threshold: Decimal::from(80),
            message: "You have used 80% of your budget".to_string(),
            triggered_at: Utc::now(),
            acknowledged: false,
        }];

        Ok(alerts)
    }

    /// 确认提醒的内部实现
    async fn _acknowledge_alert(
        &self,
        _alert_id: String,
        _context: ServiceContext,
    ) -> Result<bool> {
        // 在实际实现中，更新数据库
        Ok(true)
    }

    /// 对比预算期间的内部实现
    async fn _compare_periods(
        &self,
        budget_id: String,
        _period1: NaiveDate,
        _period2: NaiveDate,
        _context: ServiceContext,
    ) -> Result<BudgetComparison> {
        let current = BudgetPeriod {
            id: Uuid::new_v4().to_string(),
            budget_id: budget_id.clone(),
            period_start: NaiveDate::from_ymd_opt(2024, 2, 1).unwrap(),
            period_end: NaiveDate::from_ymd_opt(2024, 2, 29).unwrap(),
            allocated_amount: Decimal::from(5000),
            spent_amount: Decimal::from(4500),
            rollover_amount: Decimal::ZERO,
            is_current: true,
        };

        let previous = BudgetPeriod {
            id: Uuid::new_v4().to_string(),
            budget_id,
            period_start: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
            period_end: NaiveDate::from_ymd_opt(2024, 1, 31).unwrap(),
            allocated_amount: Decimal::from(5000),
            spent_amount: Decimal::from(4800),
            rollover_amount: Decimal::ZERO,
            is_current: false,
        };

        let change_amount = current.spent_amount - previous.spent_amount;
        let change_percentage = if previous.spent_amount > Decimal::ZERO {
            (change_amount / previous.spent_amount) * Decimal::from(100)
        } else {
            Decimal::ZERO
        };

        Ok(BudgetComparison {
            current_period: current,
            previous_period: Some(previous),
            change_amount,
            change_percentage,
            categories_comparison: Vec::new(),
        })
    }

    /// 调整预算金额的内部实现
    async fn _adjust_budget_amount(
        &self,
        budget_id: String,
        new_amount: Decimal,
        context: ServiceContext,
    ) -> Result<Budget> {
        let mut budget = self._get_budget(budget_id, context).await?;

        if new_amount <= Decimal::ZERO {
            return Err(JiveError::ValidationError {
                message: "Budget amount must be positive".to_string(),
            });
        }

        budget.amount = new_amount;
        budget.remaining = new_amount - budget.spent;
        budget.updated_at = Utc::now();

        // 在实际实现中，更新数据库
        Ok(budget)
    }

    /// 自动分配预算的内部实现
    async fn _auto_allocate_budget(
        &self,
        total_amount: Decimal,
        _period: BudgetType,
        _context: ServiceContext,
    ) -> Result<Vec<BudgetCategory>> {
        // 基于历史数据自动分配
        let categories = vec![
            BudgetCategory {
                id: Uuid::new_v4().to_string(),
                budget_id: "auto".to_string(),
                category_id: "cat-1".to_string(),
                category_name: "Food".to_string(),
                allocated_amount: total_amount * Decimal::from_str_exact("0.25").unwrap(),
                spent_amount: Decimal::ZERO,
                remaining_amount: total_amount * Decimal::from_str_exact("0.25").unwrap(),
                percentage_used: Decimal::ZERO,
                transaction_count: 0,
            },
            BudgetCategory {
                id: Uuid::new_v4().to_string(),
                budget_id: "auto".to_string(),
                category_id: "cat-2".to_string(),
                category_name: "Transport".to_string(),
                allocated_amount: total_amount * Decimal::from_str_exact("0.15").unwrap(),
                spent_amount: Decimal::ZERO,
                remaining_amount: total_amount * Decimal::from_str_exact("0.15").unwrap(),
                percentage_used: Decimal::ZERO,
                transaction_count: 0,
            },
        ];

        Ok(categories)
    }

    // 辅助方法
    fn get_template(&self, template_id: String) -> Result<BudgetTemplate> {
        Ok(BudgetTemplate {
            id: template_id,
            name: "Standard Budget".to_string(),
            description: "Standard monthly budget template".to_string(),
            budget_type: BudgetType::Monthly,
            categories: Vec::new(),
            is_public: true,
            created_by: "system".to_string(),
            created_at: Utc::now(),
        })
    }
}

impl Default for BudgetService {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_budget() {
        let service = BudgetService::new();
        let context = ServiceContext::new("user-123".to_string());

        let request = CreateBudgetRequest {
            name: "Test Budget".to_string(),
            budget_type: BudgetType::Monthly,
            amount: Decimal::from(5000),
            period_start: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
            period_end: NaiveDate::from_ymd_opt(2024, 1, 31).unwrap(),
            categories: vec!["cat-1".to_string()],
            tags: Vec::new(),
            rollover: false,
            alert_enabled: true,
            alert_threshold: Decimal::from(80),
        };

        let result = service._create_budget(request, context).await;
        assert!(result.is_ok());

        let budget = result.unwrap();
        assert_eq!(budget.name, "Test Budget");
        assert_eq!(budget.amount, Decimal::from(5000));
        assert_eq!(budget.status, BudgetStatus::Active);
    }

    #[tokio::test]
    async fn test_budget_progress() {
        let service = BudgetService::new();
        let context = ServiceContext::new("user-123".to_string());

        let result = service
            ._get_budget_progress("budget-1".to_string(), context)
            .await;
        assert!(result.is_ok());

        let progress = result.unwrap();
        assert_eq!(progress.total_budget, Decimal::from(5000));
        assert_eq!(progress.total_spent, Decimal::from(2500));
        assert_eq!(progress.percentage_used, Decimal::from(50));
    }

    #[tokio::test]
    async fn test_budget_suggestions() {
        let service = BudgetService::new();
        let context = ServiceContext::new("user-123".to_string());

        let result = service
            ._get_budget_suggestions(BudgetType::Monthly, context)
            .await;
        assert!(result.is_ok());

        let suggestions = result.unwrap();
        assert!(!suggestions.is_empty());
        assert!(suggestions[0].confidence > Decimal::ZERO);
    }

    #[test]
    fn test_budget_types() {
        assert_eq!(BudgetType::Monthly as i32, 0);
        assert_eq!(BudgetType::Yearly as i32, 2);
        assert_eq!(BudgetType::Weekly as i32, 3);
    }

    #[test]
    fn test_budget_status() {
        assert_eq!(BudgetStatus::Active as i32, 0);
        assert_eq!(BudgetStatus::Paused as i32, 1);
        assert_eq!(BudgetStatus::Completed as i32, 2);
    }
}
