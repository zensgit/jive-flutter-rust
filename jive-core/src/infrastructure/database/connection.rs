//! 数据库连接池管理
//! 提供PostgreSQL数据库连接池的初始化和管理功能

use sqlx::{postgres::PgPoolOptions, PgPool};
use std::time::Duration;
use tracing::{info, error};

/// 数据库配置
#[derive(Debug, Clone)]
pub struct DatabaseConfig {
    pub url: String,
    pub max_connections: u32,
    pub min_connections: u32,
    pub connect_timeout: Duration,
    pub idle_timeout: Duration,
    pub max_lifetime: Duration,
}

impl Default for DatabaseConfig {
    fn default() -> Self {
        Self {
            url: std::env::var("DATABASE_URL")
                .unwrap_or_else(|_| "postgresql://postgres:postgres@localhost/jive_db".to_string()),
            max_connections: 100,
            min_connections: 5,
            connect_timeout: Duration::from_secs(5),
            idle_timeout: Duration::from_secs(300),
            max_lifetime: Duration::from_secs(3600),
        }
    }
}

/// 数据库连接管理器
pub struct Database {
    pool: PgPool,
}

impl Database {
    /// 创建新的数据库连接池
    pub async fn new(config: DatabaseConfig) -> Result<Self, sqlx::Error> {
        info!("Initializing database connection pool...");
        
        let pool = PgPoolOptions::new()
            .max_connections(config.max_connections)
            .min_connections(config.min_connections)
            .connect_timeout(config.connect_timeout)
            .idle_timeout(Some(config.idle_timeout))
            .max_lifetime(Some(config.max_lifetime))
            .connect(&config.url)
            .await?;
        
        info!("Database connection pool initialized successfully");
        Ok(Self { pool })
    }

    /// 获取连接池引用
    pub fn pool(&self) -> &PgPool {
        &self.pool
    }

    /// 健康检查
    pub async fn health_check(&self) -> Result<(), sqlx::Error> {
        sqlx::query("SELECT 1")
            .fetch_one(&self.pool)
            .await?;
        Ok(())
    }

    /// 执行数据库迁移（可选启用 embed_migrations 特性）
    #[cfg(feature = "db")]
    pub async fn migrate(&self) -> Result<(), sqlx::migrate::MigrateError> {
        #[cfg(feature = "embed_migrations")]
        {
            info!("Running database migrations (embedded)...");
            sqlx::migrate!("../../migrations")
                .run(&self.pool)
                .await?;
            info!("Database migrations completed");
        }
        // 默认情况下不执行嵌入式迁移，以避免构建期需要本地 migrations 目录
        Ok(())
    }

    /// 开始事务
    pub async fn begin_transaction(&self) -> Result<sqlx::Transaction<'_, sqlx::Postgres>, sqlx::Error> {
        self.pool.begin().await
    }

    /// 关闭连接池
    pub async fn close(&self) {
        self.pool.close().await;
        info!("Database connection pool closed");
    }
}

/// 连接池健康监控
pub struct HealthMonitor {
    database: Database,
    check_interval: Duration,
}

impl HealthMonitor {
    pub fn new(database: Database, check_interval: Duration) -> Self {
        Self {
            database,
            check_interval,
        }
    }

    /// 启动健康检查循环
    pub async fn start_monitoring(self) {
        tokio::spawn(async move {
            let mut interval = tokio::time::interval(self.check_interval);
            
            loop {
                interval.tick().await;
                
                match self.database.health_check().await {
                    Ok(_) => {
                        info!("Database health check passed");
                    }
                    Err(e) => {
                        error!("Database health check failed: {}", e);
                        // 这里可以添加告警逻辑
                    }
                }
            }
        });
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_database_connection() {
        let config = DatabaseConfig::default();
        let db = Database::new(config).await;
        assert!(db.is_ok());
        
        if let Ok(database) = db {
            let health_check = database.health_check().await;
            assert!(health_check.is_ok());
        }
    }

    #[tokio::test]
    async fn test_transaction() {
        let config = DatabaseConfig::default();
        let db = Database::new(config).await.unwrap();
        
        let tx = db.begin_transaction().await;
        assert!(tx.is_ok());
        
        if let Ok(mut transaction) = tx {
            // 测试事务操作
            let result = sqlx::query("SELECT 1")
                .fetch_one(&mut *transaction)
                .await;
            assert!(result.is_ok());
            
            transaction.rollback().await.unwrap();
        }
    }
}
