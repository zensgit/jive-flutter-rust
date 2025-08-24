// Cache Service - 缓存服务
// 基于Redis和内存缓存的高性能缓存解决方案

use crate::domain::errors::DomainError;
use chrono::{DateTime, Utc, Duration};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::hash::Hash;
use std::sync::Arc;
use std::time::SystemTime;
use tokio::sync::RwLock;
use uuid::Uuid;

pub struct CacheService {
    memory_cache: Arc<RwLock<MemoryCache>>,
    redis_client: Option<Arc<dyn RedisClient>>,
    config: CacheConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheConfig {
    pub memory_cache_size: usize,
    pub default_ttl_seconds: u64,
    pub redis_enabled: bool,
    pub redis_prefix: String,
    pub compression_enabled: bool,
    pub compression_threshold: usize,
}

impl Default for CacheConfig {
    fn default() -> Self {
        Self {
            memory_cache_size: 10000,
            default_ttl_seconds: 3600, // 1 hour
            redis_enabled: false,
            redis_prefix: "jive:".to_string(),
            compression_enabled: true,
            compression_threshold: 1024, // 1KB
        }
    }
}

impl CacheService {
    pub fn new(config: CacheConfig) -> Self {
        Self {
            memory_cache: Arc::new(RwLock::new(MemoryCache::new(config.memory_cache_size))),
            redis_client: None,
            config,
        }
    }
    
    pub fn with_redis_client(mut self, redis_client: Arc<dyn RedisClient>) -> Self {
        self.redis_client = Some(redis_client);
        self
    }
    
    // 设置缓存
    pub async fn set<T>(&self, key: &str, value: &T, ttl: Option<Duration>) -> Result<(), DomainError>
    where
        T: Serialize,
    {
        let ttl = ttl.unwrap_or_else(|| Duration::seconds(self.config.default_ttl_seconds as i64));
        let serialized = serde_json::to_vec(value)
            .map_err(|e| DomainError::Serialization(e.to_string()))?;
        
        // 压缩大数据
        let data = if self.config.compression_enabled && serialized.len() > self.config.compression_threshold {
            self.compress(&serialized)?
        } else {
            serialized
        };
        
        let cache_entry = CacheEntry {
            data,
            expires_at: Utc::now() + ttl,
            compressed: self.config.compression_enabled && data.len() != serialized.len(),
            created_at: Utc::now(),
            access_count: 0,
        };
        
        // 存储到内存缓存
        {
            let mut memory_cache = self.memory_cache.write().await;
            memory_cache.set(key.to_string(), cache_entry.clone());
        }
        
        // 如果启用Redis，也存储到Redis
        if let Some(redis_client) = &self.redis_client {
            let redis_key = format!("{}{}", self.config.redis_prefix, key);
            redis_client.set(&redis_key, &cache_entry.data, ttl.num_seconds() as u64).await?;
        }
        
        Ok(())
    }
    
    // 获取缓存
    pub async fn get<T>(&self, key: &str) -> Result<Option<T>, DomainError>
    where
        T: for<'de> Deserialize<'de>,
    {
        // 首先尝试从内存缓存获取
        {
            let mut memory_cache = self.memory_cache.write().await;
            if let Some(mut entry) = memory_cache.get(key) {
                if entry.expires_at > Utc::now() {
                    entry.access_count += 1;
                    memory_cache.set(key.to_string(), entry.clone());
                    
                    let data = if entry.compressed {
                        self.decompress(&entry.data)?
                    } else {
                        entry.data
                    };
                    
                    let value: T = serde_json::from_slice(&data)
                        .map_err(|e| DomainError::Serialization(e.to_string()))?;
                    
                    return Ok(Some(value));
                } else {
                    // 过期，从内存缓存中移除
                    memory_cache.remove(key);
                }
            }
        }
        
        // 如果内存缓存没有，尝试从Redis获取
        if let Some(redis_client) = &self.redis_client {
            let redis_key = format!("{}{}", self.config.redis_prefix, key);
            if let Some(data) = redis_client.get(&redis_key).await? {
                let value: T = serde_json::from_slice(&data)
                    .map_err(|e| DomainError::Serialization(e.to_string()))?;
                
                // 回写到内存缓存
                let cache_entry = CacheEntry {
                    data,
                    expires_at: Utc::now() + Duration::seconds(self.config.default_ttl_seconds as i64),
                    compressed: false,
                    created_at: Utc::now(),
                    access_count: 1,
                };
                
                {
                    let mut memory_cache = self.memory_cache.write().await;
                    memory_cache.set(key.to_string(), cache_entry);
                }
                
                return Ok(Some(value));
            }
        }
        
        Ok(None)
    }
    
