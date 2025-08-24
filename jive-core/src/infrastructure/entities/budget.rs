use super::*;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// Budget entity - based on Maybe's budget.rb
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Budget {
    pub id: Uuid,
    pub family_id: Uuid,
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
    pub currency: String,
    
    // Budget amounts
    pub budgeted_spending: Decimal,
    pub expected_income: Decimal,
    pub allocated_spending: Decimal,
    pub actual_spending: Decimal,
    pub actual_income: Decimal,
    pub available_to_spend: Decimal,
    pub available_to_allocate: Decimal,
    pub estimated_spending: Decimal,
    pub estimated_income: Decimal,
    pub remaining_expected_income: Decimal,
    
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Entity for Budget {
    type Id = Uuid;
    
    fn id(&self) -> Self::Id {
        self.id
    }
    
    fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }
    
    fn updated_at(&self) -> DateTime<Utc> {
        self.updated_at
    }
}

impl Budget {
    pub fn new(family_id: Uuid, start_date: NaiveDate, end_date: NaiveDate, currency: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            family_id,
            start_date,
            end_date,
            currency,
            budgeted_spending: Decimal::ZERO,
            expected_income: Decimal::ZERO,
            allocated_spending: Decimal::ZERO,
            actual_spending: Decimal::ZERO,
            actual_income: Decimal::ZERO,
            available_to_spend: Decimal::ZERO,
            available_to_allocate: Decimal::ZERO,
            estimated_spending: Decimal::ZERO,
            estimated_income: Decimal::ZERO,
            remaining_expected_income: Decimal::ZERO,
            created_at: now,
            updated_at: now,
        }
    }
    
    pub fn name(&self) -> String {
        self.start_date.format("%B %Y").to_string()
    }
    
    pub fn is_initialized(&self) -> bool {
        self.budgeted_spending != Decimal::ZERO || self.expected_income != Decimal::ZERO
    }
    
    pub fn calculate_available(&mut self) {
        self.available_to_spend = self.budgeted_spending - self.actual_spending;
        self.available_to_allocate = self.expected_income - self.allocated_spending;
        self.remaining_expected_income = self.expected_income - self.actual_income;
    }
}

// BudgetCategory - category-specific budget allocations
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct BudgetCategory {
    pub id: Uuid,
    pub budget_id: Uuid,
    pub category_id: Uuid,
    pub budgeted_spending: Decimal,
    pub actual_spending: Decimal,
    pub currency: String,
    pub rollover_amount: Option<Decimal>, // Amount rolled over from previous month
    pub is_uncategorized: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl BudgetCategory {
    pub fn new(budget_id: Uuid, category_id: Uuid, currency: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            budget_id,
            category_id,
            budgeted_spending: Decimal::ZERO,
            actual_spending: Decimal::ZERO,
            currency,
            rollover_amount: None,
            is_uncategorized: false,
            created_at: now,
            updated_at: now,
        }
    }
    
    pub fn available_to_spend(&self) -> Decimal {
        self.budgeted_spending - self.actual_spending + self.rollover_amount.unwrap_or(Decimal::ZERO)
    }
    
    pub fn percentage_spent(&self) -> Decimal {
        if self.budgeted_spending == Decimal::ZERO {
            Decimal::ZERO
        } else {
            (self.actual_spending / self.budgeted_spending) * Decimal::from(100)
        }
    }
    
    pub fn is_over_budget(&self) -> bool {
        self.actual_spending > self.budgeted_spending
    }
}

// BudgetAlert - notifications for budget thresholds
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct BudgetAlert {
    pub id: Uuid,
    pub budget_id: Uuid,
    pub category_id: Option<Uuid>, // None for overall budget
    pub threshold_percentage: Decimal, // e.g., 80.0 for 80%
    pub alert_type: BudgetAlertType,
    pub is_active: bool,
    pub last_triggered_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "budget_alert_type", rename_all = "snake_case")]
pub enum BudgetAlertType {
    Warning,    // e.g., at 80% spent
    Critical,   // e.g., at 95% spent
    Exceeded,   // Over budget
}

// BudgetGoal - savings or spending goals
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct BudgetGoal {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub goal_type: BudgetGoalType,
    pub target_amount: Decimal,
    pub current_amount: Decimal,
    pub currency: String,
    pub target_date: Option<NaiveDate>,
    pub category_id: Option<Uuid>, // For category-specific goals
    pub is_achieved: bool,
    pub achieved_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "budget_goal_type", rename_all = "snake_case")]
