//! Ledger service - 账本管理服务
//!
//! 基于 Maybe 的多账本功能转换而来，包括账本CRUD、切换、权限管理等功能

use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use super::{BatchResult, PaginationParams, ServiceContext, ServiceResponse};
use crate::domain::{Ledger, LedgerDisplaySettings, LedgerStatus};
use crate::error::{JiveError, Result};

/// 账本创建请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CreateLedgerRequest {
    name: String,
    description: Option<String>,
    currency: String,
    timezone: Option<String>,
    display_settings: Option<LedgerDisplaySettings>,
    is_shared: bool,
    icon: Option<String>,
    color: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CreateLedgerRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(name: String, currency: String) -> Self {
        Self {
            name,
            description: None,
            currency,
            timezone: None,
            display_settings: None,
            is_shared: false,
            icon: None,
            color: None,
        }
    }

    // Getters
    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String {
        self.name.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn currency(&self) -> String {
        self.currency.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn is_shared(&self) -> bool {
        self.is_shared
    }

    // Setters
    #[wasm_bindgen(setter)]
    pub fn set_description(&mut self, description: Option<String>) {
        self.description = description;
    }

    #[wasm_bindgen(setter)]
    pub fn set_timezone(&mut self, timezone: Option<String>) {
        self.timezone = timezone;
    }

    #[wasm_bindgen(setter)]
    pub fn set_is_shared(&mut self, is_shared: bool) {
        self.is_shared = is_shared;
    }

    #[wasm_bindgen(setter)]
    pub fn set_icon(&mut self, icon: Option<String>) {
        self.icon = icon;
    }

    #[wasm_bindgen(setter)]
    pub fn set_color(&mut self, color: Option<String>) {
        self.color = color;
    }

    #[wasm_bindgen]
    pub fn set_display_settings(&mut self, settings: LedgerDisplaySettings) {
        self.display_settings = Some(settings);
    }
}

/// 账本更新请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UpdateLedgerRequest {
    name: Option<String>,
    description: Option<String>,
    timezone: Option<String>,
    display_settings: Option<LedgerDisplaySettings>,
    icon: Option<String>,
    color: Option<String>,
    status: Option<LedgerStatus>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl UpdateLedgerRequest {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            name: None,
            description: None,
            timezone: None,
            display_settings: None,
            icon: None,
            color: None,
            status: None,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_name(&mut self, name: Option<String>) {
        self.name = name;
    }

    #[wasm_bindgen(setter)]
    pub fn set_description(&mut self, description: Option<String>) {
        self.description = description;
    }

    #[wasm_bindgen(setter)]
    pub fn set_status(&mut self, status: Option<LedgerStatus>) {
        self.status = status;
    }

    #[wasm_bindgen]
    pub fn set_display_settings(&mut self, settings: LedgerDisplaySettings) {
        self.display_settings = Some(settings);
    }
}

/// 账本权限
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum LedgerPermission {
    Owner,  // 所有者
    Admin,  // 管理员
    Editor, // 编辑者
    Viewer, // 查看者
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl LedgerPermission {
    #[wasm_bindgen(getter)]
    pub fn as_string(&self) -> String {
        match self {
            LedgerPermission::Owner => "owner".to_string(),
            LedgerPermission::Admin => "admin".to_string(),
            LedgerPermission::Editor => "editor".to_string(),
            LedgerPermission::Viewer => "viewer".to_string(),
        }
    }

    #[wasm_bindgen]
    pub fn from_string(s: &str) -> Option<LedgerPermission> {
        match s {
            "owner" => Some(LedgerPermission::Owner),
            "admin" => Some(LedgerPermission::Admin),
            "editor" => Some(LedgerPermission::Editor),
            "viewer" => Some(LedgerPermission::Viewer),
            _ => None,
        }
    }

    /// 检查是否有权限执行操作
    #[wasm_bindgen]
    pub fn can_edit(&self) -> bool {
        matches!(
            self,
            LedgerPermission::Owner | LedgerPermission::Admin | LedgerPermission::Editor
        )
    }

    #[wasm_bindgen]
    pub fn can_admin(&self) -> bool {
        matches!(self, LedgerPermission::Owner | LedgerPermission::Admin)
    }

    #[wasm_bindgen]
    pub fn can_delete(&self) -> bool {
        matches!(self, LedgerPermission::Owner)
    }
}

/// 账本成员
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct LedgerMember {
    user_id: String,
    user_name: String,
    user_email: String,
    permission: LedgerPermission,
    joined_at: DateTime<Utc>,
    invited_by: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl LedgerMember {
    #[wasm_bindgen(getter)]
    pub fn user_id(&self) -> String {
        self.user_id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn user_name(&self) -> String {
        self.user_name.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn user_email(&self) -> String {
        self.user_email.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn permission(&self) -> LedgerPermission {
        self.permission.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn joined_at(&self) -> String {
        self.joined_at.to_rfc3339()
    }
}

/// 账本邀请请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct InviteLedgerMemberRequest {
    email: String,
    permission: LedgerPermission,
    message: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl InviteLedgerMemberRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(email: String, permission: LedgerPermission) -> Self {
        Self {
            email,
            permission,
            message: None,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_message(&mut self, message: Option<String>) {
        self.message = message;
    }
}

/// 账本筛选器
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct LedgerFilter {
    status: Option<LedgerStatus>,
    is_shared: Option<bool>,
    currency: Option<String>,
    search_query: Option<String>,
    my_ledgers_only: bool,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl LedgerFilter {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            status: None,
            is_shared: None,
            currency: None,
            search_query: None,
            my_ledgers_only: false,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_status(&mut self, status: Option<LedgerStatus>) {
        self.status = status;
    }

    #[wasm_bindgen(setter)]
    pub fn set_is_shared(&mut self, is_shared: Option<bool>) {
        self.is_shared = is_shared;
    }

    #[wasm_bindgen(setter)]
    pub fn set_my_ledgers_only(&mut self, my_only: bool) {
        self.my_ledgers_only = my_only;
    }

    #[wasm_bindgen(setter)]
    pub fn set_search_query(&mut self, query: Option<String>) {
        self.search_query = query;
    }
}

impl Default for LedgerFilter {
    fn default() -> Self {
        Self::new()
    }
}

/// 账本统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct LedgerStats {
    total_ledgers: u32,
    my_ledgers: u32,
    shared_ledgers: u32,
    total_accounts: u32,
    total_transactions: u32,
    supported_currencies: Vec<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl LedgerStats {
    #[wasm_bindgen(getter)]
    pub fn total_ledgers(&self) -> u32 {
        self.total_ledgers
    }

    #[wasm_bindgen(getter)]
    pub fn my_ledgers(&self) -> u32 {
        self.my_ledgers
    }

    #[wasm_bindgen(getter)]
    pub fn shared_ledgers(&self) -> u32 {
        self.shared_ledgers
    }

    #[wasm_bindgen(getter)]
    pub fn total_accounts(&self) -> u32 {
        self.total_accounts
    }

    #[wasm_bindgen(getter)]
    pub fn total_transactions(&self) -> u32 {
        self.total_transactions
    }

    #[wasm_bindgen(getter)]
    pub fn supported_currencies(&self) -> Vec<String> {
        self.supported_currencies.clone()
    }
}

/// 账本服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct LedgerService {
    // 在实际实现中，这里会包含数据库连接或仓储接口
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl LedgerService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {}
    }

    /// 创建账本
    #[wasm_bindgen]
    pub async fn create_ledger(
        &self,
        request: CreateLedgerRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Ledger> {
        let result = self._create_ledger(request, context).await;
        result.into()
    }

    /// 更新账本
    #[wasm_bindgen]
    pub async fn update_ledger(
        &self,
        ledger_id: String,
        request: UpdateLedgerRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Ledger> {
        let result = self._update_ledger(ledger_id, request, context).await;
        result.into()
    }

    /// 获取账本详情
    #[wasm_bindgen]
    pub async fn get_ledger(
        &self,
        ledger_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Ledger> {
        let result = self._get_ledger(ledger_id, context).await;
        result.into()
    }

    /// 删除账本
    #[wasm_bindgen]
    pub async fn delete_ledger(
        &self,
        ledger_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._delete_ledger(ledger_id, context).await;
        result.into()
    }

    /// 搜索账本
    #[wasm_bindgen]
    pub async fn search_ledgers(
        &self,
        filter: LedgerFilter,
        pagination: PaginationParams,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Ledger>> {
        let result = self._search_ledgers(filter, pagination, context).await;
        result.into()
    }

    /// 切换当前账本
    #[wasm_bindgen]
    pub async fn switch_ledger(
        &self,
        ledger_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Ledger> {
        let result = self._switch_ledger(ledger_id, context).await;
        result.into()
    }

    /// 获取当前账本
    #[wasm_bindgen]
    pub async fn get_current_ledger(&self, context: ServiceContext) -> ServiceResponse<Ledger> {
        let result = self._get_current_ledger(context).await;
        result.into()
    }

    /// 获取用户的所有账本
    #[wasm_bindgen]
    pub async fn get_user_ledgers(&self, context: ServiceContext) -> ServiceResponse<Vec<Ledger>> {
        let result = self._get_user_ledgers(context).await;
        result.into()
    }

    /// 邀请成员加入账本
    #[wasm_bindgen]
    pub async fn invite_member(
        &self,
        ledger_id: String,
        request: InviteLedgerMemberRequest,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._invite_member(ledger_id, request, context).await;
        result.into()
    }

    /// 获取账本成员列表
    #[wasm_bindgen]
    pub async fn get_ledger_members(
        &self,
        ledger_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<LedgerMember>> {
        let result = self._get_ledger_members(ledger_id, context).await;
        result.into()
    }

    /// 更新成员权限
    #[wasm_bindgen]
    pub async fn update_member_permission(
        &self,
        ledger_id: String,
        user_id: String,
        permission: LedgerPermission,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self
            ._update_member_permission(ledger_id, user_id, permission, context)
            .await;
        result.into()
    }

    /// 移除成员
    #[wasm_bindgen]
    pub async fn remove_member(
        &self,
        ledger_id: String,
        user_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._remove_member(ledger_id, user_id, context).await;
        result.into()
    }

    /// 离开账本
    #[wasm_bindgen]
    pub async fn leave_ledger(
        &self,
        ledger_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._leave_ledger(ledger_id, context).await;
        result.into()
    }

    /// 复制账本
    #[wasm_bindgen]
    pub async fn duplicate_ledger(
        &self,
        ledger_id: String,
        new_name: String,
        copy_transactions: bool,
        context: ServiceContext,
    ) -> ServiceResponse<Ledger> {
        let result = self
            ._duplicate_ledger(ledger_id, new_name, copy_transactions, context)
            .await;
        result.into()
    }

    /// 获取账本统计信息
    #[wasm_bindgen]
    pub async fn get_ledger_stats(&self, context: ServiceContext) -> ServiceResponse<LedgerStats> {
        let result = self._get_ledger_stats(context).await;
        result.into()
    }

    /// 检查用户权限
    #[wasm_bindgen]
    pub async fn check_permission(
        &self,
        ledger_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<LedgerPermission> {
        let result = self._check_permission(ledger_id, context).await;
        result.into()
    }
}

impl LedgerService {
    /// 创建账本的内部实现
    async fn _create_ledger(
        &self,
        request: CreateLedgerRequest,
        context: ServiceContext,
    ) -> Result<Ledger> {
        // 验证输入
        if request.name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Ledger name is required".to_string(),
            });
        }

        // 验证货币代码
        crate::utils::Validator::validate_currency_code(&request.currency)?;

        // 创建账本
        let mut ledger = Ledger::builder()
            .name(request.name)
            .currency(request.currency)
            .owner_id(context.user_id.clone())
            .is_shared(request.is_shared)
            .build()?;

        // 设置可选字段
        if let Some(description) = request.description {
            ledger.set_description(Some(description));
        }

        if let Some(timezone) = request.timezone {
            ledger.set_timezone(Some(timezone));
        }

        if let Some(display_settings) = request.display_settings {
            ledger.set_display_settings(display_settings);
        }

        if let Some(icon) = request.icon {
            ledger.set_icon(Some(icon));
        }

        if let Some(color) = request.color {
            ledger.set_color(Some(color));
        }

        // 在实际实现中，这里会保存到数据库
        // let saved_ledger = repository.save(ledger).await?;
        //
        // 为创建者添加所有者权限
        // permission_repository.create(LedgerPermission {
        //     ledger_id: saved_ledger.id(),
        //     user_id: context.user_id,
        //     permission: LedgerPermission::Owner,
        // }).await?;

        Ok(ledger)
    }

    /// 更新账本的内部实现
    async fn _update_ledger(
        &self,
        ledger_id: String,
        request: UpdateLedgerRequest,
        context: ServiceContext,
    ) -> Result<Ledger> {
        // 检查权限
        let permission = self
            ._check_permission(ledger_id.clone(), context.clone())
            .await?;
        if !permission.can_edit() {
            return Err(JiveError::PermissionDenied {
                message: "No permission to edit this ledger".to_string(),
            });
        }

        // 获取现有账本
        let mut ledger = self._get_ledger(ledger_id, context).await?;

        // 应用更新
        if let Some(name) = request.name {
            ledger.set_name(name)?;
        }

        if let Some(description) = request.description {
            ledger.set_description(Some(description));
        }

        if let Some(timezone) = request.timezone {
            ledger.set_timezone(Some(timezone));
        }

        if let Some(display_settings) = request.display_settings {
            ledger.set_display_settings(display_settings);
        }

        if let Some(icon) = request.icon {
            ledger.set_icon(Some(icon));
        }

        if let Some(color) = request.color {
            ledger.set_color(Some(color));
        }

        if let Some(status) = request.status {
            ledger.set_status(status);
        }

        // 在实际实现中，这里会保存到数据库
        // let updated_ledger = repository.save(ledger).await?;

        Ok(ledger)
    }

    /// 获取账本的内部实现
    async fn _get_ledger(&self, ledger_id: String, context: ServiceContext) -> Result<Ledger> {
        // 检查权限
        let _permission = self._check_permission(ledger_id.clone(), context).await?;

        // 在实际实现中，从数据库获取账本
        if ledger_id.is_empty() {
            return Err(JiveError::LedgerNotFound { id: ledger_id });
        }

        // 模拟账本获取
        let ledger = Ledger::new(
            "Test Ledger".to_string(),
            "USD".to_string(),
            "user-123".to_string(),
        )?;

        Ok(ledger)
    }

    /// 删除账本的内部实现
    async fn _delete_ledger(&self, ledger_id: String, context: ServiceContext) -> Result<bool> {
        // 检查权限
        let permission = self
            ._check_permission(ledger_id.clone(), context.clone())
            .await?;
        if !permission.can_delete() {
            return Err(JiveError::PermissionDenied {
                message: "Only owner can delete ledger".to_string(),
            });
        }

        // 检查是否有账户和交易
        // let account_count = account_repository.count_by_ledger_id(&ledger_id).await?;
        // let transaction_count = transaction_repository.count_by_ledger_id(&ledger_id).await?;
        //
        // if account_count > 0 || transaction_count > 0 {
        //     return Err(JiveError::ValidationError {
        //         message: "Cannot delete ledger with accounts or transactions".to_string(),
        //     });
        // }

        // 在实际实现中，执行软删除
        // let mut ledger = self._get_ledger(ledger_id, context).await?;
        // ledger.soft_delete();
        // repository.save(ledger).await?;

        Ok(true)
    }

    /// 搜索账本的内部实现
    async fn _search_ledgers(
        &self,
        filter: LedgerFilter,
        _pagination: PaginationParams,
        context: ServiceContext,
    ) -> Result<Vec<Ledger>> {
        // 在实际实现中，构建查询并执行
        // 这里只是模拟实现
        let mut ledgers = Vec::new();

        // 模拟一些账本数据
        for i in 1..=3 {
            let ledger = Ledger::new(
                format!("Ledger {}", i),
                "USD".to_string(),
                context.user_id.clone(),
            )?;
            ledgers.push(ledger);
        }

        // 应用过滤器
        if filter.my_ledgers_only {
            // 只返回用户拥有的账本
        }

        if let Some(_status) = filter.status {
            // 按状态过滤
        }

        if let Some(_is_shared) = filter.is_shared {
            // 按共享状态过滤
        }

        if let Some(_currency) = filter.currency {
            // 按货币过滤
        }

        if let Some(_search_query) = filter.search_query {
            // 按搜索查询过滤
        }

        Ok(ledgers)
    }

    /// 切换账本的内部实现
    async fn _switch_ledger(&self, ledger_id: String, context: ServiceContext) -> Result<Ledger> {
        // 检查权限
        let _permission = self
            ._check_permission(ledger_id.clone(), context.clone())
            .await?;

        // 获取账本
        let ledger = self._get_ledger(ledger_id.clone(), context.clone()).await?;

        // 在实际实现中，更新用户当前账本设置
        // user_settings_repository.update_current_ledger(context.user_id, ledger_id).await?;

        Ok(ledger)
    }

    /// 获取当前账本的内部实现
    async fn _get_current_ledger(&self, context: ServiceContext) -> Result<Ledger> {
        // 在实际实现中，从用户设置获取当前账本ID
        // let current_ledger_id = user_settings_repository
        //     .get_current_ledger_id(context.user_id).await?;

        let current_ledger_id = context
            .current_ledger_id
            .unwrap_or_else(|| "default-ledger".to_string());

        self._get_ledger(current_ledger_id, context).await
    }

    /// 获取用户账本的内部实现
    async fn _get_user_ledgers(&self, context: ServiceContext) -> Result<Vec<Ledger>> {
        let filter = LedgerFilter {
            my_ledgers_only: true,
            ..Default::default()
        };

        self._search_ledgers(filter, PaginationParams::new(1, 100), context)
            .await
    }

    /// 邀请成员的内部实现
    async fn _invite_member(
        &self,
        ledger_id: String,
        request: InviteLedgerMemberRequest,
        context: ServiceContext,
    ) -> Result<bool> {
        // 检查权限
        let permission = self._check_permission(ledger_id.clone(), context).await?;
        if !permission.can_admin() {
            return Err(JiveError::PermissionDenied {
                message: "No permission to invite members".to_string(),
            });
        }

        // 验证邮箱格式
        crate::utils::Validator::validate_email(&request.email)?;

        // 在实际实现中，发送邀请邮件
        // invitation_service.send_invitation(InvitationRequest {
        //     ledger_id,
        //     email: request.email,
        //     permission: request.permission,
        //     message: request.message,
        //     invited_by: context.user_id,
        // }).await?;

        Ok(true)
    }

    /// 获取成员列表的内部实现
    async fn _get_ledger_members(
        &self,
        ledger_id: String,
        context: ServiceContext,
    ) -> Result<Vec<LedgerMember>> {
        // 检查权限
        let _permission = self._check_permission(ledger_id.clone(), context).await?;

        // 在实际实现中，从数据库获取成员列表
        let members = vec![
            LedgerMember {
                user_id: "user-1".to_string(),
                user_name: "Alice".to_string(),
                user_email: "alice@example.com".to_string(),
                permission: LedgerPermission::Owner,
                joined_at: Utc::now(),
                invited_by: None,
            },
            LedgerMember {
                user_id: "user-2".to_string(),
                user_name: "Bob".to_string(),
                user_email: "bob@example.com".to_string(),
                permission: LedgerPermission::Editor,
                joined_at: Utc::now(),
                invited_by: Some("user-1".to_string()),
            },
        ];

        Ok(members)
    }

    /// 更新成员权限的内部实现
    async fn _update_member_permission(
        &self,
        ledger_id: String,
        user_id: String,
        permission: LedgerPermission,
        context: ServiceContext,
    ) -> Result<bool> {
        // 检查权限
        let current_permission = self
            ._check_permission(ledger_id.clone(), context.clone())
            .await?;
        if !current_permission.can_admin() {
            return Err(JiveError::PermissionDenied {
                message: "No permission to update member permissions".to_string(),
            });
        }

        // 不能修改自己的权限
        if user_id == context.user_id {
            return Err(JiveError::ValidationError {
                message: "Cannot update your own permission".to_string(),
            });
        }

        // 在实际实现中，更新数据库中的权限
        // permission_repository.update_permission(ledger_id, user_id, permission).await?;

        Ok(true)
    }

    /// 移除成员的内部实现
    async fn _remove_member(
        &self,
        ledger_id: String,
        user_id: String,
        context: ServiceContext,
    ) -> Result<bool> {
        // 检查权限
        let permission = self
            ._check_permission(ledger_id.clone(), context.clone())
            .await?;
        if !permission.can_admin() {
            return Err(JiveError::PermissionDenied {
                message: "No permission to remove members".to_string(),
            });
        }

        // 不能移除自己
        if user_id == context.user_id {
            return Err(JiveError::ValidationError {
                message: "Cannot remove yourself".to_string(),
            });
        }

        // 在实际实现中，从数据库移除权限记录
        // permission_repository.remove_permission(ledger_id, user_id).await?;

        Ok(true)
    }

    /// 离开账本的内部实现
    async fn _leave_ledger(&self, ledger_id: String, context: ServiceContext) -> Result<bool> {
        // 检查权限
        let permission = self
            ._check_permission(ledger_id.clone(), context.clone())
            .await?;

        // 所有者不能离开自己的账本
        if matches!(permission, LedgerPermission::Owner) {
            return Err(JiveError::ValidationError {
                message: "Owner cannot leave their own ledger".to_string(),
            });
        }

        // 在实际实现中，移除用户权限
        // permission_repository.remove_permission(ledger_id, context.user_id).await?;

        Ok(true)
    }

    /// 复制账本的内部实现
    async fn _duplicate_ledger(
        &self,
        ledger_id: String,
        new_name: String,
        _copy_transactions: bool,
        context: ServiceContext,
    ) -> Result<Ledger> {
        // 检查权限
        let _permission = self
            ._check_permission(ledger_id.clone(), context.clone())
            .await?;

        // 获取原账本
        let original_ledger = self._get_ledger(ledger_id, context.clone()).await?;

        // 创建新账本
        let request = CreateLedgerRequest {
            name: new_name,
            description: original_ledger.description(),
            currency: original_ledger.currency(),
            timezone: original_ledger.timezone(),
            display_settings: Some(original_ledger.display_settings()),
            is_shared: false, // 复制的账本默认不共享
            icon: original_ledger.icon(),
            color: original_ledger.color(),
        };

        let new_ledger = self._create_ledger(request, context).await?;

        // 在实际实现中，可以选择复制账户和交易
        // if copy_transactions {
        //     account_service.copy_accounts_from_ledger(original_ledger.id(), new_ledger.id()).await?;
        //     transaction_service.copy_transactions_from_ledger(original_ledger.id(), new_ledger.id()).await?;
        // }

        Ok(new_ledger)
    }

    /// 获取统计信息的内部实现
    async fn _get_ledger_stats(&self, _context: ServiceContext) -> Result<LedgerStats> {
        // 在实际实现中，从数据库聚合统计数据
        let stats = LedgerStats {
            total_ledgers: 5,
            my_ledgers: 3,
            shared_ledgers: 2,
            total_accounts: 25,
            total_transactions: 150,
            supported_currencies: vec![
                "USD".to_string(),
                "EUR".to_string(),
                "CNY".to_string(),
                "JPY".to_string(),
            ],
        };

        Ok(stats)
    }

    /// 检查权限的内部实现
    async fn _check_permission(
        &self,
        ledger_id: String,
        context: ServiceContext,
    ) -> Result<LedgerPermission> {
        // 在实际实现中，从数据库查询用户权限
        // let permission = permission_repository
        //     .get_user_permission(ledger_id, context.user_id).await?;

        // 模拟权限检查
        if ledger_id.is_empty() {
            return Err(JiveError::LedgerNotFound { id: ledger_id });
        }

        // 默认返回所有者权限（在实际实现中会从数据库查询）
        Ok(LedgerPermission::Owner)
    }
}

impl Default for LedgerService {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_ledger() {
        let service = LedgerService::new();
        let context = ServiceContext::new("user-123".to_string());

        let request = CreateLedgerRequest::new("Test Ledger".to_string(), "USD".to_string());

        let result = service._create_ledger(request, context).await;
        assert!(result.is_ok());

        let ledger = result.unwrap();
        assert_eq!(ledger.name(), "Test Ledger");
        assert_eq!(ledger.currency(), "USD");
    }

    #[tokio::test]
    async fn test_switch_ledger() {
        let service = LedgerService::new();
        let context = ServiceContext::new("user-123".to_string());

        let result = service
            ._switch_ledger("ledger-456".to_string(), context)
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_ledger_validation() {
        let service = LedgerService::new();
        let context = ServiceContext::new("user-123".to_string());

        let request = CreateLedgerRequest::new(
            "".to_string(), // 空名称应该失败
            "USD".to_string(),
        );

        let result = service._create_ledger(request, context).await;
        assert!(result.is_err());
    }

    #[test]
    fn test_ledger_permission() {
        let owner = LedgerPermission::Owner;
        let editor = LedgerPermission::Editor;
        let viewer = LedgerPermission::Viewer;

        assert!(owner.can_edit());
        assert!(owner.can_admin());
        assert!(owner.can_delete());

        assert!(editor.can_edit());
        assert!(!editor.can_admin());
        assert!(!editor.can_delete());

        assert!(!viewer.can_edit());
        assert!(!viewer.can_admin());
        assert!(!viewer.can_delete());
    }

    #[test]
    fn test_permission_from_string() {
        assert_eq!(
            LedgerPermission::from_string("owner"),
            Some(LedgerPermission::Owner)
        );
        assert_eq!(
            LedgerPermission::from_string("editor"),
            Some(LedgerPermission::Editor)
        );
        assert_eq!(LedgerPermission::from_string("invalid"), None);
    }
}
