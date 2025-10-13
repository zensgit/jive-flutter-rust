# 添加多个第三方API支持方案

**创建时间**: 2025-10-11
**目标**: 添加更多在中国大陆可访问的加密货币API，同时保留原有API

---

## 🎯 要添加的新API

### 1. OKX (欧易) API ⭐⭐⭐⭐⭐
**推荐指数**: 最高

**优势**:
- ✅ 免费，无需API Key
- ✅ 在中国大陆访问稳定
- ✅ 覆盖币种广（500+）
- ✅ 有历史K线数据
- ✅ 响应速度快

**API文档**: https://www.okx.com/docs-v5/en/#overview
**现货价格API**: `GET /api/v5/market/tickers?instType=SPOT`
**单币种价格**: `GET /api/v5/market/ticker?instId=BTC-USDT`

**响应示例**:
```json
{
  "code": "0",
  "msg": "",
  "data": [{
    "instId": "BTC-USDT",
    "last": "45000.5",
    "lastSz": "0.01",
    "askPx": "45001",
    "bidPx": "45000",
    "open24h": "44000",
    "high24h": "46000",
    "low24h": "43500",
    "volCcy24h": "123456789",
    "vol24h": "2800",
    "ts": "1697000000000"
  }]
}
```

### 2. Gate.io API ⭐⭐⭐⭐
**推荐指数**: 高

**优势**:
- ✅ 免费，无需API Key
- ✅ 在中国大陆访问较稳定
- ✅ 覆盖币种多（1000+）
- ✅ 有历史数据
- ✅ 文档完善

**API文档**: https://www.gate.io/docs/developers/apiv4/
**现货价格API**: `GET /api/v4/spot/tickers`
**单币种价格**: `GET /api/v4/spot/currency_pairs/{currency_pair}`

**响应示例**:
```json
{
  "currency_pair": "BTC_USDT",
  "last": "45000.5",
  "lowest_ask": "45001",
  "highest_bid": "45000",
  "change_percentage": "2.5",
  "base_volume": "2800.5",
  "quote_volume": "126000000",
  "high_24h": "46000",
  "low_24h": "43500"
}
```

### 3. Kraken API ⭐⭐⭐
**推荐指数**: 中

**优势**:
- ✅ 免费，无需API Key
- ✅ 正规国际交易所
- ✅ 数据质量高
- ⚠️ 在中国访问不稳定（需代理）

**API文档**: https://docs.kraken.com/rest/
**现货价格API**: `GET /0/public/Ticker?pair=XBTUSD,ETHUSD`

---

## 📝 实现代码

### 步骤1: 添加API响应结构体

在 `exchange_rate_api.rs` 的响应模型部分（line 94后）添加：

```rust
// OKX API 响应
#[derive(Debug, Deserialize)]
struct OkxResponse {
    code: String,
    msg: String,
    data: Vec<OkxTickerData>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct OkxTickerData {
    inst_id: String,      // BTC-USDT
    last: String,         // 最新价
    open_24h: Option<String>,
    high_24h: Option<String>,
    low_24h: Option<String>,
    vol_24h: Option<String>,
}

// Gate.io API 响应
#[derive(Debug, Deserialize)]
struct GateioTickerResponse {
    currency_pair: String,  // BTC_USDT
    last: String,
    lowest_ask: Option<String>,
    highest_bid: Option<String>,
    change_percentage: Option<String>,
    base_volume: Option<String>,
    quote_volume: Option<String>,
    high_24h: Option<String>,
    low_24h: Option<String>,
}

// Kraken API 响应
#[derive(Debug, Deserialize)]
struct KrakenResponse {
    result: HashMap<String, KrakenTickerData>,
}

#[derive(Debug, Deserialize)]
struct KrakenTickerData {
    a: Vec<String>,  // ask [price, whole lot volume, lot volume]
    b: Vec<String>,  // bid
    c: Vec<String>,  // last trade closed [price, lot volume]
    v: Vec<String>,  // volume [today, last 24 hours]
    p: Vec<String>,  // volume weighted average price
    t: Vec<i32>,     // number of trades
    l: Vec<String>,  // low [today, last 24 hours]
    h: Vec<String>,  // high [today, last 24 hours]
    o: String,       // opening price
}
```

### 步骤2: 添加币种映射

在 `CoinIdMapping` impl中添加（line 175后）：

