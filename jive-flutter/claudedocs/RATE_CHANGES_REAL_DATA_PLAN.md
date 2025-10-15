# 汇率/价格变化真实数据对接方案

**日期**: 2025-10-10 09:00
**架构**: 服务器端集成第三方API → Flutter客户端从服务器获取
**状态**: 📋 规划文档

---

## 🎯 架构设计

```
┌─────────────────┐
│  Flutter Client │
│  (jive-flutter) │
└────────┬────────┘
         │ GET /api/v1/currencies/rate-changes
         │ Authorization: Bearer <token>
         ▼
┌─────────────────┐
│  Rust Backend   │
│  (jive-api)     │
│  ┌───────────┐  │
│  │  Cache    │  │ ← 5分钟缓存
│  │  Layer    │  │
│  └─────┬─────┘  │
│        │        │
│  ┌─────▼─────┐  │
│  │ 3rd Party │  │
│  │ API Calls │  │
│  └───────────┘  │
└────────┬────────┘
         │
         ├─── CoinGecko API (加密货币)
         │    https://api.coingecko.com/api/v3/coins/{id}/market_chart
         │
         └─── ExchangeRate-API (法币)
              https://api.exchangerate-api.com/v4/latest/{base}
```

---

## 📊 第三方API选择

### 加密货币 - CoinGecko API

**官网**: https://www.coingecko.com/en/api

**优势**:
- ✅ 免费额度充足（50 calls/minute）
- ✅ 无需API密钥（基础功能）
- ✅ 数据全面（价格、市值、24h变化等）
- ✅ 支持历史数据
- ✅ 已在代码中使用

**关键端点**:
```bash
# 获取加密货币的24h/7d/30d价格变化
GET https://api.coingecko.com/api/v3/coins/{coin_id}/market_chart
  ?vs_currency=cny
  &days=30
  &interval=daily

# 返回示例
{
  "prices": [
    [1633046400000, 300.50],   # timestamp, price
    [1633132800000, 305.20],
    ...
  ]
}
```

### 法定货币 - ExchangeRate-API

**官网**: https://www.exchangerate-api.com/

**优势**:
- ✅ 免费额度: 1500 requests/month
- ✅ 无需注册（使用免费版）
- ✅ 支持历史汇率
- ✅ 简单易用

**关键端点**:
```bash
# 获取历史汇率
GET https://api.exchangerate-api.com/v4/history/{base}/{date}

# 示例: 获取CNY在2025-10-09的汇率
GET https://api.exchangerate-api.com/v4/history/CNY/2025-10-09

# 返回示例
{
  "base": "CNY",
  "date": "2025-10-09",
  "rates": {
    "JPY": 20.55,
    "USD": 0.14,
    "EUR": 0.13
  }
}
```

**替代方案**: Open Exchange Rates (更稳定但需API密钥)
- 官网: https://openexchangerates.org/
- 免费额度: 1000 requests/month
- 需要注册获取API密钥

---

## 🔧 后端实现方案

### 1. 数据结构定义

**文件**: `jive-api/src/models/rate_change.rs` (新建)

```rust
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RateChange {
    pub period: String,           // "24h", "7d", "30d"
    pub change_percent: f64,       // 变化百分比
    pub old_rate: Option<f64>,     // 旧汇率
    pub new_rate: Option<f64>,     // 新汇率
}

#[derive(Debug, Serialize, Deserialize)]
pub struct RateChangesResponse {
    pub from_currency: String,
    pub to_currency: String,
    pub is_crypto: bool,
    pub changes: Vec<RateChange>,
    pub last_updated: DateTime<Utc>,
}

#[derive(Debug, Clone)]
pub struct CachedRateChanges {
    pub data: RateChangesResponse,
    pub timestamp: DateTime<Utc>,
}

impl CachedRateChanges {
    pub fn is_expired(&self, cache_duration_minutes: i64) -> bool {
        let now = Utc::now();
        let elapsed = now.signed_duration_since(self.timestamp);
        elapsed.num_minutes() > cache_duration_minutes
    }
}
```

