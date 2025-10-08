use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Travel event status
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum TravelStatus {
    Planning,
    Active,
    Completed,
    Cancelled,
}

impl TravelStatus {
    pub fn as_str(&self) -> &'static str {
        match self {
            TravelStatus::Planning => "planning",
            TravelStatus::Active => "active",
            TravelStatus::Completed => "completed",
            TravelStatus::Cancelled => "cancelled",
        }
    }

    pub fn from_str(s: &str) -> Option<Self> {
        match s {
            "planning" => Some(TravelStatus::Planning),
            "active" => Some(TravelStatus::Active),
            "completed" => Some(TravelStatus::Completed),
            "cancelled" => Some(TravelStatus::Cancelled),
            _ => None,
        }
    }
}

/// Exchange rate mode for travel
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum ExchangeRateMode {
    RealTime,
    Fixed,
    Manual,
}

/// Travel reminder settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReminderSettings {
    pub daily_summary: bool,
    pub budget_alerts: bool,
    pub alert_threshold: f32,
}

impl Default for ReminderSettings {
    fn default() -> Self {
        Self {
            daily_summary: false,
            budget_alerts: true,
            alert_threshold: 0.8,
        }
    }
}

/// Travel event settings
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TravelSettings {
    pub auto_tags: bool,
    pub offline_mode: bool,
    pub exchange_rate_mode: ExchangeRateMode,
    pub reminder_settings: ReminderSettings,
}

impl Default for TravelSettings {
    fn default() -> Self {
        Self {
            auto_tags: false,
            offline_mode: false,
            exchange_rate_mode: ExchangeRateMode::RealTime,
            reminder_settings: ReminderSettings::default(),
        }
    }
}

/// Core travel event entity
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TravelEvent {
    pub id: Uuid,
    pub family_id: Uuid,

    // Basic information
    pub trip_name: String,
    pub status: String, // Will be converted to TravelStatus

    // Date range
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,

    // Budget settings
    pub total_budget: Option<Decimal>,
    pub budget_currency_code: Option<String>,
    pub home_currency_code: String,

    // Tag group (nullable for MVP)
    pub tag_group_id: Option<Uuid>,

    // Settings
    pub settings: serde_json::Value,

    // Statistics
    pub total_spent: Decimal,
    pub transaction_count: i32,
    pub last_transaction_at: Option<DateTime<Utc>>,

    // Audit fields
    pub created_by: Uuid,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl TravelEvent {
    /// Get status as enum
    pub fn get_status(&self) -> TravelStatus {
        TravelStatus::from_str(&self.status).unwrap_or(TravelStatus::Planning)
    }

    /// Check if travel is currently active
    pub fn is_active(&self) -> bool {
        self.get_status() == TravelStatus::Active
    }

    /// Check if travel can be activated
    pub fn can_activate(&self) -> bool {
        self.get_status() == TravelStatus::Planning
    }

    /// Check if travel can be completed
    pub fn can_complete(&self) -> bool {
        self.get_status() == TravelStatus::Active
    }

    /// Get settings from JSON
    pub fn get_settings(&self) -> TravelSettings {
        serde_json::from_value(self.settings.clone()).unwrap_or_default()
    }

    /// Calculate trip duration in days
    pub fn duration_days(&self) -> i64 {
        (self.end_date - self.start_date).num_days() + 1
    }

    /// Calculate daily budget
    pub fn daily_budget(&self) -> Option<Decimal> {
        self.total_budget.map(|budget| {
            let days = Decimal::from(self.duration_days());
            budget / days
        })
    }

    /// Calculate budget usage percentage
    pub fn budget_usage_percent(&self) -> Option<Decimal> {
        self.total_budget.map(|budget| {
            if budget.is_zero() {
                Decimal::ZERO
            } else {
                (self.total_spent / budget) * Decimal::from(100)
            }
        })
    }

    /// Check if budget alert should be triggered
    pub fn should_alert(&self) -> bool {
        let settings = self.get_settings();
        if !settings.reminder_settings.budget_alerts {
            return false;
        }

        if let Some(usage_percent) = self.budget_usage_percent() {
            let threshold = Decimal::from_f32_retain(settings.reminder_settings.alert_threshold * 100.0)
                .unwrap_or(Decimal::from(80));
            usage_percent >= threshold
        } else {
            false
        }
    }
}

/// Travel budget by category
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TravelBudget {
    pub id: Uuid,
    pub travel_event_id: Uuid,
    pub category_id: Uuid,

    // Budget
    pub budget_amount: Decimal,
    pub budget_currency_code: Option<String>,

    // Spending
    pub spent_amount: Decimal,
    pub spent_amount_home_currency: Decimal,

    // Alerts
    pub alert_threshold: Decimal,
    pub alert_sent: bool,
    pub alert_sent_at: Option<DateTime<Utc>>,

    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl TravelBudget {
    /// Calculate usage percentage
    pub fn usage_percent(&self) -> Decimal {
        if self.budget_amount.is_zero() {
            Decimal::ZERO
        } else {
            (self.spent_amount / self.budget_amount) * Decimal::from(100)
        }
    }

    /// Check if alert should be sent
    pub fn should_alert(&self) -> bool {
        !self.alert_sent && self.usage_percent() >= (self.alert_threshold * Decimal::from(100))
    }

    /// Calculate remaining budget
    pub fn remaining(&self) -> Decimal {
        self.budget_amount - self.spent_amount
    }
}

/// Travel transaction association
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TravelTransaction {
    pub travel_event_id: Uuid,
    pub transaction_id: Uuid,
    pub attached_at: DateTime<Utc>,
    pub attached_by: Option<Uuid>,
    pub notes: Option<String>,
}

/// Input for creating a travel event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateTravelEventInput {
    pub trip_name: String,
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
    pub total_budget: Option<Decimal>,
    pub budget_currency_code: Option<String>,
    pub home_currency_code: String,
    pub settings: Option<TravelSettings>,
}

impl CreateTravelEventInput {
    /// Validate input
    pub fn validate(&self) -> Result<(), String> {
        if self.trip_name.is_empty() {
            return Err("Trip name cannot be empty".to_string());
        }

        if self.trip_name.len() > 100 {
            return Err("Trip name cannot exceed 100 characters".to_string());
        }

        if self.end_date < self.start_date {
            return Err("End date must be after or equal to start date".to_string());
        }

        if let Some(budget) = self.total_budget {
            if budget.is_sign_negative() {
                return Err("Budget cannot be negative".to_string());
            }
        }

        Ok(())
    }
}

/// Input for updating a travel event
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpdateTravelEventInput {
    pub trip_name: Option<String>,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub total_budget: Option<Decimal>,
    pub budget_currency_code: Option<String>,
    pub settings: Option<TravelSettings>,
}

/// Input for creating/updating travel budget
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UpsertTravelBudgetInput {
    pub category_id: Uuid,
    pub budget_amount: Decimal,
    pub budget_currency_code: Option<String>,
    pub alert_threshold: Option<Decimal>,
}

impl UpsertTravelBudgetInput {
    pub fn validate(&self) -> Result<(), String> {
        if self.budget_amount.is_sign_negative() {
            return Err("Budget amount cannot be negative".to_string());
        }

        if let Some(threshold) = self.alert_threshold {
            if threshold < Decimal::ZERO || threshold > Decimal::ONE {
                return Err("Alert threshold must be between 0 and 1".to_string());
            }
        }

        Ok(())
    }
}

/// Input for attaching transactions to travel
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AttachTransactionsInput {
    pub transaction_ids: Option<Vec<Uuid>>,
    pub filter: Option<TransactionFilter>,
}

/// Transaction filter for smart attachment
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionFilter {
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub merchant_keywords: Option<Vec<String>>,
    pub location_keywords: Option<Vec<String>>,
    pub min_amount: Option<Decimal>,
    pub max_amount: Option<Decimal>,
}

/// Travel statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TravelStatistics {
    pub total_spent: Decimal,
    pub transaction_count: i32,
    pub daily_average: Decimal,
    pub by_category: Vec<CategorySpending>,
    pub budget_usage: Option<Decimal>,
}

