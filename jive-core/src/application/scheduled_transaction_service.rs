//! ScheduledTransactionService - 定期交易服务
//! 
//! 处理定期/周期性交易，如月度账单、订阅费用、工资收入等
//! 支持多种周期模式、自动创建交易、提醒通知等功能

use serde::{Serialize, Deserialize};
use chrono::{NaiveDate, NaiveDateTime, Datelike, Duration, Weekday};
use rust_decimal::Decimal;
use std::collections::HashMap;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::{
    error::{JiveError, Result},
    domain::{Transaction, TransactionType},
};

use super::{ServiceContext, ServiceResponse, PaginationParams};

/// 定期交易服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ScheduledTransactionService {
    // 模拟定期交易存储
    scheduled_transactions: std::sync::Arc<std::sync::Mutex<Vec<ScheduledTransaction>>>,
    // 执行历史记录
    execution_history: std::sync::Arc<std::sync::Mutex<Vec<ExecutionRecord>>>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl ScheduledTransactionService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            scheduled_transactions: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
            execution_history: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
        }
    }
}

impl ScheduledTransactionService {
    /// 创建定期交易
    pub async fn create_scheduled_transaction(
        &self,
        request: CreateScheduledTransactionRequest,
        context: ServiceContext,
    ) -> ServiceResponse<ScheduledTransaction> {
        // 验证请求
        if request.name.is_empty() {
            return ServiceResponse::error(
                JiveError::ValidationError { message: "Transaction name is required".to_string() }
            );
        }

        if request.amount <= Decimal::ZERO {
            return ServiceResponse::error(
                JiveError::ValidationError { message: "Amount must be positive".to_string() }
            );
        }

        // 验证周期设置
        if let Err(e) = Self::validate_recurrence(&request.recurrence_type, &request.recurrence_config) {
            return ServiceResponse::error(e);
        }

        // 计算下次执行时间
        let next_run = Self::calculate_next_run(
            &request.start_date,
            &request.recurrence_type,
            &request.recurrence_config,
        );

        // 创建定期交易
        let scheduled = ScheduledTransaction {
            id: format!("sched_{}", uuid::Uuid::new_v4()),
            name: request.name,
            description: request.description,
            amount: request.amount,
            from_account_id: request.from_account_id,
            to_account_id: request.to_account_id,
            category_id: request.category_id,
            tags: request.tags,
            recurrence_type: request.recurrence_type,
            recurrence_config: request.recurrence_config,
            start_date: request.start_date,
            end_date: request.end_date,
            next_run: next_run.unwrap_or(request.start_date),
            last_run: None,
            status: ScheduledTransactionStatus::Active,
            auto_confirm: request.auto_confirm,
            reminder_enabled: request.reminder_enabled,
            reminder_days_before: request.reminder_days_before,
            created_at: chrono::Utc::now().naive_utc(),
            updated_at: chrono::Utc::now().naive_utc(),
            user_id: context.user_id.clone(),
            ledger_id: context.current_ledger_id.clone(),
        };

        // 保存
        let mut storage = self.scheduled_transactions.lock().unwrap();
        storage.push(scheduled.clone());

        ServiceResponse::success_with_message(
            scheduled,
            format!("Scheduled transaction created successfully")
        )
    }

    /// 更新定期交易
    pub async fn update_scheduled_transaction(
        &self,
        id: String,
        request: UpdateScheduledTransactionRequest,
        context: ServiceContext,
    ) -> ServiceResponse<ScheduledTransaction> {
        let mut storage = self.scheduled_transactions.lock().unwrap();
        
        if let Some(scheduled) = storage.iter_mut().find(|s| s.id == id) {
            // 更新字段
            if let Some(name) = request.name {
                scheduled.name = name;
            }
            if let Some(description) = request.description {
                scheduled.description = Some(description);
            }
            if let Some(amount) = request.amount {
                scheduled.amount = amount;
            }
            if let Some(category_id) = request.category_id {
                scheduled.category_id = Some(category_id);
            }
            if let Some(tags) = request.tags {
                scheduled.tags = tags;
            }
            if let Some(auto_confirm) = request.auto_confirm {
                scheduled.auto_confirm = auto_confirm;
            }
            if let Some(reminder_enabled) = request.reminder_enabled {
                scheduled.reminder_enabled = reminder_enabled;
            }
            if let Some(status) = request.status {
                scheduled.status = status;
            }

            scheduled.updated_at = chrono::Utc::now().naive_utc();

            ServiceResponse::success(scheduled.clone())
        } else {
            ServiceResponse::error(
                JiveError::NotFound { message: format!("Scheduled transaction {} not found", id) }
            )
        }
    }