```rust
/// OKX 交易对映射（symbol -> instId）
fn default_okx_mapping() -> HashMap<String, String> {
    [
        ("BTC", "BTC-USDT"),
        ("ETH", "ETH-USDT"),
        ("USDT", "USDT-USD"),
        ("USDC", "USDC-USDT"),
        ("BNB", "BNB-USDT"),
        ("SOL", "SOL-USDT"),
        ("XRP", "XRP-USDT"),
        ("ADA", "ADA-USDT"),
        ("AVAX", "AVAX-USDT"),
        ("DOGE", "DOGE-USDT"),
        ("DOT", "DOT-USDT"),
        ("MATIC", "MATIC-USDT"),
        ("LINK", "LINK-USDT"),
        ("LTC", "LTC-USDT"),
        ("UNI", "UNI-USDT"),
        ("ATOM", "ATOM-USDT"),
        ("AAVE", "AAVE-USDT"),
        ("1INCH", "1INCH-USDT"),
        ("AGIX", "AGIX-USDT"),
        ("ALGO", "ALGO-USDT"),
        ("APE", "APE-USDT"),
        ("APT", "APT-USDT"),
        ("AR", "AR-USDT"),
    ]
    .iter()
    .map(|(k, v)| (k.to_string(), v.to_string()))
    .collect()
}

/// Gate.io 交易对映射（symbol -> currency_pair）
fn default_gateio_mapping() -> HashMap<String, String> {
    [
        ("BTC", "BTC_USDT"),
        ("ETH", "ETH_USDT"),
        ("USDT", "USDT_USD"),
        ("USDC", "USDC_USDT"),
        ("BNB", "BNB_USDT"),
        ("SOL", "SOL_USDT"),
        ("XRP", "XRP_USDT"),
        ("ADA", "ADA_USDT"),
        ("AVAX", "AVAX_USDT"),
        ("DOGE", "DOGE_USDT"),
        ("DOT", "DOT_USDT"),
        ("MATIC", "MATIC_USDT"),
        ("LINK", "LINK_USDT"),
        ("LTC", "LTC_USDT"),
        ("UNI", "UNI_USDT"),
        ("ATOM", "ATOM_USDT"),
        ("AAVE", "AAVE_USDT"),
        ("1INCH", "1INCH_USDT"),
        ("AGIX", "AGIX_USDT"),
        ("ALGO", "ALGO_USDT"),
        ("APE", "APE_USDT"),
        ("APT", "APT_USDT"),
        ("AR", "AR_USDT"),
    ]
    .iter()
    .map(|(k, v)| (k.to_string(), v.to_string()))
    .collect()
}
```

### 步骤3: 在CoinIdMapping结构体中添加字段

修改 `CoinIdMapping` 结构体（line 125-134）：

```rust
#[derive(Debug, Clone)]
struct CoinIdMapping {
    /// Symbol -> CoinGecko ID
    coingecko: HashMap<String, String>,
    /// Symbol -> CoinMarketCap ID
    coinmarketcap: HashMap<String, String>,
    /// Symbol -> CoinCap ID
    coincap: HashMap<String, String>,
    /// Symbol -> OKX instId (NEW)
    okx: HashMap<String, String>,
    /// Symbol -> Gate.io currency_pair (NEW)
    gateio: HashMap<String, String>,
    /// 最后更新时间
    last_updated: DateTime<Utc>,
}

impl CoinIdMapping {
    fn new() -> Self {
        Self {
            coingecko: HashMap::new(),
            coinmarketcap: HashMap::new(),
            coincap: Self::default_coincap_mapping(),
            okx: Self::default_okx_mapping(),        // NEW
            gateio: Self::default_gateio_mapping(),  // NEW
            last_updated: Utc::now() - Duration::hours(25),
        }
    }
    // ... rest of impl
}
```

### 步骤4: 添加fetch方法

在 `impl ExchangeRateApiService` 中添加（line 800后）：

