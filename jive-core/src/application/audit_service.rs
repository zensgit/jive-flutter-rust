// Audit Service - 审计日志系统
// Based on Maybe's activity logging patterns

use crate::domain::errors::DomainError;
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use sqlx::PgPool;
use uuid::Uuid;

pub struct AuditService {
    pool: Arc<PgPool>,
}

impl AuditService {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }
    
    // 记录审计事件
    pub async fn log_event(
        &self,
        event: AuditEvent,
    ) -> Result<AuditLog, DomainError> {
        let audit_log = sqlx::query_as!(
            AuditLog,
            r#"
            INSERT INTO audit_logs (
                id, family_id, user_id, action, resource_type, resource_id,
                old_values, new_values, ip_address, user_agent,
                success, error_message, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            RETURNING *
            "#,
            Uuid::new_v4(),
            event.family_id,
            event.user_id,
            event.action,
            event.resource_type,
            event.resource_id,
            serde_json::to_value(&event.old_values).ok(),
            serde_json::to_value(&event.new_values).ok(),
            event.ip_address,
            event.user_agent,
            event.success,
            event.error_message,
            Utc::now()
        )
        .fetch_one(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(audit_log)
    }
    
    // 记录账户变更
    pub async fn log_account_change(
        &self,
        family_id: Uuid,
        user_id: Uuid,
        account_id: Uuid,
        action: AuditAction,
        old_values: Option<serde_json::Value>,
        new_values: Option<serde_json::Value>,
    ) -> Result<(), DomainError> {
        self.log_event(AuditEvent {
            family_id,
            user_id,
            action: action.to_string(),
            resource_type: "Account".to_string(),
            resource_id: Some(account_id),
            old_values,
            new_values,
            ip_address: None,
            user_agent: None,
            success: true,
            error_message: None,
        }).await?;
        
        Ok(())
    }
    
    // 记录交易变更
    pub async fn log_transaction_change(
        &self,
        family_id: Uuid,
        user_id: Uuid,
        transaction_id: Uuid,
        action: AuditAction,
        field_changes: Vec<FieldChange>,
    ) -> Result<(), DomainError> {
        let old_values = field_changes.iter()
            .map(|fc| (fc.field.clone(), fc.old_value.clone()))
            .collect::<serde_json::Map<_, _>>();
        
        let new_values = field_changes.iter()
            .map(|fc| (fc.field.clone(), fc.new_value.clone()))
            .collect::<serde_json::Map<_, _>>();
        
        self.log_event(AuditEvent {
            family_id,
            user_id,
            action: action.to_string(),
            resource_type: "Transaction".to_string(),
            resource_id: Some(transaction_id),
            old_values: Some(serde_json::Value::Object(old_values)),
            new_values: Some(serde_json::Value::Object(new_values)),
            ip_address: None,
            user_agent: None,
            success: true,
            error_message: None,
        }).await?;
        
        Ok(())
    }
    
    // 记录批量操作
    pub async fn log_batch_operation(
        &self,
        family_id: Uuid,
        user_id: Uuid,
        operation: BatchOperation,
    ) -> Result<(), DomainError> {
        self.log_event(AuditEvent {
            family_id,
            user_id,
            action: format!("batch_{}", operation.operation_type),
            resource_type: "Batch".to_string(),
            resource_id: None,
            old_values: None,
            new_values: Some(serde_json::json!({
                "affected_count": operation.affected_count,
                "operation_details": operation.details
            })),
            ip_address: operation.ip_address,
            user_agent: operation.user_agent,
            success: operation.success,
            error_message: operation.error_message,
        }).await?;
        
        Ok(())
    }
    
    // 记录登录事件
    pub async fn log_login(
        &self,
        user_id: Uuid,
        ip_address: Option<String>,
        user_agent: Option<String>,
        success: bool,
        error: Option<String>,
    ) -> Result<(), DomainError> {
        // Get user's family
        let family_id = sqlx::query!(
            "SELECT family_id FROM users WHERE id = $1",
            user_id
        )
        .fetch_one(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?
        .family_id;
        
        self.log_event(AuditEvent {
            family_id,
            user_id,
            action: if success { "login_success" } else { "login_failed" }.to_string(),
            resource_type: "User".to_string(),
            resource_id: Some(user_id),
            old_values: None,
            new_values: Some(serde_json::json!({
                "ip_address": ip_address,
                "user_agent": user_agent
            })),
            ip_address,
            user_agent,
            success,
            error_message: error,
        }).await?;
        
        Ok(())
    }
    
    // 查询审计日志
    pub async fn get_audit_logs(
        &self,
        family_id: Uuid,
        filters: AuditFilters,
    ) -> Result<Vec<AuditLog>, DomainError> {
        let mut query = "SELECT * FROM audit_logs WHERE family_id = $1".to_string();
        let mut conditions = Vec::new();
        let mut param_count = 2;
        
        if let Some(user_id) = filters.user_id {
            conditions.push(format!("user_id = ${}", param_count));
            param_count += 1;
        }
        
        if let Some(resource_type) = &filters.resource_type {
            conditions.push(format!("resource_type = ${}", param_count));
            param_count += 1;
        }
        
        if let Some(action) = &filters.action {
            conditions.push(format!("action = ${}", param_count));
            param_count += 1;
        }
        
        if let Some(start_date) = filters.start_date {
            conditions.push(format!("created_at >= ${}", param_count));
            param_count += 1;
        }
        
        if let Some(end_date) = filters.end_date {
            conditions.push(format!("created_at <= ${}", param_count));
        }
        
        if !conditions.is_empty() {
            query += &format!(" AND {}", conditions.join(" AND "));
        }
        
        query += " ORDER BY created_at DESC LIMIT 100";
        
        // For simplicity, using a basic query
        let logs = sqlx::query_as!(
            AuditLog,
            "SELECT * FROM audit_logs WHERE family_id = $1 ORDER BY created_at DESC LIMIT 100",
            family_id
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(logs)
    }
    
    // 生成审计报告
    pub async fn generate_audit_report(
        &self,
        family_id: Uuid,
        start_date: DateTime<Utc>,
        end_date: DateTime<Utc>,
    ) -> Result<AuditReport, DomainError> {
        // Get activity summary
        let summary = sqlx::query!(
            r#"
            SELECT 
                action,
                resource_type,
                COUNT(*) as count,
                COUNT(CASE WHEN success = false THEN 1 END) as failed_count
            FROM audit_logs
            WHERE family_id = $1 
                AND created_at BETWEEN $2 AND $3
            GROUP BY action, resource_type
            ORDER BY count DESC
            "#,
            family_id,
            start_date,
            end_date
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut activity_summary = Vec::new();
        let mut total_events = 0;
        let mut total_failed = 0;
        
        for row in summary {
            let count = row.count.unwrap_or(0) as i32;
            let failed = row.failed_count.unwrap_or(0) as i32;
            
            total_events += count;
            total_failed += failed;
            
            activity_summary.push(ActivitySummary {
                action: row.action,
                resource_type: row.resource_type,
                count,
                failed_count: failed,
                success_rate: if count > 0 {
                    ((count - failed) as f64 / count as f64 * 100.0)
                } else {
                    0.0
                },
            });
        }
        
        // Get user activity
        let user_activity = sqlx::query!(
            r#"
            SELECT 
                u.email,
                COUNT(*) as actions_count
            FROM audit_logs al
            JOIN users u ON u.id = al.user_id
            WHERE al.family_id = $1 
                AND al.created_at BETWEEN $2 AND $3
            GROUP BY u.id, u.email
            ORDER BY actions_count DESC
            "#,
            family_id,
            start_date,
            end_date
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut user_stats = Vec::new();
        for row in user_activity {
            user_stats.push(UserActivity {
                user_email: row.email,
                actions_count: row.actions_count.unwrap_or(0) as i32,
            });
        }
        
        Ok(AuditReport {
            period_start: start_date,
            period_end: end_date,
            total_events,
            total_failed,
            overall_success_rate: if total_events > 0 {
                ((total_events - total_failed) as f64 / total_events as f64 * 100.0)
            } else {
                0.0
            },
            activity_summary,
            user_activity: user_stats,
            generated_at: Utc::now(),
        })
    }
}

// Entities

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct AuditLog {
    pub id: Uuid,
    pub family_id: Uuid,
    pub user_id: Uuid,
    pub action: String,
    pub resource_type: String,
    pub resource_id: Option<Uuid>,
    pub old_values: Option<serde_json::Value>,
    pub new_values: Option<serde_json::Value>,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub success: bool,
    pub error_message: Option<String>,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditEvent {
    pub family_id: Uuid,
    pub user_id: Uuid,
    pub action: String,
    pub resource_type: String,
    pub resource_id: Option<Uuid>,
    pub old_values: Option<serde_json::Value>,
    pub new_values: Option<serde_json::Value>,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub success: bool,
    pub error_message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum AuditAction {
    Create,
    Update,
    Delete,
    Login,
    Logout,
    Export,
    Import,
    Sync,
    Categorize,
    ApplyRule,
    BatchUpdate,
}

impl ToString for AuditAction {
    fn to_string(&self) -> String {
        match self {
            Self::Create => "create".to_string(),
            Self::Update => "update".to_string(),
            Self::Delete => "delete".to_string(),
            Self::Login => "login".to_string(),
            Self::Logout => "logout".to_string(),
            Self::Export => "export".to_string(),
            Self::Import => "import".to_string(),
            Self::Sync => "sync".to_string(),
            Self::Categorize => "categorize".to_string(),
            Self::ApplyRule => "apply_rule".to_string(),
            Self::BatchUpdate => "batch_update".to_string(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldChange {
    pub field: String,
    pub old_value: serde_json::Value,
    pub new_value: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BatchOperation {
    pub operation_type: String,
    pub affected_count: i32,
    pub details: serde_json::Value,
    pub ip_address: Option<String>,
    pub user_agent: Option<String>,
    pub success: bool,
    pub error_message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditFilters {
    pub user_id: Option<Uuid>,
    pub resource_type: Option<String>,
    pub action: Option<String>,
    pub start_date: Option<DateTime<Utc>>,
    pub end_date: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditReport {
    pub period_start: DateTime<Utc>,
    pub period_end: DateTime<Utc>,
    pub total_events: i32,
    pub total_failed: i32,
    pub overall_success_rate: f64,
    pub activity_summary: Vec<ActivitySummary>,
    pub user_activity: Vec<UserActivity>,
    pub generated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActivitySummary {
    pub action: String,
    pub resource_type: String,
    pub count: i32,
    pub failed_count: i32,
    pub success_rate: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserActivity {
    pub user_email: String,
    pub actions_count: i32,
}

// Audit macros for easy logging
#[macro_export]
macro_rules! audit_create {
    ($service:expr, $family_id:expr, $user_id:expr, $resource_type:expr, $resource_id:expr, $values:expr) => {
        $service.log_event(AuditEvent {
            family_id: $family_id,
            user_id: $user_id,
            action: "create".to_string(),
            resource_type: $resource_type.to_string(),
            resource_id: Some($resource_id),
            old_values: None,
            new_values: Some($values),
            ip_address: None,
            user_agent: None,
            success: true,
            error_message: None,
        }).await
    };
}

#[macro_export]
macro_rules! audit_update {
    ($service:expr, $family_id:expr, $user_id:expr, $resource_type:expr, $resource_id:expr, $old:expr, $new:expr) => {
        $service.log_event(AuditEvent {
            family_id: $family_id,
            user_id: $user_id,
            action: "update".to_string(),
            resource_type: $resource_type.to_string(),
            resource_id: Some($resource_id),
            old_values: Some($old),
            new_values: Some($new),
            ip_address: None,
            user_agent: None,
            success: true,
            error_message: None,
        }).await
    };
}

#[macro_export]
macro_rules! audit_delete {
    ($service:expr, $family_id:expr, $user_id:expr, $resource_type:expr, $resource_id:expr, $values:expr) => {
        $service.log_event(AuditEvent {
            family_id: $family_id,
            user_id: $user_id,
            action: "delete".to_string(),
            resource_type: $resource_type.to_string(),
            resource_id: Some($resource_id),
            old_values: Some($values),
            new_values: None,
            ip_address: None,
            user_agent: None,
            success: true,
            error_message: None,
        }).await
    };
}