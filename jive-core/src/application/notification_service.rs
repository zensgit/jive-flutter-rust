//! NotificationService - 通知管理服务
//! 
//! 提供全面的通知管理功能，包括：
//! - 多种通知类型支持
//! - 智能推送策略
//! - 通知模板系统
//! - 批量通知处理
//! - 通知历史追踪

use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::{NaiveDateTime, Utc, Duration};
use std::collections::HashMap;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::{
    error::{JiveError, Result},
    models::{ServiceContext, ServiceResponse, PaginationParams, PaginatedResult}
};

/// 通知类型枚举
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum NotificationType {
    BudgetAlert,        // 预算警告
    PaymentReminder,    // 付款提醒
    BillDue,           // 账单到期
    GoalAchievement,   // 目标达成
    SecurityAlert,     // 安全警告
    SystemUpdate,      // 系统更新
    TransactionAlert,  // 交易警告
    CategoryAlert,     // 分类警告
    WeeklyReport,      // 周报
    MonthlyReport,     // 月报
    CustomAlert,       // 自定义警告
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl NotificationType {
    #[wasm_bindgen(getter)]
    pub fn as_string(&self) -> String {
        match self {
            NotificationType::BudgetAlert => "budget_alert".to_string(),
            NotificationType::PaymentReminder => "payment_reminder".to_string(),
            NotificationType::BillDue => "bill_due".to_string(),
            NotificationType::GoalAchievement => "goal_achievement".to_string(),
            NotificationType::SecurityAlert => "security_alert".to_string(),
            NotificationType::SystemUpdate => "system_update".to_string(),
            NotificationType::TransactionAlert => "transaction_alert".to_string(),
            NotificationType::CategoryAlert => "category_alert".to_string(),
            NotificationType::WeeklyReport => "weekly_report".to_string(),
            NotificationType::MonthlyReport => "monthly_report".to_string(),
            NotificationType::CustomAlert => "custom_alert".to_string(),
        }
    }
}

/// 通知优先级
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum NotificationPriority {
    Low,      // 低优先级
    Medium,   // 中等优先级
    High,     // 高优先级
    Urgent,   // 紧急
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl NotificationPriority {
    #[wasm_bindgen(getter)]
    pub fn as_string(&self) -> String {
        match self {
            NotificationPriority::Low => "low".to_string(),
            NotificationPriority::Medium => "medium".to_string(),
            NotificationPriority::High => "high".to_string(),
            NotificationPriority::Urgent => "urgent".to_string(),
        }
    }
}

/// 通知状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum NotificationStatus {
    Pending,    // 待发送
    Sent,       // 已发送
    Read,       // 已读
    Dismissed,  // 已忽略
    Failed,     // 发送失败
}

/// 通知渠道
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum NotificationChannel {
    InApp,      // 应用内通知
    Email,      // 邮件
    SMS,        // 短信
    Push,       // 推送通知
    WebHook,    // 网络钩子
}

/// 通知信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct Notification {
    pub id: String,
    pub user_id: String,
    pub notification_type: NotificationType,
    pub priority: NotificationPriority,
    pub status: NotificationStatus,
    pub title: String,
    pub message: String,
    pub action_url: Option<String>,
    pub data: Option<String>, // JSON数据
    pub channels: Vec<NotificationChannel>,
    pub scheduled_at: Option<NaiveDateTime>,
    pub sent_at: Option<NaiveDateTime>,
    pub read_at: Option<NaiveDateTime>,
    pub expires_at: Option<NaiveDateTime>,
    pub retry_count: u32,
    pub max_retries: u32,
    pub template_id: Option<String>,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl Notification {
    #[wasm_bindgen(getter)]
    pub fn id(&self) -> String { self.id.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn user_id(&self) -> String { self.user_id.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn title(&self) -> String { self.title.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn message(&self) -> String { self.message.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn is_read(&self) -> bool { 
        matches!(self.status, NotificationStatus::Read | NotificationStatus::Dismissed) 
    }
    
    #[wasm_bindgen(getter)]
    pub fn is_expired(&self) -> bool {
        if let Some(expires_at) = self.expires_at {
            Utc::now().naive_utc() > expires_at
        } else {
            false
        }
    }
}

/// 通知模板
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct NotificationTemplate {
    pub id: String,
    pub name: String,
    pub notification_type: NotificationType,
    pub title_template: String,
    pub message_template: String,
    pub default_priority: NotificationPriority,
    pub default_channels: Vec<NotificationChannel>,
    pub variables: Vec<String>,
    pub is_active: bool,
    pub created_at: NaiveDateTime,
    pub updated_at: NaiveDateTime,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl NotificationTemplate {
    #[wasm_bindgen(getter)]
    pub fn id(&self) -> String { self.id.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String { self.name.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn title_template(&self) -> String { self.title_template.clone() }
    
    #[wasm_bindgen(getter)]
    pub fn message_template(&self) -> String { self.message_template.clone() }
}

/// 创建通知请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CreateNotificationRequest {
    pub user_id: String,
    pub notification_type: NotificationType,
    pub priority: NotificationPriority,
    pub title: String,
    pub message: String,
    pub action_url: Option<String>,
    pub data: Option<String>,
    pub channels: Vec<NotificationChannel>,
    pub scheduled_at: Option<NaiveDateTime>,
    pub expires_at: Option<NaiveDateTime>,
    pub template_id: Option<String>,
    pub template_variables: Option<HashMap<String, String>>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CreateNotificationRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(
        user_id: String,
        notification_type: NotificationType,
        title: String,
        message: String,
    ) -> Self {
        Self {
            user_id,
            notification_type,
            priority: NotificationPriority::Medium,
            title,
            message,
            action_url: None,
            data: None,
            channels: vec![NotificationChannel::InApp],
            scheduled_at: None,
            expires_at: None,
            template_id: None,
            template_variables: None,
        }
    }
    
    #[wasm_bindgen(setter)]
    pub fn set_priority(&mut self, priority: NotificationPriority) {
        self.priority = priority;
    }
    
    #[wasm_bindgen(setter)]
    pub fn set_action_url(&mut self, action_url: Option<String>) {
        self.action_url = action_url;
    }
    
    #[wasm_bindgen]
    pub fn add_channel(&mut self, channel: NotificationChannel) {
        if !self.channels.contains(&channel) {
            self.channels.push(channel);
        }
    }
}

/// 通知查询过滤器
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct NotificationFilter {
    pub user_id: Option<String>,
    pub notification_type: Option<NotificationType>,
    pub priority: Option<NotificationPriority>,
    pub status: Option<NotificationStatus>,
    pub is_read: Option<bool>,
    pub channel: Option<NotificationChannel>,
    pub created_after: Option<NaiveDateTime>,
    pub created_before: Option<NaiveDateTime>,
    pub expires_after: Option<NaiveDateTime>,
    pub expires_before: Option<NaiveDateTime>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl NotificationFilter {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            user_id: None,
            notification_type: None,
            priority: None,
            status: None,
            is_read: None,
            channel: None,
            created_after: None,
            created_before: None,
            expires_after: None,
            expires_before: None,
        }
    }
}

impl Default for NotificationFilter {
    fn default() -> Self {
        Self::new()
    }
}

/// 批量通知请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BulkNotificationRequest {
    pub user_ids: Vec<String>,
    pub notification_type: NotificationType,
    pub priority: NotificationPriority,
    pub title: String,
    pub message: String,
    pub action_url: Option<String>,
    pub data: Option<String>,
    pub channels: Vec<NotificationChannel>,
    pub scheduled_at: Option<NaiveDateTime>,
    pub expires_at: Option<NaiveDateTime>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl BulkNotificationRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(
        notification_type: NotificationType,
        title: String,
        message: String,
    ) -> Self {
        Self {
            user_ids: Vec::new(),
            notification_type,
            priority: NotificationPriority::Medium,
            title,
            message,
            action_url: None,
            data: None,
            channels: vec![NotificationChannel::InApp],
            scheduled_at: None,
            expires_at: None,
        }
    }
    
    #[wasm_bindgen]
    pub fn add_user(&mut self, user_id: String) {
        if !self.user_ids.contains(&user_id) {
            self.user_ids.push(user_id);
        }
    }
}

/// 通知统计
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct NotificationStats {
    pub total_sent: u32,
    pub total_read: u32,
    pub total_dismissed: u32,
    pub total_failed: u32,
    pub read_rate: f64,
    pub delivery_rate: f64,
    pub by_type: HashMap<String, u32>,
    pub by_channel: HashMap<String, u32>,
    pub by_priority: HashMap<String, u32>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl NotificationStats {
    #[wasm_bindgen(getter)]
    pub fn total_sent(&self) -> u32 { self.total_sent }
    
    #[wasm_bindgen(getter)]
    pub fn total_read(&self) -> u32 { self.total_read }
    
    #[wasm_bindgen(getter)]
    pub fn read_rate(&self) -> f64 { self.read_rate }
    
    #[wasm_bindgen(getter)]
    pub fn delivery_rate(&self) -> f64 { self.delivery_rate }
}

/// 通知管理服务
#[derive(Debug)]
pub struct NotificationService {
    notifications: HashMap<String, Notification>,
    templates: HashMap<String, NotificationTemplate>,
    user_preferences: HashMap<String, NotificationPreferences>,
}

/// 用户通知偏好设置
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct NotificationPreferences {
    pub user_id: String,
    pub enabled_channels: Vec<NotificationChannel>,
    pub enabled_types: Vec<NotificationType>,
    pub quiet_hours_start: Option<String>, // HH:MM格式
    pub quiet_hours_end: Option<String>,
    pub timezone: Option<String>,
    pub email: Option<String>,
    pub phone: Option<String>,
    pub frequency_limits: HashMap<String, u32>, // 类型 -> 每天最大数量
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl NotificationPreferences {
    #[wasm_bindgen(constructor)]
    pub fn new(user_id: String) -> Self {
        Self {
            user_id,
            enabled_channels: vec![NotificationChannel::InApp],
            enabled_types: vec![
                NotificationType::BudgetAlert,
                NotificationType::PaymentReminder,
                NotificationType::BillDue,
                NotificationType::SecurityAlert,
            ],
            quiet_hours_start: None,
            quiet_hours_end: None,
            timezone: None,
            email: None,
            phone: None,
            frequency_limits: HashMap::new(),
        }
    }
}

impl NotificationService {
    pub fn new() -> Self {
        let mut service = Self {
            notifications: HashMap::new(),
            templates: HashMap::new(),
            user_preferences: HashMap::new(),
        };
        
        service.init_default_templates();
        service
    }

    /// 初始化默认通知模板
    fn init_default_templates(&mut self) {
        let templates = vec![
            (
                NotificationType::BudgetAlert,
                "预算警告",
                "预算超限提醒",
                "您的{{category}}预算已超出{{percentage}}%",
                NotificationPriority::High,
                vec![NotificationChannel::InApp, NotificationChannel::Email],
                vec!["category".to_string(), "percentage".to_string(), "amount".to_string()],
            ),
            (
                NotificationType::PaymentReminder,
                "付款提醒",
                "付款到期提醒",
                "您有一笔{{amount}}的付款将在{{days}}天后到期",
                NotificationPriority::Medium,
                vec![NotificationChannel::InApp, NotificationChannel::Push],
                vec!["amount".to_string(), "days".to_string(), "payee".to_string()],
            ),
            (
                NotificationType::BillDue,
                "账单到期",
                "账单到期通知",
                "{{bill_name}}账单{{amount}}将在{{date}}到期",
                NotificationPriority::High,
                vec![NotificationChannel::InApp, NotificationChannel::Email, NotificationChannel::Push],
                vec!["bill_name".to_string(), "amount".to_string(), "date".to_string()],
            ),
            (
                NotificationType::GoalAchievement,
                "目标达成",
                "恭喜！目标达成",
                "恭喜您完成了{{goal_name}}目标！",
                NotificationPriority::Medium,
                vec![NotificationChannel::InApp, NotificationChannel::Push],
                vec!["goal_name".to_string(), "achievement_date".to_string()],
            ),
            (
                NotificationType::SecurityAlert,
                "安全警告",
                "账户安全警告",
                "检测到异常活动：{{activity_type}}",
                NotificationPriority::Urgent,
                vec![NotificationChannel::InApp, NotificationChannel::Email, NotificationChannel::SMS],
                vec!["activity_type".to_string(), "location".to_string(), "time".to_string()],
            ),
            (
                NotificationType::WeeklyReport,
                "周报",
                "本周财务报告",
                "本周您共消费{{total_spent}}，主要支出为{{top_category}}",
                NotificationPriority::Low,
                vec![NotificationChannel::InApp, NotificationChannel::Email],
                vec!["total_spent".to_string(), "top_category".to_string(), "week_range".to_string()],
            ),
        ];

        for (notification_type, name, title, message, priority, channels, variables) in templates {
            let template = NotificationTemplate {
                id: Uuid::new_v4().to_string(),
                name: name.to_string(),
                notification_type,
                title_template: title.to_string(),
                message_template: message.to_string(),
                default_priority: priority,
                default_channels: channels,
                variables,
                is_active: true,
                created_at: Utc::now().naive_utc(),
                updated_at: Utc::now().naive_utc(),
            };
            
            self.templates.insert(template.id.clone(), template);
        }
    }

    /// 创建通知
    pub async fn create_notification(
        &mut self,
        request: CreateNotificationRequest,
        _context: &ServiceContext,
    ) -> Result<Notification> {
        // 验证输入
        if request.user_id.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "用户ID不能为空".to_string(),
            });
        }

        if request.title.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "通知标题不能为空".to_string(),
            });
        }

        if request.message.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "通知消息不能为空".to_string(),
            });
        }

        if request.channels.is_empty() {
            return Err(JiveError::ValidationError {
                message: "至少需要选择一个通知渠道".to_string(),
            });
        }

        // 检查用户通知偏好
        if let Some(preferences) = self.user_preferences.get(&request.user_id) {
            // 检查用户是否启用了该通知类型
            if !preferences.enabled_types.contains(&request.notification_type) {
                return Err(JiveError::ValidationError {
                    message: "用户未启用此类型的通知".to_string(),
                });
            }

            // 检查通知渠道是否可用
            let available_channels: Vec<_> = request.channels.iter()
                .filter(|channel| preferences.enabled_channels.contains(channel))
                .cloned()
                .collect();

            if available_channels.is_empty() {
                return Err(JiveError::ValidationError {
                    message: "用户未启用任何请求的通知渠道".to_string(),
                });
            }
        }

        // 处理模板变量替换
        let (final_title, final_message) = if let Some(template_id) = &request.template_id {
            if let Some(template) = self.templates.get(template_id) {
                if let Some(variables) = &request.template_variables {
                    let title = self.replace_template_variables(&template.title_template, variables);
                    let message = self.replace_template_variables(&template.message_template, variables);
                    (title, message)
                } else {
                    (template.title_template.clone(), template.message_template.clone())
                }
            } else {
                return Err(JiveError::NotFound {
                    message: format!("通知模板 {} 不存在", template_id),
                });
            }
        } else {
            (request.title.clone(), request.message.clone())
        };

        // 设置过期时间（默认30天）
        let expires_at = request.expires_at
            .or_else(|| Some(Utc::now().naive_utc() + Duration::days(30)));

        let now = Utc::now().naive_utc();
        let notification = Notification {
            id: Uuid::new_v4().to_string(),
            user_id: request.user_id,
            notification_type: request.notification_type,
            priority: request.priority,
            status: if request.scheduled_at.is_some() {
                NotificationStatus::Pending
            } else {
                NotificationStatus::Sent // 立即发送
            },
            title: final_title,
            message: final_message,
            action_url: request.action_url,
            data: request.data,
            channels: request.channels,
            scheduled_at: request.scheduled_at,
            sent_at: if request.scheduled_at.is_none() { Some(now) } else { None },
            read_at: None,
            expires_at,
            retry_count: 0,
            max_retries: 3,
            template_id: request.template_id,
            created_at: now,
            updated_at: now,
        };

        self.notifications.insert(notification.id.clone(), notification.clone());
        Ok(notification)
    }

    /// 批量创建通知
    pub async fn create_bulk_notifications(
        &mut self,
        request: BulkNotificationRequest,
        context: &ServiceContext,
    ) -> Result<Vec<String>> {
        if request.user_ids.is_empty() {
            return Err(JiveError::ValidationError {
                message: "用户ID列表不能为空".to_string(),
            });
        }

        let mut notification_ids = Vec::new();
        
        for user_id in request.user_ids {
            let individual_request = CreateNotificationRequest {
                user_id,
                notification_type: request.notification_type.clone(),
                priority: request.priority.clone(),
                title: request.title.clone(),
                message: request.message.clone(),
                action_url: request.action_url.clone(),
                data: request.data.clone(),
                channels: request.channels.clone(),
                scheduled_at: request.scheduled_at,
                expires_at: request.expires_at,
                template_id: None,
                template_variables: None,
            };

            match self.create_notification(individual_request, context).await {
                Ok(notification) => notification_ids.push(notification.id),
                Err(_) => continue, // 跳过失败的通知
            }
        }

        Ok(notification_ids)
    }

    /// 获取通知详情
    pub async fn get_notification(
        &self,
        notification_id: &str,
        _context: &ServiceContext,
    ) -> Result<Notification> {
        self.notifications.get(notification_id)
            .cloned()
            .ok_or_else(|| JiveError::NotFound {
                message: format!("通知 {} 不存在", notification_id),
            })
    }

    /// 查询通知列表
    pub async fn get_notifications(
        &self,
        filter: Option<NotificationFilter>,
        pagination: PaginationParams,
        _context: &ServiceContext,
    ) -> Result<PaginatedResult<Notification>> {
        let mut notifications: Vec<_> = self.notifications.values().collect();

        // 应用过滤器
        if let Some(filter) = filter {
            notifications.retain(|notification| {
                if let Some(user_id) = &filter.user_id {
                    if &notification.user_id != user_id {
                        return false;
                    }
                }

                if let Some(notification_type) = &filter.notification_type {
                    if &notification.notification_type != notification_type {
                        return false;
                    }
                }

                if let Some(priority) = &filter.priority {
                    if &notification.priority != priority {
                        return false;
                    }
                }

                if let Some(status) = &filter.status {
                    if &notification.status != status {
                        return false;
                    }
                }

                if let Some(is_read) = filter.is_read {
                    let notification_is_read = matches!(
                        notification.status, 
                        NotificationStatus::Read | NotificationStatus::Dismissed
                    );
                    if notification_is_read != is_read {
                        return false;
                    }
                }

                if let Some(channel) = &filter.channel {
                    if !notification.channels.contains(channel) {
                        return false;
                    }
                }

                if let Some(created_after) = filter.created_after {
                    if notification.created_at < created_after {
                        return false;
                    }
                }

                if let Some(created_before) = filter.created_before {
                    if notification.created_at > created_before {
                        return false;
                    }
                }

                true
            });
        }

        // 按创建时间降序排序（最新的在前）
        notifications.sort_by(|a, b| b.created_at.cmp(&a.created_at));

        let total_count = notifications.len() as u32;
        let start = pagination.offset as usize;
        let end = (start + pagination.per_page as usize).min(notifications.len());
        
        let page_items = notifications[start..end].iter().map(|n| (*n).clone()).collect();

        Ok(PaginatedResult::new(page_items, total_count, &pagination))
    }

    /// 标记通知为已读
    pub async fn mark_as_read(
        &mut self,
        notification_id: &str,
        _context: &ServiceContext,
    ) -> Result<()> {
        let notification = self.notifications.get_mut(notification_id)
            .ok_or_else(|| JiveError::NotFound {
                message: format!("通知 {} 不存在", notification_id),
            })?;

        if notification.status != NotificationStatus::Read {
            notification.status = NotificationStatus::Read;
            notification.read_at = Some(Utc::now().naive_utc());
            notification.updated_at = Utc::now().naive_utc();
        }

        Ok(())
    }

    /// 标记通知为已忽略
    pub async fn dismiss_notification(
        &mut self,
        notification_id: &str,
        _context: &ServiceContext,
    ) -> Result<()> {
        let notification = self.notifications.get_mut(notification_id)
            .ok_or_else(|| JiveError::NotFound {
                message: format!("通知 {} 不存在", notification_id),
            })?;

        notification.status = NotificationStatus::Dismissed;
        notification.read_at = Some(Utc::now().naive_utc());
        notification.updated_at = Utc::now().naive_utc();

        Ok(())
    }

    /// 批量标记为已读
    pub async fn mark_all_as_read(
        &mut self,
        user_id: &str,
        _context: &ServiceContext,
    ) -> Result<u32> {
        let mut marked_count = 0;
        let now = Utc::now().naive_utc();

        for notification in self.notifications.values_mut() {
            if notification.user_id == user_id && 
               !matches!(notification.status, NotificationStatus::Read | NotificationStatus::Dismissed) {
                notification.status = NotificationStatus::Read;
                notification.read_at = Some(now);
                notification.updated_at = now;
                marked_count += 1;
            }
        }

        Ok(marked_count)
    }

    /// 删除通知
    pub async fn delete_notification(
        &mut self,
        notification_id: &str,
        _context: &ServiceContext,
    ) -> Result<()> {
        if !self.notifications.contains_key(notification_id) {
            return Err(JiveError::NotFound {
                message: format!("通知 {} 不存在", notification_id),
            });
        }

        self.notifications.remove(notification_id);
        Ok(())
    }

    /// 清理过期通知
    pub async fn cleanup_expired_notifications(
        &mut self,
        _context: &ServiceContext,
    ) -> Result<u32> {
        let now = Utc::now().naive_utc();
        let mut removed_count = 0;

        let expired_ids: Vec<String> = self.notifications.iter()
            .filter_map(|(id, notification)| {
                if let Some(expires_at) = notification.expires_at {
                    if now > expires_at {
                        Some(id.clone())
                    } else {
                        None
                    }
                } else {
                    None
                }
            })
            .collect();

        for id in expired_ids {
            self.notifications.remove(&id);
            removed_count += 1;
        }

        Ok(removed_count)
    }

    /// 重试失败的通知
    pub async fn retry_failed_notifications(
        &mut self,
        _context: &ServiceContext,
    ) -> Result<u32> {
        let mut retried_count = 0;
        let now = Utc::now().naive_utc();

        for notification in self.notifications.values_mut() {
            if notification.status == NotificationStatus::Failed && 
               notification.retry_count < notification.max_retries {
                notification.retry_count += 1;
                notification.status = NotificationStatus::Pending;
                notification.updated_at = now;
                retried_count += 1;
            }
        }

        Ok(retried_count)
    }

    /// 获取通知统计
    pub async fn get_notification_stats(
        &self,
        user_id: Option<String>,
        _context: &ServiceContext,
    ) -> Result<NotificationStats> {
        let notifications: Vec<_> = if let Some(user_id) = user_id {
            self.notifications.values()
                .filter(|n| n.user_id == user_id)
                .collect()
        } else {
            self.notifications.values().collect()
        };

        let total_sent = notifications.iter()
            .filter(|n| !matches!(n.status, NotificationStatus::Pending))
            .count() as u32;

        let total_read = notifications.iter()
            .filter(|n| matches!(n.status, NotificationStatus::Read))
            .count() as u32;

        let total_dismissed = notifications.iter()
            .filter(|n| matches!(n.status, NotificationStatus::Dismissed))
            .count() as u32;

        let total_failed = notifications.iter()
            .filter(|n| matches!(n.status, NotificationStatus::Failed))
            .count() as u32;

        let read_rate = if total_sent > 0 {
            (total_read as f64 / total_sent as f64) * 100.0
        } else {
            0.0
        };

        let delivery_rate = if total_sent > 0 {
            ((total_sent - total_failed) as f64 / total_sent as f64) * 100.0
        } else {
            0.0
        };

        // 按类型统计
        let mut by_type = HashMap::new();
        for notification in &notifications {
            *by_type.entry(notification.notification_type.as_string()).or_insert(0) += 1;
        }

        // 按渠道统计
        let mut by_channel = HashMap::new();
        for notification in &notifications {
            for channel in &notification.channels {
                *by_channel.entry(channel.as_string()).or_insert(0) += 1;
            }
        }

        // 按优先级统计
        let mut by_priority = HashMap::new();
        for notification in &notifications {
            *by_priority.entry(notification.priority.as_string()).or_insert(0) += 1;
        }

        Ok(NotificationStats {
            total_sent,
            total_read,
            total_dismissed,
            total_failed,
            read_rate,
            delivery_rate,
            by_type,
            by_channel,
            by_priority,
        })
    }

    /// 设置用户通知偏好
    pub async fn set_user_preferences(
        &mut self,
        preferences: NotificationPreferences,
        _context: &ServiceContext,
    ) -> Result<()> {
        self.user_preferences.insert(preferences.user_id.clone(), preferences);
        Ok(())
    }

    /// 获取用户通知偏好
    pub async fn get_user_preferences(
        &self,
        user_id: &str,
        _context: &ServiceContext,
    ) -> Result<NotificationPreferences> {
        self.user_preferences.get(user_id)
            .cloned()
            .unwrap_or_else(|| NotificationPreferences::new(user_id.to_string()))
            .into()
    }

    /// 获取通知模板
    pub async fn get_templates(
        &self,
        notification_type: Option<NotificationType>,
        _context: &ServiceContext,
    ) -> Result<Vec<NotificationTemplate>> {
        let templates: Vec<_> = self.templates.values()
            .filter(|template| {
                if let Some(notification_type) = &notification_type {
                    &template.notification_type == notification_type
                } else {
                    true
                }
            })
            .filter(|template| template.is_active)
            .cloned()
            .collect();

        Ok(templates)
    }

    /// 创建通知模板
    pub async fn create_template(
        &mut self,
        name: String,
        notification_type: NotificationType,
        title_template: String,
        message_template: String,
        _context: &ServiceContext,
    ) -> Result<NotificationTemplate> {
        if name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "模板名称不能为空".to_string(),
            });
        }

        if title_template.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "标题模板不能为空".to_string(),
            });
        }

        if message_template.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "消息模板不能为空".to_string(),
            });
        }

        let template = NotificationTemplate {
            id: Uuid::new_v4().to_string(),
            name,
            notification_type,
            title_template,
            message_template,
            default_priority: NotificationPriority::Medium,
            default_channels: vec![NotificationChannel::InApp],
            variables: self.extract_template_variables(&title_template, &message_template),
            is_active: true,
            created_at: Utc::now().naive_utc(),
            updated_at: Utc::now().naive_utc(),
        };

        self.templates.insert(template.id.clone(), template.clone());
        Ok(template)
    }

    // 辅助方法：替换模板变量
    fn replace_template_variables(&self, template: &str, variables: &HashMap<String, String>) -> String {
        let mut result = template.to_string();
        for (key, value) in variables {
            result = result.replace(&format!("{{{{{}}}}}", key), value);
        }
        result
    }

    // 辅助方法：提取模板变量
    fn extract_template_variables(&self, title_template: &str, message_template: &str) -> Vec<String> {
        let mut variables = Vec::new();
        let combined = format!("{} {}", title_template, message_template);
        
        // 简单的正则匹配 {{variable}} 格式
        let mut start = 0;
        while let Some(open) = combined[start..].find("{{") {
            let open_pos = start + open;
            if let Some(close) = combined[open_pos + 2..].find("}}") {
                let close_pos = open_pos + 2 + close;
                let variable = combined[open_pos + 2..close_pos].to_string();
                if !variables.contains(&variable) {
                    variables.push(variable);
                }
                start = close_pos + 2;
            } else {
                break;
            }
        }
        
        variables
    }
}

