use chrono::{DateTime, Utc, Duration};
use reqwest;
use rust_decimal::Decimal;
use serde::Deserialize;
use std::collections::HashMap;
use std::str::FromStr;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn, debug};

use super::ServiceError;
use crate::models::{GlobalMarketStats, CoinGeckoGlobalResponse};

// ============================================
// 外部API响应模型
// ============================================

// Frankfurter API 响应
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct FrankfurterResponse {
    amount: f64,
    base: String,
    date: String,
    rates: HashMap<String, f64>,
}

// ExchangeRate-API 响应
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct ExchangeRateApiResponse {
    result: String,
    base: String,
    rates: HashMap<String, f64>,
    time_last_updated: i64,
}

// FXRatesAPI 响应
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct FxRatesApiResponse {
    base: String,
    rates: HashMap<String, f64>,
    date: String,
}

// CoinGecko API 响应
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct CoinGeckoResponse {
    #[serde(flatten)]
    prices: HashMap<String, CoinGeckoPriceData>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
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

// CoinGecko 币种列表响应
#[derive(Debug, Deserialize)]
struct CoinGeckoCoinListItem {
    id: String,
    symbol: String,
    name: String,
}

// CoinMarketCap API 响应
#[derive(Debug, Deserialize)]
struct CoinMarketCapResponse {
    data: HashMap<String, Vec<CoinMarketCapQuote>>,
}

#[derive(Debug, Deserialize)]
struct CoinMarketCapQuote {
    quote: HashMap<String, CoinMarketCapQuoteData>,
}

#[derive(Debug, Deserialize)]
struct CoinMarketCapQuoteData {
    price: f64,
    percent_change_24h: Option<f64>,
    percent_change_7d: Option<f64>,
    percent_change_30d: Option<f64>,
}

// CoinCap API 响应
#[derive(Debug, Deserialize)]
struct CoinCapResponse {
    data: CoinCapData,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
#[allow(dead_code)]
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
#[allow(dead_code)]
struct BinanceTicker {
    symbol: String,
    price: String,
}

// OKX API 响应
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct OkxResponse {
    code: String,
    data: Vec<OkxTickerData>,
}

#[derive(Debug, Deserialize)]
#[allow(dead_code)]
#[serde(rename_all = "camelCase")]
struct OkxTickerData {
    inst_id: String,    // 交易对 BTC-USDT
    last: String,       // 最新价格
}

// Gate.io API 响应
#[derive(Debug, Deserialize)]
#[allow(dead_code)]
struct GateioTicker {
    currency_pair: String,  // 交易对 BTC_USDT
    last: String,           // 最新价格
}

// ============================================
// 币种ID映射结构
// ============================================

#[derive(Debug, Clone)]
struct CoinIdMapping {
    /// Symbol -> CoinGecko ID
    coingecko: HashMap<String, String>,
    /// Symbol -> CoinMarketCap ID (使用symbol本身)
    coinmarketcap: HashMap<String, String>,
    /// Symbol -> CoinCap ID
    coincap: HashMap<String, String>,
    /// 最后更新时间
    last_updated: DateTime<Utc>,
}

impl CoinIdMapping {
    fn new() -> Self {
        Self {
            coingecko: HashMap::new(),
            coinmarketcap: HashMap::new(),
            coincap: Self::default_coincap_mapping(),
            // 设置为过去的时间，强制第一次调用时加载映射
            last_updated: Utc::now() - Duration::hours(25),
        }
    }

    fn is_expired(&self) -> bool {
        Utc::now() - self.last_updated > Duration::hours(24)
    }

    /// CoinCap 默认映射（较少币种，手动维护）
    fn default_coincap_mapping() -> HashMap<String, String> {
        [
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
        ]
        .iter()
        .map(|(k, v)| (k.to_string(), v.to_string()))
        .collect()
    }
}

// ============================================
// 汇率API服务
// ============================================

pub struct ExchangeRateApiService {
    client: reqwest::Client,
    cache: HashMap<String, CachedRates>,
    /// 币种ID映射（动态加载）
    coin_mappings: Arc<RwLock<CoinIdMapping>>,
    /// 全球市场统计缓存
    global_market_cache: Option<(GlobalMarketStats, DateTime<Utc>)>,
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
            coin_mappings: Arc::new(RwLock::new(CoinIdMapping::new())),
            global_market_cache: None,
        }
    }

    // ============================================
    // 币种ID映射管理
    // ============================================

    /// 确保币种ID映射已加载并且是最新的
    pub async fn ensure_coin_mappings(&self) -> Result<(), ServiceError> {
        let mappings = self.coin_mappings.read().await;

        if !mappings.is_expired() {
            debug!("Coin mappings are up-to-date");
            return Ok(());
        }

        drop(mappings); // 释放读锁

        info!("Coin mappings expired, refreshing from CoinGecko API");
        let new_coingecko_map = self.fetch_coingecko_coin_list().await?;

        let mut mappings = self.coin_mappings.write().await;
        mappings.coingecko = new_coingecko_map;
        mappings.last_updated = Utc::now();

        info!("Successfully refreshed {} CoinGecko coin mappings", mappings.coingecko.len());

        Ok(())
    }

    /// 从CoinGecko API获取完整币种列表
    async fn fetch_coingecko_coin_list(&self) -> Result<HashMap<String, String>, ServiceError> {
        let url = "https://api.coingecko.com/api/v3/coins/list";

        let response = self.client
            .get(url)
            .send()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to fetch CoinGecko coin list: {}", e),
            })?;

        if !response.status().is_success() {
            return Err(ServiceError::ExternalApi {
                message: format!("CoinGecko coin list API returned status: {}", response.status()),
            });
        }

        let coins: Vec<CoinGeckoCoinListItem> = response
            .json()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to parse CoinGecko coin list: {}", e),
            })?;

        // 构建 symbol -> id 映射
        let mut mapping = HashMap::new();
        for coin in coins {
            let symbol = coin.symbol.to_uppercase();
            // 优先保留第一个出现的映射（通常是主网币种）
            mapping.entry(symbol).or_insert(coin.id);
        }

        Ok(mapping)
    }

    /// 获取币种的CoinGecko ID
    async fn get_coingecko_id(&self, crypto_code: &str) -> Option<String> {
        let mappings = self.coin_mappings.read().await;
        mappings.coingecko.get(&crypto_code.to_uppercase()).cloned()
    }

    /// 批量获取多个币种的CoinGecko ID
    async fn get_coingecko_ids(&self, crypto_codes: &[&str]) -> Vec<String> {
        let mappings = self.coin_mappings.read().await;
        crypto_codes
            .iter()
            .filter_map(|code| mappings.coingecko.get(&code.to_uppercase()).cloned())
            .collect()
    }

    /// 获取币种的CoinCap ID
    async fn get_coincap_id(&self, crypto_code: &str) -> Option<String> {
        let mappings = self.coin_mappings.read().await;
        mappings.coincap.get(&crypto_code.to_uppercase()).cloned()
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

    // ============================================
    // 法定货币汇率（保持原有逻辑）
    // ============================================

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

    // ============================================
    // 加密货币价格（多数据源智能降级）
    // ============================================

    /// 获取加密货币价格（智能降级策略）
    pub async fn fetch_crypto_prices(&mut self, crypto_codes: Vec<&str>, fiat_currency: &str) -> Result<HashMap<String, Decimal>, ServiceError> {
        let cache_key = format!("crypto_{}_{}", crypto_codes.join(","), fiat_currency);

        // 检查缓存（5分钟有效期）
        if let Some(cached) = self.cache.get(&cache_key) {
            if !cached.is_expired(Duration::minutes(5)) {
                info!("Using cached crypto prices from {}", cached.source);
                return Ok(cached.rates.clone());
            }
        }

        // 确保币种映射已加载
        if let Err(e) = self.ensure_coin_mappings().await {
            warn!("Failed to refresh coin mappings: {}", e);
        }

        // 智能降级策略：CoinGecko → OKX → Gate.io → CoinMarketCap → Binance → CoinCap
        let mut prices = None;
        let mut source = String::new();
        let order_env = std::env::var("CRYPTO_PROVIDER_ORDER")
            .unwrap_or_else(|_| "coingecko,okx,gateio,coinmarketcap,binance,coincap".to_string());
        let providers: Vec<String> = order_env
            .split(',')
            .map(|s| s.trim().to_lowercase())
            .filter(|s| !s.is_empty())
            .collect();

        for provider in providers {
            match provider.as_str() {
                "coingecko" => {
                    match self.fetch_from_coingecko_dynamic(&crypto_codes, fiat_currency).await {
                        Ok(pr) if !pr.is_empty() => {
                            info!("Successfully fetched {} prices from CoinGecko", pr.len());
                            prices = Some(pr);
                            source = "coingecko".to_string();
                        }
                        Ok(_) => warn!("CoinGecko returned empty result"),
                        Err(e) => warn!("Failed to fetch from CoinGecko: {}", e),
                    }
                }
                "okx" => {
                    // OKX仅支持USDT对（近似USD）
                    if fiat_currency.to_uppercase() == "USD" {
                        match self.fetch_from_okx(&crypto_codes).await {
                            Ok(pr) if !pr.is_empty() => {
                                info!("Successfully fetched {} prices from OKX", pr.len());
                                prices = Some(pr);
                                source = "okx".to_string();
                            }
                            Ok(_) => warn!("OKX returned empty result"),
                            Err(e) => warn!("Failed to fetch from OKX: {}", e),
                        }
                    }
                }
                "gateio" | "gate.io" => {
                    // Gate.io仅支持USDT对（近似USD）
                    if fiat_currency.to_uppercase() == "USD" {
                        match self.fetch_from_gateio(&crypto_codes).await {
                            Ok(pr) if !pr.is_empty() => {
                                info!("Successfully fetched {} prices from Gate.io", pr.len());
                                prices = Some(pr);
                                source = "gateio".to_string();
                            }
                            Ok(_) => warn!("Gate.io returned empty result"),
                            Err(e) => warn!("Failed to fetch from Gate.io: {}", e),
                        }
                    }
                }
                "coinmarketcap" => {
                    if let Ok(api_key) = std::env::var("COINMARKETCAP_API_KEY") {
                        match self.fetch_from_coinmarketcap(&crypto_codes, fiat_currency, &api_key).await {
                            Ok(pr) if !pr.is_empty() => {
                                info!("Successfully fetched {} prices from CoinMarketCap", pr.len());
                                prices = Some(pr);
                                source = "coinmarketcap".to_string();
                            }
                            Ok(_) => warn!("CoinMarketCap returned empty result"),
                            Err(e) => warn!("Failed to fetch from CoinMarketCap: {}", e),
                        }
                    } else {
                        debug!("COINMARKETCAP_API_KEY not set, skipping CoinMarketCap");
                    }
                }
                "binance" => {
                    // Binance仅支持USDT对（近似USD）
                    if fiat_currency.to_uppercase() == "USD" {
                        match self.fetch_from_binance(&crypto_codes).await {
                            Ok(pr) if !pr.is_empty() => {
                                info!("Successfully fetched {} prices from Binance", pr.len());
                                prices = Some(pr);
                                source = "binance".to_string();
                            }
                            Ok(_) => warn!("Binance returned empty result"),
                            Err(e) => warn!("Failed to fetch from Binance: {}", e),
                        }
                    }
                }
                "coincap" => {
                    let mut pr = HashMap::new();
                    for code in &crypto_codes {
                        if let Ok(price) = self.fetch_from_coincap_dynamic(code).await {
                            pr.insert(code.to_string(), price);
                        }
                    }
                    if !pr.is_empty() {
                        info!("Successfully fetched {} prices from CoinCap", pr.len());
                        prices = Some(pr);
                        source = "coincap".to_string();
                    }
                }
                other => warn!("Unknown crypto provider: {}", other),
            }

            if prices.is_some() {
                break; // 成功获取数据，退出降级循环
            }
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

        // 所有数据源都失败，返回错误以允许降级逻辑生效
        warn!("All crypto APIs failed for {:?}", crypto_codes);
        Err(ServiceError::ExternalApi {
            message: format!("All crypto price APIs failed for {:?}", crypto_codes),
        })
    }

    /// 从 CoinGecko 获取加密货币价格（动态映射）
    async fn fetch_from_coingecko_dynamic(&self, crypto_codes: &[&str], fiat_currency: &str) -> Result<HashMap<String, Decimal>, ServiceError> {
        // 获取币种ID列表
        let ids = self.get_coingecko_ids(crypto_codes).await;

        if ids.is_empty() {
            return Err(ServiceError::ExternalApi {
                message: "No CoinGecko IDs found for requested crypto codes".to_string(),
            });
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

        // 反向映射：CoinGecko ID -> Symbol
        let mappings = self.coin_mappings.read().await;
        let reverse_map: HashMap<&str, &str> = mappings
            .coingecko
            .iter()
            .map(|(symbol, id)| (id.as_str(), symbol.as_str()))
            .collect();

        for (coin_id, price_data) in data {
            if let Some(symbol) = reverse_map.get(coin_id.as_str()) {
                if let Some(price) = price_data.get(&fiat_currency.to_lowercase()) {
                    if let Ok(decimal_price) = Decimal::from_str(&price.to_string()) {
                        prices.insert(symbol.to_string(), decimal_price);
                    }
                }
            }
        }

        Ok(prices)
    }

    /// 从 CoinMarketCap 获取加密货币价格
    async fn fetch_from_coinmarketcap(
        &self,
        crypto_codes: &[&str],
        fiat_currency: &str,
        api_key: &str,
    ) -> Result<HashMap<String, Decimal>, ServiceError> {
        let symbols = crypto_codes.join(",");
        let url = format!(
            "https://pro-api.coinmarketcap.com/v2/cryptocurrency/quotes/latest?symbol={}&convert={}",
            symbols, fiat_currency
        );

        let response = self.client
            .get(&url)
            .header("X-CMC_PRO_API_KEY", api_key)
            .send()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to fetch from CoinMarketCap: {}", e),
            })?;

        if !response.status().is_success() {
            return Err(ServiceError::ExternalApi {
                message: format!("CoinMarketCap API returned status: {}", response.status()),
            });
        }

        let data: CoinMarketCapResponse = response
            .json()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to parse CoinMarketCap response: {}", e),
            })?;

        let mut prices = HashMap::new();

        for (symbol, quotes) in data.data {
            if let Some(quote) = quotes.first() {
                if let Some(quote_data) = quote.quote.get(&fiat_currency.to_uppercase()) {
                    if let Ok(decimal_price) = Decimal::from_str(&quote_data.price.to_string()) {
                        prices.insert(symbol, decimal_price);
                    }
                }
            }
        }

        Ok(prices)
    }

    /// 从 CoinCap 获取单个加密货币价格（动态映射）
    async fn fetch_from_coincap_dynamic(&self, crypto_code: &str) -> Result<Decimal, ServiceError> {
        let coin_id = self.get_coincap_id(crypto_code).await.ok_or_else(|| {
            ServiceError::NotFound {
                resource_type: "CoinCapId".to_string(),
                id: crypto_code.to_string(),
            }
        })?;

        let url = format!("https://api.coincap.io/v2/assets/{}", coin_id);

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

    /// 从 OKX 获取加密货币 USDT 价格 (近似 USD)
    async fn fetch_from_okx(&self, crypto_codes: &[&str]) -> Result<HashMap<String, Decimal>, ServiceError> {
        let mut result = HashMap::new();
        for code in crypto_codes {
            let uc = code.to_uppercase();
            if uc == "USD" || uc == "USDT" {
                result.insert(uc.clone(), Decimal::ONE);
                continue;
            }
            // OKX使用 BTC-USDT 格式
            let inst_id = format!("{}-USDT", uc);
            let url = format!("https://www.okx.com/api/v5/market/ticker?instId={}", inst_id);

            let resp = self.client
                .get(&url)
                .send()
                .await
                .map_err(|e| ServiceError::ExternalApi { message: format!("Failed to fetch from OKX: {}", e) })?;

            if !resp.status().is_success() {
                debug!("OKX API failed for {}: status {}", inst_id, resp.status());
                continue;
            }

            let data: OkxResponse = match resp.json().await {
                Ok(v) => v,
                Err(e) => {
                    debug!("Failed to parse OKX response for {}: {}", inst_id, e);
                    continue;
                }
            };

            // OKX返回code="0"表示成功
            if data.code != "0" {
                debug!("OKX returned error code {} for {}", data.code, inst_id);
                continue;
            }

            if let Some(ticker) = data.data.first() {
                if let Ok(price) = Decimal::from_str(&ticker.last) {
                    debug!("Successfully fetched {} price from OKX: {}", uc, price);
                    result.insert(uc, price);
                }
            }
        }
        Ok(result)
    }

    /// 从 Gate.io 获取加密货币 USDT 价格 (近似 USD)
    async fn fetch_from_gateio(&self, crypto_codes: &[&str]) -> Result<HashMap<String, Decimal>, ServiceError> {
        let mut result = HashMap::new();
        for code in crypto_codes {
            let uc = code.to_uppercase();
            if uc == "USD" || uc == "USDT" {
                result.insert(uc.clone(), Decimal::ONE);
                continue;
            }
            // Gate.io使用 BTC_USDT 格式
            let currency_pair = format!("{}_USDT", uc);
            let url = format!("https://api.gateio.ws/api/v4/spot/tickers?currency_pair={}", currency_pair);

            let resp = self.client
                .get(&url)
                .send()
                .await
                .map_err(|e| ServiceError::ExternalApi { message: format!("Failed to fetch from Gate.io: {}", e) })?;

            if !resp.status().is_success() {
                debug!("Gate.io API failed for {}: status {}", currency_pair, resp.status());
                continue;
            }

            // Gate.io返回数组
            let data: Vec<GateioTicker> = match resp.json().await {
                Ok(v) => v,
                Err(e) => {
                    debug!("Failed to parse Gate.io response for {}: {}", currency_pair, e);
                    continue;
                }
            };

            if let Some(ticker) = data.first() {
                if let Ok(price) = Decimal::from_str(&ticker.last) {
                    debug!("Successfully fetched {} price from Gate.io: {}", uc, price);
                    result.insert(uc, price);
                }
            }
        }
        Ok(result)
    }

    // ============================================
    // 历史价格（支持多数据源降级）
    // ============================================

    /// 获取加密货币历史价格（数据库优先，API降级）
    pub async fn fetch_crypto_historical_price(
        &self,
        pool: &sqlx::PgPool,
        crypto_code: &str,
        fiat_currency: &str,
        days_ago: u32,
    ) -> Result<Option<Decimal>, ServiceError> {
        debug!("📊 Fetching historical price for {}->{} ({} days ago)", crypto_code, fiat_currency, days_ago);

        // 1️⃣ 优先从数据库查询历史记录（±12小时窗口）
        let target_date = Utc::now() - Duration::days(days_ago as i64);
        let window_start = target_date - Duration::hours(12);
        let window_end = target_date + Duration::hours(12);

        debug!("🔍 Step 1: Querying database for historical record (target: {}, window: {} to {})",
            target_date.format("%Y-%m-%d %H:%M"),
            window_start.format("%Y-%m-%d %H:%M"),
            window_end.format("%Y-%m-%d %H:%M")
        );

        let db_result = sqlx::query!(
            r#"
            SELECT rate, updated_at
            FROM exchange_rates
            WHERE from_currency = $1
            AND to_currency = $2
            AND updated_at BETWEEN $3 AND $4
            ORDER BY ABS(EXTRACT(EPOCH FROM (updated_at - $5)))
            LIMIT 1
            "#,
            crypto_code,
            fiat_currency,
            window_start,
            window_end,
            target_date
        )
        .fetch_optional(pool)
        .await;

        match db_result {
            Ok(Some(record)) => {
                let age_hours = record.updated_at.map(|updated| (Utc::now() - updated).num_hours());
                if let Some(age) = age_hours {
                    info!("✅ Step 1 SUCCESS: Found historical rate in database for {}->{}: rate={}, age={} hours ago",
                        crypto_code, fiat_currency, record.rate, age);
                } else {
                    info!("✅ Step 1 SUCCESS: Found historical rate in database for {}->{}: rate={}",
                        crypto_code, fiat_currency, record.rate);
                }
                return Ok(Some(record.rate));
            }
            Ok(None) => {
                debug!("❌ Step 1 FAILED: No historical record found in database for {}->{} within ±12 hour window",
                    crypto_code, fiat_currency);
            }
            Err(e) => {
                warn!("❌ Step 1 FAILED: Database query error for {}->{}: {}",
                    crypto_code, fiat_currency, e);
            }
        }

        // 2️⃣ 数据库无记录，尝试外部API
        debug!("🌐 Step 2: Trying external API (CoinGecko) for {}->{}", crypto_code, fiat_currency);

        // 确保币种映射已加载
        if let Err(e) = self.ensure_coin_mappings().await {
            warn!("Failed to refresh coin mappings: {}", e);
        }

        if let Some(coin_id) = self.get_coingecko_id(crypto_code).await {
            match self.fetch_coingecko_historical_price(&coin_id, fiat_currency, days_ago).await {
                Ok(Some(price)) => {
                    info!("✅ Step 2 SUCCESS: Got historical price from CoinGecko for {}->{}: {}",
                        crypto_code, fiat_currency, price);
                    return Ok(Some(price));
                }
                Ok(None) => {
                    debug!("❌ Step 2 FAILED: CoinGecko historical data not available for {}", crypto_code);
                }
                Err(e) => {
                    warn!("❌ Step 2 FAILED: Failed to fetch historical price from CoinGecko: {}", e);
                }
            }
        } else {
            debug!("❌ Step 2 SKIPPED: No CoinGecko ID mapping for {}", crypto_code);
        }

        // 3️⃣ 所有方法都失败
        warn!("⚠️ All methods failed: No historical price available for {}->{} ({} days ago)",
            crypto_code, fiat_currency, days_ago);
        Ok(None)
    }

    /// 从 CoinGecko 获取历史价格
    async fn fetch_coingecko_historical_price(
        &self,
        coin_id: &str,
        fiat_currency: &str,
        days_ago: u32,
    ) -> Result<Option<Decimal>, ServiceError> {
        let url = format!(
            "https://api.coingecko.com/api/v3/coins/{}/market_chart?vs_currency={}&days={}",
            coin_id,
            fiat_currency.to_lowercase(),
            days_ago
        );

        let response = self.client
            .get(&url)
            .send()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to fetch historical data from CoinGecko: {}", e),
            })?;

        if !response.status().is_success() {
            warn!("CoinGecko historical API returned status: {}", response.status());
            return Ok(None);
        }

        #[derive(Debug, Deserialize)]
        struct MarketChartResponse {
            prices: Vec<Vec<f64>>, // [[timestamp_ms, price], ...]
        }

        let data: MarketChartResponse = response
            .json()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to parse CoinGecko historical response: {}", e),
            })?;

        // 获取第一个价格点（即 days_ago 天前的价格）
        if let Some(price_point) = data.prices.first() {
            if price_point.len() >= 2 {
                let price = price_point[1];
                return Ok(Some(Decimal::from_str(&price.to_string()).unwrap_or(Decimal::ZERO)));
            }
        }

        Ok(None)
    }

    // ============================================
    // 全球市场统计（新增）
    // ============================================

    /// 获取全球加密货币市场统计数据
    pub async fn fetch_global_market_stats(&mut self) -> Result<GlobalMarketStats, ServiceError> {
        // 检查缓存（5分钟有效期）
        if let Some((cached_stats, timestamp)) = &self.global_market_cache {
            if Utc::now() - *timestamp < Duration::minutes(5) {
                info!("Using cached global market stats (age: {} seconds)",
                    (Utc::now() - *timestamp).num_seconds());
                return Ok(cached_stats.clone());
            }
        }

        info!("Fetching fresh global market stats from CoinGecko");

        // 从 CoinGecko 获取全球市场数据
        let url = "https://api.coingecko.com/api/v3/global";

        let response = self.client
            .get(url)
            .send()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to fetch global market stats from CoinGecko: {}", e),
            })?;

        if !response.status().is_success() {
            return Err(ServiceError::ExternalApi {
                message: format!("CoinGecko global API returned status: {}", response.status()),
            });
        }

        let global_response: CoinGeckoGlobalResponse = response
            .json()
            .await
            .map_err(|e| ServiceError::ExternalApi {
                message: format!("Failed to parse CoinGecko global response: {}", e),
            })?;

        let stats = GlobalMarketStats::from(global_response.data);

        // 更新缓存
        self.global_market_cache = Some((stats.clone(), Utc::now()));

        info!("Successfully fetched global market stats: total_cap=${:.2}T, btc_dominance={:.2}%",
            stats.total_market_cap_usd.to_string().parse::<f64>().unwrap_or(0.0) / 1_000_000_000_000.0,
            stats.btc_dominance_percentage);

        Ok(stats)
    }

    // ============================================
    // 默认值和辅助方法
    // ============================================

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
                let rate = *usd_rate / base_to_usd;
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

impl Default for ExchangeRateApiService {
    fn default() -> Self { Self::new() }
}

// 单例模式的全局服务实例
use tokio::sync::Mutex;

lazy_static::lazy_static! {
    pub static ref EXCHANGE_RATE_SERVICE: Arc<Mutex<ExchangeRateApiService>> = Arc::new(Mutex::new(ExchangeRateApiService::new()));
}
