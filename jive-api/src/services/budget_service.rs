use crate::error::{ApiError, ApiResult};
use chrono::{DateTime, Datelike, Duration, Timelike, Utc};
use rust_decimal::prelude::ToPrimitive;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;
#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct Budget {
    pub id: Uuid,
    pub ledger_id: Uuid,
    pub name: String,
    pub period_type: BudgetPeriod,
    pub amount: Decimal,
    pub category_id: Option<Uuid>,
    pub start_date: DateTime<Utc>,
    pub end_date: Option<DateTime<Utc>>,
    pub is_active: bool,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize, sqlx::Type)]
#[sqlx(type_name = "budget_period", rename_all = "lowercase")]
pub enum BudgetPeriod {
    Daily,
    Weekly,
    Monthly,
    Quarterly,
    Yearly,
    Custom,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BudgetProgress {
    pub budget_id: Uuid,
    pub budget_name: String,
    pub period: String,
    pub budgeted_amount: Decimal,
    pub spent_amount: Decimal,
    pub remaining_amount: Decimal,
    pub percentage_used: f64,
    pub days_remaining: i64,
    pub average_daily_spend: Decimal,
    pub projected_overspend: Option<Decimal>,
    pub categories: Vec<CategorySpending>,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct CategorySpending {
    pub category_id: Uuid,
    pub category_name: String,
    pub amount_spent: Decimal,
    pub transaction_count: i32,
}

pub struct BudgetService {
    pool: PgPool,
}

impl BudgetService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }

    /// 创建预算
    pub async fn create_budget(&self, data: CreateBudgetRequest) -> ApiResult<Budget> {
        let budget_id = Uuid::new_v4();

        // 验证预算期间
        let end_date = match data.period_type {
            BudgetPeriod::Monthly => {
                let start = data.start_date;
                Some(start + Duration::days(30))
            }
            BudgetPeriod::Yearly => {
                let start = data.start_date;
                Some(start + Duration::days(365))
            }
            BudgetPeriod::Custom => data.end_date,
            _ => None,
        };

        let budget: Budget = sqlx::query_as(
            r#"
            INSERT INTO budgets (
                id, ledger_id, name, period_type, amount,
                category_id, start_date, end_date, is_active,
                created_at, updated_at
            ) VALUES (
                $1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW()
            )
            RETURNING *
            "#,
        )
        .bind(budget_id)
        .bind(data.ledger_id)
        .bind(data.name)
        .bind(data.period_type)
        .bind(data.amount)
        .bind(data.category_id)
        .bind(data.start_date)
        .bind(end_date)
        .bind(true)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        Ok(budget)
    }