    // 删除缓存
    pub async fn delete(&self, key: &str) -> Result<(), DomainError> {
        // 从内存缓存删除
        {
            let mut memory_cache = self.memory_cache.write().await;
            memory_cache.remove(key);
        }
        
        // 从Redis删除
        if let Some(redis_client) = &self.redis_client {
            let redis_key = format!("{}{}", self.config.redis_prefix, key);
            redis_client.delete(&redis_key).await?;
        }
        
        Ok(())
    }
    
    // 批量删除缓存（支持模式匹配）
    pub async fn delete_pattern(&self, pattern: &str) -> Result<u32, DomainError> {
        let mut deleted_count = 0;
        
        // 从内存缓存删除匹配的键
        {
            let mut memory_cache = self.memory_cache.write().await;
            let keys_to_remove: Vec<String> = memory_cache.data.keys()
                .filter(|k| self.matches_pattern(k, pattern))
                .cloned()
                .collect();
            
            for key in keys_to_remove {
                memory_cache.remove(&key);
                deleted_count += 1;
            }
        }
        
        // 从Redis删除匹配的键
        if let Some(redis_client) = &self.redis_client {
            let redis_pattern = format!("{}{}", self.config.redis_prefix, pattern);
            deleted_count += redis_client.delete_pattern(&redis_pattern).await?;
        }
        
        Ok(deleted_count)
    }
    
    // 清空所有缓存
    pub async fn clear(&self) -> Result<(), DomainError> {
        // 清空内存缓存
        {
            let mut memory_cache = self.memory_cache.write().await;
            memory_cache.clear();
        }
        
        // 清空Redis缓存（仅清空带前缀的键）
        if let Some(redis_client) = &self.redis_client {
            let pattern = format!("{}*", self.config.redis_prefix);
            redis_client.delete_pattern(&pattern).await?;
        }
        
        Ok(())
    }
    
    // 检查键是否存在
    pub async fn exists(&self, key: &str) -> Result<bool, DomainError> {
        // 检查内存缓存
        {
            let memory_cache = self.memory_cache.read().await;
            if let Some(entry) = memory_cache.data.get(key) {
                if entry.expires_at > Utc::now() {
                    return Ok(true);
                }
            }
        }
        
        // 检查Redis
        if let Some(redis_client) = &self.redis_client {
            let redis_key = format!("{}{}", self.config.redis_prefix, key);
            return redis_client.exists(&redis_key).await;
        }
        
        Ok(false)
    }
    
    // 设置过期时间
    pub async fn expire(&self, key: &str, ttl: Duration) -> Result<(), DomainError> {
        // 更新内存缓存的过期时间
        {
            let mut memory_cache = self.memory_cache.write().await;
            if let Some(mut entry) = memory_cache.get(key) {
                entry.expires_at = Utc::now() + ttl;
                memory_cache.set(key.to_string(), entry);
            }
        }
        
        // 更新Redis的过期时间
        if let Some(redis_client) = &self.redis_client {
            let redis_key = format!("{}{}", self.config.redis_prefix, key);
            redis_client.expire(&redis_key, ttl.num_seconds() as u64).await?;
        }
        
        Ok(())
    }
    
    // 获取TTL
    pub async fn ttl(&self, key: &str) -> Result<Option<Duration>, DomainError> {
        // 检查内存缓存
        {
            let memory_cache = self.memory_cache.read().await;
            if let Some(entry) = memory_cache.data.get(key) {
                let now = Utc::now();
                if entry.expires_at > now {
                    return Ok(Some(entry.expires_at - now));
                }
            }
        }
        
        // 检查Redis
        if let Some(redis_client) = &self.redis_client {
            let redis_key = format!("{}{}", self.config.redis_prefix, key);
            if let Some(ttl_seconds) = redis_client.ttl(&redis_key).await? {
                return Ok(Some(Duration::seconds(ttl_seconds)));
            }
        }
        
        Ok(None)
    }
    
