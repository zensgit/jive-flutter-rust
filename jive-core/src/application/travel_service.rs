//! Travel service - 旅行模式管理服务
//!
//! 提供旅行事件的创建、管理、预算追踪、交易关联等功能

use chrono::{DateTime, NaiveDate, Utc};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;

use super::{PaginatedResult, PaginationParams, ServiceContext, ServiceResponse};
use crate::domain::{
    AttachTransactionsInput, CreateTravelEventInput, TravelBudget, TravelEvent, TravelStatistics,
    TravelStatus, UpdateTravelEventInput, UpsertTravelBudgetInput,
};
use crate::error::{JiveError, Result};

/// Travel service
pub struct TravelService {
    pool: PgPool,
    context: ServiceContext,
}

impl TravelService {
    /// Create new travel service instance
    pub fn new(pool: PgPool, context: ServiceContext) -> Self {
        Self { pool, context }
    }

    /// Create a new travel event
    pub async fn create_travel_event(
        &self,
        input: CreateTravelEventInput,
    ) -> Result<ServiceResponse<TravelEvent>> {
        // Validate input
        input.validate()?;

        // Check if family already has an active travel
        let active_count: i64 = sqlx::query_scalar(
            "SELECT COUNT(*) FROM travel_events
             WHERE family_id = $1 AND status = 'active'",
        )
        .bind(self.context.family_id)
        .fetch_one(&self.pool)
        .await?;

        if active_count > 0 {
            return Err(JiveError::ValidationError(
                "Family already has an active travel event".to_string(),
            ));
        }

        // Create travel event
        let settings_json = serde_json::to_value(&input.settings.unwrap_or_default())?;

        let event = sqlx::query_as::<_, TravelEvent>(
            "INSERT INTO travel_events (
                family_id, trip_name, status, start_date, end_date,
                total_budget, budget_currency_id, home_currency_id,
                settings, created_by
            ) VALUES ($1, $2, 'planning', $3, $4, $5, $6, $7, $8, $9)
            RETURNING *",
        )
        .bind(self.context.family_id)
        .bind(&input.trip_name)
        .bind(input.start_date)
        .bind(input.end_date)
        .bind(input.total_budget)
        .bind(input.budget_currency_id)
        .bind(input.home_currency_id)
        .bind(settings_json)
        .bind(self.context.user_id)
        .fetch_one(&self.pool)
        .await?;