    /// 删除定期交易
    pub async fn delete_scheduled_transaction(
        &self,
        id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let mut storage = self.scheduled_transactions.lock().unwrap();
        let original_len = storage.len();
        storage.retain(|s| s.id != id);

        if storage.len() < original_len {
            ServiceResponse::success(true)
        } else {
            ServiceResponse::error(
                JiveError::NotFound { message: format!("Scheduled transaction {} not found", id) }
            )
        }
    }

    /// 获取定期交易列表
    pub async fn list_scheduled_transactions(
        &self,
        filter: ScheduledTransactionFilter,
        pagination: PaginationParams,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ScheduledTransaction>> {
        let storage = self.scheduled_transactions.lock().unwrap();
        
        let mut results: Vec<_> = storage.iter()
            .filter(|s| {
                // 应用过滤器
                if let Some(ref status) = filter.status {
                    if &s.status != status {
                        return false;
                    }
                }
                if let Some(ref recurrence) = filter.recurrence_type {
                    if &s.recurrence_type != recurrence {
                        return false;
                    }
                }
                if let Some(ref category) = filter.category_id {
                    if s.category_id.as_ref() != Some(category) {
                        return false;
                    }
                }
                true
            })
            .cloned()
            .collect();

        // 排序
        results.sort_by(|a, b| b.next_run.cmp(&a.next_run));

        // 分页
        let start = pagination.offset as usize;
        let end = (start + pagination.per_page as usize).min(results.len());
        let page_results = results[start..end].to_vec();

        ServiceResponse::success(page_results)
    }

    /// 获取定期交易详情
    pub async fn get_scheduled_transaction(
        &self,
        id: String,
        context: ServiceContext,
    ) -> ServiceResponse<ScheduledTransaction> {
        let storage = self.scheduled_transactions.lock().unwrap();
        
        if let Some(scheduled) = storage.iter().find(|s| s.id == id) {
            ServiceResponse::success(scheduled.clone())
        } else {
            ServiceResponse::error(
                JiveError::NotFound { message: format!("Scheduled transaction {} not found", id) }
            )
        }
    }

    /// 执行定期交易（创建实际交易）
    pub async fn execute_scheduled_transaction(
        &self,
        id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Transaction> {
        let mut storage = self.scheduled_transactions.lock().unwrap();
        
        if let Some(scheduled) = storage.iter_mut().find(|s| s.id == id) {
            // 检查状态
            if scheduled.status != ScheduledTransactionStatus::Active {
                return ServiceResponse::error(
                    JiveError::ValidationError { 
                        message: "Scheduled transaction is not active".to_string() 
                    }
                );
            }

            // 创建交易
            let transaction = Transaction::builder()
                .description(scheduled.name.clone())
                .amount(scheduled.amount)
                .transaction_type(TransactionType::Transfer)
                .date(chrono::Utc::now().naive_utc().date())
                .build()
                .map_err(|e| JiveError::ValidationError { message: e })?;

            // 更新定期交易状态
            scheduled.last_run = Some(chrono::Utc::now().naive_utc());
            scheduled.next_run = Self::calculate_next_run(
                &scheduled.next_run,
                &scheduled.recurrence_type,
                &scheduled.recurrence_config,
            ).unwrap_or(scheduled.next_run);

            // 记录执行历史
            let mut history = self.execution_history.lock().unwrap();
            history.push(ExecutionRecord {
                id: format!("exec_{}", uuid::Uuid::new_v4()),
                scheduled_transaction_id: scheduled.id.clone(),
                transaction_id: transaction.id().to_string(),
                executed_at: chrono::Utc::now().naive_utc(),
                amount: scheduled.amount,
                status: ExecutionStatus::Success,
                error_message: None,
            });

            ServiceResponse::success_with_message(
                transaction,
                "Transaction created from schedule".to_string()
            )
        } else {
            ServiceResponse::error(
                JiveError::NotFound { message: format!("Scheduled transaction {} not found", id) }
            )
        }
    }

    /// 批量执行到期的定期交易
    pub async fn execute_due_transactions(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<ExecutionSummary> {
        let mut storage = self.scheduled_transactions.lock().unwrap();
        let now = chrono::Utc::now().naive_utc().date();
        let mut summary = ExecutionSummary::default();

        for scheduled in storage.iter_mut() {
            // 检查是否到期
            if scheduled.status == ScheduledTransactionStatus::Active && 
               scheduled.next_run <= now {
                
                // 检查是否超过结束日期
                if let Some(end_date) = scheduled.end_date {
                    if now > end_date {
                        scheduled.status = ScheduledTransactionStatus::Completed;
                        continue;
                    }
                }

                // 创建交易（模拟）
                summary.total += 1;
                
                if scheduled.auto_confirm {
                    // 自动确认执行
                    scheduled.last_run = Some(chrono::Utc::now().naive_utc());
                    scheduled.next_run = Self::calculate_next_run(
                        &scheduled.next_run,
                        &scheduled.recurrence_type,
                        &scheduled.recurrence_config,
                    ).unwrap_or(scheduled.next_run);
                    
                    summary.executed += 1;
                } else {
                    // 需要手动确认
                    summary.pending += 1;
                }
            }
        }

        ServiceResponse::success(summary)
    }

    /// 获取即将到期的定期交易
    pub async fn get_upcoming_transactions(
        &self,
        days: u32,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ScheduledTransaction>> {
        let storage = self.scheduled_transactions.lock().unwrap();
        let now = chrono::Utc::now().naive_utc().date();
        let cutoff = now + Duration::days(days as i64);

        let upcoming: Vec<_> = storage.iter()
            .filter(|s| {
                s.status == ScheduledTransactionStatus::Active &&
                s.next_run >= now &&
                s.next_run <= cutoff
            })
            .cloned()
            .collect();

        ServiceResponse::success(upcoming)
    }

    /// 暂停定期交易
    pub async fn pause_scheduled_transaction(
        &self,
        id: String,
        context: ServiceContext,
    ) -> ServiceResponse<ScheduledTransaction> {
        let mut storage = self.scheduled_transactions.lock().unwrap();
        
        if let Some(scheduled) = storage.iter_mut().find(|s| s.id == id) {
            if scheduled.status != ScheduledTransactionStatus::Active {
                return ServiceResponse::error(
                    JiveError::ValidationError { 
                        message: "Can only pause active transactions".to_string() 
                    }
                );
            }

            scheduled.status = ScheduledTransactionStatus::Paused;
            scheduled.updated_at = chrono::Utc::now().naive_utc();

            ServiceResponse::success(scheduled.clone())
        } else {
            ServiceResponse::error(
                JiveError::NotFound { message: format!("Scheduled transaction {} not found", id) }
            )
        }
    }

    /// 恢复定期交易
    pub async fn resume_scheduled_transaction(
        &self,
        id: String,
        context: ServiceContext,
    ) -> ServiceResponse<ScheduledTransaction> {
        let mut storage = self.scheduled_transactions.lock().unwrap();
        
        if let Some(scheduled) = storage.iter_mut().find(|s| s.id == id) {
            if scheduled.status != ScheduledTransactionStatus::Paused {
                return ServiceResponse::error(
                    JiveError::ValidationError { 
                        message: "Can only resume paused transactions".to_string() 
                    }
                );
            }

            scheduled.status = ScheduledTransactionStatus::Active;
            scheduled.updated_at = chrono::Utc::now().naive_utc();

            // 重新计算下次执行时间
            let now = chrono::Utc::now().naive_utc().date();
            if scheduled.next_run < now {
                scheduled.next_run = Self::calculate_next_run(
                    &now,
                    &scheduled.recurrence_type,
                    &scheduled.recurrence_config,
                ).unwrap_or(now);
            }

            ServiceResponse::success(scheduled.clone())
        } else {
            ServiceResponse::error(
                JiveError::NotFound { message: format!("Scheduled transaction {} not found", id) }
            )
        }
    }

    /// 跳过下一次执行
    pub async fn skip_next_execution(
        &self,
        id: String,
        context: ServiceContext,
    ) -> ServiceResponse<ScheduledTransaction> {
        let mut storage = self.scheduled_transactions.lock().unwrap();
        
        if let Some(scheduled) = storage.iter_mut().find(|s| s.id == id) {
            // 计算跳过后的下次执行时间
            scheduled.next_run = Self::calculate_next_run(
                &scheduled.next_run,
                &scheduled.recurrence_type,
                &scheduled.recurrence_config,
            ).unwrap_or(scheduled.next_run);
            
            scheduled.updated_at = chrono::Utc::now().naive_utc();

            ServiceResponse::success_with_message(
                scheduled.clone(),
                "Next execution skipped".to_string()
            )
        } else {
            ServiceResponse::error(
                JiveError::NotFound { message: format!("Scheduled transaction {} not found", id) }
            )
        }
    }

    /// 获取执行历史
    pub async fn get_execution_history(
        &self,
        scheduled_transaction_id: String,
        limit: u32,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ExecutionRecord>> {
        let history = self.execution_history.lock().unwrap();
        
        let records: Vec<_> = history.iter()
            .filter(|r| r.scheduled_transaction_id == scheduled_transaction_id)
            .take(limit as usize)
            .cloned()
            .collect();

        ServiceResponse::success(records)
    }

    /// 获取定期交易统计
    pub async fn get_scheduled_statistics(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<ScheduledStatistics> {
        let storage = self.scheduled_transactions.lock().unwrap();
        let history = self.execution_history.lock().unwrap();

        let total = storage.len() as u32;
        let active = storage.iter().filter(|s| s.status == ScheduledTransactionStatus::Active).count() as u32;
        let paused = storage.iter().filter(|s| s.status == ScheduledTransactionStatus::Paused).count() as u32;
        let completed = storage.iter().filter(|s| s.status == ScheduledTransactionStatus::Completed).count() as u32;

        // 计算月度预计支出
        let monthly_estimated: Decimal = storage.iter()
            .filter(|s| s.status == ScheduledTransactionStatus::Active)
            .map(|s| {
                match s.recurrence_type {
                    RecurrenceType::Daily => s.amount * Decimal::from(30),
                    RecurrenceType::Weekly => s.amount * Decimal::from(4),
                    RecurrenceType::Biweekly => s.amount * Decimal::from(2),
                    RecurrenceType::Monthly => s.amount,
                    RecurrenceType::Quarterly => s.amount / Decimal::from(3),
                    RecurrenceType::Yearly => s.amount / Decimal::from(12),
                    _ => Decimal::ZERO,
                }
            })
            .sum();

        let stats = ScheduledStatistics {
            total_scheduled: total,
            active_scheduled: active,
            paused_scheduled: paused,
            completed_scheduled: completed,
            total_executions: history.len() as u32,
            successful_executions: history.iter()
                .filter(|r| r.status == ExecutionStatus::Success)
                .count() as u32,
            failed_executions: history.iter()
                .filter(|r| r.status == ExecutionStatus::Failed)
                .count() as u32,
            monthly_estimated_amount: monthly_estimated,
            next_7_days_count: storage.iter()
                .filter(|s| {
                    let now = chrono::Utc::now().naive_utc().date();
                    let week_later = now + Duration::days(7);
                    s.status == ScheduledTransactionStatus::Active &&
                    s.next_run >= now &&
                    s.next_run <= week_later
                })
                .count() as u32,
        };

        ServiceResponse::success(stats)
    }

    /// 批量更新定期交易
    pub async fn bulk_update_scheduled_transactions(
        &self,
        ids: Vec<String>,
        update: BulkUpdateRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ScheduledTransaction>> {
        let mut storage = self.scheduled_transactions.lock().unwrap();
        let mut updated = Vec::new();

        for scheduled in storage.iter_mut() {
            if ids.contains(&scheduled.id) {
                // 应用批量更新
                if let Some(ref category_id) = update.category_id {
                    scheduled.category_id = Some(category_id.clone());
                }
                if let Some(auto_confirm) = update.auto_confirm {
                    scheduled.auto_confirm = auto_confirm;
                }
                if let Some(reminder_enabled) = update.reminder_enabled {
                    scheduled.reminder_enabled = reminder_enabled;
                }
                if let Some(ref status) = update.status {
                    scheduled.status = status.clone();
                }

                scheduled.updated_at = chrono::Utc::now().naive_utc();
                updated.push(scheduled.clone());
            }
        }

        ServiceResponse::success_with_message(
            updated,
            format!("Updated {} scheduled transactions", ids.len())
        )
    }

    // 辅助方法：验证周期配置
    fn validate_recurrence(
        recurrence_type: &RecurrenceType,
        config: &Option<RecurrenceConfig>,
    ) -> Result<()> {
        match recurrence_type {
            RecurrenceType::Custom => {
                if config.is_none() {
                    return Err(JiveError::ValidationError {
                        message: "Custom recurrence requires configuration".to_string()
                    });
                }
            }
            _ => {}
        }
        Ok(())
    }

    // 辅助方法：计算下次执行时间
    fn calculate_next_run(
        from_date: &NaiveDate,
        recurrence_type: &RecurrenceType,
        config: &Option<RecurrenceConfig>,
    ) -> Option<NaiveDate> {
        match recurrence_type {
            RecurrenceType::Daily => Some(*from_date + Duration::days(1)),
            RecurrenceType::Weekly => Some(*from_date + Duration::days(7)),
            RecurrenceType::Biweekly => Some(*from_date + Duration::days(14)),
            RecurrenceType::Monthly => {
                let next_month = if from_date.month() == 12 {
                    from_date.with_year(from_date.year() + 1)?.with_month(1)?
                } else {
                    from_date.with_month(from_date.month() + 1)?
                };
                Some(next_month)
            }
            RecurrenceType::Quarterly => {
                Some(*from_date + Duration::days(90))
            }
            RecurrenceType::Yearly => {
                from_date.with_year(from_date.year() + 1)
            }
            RecurrenceType::Custom => {
                if let Some(ref cfg) = config {
                    Some(*from_date + Duration::days(cfg.interval_days as i64))
                } else {
                    None
                }
            }
            RecurrenceType::OneTime => None,
        }
    }
}

/// 定期交易
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScheduledTransaction {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub amount: Decimal,
    pub from_account_id: String,
    pub to_account_id: Option<String>,
    pub category_id: Option<String>,
    pub tags: Vec<String>,
    pub recurrence_type: RecurrenceType,
    pub recurrence_config: Option<RecurrenceConfig>,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub next_run: NaiveDate,
    pub last_run: Option<NaiveDateTime>,
    pub status: ScheduledTransactionStatus,
    pub auto_confirm: bool,
    pub reminder_enabled: bool,
    pub reminder_days_before: u32,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
    pub user_id: String,
    pub ledger_id: Option<String>,
}

/// 周期类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum RecurrenceType {
    Daily,      // 每日
    Weekly,     // 每周
    Biweekly,   // 双周
    Monthly,    // 每月
    Quarterly,  // 季度
    Yearly,     // 年度
    Custom,     // 自定义
    OneTime,    // 一次性
}

/// 自定义周期配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecurrenceConfig {
    pub interval_days: u32,
    pub weekdays: Option<Vec<Weekday>>,
    pub month_days: Option<Vec<u32>>,
    pub months: Option<Vec<u32>>,
}

/// 定期交易状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ScheduledTransactionStatus {
    Active,     // 活动中
    Paused,     // 已暂停
    Completed,  // 已完成
    Cancelled,  // 已取消
}

/// 执行记录
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionRecord {
    pub id: String,
    pub scheduled_transaction_id: String,
    pub transaction_id: String,
    pub executed_at: NaiveDateTime,
    pub amount: Decimal,
    pub status: ExecutionStatus,
    pub error_message: Option<String>,
}

/// 执行状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ExecutionStatus {
    Success,
    Failed,
    Skipped,
}

/// 执行汇总
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ExecutionSummary {
    pub total: u32,
    pub executed: u32,
    pub pending: u32,
    pub failed: u32,
}

/// 统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScheduledStatistics {
    pub total_scheduled: u32,
    pub active_scheduled: u32,
    pub paused_scheduled: u32,
    pub completed_scheduled: u32,
    pub total_executions: u32,
    pub successful_executions: u32,
    pub failed_executions: u32,
    pub monthly_estimated_amount: Decimal,
    pub next_7_days_count: u32,
}

/// 创建定期交易请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateScheduledTransactionRequest {
    pub name: String,
    pub description: Option<String>,
    pub amount: Decimal,
    pub from_account_id: String,
    pub to_account_id: Option<String>,
    pub category_id: Option<String>,
    pub tags: Vec<String>,
    pub recurrence_type: RecurrenceType,
    pub recurrence_config: Option<RecurrenceConfig>,
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub auto_confirm: bool,
    pub reminder_enabled: bool,
    pub reminder_days_before: u32,
}

/// 更新定期交易请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateScheduledTransactionRequest {
    pub name: Option<String>,
    pub description: Option<String>,
    pub amount: Option<Decimal>,
    pub category_id: Option<String>,
    pub tags: Option<Vec<String>>,
    pub auto_confirm: Option<bool>,
    pub reminder_enabled: Option<bool>,
    pub status: Option<ScheduledTransactionStatus>,
}