### 2. CoinGecko服务扩展

**文件**: `jive-api/src/services/coingecko_service.rs` (扩展现有)

```rust
use reqwest::Client;
use serde_json::Value;
use chrono::{DateTime, Utc, Duration};

pub struct CoinGeckoService {
    client: Client,
    base_url: String,
}

impl CoinGeckoService {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
            base_url: "https://api.coingecko.com/api/v3".to_string(),
        }
    }

    /// 获取加密货币的历史价格数据（用于计算变化）
    pub async fn get_market_chart(
        &self,
        coin_id: &str,
        vs_currency: &str,
        days: u32,
    ) -> Result<Vec<(DateTime<Utc>, f64)>, Box<dyn std::error::Error>> {
        let url = format!(
            "{}/coins/{}/market_chart",
            self.base_url, coin_id
        );

        let response = self.client
            .get(&url)
            .query(&[
                ("vs_currency", vs_currency),
                ("days", &days.to_string()),
                ("interval", "daily"),
            ])
            .send()
            .await?
            .json::<Value>()
            .await?;

        let prices = response["prices"]
            .as_array()
            .ok_or("Missing prices array")?;

        let mut result = Vec::new();
        for price_point in prices {
            let timestamp_ms = price_point[0].as_i64().unwrap();
            let price = price_point[1].as_f64().unwrap();

            let dt = DateTime::from_timestamp_millis(timestamp_ms)
                .ok_or("Invalid timestamp")?;

            result.push((dt, price));
        }

        Ok(result)
    }

    /// 计算加密货币的24h/7d/30d变化
    pub async fn get_price_changes(
        &self,
        coin_id: &str,
        vs_currency: &str,
    ) -> Result<Vec<RateChange>, Box<dyn std::error::Error>> {
        // 获取过去30天的数据
        let historical_prices = self.get_market_chart(coin_id, vs_currency, 30).await?;

        if historical_prices.is_empty() {
            return Err("No historical data available".into());
        }

        // 当前价格（最新）
        let current_price = historical_prices.last().unwrap().1;
        let now = Utc::now();

        // 查找24小时前、7天前、30天前的价格
        let price_24h_ago = self.find_price_at_offset(&historical_prices, now, 1);
        let price_7d_ago = self.find_price_at_offset(&historical_prices, now, 7);
        let price_30d_ago = self.find_price_at_offset(&historical_prices, now, 30);

        let mut changes = Vec::new();

        // 计算24h变化
        if let Some(old_price) = price_24h_ago {
            changes.push(RateChange {
                period: "24h".to_string(),
                change_percent: self.calculate_change_percent(old_price, current_price),
                old_rate: Some(old_price),
                new_rate: Some(current_price),
            });
        }

        // 计算7d变化
        if let Some(old_price) = price_7d_ago {
            changes.push(RateChange {
                period: "7d".to_string(),
                change_percent: self.calculate_change_percent(old_price, current_price),
                old_rate: Some(old_price),
                new_rate: Some(current_price),
            });
        }

        // 计算30d变化
        if let Some(old_price) = price_30d_ago {
            changes.push(RateChange {
                period: "30d".to_string(),
                change_percent: self.calculate_change_percent(old_price, current_price),
                old_rate: Some(old_price),
                new_rate: Some(current_price),
            });
        }

        Ok(changes)
    }

    fn find_price_at_offset(
        &self,
        prices: &[(DateTime<Utc>, f64)],
        now: DateTime<Utc>,
        days_ago: i64,
    ) -> Option<f64> {
        let target_date = now - Duration::days(days_ago);

        prices.iter()
            .min_by_key(|(dt, _)| {
                (*dt - target_date).num_seconds().abs()
            })
            .map(|(_, price)| *price)
    }

    fn calculate_change_percent(&self, old_price: f64, new_price: f64) -> f64 {
        if old_price == 0.0 {
            return 0.0;
        }
        ((new_price - old_price) / old_price) * 100.0
    }
}
```

### 3. ExchangeRate服务

**文件**: `jive-api/src/services/exchangerate_service.rs` (新建)