    /// 获取预算进度
    pub async fn get_budget_progress(&self, budget_id: Uuid) -> ApiResult<BudgetProgress> {
        // 获取预算信息
        let budget: Budget =
            sqlx::query_as("SELECT * FROM budgets WHERE id = $1 AND is_active = true")
                .bind(budget_id)
                .fetch_one(&self.pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        // 计算当前期间
        let (period_start, period_end) = self.get_current_period(&budget)?;

        // 获取期间内的支出
        let spent: (Option<Decimal>,) = sqlx::query_as(
            r#"
            SELECT SUM(amount) as total_spent
            FROM transactions
            WHERE ledger_id = $1
            AND transaction_type = 'expense'
            AND transaction_date BETWEEN $2 AND $3
            AND ($4::uuid IS NULL OR category_id = $4)
            AND status = 'cleared'
            "#,
        )
        .bind(budget.ledger_id)
        .bind(period_start)
        .bind(period_end)
        .bind(budget.category_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let spent_amount = spent.0.unwrap_or(Decimal::ZERO);
        let remaining_amount = budget.amount - spent_amount;
        let percentage_used = if budget.amount.is_zero() {
            0.0
        } else {
            ((spent_amount / budget.amount) * Decimal::from(100))
                .to_f64()
                .unwrap_or(0.0)
                .min(100.0)
        };

        // 计算剩余天数
        let now = Utc::now();
        let days_remaining = (period_end - now).num_days().max(0);
        let days_passed = (now - period_start).num_days().max(1);

        // 计算平均日支出和预测
        let average_daily_spend = if days_passed > 0 {
            spent_amount / Decimal::from(days_passed)
        } else {
            Decimal::ZERO
        };
        let projected_total =
            average_daily_spend * Decimal::from(days_passed + days_remaining);
        let projected_overspend = if projected_total > budget.amount {
            Some(projected_total - budget.amount)
        } else {
            None
        };

        // 获取分类支出明细
        let categories = self
            .get_category_spending(
                &budget.ledger_id,
                &period_start,
                &period_end,
                budget.category_id,
            )
            .await?;

        Ok(BudgetProgress {
            budget_id: budget.id,
            budget_name: budget.name,
            period: format!(
                "{} - {}",
                period_start.format("%Y-%m-%d"),
                period_end.format("%Y-%m-%d")
            ),
            budgeted_amount: budget.amount,
            spent_amount,
            remaining_amount,
            percentage_used,
            days_remaining,
            average_daily_spend,
            projected_overspend,
            categories,
        })
    }

    /// 获取分类支出明细
    async fn get_category_spending(
        &self,
        ledger_id: &Uuid,
        start_date: &DateTime<Utc>,
        end_date: &DateTime<Utc>,
        category_filter: Option<Uuid>,
    ) -> ApiResult<Vec<CategorySpending>> {
        let categories: Vec<CategorySpending> = sqlx::query_as(
            r#"
            SELECT 
                c.id as category_id,
                c.name as category_name,
                COALESCE(SUM(t.amount), 0) as amount_spent,
                COUNT(t.id) as transaction_count
            FROM categories c
            LEFT JOIN transactions t ON t.category_id = c.id
                AND t.ledger_id = $1
                AND t.transaction_type = 'expense'
                AND t.transaction_date BETWEEN $2 AND $3
                AND t.status = 'cleared'
            WHERE c.ledger_id = $1
            AND ($4::uuid IS NULL OR c.id = $4)
            GROUP BY c.id, c.name
            HAVING SUM(t.amount) > 0
            ORDER BY amount_spent DESC
            "#,
        )
        .bind(ledger_id)
        .bind(start_date)
        .bind(end_date)
        .bind(category_filter)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        Ok(categories)
    }

    /// 计算当前预算期间
    fn get_current_period(&self, budget: &Budget) -> ApiResult<(DateTime<Utc>, DateTime<Utc>)> {
        let now = Utc::now();

        match budget.period_type {
            BudgetPeriod::Monthly => {
                let start = Utc::now()
                    .with_day(1)
                    .unwrap()
                    .with_hour(0)
                    .unwrap()
                    .with_minute(0)
                    .unwrap()
                    .with_second(0)
                    .unwrap()
                    .with_nanosecond(0)
                    .unwrap();

                let end = (start + Duration::days(32)).with_day(1).unwrap() - Duration::seconds(1);

                Ok((start, end))
            }
            BudgetPeriod::Yearly => {
                let start = Utc::now()
                    .with_month(1)
                    .unwrap()
                    .with_day(1)
                    .unwrap()
                    .with_hour(0)
                    .unwrap()
                    .with_minute(0)
                    .unwrap()
                    .with_second(0)
                    .unwrap()
                    .with_nanosecond(0)
                    .unwrap();

                let end = start + Duration::days(365) - Duration::seconds(1);

                Ok((start, end))
            }
            BudgetPeriod::Custom => Ok((
                budget.start_date,
                budget.end_date.unwrap_or(now + Duration::days(30)),
            )),
            _ => Ok((budget.start_date, now + Duration::days(30))),
        }
    }

    /// 预算预警检查
    pub async fn check_budget_alerts(&self, ledger_id: Uuid) -> ApiResult<Vec<BudgetAlert>> {
        let budgets: Vec<Budget> =
            sqlx::query_as("SELECT * FROM budgets WHERE ledger_id = $1 AND is_active = true")
                .bind(ledger_id)
                .fetch_all(&self.pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let mut alerts = Vec::new();

        for budget in budgets {
            let progress = self.get_budget_progress(budget.id).await?;

            // 检查预警条件
            if progress.percentage_used >= 90.0 {
                alerts.push(BudgetAlert {
                    budget_id: budget.id,
                    budget_name: budget.name.clone(),
                    alert_type: AlertType::Critical,
                    message: format!(
                        "预算 {} 已使用 {:.1}%",
                        budget.name, progress.percentage_used
                    ),
                    percentage_used: progress.percentage_used,
                    remaining_amount: progress.remaining_amount,
                });
            } else if progress.percentage_used >= 75.0 {
                alerts.push(BudgetAlert {
                    budget_id: budget.id,
                    budget_name: budget.name.clone(),
                    alert_type: AlertType::Warning,
                    message: format!(
                        "预算 {} 已使用 {:.1}%",
                        budget.name, progress.percentage_used
                    ),
                    percentage_used: progress.percentage_used,
                    remaining_amount: progress.remaining_amount,
                });
            }

            // 检查超支预测
            if let Some(overspend) = progress.projected_overspend {
                if overspend > Decimal::ZERO {
                    alerts.push(BudgetAlert {
                        budget_id: budget.id,
                        budget_name: budget.name.clone(),
                        alert_type: AlertType::Projection,
                        message: format!(
                            "按当前支出速度，预算 {} 预计超支 ¥{:.2}",
                            budget.name, overspend
                        ),
                        percentage_used: progress.percentage_used,
                        remaining_amount: progress.remaining_amount,
                    });
                }
            }
        }

        Ok(alerts)
    }

    /// 获取预算报告
    pub async fn generate_budget_report(
        &self,
        ledger_id: Uuid,
        period: ReportPeriod,
    ) -> ApiResult<BudgetReport> {
        let (start_date, end_date) = self.get_report_period(period)?;

        // 获取所有预算
        let budgets: Vec<Budget> =
            sqlx::query_as("SELECT * FROM budgets WHERE ledger_id = $1 AND is_active = true")
                .bind(ledger_id)
                .fetch_all(&self.pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        let mut budget_summaries = Vec::new();
        let mut total_budgeted = Decimal::ZERO;
        let mut total_spent = Decimal::ZERO;

        for budget in budgets {
            let progress = self.get_budget_progress(budget.id).await?;
            total_budgeted += budget.amount;
            total_spent += progress.spent_amount;

            budget_summaries.push(BudgetSummary {
                budget_name: budget.name,
                budgeted: budget.amount,
                spent: progress.spent_amount,
                remaining: progress.remaining_amount,
                percentage: progress.percentage_used,
            });
        }

        // 获取无预算支出
        let unbudgeted_spending: (Option<Decimal>,) = sqlx::query_as(
            r#"
            SELECT SUM(amount) 
            FROM transactions
            WHERE ledger_id = $1
            AND transaction_type = 'expense'
            AND transaction_date BETWEEN $2 AND $3
            AND category_id NOT IN (
                SELECT DISTINCT category_id FROM budgets 
                WHERE ledger_id = $1 AND category_id IS NOT NULL
            )
            AND status = 'cleared'
            "#,
        )
        .bind(ledger_id)
        .bind(start_date)
        .bind(end_date)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

        Ok(BudgetReport {
            period: format!(
                "{} - {}",
                start_date.format("%Y-%m-%d"),
                end_date.format("%Y-%m-%d")
            ),
            total_budgeted,
            total_spent,
            total_remaining: total_budgeted - total_spent,
            overall_percentage: if total_budgeted.is_zero() {
                0.0
            } else {
                ((total_spent / total_budgeted) * Decimal::from(100))
                    .to_f64()
                    .unwrap_or(0.0)
                    .min(100.0)
            },
            budget_summaries,
            unbudgeted_spending: unbudgeted_spending.0.unwrap_or(Decimal::ZERO),
            generated_at: Utc::now(),
        })
    }

    fn get_report_period(&self, period: ReportPeriod) -> ApiResult<(DateTime<Utc>, DateTime<Utc>)> {
        let now = Utc::now();

        match period {
            ReportPeriod::CurrentMonth => {
                let start = now
                    .with_day(1)
                    .unwrap()
                    .with_hour(0)
                    .unwrap()
                    .with_minute(0)
                    .unwrap()
                    .with_second(0)
                    .unwrap()
                    .with_nanosecond(0)
                    .unwrap();
                Ok((start, now))
            }
            ReportPeriod::LastMonth => {
                let end = now
                    .with_day(1)
                    .unwrap()
                    .with_hour(0)
                    .unwrap()
                    .with_minute(0)
                    .unwrap()
                    .with_second(0)
                    .unwrap()
                    .with_nanosecond(0)
                    .unwrap()
                    - Duration::seconds(1);
                let start = end
                    .with_day(1)
                    .unwrap()
                    .with_hour(0)
                    .unwrap()
                    .with_minute(0)
                    .unwrap()
                    .with_second(0)
                    .unwrap()
                    .with_nanosecond(0)
                    .unwrap();
                Ok((start, end))
            }
            ReportPeriod::CurrentYear => {
                let start = now
                    .with_month(1)
                    .unwrap()
                    .with_day(1)
                    .unwrap()
                    .with_hour(0)
                    .unwrap()
                    .with_minute(0)
                    .unwrap()
                    .with_second(0)
                    .unwrap()
                    .with_nanosecond(0)
                    .unwrap();
                Ok((start, now))
            }
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateBudgetRequest {
    pub ledger_id: Uuid,
    pub name: String,
    pub period_type: BudgetPeriod,
    pub amount: Decimal,
    pub category_id: Option<Uuid>,
    pub start_date: DateTime<Utc>,
    pub end_date: Option<DateTime<Utc>>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BudgetAlert {
    pub budget_id: Uuid,
    pub budget_name: String,
    pub alert_type: AlertType,
    pub message: String,
    pub percentage_used: f64,
    pub remaining_amount: Decimal,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum AlertType {
    Warning,
    Critical,
    Projection,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BudgetReport {
    pub period: String,
    pub total_budgeted: Decimal,
    pub total_spent: Decimal,
    pub total_remaining: Decimal,
    pub overall_percentage: f64,
    pub budget_summaries: Vec<BudgetSummary>,
    pub unbudgeted_spending: Decimal,
    pub generated_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct BudgetSummary {
    pub budget_name: String,
    pub budgeted: Decimal,
    pub spent: Decimal,
    pub remaining: Decimal,
    pub percentage: f64,
}

#[derive(Debug, Serialize, Deserialize)]
pub enum ReportPeriod {
    CurrentMonth,
    LastMonth,
    CurrentYear,
}
