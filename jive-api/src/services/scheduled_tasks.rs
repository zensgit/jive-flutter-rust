// Utc import not needed after refactor
use sqlx::PgPool;
use tokio::time::{interval, Duration as TokioDuration};
use tracing::{info, error, warn};
use std::sync::Arc;

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
        
        // 启动汇率更新任务（每15分钟）
        let manager_clone = Arc::clone(&self);
        tokio::spawn(async move {
            manager_clone.run_exchange_rate_update_task().await;
        });
        
        // 启动加密货币价格更新任务（每5分钟）
        let manager_clone = Arc::clone(&self);
        tokio::spawn(async move {
            manager_clone.run_crypto_price_update_task().await;
        });
        
        // 启动缓存清理任务（每小时）
        let manager_clone = Arc::clone(&self);
        tokio::spawn(async move {
            manager_clone.run_cache_cleanup_task().await;
        });
        
        info!("All scheduled tasks started");
    }
    
    /// 汇率更新任务
    async fn run_exchange_rate_update_task(&self) {
        let mut interval = interval(TokioDuration::from_secs(15 * 60)); // 15分钟
        
        loop {
            interval.tick().await;
            
            info!("Running exchange rate update task");
            
            // 获取所有需要更新的基础货币
            let base_currencies = match self.get_active_base_currencies().await {
                Ok(currencies) => currencies,
                Err(e) => {
                    error!("Failed to get base currencies: {:?}", e);
                    continue;
                }
            };
            
            let currency_service = CurrencyService::new((*self.pool).clone());
            
            for base_currency in base_currencies {
                match currency_service.fetch_latest_rates(&base_currency).await {
                    Ok(_) => {
                        info!("Successfully updated exchange rates for {}", base_currency);
                    }
                    Err(e) => {
                        warn!("Failed to update exchange rates for {}: {:?}", base_currency, e);
                    }
                }
                
                // 避免API限流，每个请求之间等待1秒
                tokio::time::sleep(TokioDuration::from_secs(1)).await;
            }
        }
    }
    
    /// 加密货币价格更新任务
    async fn run_crypto_price_update_task(&self) {
        let mut interval = interval(TokioDuration::from_secs(5 * 60)); // 5分钟
        
        loop {
            interval.tick().await;
            
            info!("Running crypto price update task");
            
            // 检查是否有用户启用了加密货币
            let crypto_enabled = match self.check_crypto_enabled().await {
                Ok(enabled) => enabled,
                Err(e) => {
                    error!("Failed to check crypto status: {:?}", e);
                    continue;
                }
            };
            
            if !crypto_enabled {
                continue;
            }
            
            let currency_service = CurrencyService::new((*self.pool).clone());
            
            // 主要加密货币列表
            let crypto_codes = vec![
                "BTC", "ETH", "USDT", "BNB", "SOL", "XRP", "USDC", "ADA",
                "AVAX", "DOGE", "DOT", "MATIC", "LINK", "LTC", "UNI", "ATOM",
                "COMP", "MKR", "AAVE", "SUSHI", "ARB", "OP", "SHIB", "TRX"
            ];
            
            // 获取需要更新的法定货币
            let fiat_currencies = match self.get_crypto_base_currencies().await {
                Ok(currencies) => currencies,
                Err(e) => {
                    error!("Failed to get fiat currencies for crypto: {:?}", e);
                    vec!["USD".to_string()] // 默认至少更新USD
                }
            };
            
            for fiat in fiat_currencies {
                match currency_service.fetch_crypto_prices(crypto_codes.clone(), &fiat).await {
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
                    info!("Cleaned up {} expired cache entries", result.rows_affected());
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
                    info!("Cleaned up {} old conversion history records", result.rows_affected());
                }
                Err(e) => {
                    error!("Failed to clean conversion history: {:?}", e);
                }
            }
            
            // 清理过期的手动汇率（当前表结构可能无相关列，暂略过以避免编译时检查失败）
            // 如需启用，请确认 exchange_rates 存在 is_manual / manual_rate_expiry 列后恢复以下逻辑
            // 并相应更新迁移脚本确保兼容
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
            Ok(vec!["USD".to_string(), "EUR".to_string(), "CNY".to_string()])
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
}

/// 初始化并启动定时任务
pub async fn init_scheduled_tasks(pool: Arc<PgPool>) {
    let manager = Arc::new(ScheduledTaskManager::new(pool));
    manager.start_all_tasks().await;
}
