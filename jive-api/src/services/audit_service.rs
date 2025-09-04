use chrono::{DateTime, Utc};
use sqlx::PgPool;
use uuid::Uuid;

use crate::models::audit::{AuditAction, AuditLog, AuditLogFilter, CreateAuditLogRequest};

use super::ServiceError;

pub struct AuditService {
    pool: PgPool,
}

impl AuditService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
    
    pub async fn log_action(
        &self,
        family_id: Uuid,
        user_id: Uuid,
        request: CreateAuditLogRequest,
        ip_address: Option<String>,
        user_agent: Option<String>,
    ) -> Result<(), ServiceError> {
        let log = AuditLog::new(
            family_id,
            user_id,
            request.action,
            request.entity_type,
            request.entity_id,
        )
        .with_values(request.old_values, request.new_values)
        .with_request_info(ip_address, user_agent);
        
        sqlx::query(
            r#"
            INSERT INTO family_audit_logs (
                id, family_id, user_id, action, entity_type, entity_id,
                old_values, new_values, ip_address, user_agent, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            "#
        )
        .bind(log.id)
        .bind(log.family_id)
        .bind(log.user_id)
        .bind(log.action.to_string())
        .bind(log.entity_type)
        .bind(log.entity_id)
        .bind(log.old_values)
        .bind(log.new_values)
        .bind(log.ip_address)
        .bind(log.user_agent)
        .bind(log.created_at)
        .execute(&self.pool)
        .await?;
        
        Ok(())
    }
    
    pub async fn get_audit_logs(
        &self,
        filter: AuditLogFilter,
    ) -> Result<Vec<AuditLog>, ServiceError> {
        let mut query = String::from(
            "SELECT * FROM family_audit_logs WHERE 1=1"
        );
        let mut binds = vec![];
        let mut bind_idx = 1;
        
        if let Some(family_id) = filter.family_id {
            query.push_str(&format!(" AND family_id = ${}", bind_idx));
            binds.push(family_id.to_string());
            bind_idx += 1;
        }
        
        if let Some(user_id) = filter.user_id {
            query.push_str(&format!(" AND user_id = ${}", bind_idx));
            binds.push(user_id.to_string());
            bind_idx += 1;
        }
        
        if let Some(action) = filter.action {
            query.push_str(&format!(" AND action = ${}", bind_idx));
            binds.push(action.to_string());
            bind_idx += 1;
        }
        
        if let Some(entity_type) = filter.entity_type {
            query.push_str(&format!(" AND entity_type = ${}", bind_idx));
            binds.push(entity_type);
            bind_idx += 1;
        }
        
        if let Some(from_date) = filter.from_date {
            query.push_str(&format!(" AND created_at >= ${}", bind_idx));
            binds.push(from_date.to_rfc3339());
            bind_idx += 1;
        }
        
        if let Some(to_date) = filter.to_date {
            query.push_str(&format!(" AND created_at <= ${}", bind_idx));
            binds.push(to_date.to_rfc3339());
            bind_idx += 1;
        }
        
        query.push_str(" ORDER BY created_at DESC");
        
        if let Some(limit) = filter.limit {
            query.push_str(&format!(" LIMIT {}", limit));
        }
        
        if let Some(offset) = filter.offset {
            query.push_str(&format!(" OFFSET {}", offset));
        }
        
        // Execute dynamic query
        let mut query_builder = sqlx::query_as::<_, AuditLog>(&query);
        for bind in binds {
            query_builder = query_builder.bind(bind);
        }
        
        let logs = query_builder.fetch_all(&self.pool).await?;
        
        Ok(logs)
    }
    
    pub async fn log_family_created(
        &self,
        family_id: Uuid,
        user_id: Uuid,
        family_name: &str,
    ) -> Result<(), ServiceError> {
        let log = AuditLog::log_family_created(family_id, user_id, family_name);
        
        self.insert_log(log).await
    }
    
    pub async fn log_member_added(
        &self,
        family_id: Uuid,
        actor_id: Uuid,
        member_id: Uuid,
        role: &str,
    ) -> Result<(), ServiceError> {
        let log = AuditLog::log_member_added(family_id, actor_id, member_id, role);
        
        self.insert_log(log).await
    }
    
    pub async fn log_member_removed(
        &self,
        family_id: Uuid,
        actor_id: Uuid,
        member_id: Uuid,
    ) -> Result<(), ServiceError> {
        let log = AuditLog::new(
            family_id,
            actor_id,
            AuditAction::MemberRemoved,
            "member".to_string(),
            Some(member_id),
        );
        
        self.insert_log(log).await
    }
    
    pub async fn log_role_changed(
        &self,
        family_id: Uuid,
        actor_id: Uuid,
        member_id: Uuid,
        old_role: &str,
        new_role: &str,
    ) -> Result<(), ServiceError> {
        let log = AuditLog::log_role_changed(
            family_id,
            actor_id,
            member_id,
            old_role,
            new_role,
        );
        
        self.insert_log(log).await
    }
    
    pub async fn log_invitation_sent(
        &self,
        family_id: Uuid,
        inviter_id: Uuid,
        invitation_id: Uuid,
        invitee_email: &str,
    ) -> Result<(), ServiceError> {
        let log = AuditLog::log_invitation_sent(
            family_id,
            inviter_id,
            invitation_id,
            invitee_email,
        );
        
        self.insert_log(log).await
    }
    
    async fn insert_log(&self, log: AuditLog) -> Result<(), ServiceError> {
        sqlx::query(
            r#"
            INSERT INTO family_audit_logs (
                id, family_id, user_id, action, entity_type, entity_id,
                old_values, new_values, ip_address, user_agent, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            "#
        )
        .bind(log.id)
        .bind(log.family_id)
        .bind(log.user_id)
        .bind(log.action.to_string())
        .bind(log.entity_type)
        .bind(log.entity_id)
        .bind(log.old_values)
        .bind(log.new_values)
        .bind(log.ip_address)
        .bind(log.user_agent)
        .bind(log.created_at)
        .execute(&self.pool)
        .await?;
        
        Ok(())
    }
    
    pub async fn export_audit_report(
        &self,
        family_id: Uuid,
        from_date: DateTime<Utc>,
        to_date: DateTime<Utc>,
    ) -> Result<String, ServiceError> {
        let logs = self.get_audit_logs(AuditLogFilter {
            family_id: Some(family_id),
            user_id: None,
            action: None,
            entity_type: None,
            from_date: Some(from_date),
            to_date: Some(to_date),
            limit: None,
            offset: None,
        }).await?;
        
        // Generate CSV report
        let mut csv = String::from("时间,用户,操作,实体类型,实体ID,旧值,新值,IP地址\n");
        
        for log in logs {
            csv.push_str(&format!(
                "{},{},{},{},{},{},{},{}\n",
                log.created_at.format("%Y-%m-%d %H:%M:%S"),
                log.user_id,
                log.action.to_string(),
                log.entity_type,
                log.entity_id.map(|id| id.to_string()).unwrap_or_default(),
                log.old_values.map(|v| v.to_string()).unwrap_or_default(),
                log.new_values.map(|v| v.to_string()).unwrap_or_default(),
                log.ip_address.unwrap_or_default(),
            ));
        }
        
        Ok(csv)
    }
}