```rust
use reqwest::Client;
use serde::{Deserialize, Serialize};
use chrono::{DateTime, Utc, Duration, NaiveDate};
use std::collections::HashMap;

#[derive(Debug, Deserialize)]
struct ExchangeRateHistoryResponse {
    base: String,
    date: String,
    rates: HashMap<String, f64>,
}

pub struct ExchangeRateService {
    client: Client,
    base_url: String,
}

impl ExchangeRateService {
    pub fn new() -> Self {
        Self {
            client: Client::new(),
            base_url: "https://api.exchangerate-api.com/v4".to_string(),
        }
    }

    /// 获取指定日期的汇率
    async fn get_rates_at_date(
        &self,
        base: &str,
        date: NaiveDate,
    ) -> Result<HashMap<String, f64>, Box<dyn std::error::Error>> {
        let url = format!(
            "{}/history/{}/{}",
            self.base_url,
            base,
            date.format("%Y-%m-%d")
        );

        let response = self.client
            .get(&url)
            .send()
            .await?
            .json::<ExchangeRateHistoryResponse>()
            .await?;

        Ok(response.rates)
    }

    /// 计算法定货币的24h/7d/30d汇率变化
    pub async fn get_rate_changes(
        &self,
        from_currency: &str,
        to_currency: &str,
    ) -> Result<Vec<RateChange>, Box<dyn std::error::Error>> {
        let now = Utc::now().date_naive();

        // 获取不同时间点的汇率
        let rates_today = self.get_rates_at_date(from_currency, now).await?;
        let rates_1d_ago = self.get_rates_at_date(from_currency, now - Duration::days(1)).await?;
        let rates_7d_ago = self.get_rates_at_date(from_currency, now - Duration::days(7)).await?;
        let rates_30d_ago = self.get_rates_at_date(from_currency, now - Duration::days(30)).await?;

        let current_rate = rates_today.get(to_currency).copied()
            .ok_or("Currency not found in today's rates")?;

        let mut changes = Vec::new();

        // 24h变化
        if let Some(&old_rate) = rates_1d_ago.get(to_currency) {
            changes.push(RateChange {
                period: "24h".to_string(),
                change_percent: self.calculate_change_percent(old_rate, current_rate),
                old_rate: Some(old_rate),
                new_rate: Some(current_rate),
            });
        }

        // 7d变化
        if let Some(&old_rate) = rates_7d_ago.get(to_currency) {
            changes.push(RateChange {
                period: "7d".to_string(),
                change_percent: self.calculate_change_percent(old_rate, current_rate),
                old_rate: Some(old_rate),
                new_rate: Some(current_rate),
            });
        }

        // 30d变化
        if let Some(&old_rate) = rates_30d_ago.get(to_currency) {
            changes.push(RateChange {
                period: "30d".to_string(),
                change_percent: self.calculate_change_percent(old_rate, current_rate),
                old_rate: Some(old_rate),
                new_rate: Some(current_rate),
            });
        }

        Ok(changes)
    }

    fn calculate_change_percent(&self, old_rate: f64, new_rate: f64) -> f64 {
        if old_rate == 0.0 {
            return 0.0;
        }
        ((new_rate - old_rate) / old_rate) * 100.0
    }
}
```

### 4. 统一服务层

**文件**: `jive-api/src/services/rate_change_service.rs` (新建)

