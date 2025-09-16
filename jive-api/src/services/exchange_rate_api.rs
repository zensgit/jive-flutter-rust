use chrono::{DateTime, Utc, Duration};
use reqwest;
use rust_decimal::Decimal;
use serde::Deserialize; // Serialize 未用
use std::collections::HashMap;
use std::str::FromStr;
use tracing::{info, warn}; // error 未用

use super::ServiceError;

// ============================================
// 外部API响应模型
// ============================================

// Frankfurter API 响应
#[derive(Debug, Deserialize)]
struct FrankfurterResponse {
    amount: f64,
    base: String,
    date: String,
    rates: HashMap<String, f64>,
}

// ExchangeRate-API 响应
#[derive(Debug, Deserialize)]
struct ExchangeRateApiResponse {
    result: String,
    base: String,
    rates: HashMap<String, f64>,
    time_last_updated: i64,
}

// FXRatesAPI 响应
#[derive(Debug, Deserialize)]
struct FxRatesApiResponse {
    base: String,
    rates: HashMap<String, f64>,
    date: String,
}

// CoinGecko API 响应
#[derive(Debug, Deserialize)]
struct CoinGeckoResponse {
    #[serde(flatten)]
    prices: HashMap<String, CoinGeckoPriceData>,
}

#[derive(Debug, Deserialize)]
struct CoinGeckoPriceData {
    usd: f64,
    eur: Option<f64>,
    gbp: Option<f64>,
    jpy: Option<f64>,
    cny: Option<f64>,
    usd_24h_change: Option<f64>,
    usd_market_cap: Option<f64>,
    usd_24h_vol: Option<f64>,
}

// CoinCap API 响应
#[derive(Debug, Deserialize)]
struct CoinCapResponse {
    data: CoinCapData,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct CoinCapData {
    id: String,
    symbol: String,
    price_usd: String,
    change_percent_24_hr: Option<String>,
    market_cap_usd: Option<String>,
    volume_usd_24_hr: Option<String>,
}

// Binance ticker response
#[derive(Debug, Deserialize)]
struct BinanceTicker {
    symbol: String,
    price: String,
}

// ============================================
// 汇率API服务
// ============================================

pub struct ExchangeRateApiService {
    client: reqwest::Client,
    cache: HashMap<String, CachedRates>,
}

#[derive(Debug, Clone)]
struct CachedRates {
    rates: HashMap<String, Decimal>,
    timestamp: DateTime<Utc>,
    source: String,
}

impl CachedRates {
    fn is_expired(&self, duration: Duration) -> bool {
        Utc::now() - self.timestamp > duration
    }
}

impl ExchangeRateApiService {
    pub fn new() -> Self {
        let client = reqwest::Client::builder()
            .timeout(std::time::Duration::from_secs(10))
            .build()
            .unwrap();
        
        Self {
            client,
            cache: HashMap::new(),
        }
    }
    
    /// Inspect cached provider source for fiat by base code
    pub fn cached_fiat_source(&self, base_currency: &str) -> Option<String> {
        let key = format!("fiat_{}", base_currency);
        self.cache.get(&key).map(|c| c.source.clone())
    }

    /// Inspect cached provider source for crypto by codes + fiat
    pub fn cached_crypto_source(&self, crypto_codes: &[&str], fiat_currency: &str) -> Option<String> {
        let key = format!("crypto_{}_{}", crypto_codes.join(","), fiat_currency);
        self.cache.get(&key).map(|c| c.source.clone())
    }
    
