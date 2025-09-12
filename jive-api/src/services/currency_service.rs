use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use uuid::Uuid;
use std::collections::HashMap;
use std::future::Future;
use std::pin::Pin;

use super::ServiceError;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Currency {
    pub code: String,
    pub name: String,
    pub symbol: String,
    pub decimal_places: i32,
    pub is_active: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExchangeRate {
    pub id: Uuid,
    pub from_currency: String,
    pub to_currency: String,
    pub rate: Decimal,
    pub source: String,
    pub effective_date: NaiveDate,
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CurrencyPreference {
    pub currency_code: String,
    pub is_primary: bool,
    pub display_order: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilyCurrencySettings {
    pub family_id: Uuid,
    pub base_currency: String,
    pub allow_multi_currency: bool,
    pub auto_convert: bool,
    pub supported_currencies: Vec<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateCurrencySettingsRequest {
    pub base_currency: Option<String>,
    pub allow_multi_currency: Option<bool>,
    pub auto_convert: Option<bool>,
    pub supported_currencies: Option<Vec<String>>,
}

#[derive(Debug, Deserialize)]
pub struct AddExchangeRateRequest {
    pub from_currency: String,
    pub to_currency: String,
    pub rate: Decimal,
    pub source: Option<String>,
}

pub struct CurrencyService {
    pool: PgPool,
}

impl CurrencyService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
    
    /// 获取所有支持的货币
    pub async fn get_supported_currencies(&self) -> Result<Vec<Currency>, ServiceError> {
        let rows = sqlx::query!(
            r#"
            SELECT code, name, symbol, decimal_places, is_active
            FROM currencies
            WHERE is_active = true
            ORDER BY code
            "#
        )
        .fetch_all(&self.pool)
        .await?;
        
        let currencies = rows.into_iter().map(|row| Currency {
            code: row.code,
            name: row.name,
            symbol: row.symbol, // 列已为非 NULL（或宏推断非可选）
            decimal_places: row.decimal_places.unwrap_or(2),
            is_active: row.is_active.unwrap_or(true),
        }).collect();
        
        Ok(currencies)
    }
    
    /// 获取用户的货币偏好
    pub async fn get_user_currency_preferences(
        &self,
        user_id: Uuid,
    ) -> Result<Vec<CurrencyPreference>, ServiceError> {
        let rows = sqlx::query!(
            r#"
            SELECT currency_code, is_primary, display_order
            FROM user_currency_preferences
            WHERE user_id = $1
            ORDER BY display_order, currency_code
            "#,
            user_id
        )
        .fetch_all(&self.pool)
        .await?;
        
        let preferences = rows.into_iter().map(|row| CurrencyPreference {
            currency_code: row.currency_code,
            is_primary: row.is_primary.unwrap_or(false),
            display_order: row.display_order.unwrap_or(0),
        }).collect();
        
        Ok(preferences)
    }
    
    /// 设置用户的货币偏好
    pub async fn set_user_currency_preferences(
        &self,
        user_id: Uuid,
        currencies: Vec<String>,
        primary_currency: String,
    ) -> Result<(), ServiceError> {
        let mut tx = self.pool.begin().await?;
        
        // 删除现有偏好
        sqlx::query!(
            "DELETE FROM user_currency_preferences WHERE user_id = $1",
            user_id
        )
        .execute(&mut *tx)
        .await?;
        
        // 插入新偏好
        for (index, currency) in currencies.iter().enumerate() {
            sqlx::query!(
                r#"
                INSERT INTO user_currency_preferences 
                (user_id, currency_code, is_primary, display_order)
                VALUES ($1, $2, $3, $4)
                "#,
                user_id,
                currency,
                currency == &primary_currency,
                index as i32
            )
            .execute(&mut *tx)
            .await?;
        }
        
        tx.commit().await?;
        Ok(())
    }
    
    /// 获取家庭的货币设置
    pub async fn get_family_currency_settings(
        &self,
        family_id: Uuid,
    ) -> Result<FamilyCurrencySettings, ServiceError> {
        // 获取基本设置
        let settings = sqlx::query!(
            r#"
            SELECT base_currency, allow_multi_currency, auto_convert
            FROM family_currency_settings
            WHERE family_id = $1
            "#,
            family_id
        )
        .fetch_optional(&self.pool)
        .await?;
        
        if let Some(settings) = settings {
            // 获取支持的货币列表
            let supported = self.get_family_supported_currencies(family_id).await?;
            
            Ok(FamilyCurrencySettings {
                family_id,
                base_currency: settings.base_currency,
                allow_multi_currency: settings.allow_multi_currency.unwrap_or(false),
                auto_convert: settings.auto_convert.unwrap_or(false),
                supported_currencies: supported,
            })
        } else {
            // 返回默认设置
            Ok(FamilyCurrencySettings {
                family_id,
                base_currency: "CNY".to_string(),
                allow_multi_currency: true,
                auto_convert: false,
                supported_currencies: vec!["CNY".to_string(), "USD".to_string()],
            })
        }
    }
    
    /// 更新家庭的货币设置
    pub async fn update_family_currency_settings(
        &self,
        family_id: Uuid,
        request: UpdateCurrencySettingsRequest,
    ) -> Result<FamilyCurrencySettings, ServiceError> {
        let mut tx = self.pool.begin().await?;
        
        // 插入或更新设置
        sqlx::query!(
            r#"
            INSERT INTO family_currency_settings 
            (family_id, base_currency, allow_multi_currency, auto_convert)
            VALUES ($1, $2, $3, $4)
            ON CONFLICT (family_id) 
            DO UPDATE SET
                base_currency = COALESCE($2, family_currency_settings.base_currency),
                allow_multi_currency = COALESCE($3, family_currency_settings.allow_multi_currency),
                auto_convert = COALESCE($4, family_currency_settings.auto_convert),
                updated_at = CURRENT_TIMESTAMP
            "#,
            family_id,
            request.base_currency.as_deref().unwrap_or("CNY"),
            request.allow_multi_currency.unwrap_or(true),
            request.auto_convert.unwrap_or(false)
        )
        .execute(&mut *tx)
        .await?;
        
        tx.commit().await?;
        
        self.get_family_currency_settings(family_id).await
    }
    
    /// 获取汇率
    pub fn get_exchange_rate<'a>(
        &'a self,
        from_currency: &'a str,
        to_currency: &'a str,
        date: Option<NaiveDate>,
    ) -> Pin<Box<dyn Future<Output = Result<Decimal, ServiceError>> + Send + 'a>> {
        Box::pin(async move {
            self.get_exchange_rate_impl(from_currency, to_currency, date).await
        })
    }
    
    async fn get_exchange_rate_impl(
        &self,
        from_currency: &str,
        to_currency: &str,
        date: Option<NaiveDate>,
    ) -> Result<Decimal, ServiceError> {
        if from_currency == to_currency {
            return Ok(Decimal::ONE);
        }
        
        let effective_date = date.unwrap_or_else(|| Utc::now().date_naive());
        
        // 尝试直接获取汇率
        let rate = sqlx::query_scalar!(
            r#"
            SELECT rate
            FROM exchange_rates
            WHERE from_currency = $1 
            AND to_currency = $2
            AND effective_date <= $3
            ORDER BY effective_date DESC
            LIMIT 1
            "#,
            from_currency,
            to_currency,
            effective_date
        )
        .fetch_optional(&self.pool)
        .await?;
        
        if let Some(rate) = rate {
            return Ok(rate);
        }
        
        // 尝试获取反向汇率
        let reverse_rate = sqlx::query_scalar!(
            r#"
            SELECT rate
            FROM exchange_rates
            WHERE from_currency = $2 
            AND to_currency = $1
            AND effective_date <= $3
            ORDER BY effective_date DESC
            LIMIT 1
            "#,
            from_currency,
            to_currency,
            effective_date
        )
        .fetch_optional(&self.pool)
        .await?;
        
        if let Some(rate) = reverse_rate {
            return Ok(Decimal::ONE / rate);
        }
        
        // 尝试通过USD中转（最常见的中转货币）
        let from_to_usd = Box::pin(self.get_exchange_rate_impl(from_currency, "USD", Some(effective_date))).await;
        let usd_to_target = Box::pin(self.get_exchange_rate_impl("USD", to_currency, Some(effective_date))).await;
        
        if let (Ok(rate1), Ok(rate2)) = (from_to_usd, usd_to_target) {
            return Ok(rate1 * rate2);
        }
        
        Err(ServiceError::NotFound {
            resource_type: "ExchangeRate".to_string(),
            id: format!("{}-{}", from_currency, to_currency),
        })
    }
    
    /// 批量获取汇率
    pub async fn get_exchange_rates(
        &self,
        base_currency: &str,
        target_currencies: Vec<String>,
        date: Option<NaiveDate>,
    ) -> Result<HashMap<String, Decimal>, ServiceError> {
        let mut rates = HashMap::new();
        
        for currency in target_currencies {
            if let Ok(rate) = self.get_exchange_rate(base_currency, &currency, date).await {
                rates.insert(currency, rate);
            }
        }
        
        Ok(rates)
    }
    
    /// 添加或更新汇率
    pub async fn add_exchange_rate(
        &self,
        request: AddExchangeRateRequest,
    ) -> Result<ExchangeRate, ServiceError> {
        let id = Uuid::new_v4();
        let effective_date = Utc::now().date_naive();
        
        let row = sqlx::query!(
            r#"
            INSERT INTO exchange_rates 
            (id, from_currency, to_currency, rate, source, date, effective_date)
            VALUES ($1, $2, $3, $4, $5, $6, $6)
            ON CONFLICT (from_currency, to_currency, date)
            DO UPDATE SET 
                rate = $4,
                source = $5,
                effective_date = $6,
                updated_at = CURRENT_TIMESTAMP
            RETURNING id, from_currency, to_currency, rate, source, 
                      effective_date, created_at
            "#,
            id,
            request.from_currency,
            request.to_currency,
            request.rate,
            request.source.unwrap_or_else(|| "manual".to_string()),
            effective_date
        )
        .fetch_one(&self.pool)
        .await?;

        let effective = row.effective_date; // 若为非可选
        let created_at = row.created_at.unwrap_or_else(|| Utc::now());

        Ok(ExchangeRate {
            id: row.id,
            from_currency: row.from_currency,
            to_currency: row.to_currency,
            rate: row.rate,
            source: row.source.unwrap_or_else(|| "manual".to_string()),
            effective_date: effective,
            created_at,
        })
    }
    
    /// 货币转换
    pub fn convert_amount(
        &self,
        amount: Decimal,
        rate: Decimal,
        from_decimal_places: i32,
        to_decimal_places: i32,
    ) -> Decimal {
        let converted = amount * rate;
        
        // 根据目标货币的小数位数进行舍入
        let scale = 10_i64.pow(to_decimal_places as u32);
        let scaled = converted * Decimal::from(scale);
        let rounded = scaled.round();
        rounded / Decimal::from(scale)
    }
    
    /// 获取最近的汇率历史
    pub async fn get_exchange_rate_history(
        &self,
        from_currency: &str,
        to_currency: &str,
        days: i32,
    ) -> Result<Vec<ExchangeRate>, ServiceError> {
        let start_date = (Utc::now() - chrono::Duration::days(days as i64)).date_naive();
        
        let rows = sqlx::query!(
            r#"
            SELECT id, from_currency, to_currency, rate, source, 
                   effective_date, created_at
            FROM exchange_rates
            WHERE from_currency = $1 
            AND to_currency = $2
            AND effective_date >= $3
            ORDER BY effective_date DESC
            "#,
            from_currency,
            to_currency,
            start_date
        )
        .fetch_all(&self.pool)
        .await?;
        
        Ok(rows.into_iter().map(|row| ExchangeRate {
            id: row.id,
            from_currency: row.from_currency,
            to_currency: row.to_currency,
            rate: row.rate,
            source: row.source.unwrap_or_else(|| "manual".to_string()),
            effective_date: row.effective_date, // 非可选
            created_at: row.created_at.unwrap_or_else(|| Utc::now()),
        }).collect())
    }
    
    /// 获取家庭支持的货币列表
    async fn get_family_supported_currencies(
        &self,
        family_id: Uuid,
    ) -> Result<Vec<String>, ServiceError> {
        // 从账户中获取实际使用的货币
        let currencies = sqlx::query_scalar!(
            r#"
            SELECT DISTINCT a.currency
            FROM accounts a
            JOIN ledgers l ON a.ledger_id = l.id
            WHERE l.family_id = $1 AND a.currency IS NOT NULL
            ORDER BY a.currency
            "#,
            family_id
        )
        .fetch_all(&self.pool)
        .await?;
        
        let currencies: Vec<String> = currencies
            .into_iter()
            .filter_map(|c| c)
            .collect();
        
        if currencies.is_empty() {
            // 返回默认货币
            Ok(vec!["CNY".to_string(), "USD".to_string()])
        } else {
            Ok(currencies)
        }
    }
    
    /// 自动获取最新汇率并更新到数据库
    pub async fn fetch_latest_rates(&self, base_currency: &str) -> Result<(), ServiceError> {
        use super::exchange_rate_api::EXCHANGE_RATE_SERVICE;
        
        tracing::info!("Fetching latest exchange rates for {}", base_currency);
        
        // 获取汇率服务实例
        let mut service = EXCHANGE_RATE_SERVICE.lock().await;
        
        // 获取最新汇率
        let rates = service.fetch_fiat_rates(base_currency).await?;
        
        // 批量更新到数据库
        let effective_date = Utc::now().date_naive();
        
        for (target_currency, rate) in rates.iter() {
            if target_currency != base_currency {
                let id = Uuid::new_v4();
                
                // 插入或更新汇率
                sqlx::query!(
                    r#"
                    INSERT INTO exchange_rates 
                    (id, from_currency, to_currency, rate, source, date, effective_date)
                    VALUES ($1, $2, $3, $4, $5, $6, $6)
                    ON CONFLICT (from_currency, to_currency, date)
                    DO UPDATE SET 
                        rate = $4,
                        source = $5,
                        effective_date = $6,
                        updated_at = CURRENT_TIMESTAMP
                    "#,
                    id,
                    base_currency,
                    target_currency.as_str(),
                    rate,
                    "api",
                    effective_date
                )
                .execute(&self.pool)
                .await?;
            }
        }
        
        tracing::info!("Successfully updated {} exchange rates for {}", rates.len() - 1, base_currency);
        Ok(())
    }
    
    /// 获取并更新加密货币价格
    pub async fn fetch_crypto_prices(&self, crypto_codes: Vec<&str>, fiat_currency: &str) -> Result<(), ServiceError> {
        use super::exchange_rate_api::EXCHANGE_RATE_SERVICE;
        
        tracing::info!("Fetching crypto prices in {}", fiat_currency);
        
        // 获取汇率服务实例
        let mut service = EXCHANGE_RATE_SERVICE.lock().await;
        
        // 获取加密货币价格
        let prices = service.fetch_crypto_prices(crypto_codes.clone(), fiat_currency).await?;
        
        // 批量更新到数据库
        for (crypto_code, price) in prices.iter() {
            sqlx::query!(
                r#"
                INSERT INTO crypto_prices 
                (crypto_code, base_currency, price, source, last_updated)
                VALUES ($1, $2, $3, $4, CURRENT_TIMESTAMP)
                ON CONFLICT (crypto_code, base_currency)
                DO UPDATE SET 
                    price = $3,
                    source = $4,
                    last_updated = CURRENT_TIMESTAMP
                "#,
                crypto_code,
                fiat_currency,
                price,
                "api"
            )
            .execute(&self.pool)
            .await?;
        }
        
        tracing::info!("Successfully updated {} crypto prices in {}", prices.len(), fiat_currency);
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal_macros::dec;
    
    #[test]
    fn test_convert_amount() {
        let service = CurrencyService::new(PgPool::new(""));
        
        // CNY to USD
        let amount = dec!(100.00);
        let rate = dec!(0.1380);
        let result = service.convert_amount(amount, rate, 2, 2);
        assert_eq!(result, dec!(13.80));
        
        // CNY to JPY (0 decimal places)
        let amount = dec!(100.00);
        let rate = dec!(20.3551);
        let result = service.convert_amount(amount, rate, 2, 0);
        assert_eq!(result, dec!(2036));
    }
}