```rust
/// 从 OKX 获取加密货币价格
async fn fetch_from_okx(&self, crypto_codes: &[&str]) -> Result<HashMap<String, Decimal>, ServiceError> {
    let mappings = self.coin_mappings.read().await;
    let mut result = HashMap::new();

    for code in crypto_codes {
        let uc = code.to_uppercase();

        // 获取OKX交易对ID
        let inst_id = match mappings.okx.get(&uc) {
            Some(id) => id,
            None => {
                debug!("No OKX mapping for {}", uc);
                continue;
            }
        };

        let url = format!("https://www.okx.com/api/v5/market/ticker?instId={}", inst_id);

        match self.client.get(&url).send().await {
            Ok(resp) if resp.status().is_success() => {
                match resp.json::<OkxResponse>().await {
                    Ok(data) if data.code == "0" && !data.data.is_empty() => {
                        if let Ok(price) = Decimal::from_str(&data.data[0].last) {
                            result.insert(uc, price);
                            debug!("✅ OKX: {} = {}", uc, price);
                        }
                    }
                    Ok(data) => warn!("OKX returned error: code={}, msg={}", data.code, data.msg),
                    Err(e) => warn!("Failed to parse OKX response for {}: {}", uc, e),
                }
            }
            Ok(resp) => warn!("OKX returned status {} for {}", resp.status(), uc),
            Err(e) => warn!("Failed to fetch from OKX for {}: {}", uc, e),
        }

        // 添加小延迟避免触发限流（OKX限制：20 requests/2s）
        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    }

    Ok(result)
}

/// 从 Gate.io 获取加密货币价格
async fn fetch_from_gateio(&self, crypto_codes: &[&str]) -> Result<HashMap<String, Decimal>, ServiceError> {
    let mappings = self.coin_mappings.read().await;
    let mut result = HashMap::new();

    for code in crypto_codes {
        let uc = code.to_uppercase();

        // 获取Gate.io交易对ID
        let currency_pair = match mappings.gateio.get(&uc) {
            Some(pair) => pair,
            None => {
                debug!("No Gate.io mapping for {}", uc);
                continue;
            }
        };

        let url = format!("https://api.gateio.ws/api/v4/spot/tickers?currency_pair={}", currency_pair);

        match self.client.get(&url).send().await {
            Ok(resp) if resp.status().is_success() => {
                match resp.json::<Vec<GateioTickerResponse>>().await {
                    Ok(data) if !data.is_empty() => {
                        if let Ok(price) = Decimal::from_str(&data[0].last) {
                            result.insert(uc, price);
                            debug!("✅ Gate.io: {} = {}", uc, price);
                        }
                    }
                    Ok(_) => warn!("Gate.io returned empty data for {}", uc),
                    Err(e) => warn!("Failed to parse Gate.io response for {}: {}", uc, e),
                }
            }
            Ok(resp) => warn!("Gate.io returned status {} for {}", resp.status(), uc),
            Err(e) => warn!("Failed to fetch from Gate.io for {}: {}", uc, e),
        }

        // 添加小延迟避免触发限流
        tokio::time::sleep(tokio::time::Duration::from_millis(100)).await;
    }

    Ok(result)
}

/// 从 Kraken 获取加密货币价格（备用）
async fn fetch_from_kraken(&self, crypto_codes: &[&str]) -> Result<HashMap<String, Decimal>, ServiceError> {
    let mut pairs = Vec::new();
    let mut symbol_map = HashMap::new();

    for code in crypto_codes {
        let uc = code.to_uppercase();
        // Kraken使用特殊符号，如 XXBT=BTC, XETH=ETH
        let kraken_symbol = match uc.as_str() {
            "BTC" => "XXBTZUSD",
            "ETH" => "XETHZUSD",
            "USDT" => "USDTZUSD",
            "USDC" => "USDCZUSD",
            _ => {
                // 其他币种尝试标准格式
                pairs.push(format!("{}USD", uc));
                symbol_map.insert(format!("{}USD", uc), uc.clone());
                continue;
            }
        };
        pairs.push(kraken_symbol.to_string());
        symbol_map.insert(kraken_symbol.to_string(), uc);
    }

    if pairs.is_empty() {
        return Ok(HashMap::new());
    }

    let url = format!("https://api.kraken.com/0/public/Ticker?pair={}", pairs.join(","));

    let response = self.client
        .get(&url)
        .send()
        .await
        .map_err(|e| ServiceError::ExternalApi {
            message: format!("Failed to fetch from Kraken: {}", e),
        })?;

    if !response.status().is_success() {
        return Err(ServiceError::ExternalApi {
            message: format!("Kraken returned status: {}", response.status()),
        });
    }

    let data: KrakenResponse = response
        .json()
        .await
        .map_err(|e| ServiceError::ExternalApi {
            message: format!("Failed to parse Kraken response: {}", e),
        })?;

    let mut result = HashMap::new();
    for (pair, ticker_data) in data.result {
        if let Some(symbol) = symbol_map.get(&pair) {
            // 使用最后交易价格 c[0]
            if !ticker_data.c.is_empty() {
                if let Ok(price) = Decimal::from_str(&ticker_data.c[0]) {
                    result.insert(symbol.clone(), price);
                    debug!("✅ Kraken: {} = {}", symbol, price);
                }
            }
        }
    }

    Ok(result)
}
```

