//! Application services for Jive Core
//!
//! This module contains the application layer services that orchestrate business logic.

use serde::{Deserialize, Serialize};

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

// 应用层接口定义（Commands, Results, Service Traits）
pub mod commands;
pub mod results;
pub mod services;

// 导出所有应用服务
pub mod account_service;
#[cfg(feature = "app_experimental")]
pub mod analytics_service;
pub mod auth_service;
pub mod auth_service_enhanced;
pub mod budget_service;
pub mod category_service;
pub mod credit_card_service;
#[cfg(feature = "app_experimental")]
pub mod data_exchange_service;
pub mod export_service;
pub mod family_service;
pub mod import_service;
pub mod investment_service;
#[cfg(feature = "app_experimental")]
pub mod ledger_service;
pub mod mfa_service;
pub mod middleware;
pub mod multi_family_service;
pub mod notification_service;
pub mod payee_service;
pub mod quick_transaction_service;
pub mod report_service;
pub mod rule_service;
pub mod rules_engine;
pub mod scheduled_transaction_service;
pub mod sync_service;
pub mod tag_service;
pub mod transaction_service;
pub mod travel_service;
pub mod user_service;

pub use account_service::*;
pub use auth_service::*;
pub use budget_service::*;
pub use category_service::*;
pub use export_service::*;
pub use family_service::*;
pub use import_service::*;
#[cfg(feature = "app_experimental")]
pub use ledger_service::*;
pub use notification_service::*;
pub use payee_service::*;
pub use report_service::*;
pub use rule_service::*;
pub use scheduled_transaction_service::*;
pub use sync_service::*;
pub use tag_service::*;
pub use transaction_service::*;
pub use travel_service::*;
pub use user_service::*;

use crate::error::{JiveError, Result};

/// 分页请求参数
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct PaginationParams {
    pub page: u32,
    pub per_page: u32,
    pub offset: u32,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl PaginationParams {
    #[wasm_bindgen(constructor)]
    pub fn new(page: u32, per_page: u32) -> Self {
        let offset = (page.saturating_sub(1)) * per_page;
        Self {
            page,
            per_page,
            offset,
        }
    }

    #[wasm_bindgen(getter)]
    pub fn page(&self) -> u32 {
        self.page
    }

    #[wasm_bindgen(getter)]
    pub fn per_page(&self) -> u32 {
        self.per_page
    }

    #[wasm_bindgen(getter)]
    pub fn offset(&self) -> u32 {
        self.offset
    }
}

impl Default for PaginationParams {
    fn default() -> Self {
        Self::new(1, 20)
    }
}

/// 分页响应结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct PaginatedResult<T> {
    pub items: Vec<T>,
    pub total_count: u32,
    pub total_pages: u32,
    pub current_page: u32,
    pub per_page: u32,
    pub has_next: bool,
    pub has_prev: bool,
}

impl<T> PaginatedResult<T> {
    pub fn new(items: Vec<T>, total_count: u32, pagination: &PaginationParams) -> Self {
        let total_pages = (total_count as f64 / pagination.per_page as f64).ceil() as u32;
        let has_next = pagination.page < total_pages;
        let has_prev = pagination.page > 1;

        Self {
            items,
            total_count,
            total_pages,
            current_page: pagination.page,
            per_page: pagination.per_page,
            has_next,
            has_prev,
        }
    }
}

