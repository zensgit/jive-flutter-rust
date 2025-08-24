//! Account service - 账户管理服务
//! 
//! 基于 Maybe 的账户功能转换而来，包括账户CRUD、余额管理、分组等功能

use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc, NaiveDate};

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::domain::{Account, AccountType, AccountClassification};
use crate::error::{JiveError, Result};
use super::{ServiceContext, ServiceResponse, PaginationParams, PaginatedResult, QueryBuilder, FilterCondition, FilterOperator};

/// 账户创建请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CreateAccountRequest {
    name: String,
    account_type: AccountType,
    classification: AccountClassification,
    currency: String,
    balance: Option<String>,
    description: Option<String>,
    include_in_net_worth: bool,
    institution_name: Option<String>,
    account_number_last_four: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CreateAccountRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(
        name: String,
        account_type: AccountType,
        classification: AccountClassification,
        currency: String,
    ) -> Self {
        Self {
            name,
            account_type,
            classification,
            currency,
            balance: None,
            description: None,
            include_in_net_worth: true,
            institution_name: None,
            account_number_last_four: None,
        }
    }

    // Getters
    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String {
        self.name.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn account_type(&self) -> AccountType {
        self.account_type.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn classification(&self) -> AccountClassification {
        self.classification.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn currency(&self) -> String {
        self.currency.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn balance(&self) -> Option<String> {
        self.balance.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn description(&self) -> Option<String> {
        self.description.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn include_in_net_worth(&self) -> bool {
        self.include_in_net_worth
    }

    // Setters
    #[wasm_bindgen(setter)]
    pub fn set_balance(&mut self, balance: Option<String>) {
        self.balance = balance;
    }

    #[wasm_bindgen(setter)]
    pub fn set_description(&mut self, description: Option<String>) {
        self.description = description;
    }

    #[wasm_bindgen(setter)]
    pub fn set_include_in_net_worth(&mut self, include: bool) {
        self.include_in_net_worth = include;
    }

    #[wasm_bindgen(setter)]
    pub fn set_institution_name(&mut self, name: Option<String>) {
        self.institution_name = name;
    }

    #[wasm_bindgen(setter)]
    pub fn set_account_number_last_four(&mut self, number: Option<String>) {
        self.account_number_last_four = number;
    }
}

/// 账户更新请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UpdateAccountRequest {
    name: Option<String>,
    description: Option<String>,
    is_active: Option<bool>,
    include_in_net_worth: Option<bool>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl UpdateAccountRequest {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            name: None,
            description: None,
            is_active: None,
            include_in_net_worth: None,
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
    pub fn set_is_active(&mut self, is_active: Option<bool>) {
        self.is_active = is_active;
    }

    #[wasm_bindgen(setter)]
    pub fn set_include_in_net_worth(&mut self, include: Option<bool>) {
        self.include_in_net_worth = include;
    }
}

/// 账户查询过滤器
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct AccountFilter {
    account_type: Option<AccountType>,
    classification: Option<AccountClassification>,
    currency: Option<String>,
    is_active: Option<bool>,
    include_in_net_worth: Option<bool>,
    search_query: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl AccountFilter {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            account_type: None,
            classification: None,
            currency: None,
            is_active: None,
            include_in_net_worth: None,
            search_query: None,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_account_type(&mut self, account_type: Option<AccountType>) {
        self.account_type = account_type;
    }

    #[wasm_bindgen(setter)]
    pub fn set_classification(&mut self, classification: Option<AccountClassification>) {
        self.classification = classification;
    }

    #[wasm_bindgen(setter)]
    pub fn set_currency(&mut self, currency: Option<String>) {
        self.currency = currency;
    }

    #[wasm_bindgen(setter)]
    pub fn set_is_active(&mut self, is_active: Option<bool>) {
        self.is_active = is_active;
    }

    #[wasm_bindgen(setter)]
    pub fn set_search_query(&mut self, query: Option<String>) {
        self.search_query = query;
    }
}

impl Default for AccountFilter {
    fn default() -> Self {
        Self::new()
    }
}

/// 账户统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct AccountStats {
    total_accounts: u32,
    total_assets: String,
    total_liabilities: String,
    net_worth: String,
    by_type: HashMap<String, u32>,
    by_currency: HashMap<String, String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl AccountStats {
    #[wasm_bindgen(getter)]
    pub fn total_accounts(&self) -> u32 {
        self.total_accounts
    }

    #[wasm_bindgen(getter)]
    pub fn total_assets(&self) -> String {
        self.total_assets.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn total_liabilities(&self) -> String {
        self.total_liabilities.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn net_worth(&self) -> String {
        self.net_worth.clone()
    }
}

/// 账户余额历史记录
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BalanceHistory {
    account_id: String,
    date: NaiveDate,
    balance: String,
    currency: String,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl BalanceHistory {
    #[wasm_bindgen(getter)]
    pub fn account_id(&self) -> String {
        self.account_id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn date(&self) -> String {
        self.date.to_string()
    }

    #[wasm_bindgen(getter)]
    pub fn balance(&self) -> String {
        self.balance.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn currency(&self) -> String {
        self.currency.clone()
    }
}

/// 账户服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct AccountService {
    // 在实际实现中，这里会包含数据库连接或仓储接口
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl AccountService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {}
    }

    /// 创建账户
    #[wasm_bindgen]
    pub async fn create_account(
        &self,
        request: CreateAccountRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Account> {
        let result = self._create_account(request, context).await;
        result.into()
    }

    /// 更新账户
    #[wasm_bindgen]
    pub async fn update_account(
        &self,
        account_id: String,
        request: UpdateAccountRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Account> {
        let result = self._update_account(account_id, request, context).await;
        result.into()
    }

    /// 获取账户详情
    #[wasm_bindgen]
    pub async fn get_account(
        &self,
        account_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Account> {
        let result = self._get_account(account_id, context).await;
        result.into()
    }

    /// 删除账户
    #[wasm_bindgen]
    pub async fn delete_account(
        &self,
        account_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._delete_account(account_id, context).await;
        result.into()
    }

    /// 更新账户余额
    #[wasm_bindgen]
    pub async fn update_balance(
        &self,
        account_id: String,
        new_balance: String,
        context: ServiceContext,
    ) -> ServiceResponse<Account> {
        let result = self._update_balance(account_id, new_balance, context).await;
        result.into()
    }

    /// 获取账户统计信息
    #[wasm_bindgen]
    pub async fn get_account_stats(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<AccountStats> {
        let result = self._get_account_stats(context).await;
        result.into()
    }

    /// 搜索账户
    #[wasm_bindgen]
    pub async fn search_accounts(
        &self,
        filter: AccountFilter,
        pagination: PaginationParams,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Account>> {
        let result = self._search_accounts(filter, pagination, context).await;
        result.into()
    }

    /// 获取账户余额历史
    #[wasm_bindgen]
    pub async fn get_balance_history(
        &self,
        account_id: String,
        start_date: Option<String>,
        end_date: Option<String>,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<BalanceHistory>> {
        let result = self._get_balance_history(account_id, start_date, end_date, context).await;
        result.into()
    }

    /// 按分类分组账户
    #[wasm_bindgen]
    pub async fn group_by_classification(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<HashMap<String, Vec<Account>>> {
        let result = self._group_by_classification(context).await;
        result.into()
    }

    /// 按类型分组账户
    #[wasm_bindgen]
    pub async fn group_by_type(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<HashMap<String, Vec<Account>>> {
        let result = self._group_by_type(context).await;
        result.into()
    }
}

impl AccountService {
    /// 创建账户的内部实现
    async fn _create_account(
        &self,
        request: CreateAccountRequest,
        _context: ServiceContext,
    ) -> Result<Account> {
        // 验证输入
        if request.name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Account name is required".to_string(),
            });
        }

        // 创建账户
        let mut account = Account::builder()
            .name(request.name)
            .account_type(request.account_type)
            .classification(request.classification)
            .currency(request.currency)
            .include_in_net_worth(request.include_in_net_worth)
            .build()?;

        if let Some(balance) = request.balance {
            account.update_balance(&balance)?;
        }

        if let Some(description) = request.description {
            account.set_description(Some(description));
        }

        // 在实际实现中，这里会保存到数据库
        // let saved_account = repository.save(account).await?;

        Ok(account)
    }

    /// 更新账户的内部实现
    async fn _update_account(
        &self,
        account_id: String,
        request: UpdateAccountRequest,
        _context: ServiceContext,
    ) -> Result<Account> {
        // 在实际实现中，从数据库获取账户
        // let mut account = repository.find_by_id(account_id).await?;
        
        // 模拟账户获取
        let mut account = Account::new(
            "Test Account".to_string(),
            AccountType::Depository,
            AccountClassification::Asset,
            "USD".to_string(),
        )?;

        // 应用更新
        if let Some(name) = request.name {
            account.set_name(name)?;
        }

        if let Some(description) = request.description {
            account.set_description(Some(description));
        }

        if let Some(is_active) = request.is_active {
            account.set_is_active(is_active);
        }

        if let Some(include_in_net_worth) = request.include_in_net_worth {
            account.set_include_in_net_worth(include_in_net_worth);
        }

        // 在实际实现中，这里会保存到数据库
        // let updated_account = repository.save(account).await?;

        Ok(account)
    }

    /// 获取账户的内部实现
    async fn _get_account(
        &self,
        account_id: String,
        _context: ServiceContext,
    ) -> Result<Account> {
        // 在实际实现中，从数据库获取账户
        // let account = repository.find_by_id(account_id).await?;
        
        // 模拟账户获取
        if account_id.is_empty() {
            return Err(JiveError::AccountNotFound { id: account_id });
        }

        let account = Account::new(
            "Test Account".to_string(),
            AccountType::Depository,
            AccountClassification::Asset,
            "USD".to_string(),
        )?;

        Ok(account)
    }

    /// 删除账户的内部实现
    async fn _delete_account(
        &self,
        account_id: String,
        _context: ServiceContext,
    ) -> Result<bool> {
        // 在实际实现中，执行软删除
        // let mut account = repository.find_by_id(account_id).await?;
        // account.soft_delete();
        // repository.save(account).await?;
        
        // 检查账户是否存在
        if account_id.is_empty() {
            return Err(JiveError::AccountNotFound { id: account_id });
        }

        // 检查是否有关联交易
        // let has_transactions = transaction_repository.count_by_account_id(&account_id).await? > 0;
        // if has_transactions {
        //     return Err(JiveError::ValidationError {
        //         message: "Cannot delete account with transactions".to_string(),
        //     });
        // }

        Ok(true)
    }

    /// 更新余额的内部实现
    async fn _update_balance(
        &self,
        account_id: String,
        new_balance: String,
        _context: ServiceContext,
    ) -> Result<Account> {
        // 验证金额格式
        crate::utils::Validator::validate_transaction_amount(&new_balance)?;

        // 获取账户并更新余额
        let mut account = self._get_account(account_id, _context).await?;
        account.update_balance(&new_balance)?;

        // 在实际实现中，这里会保存到数据库并记录余额历史
        // repository.save(account).await?;
        // balance_history_repository.create(BalanceHistory { ... }).await?;

        Ok(account)
    }

    /// 获取统计信息的内部实现
    async fn _get_account_stats(
        &self,
        _context: ServiceContext,
    ) -> Result<AccountStats> {
        // 在实际实现中，从数据库聚合统计数据
        let stats = AccountStats {
            total_accounts: 10,
            total_assets: "50000.00".to_string(),
            total_liabilities: "15000.00".to_string(),
            net_worth: "35000.00".to_string(),
            by_type: HashMap::new(),
            by_currency: HashMap::new(),
        };

        Ok(stats)
    }

    /// 搜索账户的内部实现
    async fn _search_accounts(
        &self,
        filter: AccountFilter,
        pagination: PaginationParams,
        _context: ServiceContext,
    ) -> Result<Vec<Account>> {
        // 在实际实现中，构建查询并执行
        let _query = QueryBuilder::new()
            .paginate(pagination)
            .build();

        // 应用过滤器
        if let Some(_account_type) = filter.account_type {
            // 添加账户类型过滤
        }

        if let Some(_classification) = filter.classification {
            // 添加分类过滤
        }

        if let Some(_search_query) = filter.search_query {
            // 添加搜索查询过滤
        }

        // 模拟返回结果
        let accounts = vec![
            Account::new(
                "Checking Account".to_string(),
                AccountType::Depository,
                AccountClassification::Asset,
                "USD".to_string(),
            )?,
            Account::new(
                "Savings Account".to_string(),
                AccountType::Depository,
                AccountClassification::Asset,
                "USD".to_string(),
            )?,
        ];

        Ok(accounts)
    }

    /// 获取余额历史的内部实现
    async fn _get_balance_history(
        &self,
        account_id: String,
        _start_date: Option<String>,
        _end_date: Option<String>,
        _context: ServiceContext,
    ) -> Result<Vec<BalanceHistory>> {
        // 在实际实现中，从数据库查询余额历史
        let history = vec![
            BalanceHistory {
                account_id: account_id.clone(),
                date: chrono::Utc::now().naive_utc().date(),
                balance: "1000.00".to_string(),
                currency: "USD".to_string(),
            },
        ];

        Ok(history)
    }

    /// 按分类分组的内部实现
    async fn _group_by_classification(
        &self,
        context: ServiceContext,
    ) -> Result<HashMap<String, Vec<Account>>> {
        let accounts = self._search_accounts(
            AccountFilter::default(),
            PaginationParams::new(1, 100),
            context,
        ).await?;

        let mut grouped = HashMap::new();
        for account in accounts {
            let classification = account.classification().as_string();
            grouped.entry(classification).or_insert_with(Vec::new).push(account);
        }

        Ok(grouped)
    }

    /// 按类型分组的内部实现
    async fn _group_by_type(
        &self,
        context: ServiceContext,
    ) -> Result<HashMap<String, Vec<Account>>> {
        let accounts = self._search_accounts(
            AccountFilter::default(),
            PaginationParams::new(1, 100),
            context,
        ).await?;

        let mut grouped = HashMap::new();
        for account in accounts {
            let account_type = account.account_type().as_string();
            grouped.entry(account_type).or_insert_with(Vec::new).push(account);
        }

        Ok(grouped)
    }
}

impl Default for AccountService {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_account() {
        let service = AccountService::new();
        let context = ServiceContext::new("user-123".to_string());
        
        let request = CreateAccountRequest::new(
            "Test Account".to_string(),
            AccountType::Depository,
            AccountClassification::Asset,
            "USD".to_string(),
        );

        let result = service._create_account(request, context).await;
        assert!(result.is_ok());

        let account = result.unwrap();
        assert_eq!(account.name(), "Test Account");
        assert_eq!(account.currency(), "USD");
    }

    #[tokio::test]
    async fn test_update_account() {
        let service = AccountService::new();
        let context = ServiceContext::new("user-123".to_string());
        
        let mut request = UpdateAccountRequest::new();
        request.set_name(Some("Updated Account".to_string()));
        request.set_is_active(Some(false));

        let result = service._update_account("account-123".to_string(), request, context).await;
        assert!(result.is_ok());
    }

    #[tokio::test]
    async fn test_account_validation() {
        let service = AccountService::new();
        let context = ServiceContext::new("user-123".to_string());
        
        let request = CreateAccountRequest::new(
            "".to_string(), // 空名称应该失败
            AccountType::Depository,
            AccountClassification::Asset,
            "USD".to_string(),
        );

        let result = service._create_account(request, context).await;
        assert!(result.is_err());
    }
}