//! Transaction service - 交易管理服务
//! 
//! 基于 Maybe 的交易功能转换而来，包括交易CRUD、分类、标签、搜索等功能

use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc, NaiveDate};

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::domain::{Transaction, TransactionType, TransactionStatus};
use crate::error::{JiveError, Result};
use super::{ServiceContext, ServiceResponse, PaginationParams, PaginatedResult, BatchResult};

/// 交易创建请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct CreateTransactionRequest {
    account_id: String,
    ledger_id: String,
    name: String,
    amount: String,
    currency: String,
    date: String, // YYYY-MM-DD 格式
    transaction_type: TransactionType,
    category_id: Option<String>,
    payee_id: Option<String>,
    description: Option<String>,
    notes: Option<String>,
    reference: Option<String>,
    tags: Vec<String>,
    // 多货币支持
    original_amount: Option<String>,
    original_currency: Option<String>,
    exchange_rate: Option<String>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl CreateTransactionRequest {
    #[wasm_bindgen(constructor)]
    pub fn new(
        account_id: String,
        ledger_id: String,
        name: String,
        amount: String,
        currency: String,
        date: String,
        transaction_type: TransactionType,
    ) -> Self {
        Self {
            account_id,
            ledger_id,
            name,
            amount,
            currency,
            date,
            transaction_type,
            category_id: None,
            payee_id: None,
            description: None,
            notes: None,
            reference: None,
            tags: Vec::new(),
            original_amount: None,
            original_currency: None,
            exchange_rate: None,
        }
    }

    // Getters
    #[wasm_bindgen(getter)]
    pub fn account_id(&self) -> String {
        self.account_id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn ledger_id(&self) -> String {
        self.ledger_id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String {
        self.name.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn amount(&self) -> String {
        self.amount.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn currency(&self) -> String {
        self.currency.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn date(&self) -> String {
        self.date.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn transaction_type(&self) -> TransactionType {
        self.transaction_type.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn tags(&self) -> Vec<String> {
        self.tags.clone()
    }

    // Setters
    #[wasm_bindgen(setter)]
    pub fn set_category_id(&mut self, category_id: Option<String>) {
        self.category_id = category_id;
    }

    #[wasm_bindgen(setter)]
    pub fn set_payee_id(&mut self, payee_id: Option<String>) {
        self.payee_id = payee_id;
    }

    #[wasm_bindgen(setter)]
    pub fn set_description(&mut self, description: Option<String>) {
        self.description = description;
    }

    #[wasm_bindgen(setter)]
    pub fn set_notes(&mut self, notes: Option<String>) {
        self.notes = notes;
    }

    #[wasm_bindgen(setter)]
    pub fn set_reference(&mut self, reference: Option<String>) {
        self.reference = reference;
    }

    #[wasm_bindgen]
    pub fn add_tag(&mut self, tag: String) {
        if !self.tags.contains(&tag) {
            self.tags.push(tag);
        }
    }

    #[wasm_bindgen]
    pub fn remove_tag(&mut self, tag: String) {
        if let Some(pos) = self.tags.iter().position(|t| t == &tag) {
            self.tags.remove(pos);
        }
    }

    #[wasm_bindgen]
    pub fn set_multi_currency(&mut self, original_amount: String, original_currency: String, exchange_rate: String) {
        self.original_amount = Some(original_amount);
        self.original_currency = Some(original_currency);
        self.exchange_rate = Some(exchange_rate);
    }

    #[wasm_bindgen]
    pub fn clear_multi_currency(&mut self) {
        self.original_amount = None;
        self.original_currency = None;
        self.exchange_rate = None;
    }
}

/// 交易更新请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct UpdateTransactionRequest {
    name: Option<String>,
    amount: Option<String>,
    date: Option<String>,
    category_id: Option<String>,
    payee_id: Option<String>,
    description: Option<String>,
    notes: Option<String>,
    reference: Option<String>,
    status: Option<TransactionStatus>,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl UpdateTransactionRequest {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            name: None,
            amount: None,
            date: None,
            category_id: None,
            payee_id: None,
            description: None,
            notes: None,
            reference: None,
            status: None,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_name(&mut self, name: Option<String>) {
        self.name = name;
    }

    #[wasm_bindgen(setter)]
    pub fn set_amount(&mut self, amount: Option<String>) {
        self.amount = amount;
    }

    #[wasm_bindgen(setter)]
    pub fn set_date(&mut self, date: Option<String>) {
        self.date = date;
    }

    #[wasm_bindgen(setter)]
    pub fn set_category_id(&mut self, category_id: Option<String>) {
        self.category_id = category_id;
    }

    #[wasm_bindgen(setter)]
    pub fn set_status(&mut self, status: Option<TransactionStatus>) {
        self.status = status;
    }
}

/// 交易搜索过滤器
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct TransactionFilter {
    account_id: Option<String>,
    ledger_id: Option<String>,
    category_id: Option<String>,
    payee_id: Option<String>,
    transaction_type: Option<TransactionType>,
    status: Option<TransactionStatus>,
    currency: Option<String>,
    start_date: Option<String>,
    end_date: Option<String>,
    min_amount: Option<String>,
    max_amount: Option<String>,
    search_query: Option<String>,
    tags: Vec<String>,
    include_transfers: bool,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl TransactionFilter {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {
            account_id: None,
            ledger_id: None,
            category_id: None,
            payee_id: None,
            transaction_type: None,
            status: None,
            currency: None,
            start_date: None,
            end_date: None,
            min_amount: None,
            max_amount: None,
            search_query: None,
            tags: Vec::new(),
            include_transfers: true,
        }
    }

    #[wasm_bindgen(setter)]
    pub fn set_account_id(&mut self, account_id: Option<String>) {
        self.account_id = account_id;
    }

    #[wasm_bindgen(setter)]
    pub fn set_ledger_id(&mut self, ledger_id: Option<String>) {
        self.ledger_id = ledger_id;
    }

    #[wasm_bindgen(setter)]
    pub fn set_date_range(&mut self, start_date: Option<String>, end_date: Option<String>) {
        self.start_date = start_date;
        self.end_date = end_date;
    }

    #[wasm_bindgen(setter)]
    pub fn set_amount_range(&mut self, min_amount: Option<String>, max_amount: Option<String>) {
        self.min_amount = min_amount;
        self.max_amount = max_amount;
    }

    #[wasm_bindgen(setter)]
    pub fn set_search_query(&mut self, query: Option<String>) {
        self.search_query = query;
    }

    #[wasm_bindgen]
    pub fn add_tag_filter(&mut self, tag: String) {
        if !self.tags.contains(&tag) {
            self.tags.push(tag);
        }
    }
}

impl Default for TransactionFilter {
    fn default() -> Self {
        Self::new()
    }
}

/// 交易统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct TransactionStats {
    total_transactions: u32,
    total_income: String,
    total_expenses: String,
    net_flow: String,
    by_category: HashMap<String, String>,
    by_month: HashMap<String, String>,
    avg_transaction_amount: String,
    currency: String,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl TransactionStats {
    #[wasm_bindgen(getter)]
    pub fn total_transactions(&self) -> u32 {
        self.total_transactions
    }

    #[wasm_bindgen(getter)]
    pub fn total_income(&self) -> String {
        self.total_income.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn total_expenses(&self) -> String {
        self.total_expenses.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn net_flow(&self) -> String {
        self.net_flow.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn avg_transaction_amount(&self) -> String {
        self.avg_transaction_amount.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn currency(&self) -> String {
        self.currency.clone()
    }
}

/// 批量交易操作请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct BulkTransactionRequest {
    transaction_ids: Vec<String>,
    operation: BulkOperation,
    category_id: Option<String>,
    status: Option<TransactionStatus>,
    tags_to_add: Vec<String>,
    tags_to_remove: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum BulkOperation {
    UpdateCategory,
    UpdateStatus,
    AddTags,
    RemoveTags,
    Delete,
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl BulkOperation {
    #[wasm_bindgen(getter)]
    pub fn as_string(&self) -> String {
        match self {
            BulkOperation::UpdateCategory => "update_category".to_string(),
            BulkOperation::UpdateStatus => "update_status".to_string(),
            BulkOperation::AddTags => "add_tags".to_string(),
            BulkOperation::RemoveTags => "remove_tags".to_string(),
            BulkOperation::Delete => "delete".to_string(),
        }
    }
}

/// 交易服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct TransactionService {
    // 在实际实现中，这里会包含数据库连接或仓储接口
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl TransactionService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {}
    }

    /// 创建交易
    #[wasm_bindgen]
    pub async fn create_transaction(
        &self,
        request: CreateTransactionRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Transaction> {
        let result = self._create_transaction(request, context).await;
        result.into()
    }

    /// 更新交易
    #[wasm_bindgen]
    pub async fn update_transaction(
        &self,
        transaction_id: String,
        request: UpdateTransactionRequest,
        context: ServiceContext,
    ) -> ServiceResponse<Transaction> {
        let result = self._update_transaction(transaction_id, request, context).await;
        result.into()
    }

    /// 获取交易详情
    #[wasm_bindgen]
    pub async fn get_transaction(
        &self,
        transaction_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Transaction> {
        let result = self._get_transaction(transaction_id, context).await;
        result.into()
    }

    /// 删除交易
    #[wasm_bindgen]
    pub async fn delete_transaction(
        &self,
        transaction_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._delete_transaction(transaction_id, context).await;
        result.into()
    }

    /// 搜索交易
    #[wasm_bindgen]
    pub async fn search_transactions(
        &self,
        filter: TransactionFilter,
        pagination: PaginationParams,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<Transaction>> {
        let result = self._search_transactions(filter, pagination, context).await;
        result.into()
    }

    /// 获取交易统计
    #[wasm_bindgen]
    pub async fn get_transaction_stats(
        &self,
        filter: TransactionFilter,
        context: ServiceContext,
    ) -> ServiceResponse<TransactionStats> {
        let result = self._get_transaction_stats(filter, context).await;
        result.into()
    }

    /// 批量操作交易
    #[wasm_bindgen]
    pub async fn bulk_update_transactions(
        &self,
        request: BulkTransactionRequest,
        context: ServiceContext,
    ) -> ServiceResponse<BatchResult> {
        let result = self._bulk_update_transactions(request, context).await;
        result.into()
    }

    /// 复制交易
    #[wasm_bindgen]
    pub async fn duplicate_transaction(
        &self,
        transaction_id: String,
        new_date: Option<String>,
        context: ServiceContext,
    ) -> ServiceResponse<Transaction> {
        let result = self._duplicate_transaction(transaction_id, new_date, context).await;
        result.into()
    }

    /// 按月分组交易
    #[wasm_bindgen]
    pub async fn group_by_month(
        &self,
        filter: TransactionFilter,
        context: ServiceContext,
    ) -> ServiceResponse<HashMap<String, Vec<Transaction>>> {
        let result = self._group_by_month(filter, context).await;
        result.into()
    }

    /// 按分类分组交易
    #[wasm_bindgen]
    pub async fn group_by_category(
        &self,
        filter: TransactionFilter,
        context: ServiceContext,
    ) -> ServiceResponse<HashMap<String, Vec<Transaction>>> {
        let result = self._group_by_category(filter, context).await;
        result.into()
    }

    /// 添加交易标签
    #[wasm_bindgen]
    pub async fn add_tags(
        &self,
        transaction_id: String,
        tags: Vec<String>,
        context: ServiceContext,
    ) -> ServiceResponse<Transaction> {
        let result = self._add_tags(transaction_id, tags, context).await;
        result.into()
    }

    /// 移除交易标签
    #[wasm_bindgen]
    pub async fn remove_tags(
        &self,
        transaction_id: String,
        tags: Vec<String>,
        context: ServiceContext,
    ) -> ServiceResponse<Transaction> {
        let result = self._remove_tags(transaction_id, tags, context).await;
        result.into()
    }

    /// 自动分类交易（AI功能）
    #[wasm_bindgen]
    pub async fn auto_categorize(
        &self,
        transaction_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Transaction> {
        let result = self._auto_categorize(transaction_id, context).await;
        result.into()
    }
}

impl TransactionService {
    /// 创建交易的内部实现
    async fn _create_transaction(
        &self,
        request: CreateTransactionRequest,
        _context: ServiceContext,
    ) -> Result<Transaction> {
        // 验证输入
        if request.name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Transaction name is required".to_string(),
            });
        }

        // 验证金额
        crate::utils::Validator::validate_transaction_amount(&request.amount)?;

        // 创建交易
        let mut transaction = Transaction::builder()
            .account_id(request.account_id)
            .ledger_id(request.ledger_id)
            .name(request.name)
            .amount(request.amount)
            .currency(request.currency)
            .date(NaiveDate::parse_from_str(&request.date, "%Y-%m-%d").map_err(|_| {
                JiveError::InvalidDate { date: request.date.clone() }
            })?)
            .transaction_type(request.transaction_type)
            .build()?;

        // 设置可选字段
        if let Some(category_id) = request.category_id {
            transaction.set_category_id(Some(category_id));
        }

        if let Some(payee_id) = request.payee_id {
            transaction.set_payee_id(Some(payee_id));
        }

        if let Some(description) = request.description {
            transaction.set_description(Some(description))?;
        }

        if let Some(notes) = request.notes {
            transaction.set_notes(Some(notes))?;
        }

        if let Some(reference) = request.reference {
            transaction.set_reference(Some(reference));
        }

        // 添加标签
        for tag in request.tags {
            transaction.add_tag(tag)?;
        }

        // 设置多货币信息
        if let (Some(original_amount), Some(original_currency), Some(exchange_rate)) = 
            (request.original_amount, request.original_currency, request.exchange_rate) {
            transaction.set_multi_currency(original_amount, original_currency, exchange_rate)?;
        }

        // 在实际实现中，这里会保存到数据库并更新账户余额
        // let saved_transaction = repository.save(transaction).await?;
        // account_service.update_balance_from_transaction(&saved_transaction).await?;

        Ok(transaction)
    }

    /// 更新交易的内部实现
    async fn _update_transaction(
        &self,
        transaction_id: String,
        request: UpdateTransactionRequest,
        _context: ServiceContext,
    ) -> Result<Transaction> {
        // 获取现有交易
        let mut transaction = self._get_transaction(transaction_id, _context).await?;

        // 应用更新
        if let Some(name) = request.name {
            transaction.set_name(name)?;
        }

        if let Some(amount) = request.amount {
            transaction.set_amount(amount)?;
        }

        if let Some(date) = request.date {
            transaction.set_date(date)?;
        }

        if let Some(category_id) = request.category_id {
            transaction.set_category_id(Some(category_id));
        }

        if let Some(payee_id) = request.payee_id {
            transaction.set_payee_id(Some(payee_id));
        }

        if let Some(description) = request.description {
            transaction.set_description(Some(description))?;
        }

        if let Some(notes) = request.notes {
            transaction.set_notes(Some(notes))?;
        }

        if let Some(reference) = request.reference {
            transaction.set_reference(Some(reference));
        }

        if let Some(status) = request.status {
            transaction.set_status(status);
        }

        // 在实际实现中，这里会保存到数据库
        // let updated_transaction = repository.save(transaction).await?;

        Ok(transaction)
    }

    /// 获取交易的内部实现
    async fn _get_transaction(
        &self,
        transaction_id: String,
        _context: ServiceContext,
    ) -> Result<Transaction> {
        // 在实际实现中，从数据库获取交易
        if transaction_id.is_empty() {
            return Err(JiveError::TransactionNotFound { id: transaction_id });
        }

        // 模拟交易获取
        let transaction = Transaction::new(
            "account-123".to_string(),
            "ledger-456".to_string(),
            "Test Transaction".to_string(),
            "100.00".to_string(),
            "USD".to_string(),
            "2023-12-25".to_string(),
            TransactionType::Expense,
        )?;

        Ok(transaction)
    }

    /// 删除交易的内部实现
    async fn _delete_transaction(
        &self,
        transaction_id: String,
        _context: ServiceContext,
    ) -> Result<bool> {
        // 检查交易是否存在
        let mut transaction = self._get_transaction(transaction_id, _context).await?;

        // 执行软删除
        transaction.soft_delete();

        // 在实际实现中，这里会保存到数据库并更新账户余额
        // repository.save(transaction).await?;
        // account_service.update_balance_from_deleted_transaction(&transaction).await?;

        Ok(true)
    }

    /// 搜索交易的内部实现
    async fn _search_transactions(
        &self,
        filter: TransactionFilter,
        _pagination: PaginationParams,
        _context: ServiceContext,
    ) -> Result<Vec<Transaction>> {
        // 在实际实现中，构建查询并执行
        // 这里只是模拟实现
        let mut transactions = Vec::new();

        // 模拟一些交易数据
        for i in 1..=5 {
            let transaction = Transaction::new(
                format!("account-{}", i),
                filter.ledger_id.clone().unwrap_or_else(|| "ledger-default".to_string()),
                format!("Transaction {}", i),
                format!("{}.00", i * 100),
                "USD".to_string(),
                "2023-12-25".to_string(),
                if i % 2 == 0 { TransactionType::Income } else { TransactionType::Expense },
            )?;
            transactions.push(transaction);
        }

        Ok(transactions)
    }

    /// 获取统计信息的内部实现
    async fn _get_transaction_stats(
        &self,
        _filter: TransactionFilter,
        _context: ServiceContext,
    ) -> Result<TransactionStats> {
        // 在实际实现中，从数据库聚合统计数据
        let stats = TransactionStats {
            total_transactions: 25,
            total_income: "5000.00".to_string(),
            total_expenses: "3500.00".to_string(),
            net_flow: "1500.00".to_string(),
            by_category: HashMap::new(),
            by_month: HashMap::new(),
            avg_transaction_amount: "140.00".to_string(),
            currency: "USD".to_string(),
        };

        Ok(stats)
    }

    /// 批量更新的内部实现
    async fn _bulk_update_transactions(
        &self,
        request: BulkTransactionRequest,
        context: ServiceContext,
    ) -> Result<BatchResult> {
        let mut result = BatchResult::new();

        for transaction_id in request.transaction_ids {
            match self._apply_bulk_operation(&transaction_id, &request, &context).await {
                Ok(_) => result.add_success(),
                Err(error) => result.add_error(error.to_string()),
            }
        }

        Ok(result)
    }

    /// 应用批量操作
    async fn _apply_bulk_operation(
        &self,
        transaction_id: &str,
        request: &BulkTransactionRequest,
        context: &ServiceContext,
    ) -> Result<()> {
        let mut transaction = self._get_transaction(transaction_id.to_string(), context.clone()).await?;

        match request.operation {
            BulkOperation::UpdateCategory => {
                if let Some(ref category_id) = request.category_id {
                    transaction.set_category_id(Some(category_id.clone()));
                }
            }
            BulkOperation::UpdateStatus => {
                if let Some(status) = request.status.clone() {
                    transaction.set_status(status);
                }
            }
            BulkOperation::AddTags => {
                for tag in &request.tags_to_add {
                    transaction.add_tag(tag.clone())?;
                }
            }
            BulkOperation::RemoveTags => {
                for tag in &request.tags_to_remove {
                    transaction.remove_tag(tag.clone());
                }
            }
            BulkOperation::Delete => {
                transaction.soft_delete();
            }
        }

        // 在实际实现中，这里会保存到数据库
        // repository.save(transaction).await?;

        Ok(())
    }

    /// 复制交易的内部实现
    async fn _duplicate_transaction(
        &self,
        transaction_id: String,
        new_date: Option<String>,
        context: ServiceContext,
    ) -> Result<Transaction> {
        let original_transaction = self._get_transaction(transaction_id, context).await?;
        let mut duplicated = original_transaction.duplicate();

        if let Some(date_str) = new_date {
            duplicated.set_date(date_str)?;
        }

        // 在实际实现中，这里会保存到数据库
        // let saved_transaction = repository.save(duplicated).await?;

        Ok(duplicated)
    }

    /// 按月分组的内部实现
    async fn _group_by_month(
        &self,
        filter: TransactionFilter,
        context: ServiceContext,
    ) -> Result<HashMap<String, Vec<Transaction>>> {
        let transactions = self._search_transactions(filter, PaginationParams::new(1, 1000), context).await?;

        let mut grouped = HashMap::new();
        for transaction in transactions {
            let month_key = transaction.month_key();
            grouped.entry(month_key).or_insert_with(Vec::new).push(transaction);
        }

        Ok(grouped)
    }

    /// 按分类分组的内部实现
    async fn _group_by_category(
        &self,
        filter: TransactionFilter,
        context: ServiceContext,
    ) -> Result<HashMap<String, Vec<Transaction>>> {
        let transactions = self._search_transactions(filter, PaginationParams::new(1, 1000), context).await?;

        let mut grouped = HashMap::new();
        for transaction in transactions {
            let category_key = transaction.category_id()
                .unwrap_or_else(|| "uncategorized".to_string());
            grouped.entry(category_key).or_insert_with(Vec::new).push(transaction);
        }

        Ok(grouped)
    }

    /// 添加标签的内部实现
    async fn _add_tags(
        &self,
        transaction_id: String,
        tags: Vec<String>,
        context: ServiceContext,
    ) -> Result<Transaction> {
        let mut transaction = self._get_transaction(transaction_id, context).await?;

        for tag in tags {
            transaction.add_tag(tag)?;
        }

        // 在实际实现中，这里会保存到数据库
        // let updated_transaction = repository.save(transaction).await?;

        Ok(transaction)
    }

    /// 移除标签的内部实现
    async fn _remove_tags(
        &self,
        transaction_id: String,
        tags: Vec<String>,
        context: ServiceContext,
    ) -> Result<Transaction> {
        let mut transaction = self._get_transaction(transaction_id, context).await?;

        for tag in tags {
            transaction.remove_tag(tag);
        }

        // 在实际实现中，这里会保存到数据库
        // let updated_transaction = repository.save(transaction).await?;

        Ok(transaction)
    }

    /// 自动分类的内部实现（AI功能）
    async fn _auto_categorize(
        &self,
        transaction_id: String,
        context: ServiceContext,
    ) -> Result<Transaction> {
        let mut transaction = self._get_transaction(transaction_id, context).await?;

        // 在实际实现中，这里会调用AI服务进行自动分类
        // let suggested_category = ai_service.categorize_transaction(&transaction).await?;
        // transaction.set_category_id(Some(suggested_category.id));
        // transaction.set_confidence_score(Some(suggested_category.confidence));

        // 模拟AI分类结果
        transaction.set_category_id(Some("food-category-id".to_string()));
        transaction.set_confidence_score(Some(0.85));
        transaction.mark_as_automated(Some(0.85));

        Ok(transaction)
    }
}

impl Default for TransactionService {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_create_transaction() {
        let service = TransactionService::new();
        let context = ServiceContext::new("user-123".to_string());
        
        let request = CreateTransactionRequest::new(
            "account-123".to_string(),
            "ledger-456".to_string(),
            "Test Transaction".to_string(),
            "100.50".to_string(),
            "USD".to_string(),
            "2023-12-25".to_string(),
            TransactionType::Expense,
        );

        let result = service._create_transaction(request, context).await;
        assert!(result.is_ok());

        let transaction = result.unwrap();
        assert_eq!(transaction.name(), "Test Transaction");
        assert_eq!(transaction.amount(), "100.50");
    }

    #[tokio::test]
    async fn test_search_transactions() {
        let service = TransactionService::new();
        let context = ServiceContext::new("user-123".to_string());
        
        let filter = TransactionFilter::new();
        let pagination = PaginationParams::new(1, 10);

        let result = service._search_transactions(filter, pagination, context).await;
        assert!(result.is_ok());

        let transactions = result.unwrap();
        assert!(!transactions.is_empty());
    }

    #[tokio::test]
    async fn test_transaction_validation() {
        let service = TransactionService::new();
        let context = ServiceContext::new("user-123".to_string());
        
        let request = CreateTransactionRequest::new(
            "account-123".to_string(),
            "ledger-456".to_string(),
            "".to_string(), // 空名称应该失败
            "100.50".to_string(),
            "USD".to_string(),
            "2023-12-25".to_string(),
            TransactionType::Expense,
        );

        let result = service._create_transaction(request, context).await;
        assert!(result.is_err());
    }
}