//! Jive Money API Server
//! 
//! 本地测试API服务器，提供分类模板的网络加载功能
//! 监听地址: 127.0.0.1:8080

use axum::{
    http::{header, HeaderValue, Method, StatusCode},
    response::Json,
    routing::{get, post, put, delete},
    serve,
    Router,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::{postgres::PgPoolOptions, PgPool};
use std::{collections::HashMap, net::SocketAddr};
use tokio::net::TcpListener;
use tower::ServiceBuilder;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::{DefaultMakeSpan, TraceLayer},
};
use tracing::{info, warn, error};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use uuid::Uuid;
use chrono::{DateTime, Utc};

mod handlers;
use handlers::template_handler::*;

/// 应用状态
#[derive(Clone)]
struct AppState {
    pub pool: PgPool,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 初始化日志
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!("🚀 Starting Jive Money API Server...");

    // 数据库连接
    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgresql://jive:jive_password@localhost/jive_money".to_string());
    
    info!("📦 Connecting to database: {}", database_url.replace("jive_password", "***"));
    
    let pool = match PgPoolOptions::new()
        .max_connections(10)
        .connect(&database_url)
        .await
    {
        Ok(pool) => {
            info!("✅ Database connected successfully");
            pool
        }
        Err(e) => {
            error!("❌ Failed to connect to database: {}", e);
            warn!("💡 Make sure PostgreSQL is running and database is created");
            warn!("💡 You can create the database with: createdb jive_money");
            std::process::exit(1);
        }
    };

    // 测试数据库连接
    match sqlx::query("SELECT 1").execute(&pool).await {
        Ok(_) => info!("✅ Database connection test passed"),
        Err(e) => {
            error!("❌ Database connection test failed: {}", e);
            std::process::exit(1);
        }
    }

    let app_state = AppState { pool };

    // CORS配置
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
        .allow_headers([header::CONTENT_TYPE, header::AUTHORIZATION]);

    // 路由配置
    let app = Router::new()
        // 健康检查
        .route("/health", get(health_check))
        .route("/", get(api_info))
        
        // 分类模板API (模拟钱记的接口)
        .route("/api/v1/templates/list", get(get_templates))
        .route("/api/v1/icons/list", get(get_icons))
        .route("/api/v1/templates/updates", get(get_template_updates))
        .route("/api/v1/templates/usage", post(submit_usage))
        
        // 超级管理员API
        .route("/api/v1/admin/templates", post(create_template))
        .route("/api/v1/admin/templates/:template_id", put(update_template))
        .route("/api/v1/admin/templates/:template_id", delete(delete_template))
        
        // 静态文件 (模拟CDN)
        .route("/static/icons/*path", get(serve_icon))
        
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(cors),
        )
        .with_state(app_state.pool);

    // 启动服务器
    let addr: SocketAddr = "127.0.0.1:8080".parse()?;
    let listener = TcpListener::bind(addr).await?;
    
    info!("🌐 Server running at http://{}", addr);
    info!("📋 API Documentation:");
    info!("  GET  /api/v1/templates/list    - 获取模板列表");
    info!("  GET  /api/v1/icons/list        - 获取图标列表");
    info!("  GET  /api/v1/templates/updates - 增量更新");
    info!("  POST /api/v1/templates/usage   - 提交使用统计");
    info!("  POST /api/v1/admin/templates   - 创建模板 (管理员)");
    info!("  PUT  /api/v1/admin/templates/:id - 更新模板 (管理员)");
    info!("  DELETE /api/v1/admin/templates/:id - 删除模板 (管理员)");
    info!("💡 Test with: curl http://127.0.0.1:8080/api/v1/templates/list");
    
    serve(listener, app).await?;
    
    Ok(())
}

/// 健康检查接口
async fn health_check() -> Json<serde_json::Value> {
    Json(json!({
        "status": "healthy",
        "service": "jive-money-api",
        "version": "1.0.0",
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}

/// API信息接口
async fn api_info() -> Json<serde_json::Value> {
    Json(json!({
        "name": "Jive Money API",
        "version": "1.0.0",
        "description": "Category template management API",
        "endpoints": {
            "templates": "/api/v1/templates/list",
            "icons": "/api/v1/icons/list",
            "updates": "/api/v1/templates/updates",
            "admin": "/api/v1/admin/templates"
        },
        "documentation": "https://api.jivemoney.app/docs",
        "support": "support@jivemoney.app"
    }))
}

/// 服务静态图标文件 (模拟CDN)
async fn serve_icon() -> Result<Json<serde_json::Value>, StatusCode> {
    // 实际实现中这里应该返回真实的图片文件
    // 现在返回图标信息用于测试
    Ok(Json(json!({
        "message": "Icon serving not implemented yet",
        "note": "In production, this would serve actual image files",
        "example_icons": {
            "salary": "💰",
            "food": "🍽️",
            "transport": "🚗",
            "shopping": "🛒",
            "entertainment": "🎬"
        }
    })))
}