```rust
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use chrono::{DateTime, Utc};

use super::coingecko_service::CoinGeckoService;
use super::exchangerate_service::ExchangeRateService;
use crate::models::rate_change::{RateChange, RateChangesResponse, CachedRateChanges};

pub struct RateChangeService {
    coingecko: CoinGeckoService,
    exchangerate: ExchangeRateService,
    cache: Arc<RwLock<HashMap<String, CachedRateChanges>>>,
    cache_duration_minutes: i64,
}

impl RateChangeService {
    pub fn new() -> Self {
        Self {
            coingecko: CoinGeckoService::new(),
            exchangerate: ExchangeRateService::new(),
            cache: Arc::new(RwLock::new(HashMap::new())),
            cache_duration_minutes: 5, // 5分钟缓存
        }
    }

    /// 获取汇率/价格变化（带缓存）
    pub async fn get_rate_changes(
        &self,
        from_currency: &str,
        to_currency: &str,
        is_crypto: bool,
    ) -> Result<RateChangesResponse, Box<dyn std::error::Error>> {
        let cache_key = format!("{}_{}", from_currency, to_currency);

        // 检查缓存
        {
            let cache_read = self.cache.read().await;
            if let Some(cached) = cache_read.get(&cache_key) {
                if !cached.is_expired(self.cache_duration_minutes) {
                    return Ok(cached.data.clone());
                }
            }
        }

        // 缓存未命中或已过期，获取新数据
        let changes = if is_crypto {
            // 从CoinGecko获取加密货币价格变化
            let coin_id = self.get_coingecko_id(from_currency)?;
            self.coingecko.get_price_changes(&coin_id, to_currency).await?
        } else {
            // 从ExchangeRate-API获取法币汇率变化
            self.exchangerate.get_rate_changes(from_currency, to_currency).await?
        };

        let response = RateChangesResponse {
            from_currency: from_currency.to_string(),
            to_currency: to_currency.to_string(),
            is_crypto,
            changes,
            last_updated: Utc::now(),
        };

        // 更新缓存
        {
            let mut cache_write = self.cache.write().await;
            cache_write.insert(
                cache_key,
                CachedRateChanges {
                    data: response.clone(),
                    timestamp: Utc::now(),
                },
            );
        }

        Ok(response)
    }

    fn get_coingecko_id(&self, currency_code: &str) -> Result<String, Box<dyn std::error::Error>> {
        // 使用现有的CoinGecko ID映射
        let mapping: HashMap<&str, &str> = [
            ("BTC", "bitcoin"),
            ("ETH", "ethereum"),
            ("BNB", "binancecoin"),
            ("1INCH", "1inch"),
            ("AAVE", "aave"),
            ("AGIX", "singularitynet"),
            // ... 其他映射
        ].iter().cloned().collect();

        mapping.get(currency_code)
            .map(|s| s.to_string())
            .ok_or_else(|| format!("Unknown crypto currency: {}", currency_code).into())
    }
}
```

### 5. API Handler

**文件**: `jive-api/src/handlers/rate_change_handler.rs` (新建)

```rust
use axum::{
    extract::{Query, State},
    Json,
};
use serde::Deserialize;
use std::sync::Arc;

use crate::services::rate_change_service::RateChangeService;
use crate::models::rate_change::RateChangesResponse;
use crate::error::AppError;

#[derive(Debug, Deserialize)]
pub struct RateChangeQuery {
    from_currency: String,
    to_currency: String,
    #[serde(default)]
    is_crypto: bool,
}

pub async fn get_rate_changes(
    State(service): State<Arc<RateChangeService>>,
    Query(params): Query<RateChangeQuery>,
) -> Result<Json<RateChangesResponse>, AppError> {
    let changes = service
        .get_rate_changes(
            &params.from_currency,
            &params.to_currency,
            params.is_crypto,
        )
        .await
        .map_err(|e| AppError::InternalServerError(e.to_string()))?;

    Ok(Json(changes))
}
```

### 6. 路由注册

**文件**: `jive-api/src/routes/currency_routes.rs` (扩展现有)

```rust
use axum::{
    routing::get,
    Router,
};
use std::sync::Arc;

use crate::handlers::rate_change_handler;
use crate::services::rate_change_service::RateChangeService;

pub fn currency_routes(rate_change_service: Arc<RateChangeService>) -> Router {
    Router::new()
        // ... 现有路由 ...
        .route(
            "/currencies/rate-changes",
            get(rate_change_handler::get_rate_changes)
        )
        .with_state(rate_change_service)
}
```

---

## 📱 Flutter前端实现

### 1. API服务扩展

**文件**: `lib/services/currency_service.dart` (扩展现有)

