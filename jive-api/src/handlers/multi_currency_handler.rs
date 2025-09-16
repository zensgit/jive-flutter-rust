use actix_web::{web, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use chrono::{DateTime, Utc, Duration};
use rust_decimal::Decimal;
use std::collections::HashMap;

use crate::error::ApiError;
use crate::models::{ApiResponse, User};
use crate::services::exchange_rate_api::EXCHANGE_RATE_SERVICE;

// ============================================
// 数据模型
// ============================================

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct Currency {
    pub code: String,
    pub name: String,
    pub name_zh: String,
    pub symbol: String,
    pub decimal_places: i32,
    pub is_crypto: bool,
    pub is_active: bool,
    pub flag: Option<String>,
    pub country_code: Option<String>,
    pub is_popular: bool,
    pub display_order: i32,
    pub min_amount: Decimal,
    pub max_amount: Decimal,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct UserCurrencySettings {
    pub user_id: i32,
    pub base_currency: String,
    pub multi_currency_enabled: bool,
    pub crypto_enabled: bool,
    pub show_currency_symbol: bool,
    pub show_currency_code: bool,
    pub auto_update_rates: bool,
    pub rate_update_frequency: i32,
    pub crypto_update_frequency: i32,
    pub selected_currencies: Vec<String>,
    pub last_updated: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct ExchangeRate {
    pub id: i32,
    pub base_currency: String,
    pub target_currency: String,
    pub rate: Decimal,
    pub is_manual: bool,
    pub manual_rate_expiry: Option<DateTime<Utc>>,
    pub source: String,
    pub confidence_level: Decimal,
    pub last_updated: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize, sqlx::FromRow)]
pub struct CryptoPrice {
    pub crypto_code: String,
    pub base_currency: String,
    pub price: Decimal,
    pub price_24h_ago: Option<Decimal>,
    pub change_24h: Option<Decimal>,
    pub change_7d: Option<Decimal>,
    pub change_30d: Option<Decimal>,
    pub volume_24h: Option<Decimal>,
    pub market_cap: Option<Decimal>,
    pub is_manual: bool,
    pub manual_price_expiry: Option<DateTime<Utc>>,
    pub last_updated: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateCurrencySettingsRequest {
    pub base_currency: Option<String>,
    pub multi_currency_enabled: Option<bool>,
    pub crypto_enabled: Option<bool>,
    pub show_currency_symbol: Option<bool>,
    pub show_currency_code: Option<bool>,
    pub auto_update_rates: Option<bool>,
    pub selected_currencies: Option<Vec<String>>,
}

#[derive(Debug, Deserialize)]
pub struct SetManualRateRequest {
    pub target_currency: String,
    pub rate: Decimal,
    pub expiry_days: Option<i64>, // 有效期天数，默认1天
}

#[derive(Debug, Deserialize)]
pub struct ConvertCurrencyRequest {
    pub from_currency: String,
    pub to_currency: String,
    pub amount: Decimal,
}

#[derive(Debug, Serialize)]
pub struct ConvertCurrencyResponse {
    pub from_currency: String,
    pub to_currency: String,
    pub amount: Decimal,
    pub converted_amount: Decimal,
    pub exchange_rate: Decimal,
    pub rate_source: String,
    pub timestamp: DateTime<Utc>,
}

// ============================================
// API处理函数
// ============================================

/// 获取所有可用货币
pub async fn get_all_currencies(
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let currencies = sqlx::query_as::<_, Currency>(
        r#"
        SELECT code, name, name_zh, symbol, decimal_places, is_crypto, is_active,
               flag, country_code, is_popular, display_order, min_amount, max_amount
        FROM currencies
        WHERE is_active = true
        ORDER BY display_order, code
        "#
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(ApiResponse::success(currencies)))
}

/// 获取用户货币设置
pub async fn get_user_currency_settings(
    pool: web::Data<PgPool>,
    user: User,
) -> Result<HttpResponse, ApiError> {
    let settings = sqlx::query_as::<_, UserCurrencySettings>(
        r#"
        SELECT ucs.*, 
               COALESCE(
                   (SELECT array_agg(currency_code) 
                    FROM user_selected_currencies 
                    WHERE user_id = $1),
                   ARRAY[]::VARCHAR[]
               ) as selected_currencies
        FROM user_currency_settings ucs
        WHERE ucs.user_id = $1
        "#
    )
    .bind(user.id)
    .fetch_optional(pool.get_ref())
    .await?;

    match settings {
        Some(s) => Ok(HttpResponse::Ok().json(ApiResponse::success(s))),
        None => {
            // 创建默认设置
            let default_settings = create_default_settings(pool.get_ref(), user.id).await?;
            Ok(HttpResponse::Ok().json(ApiResponse::success(default_settings)))
        }
    }
}

/// 更新用户货币设置
pub async fn update_user_currency_settings(
    pool: web::Data<PgPool>,
    user: User,
    req: web::Json<UpdateCurrencySettingsRequest>,
) -> Result<HttpResponse, ApiError> {
    let mut tx = pool.begin().await?;

    // 更新基础设置
    if let Some(base_currency) = &req.base_currency {
        sqlx::query(
            "UPDATE user_currency_settings SET base_currency = $1 WHERE user_id = $2"
        )
        .bind(base_currency)
        .bind(user.id)
        .execute(&mut tx)
        .await?;
    }

    if let Some(multi_currency) = req.multi_currency_enabled {
        sqlx::query(
            "UPDATE user_currency_settings SET multi_currency_enabled = $1 WHERE user_id = $2"
        )
        .bind(multi_currency)
        .bind(user.id)
        .execute(&mut tx)
        .await?;
    }

    if let Some(crypto) = req.crypto_enabled {
        // 检查用户所在地区是否允许加密货币
        if crypto && !is_crypto_allowed(&user.country_code).await {
            return Err(ApiError::BadRequest("Cryptocurrency not allowed in your region".to_string()));
        }
        
        sqlx::query(
            "UPDATE user_currency_settings SET crypto_enabled = $1 WHERE user_id = $2"
        )
        .bind(crypto)
        .bind(user.id)
        .execute(&mut tx)
        .await?;
    }

    if let Some(show_symbol) = req.show_currency_symbol {
        sqlx::query(
            "UPDATE user_currency_settings SET show_currency_symbol = $1 WHERE user_id = $2"
        )
        .bind(show_symbol)
        .bind(user.id)
        .execute(&mut tx)
        .await?;
    }

    if let Some(show_code) = req.show_currency_code {
        sqlx::query(
            "UPDATE user_currency_settings SET show_currency_code = $1 WHERE user_id = $2"
        )
        .bind(show_code)
        .bind(user.id)
        .execute(&mut tx)
        .await?;
    }

    // 更新选择的货币
    if let Some(currencies) = &req.selected_currencies {
        // 删除旧的选择
        sqlx::query("DELETE FROM user_selected_currencies WHERE user_id = $1")
            .bind(user.id)
            .execute(&mut tx)
            .await?;

        // 插入新的选择
        for (idx, currency) in currencies.iter().enumerate() {
            sqlx::query(
                r#"
                INSERT INTO user_selected_currencies 
                (user_id, currency_code, display_order, added_at)
                VALUES ($1, $2, $3, $4)
                "#
            )
            .bind(user.id)
            .bind(currency)
            .bind(idx as i32)
            .bind(Utc::now())
            .execute(&mut tx)
            .await?;
        }
    }

    tx.commit().await?;

    // 返回更新后的设置
    get_user_currency_settings(pool, user).await
}

/// 获取实时汇率
pub async fn get_exchange_rates(
    pool: web::Data<PgPool>,
    user: User,
) -> Result<HttpResponse, ApiError> {
    // 获取用户的基础货币
    let base_currency = get_user_base_currency(pool.get_ref(), user.id).await?;
    
    // 获取所有汇率（优先手动设置的，且在有效期内的）
    let rates = sqlx::query_as::<_, ExchangeRate>(
        r#"
        SELECT * FROM exchange_rates
        WHERE base_currency = $1
          AND (is_manual = false 
               OR (is_manual = true AND manual_rate_expiry > CURRENT_TIMESTAMP))
        ORDER BY target_currency, is_manual DESC, last_updated DESC
        "#
    )
    .bind(&base_currency)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(ApiResponse::success(rates)))
}

/// 设置手动汇率
pub async fn set_manual_exchange_rate(
    pool: web::Data<PgPool>,
    user: User,
    req: web::Json<SetManualRateRequest>,
) -> Result<HttpResponse, ApiError> {
    let base_currency = get_user_base_currency(pool.get_ref(), user.id).await?;
    let expiry_days = req.expiry_days.unwrap_or(1);
    let expiry = Utc::now() + Duration::days(expiry_days);

    // 插入或更新手动汇率
    sqlx::query(
        r#"
        INSERT INTO exchange_rates 
        (base_currency, target_currency, rate, is_manual, manual_rate_expiry, source, last_updated)
        VALUES ($1, $2, $3, true, $4, 'manual', CURRENT_TIMESTAMP)
        ON CONFLICT (base_currency, target_currency) 
        DO UPDATE SET 
            rate = $3,
            is_manual = true,
            manual_rate_expiry = $4,
            source = 'manual',
            last_updated = CURRENT_TIMESTAMP
        "#
    )
    .bind(&base_currency)
    .bind(&req.target_currency)
    .bind(&req.rate)
    .bind(&expiry)
    .execute(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(ApiResponse::success(
        serde_json::json!({
            "message": "Manual exchange rate set successfully",
            "expiry": expiry
        })
    )))
}

/// 获取并更新加密货币价格到数据库
async fn update_crypto_prices_in_db(
    pool: &PgPool,
    crypto_codes: Vec<&str>,
    base_currency: &str,
) -> Result<(), ApiError> {
    use crate::services::exchange_rate_api::EXCHANGE_RATE_SERVICE;
    
    let mut service = EXCHANGE_RATE_SERVICE.lock().await;
    let prices = service.fetch_crypto_prices(crypto_codes, base_currency).await?;
    
    for (crypto_code, price) in prices {
        sqlx::query!(
            r#"
            INSERT INTO crypto_prices 
            (crypto_code, base_currency, price, source, last_updated)
            VALUES ($1, $2, $3, 'api', CURRENT_TIMESTAMP)
            ON CONFLICT (crypto_code, base_currency)
            DO UPDATE SET 
                price = $3,
                source = 'api',
                last_updated = CURRENT_TIMESTAMP
            "#,
            crypto_code,
            base_currency,
            price
        )
        .execute(pool)
        .await?;
    }
    
    Ok(())
}

// 获取加密货币价格
pub async fn get_crypto_prices(
    pool: web::Data<PgPool>,
    user: User,
) -> Result<HttpResponse, ApiError> {
    // 检查用户是否启用了加密货币
    let crypto_enabled = sqlx::query_scalar::<_, bool>(
        "SELECT crypto_enabled FROM user_currency_settings WHERE user_id = $1"
    )
    .bind(user.id)
    .fetch_optional(pool.get_ref())
    .await?
    .unwrap_or(false);

    if !crypto_enabled {
        return Err(ApiError::BadRequest("Cryptocurrency not enabled".to_string()));
    }

    let base_currency = get_user_base_currency(pool.get_ref(), user.id).await?;
    
    // 尝试更新加密货币价格（如果数据过期）
    let should_update = sqlx::query_scalar::<_, bool>(
        r#"
        SELECT COUNT(*) = 0 OR MAX(last_updated) < CURRENT_TIMESTAMP - INTERVAL '5 minutes'
        FROM crypto_prices
        WHERE base_currency = $1
        "#
    )
    .bind(&base_currency)
    .fetch_one(pool.get_ref())
    .await?;
    
    if should_update {
        // 更新加密货币价格
        let crypto_codes = vec!["BTC", "ETH", "USDT", "BNB", "SOL", "XRP", "USDC", "ADA", 
                              "AVAX", "DOGE", "DOT", "MATIC", "LINK", "LTC", "UNI", "ATOM"];
        if let Err(e) = update_crypto_prices_in_db(pool.get_ref(), crypto_codes, &base_currency).await {
            tracing::warn!("Failed to update crypto prices: {:?}", e);
        }
    }
    
    let prices = sqlx::query_as::<_, CryptoPrice>(
        r#"
        SELECT * FROM crypto_prices
        WHERE base_currency = $1
          AND (is_manual = false 
               OR (is_manual = true AND manual_price_expiry > CURRENT_TIMESTAMP))
        ORDER BY crypto_code
        "#
    )
    .bind(&base_currency)
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(ApiResponse::success(prices)))
}

/// 货币转换
pub async fn convert_currency(
    pool: web::Data<PgPool>,
    user: User,
    req: web::Json<ConvertCurrencyRequest>,
) -> Result<HttpResponse, ApiError> {
    let base_currency = get_user_base_currency(pool.get_ref(), user.id).await?;
    
    // 获取汇率
    let rate = get_conversion_rate(
        pool.get_ref(),
        &req.from_currency,
        &req.to_currency,
        &base_currency,
    ).await?;
    
    let converted_amount = req.amount * rate;
    
    // 记录转换历史
    sqlx::query(
        r#"
        INSERT INTO exchange_conversion_history 
        (user_id, from_currency, to_currency, amount, converted_amount, exchange_rate)
        VALUES ($1, $2, $3, $4, $5, $6)
        "#
    )
    .bind(user.id)
    .bind(&req.from_currency)
    .bind(&req.to_currency)
    .bind(&req.amount)
    .bind(&converted_amount)
    .bind(&rate)
    .execute(pool.get_ref())
    .await?;

    // 更新使用统计
    update_currency_usage_stats(
        pool.get_ref(),
        user.id,
        &req.from_currency,
        &req.to_currency,
    ).await?;

    Ok(HttpResponse::Ok().json(ApiResponse::success(ConvertCurrencyResponse {
        from_currency: req.from_currency.clone(),
        to_currency: req.to_currency.clone(),
        amount: req.amount,
        converted_amount,
        exchange_rate: rate,
        rate_source: "system".to_string(),
        timestamp: Utc::now(),
    })))
}

/// 获取转换历史
pub async fn get_conversion_history(
    pool: web::Data<PgPool>,
    user: User,
) -> Result<HttpResponse, ApiError> {
    let history = sqlx::query!(
        r#"
        SELECT from_currency, to_currency, amount, converted_amount, 
               exchange_rate, conversion_date
        FROM exchange_conversion_history
        WHERE user_id = $1
        ORDER BY conversion_date DESC
        LIMIT 50
        "#,
        user.id
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(ApiResponse::success(history)))
}

/// 获取热门货币对
pub async fn get_popular_pairs(
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    let pairs = sqlx::query!(
        r#"
        SELECT from_currency, to_currency, COUNT(*) as usage_count
        FROM exchange_conversion_history
        WHERE conversion_date > CURRENT_TIMESTAMP - INTERVAL '30 days'
        GROUP BY from_currency, to_currency
        ORDER BY usage_count DESC
        LIMIT 20
        "#
    )
    .fetch_all(pool.get_ref())
    .await?;

    Ok(HttpResponse::Ok().json(ApiResponse::success(pairs)))
}

/// 批量更新汇率（系统定时任务调用）
pub async fn batch_update_exchange_rates(
    pool: web::Data<PgPool>,
) -> Result<HttpResponse, ApiError> {
    // 这里应该调用外部API获取最新汇率
    // 示例：从 exchangerate-api.com 或其他提供商获取
    
    let rates = fetch_latest_rates_from_provider().await?;
    
    let mut tx = pool.begin().await?;
    
    for (currency_pair, rate) in rates {
        sqlx::query(
            r#"
            INSERT INTO exchange_rates 
            (base_currency, target_currency, rate, is_manual, source, last_updated)
            VALUES ($1, $2, $3, false, 'api', CURRENT_TIMESTAMP)
            ON CONFLICT (base_currency, target_currency) 
            DO UPDATE SET 
                rate = $3,
                source = 'api',
                last_updated = CURRENT_TIMESTAMP
            WHERE exchange_rates.is_manual = false
            "#
        )
        .bind(&currency_pair.0)
        .bind(&currency_pair.1)
        .bind(rate)
        .execute(&mut tx)
        .await?;
    }
    
    tx.commit().await?;

    Ok(HttpResponse::Ok().json(ApiResponse::success(
        serde_json::json!({
            "message": "Exchange rates updated successfully",
            "count": rates.len()
        })
    )))
}

// ============================================
// 辅助函数
// ============================================

async fn create_default_settings(
    pool: &PgPool,
    user_id: i32,
) -> Result<UserCurrencySettings, ApiError> {
    let settings = UserCurrencySettings {
        user_id,
        base_currency: "USD".to_string(),
        multi_currency_enabled: false,
        crypto_enabled: false,
        show_currency_symbol: true,
        show_currency_code: true,
        auto_update_rates: true,
        rate_update_frequency: 15,
        crypto_update_frequency: 5,
        selected_currencies: vec!["USD".to_string()],
        last_updated: Utc::now(),
    };

    sqlx::query(
        r#"
        INSERT INTO user_currency_settings 
        (user_id, base_currency, multi_currency_enabled, crypto_enabled,
         show_currency_symbol, show_currency_code, auto_update_rates,
         rate_update_frequency, crypto_update_frequency)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (user_id) DO NOTHING
        "#
    )
    .bind(&settings.user_id)
    .bind(&settings.base_currency)
    .bind(&settings.multi_currency_enabled)
    .bind(&settings.crypto_enabled)
    .bind(&settings.show_currency_symbol)
    .bind(&settings.show_currency_code)
    .bind(&settings.auto_update_rates)
    .bind(&settings.rate_update_frequency)
    .bind(&settings.crypto_update_frequency)
    .execute(pool)
    .await?;

    Ok(settings)
}

async fn get_user_base_currency(pool: &PgPool, user_id: i32) -> Result<String, ApiError> {
    sqlx::query_scalar::<_, String>(
        "SELECT base_currency FROM user_currency_settings WHERE user_id = $1"
    )
    .bind(user_id)
    .fetch_optional(pool)
    .await?
    .ok_or_else(|| ApiError::NotFound("User currency settings not found".to_string()))
}

async fn is_crypto_allowed(country_code: &Option<String>) -> bool {
    if let Some(code) = country_code {
        // 限制的国家列表
        let restricted = vec!["KP", "IR", "CU", "SY", "SD"];
        !restricted.contains(&code.as_str())
    } else {
        true
    }
}

async fn get_conversion_rate(
    pool: &PgPool,
    from: &str,
    to: &str,
    base: &str,
) -> Result<Decimal, ApiError> {
    // 如果是相同货币，返回1
    if from == to {
        return Ok(Decimal::from(1));
    }

    // 获取from到base的汇率
    let from_to_base = if from == base {
        Decimal::from(1)
    } else {
        sqlx::query_scalar::<_, Decimal>(
            r#"
            SELECT rate FROM exchange_rates 
            WHERE base_currency = $1 AND target_currency = $2
            ORDER BY is_manual DESC, last_updated DESC
            LIMIT 1
            "#
        )
        .bind(base)
        .bind(from)
        .fetch_optional(pool)
        .await?
        .unwrap_or(Decimal::from(1))
    };

    // 获取base到to的汇率
    let base_to_to = if to == base {
        Decimal::from(1)
    } else {
        sqlx::query_scalar::<_, Decimal>(
            r#"
            SELECT rate FROM exchange_rates 
            WHERE base_currency = $1 AND target_currency = $2
            ORDER BY is_manual DESC, last_updated DESC
            LIMIT 1
            "#
        )
        .bind(base)
        .bind(to)
        .fetch_optional(pool)
        .await?
        .unwrap_or(Decimal::from(1))
    };

    // 计算最终汇率
    Ok(base_to_to / from_to_base)
}

async fn update_currency_usage_stats(
    pool: &PgPool,
    user_id: i32,
    from: &str,
    to: &str,
) -> Result<(), ApiError> {
    for currency in [from, to] {
        sqlx::query(
            r#"
            INSERT INTO currency_usage_stats (user_id, currency_code, usage_count, last_used)
            VALUES ($1, $2, 1, CURRENT_TIMESTAMP)
            ON CONFLICT (user_id, currency_code) 
            DO UPDATE SET 
                usage_count = currency_usage_stats.usage_count + 1,
                last_used = CURRENT_TIMESTAMP
            "#
        )
        .bind(user_id)
        .bind(currency)
        .execute(pool)
        .await?;
    }
    
    Ok(())
}

async fn fetch_latest_rates_from_provider() -> Result<HashMap<(String, String), Decimal>, ApiError> {
    // 使用真实的汇率API服务
    let mut service = EXCHANGE_RATE_SERVICE.lock().await;
    
    let mut all_rates = HashMap::new();
    
    // 获取主要货币的汇率
    let base_currencies = vec!["USD", "EUR", "CNY", "GBP", "JPY"];
    
    for base in base_currencies {
        match service.fetch_fiat_rates(base).await {
            Ok(rates) => {
                for (target, rate) in rates {
                    if target != base {
                        all_rates.insert((base.to_string(), target.clone()), rate);
                    }
                }
            }
            Err(e) => {
                tracing::warn!("Failed to fetch rates for {}: {:?}", base, e);
            }
        }
    }
    
    Ok(all_rates)
}

// ============================================
// 路由配置
// ============================================

pub fn configure_routes(cfg: &mut web::ServiceConfig) {
    cfg.service(
        web::scope("/currency")
            .route("/all", web::get().to(get_all_currencies))
            .route("/settings", web::get().to(get_user_currency_settings))
            .route("/settings", web::put().to(update_user_currency_settings))
            .route("/rates", web::get().to(get_exchange_rates))
            .route("/rates/manual", web::post().to(set_manual_exchange_rate))
            .route("/crypto/prices", web::get().to(get_crypto_prices))
            .route("/convert", web::post().to(convert_currency))
            .route("/history", web::get().to(get_conversion_history))
            .route("/popular-pairs", web::get().to(get_popular_pairs))
            .route("/rates/batch-update", web::post().to(batch_update_exchange_rates))
    );
}