impl Default for NotificationService {
    fn default() -> Self {
        Self::new()
    }
}

// 扩展通知渠道的字符串表示
#[cfg(feature = "wasm")]
impl NotificationChannel {
    #[wasm_bindgen(getter)]
    pub fn as_string(&self) -> String {
        match self {
            NotificationChannel::InApp => "in_app".to_string(),
            NotificationChannel::Email => "email".to_string(),
            NotificationChannel::SMS => "sms".to_string(),
            NotificationChannel::Push => "push".to_string(),
            NotificationChannel::WebHook => "webhook".to_string(),
        }
    }
}

// 为非WASM环境提供字符串转换
impl NotificationChannel {
    pub fn as_string(&self) -> String {
        match self {
            NotificationChannel::InApp => "in_app".to_string(),
            NotificationChannel::Email => "email".to_string(),
            NotificationChannel::SMS => "sms".to_string(),
            NotificationChannel::Push => "push".to_string(),
            NotificationChannel::WebHook => "webhook".to_string(),
        }
    }
}

impl NotificationPriority {
    pub fn as_string(&self) -> String {
        match self {
            NotificationPriority::Low => "low".to_string(),
            NotificationPriority::Medium => "medium".to_string(),
            NotificationPriority::High => "high".to_string(),
            NotificationPriority::Urgent => "urgent".to_string(),
        }
    }
}

