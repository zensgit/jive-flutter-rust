use axum::{
    extract::{Query, State},
    response::Json,
};
use chrono::Utc;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use serde::de::{self, Deserializer, SeqAccess, Visitor};
use sqlx::PgPool;
use std::collections::HashMap;

use crate::auth::Claims;
use crate::error::{ApiError, ApiResult};
use crate::services::{CurrencyService};
use crate::services::exchange_rate_api::ExchangeRateApiService;
use crate::services::currency_service::{CurrencyPreference};
use super::family_handler::ApiResponse;

/// Enhanced Currency model with all fields needed by Flutter
#[derive(Debug, Serialize, Deserialize, Clone)]
pub struct Currency {
    pub code: String,
    pub name: String,
    pub name_zh: Option<String>,
    pub symbol: String,
    pub decimal_places: i32,
    pub is_enabled: bool,
    pub is_crypto: bool,
    pub flag: Option<String>,
    pub exchange_rate: Option<Decimal>, // Rate to base currency
}

/// User currency preferences with enhanced fields
#[derive(Debug, Serialize, Deserialize)]
pub struct UserCurrencySettings {
    pub multi_currency_enabled: bool,
    pub crypto_enabled: bool,
    pub base_currency: String,
    pub selected_currencies: Vec<String>,
    pub show_currency_code: bool,
    pub show_currency_symbol: bool,
    pub preferences: Vec<CurrencyPreference>,
}

/// Get all currencies with enhanced information
pub async fn get_all_currencies(
    State(pool): State<PgPool>,
) -> ApiResult<Json<ApiResponse<CurrenciesResponse>>> {
    // Get all currencies from database with enriched fields
    let rows = sqlx::query!(
        r#"
        SELECT 
            code, 
            name, 
            name_zh,
            COALESCE(symbol, '') AS symbol,
            decimal_places, 
            is_active,
            is_crypto,
            flag
        FROM currencies
        WHERE is_active = true
        ORDER BY 
            is_crypto ASC,  -- Fiat first, then crypto
            code ASC
        "#
    )
    .fetch_all(&pool)
    .await
    .map_err(|_| ApiError::InternalServerError)?;
    
    let mut fiat_currencies = Vec::new();
    let mut crypto_currencies = Vec::new();
    
    for row in rows {
        let currency = Currency {
            code: row.code.clone(),
            name: row.name,
            name_zh: row.name_zh,
            // row.symbol 已被编译期推断为非 Option；直接使用
            symbol: row.symbol.unwrap_or_default(),
            decimal_places: row.decimal_places.unwrap_or(2),
            is_enabled: row.is_active.unwrap_or(true),
            is_crypto: row.is_crypto.unwrap_or(false),
            flag: row.flag,
            exchange_rate: None, // Will be populated separately if needed
        };
        
        if currency.is_crypto {
            crypto_currencies.push(currency);
        } else {
            fiat_currencies.push(currency);
        }
    }
    
    Ok(Json(ApiResponse::success(CurrenciesResponse {
        fiat_currencies,
        crypto_currencies,
    })))
}

#[derive(Debug, Serialize)]
pub struct CurrenciesResponse {
    pub fiat_currencies: Vec<Currency>,
    pub crypto_currencies: Vec<Currency>,
}