pub enum BudgetGoalType {
    Savings,        // Save X amount
    DebtReduction,  // Pay down debt
    SpendingLimit,  // Don't exceed X amount
    Emergency,      // Emergency fund
}

impl BudgetGoal {
    pub fn progress_percentage(&self) -> Decimal {
        if self.target_amount == Decimal::ZERO {
            Decimal::from(100)
        } else {
            (self.current_amount / self.target_amount) * Decimal::from(100)
        }
    }
    
    pub fn remaining_amount(&self) -> Decimal {
        (self.target_amount - self.current_amount).max(Decimal::ZERO)
    }
    
    pub fn days_until_target(&self) -> Option<i64> {
        self.target_date.map(|date| {
            let today = chrono::Local::now().naive_local().date();
            (date - today).num_days()
        })
    }
}

// BudgetTemplate - reusable budget templates
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct BudgetTemplate {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub template_data: serde_json::Value, // JSONB of category allocations
    pub is_default: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// Budget calculation utilities
pub struct BudgetCalculator {
    pub budget_id: Uuid,
}

impl BudgetCalculator {
    pub fn new(budget_id: Uuid) -> Self {
        Self { budget_id }
    }
    
    pub async fn calculate_actuals(&self, pool: &sqlx::PgPool) -> Result<BudgetActuals, sqlx::Error> {
        // Get budget details
        let budget = sqlx::query_as!(
            Budget,
            "SELECT * FROM budgets WHERE id = $1",
            self.budget_id
        )
        .fetch_one(pool)
        .await?;
        
        // Calculate actual spending
        let spending = sqlx::query!(
            r#"
            SELECT COALESCE(SUM(ABS(e.amount)), 0) as total
            FROM entries e
            JOIN transactions t ON t.entry_id = e.id
            JOIN accounts a ON a.id = e.account_id
            WHERE a.family_id = $1
                AND e.date >= $2
                AND e.date <= $3
                AND e.nature = 'outflow'
                AND t.kind = 'standard'
            "#,
            budget.family_id,
            budget.start_date,
            budget.end_date
        )
        .fetch_one(pool)
        .await?;
        
        // Calculate actual income
        let income = sqlx::query!(
            r#"
            SELECT COALESCE(SUM(e.amount), 0) as total
            FROM entries e
            JOIN transactions t ON t.entry_id = e.id
            JOIN accounts a ON a.id = e.account_id
            WHERE a.family_id = $1
                AND e.date >= $2
                AND e.date <= $3
                AND e.nature = 'inflow'
                AND t.kind = 'standard'
            "#,
            budget.family_id,
            budget.start_date,
            budget.end_date
        )
        .fetch_one(pool)
        .await?;
        
        // Calculate by category
        let category_spending = sqlx::query!(
            r#"
            SELECT 
                t.category_id,
                COALESCE(SUM(ABS(e.amount)), 0) as total
            FROM entries e
            JOIN transactions t ON t.entry_id = e.id
            JOIN accounts a ON a.id = e.account_id
            WHERE a.family_id = $1
                AND e.date >= $2
                AND e.date <= $3
                AND e.nature = 'outflow'
                AND t.kind = 'standard'
                AND t.category_id IS NOT NULL
            GROUP BY t.category_id
            "#,
            budget.family_id,
            budget.start_date,
            budget.end_date
        )
        .fetch_all(pool)
        .await?;
        
        Ok(BudgetActuals {
            total_spending: Decimal::from_str(&spending.total.unwrap_or(0).to_string()).unwrap_or(Decimal::ZERO),
            total_income: Decimal::from_str(&income.total.unwrap_or(0).to_string()).unwrap_or(Decimal::ZERO),
            category_spending: category_spending
                .into_iter()
                .map(|row| (
                    row.category_id.unwrap(),
                    Decimal::from_str(&row.total.unwrap_or(0).to_string()).unwrap_or(Decimal::ZERO)
                ))
                .collect(),
        })
    }
}

#[derive(Debug, Clone)]
pub struct BudgetActuals {
    pub total_spending: Decimal,
    pub total_income: Decimal,
    pub category_spending: Vec<(Uuid, Decimal)>,
}

use rust_decimal::prelude::FromStr;