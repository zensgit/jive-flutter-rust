//! Account domain model - 账户领域模型
//!
//! 基于 Maybe 的 Account 模型转换而来

use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::error::{JiveError, Result};

/// 账户类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum AccountType {
    Checking,   // 支票账户
    Savings,    // 储蓄账户
    CreditCard, // 信用卡
    Investment, // 投资账户
    Loan,       // 贷款
    Cash,       // 现金
    Other,      // 其他
}

/// 账户状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum AccountStatus {
    Active,   // 活跃
    Inactive, // 不活跃
    Closed,   // 关闭
}

/// 账户实体
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct Account {
    id: String,
    name: String,
    account_type: AccountType,
    balance: Decimal,
    currency: String,
    status: AccountStatus,
    ledger_id: String,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

impl Account {
    pub fn new(
        name: String,
        account_type: AccountType,
        currency: String,
        ledger_id: String,
    ) -> Result<Self> {
        if name.trim().is_empty() {
            return Err(JiveError::ValidationError {
                message: "Account name cannot be empty".to_string(),
            });
        }

        let now = Utc::now();

        Ok(Self {
            id: uuid::Uuid::new_v4().to_string(),
            name,
            account_type,
            balance: Decimal::ZERO,
            currency,
            status: AccountStatus::Active,
            ledger_id,
            created_at: now,
            updated_at: now,
        })
    }

    // Getters
    pub fn id(&self) -> String {
        self.id.clone()
    }
    pub fn name(&self) -> String {
        self.name.clone()
    }
    pub fn account_type(&self) -> AccountType {
        self.account_type.clone()
    }
    pub fn balance(&self) -> Decimal {
        self.balance
    }
    pub fn currency(&self) -> String {
        self.currency.clone()
    }
    pub fn status(&self) -> AccountStatus {
        self.status.clone()
    }
    pub fn ledger_id(&self) -> String {
        self.ledger_id.clone()
    }

    // Business methods
    pub fn update_balance(&mut self, new_balance: Decimal) -> Result<()> {
        self.balance = new_balance;
        self.updated_at = Utc::now();
        Ok(())
    }

    pub fn is_active(&self) -> bool {
        self.status == AccountStatus::Active
    }

    /// 账户构建器
    pub fn builder() -> AccountBuilder {
        AccountBuilder::new()
    }
}

/// 账户构建器
#[derive(Debug, Default)]
pub struct AccountBuilder {
    name: Option<String>,
    account_type: Option<AccountType>,
    currency: Option<String>,
    ledger_id: Option<String>,
    balance: Option<Decimal>,
}

impl AccountBuilder {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn name(mut self, name: String) -> Self {
        self.name = Some(name);
        self
    }

    pub fn account_type(mut self, account_type: AccountType) -> Self {
        self.account_type = Some(account_type);
        self
    }

    pub fn currency(mut self, currency: String) -> Self {
        self.currency = Some(currency);
        self
    }

    pub fn ledger_id(mut self, ledger_id: String) -> Self {
        self.ledger_id = Some(ledger_id);
        self
    }

    pub fn balance(mut self, balance: Decimal) -> Self {
        self.balance = Some(balance);
        self
    }

    pub fn build(self) -> Result<Account> {
        let name = self.name.ok_or_else(|| JiveError::ValidationError {
            message: "Account name is required".to_string(),
        })?;

        let account_type = self
            .account_type
            .ok_or_else(|| JiveError::ValidationError {
                message: "Account type is required".to_string(),
            })?;

        let currency = self.currency.ok_or_else(|| JiveError::ValidationError {
            message: "Currency is required".to_string(),
        })?;

        let ledger_id = self.ledger_id.ok_or_else(|| JiveError::ValidationError {
            message: "Ledger ID is required".to_string(),
        })?;

        let mut account = Account::new(name, account_type, currency, ledger_id)?;

        if let Some(balance) = self.balance {
            account.update_balance(balance)?;
        }

        Ok(account)
    }
}
