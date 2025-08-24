use super::*;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// Import entity - based on Maybe's import.rb
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Import {
    pub id: Uuid,
    pub family_id: Uuid,
    pub account_id: Option<Uuid>, // Target account for transactions
    pub import_type: ImportType,
    pub status: ImportStatus,
    pub col_sep: String, // CSV column separator
    pub signage_convention: SignageConvention,
    pub number_format: String, // e.g., "1,234.56" or "1.234,56"
    pub amount_type_strategy: AmountTypeStrategy,
    pub csv_data: Option<String>, // Raw CSV content
    pub error: Option<String>,
    pub row_count: i32,
    pub processed_count: i32,
    pub failed_count: i32,
    
    // Column mappings
    pub date_col_label: Option<String>,
    pub amount_col_label: Option<String>,
    pub name_col_label: Option<String>,
    pub category_col_label: Option<String>,
    pub account_col_label: Option<String>,
    pub tags_col_label: Option<String>,
    pub notes_col_label: Option<String>,
    pub currency_col_label: Option<String>,
    pub payee_col_label: Option<String>,
    
    // For investment imports
    pub ticker_col_label: Option<String>,
    pub qty_col_label: Option<String>,
    pub price_col_label: Option<String>,
    
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "import_type", rename_all = "snake_case")]
pub enum ImportType {
    TransactionImport,
    TradeImport,
    AccountImport,
    MintImport,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "import_status", rename_all = "snake_case")]
pub enum ImportStatus {
    Pending,
    Importing,
    Complete,
    Reverting,
    RevertFailed,
    Failed,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "signage_convention", rename_all = "snake_case")]
pub enum SignageConvention {
    InflowsPositive,
    InflowsNegative,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "amount_type_strategy", rename_all = "snake_case")]
pub enum AmountTypeStrategy {
    SignedAmount,
    CustomColumn,
}

// ImportRow - individual row from CSV
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct ImportRow {
    pub id: Uuid,
    pub import_id: Uuid,
    pub row_number: i32,
    pub status: ImportRowStatus,
    pub error: Option<String>,
    
    // Parsed data
    pub date: Option<NaiveDate>,
    pub amount: Option<Decimal>,
    pub name: Option<String>,
    pub category: Option<String>,
    pub account: Option<String>,
    pub tags: Option<String>,
    pub notes: Option<String>,
    pub currency: Option<String>,
    pub payee: Option<String>,
    
    // For investment imports
    pub ticker: Option<String>,
    pub qty: Option<Decimal>,
    pub price: Option<Decimal>,
    
    // Raw data
    pub raw_data: serde_json::Value, // JSONB of original row
    
    // Generated entries/transactions
    pub entry_id: Option<Uuid>,
    pub transaction_id: Option<Uuid>,
    
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "import_row_status", rename_all = "snake_case")]
pub enum ImportRowStatus {
    Pending,
    Processing,
    Success,
    Failed,
    Skipped,
}

// ImportMapping - maps imported values to existing entities
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct ImportMapping {
    pub id: Uuid,
    pub import_id: Uuid,
    pub mappable_type: String, // 'Account', 'Category', 'Tag', 'Payee'
    pub mappable_id: Option<Uuid>, // Existing entity ID
    pub imported_value: String, // Value from CSV
    pub mapped_name: String, // Name to use
    pub is_new: bool, // Whether to create new entity
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// AccountImportMapping - specific mapping for accounts
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct AccountImportMapping {
    pub id: Uuid,
    pub import_id: Uuid,
    pub account_id: Option<Uuid>,
    pub imported_name: String,
    pub account_type: String,
    pub currency: String,
    pub initial_balance: Option<Decimal>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// CategoryImportMapping - specific mapping for categories
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct CategoryImportMapping {
    pub id: Uuid,
    pub import_id: Uuid,
    pub category_id: Option<Uuid>,
    pub imported_name: String,
    pub classification: String, // 'income' or 'expense'
    pub color: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// TagImportMapping - specific mapping for tags
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct TagImportMapping {
    pub id: Uuid,
    pub import_id: Uuid,
    pub tag_id: Option<Uuid>,
    pub imported_name: String,
    pub color: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Import {
    pub fn new(family_id: Uuid, import_type: ImportType) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            family_id,
            account_id: None,
            import_type,
            status: ImportStatus::Pending,
            col_sep: ",".to_string(),
            signage_convention: SignageConvention::InflowsPositive,
            number_format: "1,234.56".to_string(),
            amount_type_strategy: AmountTypeStrategy::SignedAmount,
            csv_data: None,
            error: None,
            row_count: 0,
            processed_count: 0,
            failed_count: 0,
            date_col_label: None,
            amount_col_label: None,
            name_col_label: None,
            category_col_label: None,
            account_col_label: None,
            tags_col_label: None,
            notes_col_label: None,
            currency_col_label: None,
            payee_col_label: None,
            ticker_col_label: None,
            qty_col_label: None,
            price_col_label: None,
            created_at: now,
            updated_at: now,
        }
    }
    
    pub fn is_publishable(&self) -> bool {
        matches!(self.status, ImportStatus::Pending) && self.row_count > 0
    }
    
    pub fn is_revertable(&self) -> bool {
        matches!(self.status, ImportStatus::Complete)
    }
    
    // Parse number based on format settings
    pub fn parse_number(&self, value: &str) -> Option<Decimal> {
        if value.is_empty() {
            return None;
        }
        
        // Remove currency symbols and whitespace
        let cleaned = value
            .replace("$", "")
            .replace("€", "")
            .replace("£", "")
            .replace("¥", "")
            .trim()
            .to_string();
        
        // Handle different number formats
        let normalized = match self.number_format.as_str() {
            "1,234.56" => cleaned.replace(",", ""),
            "1.234,56" => cleaned.replace(".", "").replace(",", "."),
            "1 234,56" => cleaned.replace(" ", "").replace(",", "."),
            "1,234" => cleaned.replace(",", ""),
            _ => cleaned,
        };
        
        normalized.parse::<Decimal>().ok()
    }
    
    // Apply signage convention
    pub fn apply_signage(&self, amount: Decimal, is_expense: bool) -> Decimal {
        match self.signage_convention {
            SignageConvention::InflowsPositive => {
                if is_expense {
                    -amount.abs()
                } else {
                    amount.abs()
                }
            }
            SignageConvention::InflowsNegative => {
                if is_expense {
                    amount.abs()
                } else {
                    -amount.abs()
                }
            }
        }
    }
}