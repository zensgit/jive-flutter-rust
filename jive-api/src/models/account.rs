use serde::{Deserialize, Serialize};
use sqlx::Type;
use std::fmt;
use std::str::FromStr;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type)]
#[sqlx(type_name = "text", rename_all = "snake_case")]
#[serde(rename_all = "snake_case")]
pub enum AccountMainType {
    Asset,
    Liability,
}

impl fmt::Display for AccountMainType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AccountMainType::Asset => write!(f, "asset"),
            AccountMainType::Liability => write!(f, "liability"),
        }
    }
}

impl FromStr for AccountMainType {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "asset" => Ok(AccountMainType::Asset),
            "liability" => Ok(AccountMainType::Liability),
            _ => Err(format!("Invalid account main type: {}", s)),
        }
    }
}

impl AccountMainType {
    pub fn is_asset(&self) -> bool {
        matches!(self, AccountMainType::Asset)
    }

    pub fn is_liability(&self) -> bool {
        matches!(self, AccountMainType::Liability)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Type)]
#[sqlx(type_name = "text", rename_all = "snake_case")]
#[serde(rename_all = "snake_case")]
pub enum AccountSubType {
    Cash,
    DebitCard,
    SavingsAccount,
    Checking,
    Investment,
    PrepaidCard,
    DigitalWallet,
    Wechat,
    WechatChange,
    Alipay,
    Yuebao,
    UnionPay,
    BankCard,
    ProvidentFund,
    QQWallet,
    JDWallet,
    MedicalInsurance,
    DigitalRMB,
    HuaweiWallet,
    PinduoduoWallet,
    Paypal,
    CreditCard,
    Huabei,
    Jiebei,
    JDWhiteBar,
    MeituanMonthly,
    DouyinMonthly,
    WechatInstallment,
    Loan,
    Mortgage,
    PhoneCredit,
    Utilities,
    MealCard,
    Deposit,
    TransitCard,
    MembershipCard,
    GasCard,
    SinopecWallet,
    AppleAccount,
    Stock,
    Fund,
    Gold,
    Forex,
    Futures,
    Bond,
    FixedIncome,
    Crypto,
    Other,
}

impl fmt::Display for AccountSubType {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            AccountSubType::Cash => "cash",
            AccountSubType::DebitCard => "debit_card",
            AccountSubType::SavingsAccount => "savings_account",
            AccountSubType::Checking => "checking",
            AccountSubType::Investment => "investment",
            AccountSubType::PrepaidCard => "prepaid_card",
            AccountSubType::DigitalWallet => "digital_wallet",
            AccountSubType::Wechat => "wechat",
            AccountSubType::WechatChange => "wechat_change",
            AccountSubType::Alipay => "alipay",
            AccountSubType::Yuebao => "yuebao",
            AccountSubType::UnionPay => "union_pay",
            AccountSubType::BankCard => "bank_card",
            AccountSubType::ProvidentFund => "provident_fund",
            AccountSubType::QQWallet => "qq_wallet",
            AccountSubType::JDWallet => "jd_wallet",
            AccountSubType::MedicalInsurance => "medical_insurance",
            AccountSubType::DigitalRMB => "digital_rmb",
            AccountSubType::HuaweiWallet => "huawei_wallet",
            AccountSubType::PinduoduoWallet => "pinduoduo_wallet",
            AccountSubType::Paypal => "paypal",
            AccountSubType::CreditCard => "credit_card",
            AccountSubType::Huabei => "huabei",
            AccountSubType::Jiebei => "jiebei",
            AccountSubType::JDWhiteBar => "jd_white_bar",
            AccountSubType::MeituanMonthly => "meituan_monthly",
            AccountSubType::DouyinMonthly => "douyin_monthly",
            AccountSubType::WechatInstallment => "wechat_installment",
            AccountSubType::Loan => "loan",
            AccountSubType::Mortgage => "mortgage",
            AccountSubType::PhoneCredit => "phone_credit",
            AccountSubType::Utilities => "utilities",
            AccountSubType::MealCard => "meal_card",
            AccountSubType::Deposit => "deposit",
            AccountSubType::TransitCard => "transit_card",
            AccountSubType::MembershipCard => "membership_card",
            AccountSubType::GasCard => "gas_card",
            AccountSubType::SinopecWallet => "sinopec_wallet",
            AccountSubType::AppleAccount => "apple_account",
            AccountSubType::Stock => "stock",
            AccountSubType::Fund => "fund",
            AccountSubType::Gold => "gold",
            AccountSubType::Forex => "forex",
            AccountSubType::Futures => "futures",
            AccountSubType::Bond => "bond",
            AccountSubType::FixedIncome => "fixed_income",
            AccountSubType::Crypto => "crypto",
            AccountSubType::Other => "other",
        };
        write!(f, "{}", s)
    }
}