/// Get user's currency settings
pub async fn get_user_currency_settings(
    State(pool): State<PgPool>,
    claims: Claims,
) -> ApiResult<Json<ApiResponse<UserCurrencySettings>>> {
    let user_id = claims.user_id()?;
    
    // Get user preferences
    let service = CurrencyService::new(pool.clone());
    let preferences = service.get_user_currency_preferences(user_id).await
        .map_err(|_| ApiError::InternalServerError)?;
    
    // Get user settings from database or use defaults
    let settings = sqlx::query!(
        r#"
        SELECT 
            multi_currency_enabled,
            crypto_enabled,
            base_currency,
            selected_currencies,
            show_currency_code,
            show_currency_symbol
        FROM user_currency_settings
        WHERE user_id = $1
        "#,
        user_id
    )
    .fetch_optional(&pool)
    .await
    .map_err(|_| ApiError::InternalServerError)?;
    
    let settings = if let Some(settings) = settings {
        UserCurrencySettings {
            multi_currency_enabled: settings.multi_currency_enabled.unwrap_or(false),
            crypto_enabled: settings.crypto_enabled.unwrap_or(false),
            base_currency: settings.base_currency.unwrap_or_else(|| "USD".to_string()),
            selected_currencies: settings.selected_currencies.unwrap_or_else(|| vec!["USD".to_string(), "CNY".to_string()]),
            show_currency_code: settings.show_currency_code.unwrap_or(true),
            show_currency_symbol: settings.show_currency_symbol.unwrap_or(false),
            preferences,
        }
    } else {
        // Default settings
        UserCurrencySettings {
            multi_currency_enabled: false,
            crypto_enabled: false,
            base_currency: "USD".to_string(),
            selected_currencies: vec!["USD".to_string(), "CNY".to_string(), "EUR".to_string()],
            show_currency_code: true,
            show_currency_symbol: false,
            preferences,
        }
    };
    
    Ok(Json(ApiResponse::success(settings)))
}

#[derive(Debug, Deserialize)]
pub struct UpdateUserCurrencySettingsRequest {
    pub multi_currency_enabled: Option<bool>,
    pub crypto_enabled: Option<bool>,
    pub base_currency: Option<String>,
    pub selected_currencies: Option<Vec<String>>,
    pub show_currency_code: Option<bool>,
    pub show_currency_symbol: Option<bool>,
}