    // 获取缓存统计信息
    pub async fn get_stats(&self) -> CacheStats {
        let memory_cache = self.memory_cache.read().await;
        let total_entries = memory_cache.data.len();
        let mut expired_entries = 0;
        let mut total_size = 0;
        let mut total_access_count = 0;
        
        let now = Utc::now();
        for entry in memory_cache.data.values() {
            if entry.expires_at <= now {
                expired_entries += 1;
            }
            total_size += entry.data.len();
            total_access_count += entry.access_count;
        }
        
        CacheStats {
            total_entries,
            expired_entries,
            active_entries: total_entries - expired_entries,
            total_size_bytes: total_size,
            average_access_count: if total_entries > 0 {
                total_access_count as f64 / total_entries as f64
            } else {
                0.0
            },
            memory_cache_enabled: true,
            redis_cache_enabled: self.redis_client.is_some(),
        }
    }
    
    // 清理过期的缓存项
    pub async fn cleanup_expired(&self) -> Result<u32, DomainError> {
        let mut cleaned_count = 0;
        
        {
            let mut memory_cache = self.memory_cache.write().await;
            let now = Utc::now();
            let expired_keys: Vec<String> = memory_cache.data.iter()
                .filter_map(|(key, entry)| {
                    if entry.expires_at <= now {
                        Some(key.clone())
                    } else {
                        None
                    }
                })
                .collect();
            
            for key in expired_keys {
                memory_cache.remove(&key);
                cleaned_count += 1;
            }
        }
        
        Ok(cleaned_count)
    }
    
    // 获取或设置缓存（如果不存在则计算）
    pub async fn get_or_set<T, F, Fut>(&self, key: &str, compute_fn: F, ttl: Option<Duration>) -> Result<T, DomainError>
    where
        T: Serialize + for<'de> Deserialize<'de> + Clone,
        F: FnOnce() -> Fut,
        Fut: std::future::Future<Output = Result<T, DomainError>>,
    {
        // 尝试获取缓存
        if let Some(cached_value) = self.get::<T>(key).await? {
            return Ok(cached_value);
        }
        
        // 计算新值
        let computed_value = compute_fn().await?;
        
        // 设置缓存
        self.set(key, &computed_value, ttl).await?;
        
        Ok(computed_value)
    }
    
    // 批量获取
    pub async fn get_multi<T>(&self, keys: &[String]) -> Result<HashMap<String, T>, DomainError>
    where
        T: for<'de> Deserialize<'de>,
    {
        let mut results = HashMap::new();
        
        for key in keys {
            if let Some(value) = self.get::<T>(key).await? {
                results.insert(key.clone(), value);
            }
        }
        
        Ok(results)
    }
    
    // 批量设置
    pub async fn set_multi<T>(&self, entries: &HashMap<String, T>, ttl: Option<Duration>) -> Result<(), DomainError>
    where
        T: Serialize,
    {
        for (key, value) in entries {
            self.set(key, value, ttl).await?;
        }
        
        Ok(())
    }
    
    // 辅助方法
    
    fn compress(&self, data: &[u8]) -> Result<Vec<u8>, DomainError> {
        // 使用简单的压缩算法 (在实际实现中可以使用gzip或lz4)
        Ok(data.to_vec()) // 暂时不压缩
    }
    
    fn decompress(&self, data: &[u8]) -> Result<Vec<u8>, DomainError> {
        // 对应的解压缩
        Ok(data.to_vec())
    }
    
    fn matches_pattern(&self, key: &str, pattern: &str) -> bool {
        // 简单的模式匹配，支持*通配符
        if pattern == "*" {
            return true;
        }
        
        if pattern.ends_with('*') {
            let prefix = &pattern[..pattern.len() - 1];
            return key.starts_with(prefix);
        }
        
        if pattern.starts_with('*') {
            let suffix = &pattern[1..];
            return key.ends_with(suffix);
        }
        
        key == pattern
    }
}

// 内存缓存实现
#[derive(Debug)]
struct MemoryCache {
    data: HashMap<String, CacheEntry>,
    max_size: usize,
    access_order: Vec<String>, // LRU队列
}

impl MemoryCache {
    fn new(max_size: usize) -> Self {
        Self {
            data: HashMap::new(),
            max_size,
            access_order: Vec::new(),
        }
    }
    