impl FromStr for AccountSubType {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.to_lowercase().as_str() {
            "cash" => Ok(AccountSubType::Cash),
            "debit_card" | "debit" => Ok(AccountSubType::DebitCard),
            "savings_account" | "savings" => Ok(AccountSubType::SavingsAccount),
            "checking" => Ok(AccountSubType::Checking),
            "investment" => Ok(AccountSubType::Investment),
            "prepaid_card" => Ok(AccountSubType::PrepaidCard),
            "digital_wallet" => Ok(AccountSubType::DigitalWallet),
            "wechat" => Ok(AccountSubType::Wechat),
            "wechat_change" => Ok(AccountSubType::WechatChange),
            "alipay" => Ok(AccountSubType::Alipay),
            "yuebao" => Ok(AccountSubType::Yuebao),
            "union_pay" => Ok(AccountSubType::UnionPay),
            "bank_card" => Ok(AccountSubType::BankCard),
            "provident_fund" => Ok(AccountSubType::ProvidentFund),
            "qq_wallet" => Ok(AccountSubType::QQWallet),
            "jd_wallet" => Ok(AccountSubType::JDWallet),
            "medical_insurance" => Ok(AccountSubType::MedicalInsurance),
            "digital_rmb" => Ok(AccountSubType::DigitalRMB),
            "huawei_wallet" => Ok(AccountSubType::HuaweiWallet),
            "pinduoduo_wallet" => Ok(AccountSubType::PinduoduoWallet),
            "paypal" => Ok(AccountSubType::Paypal),
            "credit_card" | "credit" | "creditcard" => Ok(AccountSubType::CreditCard),
            "huabei" => Ok(AccountSubType::Huabei),
            "jiebei" => Ok(AccountSubType::Jiebei),
            "jd_white_bar" => Ok(AccountSubType::JDWhiteBar),
            "meituan_monthly" => Ok(AccountSubType::MeituanMonthly),
            "douyin_monthly" => Ok(AccountSubType::DouyinMonthly),
            "wechat_installment" => Ok(AccountSubType::WechatInstallment),
            "loan" => Ok(AccountSubType::Loan),
            "mortgage" => Ok(AccountSubType::Mortgage),
            "phone_credit" => Ok(AccountSubType::PhoneCredit),
            "utilities" => Ok(AccountSubType::Utilities),
            "meal_card" => Ok(AccountSubType::MealCard),
            "deposit" => Ok(AccountSubType::Deposit),
            "transit_card" => Ok(AccountSubType::TransitCard),
            "membership_card" => Ok(AccountSubType::MembershipCard),
            "gas_card" => Ok(AccountSubType::GasCard),
            "sinopec_wallet" => Ok(AccountSubType::SinopecWallet),
            "apple_account" => Ok(AccountSubType::AppleAccount),
            "stock" => Ok(AccountSubType::Stock),
            "fund" => Ok(AccountSubType::Fund),
            "gold" => Ok(AccountSubType::Gold),
            "forex" => Ok(AccountSubType::Forex),
            "futures" => Ok(AccountSubType::Futures),
            "bond" => Ok(AccountSubType::Bond),
            "fixed_income" => Ok(AccountSubType::FixedIncome),
            "crypto" => Ok(AccountSubType::Crypto),
            "other" => Ok(AccountSubType::Other),
            _ => Err(format!("Invalid account sub type: {}", s)),
        }
    }
}

impl AccountSubType {
    pub fn get_main_type(&self) -> AccountMainType {
        match self {
            AccountSubType::Cash
            | AccountSubType::DebitCard
            | AccountSubType::SavingsAccount
            | AccountSubType::Checking
            | AccountSubType::Investment
            | AccountSubType::PrepaidCard
            | AccountSubType::DigitalWallet
            | AccountSubType::Wechat
            | AccountSubType::WechatChange
            | AccountSubType::Alipay
            | AccountSubType::Yuebao
            | AccountSubType::UnionPay
            | AccountSubType::BankCard
            | AccountSubType::ProvidentFund
            | AccountSubType::QQWallet
            | AccountSubType::JDWallet
            | AccountSubType::MedicalInsurance
            | AccountSubType::DigitalRMB
            | AccountSubType::HuaweiWallet
            | AccountSubType::PinduoduoWallet
            | AccountSubType::Paypal
            | AccountSubType::PhoneCredit
            | AccountSubType::Utilities
            | AccountSubType::MealCard
            | AccountSubType::Deposit
            | AccountSubType::TransitCard
            | AccountSubType::MembershipCard
            | AccountSubType::GasCard
            | AccountSubType::SinopecWallet
            | AccountSubType::AppleAccount
            | AccountSubType::Stock
            | AccountSubType::Fund
            | AccountSubType::Gold
            | AccountSubType::Forex
            | AccountSubType::Futures
            | AccountSubType::Bond
            | AccountSubType::FixedIncome
            | AccountSubType::Crypto
            | AccountSubType::Other => AccountMainType::Asset,
            AccountSubType::CreditCard
            | AccountSubType::Huabei
            | AccountSubType::Jiebei
            | AccountSubType::JDWhiteBar
            | AccountSubType::MeituanMonthly
            | AccountSubType::DouyinMonthly
            | AccountSubType::WechatInstallment
            | AccountSubType::Loan
            | AccountSubType::Mortgage => AccountMainType::Liability,
        }
    }

