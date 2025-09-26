//! User service - 用户管理服务
//!
//! 基于 Maybe 的用户管理功能转换而来，包括用户CRUD、偏好设置、权限管理等功能

use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use super::{BatchResult, PaginationParams, ServiceContext, ServiceResponse};
use crate::domain::{User, UserPreferences, UserRole, UserStatus};
use crate::error::{JiveError, Result};

/// 用户创建请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CreateUserRequest {
    email: String,
    name: String,
    password: String,
    avatar_url: Option<String>,
    preferences: Option<UserPreferences>,
    send_welcome_email: bool,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CreateUserRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(email: String, name: String, password: String) -> Self {
        Self {
            email,
            name,
            password,
            avatar_url: None,
            preferences: None,
            send_welcome_email: true,
        }
    }

    // Getters
    #[wasm_bindgen(getter)]
    pub fn email(&self) -> String {
        self.email.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String {
        self.name.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn send_welcome_email(&self) -> bool {
        self.send_welcome_email
    }

    // Setters
    #[wasm_bindgen(setter)]
    pub fn set_avatar_url(&mut self, avatar_url: Option<String>) {
        self.avatar_url = avatar_url;
    }

    #[wasm_bindgen]
    pub fn set_preferences(&mut self, preferences: UserPreferences) {
        self.preferences = Some(preferences);
    }

    #[wasm_bindgen(setter)]
    pub fn set_send_welcome_email(&mut self, send: bool) {
        self.send_welcome_email = send;
    }
}

/// 用户更新请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UpdateUserRequest {
    name: Option<String>,
    avatar_url: Option<String>,
    preferences: Option<UserPreferences>,
    status: Option<UserStatus>,
    role: Option<UserRole>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl UpdateUserRequest {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            name: None,
            avatar_url: None,
            preferences: None,
            status: None,
            role: None,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_name(&mut self, name: Option<String>) {
        self.name = name;
    }

    #[wasm_bindgen(setter)]
    pub fn set_avatar_url(&mut self, avatar_url: Option<String>) {
        self.avatar_url = avatar_url;
    }

    #[wasm_bindgen]
    pub fn set_preferences(&mut self, preferences: UserPreferences) {
        self.preferences = Some(preferences);
    }

    #[wasm_bindgen(setter)]
    pub fn set_status(&mut self, status: Option<UserStatus>) {
        self.status = status;
    }

    #[wasm_bindgen(setter)]
    pub fn set_role(&mut self, role: Option<UserRole>) {
        self.role = role;
    }
}

/// 用户筛选器
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UserFilter {
    status: Option<UserStatus>,
    role: Option<UserRole>,
    search_query: Option<String>,
    created_after: Option<DateTime<Utc>>,
    created_before: Option<DateTime<Utc>>,
    email_verified: Option<bool>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl UserFilter {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            status: None,
            role: None,
            search_query: None,
            created_after: None,
            created_before: None,
            email_verified: None,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_status(&mut self, status: Option<UserStatus>) {
        self.status = status;
    }

    #[wasm_bindgen(setter)]
    pub fn set_role(&mut self, role: Option<UserRole>) {
        self.role = role;
    }

    #[wasm_bindgen(setter)]
    pub fn set_search_query(&mut self, query: Option<String>) {
        self.search_query = query;
    }

    #[wasm_bindgen(setter)]
    pub fn set_email_verified(&mut self, verified: Option<bool>) {
        self.email_verified = verified;
    }
}

impl Default for UserFilter {
    fn default() -> Self {
        Self::new()
    }
}

/// 密码更改请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ChangePasswordRequest {
    current_password: String,
    new_password: String,
    confirm_password: String,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl ChangePasswordRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(current_password: String, new_password: String, confirm_password: String) -> Self {
        Self {
            current_password,
            new_password,
            confirm_password,
        }
    }

    #[wasm_bindgen(getter)]
    pub fn current_password(&self) -> String {
        self.current_password.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn new_password(&self) -> String {
        self.new_password.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn confirm_password(&self) -> String {
        self.confirm_password.clone()
    }
}

/// 用户邀请请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct InviteUserRequest {
    email: String,
    name: String,
    role: UserRole,
    message: Option<String>,
    ledger_id: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl InviteUserRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(email: String, name: String, role: UserRole) -> Self {
        Self {
            email,
            name,
            role,
            message: None,
            ledger_id: None,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_message(&mut self, message: Option<String>) {
        self.message = message;
    }

    #[wasm_bindgen(setter)]
    pub fn set_ledger_id(&mut self, ledger_id: Option<String>) {
        self.ledger_id = ledger_id;
    }
}

/// 用户统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UserStats {
    total_users: u32,
    active_users: u32,
    premium_users: u32,
    admin_users: u32,
    new_users_this_month: u32,
    verified_users: u32,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl UserStats {
    #[wasm_bindgen(getter)]
    pub fn total_users(&self) -> u32 {
        self.total_users
    }

    #[wasm_bindgen(getter)]
    pub fn active_users(&self) -> u32 {
        self.active_users
    }

    #[wasm_bindgen(getter)]
    pub fn premium_users(&self) -> u32 {
        self.premium_users
    }

    #[wasm_bindgen(getter)]
    pub fn admin_users(&self) -> u32 {
        self.admin_users
    }

    #[wasm_bindgen(getter)]
    pub fn new_users_this_month(&self) -> u32 {
        self.new_users_this_month
    }

    #[wasm_bindgen(getter)]
    pub fn verified_users(&self) -> u32 {
        self.verified_users
    }
}

/// 用户活动记录
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UserActivity {
    user_id: String,
    activity_type: String,
    description: String,
    metadata: HashMap<String, String>,
    created_at: DateTime<Utc>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl UserActivity {
    #[wasm_bindgen(getter)]
    pub fn user_id(&self) -> String {
        self.user_id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn activity_type(&self) -> String {
        self.activity_type.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn description(&self) -> String {
        self.description.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn created_at(&self) -> String {
        self.created_at.to_rfc3339()
    }
}

/// 用户服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UserService {
    // 在实际实现中，这里会包含数据库连接或仓储接口
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl UserService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {}
    }

    /// 创建用户
    #[wasm_bindgen]
    pub async fn create_user(
        &self,
        request: CreateUserRequest,
        context: ServiceContext,
    ) -> ServiceResponse<User> {
        let result = self._create_user(request, context).await;
        result.into()
    }

    /// 更新用户
    #[wasm_bindgen]
    pub async fn update_user(
        &self,
        user_id: String,
        request: UpdateUserRequest,
        context: ServiceContext,
    ) -> ServiceResponse<User> {
        let result = self._update_user(user_id, request, context).await;
        result.into()
    }

    /// 获取用户详情
    #[wasm_bindgen]
    pub async fn get_user(
        &self,
        user_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<User> {
        let result = self._get_user(user_id, context).await;
        result.into()
    }

    /// 获取当前用户
    #[wasm_bindgen]
    pub async fn get_current_user(&self, context: ServiceContext) -> ServiceResponse<User> {
        let result = self._get_current_user(context).await;
        result.into()
    }

    /// 删除用户
    #[wasm_bindgen]
    pub async fn delete_user(
        &self,
        user_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._delete_user(user_id, context).await;
        result.into()
    }

    /// 搜索用户
    #[wasm_bindgen]
    pub async fn search_users(
        &self,
        filter: UserFilter,
        pagination: PaginationParams,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<User>> {
        let result = self._search_users(filter, pagination, context).await;
        result.into()
    }

    /// 更改密码
    #[wasm_bindgen]
    pub async fn change_password(
        &self,
        user_id: String,
        request: ChangePasswordRequest,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._change_password(user_id, request, context).await;
        result.into()
    }

    /// 重置密码
    #[wasm_bindgen]
    pub async fn reset_password(
        &self,
        email: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._reset_password(email, context).await;
        result.into()
    }

    /// 验证邮箱
    #[wasm_bindgen]
    pub async fn verify_email(
        &self,
        user_id: String,
        verification_token: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self
            ._verify_email(user_id, verification_token, context)
            .await;
        result.into()
    }

    /// 发送验证邮件
    #[wasm_bindgen]
    pub async fn send_verification_email(
        &self,
        user_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._send_verification_email(user_id, context).await;
        result.into()
    }

    /// 邀请用户
    #[wasm_bindgen]
    pub async fn invite_user(
        &self,
        request: InviteUserRequest,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._invite_user(request, context).await;
        result.into()
    }

    /// 激活用户
    #[wasm_bindgen]
    pub async fn activate_user(
        &self,
        user_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<User> {
        let result = self._activate_user(user_id, context).await;
        result.into()
    }

    /// 暂停用户
    #[wasm_bindgen]
    pub async fn suspend_user(
        &self,
        user_id: String,
        reason: String,
        context: ServiceContext,
    ) -> ServiceResponse<User> {
        let result = self._suspend_user(user_id, reason, context).await;
        result.into()
    }

    /// 更新用户偏好
    #[wasm_bindgen]
    pub async fn update_preferences(
        &self,
        user_id: String,
        preferences: UserPreferences,
        context: ServiceContext,
    ) -> ServiceResponse<User> {
        let result = self
            ._update_preferences(user_id, preferences, context)
            .await;
        result.into()
    }

    /// 获取用户统计信息
    #[wasm_bindgen]
    pub async fn get_user_stats(&self, context: ServiceContext) -> ServiceResponse<UserStats> {
        let result = self._get_user_stats(context).await;
        result.into()
    }

    /// 获取用户活动记录
    #[wasm_bindgen]
    pub async fn get_user_activities(
        &self,
        user_id: String,
        pagination: PaginationParams,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<UserActivity>> {
        let result = self
            ._get_user_activities(user_id, pagination, context)
            .await;
        result.into()
    }

    /// 记录用户活动
    #[wasm_bindgen]
    pub async fn log_activity(
        &self,
        user_id: String,
        activity_type: String,
        description: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self
            ._log_activity(user_id, activity_type, description, context)
            .await;
        result.into()
    }

    /// 检查用户是否存在
    #[wasm_bindgen]
    pub async fn user_exists(
        &self,
        email: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._user_exists(email, context).await;
        result.into()
    }

    /// 获取用户通过邮箱
    #[wasm_bindgen]
    pub async fn get_user_by_email(
        &self,
        email: String,
        context: ServiceContext,
    ) -> ServiceResponse<User> {
        let result = self._get_user_by_email(email, context).await;
        result.into()
    }
}

impl UserService {
    /// 创建用户的内部实现
    async fn _create_user(
        &self,
        request: CreateUserRequest,
        _context: ServiceContext,
    ) -> Result<User> {
        // 验证密码强度
        self.validate_password(&request.password)?;

        // 检查邮箱是否已存在
        if self
            ._user_exists(request.email.clone(), _context.clone())
            .await?
        {
            return Err(JiveError::ValidationError {
                message: "Email already exists".to_string(),
            });
        }

        // 创建用户
        let mut user = User::new(request.email, request.name)?;

        // 设置可选字段
        if let Some(avatar_url) = request.avatar_url {
            user.set_avatar_url(Some(avatar_url));
        }

        if let Some(preferences) = request.preferences {
            user.set_preferences(preferences);
        }

        // 在实际实现中，这里会：
        // 1. 保存用户到数据库
        // 2. 哈希并保存密码
        // 3. 发送欢迎邮件
        // 4. 记录用户活动

        // if request.send_welcome_email {
        //     email_service.send_welcome_email(&user).await?;
        // }

        // 记录用户创建活动
        self._log_activity(
            user.id(),
            "user_created".to_string(),
            "User account created".to_string(),
            _context,
        )
        .await?;

        Ok(user)
    }

    /// 更新用户的内部实现
    async fn _update_user(
        &self,
        user_id: String,
        request: UpdateUserRequest,
        context: ServiceContext,
    ) -> Result<User> {
        // 权限检查：只能更新自己的信息，或者管理员可以更新其他用户
        if user_id != context.user_id {
            let current_user = self._get_current_user(context.clone()).await?;
            if !current_user.is_admin() {
                return Err(JiveError::PermissionDenied {
                    message: "Cannot update other user's information".to_string(),
                });
            }
        }

        // 获取现有用户
        let mut user = self._get_user(user_id, context.clone()).await?;

        // 应用更新
        if let Some(name) = request.name {
            user.set_name(name)?;
        }

        if let Some(avatar_url) = request.avatar_url {
            user.set_avatar_url(Some(avatar_url));
        }

        if let Some(preferences) = request.preferences {
            user.set_preferences(preferences);
        }

        // 管理员才能更新状态和角色
        let current_user = self._get_current_user(context.clone()).await?;
        if current_user.is_admin() {
            if let Some(status) = request.status {
                user.set_status(status);
            }

            if let Some(role) = request.role {
                user.set_role(role);
            }
        }

        // 在实际实现中，这里会保存到数据库
        // repository.save(user).await?;

        // 记录更新活动
        self._log_activity(
            user.id(),
            "user_updated".to_string(),
            "User information updated".to_string(),
            context,
        )
        .await?;

        Ok(user)
    }

    /// 获取用户的内部实现
    async fn _get_user(&self, user_id: String, context: ServiceContext) -> Result<User> {
        // 权限检查：只能查看自己的信息，或者管理员可以查看其他用户
        if user_id != context.user_id {
            let current_user = self._get_current_user(context.clone()).await?;
            if !current_user.is_admin() {
                return Err(JiveError::PermissionDenied {
                    message: "Cannot view other user's information".to_string(),
                });
            }
        }

        // 在实际实现中，从数据库获取用户
        if user_id.is_empty() {
            return Err(JiveError::UserNotFound { id: user_id });
        }

        // 模拟用户获取
        let user = User::new("test@example.com".to_string(), "Test User".to_string())?;

        Ok(user)
    }

    /// 获取当前用户的内部实现
    async fn _get_current_user(&self, context: ServiceContext) -> Result<User> {
        self._get_user(context.user_id, context).await
    }

    /// 删除用户的内部实现
    async fn _delete_user(&self, user_id: String, context: ServiceContext) -> Result<bool> {
        // 权限检查：只有管理员或用户本人可以删除
        if user_id != context.user_id {
            let current_user = self._get_current_user(context.clone()).await?;
            if !current_user.is_admin() {
                return Err(JiveError::PermissionDenied {
                    message: "Cannot delete other user's account".to_string(),
                });
            }
        }

        // 获取用户
        let mut user = self._get_user(user_id, context.clone()).await?;

        // 执行软删除
        user.soft_delete();

        // 在实际实现中，这里会：
        // 1. 软删除用户数据
        // 2. 匿名化敏感信息
        // 3. 取消所有订阅
        // 4. 发送确认邮件

        // 记录删除活动
        self._log_activity(
            user.id(),
            "user_deleted".to_string(),
            "User account deleted".to_string(),
            context,
        )
        .await?;

        Ok(true)
    }

    /// 搜索用户的内部实现
    async fn _search_users(
        &self,
        filter: UserFilter,
        _pagination: PaginationParams,
        context: ServiceContext,
    ) -> Result<Vec<User>> {
        // 权限检查：只有管理员可以搜索用户
        let current_user = self._get_current_user(context).await?;
        if !current_user.is_admin() {
            return Err(JiveError::PermissionDenied {
                message: "Only admins can search users".to_string(),
            });
        }

        // 在实际实现中，构建查询并执行
        let mut users = Vec::new();

        // 模拟一些用户数据
        for i in 1..=5 {
            let user = User::new(format!("user{}@example.com", i), format!("User {}", i))?;
            users.push(user);
        }

        // 应用过滤器
        if let Some(_status) = filter.status {
            // 按状态过滤
        }

        if let Some(_role) = filter.role {
            // 按角色过滤
        }

        if let Some(_search_query) = filter.search_query {
            // 按搜索查询过滤
        }

        Ok(users)
    }

    /// 更改密码的内部实现
    async fn _change_password(
        &self,
        user_id: String,
        request: ChangePasswordRequest,
        context: ServiceContext,
    ) -> Result<bool> {
        // 权限检查：只能更改自己的密码
        if user_id != context.user_id {
            return Err(JiveError::PermissionDenied {
                message: "Cannot change other user's password".to_string(),
            });
        }

        // 验证新密码
        if request.new_password != request.confirm_password {
            return Err(JiveError::ValidationError {
                message: "New password and confirmation do not match".to_string(),
            });
        }

        self.validate_password(&request.new_password)?;

        // 在实际实现中，这里会验证当前密码并更新新密码
        // let user = self._get_user(user_id, context.clone()).await?;
        //
        // if !password_service.verify_password(&request.current_password, &user.password_hash) {
        //     return Err(JiveError::ValidationError {
        //         message: "Current password is incorrect".to_string(),
        //     });
        // }
        //
        // let new_password_hash = password_service.hash_password(&request.new_password)?;
        // repository.update_password(user_id, new_password_hash).await?;

        // 记录密码更改活动
        self._log_activity(
            user_id,
            "password_changed".to_string(),
            "Password changed successfully".to_string(),
            context,
        )
        .await?;

        Ok(true)
    }

    /// 重置密码的内部实现
    async fn _reset_password(&self, email: String, _context: ServiceContext) -> Result<bool> {
        // 验证邮箱格式
        crate::utils::Validator::validate_email(&email)?;

        // 在实际实现中，这里会：
        // 1. 检查用户是否存在
        // 2. 生成重置令牌
        // 3. 发送重置邮件
        // 4. 记录重置请求

        // let user = self._get_user_by_email(email.clone(), context.clone()).await?;
        // let reset_token = token_service.generate_reset_token(&user.id())?;
        // email_service.send_password_reset_email(&user, &reset_token).await?;

        Ok(true)
    }

    /// 验证邮箱的内部实现
    async fn _verify_email(
        &self,
        user_id: String,
        verification_token: String,
        context: ServiceContext,
    ) -> Result<bool> {
        // 在实际实现中，这里会验证令牌并标记邮箱为已验证
        // let is_valid = token_service.verify_email_token(&verification_token, &user_id)?;
        //
        // if !is_valid {
        //     return Err(JiveError::ValidationError {
        //         message: "Invalid verification token".to_string(),
        //     });
        // }

        let mut user = self._get_user(user_id, context.clone()).await?;
        user.verify_email();

        // repository.save(user).await?;

        // 记录邮箱验证活动
        self._log_activity(
            user.id(),
            "email_verified".to_string(),
            "Email address verified".to_string(),
            context,
        )
        .await?;

        Ok(true)
    }

    /// 发送验证邮件的内部实现
    async fn _send_verification_email(
        &self,
        user_id: String,
        context: ServiceContext,
    ) -> Result<bool> {
        let user = self._get_user(user_id, context.clone()).await?;

        // 在实际实现中，这里会生成验证令牌并发送邮件
        // let verification_token = token_service.generate_verification_token(&user.id())?;
        // email_service.send_verification_email(&user, &verification_token).await?;

        // 记录发送验证邮件活动
        self._log_activity(
            user.id(),
            "verification_email_sent".to_string(),
            "Verification email sent".to_string(),
            context,
        )
        .await?;

        Ok(true)
    }

    /// 邀请用户的内部实现
    async fn _invite_user(
        &self,
        request: InviteUserRequest,
        context: ServiceContext,
    ) -> Result<bool> {
        // 权限检查：只有管理员可以邀请用户
        let current_user = self._get_current_user(context.clone()).await?;
        if !current_user.is_admin() {
            return Err(JiveError::PermissionDenied {
                message: "Only admins can invite users".to_string(),
            });
        }

        // 验证邮箱格式
        crate::utils::Validator::validate_email(&request.email)?;

        // 检查用户是否已存在
        if self
            ._user_exists(request.email.clone(), context.clone())
            .await?
        {
            return Err(JiveError::ValidationError {
                message: "User with this email already exists".to_string(),
            });
        }

        // 在实际实现中，这里会：
        // 1. 创建邀请记录
        // 2. 生成邀请令牌
        // 3. 发送邀请邮件

        // let invitation = Invitation::new(
        //     request.email.clone(),
        //     request.name.clone(),
        //     request.role,
        //     context.user_id,
        // )?;
        //
        // let invite_token = token_service.generate_invite_token(&invitation.id())?;
        // email_service.send_invitation_email(&invitation, &invite_token).await?;

        Ok(true)
    }

    /// 激活用户的内部实现
    async fn _activate_user(&self, user_id: String, context: ServiceContext) -> Result<User> {
        // 权限检查：只有管理员可以激活用户
        let current_user = self._get_current_user(context.clone()).await?;
        if !current_user.is_admin() {
            return Err(JiveError::PermissionDenied {
                message: "Only admins can activate users".to_string(),
            });
        }

        let mut user = self._get_user(user_id, context.clone()).await?;
        user.activate();

        // 记录激活活动
        self._log_activity(
            user.id(),
            "user_activated".to_string(),
            "User account activated".to_string(),
            context,
        )
        .await?;

        Ok(user)
    }

    /// 暂停用户的内部实现
    async fn _suspend_user(
        &self,
        user_id: String,
        reason: String,
        context: ServiceContext,
    ) -> Result<User> {
        // 权限检查：只有管理员可以暂停用户
        let current_user = self._get_current_user(context.clone()).await?;
        if !current_user.is_admin() {
            return Err(JiveError::PermissionDenied {
                message: "Only admins can suspend users".to_string(),
            });
        }

        let mut user = self._get_user(user_id, context.clone()).await?;
        user.suspend();

        // 记录暂停活动
        self._log_activity(
            user.id(),
            "user_suspended".to_string(),
            format!("User account suspended: {}", reason),
            context,
        )
        .await?;

        Ok(user)
    }

    /// 更新用户偏好的内部实现
    async fn _update_preferences(
        &self,
        user_id: String,
        preferences: UserPreferences,
        context: ServiceContext,
    ) -> Result<User> {
        // 权限检查：只能更新自己的偏好
        if user_id != context.user_id {
            return Err(JiveError::PermissionDenied {
                message: "Cannot update other user's preferences".to_string(),
            });
        }

        let mut user = self._get_user(user_id, context.clone()).await?;
        user.set_preferences(preferences);

        // 记录偏好更新活动
        self._log_activity(
            user.id(),
            "preferences_updated".to_string(),
            "User preferences updated".to_string(),
            context,
        )
        .await?;

        Ok(user)
    }

    /// 获取用户统计信息的内部实现
    async fn _get_user_stats(&self, context: ServiceContext) -> Result<UserStats> {
        // 权限检查：只有管理员可以查看统计信息
        let current_user = self._get_current_user(context).await?;
        if !current_user.is_admin() {
            return Err(JiveError::PermissionDenied {
                message: "Only admins can view user statistics".to_string(),
            });
        }

        // 在实际实现中，从数据库聚合统计数据
        let stats = UserStats {
            total_users: 1250,
            active_users: 1180,
            premium_users: 340,
            admin_users: 12,
            new_users_this_month: 85,
            verified_users: 1150,
        };

        Ok(stats)
    }

    /// 获取用户活动记录的内部实现
    async fn _get_user_activities(
        &self,
        user_id: String,
        _pagination: PaginationParams,
        context: ServiceContext,
    ) -> Result<Vec<UserActivity>> {
        // 权限检查：只能查看自己的活动，或者管理员可以查看其他用户
        if user_id != context.user_id {
            let current_user = self._get_current_user(context).await?;
            if !current_user.is_admin() {
                return Err(JiveError::PermissionDenied {
                    message: "Cannot view other user's activities".to_string(),
                });
            }
        }

        // 在实际实现中，从数据库查询活动记录
        let activities = vec![
            UserActivity {
                user_id: user_id.clone(),
                activity_type: "login".to_string(),
                description: "User logged in".to_string(),
                metadata: HashMap::new(),
                created_at: Utc::now(),
            },
            UserActivity {
                user_id: user_id.clone(),
                activity_type: "profile_updated".to_string(),
                description: "Profile information updated".to_string(),
                metadata: HashMap::new(),
                created_at: Utc::now(),
            },
        ];

        Ok(activities)
    }

    /// 记录用户活动的内部实现
    async fn _log_activity(
        &self,
        user_id: String,
        activity_type: String,
        description: String,
        _context: ServiceContext,
    ) -> Result<bool> {
        // 在实际实现中，这里会保存活动记录到数据库
        // let activity = UserActivity {
        //     user_id,
        //     activity_type,
        //     description,
        //     metadata: HashMap::new(),
        //     created_at: Utc::now(),
        // };
        //
        // activity_repository.save(activity).await?;

        Ok(true)
    }

    /// 检查用户是否存在的内部实现
    async fn _user_exists(&self, email: String, _context: ServiceContext) -> Result<bool> {
        // 在实际实现中，查询数据库检查邮箱是否存在
        // let exists = repository.exists_by_email(&email).await?;

        // 模拟检查
        Ok(false)
    }

    /// 通过邮箱获取用户的内部实现
    async fn _get_user_by_email(&self, email: String, context: ServiceContext) -> Result<User> {
        // 验证邮箱格式
        crate::utils::Validator::validate_email(&email)?;

        // 在实际实现中，从数据库通过邮箱查询用户
        // let user = repository.find_by_email(&email).await?
        //     .ok_or_else(|| JiveError::UserNotFound { id: email.clone() })?;

        // 模拟获取用户
        if email == "test@example.com" {
            User::new(email, "Test User".to_string())
        } else {
            Err(JiveError::UserNotFound { id: email })
        }
    }

    /// 验证密码强度
    fn validate_password(&self, password: &str) -> Result<()> {
        if password.len() < 8 {
            return Err(JiveError::ValidationError {
                message: "Password must be at least 8 characters long".to_string(),
            });
        }

        if !password.chars().any(|c| c.is_ascii_uppercase()) {
            return Err(JiveError::ValidationError {
                message: "Password must contain at least one uppercase letter".to_string(),
            });
        }

        if !password.chars().any(|c| c.is_ascii_lowercase()) {
            return Err(JiveError::ValidationError {
                message: "Password must contain at least one lowercase letter".to_string(),
            });
        }

        if !password.chars().any(|c| c.is_ascii_digit()) {
            return Err(JiveError::ValidationError {
                message: "Password must contain at least one number".to_string(),
            });
        }

        Ok(())
    }
}

impl Default for UserService {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_user() {
        let service = UserService::new();
        let context = ServiceContext::new("admin-123".to_string());

        let request = CreateUserRequest::new(
            "test@example.com".to_string(),
            "Test User".to_string(),
            "Password123".to_string(),
        );

        let result = service._create_user(request, context).await;
        assert!(result.is_ok());

        let user = result.unwrap();
        assert_eq!(user.email(), "test@example.com");
        assert_eq!(user.name(), "Test User");
    }

    #[tokio::test]
    async fn test_password_validation() {
        let service = UserService::new();

        // 测试密码太短
        let result = service.validate_password("12345");
        assert!(result.is_err());

        // 测试缺少大写字母
        let result = service.validate_password("password123");
        assert!(result.is_err());

        // 测试缺少数字
        let result = service.validate_password("Password");
        assert!(result.is_err());

        // 测试有效密码
        let result = service.validate_password("Password123");
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_change_password() {
        let service = UserService::new();
        let context = ServiceContext::new("user-123".to_string());

        let request = ChangePasswordRequest::new(
            "OldPassword123".to_string(),
            "NewPassword123".to_string(),
            "NewPassword123".to_string(),
        );

        let result = service
            ._change_password("user-123".to_string(), request, context)
            .await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_change_password_mismatch() {
        let service = UserService::new();
        let context = ServiceContext::new("user-123".to_string());

        let request = ChangePasswordRequest::new(
            "OldPassword123".to_string(),
            "NewPassword123".to_string(),
            "DifferentPassword123".to_string(),
        );

        let result = service
            ._change_password("user-123".to_string(), request, context)
            .await;
        assert!(result.is_err());
    }

    #[test]
    fn test_user_filter() {
        let mut filter = UserFilter::new();
        filter.set_status(Some(UserStatus::Active));
        filter.set_role(Some(UserRole::Premium));
        filter.set_search_query(Some("test".to_string()));

        // 测试默认值
        let default_filter = UserFilter::default();
        assert!(default_filter.status.is_none());
        assert!(default_filter.role.is_none());
    }
}
