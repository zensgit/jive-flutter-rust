use super::*;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// Ledger entity - based on Maybe's ledger.rb (多账本系统)
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Ledger {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub ledger_type: LedgerType,
    pub color: String,
    pub currency: String,
    pub is_default: bool,
    pub is_active: bool,
    pub is_hidden: bool,
    pub cover_image_url: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "ledger_type", rename_all = "snake_case")]
pub enum LedgerType {
    Personal,  // 个人账本
    Family,    // 家庭账本
    Project,   // 项目账本
    Business,  // 商务账本
}

impl Ledger {
    pub fn new(family_id: Uuid, name: String, ledger_type: LedgerType) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            family_id,
            name,
            description: None,
            ledger_type,
            color: "#3B82F6".to_string(),
            currency: "USD".to_string(),
            is_default: false,
            is_active: true,
            is_hidden: false,
            cover_image_url: None,
            created_at: now,
            updated_at: now,
        }
    }
}

// LedgerAccount - 账本中的虚拟账户视图
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct LedgerAccount {
    pub id: Uuid,
    pub ledger_id: Uuid,
    pub physical_account_id: Uuid, // 对应的物理账户
    pub display_name: String, // 在此账本中的显示名称
    pub is_active: bool,
    pub is_hidden: bool,
    pub custom_balance: Option<Decimal>, // 自定义余额（覆盖物理账户余额）
    pub balance_adjustment: Option<Decimal>, // 余额调整值
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl LedgerAccount {
    pub fn new(ledger_id: Uuid, physical_account_id: Uuid, display_name: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            ledger_id,
            physical_account_id,
            display_name,
            is_active: true,
            is_hidden: false,
            custom_balance: None,
            balance_adjustment: None,
            created_at: now,
            updated_at: now,
        }
    }
    
    // 获取在账本中的余额
    pub fn balance_in_ledger(&self, physical_balance: Decimal) -> Decimal {
        if let Some(custom) = self.custom_balance {
            custom
        } else {
            physical_balance + self.balance_adjustment.unwrap_or(Decimal::ZERO)
        }
    }
}

// LedgerTransfer - 账本间转账
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct LedgerTransfer {
    pub id: Uuid,
    pub from_ledger_id: Uuid,
    pub to_ledger_id: Uuid,
    pub amount: Decimal,
    pub currency: String,
    pub description: Option<String>,
    pub transfer_date: NaiveDate,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// TravelEvent - based on Maybe's travel_event.rb (旅行功能)
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct TravelEvent {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
    pub destination: Option<String>,
    pub budget: Option<Decimal>,
    pub currency: String,
    pub travel_categories: Vec<Uuid>, // JSONB - 旅行相关的分类ID
    pub auto_tag: bool, // 自动为期间内的交易添加标签
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl TravelEvent {
    pub fn new(family_id: Uuid, name: String, start_date: NaiveDate, end_date: NaiveDate) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            family_id,
            name,
            description: None,
            start_date,
            end_date,
            destination: None,
            budget: None,
            currency: "USD".to_string(),
            travel_categories: Vec::new(),
            auto_tag: true,
            is_active: true,
            created_at: now,
            updated_at: now,
        }
    }
    
    // 检查日期是否在旅行期间
    pub fn includes_date(&self, date: NaiveDate) -> bool {
        date >= self.start_date && date <= self.end_date
    }
    
    // 获取旅行标签名称
    pub fn travel_tag_name(&self) -> String {
        format!("旅行-{}", self.name)
    }
}

// Transfer - based on Maybe's transfer matching (自动转账匹配)
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Transfer {
    pub id: Uuid,
    pub inflow_transaction_id: Uuid,
    pub outflow_transaction_id: Uuid,
    pub matched_at: DateTime<Utc>,
    pub confidence_score: Decimal, // 匹配置信度
    pub is_confirmed: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// RejectedTransfer - 被拒绝的转账匹配
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct RejectedTransfer {
    pub id: Uuid,
    pub inflow_transaction_id: Uuid,
    pub outflow_transaction_id: Uuid,
    pub rejected_at: DateTime<Utc>,
    pub reason: Option<String>,
    pub created_at: DateTime<Utc>,
}

// Assistant/Chat - based on Maybe's AI assistant (AI助手)
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Chat {
    pub id: Uuid,
    pub user_id: Uuid,
    pub title: Option<String>,
    pub is_active: bool,
    pub latest_assistant_response_id: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct AssistantMessage {
    pub id: Uuid,
    pub chat_id: Uuid,
    pub role: MessageRole,
    pub content: String,
    pub ai_model: String,
    pub tool_calls: Option<serde_json::Value>, // JSONB
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "message_role", rename_all = "snake_case")]
pub enum MessageRole {
    User,
    Assistant,
    System,
    Tool,
}

// DataEnrichment - based on Maybe's auto-categorization (数据增强)
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct DataEnrichment {
    pub id: Uuid,
    pub family_id: Uuid,
    pub enrichment_type: EnrichmentType,
    pub resource_type: String,
    pub resource_id: Uuid,
    pub original_value: String,
    pub enriched_value: String,
    pub confidence: Decimal,
    pub provider: String, // 'openai', 'manual', 'rule'
    pub applied: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "enrichment_type", rename_all = "snake_case")]
pub enum EnrichmentType {
    CategoryDetection,  // 自动分类
    MerchantDetection, // 商家识别
    TransferMatching,  // 转账匹配
    DuplicateDetection, // 重复检测
    AnomalyDetection,  // 异常检测
}

// Investment entities - based on Maybe's investment models
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Holding {
    pub id: Uuid,
    pub account_id: Uuid,
    pub security_id: Uuid,
    pub quantity: Decimal,
    pub cost_basis: Decimal,
    pub currency: String,
    pub date: NaiveDate,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Security {
    pub id: Uuid,
    pub symbol: String,
    pub name: Option<String>,
    pub security_type: SecurityType,
    pub exchange: Option<String>,
    pub cusip: Option<String>,
    pub isin: Option<String>,
    pub currency: String,
    pub last_price: Option<Decimal>,
    pub last_price_date: Option<NaiveDate>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "security_type", rename_all = "snake_case")]
pub enum SecurityType {
    Stock,
    Bond,
    Etf,
    MutualFund,
    Option,
    Cryptocurrency,
    Commodity,
    Other,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Trade {
    pub id: Uuid,
    pub entry_id: Uuid,
    pub security_id: Uuid,
    pub trade_type: TradeType,
    pub quantity: Decimal,
    pub price: Decimal,
    pub fees: Option<Decimal>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "trade_type", rename_all = "snake_case")]
pub enum TradeType {
    Buy,
    Sell,
    Dividend,
    Interest,
    Transfer,
}