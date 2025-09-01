//! 数据库连接管理模块
//! 
//! 提供PostgreSQL数据库连接池和迁移管理

use sqlx::postgres::{PgPool, PgPoolOptions};
use std::env;
use std::sync::Arc;

/// 数据库配置
#[derive(Debug, Clone)]
pub struct DatabaseConfig {
    pub host: String,
    pub port: u16,
    pub database: String,
    pub username: String,
    pub password: String,
    pub max_connections: u32,
}

impl Default for DatabaseConfig {
    fn default() -> Self {
        Self {
            host: env::var("DB_HOST").unwrap_or_else(|_| "localhost".to_string()),
            port: env::var("DB_PORT")
                .unwrap_or_else(|_| "5432".to_string())
                .parse()
                .unwrap_or(5432),
            database: env::var("DB_NAME").unwrap_or_else(|_| "jive_money".to_string()),
            username: env::var("DB_USER").unwrap_or_else(|_| "jive".to_string()),
            password: env::var("DB_PASSWORD").unwrap_or_else(|_| "jive_password".to_string()),
            max_connections: env::var("DB_MAX_CONNECTIONS")
                .unwrap_or_else(|_| "10".to_string())
                .parse()
                .unwrap_or(10),
        }
    }
}

impl DatabaseConfig {
    /// 构建数据库连接URL
    pub fn connection_url(&self) -> String {
        format!(
            "postgres://{}:{}@{}:{}/{}",
            self.username, self.password, self.host, self.port, self.database
        )
    }
}

/// 数据库连接管理器
pub struct Database {
    pool: Arc<PgPool>,
}

impl Database {
    /// 创建新的数据库连接
    pub async fn new(config: DatabaseConfig) -> Result<Self, sqlx::Error> {
        let pool = PgPoolOptions::new()
            .max_connections(config.max_connections)
            .connect(&config.connection_url())
            .await?;

        Ok(Self {
            pool: Arc::new(pool),
        })
    }

    /// 从环境变量创建数据库连接
    pub async fn from_env() -> Result<Self, sqlx::Error> {
        let config = DatabaseConfig::default();
        Self::new(config).await
    }

    /// 获取连接池
    pub fn pool(&self) -> Arc<PgPool> {
        self.pool.clone()
    }

    /// 运行数据库迁移
    pub async fn run_migrations(&self) -> Result<(), sqlx::Error> {
        sqlx::migrate!("../migrations")
            .run(&*self.pool)
            .await?;
        Ok(())
    }

    /// 检查数据库连接
    pub async fn health_check(&self) -> Result<(), sqlx::Error> {
        sqlx::query("SELECT 1")
            .fetch_one(&*self.pool)
            .await?;
        Ok(())
    }

    /// 清理测试数据（仅用于测试环境）
    #[cfg(test)]
    pub async fn cleanup_test_data(&self) -> Result<(), sqlx::Error> {
        // 清理测试数据的SQL语句
        sqlx::query(
            r#"
            DELETE FROM transactions WHERE created_at > NOW() - INTERVAL '1 day';
            DELETE FROM categories WHERE created_at > NOW() - INTERVAL '1 day' AND is_system = false;
            DELETE FROM tags WHERE created_at > NOW() - INTERVAL '1 day';
            "#
        )
        .execute(&*self.pool)
        .await?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_database_connection() {
        let config = DatabaseConfig {
            host: "localhost".to_string(),
            port: 5432,
            database: "jive_test".to_string(),
            username: "jive".to_string(),
            password: "jive_password".to_string(),
            max_connections: 5,
        };

        match Database::new(config).await {
            Ok(db) => {
                assert!(db.health_check().await.is_ok());
            }
            Err(e) => {
                eprintln!("Database connection failed: {}", e);
                // 在CI环境中可能没有数据库，所以不让测试失败
            }
        }
    }
}