/// 排序参数
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct SortParams {
    pub field: String,
    pub direction: SortDirection,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum SortDirection {
    Asc,
    Desc,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl SortDirection {
    #[wasm_bindgen(getter)]
    pub fn as_string(&self) -> String {
        match self {
            SortDirection::Asc => "asc".to_string(),
            SortDirection::Desc => "desc".to_string(),
        }
    }

    #[wasm_bindgen]
    pub fn from_string(s: &str) -> Option<SortDirection> {
        match s {
            "asc" => Some(SortDirection::Asc),
            "desc" => Some(SortDirection::Desc),
            _ => None,
        }
    }
}

/// 过滤参数基础trait
pub trait FilterParams {
    fn apply_filters(&self) -> Vec<FilterCondition>;
}

/// 过滤条件
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FilterCondition {
    pub field: String,
    pub operator: FilterOperator,
    pub value: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum FilterOperator {
    Equals,
    NotEquals,
    GreaterThan,
    LessThan,
    GreaterThanOrEqual,
    LessThanOrEqual,
    Contains,
    StartsWith,
    EndsWith,
    In,
    NotIn,
    IsNull,
    IsNotNull,
}

/// 查询构建器
pub struct QueryBuilder {
    filters: Vec<FilterCondition>,
    sorts: Vec<SortParams>,
    pagination: Option<PaginationParams>,
}

impl QueryBuilder {
    pub fn new() -> Self {
        Self {
            filters: Vec::new(),
            sorts: Vec::new(),
            pagination: None,
        }
    }

    pub fn filter(mut self, condition: FilterCondition) -> Self {
        self.filters.push(condition);
        self
    }

    pub fn sort(mut self, sort: SortParams) -> Self {
        self.sorts.push(sort);
        self
    }

    pub fn paginate(mut self, pagination: PaginationParams) -> Self {
        self.pagination = Some(pagination);
        self
    }

    pub fn build(self) -> Query {
        Query {
            filters: self.filters,
            sorts: self.sorts,
            pagination: self.pagination.unwrap_or_default(),
        }
    }
}

/// 查询对象
#[derive(Debug, Clone)]
pub struct Query {
    pub filters: Vec<FilterCondition>,
    pub sorts: Vec<SortParams>,
    pub pagination: PaginationParams,
}

impl Default for QueryBuilder {
    fn default() -> Self {
        Self::new()
    }
}

/// 服务响应结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ServiceResponse<T> {
    pub success: bool,
    pub data: Option<T>,
    pub error: Option<String>,
    pub message: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl<T> ServiceResponse<T>
where
    T: Clone + Serialize,
{
    #[wasm_bindgen(getter)]
    pub fn success(&self) -> bool {
        self.success
    }

    #[wasm_bindgen(getter)]
    pub fn error(&self) -> Option<String> {
        self.error.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn message(&self) -> Option<String> {
        self.message.clone()
    }
}

impl<T> ServiceResponse<T> {
    pub fn success(data: T) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
            message: None,
        }
    }

    pub fn success_with_message(data: T, message: String) -> Self {
        Self {
            success: true,
            data: Some(data),
            error: None,
            message: Some(message),
        }
    }

    pub fn error(error: JiveError) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(error.to_string()),
            message: None,
        }
    }

    pub fn error_with_message(error: JiveError, message: String) -> Self {
        Self {
            success: false,
            data: None,
            error: Some(error.to_string()),
            message: Some(message),
        }
    }
}

impl<T> From<Result<T>> for ServiceResponse<T> {
    fn from(result: Result<T>) -> Self {
        match result {
            Ok(data) => Self::success(data),
            Err(error) => Self::error(error),
        }
    }
}

/// 批量操作结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BatchResult {
    pub total: u32,
    pub successful: u32,
    pub failed: u32,
    pub errors: Vec<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl BatchResult {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            total: 0,
            successful: 0,
            failed: 0,
            errors: Vec::new(),
        }
    }

    #[wasm_bindgen(getter)]
    pub fn total(&self) -> u32 {
        self.total
    }

    #[wasm_bindgen(getter)]
    pub fn successful(&self) -> u32 {
        self.successful
    }

    #[wasm_bindgen(getter)]
    pub fn failed(&self) -> u32 {
        self.failed
    }

    #[wasm_bindgen(getter)]
    pub fn errors(&self) -> Vec<String> {
        self.errors.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn success_rate(&self) -> f64 {
        if self.total == 0 {
            0.0
        } else {
            (self.successful as f64 / self.total as f64) * 100.0
        }
    }

    #[wasm_bindgen]
    pub fn add_success(&mut self) {
        self.total += 1;
        self.successful += 1;
    }

    #[wasm_bindgen]
    pub fn add_error(&mut self, error: String) {
        self.total += 1;
        self.failed += 1;
        self.errors.push(error);
    }
}

impl Default for BatchResult {
    fn default() -> Self {
        Self::new()
    }
}

/// 服务上下文 - 增强以支持 Family 多用户协作
#[derive(Debug, Clone)]
pub struct ServiceContext {
    pub user_id: String,
    pub family_id: String, // 新增：当前 Family
    pub current_ledger_id: Option<String>,
    pub permissions: Vec<crate::domain::Permission>, // 新增：用户权限
    pub request_id: Option<String>,
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub ip_address: Option<String>, // 新增：用于审计
    pub user_agent: Option<String>, // 新增：用于审计
}