    /// 获取法定货币汇率
    pub async fn fetch_fiat_rates(&mut self, base_currency: &str) -> Result<HashMap<String, Decimal>, ServiceError> {
        let cache_key = format!("fiat_{}", base_currency);
        
        // 检查缓存（15分钟有效期）
        if let Some(cached) = self.cache.get(&cache_key) {
            if !cached.is_expired(Duration::minutes(15)) {
                info!("Using cached rates for {} from {}", base_currency, cached.source);
                return Ok(cached.rates.clone());
            }
        }
        
        // 尝试多个数据源（顺序可配置：FIAT_PROVIDER_ORDER=exchangerate-api,frankfurter,fxrates）
        let mut rates = None;
        let mut source = String::new();
        let order_env = std::env::var("FIAT_PROVIDER_ORDER").unwrap_or_else(|_| "exchangerate-api,frankfurter,fxrates".to_string());
        let providers: Vec<String> = order_env
            .split(',')
            .map(|s| s.trim().to_lowercase())
            .filter(|s| !s.is_empty())
            .collect();
        for p in providers {
            match p.as_str() {
                "frankfurter" => match self.fetch_from_frankfurter(base_currency).await {
                    Ok(r) => { rates = Some(r); source = "frankfurter".to_string(); },
                    Err(e) => warn!("Failed to fetch from Frankfurter: {}", e),
                },
                "exchangerate-api" | "exchange-rate-api" => match self.fetch_from_exchangerate_api(base_currency).await {
                    Ok(r) => { rates = Some(r); source = "exchangerate-api".to_string(); },
                    Err(e) => warn!("Failed to fetch from ExchangeRate-API: {}", e),
                },
                "fxrates" | "fx-rates-api" | "fxratesapi" => match self.fetch_from_fxrates_api(base_currency).await {
                    Ok(r) => { rates = Some(r); source = "fxrates".to_string(); },
                    Err(e) => warn!("Failed to fetch from FXRates API: {}", e),
                },
                other => warn!("Unknown fiat provider: {}", other),
            }
            if rates.is_some() { break; }
        }
        
        // 如果获取成功，更新缓存
        if let Some(rates) = rates {
            self.cache.insert(
                cache_key,
                CachedRates {
                    rates: rates.clone(),
                    timestamp: Utc::now(),
                    source,
                },
            );
            return Ok(rates);
        }
        
        // 如果所有API都失败，返回默认汇率
        warn!("All rate APIs failed, returning default rates");
        Ok(self.get_default_rates(base_currency))
    }
    
    /// 从 Frankfurter API 获取汇率
    async fn fetch_from_frankfurter(&self, base_currency: &str) -> Result<HashMap<String, Decimal>, ServiceError> {
        let url = format!("https://api.frankfurter.app/latest?from={}", base_currency);
        
        let response = self.client
            .get(&url)
            .send()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to fetch from Frankfurter: {}", e),
            })?;
        
        if !response.status().is_success() {
            return Err(ServiceError::ExternalApi {
                message: format!("Frankfurter API returned status: {}", response.status()),
            });
        }
        