```dart
import 'package:dio/dio.dart';
import 'package:jive_money/utils/constants.dart';

class RateChange {
  final String period;
  final double changePercent;
  final double? oldRate;
  final double? newRate;

  RateChange({
    required this.period,
    required this.changePercent,
    this.oldRate,
    this.newRate,
  });

  factory RateChange.fromJson(Map<String, dynamic> json) {
    return RateChange(
      period: json['period'] as String,
      changePercent: (json['change_percent'] as num).toDouble(),
      oldRate: json['old_rate'] != null ? (json['old_rate'] as num).toDouble() : null,
      newRate: json['new_rate'] != null ? (json['new_rate'] as num).toDouble() : null,
    );
  }

  String get formattedPercent {
    final sign = changePercent >= 0 ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }

  Color get color => changePercent >= 0 ? Colors.green : Colors.red;
}

class RateChangesResponse {
  final String fromCurrency;
  final String toCurrency;
  final bool isCrypto;
  final List<RateChange> changes;
  final DateTime lastUpdated;

  RateChangesResponse({
    required this.fromCurrency,
    required this.toCurrency,
    required this.isCrypto,
    required this.changes,
    required this.lastUpdated,
  });

  factory RateChangesResponse.fromJson(Map<String, dynamic> json) {
    return RateChangesResponse(
      fromCurrency: json['from_currency'] as String,
      toCurrency: json['to_currency'] as String,
      isCrypto: json['is_crypto'] as bool,
      changes: (json['changes'] as List)
          .map((c) => RateChange.fromJson(c as Map<String, dynamic>))
          .toList(),
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  RateChange? getChange(String period) {
    return changes.firstWhere(
      (c) => c.period == period,
      orElse: () => RateChange(period: period, changePercent: 0),
    );
  }
}

class CurrencyService {
  final Dio _dio;

  // 缓存，5分钟有效期
  final Map<String, _CachedRateChanges> _rateChangesCache = {};
  static const _cacheDuration = Duration(minutes: 5);

  CurrencyService(this._dio);

  /// 获取汇率/价格变化
  Future<RateChangesResponse?> getRateChanges({
    required String fromCurrency,
    required String toCurrency,
    required bool isCrypto,
  }) async {
    final cacheKey = '${fromCurrency}_$toCurrency';

    // 检查缓存
    if (_rateChangesCache.containsKey(cacheKey)) {
      final cached = _rateChangesCache[cacheKey]!;
      if (!cached.isExpired) {
        return cached.data;
      }
    }

    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}/currencies/rate-changes',
        queryParameters: {
          'from_currency': fromCurrency,
          'to_currency': toCurrency,
          'is_crypto': isCrypto,
        },
      );

      if (response.statusCode == 200) {
        final data = RateChangesResponse.fromJson(response.data);

        // 更新缓存
        _rateChangesCache[cacheKey] = _CachedRateChanges(
          data: data,
          timestamp: DateTime.now(),
        );

        return data;
      }
    } catch (e) {
      debugPrint('Error fetching rate changes: $e');
    }

    return null;
  }

  /// 批量获取多个货币的变化
  Future<Map<String, RateChangesResponse>> getRateChangesForCurrencies({
    required String baseCurrency,
    required List<String> currencyCodes,
    required bool isCrypto,
  }) async {
    final Map<String, RateChangesResponse> results = {};

    // 并行请求所有货币的变化数据
    final futures = currencyCodes.map((code) =>
      getRateChanges(
        fromCurrency: baseCurrency,
        toCurrency: code,
        isCrypto: isCrypto,
      )
    );

    final responses = await Future.wait(futures);

    for (int i = 0; i < currencyCodes.length; i++) {
      final response = responses[i];
      if (response != null) {
        results[currencyCodes[i]] = response;
      }
    }

    return results;
  }
}

class _CachedRateChanges {
  final RateChangesResponse data;
  final DateTime timestamp;

  _CachedRateChanges({
    required this.data,
    required this.timestamp,
  });

  bool get isExpired {
    return DateTime.now().difference(timestamp) > CurrencyService._cacheDuration;
  }
}
```

### 2. 更新法定货币页面

**文件**: `lib/screens/management/currency_selection_page.dart`

