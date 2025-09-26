// Jive Money Entity Mappings
// Based on Maybe's database structure

#[cfg(feature = "db")]
pub mod family;
#[cfg(feature = "db")]
pub mod user;
#[cfg(feature = "db")]
pub mod account;
#[cfg(feature = "db")]
pub mod transaction;
pub mod budget;
pub mod balance;
pub mod import;
pub mod rule;

use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::types::Json;
use uuid::Uuid;

// Common trait for all entities
pub trait Entity {
    type Id;
    
    fn id(&self) -> Self::Id;
    fn created_at(&self) -> DateTime<Utc>;
    fn updated_at(&self) -> DateTime<Utc>;
}

// For polymorphic associations (Rails delegated_type pattern)
pub trait Accountable: Send + Sync {
    const TYPE_NAME: &'static str;
    
    async fn save(&self, tx: &mut sqlx::PgConnection) -> Result<Uuid, sqlx::Error>;
    async fn load(id: Uuid, conn: &sqlx::PgPool) -> Result<Self, sqlx::Error>
    where
        Self: Sized;
}

// For transaction entries (Rails single table inheritance pattern)
pub trait Entryable: Send + Sync {
    const TYPE_NAME: &'static str;
    
    fn to_entry(&self) -> Entry;
    fn from_entry(entry: Entry) -> Result<Self, String>
    where
        Self: Sized;
}

// Base entry struct used by various transaction types
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Entry {
    pub id: Uuid,
    pub account_id: Uuid,
    pub entryable_type: String,
    pub entryable_id: Uuid,
    pub amount: Decimal,
    pub currency: String,
    pub date: NaiveDate,
    pub name: String,
    pub notes: Option<String>,
    pub excluded: bool,
    pub pending: bool,
    pub nature: String, // 'inflow' or 'outflow'
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// Classification enum for accounts
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "account_classification", rename_all = "lowercase")]
pub enum AccountClassification {
    Asset,
    Liability,
}

// Account status enum
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "account_status", rename_all = "lowercase")]
pub enum AccountStatus {
    Ok,
    Syncing,
    Error,
}

// Transaction nature enum
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TransactionNature {
    Inflow,
    Outflow,
}

impl ToString for TransactionNature {
    fn to_string(&self) -> String {
        match self {
            Self::Inflow => "inflow".to_string(),
            Self::Outflow => "outflow".to_string(),
        }
    }
}

// Helper type for JSONB columns
pub type JsonValue = Json<serde_json::Value>;

// Pagination helper
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaginationParams {
    pub page: i32,
    pub per_page: i32,
    pub offset: i32,
}

impl Default for PaginationParams {
    fn default() -> Self {
        Self {
            page: 1,
            per_page: 25,
            offset: 0,
        }
    }
}

impl PaginationParams {
    pub fn new(page: i32, per_page: i32) -> Self {
        let offset = (page - 1) * per_page;
        Self {
            page,
            per_page,
            offset,
        }
    }
}

// Date range helper
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DateRange {
    pub start: NaiveDate,
    pub end: NaiveDate,
}

impl DateRange {
    pub fn new(start: NaiveDate, end: NaiveDate) -> Self {
        Self { start, end }
    }
    
    pub fn current_month() -> Self {
        let now = chrono::Local::now().naive_local().date();
        let start = NaiveDate::from_ymd_opt(now.year(), now.month(), 1).unwrap();
        let end = if now.month() == 12 {
            NaiveDate::from_ymd_opt(now.year() + 1, 1, 1).unwrap() - chrono::Duration::days(1)
        } else {
            NaiveDate::from_ymd_opt(now.year(), now.month() + 1, 1).unwrap() - chrono::Duration::days(1)
        };
        Self { start, end }
    }
    
    pub fn current_year() -> Self {
        let now = chrono::Local::now().naive_local().date();
        let start = NaiveDate::from_ymd_opt(now.year(), 1, 1).unwrap();
        let end = NaiveDate::from_ymd_opt(now.year(), 12, 31).unwrap();
        Self { start, end }
    }
}