/// 批量更新请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BulkUpdateRequest {
    pub category_id: Option<String>,
    pub auto_confirm: Option<bool>,
    pub reminder_enabled: Option<bool>,
    pub status: Option<ScheduledTransactionStatus>,
}

/// 定期交易过滤器
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct ScheduledTransactionFilter {
    pub status: Option<ScheduledTransactionStatus>,
    pub recurrence_type: Option<RecurrenceType>,
    pub category_id: Option<String>,
    pub search: Option<String>,
}

// 外部依赖
use uuid;

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_scheduled_transaction() {
        let service = ScheduledTransactionService::new();
        let context = ServiceContext::new("test-user".to_string());

        let request = CreateScheduledTransactionRequest {
            name: "Monthly Rent".to_string(),
            description: Some("Apartment rent payment".to_string()),
            amount: Decimal::from(1500),
            from_account_id: "checking-account".to_string(),
            to_account_id: Some("landlord-account".to_string()),
            category_id: Some("housing".to_string()),
            tags: vec!["rent".to_string(), "fixed".to_string()],
            recurrence_type: RecurrenceType::Monthly,
            recurrence_config: None,
            start_date: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
            end_date: None,
            auto_confirm: true,
            reminder_enabled: true,
            reminder_days_before: 3,
        };

        let result = service.create_scheduled_transaction(request, context).await;
        assert!(result.success);
        assert!(result.data.is_some());
        
        let scheduled = result.data.unwrap();
        assert_eq!(scheduled.name, "Monthly Rent");
        assert_eq!(scheduled.amount, Decimal::from(1500));
        assert_eq!(scheduled.recurrence_type, RecurrenceType::Monthly);
    }

    #[tokio::test]
    async fn test_execute_scheduled_transaction() {
        let service = ScheduledTransactionService::new();
        let context = ServiceContext::new("test-user".to_string());

        // 先创建一个定期交易
        let request = CreateScheduledTransactionRequest {
            name: "Weekly Grocery".to_string(),
            description: None,
            amount: Decimal::from(100),
            from_account_id: "checking".to_string(),
            to_account_id: None,
            category_id: Some("food".to_string()),
            tags: vec![],
            recurrence_type: RecurrenceType::Weekly,
            recurrence_config: None,
            start_date: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
            end_date: None,
            auto_confirm: false,
            reminder_enabled: false,
            reminder_days_before: 0,
        };

        let created = service.create_scheduled_transaction(request, context.clone()).await;
        assert!(created.success);
        
        let scheduled_id = created.data.unwrap().id;

        // 执行定期交易
        let execution = service.execute_scheduled_transaction(scheduled_id, context).await;
        assert!(execution.success);
        assert!(execution.data.is_some());
    }

    #[tokio::test]
    async fn test_pause_and_resume() {
        let service = ScheduledTransactionService::new();
        let context = ServiceContext::new("test-user".to_string());

        // 创建定期交易
        let request = CreateScheduledTransactionRequest {
            name: "Test Subscription".to_string(),
            description: None,
            amount: Decimal::from(10),
            from_account_id: "account".to_string(),
            to_account_id: None,
            category_id: None,
            tags: vec![],
            recurrence_type: RecurrenceType::Monthly,
            recurrence_config: None,
            start_date: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
            end_date: None,
            auto_confirm: true,
            reminder_enabled: false,
            reminder_days_before: 0,
        };

        let created = service.create_scheduled_transaction(request, context.clone()).await;
        let id = created.data.unwrap().id;

        // 暂停
        let paused = service.pause_scheduled_transaction(id.clone(), context.clone()).await;
        assert!(paused.success);
        assert_eq!(paused.data.unwrap().status, ScheduledTransactionStatus::Paused);

        // 恢复
        let resumed = service.resume_scheduled_transaction(id, context).await;
        assert!(resumed.success);
        assert_eq!(resumed.data.unwrap().status, ScheduledTransactionStatus::Active);
    }

    #[test]
    fn test_recurrence_types() {
        // 测试每种周期类型
        assert_eq!(
            serde_json::to_string(&RecurrenceType::Daily).unwrap(),
            "\"Daily\""
        );
        assert_eq!(
            serde_json::to_string(&RecurrenceType::Monthly).unwrap(),
            "\"Monthly\""
        );
    }

    #[test]
    fn test_scheduled_status() {
        // 测试状态枚举
        assert_eq!(
            serde_json::to_string(&ScheduledTransactionStatus::Active).unwrap(),
            "\"Active\""
        );
        assert_eq!(
            serde_json::to_string(&ScheduledTransactionStatus::Paused).unwrap(),
            "\"Paused\""
        );
    }
}