/// Category spending breakdown
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategorySpending {
    pub category_id: Uuid,
    pub category_name: String,
    pub amount: Decimal,
    pub percentage: Decimal,
    pub transaction_count: i32,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_travel_status_conversion() {
        assert_eq!(TravelStatus::Planning.as_str(), "planning");
        assert_eq!(TravelStatus::from_str("active"), Some(TravelStatus::Active));
        assert_eq!(TravelStatus::from_str("invalid"), None);
    }

    #[test]
    fn test_create_input_validation() {
        let mut input = CreateTravelEventInput {
            trip_name: "Japan Trip".to_string(),
            start_date: NaiveDate::from_ymd_opt(2024, 3, 1).unwrap(),
            end_date: NaiveDate::from_ymd_opt(2024, 3, 10).unwrap(),
            total_budget: Some(Decimal::from(5000)),
            budget_currency_code: None,
            home_currency_code: "USD".to_string(),
            settings: None,
        };

        assert!(input.validate().is_ok());

        // Test invalid cases
        input.trip_name = "".to_string();
        assert!(input.validate().is_err());

        input.trip_name = "Valid name".to_string();
        input.end_date = NaiveDate::from_ymd_opt(2024, 2, 28).unwrap();
        assert!(input.validate().is_err());
    }

    #[test]
    fn test_travel_event_calculations() {
        let event = TravelEvent {
            id: Uuid::new_v4(),
            family_id: Uuid::new_v4(),
            trip_name: "Test Trip".to_string(),
            status: "active".to_string(),
            start_date: NaiveDate::from_ymd_opt(2024, 3, 1).unwrap(),
            end_date: NaiveDate::from_ymd_opt(2024, 3, 10).unwrap(),
            total_budget: Some(Decimal::from(1000)),
            budget_currency_code: None,
            home_currency_code: "USD".to_string(),
            tag_group_id: None,
            settings: serde_json::json!({}),
            total_spent: Decimal::from(800),
            transaction_count: 10,
            last_transaction_at: None,
            created_by: Uuid::new_v4(),
            created_at: Utc::now(),
            updated_at: Utc::now(),
        };

        assert_eq!(event.duration_days(), 10);
        assert_eq!(event.daily_budget(), Some(Decimal::from(100)));
        assert_eq!(event.budget_usage_percent(), Some(Decimal::from(80)));
        assert!(event.should_alert());
    }
}