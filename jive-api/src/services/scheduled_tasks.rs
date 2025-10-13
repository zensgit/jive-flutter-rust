// Utc import not needed after refactor
use sqlx::PgPool;
use std::sync::Arc;
use tokio::time::{interval, Duration as TokioDuration};
use tracing::{error, info, warn};

use super::currency_service::CurrencyService;

/// 定时任务管理器
pub struct ScheduledTaskManager {
    pool: Arc<PgPool>,
}

impl ScheduledTaskManager {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self { pool }
    }

    /// 启动所有定时任务
    pub async fn start_all_tasks(self: Arc<Self>) {
        info!("Starting scheduled tasks...");

        // 延迟启动时间（秒）
        let startup_delay = std::env::var("STARTUP_DELAY")
            .unwrap_or_else(|_| "30".to_string())
            .parse::<u64>()
            .unwrap_or(30);

        // 启动汇率更新任务（延迟30秒后开始，每15分钟执行）
        let manager_clone = Arc::clone(&self);
        tokio::spawn(async move {
            info!(
                "Exchange rate update task will start in {} seconds",
                startup_delay
            );
            tokio::time::sleep(TokioDuration::from_secs(startup_delay)).await;
            manager_clone.run_exchange_rate_update_task().await;
        });

        // 启动加密货币价格更新任务（延迟20秒后开始，每5分钟执行）
        let manager_clone = Arc::clone(&self);
        tokio::spawn(async move {
            info!("Crypto price update task will start in 20 seconds");
            tokio::time::sleep(TokioDuration::from_secs(20)).await;
            manager_clone.run_crypto_price_update_task().await;
        });

        // 启动缓存清理任务（延迟60秒后开始，每小时执行）
        let manager_clone = Arc::clone(&self);
        tokio::spawn(async move {
            info!("Cache cleanup task will start in 60 seconds");
            tokio::time::sleep(TokioDuration::from_secs(60)).await;
            manager_clone.run_cache_cleanup_task().await;
        });

        // 启动手动汇率过期清理任务（可配置开关与频率）
        let manager_clone = Arc::clone(&self);
        tokio::spawn(async move {
            let enabled = std::env::var("MANUAL_CLEAR_ENABLED")
                .ok()
                .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
                .unwrap_or(true);
            if !enabled {
                info!("Manual rate cleanup task disabled by MANUAL_CLEAR_ENABLED");
                return;
            }
            let mins = std::env::var("MANUAL_CLEAR_INTERVAL_MIN")
                .ok()
                .and_then(|v| v.parse::<u64>().ok())
                .unwrap_or(60);
            info!(
                "Manual rate cleanup task will start in 90 seconds, interval: {} minutes",
                mins
            );
            tokio::time::sleep(TokioDuration::from_secs(90)).await;
            manager_clone.run_manual_overrides_cleanup_task(mins).await;
        });

        // 启动全球市场统计更新任务（延迟45秒后开始，每10分钟执行）
        let manager_clone = Arc::clone(&self);
        tokio::spawn(async move {
            info!("Global market stats update task will start in 45 seconds");
            tokio::time::sleep(TokioDuration::from_secs(45)).await;
            manager_clone.run_global_market_stats_task().await;
        });

        info!("All scheduled tasks initialized (will start after delay)");
    }

    /// 汇率更新任务
    async fn run_exchange_rate_update_task(&self) {
        let mut interval = interval(TokioDuration::from_secs(15 * 60)); // 15分钟

        // 第一次执行汇率更新
        info!("Starting initial exchange rate update");
        self.update_exchange_rates().await;

        loop {
            interval.tick().await;
            info!("Running scheduled exchange rate update");
            self.update_exchange_rates().await;
        }
    }

    /// 执行汇率更新
    async fn update_exchange_rates(&self) {
        // 获取所有需要更新的基础货币
        let base_currencies = match self.get_active_base_currencies().await {
            Ok(currencies) => currencies,
            Err(e) => {
                error!("Failed to get base currencies: {:?}", e);
                return;
            }
        };

        let currency_service = CurrencyService::new((*self.pool).clone());

        for base_currency in base_currencies {
            match currency_service.fetch_latest_rates(&base_currency).await {
                Ok(_) => {
                    info!("Successfully updated exchange rates for {}", base_currency);
                }
                Err(e) => {
                    warn!(
                        "Failed to update exchange rates for {}: {:?}",
                        base_currency, e
                    );
                }
            }

            // 避免API限流，每个请求之间等待1秒
            tokio::time::sleep(TokioDuration::from_secs(1)).await;
        }
    }

    /// 加密货币价格更新任务
    async fn run_crypto_price_update_task(&self) {
        let mut interval = interval(TokioDuration::from_secs(5 * 60)); // 5分钟

        // 第一次执行
        info!("Starting initial crypto price update");
        self.update_crypto_prices().await;

        loop {
            interval.tick().await;
            info!("Running scheduled crypto price update");
            self.update_crypto_prices().await;
        }
    }

    /// 执行加密货币价格更新
    async fn update_crypto_prices(&self) {
        info!("Checking crypto price updates...");

        // 检查是否有用户启用了加密货币
        let crypto_enabled = match self.check_crypto_enabled().await {
            Ok(enabled) => enabled,
            Err(e) => {
                error!("Failed to check crypto status: {:?}", e);
                return;
            }
        };

        if !crypto_enabled {
            return;
        }

        let currency_service = CurrencyService::new((*self.pool).clone());

        // 从数据库动态获取所有启用的加密货币
        let crypto_codes = match self.get_active_crypto_currencies().await {
            Ok(codes) => {
                if codes.is_empty() {
                    info!("No active cryptocurrencies found in database");
                    return;
                }
                info!("Found {} active cryptocurrencies to update", codes.len());
                codes
            }
            Err(e) => {
                error!("Failed to get active cryptocurrencies: {:?}", e);
                return;
            }
        };

        // 获取需要更新的法定货币
        let fiat_currencies = match self.get_crypto_base_currencies().await {
            Ok(currencies) => currencies,
            Err(e) => {
                error!("Failed to get fiat currencies for crypto: {:?}", e);
                vec!["USD".to_string()] // 默认至少更新USD
            }
        };

        // 将加密货币代码转换为 &str 引用
        let crypto_code_refs: Vec<&str> = crypto_codes.iter().map(|s| s.as_str()).collect();

        for fiat in fiat_currencies {
            match currency_service
                .fetch_crypto_prices(crypto_code_refs.clone(), &fiat)
                .await
            {
                Ok(_) => {
                    info!("Successfully updated crypto prices in {}", fiat);
                }
                Err(e) => {
                    warn!("Failed to update crypto prices in {}: {:?}", fiat, e);
                }
            }

            // 避免API限流
            tokio::time::sleep(TokioDuration::from_secs(2)).await;
        }
    }

    /// 缓存清理任务
    async fn run_cache_cleanup_task(&self) {
        let mut interval = interval(TokioDuration::from_secs(60 * 60)); // 1小时

        loop {
            interval.tick().await;

            info!("Running cache cleanup task");

            // 清理过期的汇率缓存
            match sqlx::query!(
                r#"
                DELETE FROM exchange_rate_cache 
                WHERE expires_at < CURRENT_TIMESTAMP
                "#
            )
            .execute(&*self.pool)
            .await
            {
                Ok(result) => {
                    info!(
                        "Cleaned up {} expired cache entries",
                        result.rows_affected()
                    );
                }
                Err(e) => {
                    error!("Failed to clean cache: {:?}", e);
                }
            }

            // 清理90天前的转换历史
            match sqlx::query!(
                r#"
                DELETE FROM exchange_conversion_history 
                WHERE conversion_date < CURRENT_TIMESTAMP - INTERVAL '90 days'
                "#
            )
            .execute(&*self.pool)
            .await
            {
                Ok(result) => {
                    info!(
                        "Cleaned up {} old conversion history records",
                        result.rows_affected()
                    );
                }
                Err(e) => {
                    error!("Failed to clean conversion history: {:?}", e);
                }
            }
        }
    }

    /// 全球市场统计更新任务
    async fn run_global_market_stats_task(&self) {
        let mut interval = interval(TokioDuration::from_secs(10 * 60)); // 10分钟

        // 第一次执行
        info!("Starting initial global market stats update");
        self.update_global_market_stats().await;

        loop {
            interval.tick().await;
            info!("Running scheduled global market stats update");
            self.update_global_market_stats().await;
        }
    }

    /// 执行全球市场统计更新（带重试机制）
    async fn update_global_market_stats(&self) {
        use crate::services::exchange_rate_api::EXCHANGE_RATE_SERVICE;

        let max_retries = 3;
        let mut retry_count = 0;

        while retry_count < max_retries {
            let mut service = EXCHANGE_RATE_SERVICE.lock().await;

            match service.fetch_global_market_stats().await {
                Ok(stats) => {
                    info!(
                        "Successfully updated global market stats: Market Cap: ${}, BTC Dominance: {}%",
                        stats.total_market_cap_usd,
                        stats.btc_dominance_percentage
                    );
                    return; // 成功后退出
                }
                Err(e) => {
                    retry_count += 1;
                    if retry_count < max_retries {
                        let backoff_secs = retry_count * 10; // 10s, 20s, 30s递增
                        warn!(
                            "Failed to update global market stats (attempt {}/{}): {:?}. Retrying in {} seconds...",
                            retry_count, max_retries, e, backoff_secs
                        );
                        tokio::time::sleep(TokioDuration::from_secs(backoff_secs)).await;
                    } else {
                        error!(
                            "Failed to update global market stats after {} attempts: {:?}. Will retry in next cycle.",
                            max_retries, e
                        );
                    }
                }
            }
        }
    }

    /// 手动汇率过期清理任务（仅清除标志与过期时间，不删除记录）
    async fn run_manual_overrides_cleanup_task(&self, interval_minutes: u64) {
        let mut interval = interval(TokioDuration::from_secs(interval_minutes * 60));
        loop {
            interval.tick().await;
            match sqlx::query(
                r#"
                UPDATE exchange_rates
                SET is_manual = false,
                    manual_rate_expiry = NULL,
                    updated_at = CURRENT_TIMESTAMP
                WHERE is_manual = true
                  AND manual_rate_expiry IS NOT NULL
                  AND manual_rate_expiry <= NOW()
                "#,
            )
            .execute(&*self.pool)
            .await
            {
                Ok(res) => {
                    let n = res.rows_affected();
                    if n > 0 {
                        info!("Cleared {} expired manual rate flags", n);
                    }
                }
                Err(e) => {
                    warn!("Failed to clear expired manual rates: {:?}", e);
                }
            }
        }
    }

    /// 获取所有活跃的基础货币
    async fn get_active_base_currencies(&self) -> Result<Vec<String>, sqlx::Error> {
        let raw = sqlx::query_scalar!(
            r#"
            SELECT DISTINCT base_currency 
            FROM user_currency_settings 
            WHERE multi_currency_enabled = true
            LIMIT 10
            "#
        )
        .fetch_all(&*self.pool)
        .await?;
        let currencies: Vec<String> = raw.into_iter().flatten().collect();

        // 如果没有用户设置，至少更新主要货币
        if currencies.is_empty() {
            Ok(vec![
                "USD".to_string(),
                "EUR".to_string(),
                "CNY".to_string(),
            ])
        } else {
            Ok(currencies)
        }
    }

    /// 检查是否有用户启用了加密货币
    async fn check_crypto_enabled(&self) -> Result<bool, sqlx::Error> {
        let count: Option<i64> = sqlx::query_scalar!(
            r#"
            SELECT COUNT(*) 
            FROM user_currency_settings 
            WHERE crypto_enabled = true
            "#
        )
        .fetch_one(&*self.pool)
        .await?;

        Ok(count.unwrap_or(0) > 0)
    }

    /// 获取需要更新加密货币价格的法定货币
    async fn get_crypto_base_currencies(&self) -> Result<Vec<String>, sqlx::Error> {
        let raw = sqlx::query_scalar!(
            r#"
            SELECT DISTINCT base_currency
            FROM user_currency_settings
            WHERE crypto_enabled = true
            LIMIT 5
            "#
        )
        .fetch_all(&*self.pool)
        .await?;
        let currencies: Vec<String> = raw.into_iter().flatten().collect();

        if currencies.is_empty() {
            Ok(vec!["USD".to_string()])
        } else {
            Ok(currencies)
        }
    }

    /// 获取需要更新的加密货币列表（智能混合策略）
    async fn get_active_crypto_currencies(&self) -> Result<Vec<String>, sqlx::Error> {
        // 策略1: 优先从用户选择中提取加密货币
        let user_selected = sqlx::query_scalar!(
            r#"
            SELECT DISTINCT c.code
            FROM user_currency_settings ucs,
                 UNNEST(ucs.selected_currencies) AS selected_code
            INNER JOIN currencies c ON selected_code = c.code
            WHERE ucs.crypto_enabled = true
              AND c.is_crypto = true
              AND c.is_active = true
            ORDER BY c.code
            "#
        )
        .fetch_all(&*self.pool)
        .await?;

        if !user_selected.is_empty() {
            info!(
                "Using {} user-selected cryptocurrencies",
                user_selected.len()
            );
            return Ok(user_selected);
        }

        // 策略2: 如果用户没有选择，查找exchange_rates表中已有数据的加密货币
        let cryptos_with_rates = sqlx::query_scalar!(
            r#"
            SELECT DISTINCT er.from_currency
            FROM exchange_rates er
            INNER JOIN currencies c ON er.from_currency = c.code
            WHERE c.is_crypto = true
              AND c.is_active = true
              AND er.updated_at > NOW() - INTERVAL '30 days'
            ORDER BY er.from_currency
            "#
        )
        .fetch_all(&*self.pool)
        .await?;

        if !cryptos_with_rates.is_empty() {
            info!(
                "Using {} cryptocurrencies with existing rates",
                cryptos_with_rates.len()
            );
            return Ok(cryptos_with_rates);
        }

        // 策略3: 最后保底 - 使用精选的主流加密货币列表
        info!("Using default curated cryptocurrency list");
        Ok(vec![
            "BTC".to_string(),
            "ETH".to_string(),
            "USDT".to_string(),
            "USDC".to_string(),
            "BNB".to_string(),
            "XRP".to_string(),
            "ADA".to_string(),
            "SOL".to_string(),
            "DOT".to_string(),
            "DOGE".to_string(),
            "MATIC".to_string(),
            "AVAX".to_string(),
        ])
    }
}

/// 初始化并启动定时任务
pub async fn init_scheduled_tasks(pool: Arc<PgPool>) {
    let manager = Arc::new(ScheduledTaskManager::new(pool));
    manager.start_all_tasks().await;
}
