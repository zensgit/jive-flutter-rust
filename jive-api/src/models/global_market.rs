use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};

/// 全球加密货币市场统计数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GlobalMarketStats {
    /// 总市值 (USD)
    pub total_market_cap_usd: Decimal,

    /// 24小时总交易量 (USD)
    pub total_volume_24h_usd: Decimal,

    /// BTC市值占比 (百分比，例如 48.5 表示 48.5%)
    pub btc_dominance_percentage: Decimal,

    /// ETH市值占比 (百分比)
    #[serde(skip_serializing_if = "Option::is_none")]
    pub eth_dominance_percentage: Option<Decimal>,

    /// 活跃加密货币数量
    pub active_cryptocurrencies: i32,

    /// 活跃交易市场数量
    #[serde(skip_serializing_if = "Option::is_none")]
    pub markets: Option<i32>,

    /// 数据最后更新时间戳 (Unix timestamp)
    pub updated_at: i64,
}

/// CoinGecko Global API 响应结构
#[derive(Debug, Deserialize)]
pub struct CoinGeckoGlobalResponse {
    pub data: CoinGeckoGlobalData,
}

#[derive(Debug, Deserialize)]
pub struct CoinGeckoGlobalData {
    /// 所有币种市值
    pub total_market_cap: std::collections::HashMap<String, f64>,

    /// 24h交易量
    pub total_volume: std::collections::HashMap<String, f64>,

    /// 市值占比百分比
    pub market_cap_percentage: std::collections::HashMap<String, f64>,

    /// 活跃加密货币数量
    pub active_cryptocurrencies: i32,

    /// 市场数量
    pub markets: i32,

    /// 最后更新时间
    pub updated_at: i64,
}

impl From<CoinGeckoGlobalData> for GlobalMarketStats {
    fn from(data: CoinGeckoGlobalData) -> Self {
        use rust_decimal::prelude::FromPrimitive;

        let total_market_cap_usd = data
            .total_market_cap
            .get("usd")
            .and_then(|v| Decimal::from_f64(*v))
            .unwrap_or(Decimal::ZERO);

        let total_volume_24h_usd = data
            .total_volume
            .get("usd")
            .and_then(|v| Decimal::from_f64(*v))
            .unwrap_or(Decimal::ZERO);

        let btc_dominance_percentage = data
            .market_cap_percentage
            .get("btc")
            .and_then(|v| Decimal::from_f64(*v))
            .unwrap_or(Decimal::ZERO);

        let eth_dominance_percentage = data
            .market_cap_percentage
            .get("eth")
            .and_then(|v| Decimal::from_f64(*v));

        Self {
            total_market_cap_usd,
            total_volume_24h_usd,
            btc_dominance_percentage,
            eth_dominance_percentage,
            active_cryptocurrencies: data.active_cryptocurrencies,
            markets: Some(data.markets),
            updated_at: data.updated_at,
        }
    }
}
