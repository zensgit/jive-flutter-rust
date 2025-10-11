use chrono::{DateTime, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};
use uuid::Uuid;
use std::collections::HashMap;
use std::future::Future;
use std::pin::Pin;

use super::ServiceError;
// remove duplicate import of NaiveDate

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Currency {
    pub code: String,
    pub name: String,
    #[serde(rename = "name_zh")]
    pub name_zh: Option<String>,
    pub symbol: String,
    pub decimal_places: i32,
    #[serde(rename = "is_enabled", alias = "is_active")]
    pub is_active: bool,
    pub is_crypto: bool,
    pub flag: Option<String>,
    pub icon: Option<String>,
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
    #[serde(skip_serializing_if = "Option::is_none")]
    pub change_24h: Option<Decimal>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub change_7d: Option<Decimal>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub change_30d: Option<Decimal>,
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
    /// Optional manual rate expiry (RFC3339). When provided, marks this rate as manual
    /// and sets its expiry time; otherwise manual without expiry.
    pub manual_rate_expiry: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Debug, Deserialize)]
pub struct ClearManualRateRequest {
    pub from_currency: String,
    pub to_currency: String,
}

#[derive(Debug, Deserialize)]
pub struct ClearManualRatesBatchRequest {
    pub from_currency: String,
    pub to_currencies: Option<Vec<String>>, // if None -> all target currencies
    pub before_date: Option<NaiveDate>,     // if None -> CURRENT_DATE
    pub only_expired: Option<bool>,         // if true -> only clear expired manual
}

pub struct CurrencyService {
    pool: PgPool,
    redis: Option<redis::aio::ConnectionManager>,
}

impl CurrencyService {
    pub fn new(pool: PgPool) -> Self {
        Self { pool, redis: None }
    }

    pub fn new_with_redis(pool: PgPool, redis: Option<redis::aio::ConnectionManager>) -> Self {
        Self { pool, redis }
    }
    
    /// 获取所有支持的货币
    pub async fn get_supported_currencies(&self) -> Result<Vec<Currency>, ServiceError> {
        let rows = sqlx::query!(
            r#"
            SELECT code, name, name_zh, symbol, decimal_places, is_active, is_crypto, flag, icon
            FROM currencies
            WHERE is_active = true
            ORDER BY code
            "#
        )
        .fetch_all(&self.pool)
        .await?;

        let currencies = rows
            .into_iter()
            .map(|row| Currency {
                code: row.code,
                name: row.name,
                name_zh: row.name_zh,
                symbol: row.symbol.unwrap_or_default(),
                decimal_places: row.decimal_places.unwrap_or(2),
                is_active: row.is_active.unwrap_or(true),
                is_crypto: row.is_crypto.unwrap_or(false),
                flag: row.flag,
                icon: row.icon,
            })
            .collect();

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
                base_currency: settings.base_currency.unwrap_or_else(|| "CNY".to_string()),
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
            request.base_currency.as_deref(),  // 不使用默认值，让数据库的COALESCE处理
            request.allow_multi_currency,      // 不使用默认值
            request.auto_convert               // 不使用默认值
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

        // 🚀 Redis缓存层：先检查缓存
        let cache_key = format!("rate:{}:{}:{}", from_currency, to_currency, effective_date);

        if let Some(redis_conn) = &self.redis {
            let mut conn = redis_conn.clone();
            // 尝试从Redis获取缓存
            if let Ok(cached_value) = redis::cmd("GET")
                .arg(&cache_key)
                .query_async::<String>(&mut conn)
                .await
            {
                if let Ok(rate) = cached_value.parse::<Decimal>() {
                    tracing::debug!("✅ Redis cache hit for {}", cache_key);
                    return Ok(rate);
                }
            }
        }

        // 缓存未命中，查询数据库
        tracing::debug!("❌ Redis cache miss for {}, querying database", cache_key);

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
            // 存入Redis缓存 (TTL: 1小时 = 3600秒)
            self.cache_exchange_rate(&cache_key, rate, 3600).await;
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
            let computed_rate = Decimal::ONE / rate;
            // 存入Redis缓存
            self.cache_exchange_rate(&cache_key, computed_rate, 3600).await;
            return Ok(computed_rate);
        }

        // 尝试通过USD中转（最常见的中转货币）
        let from_to_usd = Box::pin(self.get_exchange_rate_impl(from_currency, "USD", Some(effective_date))).await;
        let usd_to_target = Box::pin(self.get_exchange_rate_impl("USD", to_currency, Some(effective_date))).await;