impl ServiceContext {
    pub fn new(user_id: String, family_id: String) -> Self {
        Self {
            user_id,
            family_id,
            current_ledger_id: None,
            permissions: Vec::new(),
            request_id: None,
            timestamp: chrono::Utc::now(),
            ip_address: None,
            user_agent: None,
        }
    }

    pub fn with_ledger(mut self, ledger_id: String) -> Self {
        self.current_ledger_id = Some(ledger_id);
        self
    }

    pub fn with_request_id(mut self, request_id: String) -> Self {
        self.request_id = Some(request_id);
        self
    }

    pub fn with_permissions(mut self, permissions: Vec<crate::domain::Permission>) -> Self {
        self.permissions = permissions;
        self
    }

    pub fn with_client_info(mut self, ip: Option<String>, agent: Option<String>) -> Self {
        self.ip_address = ip;
        self.user_agent = agent;
        self
    }

    /// 检查权限
    pub fn has_permission(&self, permission: crate::domain::Permission) -> bool {
        self.permissions.contains(&permission)
    }

    /// 检查权限（通过字符串）
    pub fn has_permission_str(&self, permission_str: &str) -> bool {
        use crate::domain::Permission;

        // 将字符串转换为 Permission 枚举
        let permission = match permission_str {
            "view_transactions" => Permission::ViewTransactions,
            "create_transactions" => Permission::CreateTransactions,
            "edit_transactions" => Permission::EditTransactions,
            "delete_transactions" => Permission::DeleteTransactions,
            "manage_rules" => Permission::ManageFamily, // 暂时使用 ManageFamily 权限
            _ => return false,
        };

        self.has_permission(permission)
    }

    /// 要求权限（无权限时抛出错误）
    pub fn require_permission(
        &self,
        permission: crate::domain::Permission,
    ) -> crate::error::Result<()> {
        use crate::error::JiveError;
        if !self.has_permission(permission) {
            return Err(JiveError::Unauthorized(format!(
                "Missing permission: {:?}",
                permission
            )));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_pagination_params() {
        let params = PaginationParams::new(2, 10);
        assert_eq!(params.page, 2);
        assert_eq!(params.per_page, 10);
        assert_eq!(params.offset, 10);
    }

    #[test]
    fn test_paginated_result() {
        let items = vec![1, 2, 3, 4, 5];
        let pagination = PaginationParams::new(1, 3);
        let result = PaginatedResult::new(items, 10, &pagination);

        assert_eq!(result.total_count, 10);
        assert_eq!(result.total_pages, 4);
        assert_eq!(result.current_page, 1);
        assert!(result.has_next);
        assert!(!result.has_prev);
    }

    #[test]
    fn test_service_response() {
        let success_response = ServiceResponse::success("test data".to_string());
        assert!(success_response.success);
        assert_eq!(success_response.data, Some("test data".to_string()));

        let error_response: ServiceResponse<String> =
            ServiceResponse::error(JiveError::ValidationError {
                message: "test error".to_string(),
            });
        assert!(!error_response.success);
        assert!(error_response.error.is_some());
    }

    #[test]
    fn test_batch_result() {
        let mut batch = BatchResult::new();
        batch.add_success();
        batch.add_success();
        batch.add_error("Test error".to_string());

        assert_eq!(batch.total, 3);
        assert_eq!(batch.successful, 2);
        assert_eq!(batch.failed, 1);
        assert_eq!(batch.success_rate(), 66.66666666666667);
    }

    #[test]
    fn test_service_context() {
        use crate::domain::Permission;

        let context = ServiceContext::new("user-123".to_string(), "family-456".to_string())
            .with_ledger("ledger-789".to_string())
            .with_request_id("req-012".to_string())
            .with_permissions(vec![
                Permission::ViewTransactions,
                Permission::CreateTransactions,
            ]);

        assert_eq!(context.user_id, "user-123");
        assert_eq!(context.family_id, "family-456");
        assert_eq!(context.current_ledger_id, Some("ledger-789".to_string()));
        assert_eq!(context.request_id, Some("req-012".to_string()));
        assert!(context.has_permission(Permission::ViewTransactions));
        assert!(!context.has_permission(Permission::DeleteTransactions));
    }
}
