// 智能配置加载器 - 自动适配不同环境

use std::env;

pub struct Config {
    pub database_url: String,
    pub redis_url: String,
    pub api_port: u16,
}

impl Config {
    pub fn from_env() -> Self {
        // 检测运行环境
        let is_docker = env::var("DOCKER_ENV").is_ok();
        let os = env::consts::OS;
        
        // 根据环境智能选择配置
        let database_url = env::var("DATABASE_URL").unwrap_or_else(|_| {
            if is_docker {
                // Docker内部网络
                "postgresql://postgres:postgres@postgres:5432/jive_money".to_string()
            } else if os == "macos" {
                // macOS本地
                "postgresql://postgres:postgres@localhost:5432/jive_money".to_string()
            } else {
                // Linux本地访问Docker
                "postgresql://postgres:postgres@localhost:5433/jive_money".to_string()
            }
        });
        
        let redis_url = env::var("REDIS_URL").unwrap_or_else(|_| {
            if is_docker {
                "redis://redis:6379".to_string()
            } else if os == "macos" {
                "redis://localhost:6379".to_string()
            } else {
                "redis://localhost:6380".to_string()
            }
        });
        
        let api_port = env::var("API_PORT")
            .unwrap_or_else(|_| "8012".to_string())
            .parse()
            .unwrap_or(8012);
        
        println!("🔧 配置加载:");
        println!("  - 系统: {}", os);
        println!("  - Docker: {}", is_docker);
        println!("  - 数据库: {}", database_url);
        println!("  - Redis: {}", redis_url);
        println!("  - API端口: {}", api_port);
        
        Config {
            database_url,
            redis_url,
            api_port,
        }
    }
}