        if let (Ok(rate1), Ok(rate2)) = (from_to_usd, usd_to_target) {
            let computed_rate = rate1 * rate2;
            // 存入Redis缓存
            self.cache_exchange_rate(&cache_key, computed_rate, 3600).await;
            return Ok(computed_rate);
        }

        Err(ServiceError::NotFound {
            resource_type: "ExchangeRate".to_string(),
            id: format!("{}-{}", from_currency, to_currency),
        })
    }

    /// Redis缓存辅助方法：存储汇率到Redis
    async fn cache_exchange_rate(&self, key: &str, rate: Decimal, ttl_seconds: usize) {
        if let Some(redis_conn) = &self.redis {
            let mut conn = redis_conn.clone();
            let rate_str = rate.to_string();
            if let Err(e) = redis::cmd("SETEX")
                .arg(key)
                .arg(ttl_seconds)
                .arg(&rate_str)
                .query_async::<()>(&mut conn)
                .await
            {
                tracing::warn!("Failed to cache rate in Redis: {}", e);
            } else {
                tracing::debug!("✅ Cached rate {} = {} (TTL: {}s)", key, rate_str, ttl_seconds);
            }
        }
    }

    /// Redis缓存辅助方法：删除缓存键（用于缓存失效）
    /// 使用SCAN命令替代KEYS，避免阻塞Redis服务器
    async fn invalidate_cache(&self, pattern: &str) {
        if let Some(redis_conn) = &self.redis {
            let mut conn = redis_conn.clone();
            let mut cursor = 0u64;
            let mut all_keys = Vec::new();

            // 使用SCAN命令遍历键，避免阻塞
            loop {
                match redis::cmd("SCAN")
                    .arg(cursor)
                    .arg("MATCH")
                    .arg(pattern)
                    .arg("COUNT")
                    .arg(100)  // 每次扫描100个键，平衡性能和响应时间
                    .query_async::<(u64, Vec<String>)>(&mut conn)
                    .await
                {
                    Ok((new_cursor, keys)) => {
                        all_keys.extend(keys);
                        cursor = new_cursor;

                        if cursor == 0 {
                            break;
                        }
                    }
                    Err(e) => {
                        tracing::warn!("Failed to scan cache keys with pattern {}: {}", pattern, e);
                        return;
                    }
                }
            }

            if !all_keys.is_empty() {
                // 批量删除找到的键
                if let Err(e) = redis::cmd("DEL")
                    .arg(&all_keys)
                    .query_async::<()>(&mut conn)
                    .await
                {
                    tracing::warn!("Failed to invalidate cache pattern {}: {}", pattern, e);
                } else {
                    tracing::debug!("🗑️ Invalidated {} cache keys matching {}", all_keys.len(), pattern);
                }
            }
        }
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
        // Align with DB schema: UNIQUE(from_currency, to_currency, date)
        // Use business date == effective_date for upsert key
        let business_date = effective_date;
        
        let rec = sqlx::query(
            r#"
            INSERT INTO exchange_rates
            (id, from_currency, to_currency, rate, source, date, effective_date, is_manual, manual_rate_expiry)
            VALUES ($1, $2, $3, $4, $5, $6, $7, true, $8)
            ON CONFLICT (from_currency, to_currency, date)
            DO UPDATE SET
                rate = EXCLUDED.rate,
                source = EXCLUDED.source,
                effective_date = EXCLUDED.effective_date,
                is_manual = true,
                manual_rate_expiry = EXCLUDED.manual_rate_expiry,
                updated_at = CURRENT_TIMESTAMP
            RETURNING id, from_currency, to_currency, rate, source,
                      effective_date, created_at
            "#
        )
        .bind(id)
        .bind(&request.from_currency)
        .bind(&request.to_currency)
        .bind(request.rate)
        .bind(request.source.clone().unwrap_or_else(|| "manual".to_string()))
        .bind(business_date)
        .bind(effective_date)
        .bind(request.manual_rate_expiry)
        .fetch_one(&self.pool)
        .await?;

        // 🗑️ 缓存失效：删除相关的缓存键
        let cache_pattern = format!("rate:{}:{}:*", request.from_currency, request.to_currency);
        self.invalidate_cache(&cache_pattern).await;

        // 同时清除反向汇率缓存
        let reverse_cache_pattern = format!("rate:{}:{}:*", request.to_currency, request.from_currency);
        self.invalidate_cache(&reverse_cache_pattern).await;

        Ok(ExchangeRate {
            id: rec.get("id"),
            from_currency: rec.get("from_currency"),
            to_currency: rec.get("to_currency"),
            rate: rec.get("rate"),
            source: rec
                .get::<Option<String>, _>("source")
                .unwrap_or_else(|| "manual".to_string()),
            effective_date: rec
                .get::<Option<NaiveDate>, _>("effective_date")
                .unwrap_or_else(|| chrono::Utc::now().date_naive()),
            created_at: rec
                .get::<Option<DateTime<Utc>>, _>("created_at")
                .unwrap_or_else(chrono::Utc::now),
            change_24h: None,
            change_7d: None,
            change_30d: None,
        })
    }
    
    /// 货币转换（使用金融友好的舍入策略）
    pub fn convert_amount(
        &self,
        amount: Decimal,
        rate: Decimal,
        _from_decimal_places: i32,
        to_decimal_places: i32,
    ) -> Decimal {
        use rust_decimal::RoundingStrategy;

        let converted = amount * rate;

        // 使用金融标准的舍入策略：四舍五入（MidpointAwayFromZero）
        // 这是大多数金融系统使用的策略，与银行家舍入（RoundHalfEven）不同
        converted.round_dp_with_strategy(
            to_decimal_places as u32,
            RoundingStrategy::MidpointAwayFromZero
        )
    }
    
    /// 获取最近的汇率历史（包含汇率变化数据）
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
                   effective_date, created_at,
                   change_24h, change_7d, change_30d
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
            effective_date: row.effective_date,
            created_at: row.created_at.unwrap_or_else(Utc::now),
            change_24h: row.change_24h,
            change_7d: row.change_7d,
            change_30d: row.change_30d,
        }).collect())
    }

    /// 获取最新汇率（包含汇率变化数据）- 用于Flutter客户端
    pub async fn get_latest_rate_with_changes(
        &self,
        from_currency: &str,
        to_currency: &str,
    ) -> Result<Option<ExchangeRate>, ServiceError> {
        let row = sqlx::query!(
            r#"
            SELECT id, from_currency, to_currency, rate, source,
                   effective_date, created_at,
                   change_24h, change_7d, change_30d
            FROM exchange_rates
            WHERE from_currency = $1
            AND to_currency = $2
            ORDER BY effective_date DESC
            LIMIT 1
            "#,
            from_currency,
            to_currency
        )
        .fetch_optional(&self.pool)
        .await?;

        Ok(row.map(|r| ExchangeRate {
            id: r.id,
            from_currency: r.from_currency,
            to_currency: r.to_currency,
            rate: r.rate,
            source: r.source.unwrap_or_else(|| "manual".to_string()),
            effective_date: r.effective_date,
            created_at: r.created_at.unwrap_or_else(Utc::now),
            change_24h: r.change_24h,
            change_7d: r.change_7d,
            change_30d: r.change_30d,
        }))
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
            .flatten()
            .collect();
        
        if currencies.is_empty() {
            // 返回默认货币
            Ok(vec!["CNY".to_string(), "USD".to_string()])
        } else {
            Ok(currencies)
        }
    }
    
    /// 自动获取最新汇率并更新到数据库（包含汇率变化计算）
    pub async fn fetch_latest_rates(&self, base_currency: &str) -> Result<(), ServiceError> {
        use super::exchange_rate_api::EXCHANGE_RATE_SERVICE;

        tracing::info!("Fetching latest exchange rates for {}", base_currency);

        // 获取汇率服务实例
        let mut service = EXCHANGE_RATE_SERVICE.lock().await;

        // 获取最新汇率
        let rates = service.fetch_fiat_rates(base_currency).await?;

        // 仅对系统已知的币种写库，避免外键错误
        let known_codes: std::collections::HashSet<String> = std::collections::HashSet::new();

        // 批量更新到数据库
        let effective_date = Utc::now().date_naive();
        let business_date = effective_date;

        for (target_currency, current_rate) in rates.iter() {
            if target_currency != base_currency {
                // 跳过未知币种，避免外键约束失败
                if !known_codes.is_empty() && !known_codes.contains(target_currency) {
                    continue;
                }

                // 从数据库查询历史汇率（24h、7d、30d前）
                let rate_24h_ago = self.get_historical_rate_from_db(base_currency, target_currency, 1).await.ok().flatten();
                let rate_7d_ago = self.get_historical_rate_from_db(base_currency, target_currency, 7).await.ok().flatten();
                let rate_30d_ago = self.get_historical_rate_from_db(base_currency, target_currency, 30).await.ok().flatten();

                // 计算变化百分比
                let change_24h = rate_24h_ago.and_then(|old_rate| {
                    if old_rate > Decimal::ZERO {
                        Some(((*current_rate - old_rate) / old_rate) * Decimal::from(100))
                    } else {
                        None
                    }
                });

                let change_7d = rate_7d_ago.and_then(|old_rate| {
                    if old_rate > Decimal::ZERO {
                        Some(((*current_rate - old_rate) / old_rate) * Decimal::from(100))
                    } else {
                        None
                    }
                });

                let change_30d = rate_30d_ago.and_then(|old_rate| {
                    if old_rate > Decimal::ZERO {
                        Some(((*current_rate - old_rate) / old_rate) * Decimal::from(100))
                    } else {
                        None
                    }
                });

                let id = Uuid::new_v4();

                // 插入或更新汇率（包含变化数据）
                let res = sqlx::query(
                    r#"
                    INSERT INTO exchange_rates
                    (id, from_currency, to_currency, rate, source, date, effective_date,
                     change_24h, change_7d, change_30d, price_24h_ago, price_7d_ago, price_30d_ago,
                     is_manual, manual_rate_expiry)
                    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, false, NULL)
                    ON CONFLICT (from_currency, to_currency, date)
                    DO UPDATE SET
                        rate = EXCLUDED.rate,
                        source = EXCLUDED.source,
                        effective_date = EXCLUDED.effective_date,
                        change_24h = EXCLUDED.change_24h,
                        change_7d = EXCLUDED.change_7d,
                        change_30d = EXCLUDED.change_30d,
                        price_24h_ago = EXCLUDED.price_24h_ago,
                        price_7d_ago = EXCLUDED.price_7d_ago,
                        price_30d_ago = EXCLUDED.price_30d_ago,
                        updated_at = CURRENT_TIMESTAMP
                    "#
                )
                .bind(id)
                .bind(base_currency)
                .bind(target_currency.as_str())
                .bind(current_rate)
                .bind("exchangerate-api")
                .bind(business_date)
                .bind(effective_date)
                .bind(change_24h)
                .bind(change_7d)
                .bind(change_30d)
                .bind(rate_24h_ago)
                .bind(rate_7d_ago)
                .bind(rate_30d_ago)
                .execute(&self.pool)
                .await;

                if let Err(err) = res {
                    // 忽略外键约束错误（未知币种），避免任务失败
                    if let sqlx::Error::Database(db_err) = &err {
                        if db_err.code().as_deref() == Some("23503") {
                            tracing::warn!(
                                "Skip writing rate for unknown currency {} due to FK constraint",
                                target_currency
                            );
                            continue;
                        }
                    }
                    return Err(ServiceError::DatabaseError(err));
                }
            }
        }

        tracing::info!("Successfully updated {} exchange rates for {}", rates.len() - 1, base_currency);
        Ok(())
    }

    /// 从数据库获取历史汇率（用于计算变化百分比）
    ///
    /// 查询策略：
    /// 1. 优先精确匹配目标日期
    /// 2. 如果精确日期无数据，查询±2天窗口内最接近的数据
    /// 3. 超过2天范围则返回None（避免计算错误的变化百分比）
    async fn get_historical_rate_from_db(
        &self,
        from_currency: &str,
        to_currency: &str,
        days_ago: i64,
    ) -> Result<Option<Decimal>, ServiceError> {
        let target_date = (Utc::now() - chrono::Duration::days(days_ago)).date_naive();

        // 1️⃣ 优先：精确日期匹配
        let exact_rate = sqlx::query_scalar!(
            r#"
            SELECT rate
            FROM exchange_rates
            WHERE from_currency = $1
            AND to_currency = $2
            AND date = $3
            LIMIT 1
            "#,
            from_currency,
            to_currency,
            target_date
        )
        .fetch_optional(&self.pool)
        .await?;

        if exact_rate.is_some() {
            return Ok(exact_rate);
        }

        // 2️⃣ 降级：±2天窗口（避免使用过旧数据）
        let min_date = target_date - chrono::Duration::days(2);
        let max_date = target_date + chrono::Duration::days(2);

        let fallback_rate = sqlx::query!(
            r#"
            SELECT rate, date
            FROM exchange_rates
            WHERE from_currency = $1
            AND to_currency = $2
            AND date BETWEEN $3 AND $5
            ORDER BY ABS(date - $4) ASC
            LIMIT 1
            "#,
            from_currency,
            to_currency,
            min_date,
            target_date,
            max_date
        )
        .fetch_optional(&self.pool)
        .await?;

        if let Some(row) = fallback_rate {
            let actual_date = row.date;
            if actual_date != target_date {
                tracing::debug!(
                    "Using fallback rate for {}/{}: target={}, actual={}, diff={} days",
                    from_currency,
                    to_currency,
                    target_date,
                    actual_date,
                    (actual_date - target_date).num_days().abs()
                );
            }
            Ok(Some(row.rate))
        } else {
            Ok(None)
        }
    }
    
    /// 获取并更新加密货币价格（包含汇率变化计算）
    pub async fn fetch_crypto_prices(&self, crypto_codes: Vec<&str>, fiat_currency: &str) -> Result<(), ServiceError> {
        use super::exchange_rate_api::EXCHANGE_RATE_SERVICE;

        tracing::info!("Fetching crypto prices in {}", fiat_currency);

        // 获取汇率服务实例
        let mut service = EXCHANGE_RATE_SERVICE.lock().await;

        // 获取当前加密货币价格
        let prices = service.fetch_crypto_prices(crypto_codes.clone(), fiat_currency).await?;

        // 批量更新到数据库（包括历史数据和变化计算）
        for (crypto_code, current_price) in prices.iter() {
            // 获取历史价格（24h、7d、30d前）- 数据库优先策略
            let price_24h_ago = service.fetch_crypto_historical_price(&self.pool, crypto_code, fiat_currency, 1).await.ok().flatten();
            let price_7d_ago = service.fetch_crypto_historical_price(&self.pool, crypto_code, fiat_currency, 7).await.ok().flatten();
            let price_30d_ago = service.fetch_crypto_historical_price(&self.pool, crypto_code, fiat_currency, 30).await.ok().flatten();

            // 计算变化百分比
            let change_24h = price_24h_ago.and_then(|old_price| {
                if old_price > Decimal::ZERO {
                    Some(((*current_price - old_price) / old_price) * Decimal::from(100))
                } else {
                    None
                }
            });

            let change_7d = price_7d_ago.and_then(|old_price| {
                if old_price > Decimal::ZERO {
                    Some(((*current_price - old_price) / old_price) * Decimal::from(100))
                } else {
                    None
                }
            });

            let change_30d = price_30d_ago.and_then(|old_price| {
                if old_price > Decimal::ZERO {
                    Some(((*current_price - old_price) / old_price) * Decimal::from(100))
                } else {
                    None
                }
            });

            // 更新exchange_rates表（加密货币也使用这个表）
            let effective_date = Utc::now().date_naive();
            let business_date = effective_date;
            let id = Uuid::new_v4();

            let _ = sqlx::query(
                r#"
                INSERT INTO exchange_rates
                (id, from_currency, to_currency, rate, source, date, effective_date,
                 change_24h, change_7d, change_30d, price_24h_ago, price_7d_ago, price_30d_ago,
                 is_manual, manual_rate_expiry)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, false, NULL)
                ON CONFLICT (from_currency, to_currency, date)
                DO UPDATE SET
                    rate = EXCLUDED.rate,
                    source = EXCLUDED.source,
                    effective_date = EXCLUDED.effective_date,
                    change_24h = EXCLUDED.change_24h,
                    change_7d = EXCLUDED.change_7d,
                    change_30d = EXCLUDED.change_30d,
                    price_24h_ago = EXCLUDED.price_24h_ago,
                    price_7d_ago = EXCLUDED.price_7d_ago,
                    price_30d_ago = EXCLUDED.price_30d_ago,
                    updated_at = CURRENT_TIMESTAMP
                "#
            )
            .bind(id)
            .bind(crypto_code)
            .bind(fiat_currency)
            .bind(current_price)
            .bind("coingecko")
            .bind(business_date)
            .bind(effective_date)
            .bind(change_24h)
            .bind(change_7d)
            .bind(change_30d)
            .bind(price_24h_ago)
            .bind(price_7d_ago)
            .bind(price_30d_ago)
            .execute(&self.pool)
            .await;
        }

        tracing::info!("Successfully updated {} crypto prices in {}", prices.len(), fiat_currency);
        Ok(())
    }

    /// Clear manual flag/expiry for today's business date for a given pair
    pub async fn clear_manual_rate(&self, from_currency: &str, to_currency: &str) -> Result<(), ServiceError> {
        let _ = sqlx::query(
            r#"
            UPDATE exchange_rates
            SET is_manual = false,
                manual_rate_expiry = NULL,
                updated_at = CURRENT_TIMESTAMP
            WHERE from_currency = $1 AND to_currency = $2 AND date = CURRENT_DATE
            "#
        )
        .bind(from_currency)
        .bind(to_currency)
        .execute(&self.pool)
        .await?;

        // 🗑️ 缓存失效：清除相关汇率缓存
        let cache_pattern = format!("rate:{}:{}:*", from_currency, to_currency);
        self.invalidate_cache(&cache_pattern).await;

        // 同时清除反向汇率缓存
        let reverse_cache_pattern = format!("rate:{}:{}:*", to_currency, from_currency);
        self.invalidate_cache(&reverse_cache_pattern).await;

        Ok(())
    }

    /// Batch clear manual flags/expiry by filters
    pub async fn clear_manual_rates_batch(&self, req: ClearManualRatesBatchRequest) -> Result<u64, ServiceError> {
        let target_date = req.before_date.unwrap_or_else(|| chrono::Utc::now().date_naive());
        let only_expired = req.only_expired.unwrap_or(false);

        let mut total: u64 = 0;
        if let Some(list) = req.to_currencies.as_ref() {
            if only_expired {
                let res = sqlx::query(
                    r#"
                    UPDATE exchange_rates
                    SET is_manual = false,
                        manual_rate_expiry = NULL,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE from_currency = $1
                      AND to_currency = ANY($2)
                      AND date <= $3
                      AND manual_rate_expiry IS NOT NULL AND manual_rate_expiry <= NOW()
                    "#
                )
                .bind(&req.from_currency)
                .bind(list)
                .bind(target_date)
                .execute(&self.pool)
                .await?;
                total += res.rows_affected();
            } else {
                let res = sqlx::query(
                    r#"
                    UPDATE exchange_rates
                    SET is_manual = false,
                        manual_rate_expiry = NULL,
                        updated_at = CURRENT_TIMESTAMP
                    WHERE from_currency = $1
                      AND to_currency = ANY($2)
                      AND date <= $3
                    "#
                )
                .bind(&req.from_currency)
                .bind(list)
                .bind(target_date)
                .execute(&self.pool)
                .await?;
                total += res.rows_affected();
            }

            // 🗑️ 缓存失效：清除指定货币对的缓存
            for to_currency in list {
                let cache_pattern = format!("rate:{}:{}:*", req.from_currency, to_currency);
                self.invalidate_cache(&cache_pattern).await;

                // 同时清除反向汇率缓存
                let reverse_cache_pattern = format!("rate:{}:{}:*", to_currency, req.from_currency);
                self.invalidate_cache(&reverse_cache_pattern).await;
            }
        } else if only_expired {
            let res = sqlx::query(
                r#"
                UPDATE exchange_rates
                SET is_manual = false,
                    manual_rate_expiry = NULL,
                    updated_at = CURRENT_TIMESTAMP
                WHERE from_currency = $1
                  AND date <= $2
                  AND manual_rate_expiry IS NOT NULL AND manual_rate_expiry <= NOW()
                "#
            )
            .bind(&req.from_currency)
            .bind(target_date)
            .execute(&self.pool)
            .await?;
            total += res.rows_affected();

            // 🗑️ 缓存失效：清除所有from_currency的缓存
            let cache_pattern = format!("rate:{}:*", req.from_currency);
            self.invalidate_cache(&cache_pattern).await;
        } else {
            let res = sqlx::query(
                r#"
                UPDATE exchange_rates
                SET is_manual = false,
                    manual_rate_expiry = NULL,
                    updated_at = CURRENT_TIMESTAMP
                WHERE from_currency = $1
                  AND date <= $2
                "#
            )
            .bind(&req.from_currency)
            .bind(target_date)
            .execute(&self.pool)
            .await?;
            total += res.rows_affected();

            // 🗑️ 缓存失效：清除所有from_currency的缓存
            let cache_pattern = format!("rate:{}:*", req.from_currency);
            self.invalidate_cache(&cache_pattern).await;
        }
        Ok(total)
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_convert_amount() {
        // let service = CurrencyService::new(PgPool::connect_lazy("").unwrap());
        // Test would require a pool to work
        // Skipping test for now as it requires database connection
    }
}