```dart
// 添加状态变量
class _CurrencySelectionPageState extends ConsumerState<CurrencySelectionPage> {
  // ... 现有变量 ...

  // 新增：汇率变化数据缓存
  final Map<String, RateChangesResponse> _rateChanges = {};
  bool _isLoadingChanges = false;

  @override
  void initState() {
    super.initState();
    // ... 现有初始化 ...

    // 加载汇率变化数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchRateChanges();
    });
  }

  Future<void> _fetchRateChanges() async {
    if (!mounted) return;
    setState(() {
      _isLoadingChanges = true;
    });

    try {
      final baseCurrency = ref.read(baseCurrencyProvider).code;
      final selectedCurrencies = ref.read(selectedCurrenciesProvider)
          .where((c) => !c.isCrypto)
          .map((c) => c.code)
          .toList();

      final currencyService = CurrencyService(Dio());
      final changes = await currencyService.getRateChangesForCurrencies(
        baseCurrency: baseCurrency,
        currencyCodes: selectedCurrencies,
        isCrypto: false,
      );

      if (mounted) {
        setState(() {
          _rateChanges.addAll(changes);
        });
      }
    } catch (e) {
      debugPrint('Error fetching rate changes: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingChanges = false;
        });
      }
    }
  }

  // 修改_buildCurrencyTile中的汇率变化显示
  Widget _buildCurrencyTile(model.Currency currency) {
    // ... 前面的代码不变 ...

    children: isSelected && !widget.isSelectingBaseCurrency
      ? [
          Container(
            padding: EdgeInsets.all(dense ? 12 : 16),
            child: Column(
              children: [
                // ... 汇率设置部分 ...

                const SizedBox(height: 12),
                // 汇率变化趋势（真实数据）
                _buildRateChangesContainer(currency, cs),
              ],
            ),
          ),
        ]
      : [],
  }

  Widget _buildRateChangesContainer(model.Currency currency, ColorScheme cs) {
    final rateChanges = _rateChanges[currency.code];

    if (rateChanges == null) {
      // 数据加载中或加载失败
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
        ),
        child: _isLoadingChanges
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '加载汇率变化...',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              )
            : Text(
                '暂无汇率变化数据',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
      );
    }

    // 显示真实数据
    final change24h = rateChanges.getChange('24h');
    final change7d = rateChanges.getChange('7d');
    final change30d = rateChanges.getChange('30d');

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          if (change24h != null)
            _buildRateChange(cs, '24h', change24h.formattedPercent, change24h.color),
          if (change7d != null)
            _buildRateChange(cs, '7d', change7d.formattedPercent, change7d.color),
          if (change30d != null)
            _buildRateChange(cs, '30d', change30d.formattedPercent, change30d.color),
        ],
      ),
    );
  }
}
```

### 3. 更新加密货币页面

**文件**: `lib/screens/management/crypto_selection_page.dart`

类似的改造，使用 `isCrypto: true` 调用API。

---

## 📋 实施步骤

### Phase 1: 后端基础 (2-3天)

1. **Day 1: 数据模型和服务层**
   - [ ] 创建 `models/rate_change.rs`
   - [ ] 创建 `services/exchangerate_service.rs`
   - [ ] 扩展 `services/coingecko_service.rs`
   - [ ] 创建 `services/rate_change_service.rs`
   - [ ] 添加单元测试

2. **Day 2: API Handler和路由**
   - [ ] 创建 `handlers/rate_change_handler.rs`
   - [ ] 注册新路由到 `currency_routes.rs`
   - [ ] 添加错误处理
   - [ ] 手动测试API端点

3. **Day 3: 缓存优化和测试**
   - [ ] 实现5分钟缓存机制
   - [ ] 添加集成测试
   - [ ] 性能测试（模拟并发请求）
   - [ ] 文档更新

### Phase 2: 前端对接 (1-2天)

4. **Day 4: Flutter服务层**
   - [ ] 扩展 `CurrencyService` 添加汇率变化API
   - [ ] 实现前端缓存机制
   - [ ] 添加单元测试

