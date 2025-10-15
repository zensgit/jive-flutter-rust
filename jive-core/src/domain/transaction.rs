//! Transaction domain model

use chrono::{DateTime, Datelike, NaiveDate, Utc};
use serde::{Deserialize, Serialize};

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use super::{Entity, SoftDeletable, TransactionStatus, TransactionType};
use crate::error::{JiveError, Result};

/// 交易实体
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct Transaction {
    id: String,
    account_id: String,
    ledger_id: String,
    category_id: Option<String>,
    payee_id: Option<String>,
    name: String,
    description: Option<String>,
    amount: String, // 使用字符串存储以避免精度问题
    currency: String,
    date: NaiveDate,
    transaction_type: TransactionType,
    status: TransactionStatus,
    reference: Option<String>, // 参考号或支票号
    notes: Option<String>,
    tags: Vec<String>,
    // 多货币支持
    original_amount: Option<String>,
    original_currency: Option<String>,
    exchange_rate: Option<String>,
    // 外部集成
    external_id: Option<String>,
    plaid_transaction_id: Option<String>,
    // 审计字段
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
    deleted_at: Option<DateTime<Utc>>,
    // 规则和自动化
    created_by_rule: bool,
    confidence_score: Option<f32>, // AI 分类的置信度
}

#[cfg(feature = "wasm")]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
impl Transaction {
    #[wasm_bindgen(constructor)]
    pub fn new(
        account_id: String,
        ledger_id: String,
        name: String,
        amount: String,
        currency: String,
        date: String,
        transaction_type: TransactionType,
    ) -> Result<Transaction> {
        let parsed_date = NaiveDate::parse_from_str(&date, "%Y-%m-%d")
            .map_err(|_| JiveError::InvalidDate { date })?;

        // 验证金额
        crate::utils::Validator::validate_transaction_amount(&amount)?;
        crate::error::validate_currency(&currency)?;

        // 验证名称
        if name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Transaction name cannot be empty".to_string(),
            });
        }

        let now = Utc::now();

        Ok(Transaction {
            id: crate::utils::generate_id(),
            account_id,
            ledger_id,
            category_id: None,
            payee_id: None,
            name: name.trim().to_string(),
            description: None,
            amount,
            currency,
            date: parsed_date,
            transaction_type,
            status: TransactionStatus::Completed,
            reference: None,
            notes: None,
            tags: Vec::new(),
            original_amount: None,
            original_currency: None,
            exchange_rate: None,
            external_id: None,
            plaid_transaction_id: None,
            created_at: now,
            updated_at: now,
            deleted_at: None,
            created_by_rule: false,
            confidence_score: None,
        })
    }

    // Getters
    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn id(&self) -> String {
        self.id.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn account_id(&self) -> String {
        self.account_id.clone()
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn ledger_id(&self) -> String {
        self.ledger_id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn category_id(&self) -> Option<String> {
        self.category_id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn payee_id(&self) -> Option<String> {
        self.payee_id.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn name(&self) -> String {
        self.name.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn description(&self) -> Option<String> {
        self.description.clone()
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
        self.date.to_string()
    }

    #[wasm_bindgen(getter)]
    pub fn transaction_type(&self) -> TransactionType {
        self.transaction_type.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn status(&self) -> TransactionStatus {
        self.status.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn reference(&self) -> Option<String> {
        self.reference.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn notes(&self) -> Option<String> {
        self.notes.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn tags(&self) -> Vec<String> {
        self.tags.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn created_at(&self) -> String {
        self.created_at.to_rfc3339()
    }

    #[wasm_bindgen(getter)]
    pub fn updated_at(&self) -> String {
        self.updated_at.to_rfc3339()
    }

    #[wasm_bindgen(getter)]
    pub fn is_deleted(&self) -> bool {
        self.deleted_at.is_some()
    }

    #[wasm_bindgen(getter)]
    pub fn created_by_rule(&self) -> bool {
        self.created_by_rule
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(getter))]
    pub fn confidence_score(&self) -> Option<f32> {
        self.confidence_score
    }

    // Setters
    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_name(&mut self, name: String) -> Result<()> {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Transaction name cannot be empty".to_string(),
            });
        }
        self.name = trimmed.to_string();
        self.updated_at = Utc::now();
        Ok(())
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_description(&mut self, description: Option<String>) -> Result<()> {
        if let Some(ref desc) = description {
            crate::utils::Validator::validate_description(desc)?;
        }
        self.description = description;
        self.updated_at = Utc::now();
        Ok(())
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_amount(&mut self, amount: String) -> Result<()> {
        crate::utils::Validator::validate_transaction_amount(&amount)?;
        self.amount = amount;
        self.updated_at = Utc::now();
        Ok(())
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_date(&mut self, date: String) -> Result<()> {
        let parsed_date = NaiveDate::parse_from_str(&date, "%Y-%m-%d")
            .map_err(|_| JiveError::InvalidDate { date })?;
        self.date = parsed_date;
        self.updated_at = Utc::now();
        Ok(())
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_category_id(&mut self, category_id: Option<String>) {
        self.category_id = category_id;
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_payee_id(&mut self, payee_id: Option<String>) {
        self.payee_id = payee_id;
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_status(&mut self, status: TransactionStatus) {
        self.status = status;
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_reference(&mut self, reference: Option<String>) {
        self.reference = reference;
        self.updated_at = Utc::now();
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_notes(&mut self, notes: Option<String>) -> Result<()> {
        if let Some(ref n) = notes {
            crate::utils::Validator::validate_description(n)?;
        }
        self.notes = notes;
        self.updated_at = Utc::now();
        Ok(())
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen(setter))]
    pub fn set_confidence_score(&mut self, score: Option<f32>) {
        self.confidence_score = score;
        self.updated_at = Utc::now();
    }

    // 业务方法
    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn add_tag(&mut self, tag: String) -> Result<()> {
        let cleaned_tag = crate::utils::StringUtils::clean_text(&tag);
        if cleaned_tag.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Tag cannot be empty".to_string(),
            });
        }

        if !self.tags.contains(&cleaned_tag) {
            self.tags.push(cleaned_tag);
            self.updated_at = Utc::now();
        }
        Ok(())
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn remove_tag(&mut self, tag: String) {
        if let Some(pos) = self.tags.iter().position(|t| t == &tag) {
            self.tags.remove(pos);
            self.updated_at = Utc::now();
        }
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn has_tag(&self, tag: String) -> bool {
        self.tags.contains(&tag)
    }

    #[cfg_attr(feature = "wasm", wasm_bindgen)]
    pub fn clear_tags(&mut self) {
        if !self.tags.is_empty() {
            self.tags.clear();
            self.updated_at = Utc::now();
        }
    }

    #[wasm_bindgen]
    pub fn formatted_amount(&self) -> String {
        crate::utils::format_amount(&self.amount, &self.currency)
    }

    #[wasm_bindgen]
    pub fn is_income(&self) -> bool {
        matches!(self.transaction_type, TransactionType::Income)
    }

    #[wasm_bindgen]
    pub fn is_expense(&self) -> bool {
        matches!(self.transaction_type, TransactionType::Expense)
    }

    #[wasm_bindgen]
    pub fn is_transfer(&self) -> bool {
        matches!(self.transaction_type, TransactionType::Transfer)
    }

    #[wasm_bindgen]
    pub fn is_pending(&self) -> bool {
        matches!(self.status, TransactionStatus::Pending)
    }

    #[wasm_bindgen]
    pub fn is_completed(&self) -> bool {
        matches!(self.status, TransactionStatus::Completed)
    }

    #[wasm_bindgen]
    pub fn set_multi_currency(
        &mut self,
        original_amount: String,
        original_currency: String,
        exchange_rate: String,
    ) -> Result<()> {
        crate::error::validate_currency(&original_currency)?;
        crate::utils::Validator::validate_transaction_amount(&original_amount)?;
        crate::utils::Validator::validate_transaction_amount(&exchange_rate)?;

        self.original_amount = Some(original_amount);
        self.original_currency = Some(original_currency);
        self.exchange_rate = Some(exchange_rate);
        self.updated_at = Utc::now();
        Ok(())
    }

    #[wasm_bindgen]
    pub fn clear_multi_currency(&mut self) {
        self.original_amount = None;
        self.original_currency = None;
        self.exchange_rate = None;
        self.updated_at = Utc::now();
    }

    #[wasm_bindgen]
    pub fn is_multi_currency(&self) -> bool {
        self.original_currency.is_some()
    }

    #[wasm_bindgen]
    pub fn mark_as_automated(&mut self, confidence: Option<f32>) {
        self.created_by_rule = true;
        self.confidence_score = confidence;
        self.updated_at = Utc::now();
    }

    #[wasm_bindgen]
    pub fn soft_delete(&mut self) {
        self.deleted_at = Some(Utc::now());
        self.updated_at = Utc::now();
    }

    #[wasm_bindgen]
    pub fn restore(&mut self) {
        self.deleted_at = None;
        self.updated_at = Utc::now();
    }

    /// 获取签名金额（收入为正，支出为负）
    #[wasm_bindgen]
    pub fn signed_amount(&self) -> String {
        let amount = self.amount.parse::<Decimal>().unwrap_or_default();
        match self.transaction_type {
            TransactionType::Income => amount.to_string(),
            TransactionType::Expense => (-amount).to_string(),
            TransactionType::Transfer => amount.to_string(), // 转账的符号由上下文决定
        }
    }

    /// 获取月份键（用于分组）
    #[wasm_bindgen]
    pub fn month_key(&self) -> String {
        format!("{}-{:02}", self.date.year(), self.date.month())
    }

    /// 检查是否为本月交易
    #[wasm_bindgen]
    pub fn is_current_month(&self) -> bool {
        let now = Utc::now().naive_utc().date();
        self.date.year() == now.year() && self.date.month() == now.month()
    }

    /// 检查是否为本年交易
    #[wasm_bindgen]
    pub fn is_current_year(&self) -> bool {
        let now = Utc::now().naive_utc().date();
        self.date.year() == now.year()
    }
}

impl Transaction {
    /// 从 JSON 创建交易
    pub fn from_json(json: &str) -> Result<Self> {
        serde_json::from_str(json).map_err(|e| JiveError::SerializationError {
            message: e.to_string(),
        })
    }

    /// 转换为 JSON
    pub fn to_json(&self) -> Result<String> {
        serde_json::to_string(self).map_err(|e| JiveError::SerializationError {
            message: e.to_string(),
        })
    }

    /// 创建交易的 builder 模式
    pub fn builder() -> TransactionBuilder {
        TransactionBuilder::new()
    }

    /// 复制交易（新ID）
    pub fn duplicate(&self) -> Self {
        let mut duplicate = self.clone();
        duplicate.id = crate::utils::generate_id();
        duplicate.created_at = Utc::now();
        duplicate.updated_at = Utc::now();
        duplicate.deleted_at = None;
        duplicate.external_id = None;
        duplicate.plaid_transaction_id = None;
        duplicate
    }

    /// 获取搜索关键词
    pub fn search_keywords(&self) -> Vec<String> {
        let mut keywords = Vec::new();
        keywords.push(self.name.to_lowercase());

        if let Some(desc) = &self.description {
            keywords.push(desc.to_lowercase());
        }

        if let Some(notes) = &self.notes {
            keywords.push(notes.to_lowercase());
        }

        keywords.extend(self.tags.iter().map(|tag| tag.to_lowercase()));
        keywords
    }

    /// 业务方法 - 非WASM环境
    #[cfg(not(feature = "wasm"))]
    pub fn add_tag(&mut self, tag: String) -> Result<()> {
        let cleaned_tag = crate::utils::StringUtils::clean_text(&tag);
        if cleaned_tag.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Tag cannot be empty".to_string(),
            });
        }

        if !self.tags.contains(&cleaned_tag) {
            self.tags.push(cleaned_tag);
            self.updated_at = Utc::now();
        }
        Ok(())
    }

    #[cfg(not(feature = "wasm"))]
    pub fn remove_tag(&mut self, tag: String) {
        if let Some(pos) = self.tags.iter().position(|t| t == &tag) {
            self.tags.remove(pos);
            self.updated_at = Utc::now();
        }
    }

    #[cfg(not(feature = "wasm"))]
    pub fn has_tag(&self, tag: String) -> bool {
        self.tags.contains(&tag)
    }

    #[cfg(not(feature = "wasm"))]
    pub fn is_income(&self) -> bool {
        matches!(self.transaction_type, TransactionType::Income)
    }

    #[cfg(not(feature = "wasm"))]
    pub fn is_expense(&self) -> bool {
        matches!(self.transaction_type, TransactionType::Expense)
    }

    #[cfg(not(feature = "wasm"))]
    pub fn is_transfer(&self) -> bool {
        matches!(self.transaction_type, TransactionType::Transfer)
    }

    #[cfg(not(feature = "wasm"))]
    pub fn is_pending(&self) -> bool {
        matches!(self.status, TransactionStatus::Pending)
    }

    #[cfg(not(feature = "wasm"))]
    pub fn is_completed(&self) -> bool {
        matches!(self.status, TransactionStatus::Completed)
    }

    #[cfg(not(feature = "wasm"))]
    pub fn set_multi_currency(
        &mut self,
        original_amount: String,
        original_currency: String,
        exchange_rate: String,
    ) -> Result<()> {
        crate::error::validate_currency(&original_currency)?;
        crate::utils::Validator::validate_transaction_amount(&original_amount)?;
        crate::utils::Validator::validate_transaction_amount(&exchange_rate)?;

        self.original_amount = Some(original_amount);
        self.original_currency = Some(original_currency);
        self.exchange_rate = Some(exchange_rate);
        self.updated_at = Utc::now();
        Ok(())
    }

    #[cfg(not(feature = "wasm"))]
    pub fn clear_multi_currency(&mut self) {
        self.original_amount = None;
        self.original_currency = None;
        self.exchange_rate = None;
        self.updated_at = Utc::now();
    }

    #[cfg(not(feature = "wasm"))]
    pub fn is_multi_currency(&self) -> bool {
        self.original_currency.is_some()
    }

    #[cfg(not(feature = "wasm"))]
    pub fn signed_amount(&self) -> String {
        use rust_decimal::Decimal;
        let amount = self.amount.parse::<Decimal>().unwrap_or_default();
        match self.transaction_type {
            TransactionType::Income => amount.to_string(),
            TransactionType::Expense => (-amount).to_string(),
            TransactionType::Transfer => amount.to_string(),
        }
    }

    #[cfg(not(feature = "wasm"))]
    pub fn month_key(&self) -> String {
        format!("{}-{:02}", self.date.year(), self.date.month())
    }
}

impl Entity for Transaction {
    type Id = String;

    fn id(&self) -> &Self::Id {
        &self.id
    }

    fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }

    fn updated_at(&self) -> DateTime<Utc> {
        self.updated_at
    }
}

impl SoftDeletable for Transaction {
    fn is_deleted(&self) -> bool {
        self.deleted_at.is_some()
    }
    fn deleted_at(&self) -> Option<DateTime<Utc>> {
        self.deleted_at
    }
    fn soft_delete(&mut self) {
        self.deleted_at = Some(Utc::now());
    }
    fn restore(&mut self) {
        self.deleted_at = None;
    }
}

/// 交易构建器
pub struct TransactionBuilder {
    account_id: Option<String>,
    ledger_id: Option<String>,
    category_id: Option<String>,
    payee_id: Option<String>,
    name: Option<String>,
    description: Option<String>,
    amount: Option<String>,
    currency: Option<String>,
    date: Option<NaiveDate>,
    transaction_type: Option<TransactionType>,
    status: TransactionStatus,
    reference: Option<String>,
    notes: Option<String>,
    tags: Vec<String>,
    external_id: Option<String>,
}

impl TransactionBuilder {
    pub fn new() -> Self {
        Self {
            account_id: None,
            ledger_id: None,
            category_id: None,
            payee_id: None,
            name: None,
            description: None,
            amount: None,
            currency: None,
            date: None,
            transaction_type: None,
            status: TransactionStatus::Completed,
            reference: None,
            notes: None,
            tags: Vec::new(),
            external_id: None,
        }
    }

    pub fn account_id(mut self, account_id: String) -> Self {
        self.account_id = Some(account_id);
        self
    }

    pub fn ledger_id(mut self, ledger_id: String) -> Self {
        self.ledger_id = Some(ledger_id);
        self
    }

    pub fn category_id(mut self, category_id: String) -> Self {
        self.category_id = Some(category_id);
        self
    }

    pub fn payee_id(mut self, payee_id: String) -> Self {
        self.payee_id = Some(payee_id);
        self
    }

    pub fn name(mut self, name: String) -> Self {
        self.name = Some(name);
        self
    }

    pub fn description(mut self, description: String) -> Self {
        self.description = Some(description);
        self
    }

    pub fn amount(mut self, amount: String) -> Self {
        self.amount = Some(amount);
        self
    }

    pub fn currency(mut self, currency: String) -> Self {
        self.currency = Some(currency);
        self
    }

    pub fn date(mut self, date: NaiveDate) -> Self {
        self.date = Some(date);
        self
    }

    pub fn transaction_type(mut self, transaction_type: TransactionType) -> Self {
        self.transaction_type = Some(transaction_type);
        self
    }

    pub fn status(mut self, status: TransactionStatus) -> Self {
        self.status = status;
        self
    }

    pub fn reference(mut self, reference: String) -> Self {
        self.reference = Some(reference);
        self
    }

    pub fn notes(mut self, notes: String) -> Self {
        self.notes = Some(notes);
        self
    }

    pub fn tag(mut self, tag: String) -> Self {
        self.tags.push(tag);
        self
    }

    pub fn tags(mut self, tags: Vec<String>) -> Self {
        self.tags = tags;
        self
    }

    pub fn external_id(mut self, external_id: String) -> Self {
        self.external_id = Some(external_id);
        self
    }

    pub fn build(self) -> Result<Transaction> {
        let account_id = self.account_id.ok_or_else(|| JiveError::ValidationError {
            message: "Account ID is required".to_string(),
        })?;

        let ledger_id = self.ledger_id.ok_or_else(|| JiveError::ValidationError {
            message: "Ledger ID is required".to_string(),
        })?;

        let name = self.name.ok_or_else(|| JiveError::ValidationError {
            message: "Transaction name is required".to_string(),
        })?;

        let amount = self.amount.ok_or_else(|| JiveError::ValidationError {
            message: "Amount is required".to_string(),
        })?;

        let currency = self.currency.ok_or_else(|| JiveError::ValidationError {
            message: "Currency is required".to_string(),
        })?;

        let date = self.date.ok_or_else(|| JiveError::ValidationError {
            message: "Date is required".to_string(),
        })?;

        let transaction_type = self
            .transaction_type
            .ok_or_else(|| JiveError::ValidationError {
                message: "Transaction type is required".to_string(),
            })?;

        // 验证输入
        crate::utils::Validator::validate_transaction_amount(&amount)?;
        crate::error::validate_currency(&currency)?;

        if name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Transaction name cannot be empty".to_string(),
            });
        }

        let now = Utc::now();

        Ok(Transaction {
            id: crate::utils::generate_id(),
            account_id,
            ledger_id,
            category_id: self.category_id,
            payee_id: self.payee_id,
            name: name.trim().to_string(),
            description: self.description,
            amount,
            currency,
            date,
            transaction_type,
            status: self.status,
            reference: self.reference,
            notes: self.notes,
            tags: self.tags,
            original_amount: None,
            original_currency: None,
            exchange_rate: None,
            external_id: self.external_id,
            plaid_transaction_id: None,
            created_at: now,
            updated_at: now,
            deleted_at: None,
            created_by_rule: false,
            confidence_score: None,
        })
    }
}

impl Default for TransactionBuilder {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::NaiveDate;

    #[test]
    fn test_transaction_creation() {
        let transaction = Transaction::builder()
            .account_id("account-123".to_string())
            .ledger_id("ledger-456".to_string())
            .name("Test Transaction".to_string())
            .amount("100.50".to_string())
            .currency("USD".to_string())
            .date(NaiveDate::from_ymd_opt(2023, 12, 25).unwrap())
            .transaction_type(TransactionType::Expense)
            .build()
            .unwrap();

        assert_eq!(transaction.name, "Test Transaction");
        assert_eq!(transaction.amount, "100.50");
        assert_eq!(transaction.currency, "USD");
        assert!(transaction.is_expense());
        assert!(transaction.is_completed());
    }

    #[test]
    fn test_transaction_tags() {
        let mut transaction = Transaction::builder()
            .account_id("account-123".to_string())
            .ledger_id("ledger-456".to_string())
            .name("Test Transaction".to_string())
            .amount("100.50".to_string())
            .currency("USD".to_string())
            .date(NaiveDate::from_ymd_opt(2023, 12, 25).unwrap())
            .transaction_type(TransactionType::Expense)
            .build()
            .unwrap();

        transaction.add_tag("food".to_string()).unwrap();
        transaction.add_tag("restaurant".to_string()).unwrap();

        assert!(transaction.has_tag("food".to_string()));
        assert!(transaction.has_tag("restaurant".to_string()));
        assert!(!transaction.has_tag("travel".to_string()));

        transaction.remove_tag("food".to_string());
        assert!(!transaction.has_tag("food".to_string()));
    }

    #[test]
    fn test_transaction_builder() {
        let transaction = Transaction::builder()
            .account_id("account-123".to_string())
            .ledger_id("ledger-456".to_string())
            .name("Salary".to_string())
            .amount("5000.00".to_string())
            .currency("USD".to_string())
            .date(NaiveDate::from_ymd_opt(2023, 12, 1).unwrap())
            .transaction_type(TransactionType::Income)
            .description("Monthly salary".to_string())
            .tag("salary".to_string())
            .tag("income".to_string())
            .build()
            .unwrap();

        assert_eq!(transaction.name, "Salary");
        assert_eq!(transaction.amount, "5000.00");
        assert!(transaction.is_income());
        assert_eq!(transaction.tags.len(), 2);
    }

    #[test]
    fn test_multi_currency() {
        let mut transaction = Transaction::builder()
            .account_id("account-123".to_string())
            .ledger_id("ledger-456".to_string())
            .name("Hotel Booking".to_string())
            .amount("720.00".to_string())
            .currency("CNY".to_string())
            .date(NaiveDate::from_ymd_opt(2023, 12, 25).unwrap())
            .transaction_type(TransactionType::Expense)
            .build()
            .unwrap();

        transaction
            .set_multi_currency("100.00".to_string(), "USD".to_string(), "7.20".to_string())
            .unwrap();

        assert!(transaction.is_multi_currency());

        transaction.clear_multi_currency();
        assert!(!transaction.is_multi_currency());
    }

    #[test]
    fn test_signed_amount() {
        let income = Transaction::builder()
            .account_id("account-123".to_string())
            .ledger_id("ledger-456".to_string())
            .name("Income".to_string())
            .amount("1000.00".to_string())
            .currency("USD".to_string())
            .date(NaiveDate::from_ymd_opt(2023, 12, 25).unwrap())
            .transaction_type(TransactionType::Income)
            .build()
            .unwrap();

        let expense = Transaction::builder()
            .account_id("account-123".to_string())
            .ledger_id("ledger-456".to_string())
            .name("Expense".to_string())
            .amount("500.00".to_string())
            .currency("USD".to_string())
            .date(NaiveDate::from_ymd_opt(2023, 12, 25).unwrap())
            .transaction_type(TransactionType::Expense)
            .build()
            .unwrap();

        assert_eq!(income.signed_amount(), "1000.00");
        assert_eq!(expense.signed_amount(), "-500.00");
    }

    #[test]
    fn test_date_helpers() {
        let transaction = Transaction::builder()
            .account_id("account-123".to_string())
            .ledger_id("ledger-456".to_string())
            .name("Test".to_string())
            .amount("100.00".to_string())
            .currency("USD".to_string())
            .date(NaiveDate::from_ymd_opt(2023, 12, 25).unwrap())
            .transaction_type(TransactionType::Expense)
            .build()
            .unwrap();

        assert_eq!(transaction.month_key(), "2023-12");
    }
}