    fn set(&mut self, key: String, entry: CacheEntry) {
        // 如果缓存已满，移除最少使用的项
        if self.data.len() >= self.max_size && !self.data.contains_key(&key) {
            if let Some(lru_key) = self.access_order.first().cloned() {
                self.data.remove(&lru_key);
                self.access_order.retain(|k| k != &lru_key);
            }
        }
        
        // 更新访问顺序
        self.access_order.retain(|k| k != &key);
        self.access_order.push(key.clone());
        
        self.data.insert(key, entry);
    }
    
    fn get(&mut self, key: &str) -> Option<CacheEntry> {
        if let Some(entry) = self.data.get(key) {
            // 更新访问顺序
            self.access_order.retain(|k| k != key);
            self.access_order.push(key.to_string());
            
            Some(entry.clone())
        } else {
            None
        }
    }
    
    fn remove(&mut self, key: &str) {
        self.data.remove(key);
        self.access_order.retain(|k| k != key);
    }
    
    fn clear(&mut self) {
        self.data.clear();
        self.access_order.clear();
    }
}

// 缓存条目
#[derive(Debug, Clone)]
struct CacheEntry {
    data: Vec<u8>,
    expires_at: DateTime<Utc>,
    compressed: bool,
    created_at: DateTime<Utc>,
    access_count: u64,
}

// 缓存统计信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheStats {
    pub total_entries: usize,
    pub expired_entries: usize,
    pub active_entries: usize,
    pub total_size_bytes: usize,
    pub average_access_count: f64,
    pub memory_cache_enabled: bool,
    pub redis_cache_enabled: bool,
}

// Redis客户端trait
#[async_trait::async_trait]
pub trait RedisClient: Send + Sync {
    async fn set(&self, key: &str, value: &[u8], ttl_seconds: u64) -> Result<(), DomainError>;
    async fn get(&self, key: &str) -> Result<Option<Vec<u8>>, DomainError>;
    async fn delete(&self, key: &str) -> Result<(), DomainError>;
    async fn delete_pattern(&self, pattern: &str) -> Result<u32, DomainError>;
    async fn exists(&self, key: &str) -> Result<bool, DomainError>;
    async fn expire(&self, key: &str, ttl_seconds: u64) -> Result<(), DomainError>;
    async fn ttl(&self, key: &str) -> Result<Option<i64>, DomainError>;
}

// 缓存键生成器
pub struct CacheKeyBuilder {
    prefix: String,
}

impl CacheKeyBuilder {
    pub fn new(prefix: &str) -> Self {
        Self {
            prefix: prefix.to_string(),
        }
    }
    
    pub fn user_data(&self, user_id: Uuid, data_type: &str) -> String {
        format!("{}:user:{}:{}", self.prefix, user_id, data_type)
    }
    
    pub fn family_data(&self, family_id: Uuid, data_type: &str) -> String {
        format!("{}:family:{}:{}", self.prefix, family_id, data_type)
    }
    
    pub fn account_balance(&self, account_id: Uuid) -> String {
        format!("{}:account:{}:balance", self.prefix, account_id)
    }
    
    pub fn transaction_summary(&self, account_id: Uuid, date: NaiveDate) -> String {
        format!("{}:transactions:{}:{}", self.prefix, account_id, date.format("%Y-%m-%d"))
    }
    
    pub fn budget_status(&self, family_id: Uuid, period: &str) -> String {
        format!("{}:budget:{}:{}", self.prefix, family_id, period)
    }
    
    pub fn report_data(&self, family_id: Uuid, report_type: &str, date_range: &str) -> String {
        format!("{}:report:{}:{}:{}", self.prefix, family_id, report_type, date_range)
    }
}

// 预定义的缓存键
impl CacheKeyBuilder {
    pub const USER_PREFERENCES: &'static str = "user_preferences";
    pub const ACCOUNT_BALANCES: &'static str = "account_balances";
    pub const CATEGORY_TOTALS: &'static str = "category_totals";
    pub const BUDGET_STATUS: &'static str = "budget_status";
    pub const NET_WORTH_HISTORY: &'static str = "net_worth_history";
    pub const TRANSACTION_COUNTS: &'static str = "transaction_counts";
    pub const MERCHANT_STATS: &'static str = "merchant_stats";
    pub const MONTHLY_REPORTS: &'static str = "monthly_reports";
    pub const PLAID_SYNC_STATUS: &'static str = "plaid_sync_status";
    pub const AI_CATEGORIZATIONS: &'static str = "ai_categorizations";
}

use chrono::NaiveDate;