    pub fn display_name(&self) -> &'static str {
        match self {
            AccountSubType::Cash => "现金",
            AccountSubType::DebitCard => "借记卡",
            AccountSubType::SavingsAccount => "储蓄账户",
            AccountSubType::Checking => "支票账户",
            AccountSubType::Investment => "投资账户",
            AccountSubType::PrepaidCard => "预付卡",
            AccountSubType::DigitalWallet => "数字钱包",
            AccountSubType::Wechat => "微信",
            AccountSubType::WechatChange => "微信零钱通",
            AccountSubType::Alipay => "支付宝",
            AccountSubType::Yuebao => "余额宝",
            AccountSubType::UnionPay => "云闪付",
            AccountSubType::BankCard => "银行卡",
            AccountSubType::ProvidentFund => "公积金",
            AccountSubType::QQWallet => "QQ钱包",
            AccountSubType::JDWallet => "京东金融",
            AccountSubType::MedicalInsurance => "医保",
            AccountSubType::DigitalRMB => "数字人民币",
            AccountSubType::HuaweiWallet => "华为钱包",
            AccountSubType::PinduoduoWallet => "多多钱包",
            AccountSubType::Paypal => "PayPal",
            AccountSubType::CreditCard => "信用卡",
            AccountSubType::Huabei => "花呗",
            AccountSubType::Jiebei => "借呗",
            AccountSubType::JDWhiteBar => "京东白条",
            AccountSubType::MeituanMonthly => "美团月付",
            AccountSubType::DouyinMonthly => "抖音月付",
            AccountSubType::WechatInstallment => "微信分付",
            AccountSubType::Loan => "贷款",
            AccountSubType::Mortgage => "房贷",
            AccountSubType::PhoneCredit => "话费",
            AccountSubType::Utilities => "水电",
            AccountSubType::MealCard => "饭卡",
            AccountSubType::Deposit => "押金",
            AccountSubType::TransitCard => "公交卡",
            AccountSubType::MembershipCard => "会员卡",
            AccountSubType::GasCard => "加油卡",
            AccountSubType::SinopecWallet => "石化钱包",
            AccountSubType::AppleAccount => "Apple",
            AccountSubType::Stock => "股票",
            AccountSubType::Fund => "基金",
            AccountSubType::Gold => "黄金",
            AccountSubType::Forex => "外汇",
            AccountSubType::Futures => "期货",
            AccountSubType::Bond => "债券",
            AccountSubType::FixedIncome => "固定收益",
            AccountSubType::Crypto => "加密货币",
            AccountSubType::Other => "其它",
        }
    }

    pub fn validate_with_main_type(&self, main_type: AccountMainType) -> Result<(), String> {
        let expected = self.get_main_type();
        if expected == main_type {
            Ok(())
        } else {
            Err(format!(
                "Account sub type {:?} requires main type {:?}, got {:?}",
                self, expected, main_type
            ))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_account_main_type_from_str() {
        assert_eq!(
            AccountMainType::from_str("asset").unwrap(),
            AccountMainType::Asset
        );
        assert_eq!(
            AccountMainType::from_str("liability").unwrap(),
            AccountMainType::Liability
        );
        assert_eq!(
            AccountMainType::from_str("ASSET").unwrap(),
            AccountMainType::Asset
        );
        assert!(AccountMainType::from_str("invalid").is_err());
    }

    #[test]
    fn test_account_sub_type_from_str() {
        assert_eq!(
            AccountSubType::from_str("cash").unwrap(),
            AccountSubType::Cash
        );
        assert_eq!(
            AccountSubType::from_str("debit_card").unwrap(),
            AccountSubType::DebitCard
        );
        assert_eq!(
            AccountSubType::from_str("credit_card").unwrap(),
            AccountSubType::CreditCard
        );
        assert_eq!(
            AccountSubType::from_str("creditcard").unwrap(),
            AccountSubType::CreditCard
        );
        assert!(AccountSubType::from_str("invalid").is_err());
    }

    #[test]
    fn test_sub_type_main_type_mapping() {
        assert_eq!(
            AccountSubType::Cash.get_main_type(),
            AccountMainType::Asset
        );
        assert_eq!(
            AccountSubType::CreditCard.get_main_type(),
            AccountMainType::Liability
        );
        assert_eq!(
            AccountSubType::Loan.get_main_type(),
            AccountMainType::Liability
        );
    }

    #[test]
    fn test_validate_with_main_type() {
        assert!(AccountSubType::Cash
            .validate_with_main_type(AccountMainType::Asset)
            .is_ok());
        assert!(AccountSubType::Cash
            .validate_with_main_type(AccountMainType::Liability)
            .is_err());
        assert!(AccountSubType::CreditCard
            .validate_with_main_type(AccountMainType::Liability)
            .is_ok());
    }
}