        let data: FrankfurterResponse = response
            .json()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to parse Frankfurter response: {}", e),
            })?;
        
        let mut rates = HashMap::new();
        for (currency, rate) in data.rates {
            if let Ok(decimal_rate) = Decimal::from_str(&rate.to_string()) {
                rates.insert(currency, decimal_rate);
            }
        }
        
        // 添加基础货币本身
        rates.insert(base_currency.to_string(), Decimal::ONE);
        
        Ok(rates)
    }

    /// 从 FXRates API 获取汇率
    async fn fetch_from_fxrates_api(&self, base_currency: &str) -> Result<HashMap<String, Decimal>, ServiceError> {
        let url = format!("https://api.fxratesapi.com/latest?base={}", base_currency);

        let response = self.client
            .get(&url)
            .send()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to fetch from FXRates API: {}", e),
            })?;

        if !response.status().is_success() {
            return Err(ServiceError::ExternalApi {
                message: format!("FXRates API returned status: {}", response.status()),
            });
        }

        let data: FxRatesApiResponse = response
            .json()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to parse FXRates response: {}", e),
            })?;

        let mut rates = HashMap::new();
        for (currency, rate) in data.rates {
            if let Ok(decimal_rate) = Decimal::from_str(&rate.to_string()) {
                rates.insert(currency, decimal_rate);
            }
        }
        // 添加基础货币本身
        rates.insert(base_currency.to_string(), Decimal::ONE);

        Ok(rates)
    }

    /// Fetch fiat rates from a specific provider label
    pub async fn fetch_fiat_rates_from(&self, provider: &str, base_currency: &str) -> Result<(HashMap<String, Decimal>, String), ServiceError> {
        match provider.to_lowercase().as_str() {
            "exchangerate-api" | "exchange-rate-api" => {
                let r = self.fetch_from_exchangerate_api(base_currency).await?;
                Ok((r, "exchangerate-api".to_string()))
            }
            "frankfurter" => {
                let r = self.fetch_from_frankfurter(base_currency).await?;
                Ok((r, "frankfurter".to_string()))
            }
            "fxrates" | "fx-rates-api" | "fxratesapi" => {
                let r = self.fetch_from_fxrates_api(base_currency).await?;
                Ok((r, "fxrates".to_string()))
            }
            other => Err(ServiceError::ExternalApi { message: format!("Unknown fiat provider: {}", other) }),
        }
    }
    
    /// 从 ExchangeRate-API 获取汇率（兼容 open.er-api 与 exchangerate-api 两种格式）
    async fn fetch_from_exchangerate_api(&self, base_currency: &str) -> Result<HashMap<String, Decimal>, ServiceError> {
        // 优先尝试 open.er-api.com（无需密钥，速率较高）
        let try_urls = vec![
            format!("https://open.er-api.com/v6/latest/{}", base_currency),
            format!("https://api.exchangerate-api.com/v4/latest/{}", base_currency),
        ];

        let mut last_err: Option<String> = None;
        for url in try_urls {
            let resp = match self.client.get(&url).send().await {
                Ok(r) => r,
                Err(e) => { last_err = Some(format!("request error: {}", e)); continue; }
            };
            if !resp.status().is_success() { 
                last_err = Some(format!("status: {}", resp.status()));
                continue; 
            }
            let v: serde_json::Value = match resp.json().await {
                Ok(json) => json,
                Err(e) => { last_err = Some(format!("json error: {}", e)); continue; }
            };
            // 允许两种字段名：rates 或 conversion_rates
            let map_node = v.get("rates").or_else(|| v.get("conversion_rates"));
            if let Some(map) = map_node.and_then(|n| n.as_object()) {
                let mut rates = HashMap::new();
                for (code, val) in map.iter() {
                    if let Some(f) = val.as_f64() {
                        if let Ok(d) = Decimal::from_str(&f.to_string()) {
                            rates.insert(code.to_uppercase(), d);
                        }
                    }
                }
                // 添加基础货币自环
                rates.insert(base_currency.to_uppercase(), Decimal::ONE);
                if !rates.is_empty() { return Ok(rates); }
            }
            last_err = Some("missing rates map".to_string());
        }
        Err(ServiceError::ExternalApi { message: format!("Failed to fetch/parse ExchangeRate-API: {}", last_err.unwrap_or_else(|| "unknown".to_string())) })
    }
    
    /// 获取加密货币价格
    pub async fn fetch_crypto_prices(&mut self, crypto_codes: Vec<&str>, fiat_currency: &str) -> Result<HashMap<String, Decimal>, ServiceError> {
        let cache_key = format!("crypto_{}_{}", crypto_codes.join(","), fiat_currency);
        
        // 检查缓存（5分钟有效期）
        if let Some(cached) = self.cache.get(&cache_key) {
            if !cached.is_expired(Duration::minutes(5)) {
                info!("Using cached crypto prices from {}", cached.source);
                return Ok(cached.rates.clone());
            }
        }
        
        // 尝试从多个加密货币提供商获取（顺序可配置：CRYPTO_PROVIDER_ORDER=coingecko,coincap）
        let mut prices = None;
        let mut source = String::new();
        let order_env = std::env::var("CRYPTO_PROVIDER_ORDER").unwrap_or_else(|_| "coingecko,coincap,binance".to_string());
        let providers: Vec<String> = order_env
            .split(',')
            .map(|s| s.trim().to_lowercase())
            .filter(|s| !s.is_empty())
            .collect();
        for p in providers {
            match p.as_str() {
                "coingecko" => match self.fetch_from_coingecko(&crypto_codes, fiat_currency).await {
                    Ok(pr) => { prices = Some(pr); source = "coingecko".to_string(); },
                    Err(e) => warn!("Failed to fetch from CoinGecko: {}", e),
                },
                "coincap" => {
                    // CoinCap effectively USD; for non-USD we still return USD prices for cross computation by caller
                    for code in &crypto_codes {
                        if let Ok(price) = self.fetch_from_coincap(code).await {
                            if prices.is_none() { prices = Some(HashMap::new()); }
                            if let Some(ref mut pmap) = prices { pmap.insert(code.to_string(), price); }
                        }
                    }
                    if prices.is_some() { source = "coincap".to_string(); }
                }
                "binance" => {
                    // Binance provides USDT pairs. Only support USD (treated as USDT) directly.
                    if fiat_currency.to_uppercase() == "USD" {
                        if let Ok(pmap) = self.fetch_from_binance(&crypto_codes).await {
                            if !pmap.is_empty() { prices = Some(pmap); source = "binance".to_string(); }
                        }
                    }
                }
                other => warn!("Unknown crypto provider: {}", other),
            }
            if prices.is_some() { break; }
        }
        
        // 更新缓存
        if let Some(prices) = prices {
            self.cache.insert(
                cache_key,
                CachedRates {
                    rates: prices.clone(),
                    timestamp: Utc::now(),
                    source,
                },
            );
            return Ok(prices);
        }
        
        // 返回默认价格
        warn!("All crypto APIs failed, returning default prices");
        Ok(self.get_default_crypto_prices())
    }
    
    /// 从 CoinGecko 获取加密货币价格
    async fn fetch_from_coingecko(&self, crypto_codes: &[&str], fiat_currency: &str) -> Result<HashMap<String, Decimal>, ServiceError> {
        // CoinGecko ID 映射
        let id_map: HashMap<&str, &str> = [
            ("BTC", "bitcoin"),
            ("ETH", "ethereum"),
            ("USDT", "tether"),
            ("BNB", "binancecoin"),
            ("SOL", "solana"),
            ("XRP", "ripple"),
            ("USDC", "usd-coin"),
            ("ADA", "cardano"),
            ("AVAX", "avalanche-2"),
            ("DOGE", "dogecoin"),
            ("DOT", "polkadot"),
            ("MATIC", "matic-network"),
            ("LINK", "chainlink"),
            ("LTC", "litecoin"),
            ("UNI", "uniswap"),
            ("ATOM", "cosmos"),
            ("COMP", "compound-governance-token"),
            ("MKR", "maker"),
            ("AAVE", "aave"),
            ("SUSHI", "sushi"),
            ("ARB", "arbitrum"),
            ("OP", "optimism"),
            ("SHIB", "shiba-inu"),
            ("TRX", "tron"),
        ].iter().cloned().collect();
        
        let ids: Vec<String> = crypto_codes
            .iter()
            .filter_map(|code| id_map.get(code).map(|id| id.to_string()))
            .collect();
        
        if ids.is_empty() {
            return Ok(HashMap::new());
        }
        
        let url = format!(
            "https://api.coingecko.com/api/v3/simple/price?ids={}&vs_currencies={}&include_24hr_change=true&include_market_cap=true&include_24hr_vol=true",
            ids.join(","),
            fiat_currency.to_lowercase()
        );
        
        let response = self.client
            .get(&url)
            .send()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to fetch from CoinGecko: {}", e),
            })?;
        
        if !response.status().is_success() {
            return Err(ServiceError::ExternalApi {
                message: format!("CoinGecko API returned status: {}", response.status()),
            });
        }
        
        let data: HashMap<String, HashMap<String, f64>> = response
            .json()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to parse CoinGecko response: {}", e),
            })?;
        
        let mut prices = HashMap::new();
        
        // 反向映射回代码
        let reverse_map: HashMap<&str, &str> = id_map.iter().map(|(k, v)| (*v, *k)).collect();
        
        for (id, price_data) in data {
            if let Some(code) = reverse_map.get(id.as_str()) {
                if let Some(price) = price_data.get(&fiat_currency.to_lowercase()) {
                    if let Ok(decimal_price) = Decimal::from_str(&price.to_string()) {
                        prices.insert(code.to_string(), decimal_price);
                    }
                }
            }
        }
        
        Ok(prices)
    }
    
    /// 从 CoinCap 获取单个加密货币价格 (仅USD)
    async fn fetch_from_coincap(&self, crypto_code: &str) -> Result<Decimal, ServiceError> {
        let id_map: HashMap<&str, &str> = [
            ("BTC", "bitcoin"),
            ("ETH", "ethereum"),
            ("USDT", "tether"),
            ("BNB", "binance-coin"),
            ("SOL", "solana"),
            ("XRP", "xrp"),
            ("USDC", "usd-coin"),
            ("ADA", "cardano"),
            ("AVAX", "avalanche"),
            ("DOGE", "dogecoin"),
            ("DOT", "polkadot"),
            ("MATIC", "polygon"),
            ("LINK", "chainlink"),
            ("LTC", "litecoin"),
            ("UNI", "uniswap"),
            ("ATOM", "cosmos"),
        ].iter().cloned().collect();
        
        let id = id_map.get(crypto_code).ok_or(ServiceError::NotFound {
            resource_type: "CryptoId".to_string(),
            id: crypto_code.to_string(),
        })?;
        
        let url = format!("https://api.coincap.io/v2/assets/{}", id);
        
        let response = self.client
            .get(&url)
            .send()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to fetch from CoinCap: {}", e),
            })?;
        
        if !response.status().is_success() {
            return Err(ServiceError::ExternalApi {
                message: format!("CoinCap API returned status: {}", response.status()),
            });
        }
        
        let data: CoinCapResponse = response
            .json()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to parse CoinCap response: {}", e),
            })?;
        
        Decimal::from_str(&data.data.price_usd).map_err(|e| ServiceError::ExternalApi {
            message: format!("Failed to parse price: {}", e),
        })
    }

    /// 从 Binance 获取加密货币 USDT 价格 (近似 USD)
    async fn fetch_from_binance(&self, crypto_codes: &[&str]) -> Result<HashMap<String, Decimal>, ServiceError> {
        let mut result = HashMap::new();
        for code in crypto_codes {
            let uc = code.to_uppercase();
            if uc == "USD" || uc == "USDT" { 
                result.insert(uc.clone(), Decimal::ONE);
                continue; 
            }
            let symbol = format!("{}USDT", uc);
            let url = format!("https://api.binance.com/api/v3/ticker/price?symbol={}", symbol);
            let resp = self.client
                .get(&url)
                .send()
                .await
                .map_err(|e| ServiceError::ExternalApi { message: format!("Failed to fetch from Binance: {}", e) })?;
            if !resp.status().is_success() {
                // Skip this code silently; continue other codes
                continue;
            }
            let data: BinanceTicker = match resp.json().await {
                Ok(v) => v,
                Err(_) => continue,
            };
            if let Ok(price) = Decimal::from_str(&data.price) {
                result.insert(uc, price);
            }
        }
        Ok(result)
    }
    
    /// 获取默认汇率（用于API失败时的备用）
    fn get_default_rates(&self, base_currency: &str) -> HashMap<String, Decimal> {
        let mut rates = HashMap::new();
        
        // 基础货币
        rates.insert(base_currency.to_string(), Decimal::ONE);
        
        // 主要货币的大概汇率（以USD为基准）
        let usd_rates: HashMap<&str, f64> = [
            ("USD", 1.0),
            ("EUR", 0.85),
            ("GBP", 0.73),
            ("JPY", 110.0),
            ("CNY", 6.45),
            ("HKD", 7.75),
            ("SGD", 1.35),
            ("AUD", 1.35),
            ("CAD", 1.25),
            ("CHF", 0.92),
            ("SEK", 8.6),
            ("NOK", 8.5),
            ("DKK", 6.3),
            ("NZD", 1.42),
            ("INR", 74.5),
            ("KRW", 1180.0),
            ("MXN", 20.0),
            ("BRL", 5.0),
            ("RUB", 75.0),
            ("ZAR", 15.0),
        ].iter().cloned().collect();
        
        // 获取基础货币对USD的汇率
        let base_to_usd = usd_rates.get(base_currency).copied().unwrap_or(1.0);
        
        // 计算相对汇率
        for (currency, usd_rate) in usd_rates.iter() {
            if *currency != base_currency {
                let rate = *usd_rate as f64 / base_to_usd;
                if let Ok(decimal_rate) = Decimal::from_str(&rate.to_string()) {
                    rates.insert((*currency).to_string(), decimal_rate);
                }
            }
        }
        
        rates
    }
    
    /// 获取默认加密货币价格（USD）
    fn get_default_crypto_prices(&self) -> HashMap<String, Decimal> {
        let prices: HashMap<&str, f64> = [
            ("BTC", 45000.0),
            ("ETH", 3000.0),
            ("USDT", 1.0),
            ("BNB", 300.0),
            ("SOL", 100.0),
            ("XRP", 0.5),
            ("USDC", 1.0),
            ("ADA", 0.5),
            ("AVAX", 30.0),
            ("DOGE", 0.08),
            ("DOT", 7.0),
            ("MATIC", 0.8),
            ("LINK", 7.0),
            ("LTC", 100.0),
            ("UNI", 6.0),
            ("ATOM", 10.0),
        ].iter().cloned().collect();
        
        let mut result = HashMap::new();
        for (code, price) in prices {
            if let Ok(decimal_price) = Decimal::from_str(&price.to_string()) {
                result.insert(code.to_string(), decimal_price);
            }
        }
        
        result
    }
}

// 单例模式的全局服务实例
use tokio::sync::Mutex;
use std::sync::Arc;

lazy_static::lazy_static! {
    pub static ref EXCHANGE_RATE_SERVICE: Arc<Mutex<ExchangeRateApiService>> = Arc::new(Mutex::new(ExchangeRateApiService::new()));
}