/// Update user's currency settings
pub async fn update_user_currency_settings(
    State(pool): State<PgPool>,
    claims: Claims,
    Json(req): Json<UpdateUserCurrencySettingsRequest>,
) -> ApiResult<Json<ApiResponse<UserCurrencySettings>>> {
    let user_id = claims.user_id()?;
    
    // Upsert user settings
    sqlx::query!(
        r#"
        INSERT INTO user_currency_settings (
            user_id,
            multi_currency_enabled,
            crypto_enabled,
            base_currency,
            selected_currencies,
            show_currency_code,
            show_currency_symbol
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
        ON CONFLICT (user_id) DO UPDATE SET
            multi_currency_enabled = COALESCE($2, user_currency_settings.multi_currency_enabled),
            crypto_enabled = COALESCE($3, user_currency_settings.crypto_enabled),
            base_currency = COALESCE($4, user_currency_settings.base_currency),
            selected_currencies = COALESCE($5, user_currency_settings.selected_currencies),
            show_currency_code = COALESCE($6, user_currency_settings.show_currency_code),
            show_currency_symbol = COALESCE($7, user_currency_settings.show_currency_symbol),
            updated_at = CURRENT_TIMESTAMP
        "#,
        user_id,
        req.multi_currency_enabled,
        req.crypto_enabled,
        req.base_currency.as_deref(),
        req.selected_currencies.as_deref(),
        req.show_currency_code,
        req.show_currency_symbol
    )
    .execute(&pool)
    .await
    .map_err(|_| ApiError::InternalServerError)?;
    
    // Return updated settings
    get_user_currency_settings(State(pool), claims).await
}

/// Get real-time exchange rates (with caching)
pub async fn get_realtime_exchange_rates(
    State(pool): State<PgPool>,
    Query(query): Query<RealtimeRatesQuery>,
) -> ApiResult<Json<ApiResponse<RealtimeRatesResponse>>> {
    let base_currency = query.base_currency.unwrap_or_else(|| "USD".to_string());
    
    // Check if we have recent rates (within 15 minutes)
    let recent_rates = sqlx::query!(
        r#"
        SELECT 
            to_currency,
            rate,
            created_at
        FROM exchange_rates
        WHERE from_currency = $1
        AND created_at > NOW() - INTERVAL '15 minutes'
        ORDER BY created_at DESC
        "#,
        base_currency
    )
    .fetch_all(&pool)
    .await
    .map_err(|_| ApiError::InternalServerError)?;
    
    let mut rates = HashMap::new();
    let mut last_updated: Option<chrono::NaiveDateTime> = None;
    
    for row in recent_rates {
        rates.insert(row.to_currency, row.rate);
        let created_naive = row.created_at.naive_utc();
        if last_updated.map(|lu| created_naive > lu).unwrap_or(true) {
            last_updated = Some(created_naive);
        }
    }
    
    // If no recent rates or not enough currencies, fetch from external API
    if rates.is_empty() || (query.force_refresh.unwrap_or(false)) {
        // TODO: Implement external API integration
        // For now, return cached rates or defaults
        if rates.is_empty() {
            rates = get_default_rates(&base_currency);
            last_updated = Some(Utc::now().naive_utc());
        }
    }
    
    Ok(Json(ApiResponse::success(RealtimeRatesResponse {
        base_currency,
        rates,
        last_updated,
        cache_duration_minutes: 15,
    })))
}

#[derive(Debug, Deserialize)]
pub struct RealtimeRatesQuery {
    pub base_currency: Option<String>,
    pub force_refresh: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct RealtimeRatesResponse {
    pub base_currency: String,
    pub rates: HashMap<String, Decimal>,
    pub last_updated: Option<chrono::NaiveDateTime>,
    pub cache_duration_minutes: i32,
}

#[derive(Debug, Deserialize)]
pub struct DetailedRatesRequest {
    pub base_currency: String,
    pub target_currencies: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct DetailedRateItem {
    pub rate: Decimal,
    pub source: String,
}

#[derive(Debug, Serialize)]
pub struct DetailedRatesResponse {
    pub base_currency: String,
    pub rates: HashMap<String, DetailedRateItem>,
}

/// Get detailed batch rates (supports fiat and crypto) with source label
pub async fn get_detailed_batch_rates(
    State(pool): State<PgPool>,
    Json(req): Json<DetailedRatesRequest>,
) -> ApiResult<Json<ApiResponse<DetailedRatesResponse>>> {
    let mut api = ExchangeRateApiService::new();
    let base = req.base_currency.to_uppercase();
    let targets: Vec<String> = req.target_currencies
        .into_iter()
        .map(|s| s.to_uppercase())
        .filter(|c| c != &base)
        .collect();

    // Determine crypto vs fiat for base and targets
    let base_is_crypto = is_crypto_currency(&pool, &base).await?;
    let mut result: HashMap<String, DetailedRateItem> = HashMap::new();

    // Helper closures
    let mut fiat_rates: Option<(HashMap<String, Decimal>, String)> = None;
    // Keep per-currency provider label for fiat targets
    let mut fiat_source_map: HashMap<String, String> = HashMap::new();
    let mut crypto_prices_cache: Option<(HashMap<String, Decimal>, String)> = None; // code -> price in USD

    // Fetch fiat rates for base if needed
    if !base_is_crypto {
        // Merge per-target from providers in priority order, so missing ones are filled by next providers
        let order_env = std::env::var("FIAT_PROVIDER_ORDER").unwrap_or_else(|_| "exchangerate-api,frankfurter,fxrates".to_string());
        let providers: Vec<String> = order_env
            .split(',')
            .map(|s| s.trim().to_lowercase())
            .filter(|s| !s.is_empty())
            .collect();

        // Accumulator for merged rates and a map to track source per currency
        let mut merged: std::collections::HashMap<String, rust_decimal::Decimal> = std::collections::HashMap::new();
        // Source map lives outside for later access

        // Determine which targets are fiat (we only need fiat->fiat rates here)
        let mut fiat_targets: Vec<String> = Vec::new();
        for t in targets.iter() {
            if !is_crypto_currency(&pool, t).await.unwrap_or(false) {
                fiat_targets.push(t.clone());
            }
        }

        for p in providers {
            if fiat_targets.is_empty() { break; }
            if let Ok((rmap, src)) = api.fetch_fiat_rates_from(&p, &base).await {
                for t in fiat_targets.clone() { // iterate over a snapshot to allow removal
                    if let Some(val) = rmap.get(&t) {
                        // fill only if not already present
                        if !merged.contains_key(&t) {
                            merged.insert(t.clone(), *val);
                            fiat_source_map.insert(t.clone(), src.clone());
                        }
                    }
                }
                // remove filled ones from pending list
                fiat_targets.retain(|code| !merged.contains_key(code));
            }
        }

        // If still missing, fallback to combined/default method (may be cached/default)
        if !fiat_targets.is_empty() {
            if let Ok(r) = api.fetch_fiat_rates(&base).await {
                for t in fiat_targets.iter() {
                    if let Some(val) = r.get(t) {
                        if !merged.contains_key(t) {
                            merged.insert(t.clone(), *val);
                            // use cached source if available; otherwise mark as "fiat"
                            let src = api.cached_fiat_source(&base).unwrap_or_else(|| "fiat".to_string());
                            fiat_source_map.insert(t.clone(), src);
                        }
                    }
                }
            }
        }

        if !merged.is_empty() {
            fiat_rates = Some((merged, "merged".to_string()));
            // We'll use source_map at insertion time below
        }
    }

    // We will use USD as common fiat for crypto cross when needed
    let usd = "USD".to_string();

    for tgt in targets.iter() {
        let tgt_is_crypto = is_crypto_currency(&pool, tgt).await?;
        let rate_and_source = if !base_is_crypto && !tgt_is_crypto {
            // fiat -> fiat
            if let Some((ref rates_map, _)) = fiat_rates {
                if let Some(rate) = rates_map.get(tgt) {
                    // Try to get per-currency provider label if available; otherwise fall back to cached/global
                    let provider = match fiat_source_map.get(tgt) {
                        Some(p) => p.clone(),
                        None => api.cached_fiat_source(&base).unwrap_or_else(|| "fiat".to_string()),
                    };
                    Some((*rate, provider))
                } else { None }
            } else { None }
        } else if base_is_crypto && !tgt_is_crypto {
            // crypto -> fiat: need price(base, tgt)
            // fetch crypto price of base in target fiat; if not supported, use USD cross
            // First try target directly
            let codes = vec![base.as_str()];
            if let Ok(prices) = api.fetch_crypto_prices(codes.clone(), tgt).await {
                let provider = api.cached_crypto_source(&[base.as_str()], tgt.as_str()).unwrap_or_else(|| "crypto".to_string());
                prices.get(&base).map(|price| (*price, provider))
            } else {
                // fallback via USD: price(base, USD) and fiat USD->tgt
                if crypto_prices_cache.is_none() {
                    if let Ok(p) = api.fetch_crypto_prices(vec![base.as_str()], &usd).await {
                        crypto_prices_cache = Some((p.clone(), "coingecko".to_string()));
                    }
                }
                if let (Some((ref cp, _)), Some((ref fr, ref provider))) = (&crypto_prices_cache, &fiat_rates) {
                    if let (Some(p_base_usd), Some(usd_to_tgt)) = (cp.get(&base), fr.get(tgt)) {
                        Some((*p_base_usd * *usd_to_tgt, provider.clone()))
                    } else { None }
                } else { None }
            }
        } else if !base_is_crypto && tgt_is_crypto {
            // fiat -> crypto: need price(tgt, base), then invert: 1 base = (1/price) tgt
            let codes = vec![tgt.as_str()];
            if let Ok(prices) = api.fetch_crypto_prices(codes.clone(), &base).await {
                let provider = api.cached_crypto_source(&[tgt.as_str()], base.as_str()).unwrap_or_else(|| "crypto".to_string());
                prices.get(tgt).map(|price| (Decimal::ONE / *price, provider))
            } else {
                // fallback via USD
                if crypto_prices_cache.is_none() {
                    if let Ok(p) = api.fetch_crypto_prices(vec![tgt.as_str()], &usd).await {
                        crypto_prices_cache = Some((p.clone(), "coingecko".to_string()));
                    }
                }
                if let (Some((ref cp, _)), Some((ref fr, ref provider))) = (&crypto_prices_cache, &fiat_rates) {
                    if let (Some(p_tgt_usd), Some(usd_to_base)) = (cp.get(tgt), fr.get(&base)) {
                        // price(tgt, base) = p_tgt_usd / usd_to_base; then invert for base->tgt
                        let price_tgt_base = *p_tgt_usd / *usd_to_base;
                        Some((Decimal::ONE / price_tgt_base, provider.clone()))
                    } else { None }
                } else { None }
            }
        } else {
            // crypto -> crypto: use USD cross
            let codes = vec![base.as_str(), tgt.as_str()];
            if let Ok(prices) = api.fetch_crypto_prices(codes.clone(), &usd).await {
                if let (Some(p_base_usd), Some(p_tgt_usd)) = (prices.get(&base), prices.get(tgt)) {
                    let rate = *p_base_usd / *p_tgt_usd; // 1 base = rate target
                    let provider = api.cached_crypto_source(&[base.as_str(), tgt.as_str()], "USD").unwrap_or_else(|| "crypto".to_string());
                    Some((rate, provider))
                } else { None }
            } else { None }
        };

        if let Some((rate, source)) = rate_and_source {
            result.insert(tgt.clone(), DetailedRateItem { rate, source });
        }
    }

    Ok(Json(ApiResponse::success(DetailedRatesResponse {
        base_currency: base,
        rates: result,
    })))
}

/// Get crypto prices with proper caching
pub async fn get_crypto_prices(
    State(pool): State<PgPool>,
    Query(query): Query<CryptoPricesQuery>,
) -> ApiResult<Json<ApiResponse<CryptoPricesResponse>>> {
    let fiat_currency = query.fiat_currency.unwrap_or_else(|| "USD".to_string());
    let crypto_codes = query.crypto_codes.unwrap_or_else(|| {
        vec!["BTC".to_string(), "ETH".to_string(), "USDT".to_string()]
    });
    
    // Get crypto prices from exchange_rates table
    let prices = sqlx::query!(
        r#"
        SELECT 
            from_currency as crypto_code,
            rate as price,
            created_at
        FROM exchange_rates
        WHERE to_currency = $1
        AND from_currency = ANY($2)
        AND created_at > NOW() - INTERVAL '5 minutes'
        ORDER BY created_at DESC
        "#,
        fiat_currency,
        &crypto_codes
    )
    .fetch_all(&pool)
    .await
    .map_err(|_| ApiError::InternalServerError)?;
    
    let mut crypto_prices = HashMap::new();
    let mut last_updated: Option<chrono::NaiveDateTime> = None;
    
    for row in prices {
        let price = Decimal::ONE / row.price;
        crypto_prices.insert(row.crypto_code, price);
        let created_naive = row.created_at.naive_utc();
        if last_updated.map(|lu| created_naive > lu).unwrap_or(true) {
            last_updated = Some(created_naive);
        }
    }
    
    // If no recent prices, return mock data
    if crypto_prices.is_empty() {
        crypto_prices = get_mock_crypto_prices(&fiat_currency);
        last_updated = Some(Utc::now().naive_utc());
    }
    
    Ok(Json(ApiResponse::success(CryptoPricesResponse {
        fiat_currency,
        prices: crypto_prices,
        last_updated,
        cache_duration_minutes: 5,
    })))
}

#[derive(Debug, Deserialize)]
pub struct CryptoPricesQuery {
    pub fiat_currency: Option<String>,
    // 支持两种格式：
    // 1) crypto_codes=BTC&crypto_codes=ETH
    // 2) crypto_codes=BTC,ETH
    #[serde(default, deserialize_with = "deserialize_csv_or_vec")] 
    pub crypto_codes: Option<Vec<String>>,
}

fn deserialize_csv_or_vec<'de, D>(deserializer: D) -> Result<Option<Vec<String>>, D::Error>
where
    D: Deserializer<'de>,
{
    struct CodesVisitor;

    impl<'de> Visitor<'de> for CodesVisitor {
        type Value = Option<Vec<String>>;

        fn expecting(&self, formatter: &mut std::fmt::Formatter) -> std::fmt::Result {
            formatter.write_str("a list of strings or a comma-separated string")
        }

        fn visit_none<E>(self) -> Result<Self::Value, E>
        where
            E: de::Error,
        {
            Ok(None)
        }

        fn visit_unit<E>(self) -> Result<Self::Value, E>
        where
            E: de::Error,
        {
            Ok(None)
        }

        fn visit_seq<A>(self, mut seq: A) -> Result<Self::Value, A::Error>
        where
            A: SeqAccess<'de>,
        {
            let mut items = Vec::new();
            while let Some(item) = seq.next_element::<String>()? {
                let s = item.trim();
                if !s.is_empty() { items.push(s.to_uppercase()); }
            }
            Ok(if items.is_empty() { None } else { Some(items) })
        }

        fn visit_str<E>(self, v: &str) -> Result<Self::Value, E>
        where
            E: de::Error,
        {
            let items: Vec<String> = v
                .split(',')
                .map(|s| s.trim())
                .filter(|s| !s.is_empty())
                .map(|s| s.to_uppercase())
                .collect();
            Ok(if items.is_empty() { None } else { Some(items) })
        }

        fn visit_string<E>(self, v: String) -> Result<Self::Value, E>
        where
            E: de::Error,
        {
            self.visit_str(&v)
        }
    }

    deserializer.deserialize_any(CodesVisitor)
}

#[derive(Debug, Serialize)]
pub struct CryptoPricesResponse {
    pub fiat_currency: String,
    pub prices: HashMap<String, Decimal>,
    pub last_updated: Option<chrono::NaiveDateTime>,
    pub cache_duration_minutes: i32,
}

/// Convert between any two currencies (fiat or crypto)
pub async fn convert_currency(
    State(pool): State<PgPool>,
    Json(req): Json<ConvertCurrencyRequest>,
) -> ApiResult<Json<ApiResponse<ConvertCurrencyResponse>>> {
    let service = CurrencyService::new(pool.clone());
    
    // Check if either is crypto
    let from_is_crypto = is_crypto_currency(&pool, &req.from).await?;
    let to_is_crypto = is_crypto_currency(&pool, &req.to).await?;
    
    let rate = if from_is_crypto || to_is_crypto {
        // Handle crypto conversion
        get_crypto_rate(&pool, &req.from, &req.to).await?
    } else {
        // Regular fiat conversion
        service.get_exchange_rate(&req.from, &req.to, None).await
            .map_err(|_| ApiError::NotFound("Exchange rate not found".to_string()))?
    };
    
    let converted_amount = req.amount * rate;
    
    Ok(Json(ApiResponse::success(ConvertCurrencyResponse {
        from: req.from.clone(),
        to: req.to.clone(),
        amount: req.amount,
        converted_amount,
        rate,
        is_crypto_involved: from_is_crypto || to_is_crypto,
    })))
}

#[derive(Debug, Deserialize)]
pub struct ConvertCurrencyRequest {
    pub from: String,
    pub to: String,
    pub amount: Decimal,
}

#[derive(Debug, Serialize)]
pub struct ConvertCurrencyResponse {
    pub from: String,
    pub to: String,
    pub amount: Decimal,
    pub converted_amount: Decimal,
    pub rate: Decimal,
    pub is_crypto_involved: bool,
}

/// Manual refresh of exchange rates
pub async fn manual_refresh_rates(
    State(_pool): State<PgPool>,
    _claims: Claims,
    Json(req): Json<ManualRefreshRequest>,
) -> ApiResult<Json<ApiResponse<RefreshResponse>>> {
    // TODO: Implement external API calls to update rates
    // For now, just mark as refreshed
    
    let message = format!(
        "Rates refreshed for base currency: {}",
        req.base_currency.unwrap_or_else(|| "USD".to_string())
    );
    
    Ok(Json(ApiResponse::success(RefreshResponse {
        success: true,
        message,
        refreshed_at: Utc::now().naive_utc(),
    })))
}

#[derive(Debug, Deserialize)]
pub struct ManualRefreshRequest {
    pub base_currency: Option<String>,
    pub include_crypto: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct RefreshResponse {
    pub success: bool,
    pub message: String,
    pub refreshed_at: chrono::NaiveDateTime,
}

// Helper functions

async fn is_crypto_currency(pool: &PgPool, code: &str) -> ApiResult<bool> {
    let result = sqlx::query_scalar!(
        "SELECT is_crypto FROM currencies WHERE code = $1",
        code
    )
    .fetch_optional(pool)
    .await
    .map_err(|_| ApiError::InternalServerError)?;
    
    Ok(result.flatten().unwrap_or(false))
}

async fn get_crypto_rate(pool: &PgPool, from: &str, to: &str) -> ApiResult<Decimal> {
    // Try direct rate
    let rate = sqlx::query_scalar!(
        r#"
        SELECT rate
        FROM exchange_rates
        WHERE from_currency = $1 AND to_currency = $2
        AND created_at > NOW() - INTERVAL '5 minutes'
        ORDER BY created_at DESC
        LIMIT 1
        "#,
        from,
        to
    )
    .fetch_optional(pool)
    .await
    .map_err(|_| ApiError::InternalServerError)?;
    
    if let Some(rate) = rate {
        return Ok(rate);
    }
    
    // Try inverse rate
    let inverse_rate = sqlx::query_scalar!(
        r#"
        SELECT rate
        FROM exchange_rates
        WHERE from_currency = $2 AND to_currency = $1
        AND created_at > NOW() - INTERVAL '5 minutes'
        ORDER BY created_at DESC
        LIMIT 1
        "#,
        from,
        to
    )
    .fetch_optional(pool)
    .await
    .map_err(|_| ApiError::InternalServerError)?;
    
    if let Some(rate) = inverse_rate {
        return Ok(Decimal::ONE / rate);
    }
    
    // Return mock rate for demo
    Ok(get_mock_rate(from, to))
}

fn get_default_rates(base: &str) -> HashMap<String, Decimal> {
    let mut rates = HashMap::new();
    
    match base {
        "USD" => {
            rates.insert("EUR".to_string(), decimal_from_str("0.92"));
            rates.insert("GBP".to_string(), decimal_from_str("0.79"));
            rates.insert("JPY".to_string(), decimal_from_str("147.50"));
            rates.insert("CNY".to_string(), decimal_from_str("7.25"));
            rates.insert("AUD".to_string(), decimal_from_str("1.53"));
            rates.insert("CAD".to_string(), decimal_from_str("1.36"));
            rates.insert("CHF".to_string(), decimal_from_str("0.88"));
            rates.insert("HKD".to_string(), decimal_from_str("7.80"));
            rates.insert("SGD".to_string(), decimal_from_str("1.35"));
        }
        "CNY" => {
            rates.insert("USD".to_string(), decimal_from_str("0.138"));
            rates.insert("EUR".to_string(), decimal_from_str("0.127"));
            rates.insert("JPY".to_string(), decimal_from_str("20.35"));
            rates.insert("HKD".to_string(), decimal_from_str("1.08"));
        }
        _ => {}
    }
    
    rates
}

fn get_mock_crypto_prices(fiat: &str) -> HashMap<String, Decimal> {
    let mut prices = HashMap::new();
    
    let usd_prices = vec![
        ("BTC", "67500.00"),
        ("ETH", "3450.00"),
        ("USDT", "1.00"),
        ("BNB", "580.00"),
        ("SOL", "185.00"),
        ("XRP", "0.52"),
        ("USDC", "1.00"),
        ("ADA", "0.45"),
        ("AVAX", "35.00"),
        ("DOGE", "0.08"),
    ];
    
    let multiplier = match fiat {
        "CNY" => decimal_from_str("7.25"),
        "EUR" => decimal_from_str("0.92"),
        "GBP" => decimal_from_str("0.79"),
        _ => Decimal::ONE,
    };
    
    for (code, price) in usd_prices {
        let base_price = decimal_from_str(price);
        prices.insert(code.to_string(), base_price * multiplier);
    }
    
    prices
}

fn get_mock_rate(from: &str, to: &str) -> Decimal {
    // Simple mock rates for demo
    match (from, to) {
        ("BTC", "USD") => decimal_from_str("67500"),
        ("ETH", "USD") => decimal_from_str("3450"),
        ("USD", "BTC") => decimal_from_str("0.0000148"),
        ("USD", "ETH") => decimal_from_str("0.00029"),
        _ => Decimal::ONE,
    }
}

use rust_decimal::prelude::FromStr;

fn decimal_from_str(s: &str) -> Decimal {
    Decimal::from_str(s).unwrap_or(Decimal::ZERO)
}