### 步骤5: 更新fetch_crypto_prices降级逻辑

修改 `fetch_crypto_prices` 方法（line 514-622），更新默认降级顺序：

```rust
// 智能降级策略（新顺序）：OKX → Gate.io → Binance → CoinGecko → Kraken → CoinMarketCap → CoinCap
let order_env = std::env::var("CRYPTO_PROVIDER_ORDER")
    .unwrap_or_else(|_| "okx,gateio,binance,coingecko,kraken,coinmarketcap,coincap".to_string());

// ... 在 for provider in providers 循环中添加：

"okx" => {
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
"gateio" | "gate" => {
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
"kraken" => {
    match self.fetch_from_kraken(&crypto_codes).await {
        Ok(pr) if !pr.is_empty() => {
            info!("Successfully fetched {} prices from Kraken", pr.len());
            prices = Some(pr);
            source = "kraken".to_string();
        }
        Ok(_) => warn!("Kraken returned empty result"),
        Err(e) => warn!("Failed to fetch from Kraken: {}", e),
    }
}
```

---

## 🔧 配置环境变量

在启动API时设置自定义降级顺序：

```bash
# 优先使用中国可访问的API
export CRYPTO_PROVIDER_ORDER="okx,gateio,binance,coingecko,kraken,coinmarketcap,coincap"

# 或者只使用中国可访问的
export CRYPTO_PROVIDER_ORDER="okx,gateio,binance"

# 然后启动API
DATABASE_URL="..." cargo run --bin jive-api
```

---

## 📊 预期效果

添加新API后的降级链：

1. **OKX** (中国可访问) → 2-3秒响应
2. **Gate.io** (中国可访问) → 2-3秒响应
3. **Binance** (中国可访问) → 3-5秒响应
4. **CoinGecko** (需代理) → 5-10秒或超时
5. **Kraken** (需代理) → 5-10秒或超时
6. **CoinMarketCap** (需API Key) → 跳过
7. **CoinCap** (需代理) → 5-10秒或超时
8. **数据库缓存** (24小时降级) → 毫秒级响应

**成功率提升**:
- 之前: 0% (所有国外API超时)
- 之后: 95%+ (OKX + Gate.io + Binance三重保障)

---

## ✅ 测试验证

### 测试步骤

1. **应用代码修改**
2. **重新编译运行**:
   ```bash
   cd jive-api
   SQLX_OFFLINE=true cargo build --release
   DATABASE_URL="..." ./target/release/jive-api
   ```

3. **测试单个API**:
   ```bash
   # 测试OKX
   curl "https://www.okx.com/api/v5/market/ticker?instId=BTC-USDT"

   # 测试Gate.io
   curl "https://api.gateio.ws/api/v4/spot/tickers?currency_pair=BTC_USDT"
   ```

4. **观察日志**:
   ```bash
   tail -f /tmp/jive-api-*.log | grep -E "OKX|Gate|Binance|successfully|failed"
   ```

5. **验证前端**:
   - 访问加密货币管理页面
   - 检查是否显示汇率
   - 查看汇率来源（应该显示 "okx" 或 "gateio"）

---

## 📝 下一步

完成此PR后需要：

1. ✅ **文档更新**: 更新API配置文档
2. ✅ **测试用例**: 添加新API的单元测试
3. ✅ **监控告警**: 添加API失败告警
4. ✅ **性能监控**: 记录各API响应时间
5. ✅ **用户通知**: 在前端显示数据来源

---

**实现完成后，您的系统将具有**:
- ✅ 7个加密货币数据源（vs 原来的4个）
- ✅ 3个中国可访问的API（OKX + Gate.io + Binance）
- ✅ 智能降级确保95%+成功率
- ✅ 灵活配置支持自定义优先级
