use std::collections::HashMap;
use std::sync::Arc;
use chrono::{DateTime, Duration, Utc};
use redis::AsyncCommands;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use tracing::{error, info, warn};

use crate::error::{ApiError, ApiResult};

/// Exchange rate service for fetching and caching rates
pub struct ExchangeRateService {
    pool: Arc<PgPool>,
    redis_client: Option<Arc<redis::aio::ConnectionManager>>,
    http_client: reqwest::Client,
    api_config: ExchangeRateApiConfig,
}

#[derive(Clone)]
pub struct ExchangeRateApiConfig {
    /// API provider (e.g., "exchangerate-api", "fixer", "openexchangerates")
    pub provider: String,
    /// API key for the provider
    pub api_key: Option<String>,
    /// Base URL for the API
    pub base_url: String,
    /// Cache duration in minutes
    pub cache_duration_minutes: i64,
    /// Request timeout in seconds
    pub timeout_seconds: u64,
}

impl Default for ExchangeRateApiConfig {
    fn default() -> Self {
        Self {
            provider: "exchangerate-api".to_string(),
            api_key: std::env::var("EXCHANGE_RATE_API_KEY").ok(),
            base_url: "https://v6.exchangerate-api.com/v6".to_string(),
            cache_duration_minutes: 60, // Cache for 1 hour by default
            timeout_seconds: 10,
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct ExchangeRate {
    pub from_currency: String,
    pub to_currency: String,
    pub rate: f64,
    pub timestamp: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
struct ExchangeRateApiResponse {
    result: String,
    base_code: String,
    conversion_rates: HashMap<String, f64>,
    time_last_update_utc: Option<String>,
}

#[derive(Debug, Deserialize)]
struct FixerApiResponse {
    success: bool,
    base: String,
    rates: HashMap<String, f64>,
    timestamp: Option<i64>,
}

impl ExchangeRateService {
    pub fn new(
        pool: Arc<PgPool>,
        redis_client: Option<Arc<redis::aio::ConnectionManager>>,
    ) -> Self {
        Self {
            pool,
            redis_client,
            http_client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(10))
                .build()
                .unwrap(),
            api_config: ExchangeRateApiConfig::default(),
        }
    }

    /// Fetch exchange rates from external API or cache
    pub async fn get_rates(
        &self,
        base_currency: &str,
        target_currencies: Option<Vec<String>>,
        force_refresh: bool,
    ) -> ApiResult<Vec<ExchangeRate>> {
        // Try to get from cache first (unless force refresh)
        if !force_refresh {
            if let Some(cached_rates) = self.get_cached_rates(base_currency).await? {
                info!("Using cached exchange rates for {}", base_currency);
                return Ok(cached_rates);
            }
        }

        // Fetch from external API
        info!("Fetching fresh exchange rates for {}", base_currency);
        let rates = self.fetch_from_api(base_currency, target_currencies).await?;

        // Cache the results
        self.cache_rates(base_currency, &rates).await?;

        // Store in database for history
        self.store_rates_in_db(&rates).await?;

        Ok(rates)
    }

    /// Fetch rates from external API
    async fn fetch_from_api(
        &self,
        base_currency: &str,
        target_currencies: Option<Vec<String>>,
    ) -> ApiResult<Vec<ExchangeRate>> {
        match self.api_config.provider.as_str() {
            "exchangerate-api" => self.fetch_from_exchangerate_api(base_currency).await,
            "fixer" => self.fetch_from_fixer(base_currency).await,
            _ => self.fetch_from_exchangerate_api(base_currency).await,
        }
    }

    /// Fetch from exchangerate-api.com
    async fn fetch_from_exchangerate_api(
        &self,
        base_currency: &str,
    ) -> ApiResult<Vec<ExchangeRate>> {
        let api_key = self.api_config.api_key.as_ref()
            .ok_or_else(|| ApiError::Configuration("Exchange rate API key not configured".into()))?;

        let url = format!(
            "{}/{}/latest/{}",
            self.api_config.base_url,
            api_key,
            base_currency.to_uppercase()
        );

        let response = self.http_client
            .get(&url)
            .timeout(std::time::Duration::from_secs(self.api_config.timeout_seconds))
            .send()
            .await
            .map_err(|e| ApiError::ExternalService(format!("Failed to fetch rates: {}", e)))?;

        if !response.status().is_success() {
            return Err(ApiError::ExternalService(
                format!("API returned error status: {}", response.status())
            ));
        }

        let api_response: ExchangeRateApiResponse = response
            .json()
            .await
            .map_err(|e| ApiError::ExternalService(format!("Failed to parse response: {}", e)))?;

        if api_response.result != "success" {
            return Err(ApiError::ExternalService(
                format!("API returned error result: {}", api_response.result)
            ));
        }

        let timestamp = Utc::now();
        let rates: Vec<ExchangeRate> = api_response.conversion_rates
            .into_iter()
            .map(|(to_currency, rate)| ExchangeRate {
                from_currency: base_currency.to_uppercase(),
                to_currency,
                rate,
                timestamp,
            })
            .collect();

        Ok(rates)
    }

    /// Fetch from fixer.io
    async fn fetch_from_fixer(
        &self,
        base_currency: &str,
    ) -> ApiResult<Vec<ExchangeRate>> {
        let api_key = self.api_config.api_key.as_ref()
            .ok_or_else(|| ApiError::Configuration("Fixer API key not configured".into()))?;

        let url = format!(
            "http://data.fixer.io/api/latest?access_key={}&base={}",
            api_key,
            base_currency.to_uppercase()
        );

        let response = self.http_client
            .get(&url)
            .timeout(std::time::Duration::from_secs(self.api_config.timeout_seconds))
            .send()
            .await
            .map_err(|e| ApiError::ExternalService(format!("Failed to fetch rates: {}", e)))?;

        let api_response: FixerApiResponse = response
            .json()
            .await
            .map_err(|e| ApiError::ExternalService(format!("Failed to parse response: {}", e)))?;

        if !api_response.success {
            return Err(ApiError::ExternalService("Fixer API returned error".into()));
        }

        let timestamp = api_response.timestamp
            .map(|ts| DateTime::from_timestamp(ts, 0).unwrap_or_else(Utc::now))
            .unwrap_or_else(Utc::now);

        let rates: Vec<ExchangeRate> = api_response.rates
            .into_iter()
            .map(|(to_currency, rate)| ExchangeRate {
                from_currency: base_currency.to_uppercase(),
                to_currency,
                rate,
                timestamp,
            })
            .collect();

        Ok(rates)
    }

    /// Get cached rates from Redis
    async fn get_cached_rates(&self, base_currency: &str) -> ApiResult<Option<Vec<ExchangeRate>>> {
        if let Some(redis) = &self.redis_client {
            let cache_key = format!("exchange_rates:{}", base_currency.to_uppercase());

            let mut conn = redis.as_ref().clone();
            let cached: Option<String> = conn.get(&cache_key).await
                .map_err(|e| {
                    warn!("Failed to get from Redis cache: {}", e);
                    ApiError::Cache(format!("Redis error: {}", e))
                })?;

            if let Some(cached_json) = cached {
                let rates: Vec<ExchangeRate> = serde_json::from_str(&cached_json)
                    .map_err(|e| ApiError::Cache(format!("Failed to deserialize cache: {}", e)))?;

                // Check if cache is still valid
                if let Some(first_rate) = rates.first() {
                    let age = Utc::now() - first_rate.timestamp;
                    if age < Duration::minutes(self.api_config.cache_duration_minutes) {
                        return Ok(Some(rates));
                    }
                }
            }
        }

        Ok(None)
    }

    /// Cache rates in Redis
    async fn cache_rates(&self, base_currency: &str, rates: &[ExchangeRate]) -> ApiResult<()> {
        if let Some(redis) = &self.redis_client {
            let cache_key = format!("exchange_rates:{}", base_currency.to_uppercase());
            let cache_json = serde_json::to_string(rates)
                .map_err(|e| ApiError::Cache(format!("Failed to serialize rates: {}", e)))?;

            let mut conn = redis.as_ref().clone();
            let expire_seconds = self.api_config.cache_duration_minutes * 60;

            conn.set_ex(&cache_key, cache_json, expire_seconds as u64)
                .await
                .map_err(|e| {
                    warn!("Failed to cache in Redis: {}", e);
                    ApiError::Cache(format!("Redis error: {}", e))
                })?;

            info!("Cached exchange rates for {} ({} rates)", base_currency, rates.len());
        }

        Ok(())
    }

    /// Store rates in database for historical tracking
    async fn store_rates_in_db(&self, rates: &[ExchangeRate]) -> ApiResult<()> {
        if rates.is_empty() {
            return Ok(());
        }

        // Store rates in the exchange_rates table (if it exists)
        for rate in rates {
            sqlx::query!(
                r#"
                INSERT INTO exchange_rates (from_currency, to_currency, rate, rate_date, source)
                VALUES ($1, $2, $3, $4, $5)
                ON CONFLICT (from_currency, to_currency, rate_date)
                DO UPDATE SET rate = $3, source = $5, updated_at = NOW()
                "#,
                rate.from_currency,
                rate.to_currency,
                rate.rate as f64,
                rate.timestamp.date_naive(),
                self.api_config.provider
            )
            .execute(self.pool.as_ref())
            .await
            .map_err(|e| {
                warn!("Failed to store rate in DB: {}", e);
                // Don't fail the whole operation if DB storage fails
                e
            })
            .ok();
        }

        info!("Stored {} exchange rates in database", rates.len());
        Ok(())
    }

    /// Update rates for all active currencies
    pub async fn update_all_rates(&self) -> ApiResult<()> {
        // Get all active currencies from database
        let currencies = sqlx::query!(
            "SELECT code FROM currencies WHERE is_active = true"
        )
        .fetch_all(self.pool.as_ref())
        .await?;

        let mut success_count = 0;
        let mut error_count = 0;

        for currency in currencies {
            match self.get_rates(&currency.code, None, true).await {
                Ok(rates) => {
                    success_count += 1;
                    info!("Updated {} rates for {}", rates.len(), currency.code);
                }
                Err(e) => {
                    error_count += 1;
                    error!("Failed to update rates for {}: {}", currency.code, e);
                }
            }

            // Add a small delay to avoid hitting rate limits
            tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
        }

        info!(
            "Exchange rate update completed: {} successful, {} failed",
            success_count, error_count
        );

        if error_count > 0 && success_count == 0 {
            return Err(ApiError::ExternalService(
                "All rate updates failed".into()
            ));
        }

        Ok(())
    }
}

/// Background task to periodically update exchange rates
pub async fn start_rate_update_task(service: Arc<ExchangeRateService>) {
    let interval_minutes = service.api_config.cache_duration_minutes;
    let mut interval = tokio::time::interval(
        tokio::time::Duration::from_secs((interval_minutes * 60) as u64)
    );

    loop {
        interval.tick().await;

        info!("Starting scheduled exchange rate update");
        if let Err(e) = service.update_all_rates().await {
            error!("Scheduled rate update failed: {}", e);
        }
    }
}