impl NotificationType {
    pub fn as_string(&self) -> String {
        match self {
            NotificationType::BudgetAlert => "budget_alert".to_string(),
            NotificationType::PaymentReminder => "payment_reminder".to_string(),
            NotificationType::BillDue => "bill_due".to_string(),
            NotificationType::GoalAchievement => "goal_achievement".to_string(),
            NotificationType::SecurityAlert => "security_alert".to_string(),
            NotificationType::SystemUpdate => "system_update".to_string(),
            NotificationType::TransactionAlert => "transaction_alert".to_string(),
            NotificationType::CategoryAlert => "category_alert".to_string(),
            NotificationType::WeeklyReport => "weekly_report".to_string(),
            NotificationType::MonthlyReport => "monthly_report".to_string(),
            NotificationType::CustomAlert => "custom_alert".to_string(),
        }
    }
}

// WASM 绑定
#[cfg(feature = "wasm")]
#[wasm_bindgen]
pub struct WasmNotificationService {
    service: NotificationService,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl WasmNotificationService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            service: NotificationService::new(),
        }
    }

    #[wasm_bindgen]
    pub async fn create_notification(
        &mut self,
        request: CreateNotificationRequest,
        context: &ServiceContext,
    ) -> Result<ServiceResponse<Notification>, JsValue> {
        let result = self.service.create_notification(request, context).await;
        Ok(ServiceResponse::from(result))
    }

    #[wasm_bindgen]
    pub async fn get_notification(
        &self,
        notification_id: &str,
        context: &ServiceContext,
    ) -> Result<ServiceResponse<Notification>, JsValue> {
        let result = self.service.get_notification(notification_id, context).await;
        Ok(ServiceResponse::from(result))
    }

    #[wasm_bindgen]
    pub async fn mark_as_read(
        &mut self,
        notification_id: &str,
        context: &ServiceContext,
    ) -> Result<ServiceResponse<()>, JsValue> {
        let result = self.service.mark_as_read(notification_id, context).await;
        Ok(ServiceResponse::from(result))
    }

    #[wasm_bindgen]
    pub async fn get_notification_stats(
        &self,
        user_id: Option<String>,
        context: &ServiceContext,
    ) -> Result<ServiceResponse<NotificationStats>, JsValue> {
        let result = self.service.get_notification_stats(user_id, context).await;
        Ok(ServiceResponse::from(result))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_context() -> ServiceContext {
        ServiceContext {
            user_id: "test-user".to_string(),
            current_ledger_id: Some("test-ledger".to_string()),
            request_id: Some("test-request".to_string()),
            timestamp: Utc::now(),
        }
    }

    #[tokio::test]
    async fn test_create_notification() {
        let mut service = NotificationService::new();
        let context = create_test_context();

        let request = CreateNotificationRequest {
            user_id: "test-user".to_string(),
            notification_type: NotificationType::BudgetAlert,
            priority: NotificationPriority::High,
            title: "预算警告".to_string(),
            message: "您的餐饮预算已超出80%".to_string(),
            action_url: Some("/budgets/food".to_string()),
            data: Some("{\"category\": \"food\", \"percentage\": 80}".to_string()),
            channels: vec![NotificationChannel::InApp, NotificationChannel::Email],
            scheduled_at: None,
            expires_at: None,
            template_id: None,
            template_variables: None,
        };

        let notification = service.create_notification(request, &context).await.unwrap();
        assert_eq!(notification.title, "预算警告");
        assert_eq!(notification.message, "您的餐饮预算已超出80%");
        assert_eq!(notification.user_id, "test-user");
        assert_eq!(notification.notification_type, NotificationType::BudgetAlert);
        assert_eq!(notification.priority, NotificationPriority::High);
        assert_eq!(notification.status, NotificationStatus::Sent);
        assert!(notification.sent_at.is_some());
    }

    #[tokio::test]
    async fn test_notification_validation() {
        let mut service = NotificationService::new();
        let context = create_test_context();

        // 测试空用户ID
        let empty_user_request = CreateNotificationRequest {
            user_id: "".to_string(),
            notification_type: NotificationType::BudgetAlert,
            priority: NotificationPriority::Medium,
            title: "Test".to_string(),
            message: "Test message".to_string(),
            action_url: None,
            data: None,
            channels: vec![NotificationChannel::InApp],
            scheduled_at: None,
            expires_at: None,
            template_id: None,
            template_variables: None,
        };

        let result = service.create_notification(empty_user_request, &context).await;
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("用户ID不能为空"));

        // 测试空标题
        let empty_title_request = CreateNotificationRequest {
            user_id: "test-user".to_string(),
            notification_type: NotificationType::BudgetAlert,
            priority: NotificationPriority::Medium,
            title: "".to_string(),
            message: "Test message".to_string(),
            action_url: None,
            data: None,
            channels: vec![NotificationChannel::InApp],
            scheduled_at: None,
            expires_at: None,
            template_id: None,
            template_variables: None,
        };

        let result = service.create_notification(empty_title_request, &context).await;
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("通知标题不能为空"));

        // 测试空渠道
        let empty_channels_request = CreateNotificationRequest {
            user_id: "test-user".to_string(),
            notification_type: NotificationType::BudgetAlert,
            priority: NotificationPriority::Medium,
            title: "Test".to_string(),
            message: "Test message".to_string(),
            action_url: None,
            data: None,
            channels: vec![],
            scheduled_at: None,
            expires_at: None,
            template_id: None,
            template_variables: None,
        };

        let result = service.create_notification(empty_channels_request, &context).await;
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("至少需要选择一个通知渠道"));
    }

    #[tokio::test]
    async fn test_mark_as_read() {
        let mut service = NotificationService::new();
        let context = create_test_context();

        // 创建通知
        let request = CreateNotificationRequest {
            user_id: "test-user".to_string(),
            notification_type: NotificationType::PaymentReminder,
            priority: NotificationPriority::Medium,
            title: "付款提醒".to_string(),
            message: "您有一笔付款即将到期".to_string(),
            action_url: None,
            data: None,
            channels: vec![NotificationChannel::InApp],
            scheduled_at: None,
            expires_at: None,
            template_id: None,
            template_variables: None,
        };

        let notification = service.create_notification(request, &context).await.unwrap();
        assert_eq!(notification.status, NotificationStatus::Sent);
        assert!(notification.read_at.is_none());

        // 标记为已读
        service.mark_as_read(&notification.id, &context).await.unwrap();

        let updated_notification = service.get_notification(&notification.id, &context).await.unwrap();
        assert_eq!(updated_notification.status, NotificationStatus::Read);
        assert!(updated_notification.read_at.is_some());
    }

    #[tokio::test]
    async fn test_bulk_notifications() {
        let mut service = NotificationService::new();
        let context = create_test_context();

        let bulk_request = BulkNotificationRequest {
            user_ids: vec!["user1".to_string(), "user2".to_string(), "user3".to_string()],
            notification_type: NotificationType::SystemUpdate,
            priority: NotificationPriority::Low,
            title: "系统更新".to_string(),
            message: "系统将在今晚进行维护更新".to_string(),
            action_url: Some("/system/updates".to_string()),
            data: None,
            channels: vec![NotificationChannel::InApp, NotificationChannel::Email],
            scheduled_at: None,
            expires_at: None,
        };

        let notification_ids = service.create_bulk_notifications(bulk_request, &context).await.unwrap();
        assert_eq!(notification_ids.len(), 3);

        // 验证每个用户都收到了通知
        for user_id in &["user1", "user2", "user3"] {
            let filter = NotificationFilter {
                user_id: Some(user_id.to_string()),
                notification_type: Some(NotificationType::SystemUpdate),
                priority: None,
                status: None,
                is_read: None,
                channel: None,
                created_after: None,
                created_before: None,
                expires_after: None,
                expires_before: None,
            };

            let pagination = PaginationParams::new(1, 10);
            let notifications = service.get_notifications(Some(filter), pagination, &context).await.unwrap();
            assert_eq!(notifications.items.len(), 1);
            assert_eq!(notifications.items[0].title, "系统更新");
        }
    }

    #[tokio::test]
    async fn test_notification_stats() {
        let mut service = NotificationService::new();
        let context = create_test_context();

        // 创建不同状态的通知
        let notifications_data = vec![
            (NotificationStatus::Sent, NotificationType::BudgetAlert),
            (NotificationStatus::Read, NotificationType::PaymentReminder),
            (NotificationStatus::Read, NotificationType::BillDue),
            (NotificationStatus::Dismissed, NotificationType::GoalAchievement),
            (NotificationStatus::Failed, NotificationType::SecurityAlert),
        ];

        for (status, notification_type) in notifications_data {
            let request = CreateNotificationRequest {
                user_id: "test-user".to_string(),
                notification_type,
                priority: NotificationPriority::Medium,
                title: "Test Notification".to_string(),
                message: "Test message".to_string(),
                action_url: None,
                data: None,
                channels: vec![NotificationChannel::InApp],
                scheduled_at: None,
                expires_at: None,
                template_id: None,
                template_variables: None,
            };

            let notification = service.create_notification(request, &context).await.unwrap();
            
            // 手动设置状态（模拟不同的状态）
            if let Some(n) = service.notifications.get_mut(&notification.id) {
                n.status = status;
                if matches!(status, NotificationStatus::Read | NotificationStatus::Dismissed) {
                    n.read_at = Some(Utc::now().naive_utc());
                }
            }
        }

        let stats = service.get_notification_stats(Some("test-user".to_string()), &context).await.unwrap();
        assert_eq!(stats.total_sent, 5);
        assert_eq!(stats.total_read, 2);
        assert_eq!(stats.total_dismissed, 1);
        assert_eq!(stats.total_failed, 1);
        assert_eq!(stats.read_rate, 40.0); // 2/5 * 100
        assert_eq!(stats.delivery_rate, 80.0); // (5-1)/5 * 100
    }

    #[tokio::test]
    async fn test_template_variables() {
        let mut service = NotificationService::new();
        let context = create_test_context();

        // 创建一个包含模板变量的模板
        let template = service.create_template(
            "预算警告模板".to_string(),
            NotificationType::BudgetAlert,
            "{{category}}预算警告".to_string(),
            "您的{{category}}预算已超出{{percentage}}%，当前金额：{{amount}}".to_string(),
            &context,
        ).await.unwrap();

        // 使用模板创建通知
        let mut variables = HashMap::new();
        variables.insert("category".to_string(), "餐饮".to_string());
        variables.insert("percentage".to_string(), "120".to_string());
        variables.insert("amount".to_string(), "¥1,200".to_string());

        let request = CreateNotificationRequest {
            user_id: "test-user".to_string(),
            notification_type: NotificationType::BudgetAlert,
            priority: NotificationPriority::High,
            title: "".to_string(), // 将被模板替换
            message: "".to_string(), // 将被模板替换
            action_url: None,
            data: None,
            channels: vec![NotificationChannel::InApp],
            scheduled_at: None,
            expires_at: None,
            template_id: Some(template.id),
            template_variables: Some(variables),
        };

        let notification = service.create_notification(request, &context).await.unwrap();
        assert_eq!(notification.title, "餐饮预算警告");
        assert_eq!(notification.message, "您的餐饮预算已超出120%，当前金额：¥1,200");
    }
}