5. **Day 5: UI集成**
   - [ ] 更新 `currency_selection_page.dart`
   - [ ] 更新 `crypto_selection_page.dart`
   - [ ] 添加加载状态和错误处理
   - [ ] UI测试

### Phase 3: 测试和优化 (1天)

6. **Day 6: 端到端测试**
   - [ ] 功能测试
   - [ ] 跨主题测试
   - [ ] 网络失败场景测试
   - [ ] 性能优化

---

## 🧪 测试计划

### 后端测试

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_get_crypto_rate_changes() {
        let service = RateChangeService::new();
        let result = service.get_rate_changes("BTC", "CNY", true).await;

        assert!(result.is_ok());
        let response = result.unwrap();
        assert_eq!(response.from_currency, "BTC");
        assert_eq!(response.to_currency, "CNY");
        assert!(response.is_crypto);
        assert_eq!(response.changes.len(), 3); // 24h, 7d, 30d
    }

    #[tokio::test]
    async fn test_get_fiat_rate_changes() {
        let service = RateChangeService::new();
        let result = service.get_rate_changes("CNY", "JPY", false).await;

        assert!(result.is_ok());
        let response = result.unwrap();
        assert_eq!(response.from_currency, "CNY");
        assert_eq!(response.to_currency, "JPY");
        assert!(!response.is_crypto);
    }
}
```

### 前端测试

```dart
void main() {
  testWidgets('Rate changes display test', (WidgetTester tester) async {
    // Mock API响应
    final mockDio = MockDio();
    when(mockDio.get(any, queryParameters: anyNamed('queryParameters')))
        .thenAnswer((_) async => Response(
              data: {
                'from_currency': 'CNY',
                'to_currency': 'JPY',
                'is_crypto': false,
                'changes': [
                  {'period': '24h', 'change_percent': 1.25},
                  {'period': '7d', 'change_percent': -0.82},
                  {'period': '30d', 'change_percent': 3.15},
                ],
                'last_updated': DateTime.now().toIso8601String(),
              },
              statusCode: 200,
              requestOptions: RequestOptions(path: ''),
            ));

    // 渲染页面
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: CurrencySelectionPage(),
        ),
      ),
    );

    // 等待数据加载
    await tester.pumpAndSettle();

    // 验证显示
    expect(find.text('+1.25%'), findsOneWidget);
    expect(find.text('-0.82%'), findsOneWidget);
    expect(find.text('+3.15%'), findsOneWidget);
  });
}
```

---

## 💰 成本估算

### 第三方API费用

**CoinGecko**:
- 免费版: 50 calls/minute
- Pro版: $129/month (500 calls/minute)
- **预估**: 免费版足够（用户量<1000）

**ExchangeRate-API**:
- 免费版: 1500 requests/month
- Basic: $9/month (100,000 requests/month)
- **预估**: 如果用户量<50，免费版足够

**总成本**: $0/month (初期) → $9-20/month (用户量增长后)

---

## 🚀 优化建议

### 1. 智能缓存策略

```rust
// 不同数据的缓存时长
- 加密货币价格变化: 5分钟 (波动快)
- 法币汇率变化: 1小时 (波动慢)
- 历史数据: 24小时 (不变)
```

### 2. 批量请求优化

```rust
// 一次请求获取多个货币的变化
GET /currencies/rate-changes/batch
Body: {
  "base_currency": "CNY",
  "target_currencies": ["JPY", "USD", "EUR"],
  "is_crypto": false
}
```

### 3. WebSocket实时更新（长期）

```
对于活跃用户，使用WebSocket推送实时变化，
减少轮询请求，提升用户体验。
```

---

## 📚 参考资料

- **CoinGecko API文档**: https://www.coingecko.com/en/api/documentation
- **ExchangeRate-API文档**: https://www.exchangerate-api.com/docs
- **Rust async编程**: https://rust-lang.github.io/async-book/
- **Flutter Dio文档**: https://pub.dev/packages/dio

---

**文档版本**: 1.0
**最后更新**: 2025-10-10 09:00
**状态**: 📋 规划完成，等待实施确认