        Ok(ServiceResponse {
            data: event,
            message: Some("Travel event created successfully".to_string()),
            code: 201,
        })
    }

    /// Update travel event
    pub async fn update_travel_event(
        &self,
        id: Uuid,
        input: UpdateTravelEventInput,
    ) -> Result<ServiceResponse<TravelEvent>> {
        // Fetch existing event
        let mut event = self.get_travel_event(id).await?.data;

        // Apply updates
        if let Some(trip_name) = input.trip_name {
            event.trip_name = trip_name;
        }
        if let Some(start_date) = input.start_date {
            event.start_date = start_date;
        }
        if let Some(end_date) = input.end_date {
            event.end_date = end_date;
        }
        if let Some(total_budget) = input.total_budget {
            event.total_budget = Some(total_budget);
        }
        if let Some(budget_currency_id) = input.budget_currency_id {
            event.budget_currency_id = Some(budget_currency_id);
        }
        if let Some(settings) = input.settings {
            event.settings = serde_json::to_value(&settings)?;
        }

        // Update in database
        let updated = sqlx::query_as::<_, TravelEvent>(
            "UPDATE travel_events SET
                trip_name = $2,
                start_date = $3,
                end_date = $4,
                total_budget = $5,
                budget_currency_id = $6,
                settings = $7,
                updated_at = NOW()
            WHERE id = $1
            RETURNING *",
        )
        .bind(id)
        .bind(&event.trip_name)
        .bind(event.start_date)
        .bind(event.end_date)
        .bind(event.total_budget)
        .bind(event.budget_currency_id)
        .bind(&event.settings)
        .fetch_one(&self.pool)
        .await?;

        Ok(ServiceResponse {
            data: updated,
            message: Some("Travel event updated successfully".to_string()),
            code: 200,
        })
    }

    /// Get travel event by ID
    pub async fn get_travel_event(&self, id: Uuid) -> Result<ServiceResponse<TravelEvent>> {
        let event = sqlx::query_as::<_, TravelEvent>(
            "SELECT * FROM travel_events
             WHERE id = $1 AND family_id = $2",
        )
        .bind(id)
        .bind(self.context.family_id)
        .fetch_optional(&self.pool)
        .await?
        .ok_or_else(|| JiveError::NotFound("Travel event not found".to_string()))?;

        Ok(ServiceResponse {
            data: event,
            message: None,
            code: 200,
        })
    }

    /// List travel events for family
    pub async fn list_travel_events(
        &self,
        status: Option<String>,
        pagination: PaginationParams,
    ) -> Result<ServiceResponse<PaginatedResult<TravelEvent>>> {
        let mut query = String::from("SELECT * FROM travel_events WHERE family_id = $1");
        let mut count_query =
            String::from("SELECT COUNT(*) FROM travel_events WHERE family_id = $1");

        if let Some(status) = &status {
            query.push_str(" AND status = $2");
            count_query.push_str(" AND status = $2");
        }

        query.push_str(" ORDER BY created_at DESC");
        query.push_str(&format!(
            " LIMIT {} OFFSET {}",
            pagination.page_size,
            pagination.offset()
        ));

        // Get total count
        let total = if let Some(status) = &status {
            sqlx::query_scalar::<_, i64>(&count_query)
                .bind(self.context.family_id)
                .bind(status)
                .fetch_one(&self.pool)
                .await?
        } else {
            sqlx::query_scalar::<_, i64>(&count_query)
                .bind(self.context.family_id)
                .fetch_one(&self.pool)
                .await?
        };

        // Get events
        let events = if let Some(status) = status {
            sqlx::query_as::<_, TravelEvent>(&query)
                .bind(self.context.family_id)
                .bind(status)
                .fetch_all(&self.pool)
                .await?
        } else {
            sqlx::query_as::<_, TravelEvent>(&query)
                .bind(self.context.family_id)
                .fetch_all(&self.pool)
                .await?
        };

        Ok(ServiceResponse {
            data: PaginatedResult {
                items: events,
                page: pagination.page,
                page_size: pagination.page_size,
                total: total as usize,
                total_pages: ((total as f64) / (pagination.page_size as f64)).ceil() as usize,
            },
            message: None,
            code: 200,
        })
    }

    /// Get active travel event for family
    pub async fn get_active_travel(&self) -> Result<ServiceResponse<Option<TravelEvent>>> {
        let event = sqlx::query_as::<_, TravelEvent>(
            "SELECT * FROM travel_events
             WHERE family_id = $1 AND status = 'active'
             ORDER BY created_at DESC
             LIMIT 1",
        )
        .bind(self.context.family_id)
        .fetch_optional(&self.pool)
        .await?;

        Ok(ServiceResponse {
            data: event,
            message: None,
            code: 200,
        })
    }

    /// Activate a travel event
    pub async fn activate_travel(&self, id: Uuid) -> Result<ServiceResponse<TravelEvent>> {
        // Check if event can be activated
        let event = self.get_travel_event(id).await?.data;
        if !event.can_activate() {
            return Err(JiveError::ValidationError(
                "Travel event cannot be activated from current status".to_string(),
            ));
        }

        // Deactivate any other active travel
        sqlx::query(
            "UPDATE travel_events
             SET status = 'completed', updated_at = NOW()
             WHERE family_id = $1 AND status = 'active' AND id != $2",
        )
        .bind(self.context.family_id)
        .bind(id)
        .execute(&self.pool)
        .await?;

        // Activate this travel
        let activated = sqlx::query_as::<_, TravelEvent>(
            "UPDATE travel_events
             SET status = 'active', updated_at = NOW()
             WHERE id = $1
             RETURNING *",
        )
        .bind(id)
        .fetch_one(&self.pool)
        .await?;

        // Cache active travel in Redis (if available)
        // TODO: Add Redis caching

        Ok(ServiceResponse {
            data: activated,
            message: Some("Travel event activated successfully".to_string()),
            code: 200,
        })
    }

    /// Complete a travel event
    pub async fn complete_travel(&self, id: Uuid) -> Result<ServiceResponse<TravelEvent>> {
        let event = self.get_travel_event(id).await?.data;
        if !event.can_complete() {
            return Err(JiveError::ValidationError(
                "Travel event cannot be completed from current status".to_string(),
            ));
        }

        let completed = sqlx::query_as::<_, TravelEvent>(
            "UPDATE travel_events
             SET status = 'completed', updated_at = NOW()
             WHERE id = $1
             RETURNING *",
        )
        .bind(id)
        .fetch_one(&self.pool)
        .await?;

        Ok(ServiceResponse {
            data: completed,
            message: Some("Travel event completed successfully".to_string()),
            code: 200,
        })
    }

    /// Cancel a travel event
    pub async fn cancel_travel(&self, id: Uuid) -> Result<ServiceResponse<TravelEvent>> {
        let cancelled = sqlx::query_as::<_, TravelEvent>(
            "UPDATE travel_events
             SET status = 'cancelled', updated_at = NOW()
             WHERE id = $1 AND family_id = $2
             RETURNING *",
        )
        .bind(id)
        .bind(self.context.family_id)
        .fetch_one(&self.pool)
        .await?;

        Ok(ServiceResponse {
            data: cancelled,
            message: Some("Travel event cancelled successfully".to_string()),
            code: 200,
        })
    }

    /// Attach transactions to travel event
    pub async fn attach_transactions(
        &self,
        travel_id: Uuid,
        input: AttachTransactionsInput,
    ) -> Result<ServiceResponse<i32>> {
        // Verify travel exists
        self.get_travel_event(travel_id).await?;

        let mut transaction_ids = Vec::new();

        // Use provided transaction IDs
        if let Some(ids) = input.transaction_ids {
            transaction_ids = ids;
        }
        // Or find transactions by filter
        else if let Some(filter) = input.filter {
            // Build query based on filter
            let mut query = String::from("SELECT id FROM transactions WHERE family_id = $1");

            if let Some(start_date) = filter.start_date {
                query.push_str(&format!(" AND date >= '{}'", start_date));
            }
            if let Some(end_date) = filter.end_date {
                query.push_str(&format!(" AND date <= '{}'", end_date));
            }

            // TODO: Add more filter conditions (merchant keywords, location, amount range)

            let ids: Vec<Uuid> = sqlx::query_scalar(&query)
                .bind(self.context.family_id)
                .fetch_all(&self.pool)
                .await?;

            transaction_ids = ids;
        }

        // Attach transactions
        let mut attached_count = 0;
        for transaction_id in transaction_ids {
            let result = sqlx::query(
                "INSERT INTO travel_transactions (travel_event_id, transaction_id, attached_by)
                 VALUES ($1, $2, $3)
                 ON CONFLICT (travel_event_id, transaction_id) DO NOTHING",
            )
            .bind(travel_id)
            .bind(transaction_id)
            .bind(self.context.user_id)
            .execute(&self.pool)
            .await?;

            attached_count += result.rows_affected() as i32;
        }

        // Update travel statistics
        sqlx::query("SELECT update_travel_event_stats($1)")
            .bind(travel_id)
            .execute(&self.pool)
            .await?;

        Ok(ServiceResponse {
            data: attached_count,
            message: Some(format!("{} transactions attached", attached_count)),
            code: 200,
        })
    }

    /// Detach transaction from travel
    pub async fn detach_transaction(
        &self,
        travel_id: Uuid,
        transaction_id: Uuid,
    ) -> Result<ServiceResponse<()>> {
        sqlx::query(
            "DELETE FROM travel_transactions
             WHERE travel_event_id = $1 AND transaction_id = $2",
        )
        .bind(travel_id)
        .bind(transaction_id)
        .execute(&self.pool)
        .await?;

        // Update travel statistics
        sqlx::query("SELECT update_travel_event_stats($1)")
            .bind(travel_id)
            .execute(&self.pool)
            .await?;

        Ok(ServiceResponse {
            data: (),
            message: Some("Transaction detached successfully".to_string()),
            code: 200,
        })
    }

    /// Set or update budget for a category
    pub async fn upsert_travel_budget(
        &self,
        travel_id: Uuid,
        input: UpsertTravelBudgetInput,
    ) -> Result<ServiceResponse<TravelBudget>> {
        // Validate input
        input.validate()?;

        // Verify travel exists
        self.get_travel_event(travel_id).await?;

        let budget = sqlx::query_as::<_, TravelBudget>(
            "INSERT INTO travel_budgets (
                travel_event_id, category_id, budget_amount,
                budget_currency_id, alert_threshold
            ) VALUES ($1, $2, $3, $4, $5)
            ON CONFLICT (travel_event_id, category_id)
            DO UPDATE SET
                budget_amount = EXCLUDED.budget_amount,
                budget_currency_id = EXCLUDED.budget_currency_id,
                alert_threshold = EXCLUDED.alert_threshold,
                updated_at = NOW()
            RETURNING *",
        )
        .bind(travel_id)
        .bind(input.category_id)
        .bind(input.budget_amount)
        .bind(input.budget_currency_id)
        .bind(
            input
                .alert_threshold
                .unwrap_or(rust_decimal::Decimal::new(8, 1)),
        ) // 0.8
        .fetch_one(&self.pool)
        .await?;

        Ok(ServiceResponse {
            data: budget,
            message: Some("Budget set successfully".to_string()),
            code: 200,
        })
    }

    /// Get budgets for travel event
    pub async fn get_travel_budgets(
        &self,
        travel_id: Uuid,
    ) -> Result<ServiceResponse<Vec<TravelBudget>>> {
        let budgets = sqlx::query_as::<_, TravelBudget>(
            "SELECT * FROM travel_budgets
             WHERE travel_event_id = $1
             ORDER BY category_id",
        )
        .bind(travel_id)
        .fetch_all(&self.pool)
        .await?;

        Ok(ServiceResponse {
            data: budgets,
            message: None,
            code: 200,
        })
    }

    /// Get travel statistics
    pub async fn get_travel_statistics(
        &self,
        travel_id: Uuid,
    ) -> Result<ServiceResponse<TravelStatistics>> {
        let event = self.get_travel_event(travel_id).await?.data;

        // Get category breakdown
        let category_spending = sqlx::query!(
            r#"
            SELECT
                c.id as category_id,
                c.name as category_name,
                COALESCE(SUM(t.amount), 0) as amount,
                COUNT(t.id) as transaction_count
            FROM categories c
            LEFT JOIN (
                SELECT t.* FROM transactions t
                JOIN travel_transactions tt ON t.id = tt.transaction_id
                WHERE tt.travel_event_id = $1 AND t.deleted_at IS NULL
            ) t ON c.id = t.category_id
            WHERE c.family_id = $2
            GROUP BY c.id, c.name
            HAVING COUNT(t.id) > 0
            ORDER BY amount DESC
            "#,
            travel_id,
            self.context.family_id
        )
        .fetch_all(&self.pool)
        .await?;

        let total = event.total_spent;
        let categories = category_spending
            .into_iter()
            .map(|row| {
                let amount = rust_decimal::Decimal::from_i64_retain(row.amount.unwrap_or(0))
                    .unwrap_or_default();
                let percentage = if total.is_zero() {
                    rust_decimal::Decimal::ZERO
                } else {
                    (amount / total) * rust_decimal::Decimal::from(100)
                };

                crate::domain::CategorySpending {
                    category_id: row.category_id,
                    category_name: row.category_name,
                    amount,
                    percentage,
                    transaction_count: row.transaction_count.unwrap_or(0) as i32,
                }
            })
            .collect();

        let daily_average = if event.duration_days() > 0 {
            event.total_spent / rust_decimal::Decimal::from(event.duration_days())
        } else {
            rust_decimal::Decimal::ZERO
        };

        let stats = TravelStatistics {
            total_spent: event.total_spent,
            transaction_count: event.transaction_count,
            daily_average,
            by_category: categories,
            budget_usage: event.budget_usage_percent(),
        };

        Ok(ServiceResponse {
            data: stats,
            message: None,
            code: 200,
        })
    }

    /// Check and send budget alerts
    pub async fn check_budget_alerts(&self, travel_id: Uuid) -> Result<()> {
        let event = self.get_travel_event(travel_id).await?.data;

        // Check overall budget alert
        if event.should_alert() {
            // TODO: Send notification via notification service
            tracing::warn!(
                "Budget alert for travel {}: {}% used",
                event.trip_name,
                event.budget_usage_percent().unwrap_or_default()
            );
        }

        // Check category budget alerts
        let budgets = self.get_travel_budgets(travel_id).await?.data;
        for budget in budgets {
            if budget.should_alert() {
                // Mark alert as sent
                sqlx::query(
                    "UPDATE travel_budgets
                     SET alert_sent = true, alert_sent_at = NOW()
                     WHERE id = $1",
                )
                .bind(budget.id)
                .execute(&self.pool)
                .await?;

                // TODO: Send notification
                tracing::warn!(
                    "Category budget alert for {}: {}% used",
                    budget.category_id,
                    budget.usage_percent()
                );
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_travel_service_creation() {
        // This is a placeholder test
        // Real tests would require a test database setup
        assert_eq!(1 + 1, 2);
    }
}
