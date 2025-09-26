use super::*;
use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// Transaction entity - based on Maybe's transaction.rb
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Transaction {
    pub id: Uuid,
    pub entry_id: Uuid,
    pub category_id: Option<Uuid>,
    pub payee_id: Option<Uuid>,
    pub ledger_id: Option<Uuid>,
    pub ledger_account_id: Option<Uuid>,
    pub scheduled_transaction_id: Option<Uuid>,
    pub original_transaction_id: Option<Uuid>, // For splits and refunds
    pub reimbursement_batch_id: Option<Uuid>,
    pub notes: Option<String>,
    pub kind: TransactionKind,
    pub tags: Vec<String>, // Stored as JSONB
    pub reimbursable: bool,
    pub reimbursed: bool,
    pub reimbursed_at: Option<DateTime<Utc>>,
    pub is_refund: bool,
    pub refund_amount: Option<Decimal>,
    pub exclude_from_reports: bool,
    pub exclude_from_budget: bool,
    pub discount: Option<Decimal>, // For merchant discounts
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// Transaction kind enum - based on Maybe's transaction kinds
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "transaction_kind", rename_all = "snake_case")]
pub enum TransactionKind {
    Standard,      // Regular transaction, included in budget
    FundsMovement, // Movement between accounts, excluded from budget
    CcPayment,     // Credit card payment, excluded from budget
    LoanPayment,   // Loan payment, treated as expense in budget
    OneTime,       // One-time expense/income, excluded from budget
}

impl Transaction {
    pub fn new(entry_id: Uuid) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            entry_id,
            category_id: None,
            payee_id: None,
            ledger_id: None,
            ledger_account_id: None,
            scheduled_transaction_id: None,
            original_transaction_id: None,
            reimbursement_batch_id: None,
            notes: None,
            kind: TransactionKind::Standard,
            tags: Vec::new(),
            reimbursable: false,
            reimbursed: false,
            reimbursed_at: None,
            is_refund: false,
            refund_amount: None,
            exclude_from_reports: false,
            exclude_from_budget: false,
            discount: None,
            created_at: now,
            updated_at: now,
        }
    }

    // Check if this is a transfer-type transaction
    pub fn is_transfer(&self) -> bool {
        matches!(
            self.kind,
            TransactionKind::FundsMovement
                | TransactionKind::CcPayment
                | TransactionKind::LoanPayment
        )
    }

    // Check if this can be reimbursed
    pub fn can_be_reimbursed(&self) -> bool {
        self.reimbursable && !self.reimbursed
    }

    // Mark as reimbursed
    pub fn mark_as_reimbursed(&mut self, batch_id: Option<Uuid>) {
        self.reimbursed = true;
        self.reimbursed_at = Some(Utc::now());
        self.reimbursement_batch_id = batch_id;
        self.updated_at = Utc::now();
    }

    // Check if this is a scheduled transaction
    pub fn is_scheduled(&self) -> bool {
        self.scheduled_transaction_id.is_some()
    }

    // Check if transaction can be split
    pub fn can_be_split(&self) -> bool {
        !self.is_refund && self.original_transaction_id.is_none()
    }
}

// Category entity
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Category {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: String,
    pub classification: CategoryClassification,
    pub color: String,
    pub icon: Option<String>,
    pub parent_id: Option<Uuid>, // For hierarchical categories
    pub is_system: bool,
    pub is_archived: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "category_classification", rename_all = "lowercase")]
pub enum CategoryClassification {
    Income,
    Expense,
}

// Payee entity - based on Maybe's payee.rb
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Payee {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: String,
    pub transactions_count: i32,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// PayeeCategory association - for auto-categorization
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct PayeeCategory {
    pub id: Uuid,
    pub payee_id: Uuid,
    pub category_id: Uuid,
    pub auto_assigned: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// Tag entity
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Tag {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: String,
    pub color: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// Tagging entity - polymorphic association
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Tagging {
    pub id: Uuid,
    pub tag_id: Uuid,
    pub taggable_type: String,
    pub taggable_id: Uuid,
    pub created_at: DateTime<Utc>,
}

// TransactionSplit - for split transactions
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct TransactionSplit {
    pub id: Uuid,
    pub original_transaction_id: Uuid,
    pub split_transaction_id: Uuid,
    pub description: String,
    pub amount: Decimal,
    pub percentage: Decimal,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

// ReimbursementBatch - for grouping reimbursements
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct ReimbursementBatch {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: String,
    pub description: Option<String>,
    pub total_amount: Decimal,
    pub currency: String,
    pub status: ReimbursementStatus,
    pub submitted_at: Option<DateTime<Utc>>,
    pub approved_at: Option<DateTime<Utc>>,
    pub paid_at: Option<DateTime<Utc>>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "reimbursement_status", rename_all = "snake_case")]
pub enum ReimbursementStatus {
    Draft,
    Submitted,
    Approved,
    Paid,
    Rejected,
}

// ScheduledTransaction - for recurring transactions
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct ScheduledTransaction {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: String,
    pub amount: Decimal,
    pub currency: String,
    pub category_id: Option<Uuid>,
    pub payee_id: Option<Uuid>,
    pub account_id: Uuid,
    pub frequency: RecurrenceFrequency,
    pub interval: i32, // e.g., every 2 weeks
    pub start_date: NaiveDate,
    pub end_date: Option<NaiveDate>,
    pub next_occurrence: NaiveDate,
    pub last_occurrence: Option<NaiveDate>,
    pub occurrences_count: i32,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "recurrence_frequency", rename_all = "snake_case")]
pub enum RecurrenceFrequency {
    Daily,
    Weekly,
    Biweekly,
    Monthly,
    Quarterly,
    Yearly,
}
