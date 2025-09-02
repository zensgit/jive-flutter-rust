//! 包含WebSocket的完整API服务器

use axum::{
    http::{header, Method, StatusCode},
    response::Json,
    routing::{get, post, put, delete},
    Router,
};
use serde_json::json;
use sqlx::postgres::PgPoolOptions;
use std::net::SocketAddr;
use tokio::net::TcpListener;
use tower::ServiceBuilder;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};
use tracing::{info, warn, error};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

mod handlers;
mod error;
mod auth;
mod ws;

use handlers::template_handler::*;
use handlers::accounts::*;
use handlers::transactions::*;
use handlers::payees::*;
use handlers::rules::*;
use handlers::auth as auth_handlers;

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

    info!("🚀 Starting Jive Money API Server with WebSocket...");

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
        
        // WebSocket端点
        .route("/ws", get(ws::ws_handler))
        
        // 分类模板API
        .route("/api/v1/templates/list", get(get_templates))
        .route("/api/v1/icons/list", get(get_icons))
        .route("/api/v1/templates/updates", get(get_template_updates))
        .route("/api/v1/templates/usage", post(submit_usage))
        
        // 超级管理员API
        .route("/api/v1/admin/templates", post(create_template))
        .route("/api/v1/admin/templates/:template_id", put(update_template))
        .route("/api/v1/admin/templates/:template_id", delete(delete_template))
        
        // 账户管理API
        .route("/api/v1/accounts", get(list_accounts))
        .route("/api/v1/accounts", post(create_account))
        .route("/api/v1/accounts/:id", get(get_account))
        .route("/api/v1/accounts/:id", put(update_account))
        .route("/api/v1/accounts/:id", delete(delete_account))
        .route("/api/v1/accounts/statistics", get(get_account_statistics))
        
        // 交易管理API
        .route("/api/v1/transactions", get(list_transactions))
        .route("/api/v1/transactions", post(create_transaction))
        .route("/api/v1/transactions/:id", get(get_transaction))
        .route("/api/v1/transactions/:id", put(update_transaction))
        .route("/api/v1/transactions/:id", delete(delete_transaction))
        .route("/api/v1/transactions/bulk", post(bulk_transaction_operations))
        .route("/api/v1/transactions/statistics", get(get_transaction_statistics))
        
        // 收款人管理API
        .route("/api/v1/payees", get(list_payees))
        .route("/api/v1/payees", post(create_payee))
        .route("/api/v1/payees/:id", get(get_payee))
        .route("/api/v1/payees/:id", put(update_payee))
        .route("/api/v1/payees/:id", delete(delete_payee))
        .route("/api/v1/payees/suggestions", get(get_payee_suggestions))
        .route("/api/v1/payees/statistics", get(get_payee_statistics))
        .route("/api/v1/payees/merge", post(merge_payees))
        
        // 规则引擎API
        .route("/api/v1/rules", get(list_rules))
        .route("/api/v1/rules", post(create_rule))
        .route("/api/v1/rules/:id", get(get_rule))
        .route("/api/v1/rules/:id", put(update_rule))
        .route("/api/v1/rules/:id", delete(delete_rule))
        .route("/api/v1/rules/execute", post(execute_rules))
        
        // 认证API
        .route("/api/v1/auth/register", post(auth_handlers::register))
        .route("/api/v1/auth/login", post(auth_handlers::login))
        .route("/api/v1/auth/refresh", post(auth_handlers::refresh_token))
        .route("/api/v1/auth/user", get(auth_handlers::get_current_user))
        .route("/api/v1/auth/user", put(auth_handlers::update_user))
        .route("/api/v1/auth/password", post(auth_handlers::change_password))
        
        // 静态文件
        .route("/static/icons/*path", get(serve_icon))
        
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(cors),
        )
        .with_state(pool);

    // 启动服务器
    let port = std::env::var("API_PORT").unwrap_or_else(|_| "8012".to_string());
    let addr: SocketAddr = format!("127.0.0.1:{}", port).parse()?;
    let listener = TcpListener::bind(addr).await?;
    
    info!("🌐 Server running at http://{}", addr);
    info!("🔌 WebSocket endpoint: ws://{}/ws", addr);
    info!("");
    info!("📋 API Endpoints:");
    info!("  Authentication:");
    info!("    POST /api/v1/auth/register - 用户注册");
    info!("    POST /api/v1/auth/login    - 用户登录");
    info!("    POST /api/v1/auth/refresh  - 刷新令牌");
    info!("");
    info!("  WebSocket:");
    info!("    WS /ws?token=<jwt_token>    - WebSocket连接");
    info!("");
    info!("  Core APIs:");
    info!("    /api/v1/accounts            - 账户管理");
    info!("    /api/v1/transactions        - 交易管理");
    info!("    /api/v1/payees             - 收款人管理");
    info!("    /api/v1/rules              - 规则引擎");
    info!("");
    info!("💡 Test WebSocket: wscat -c 'ws://localhost:{}/ws?token=test'", port);
    
    axum::serve(listener, app).await?;
    
    Ok(())
}

/// 健康检查接口
async fn health_check() -> Json<serde_json::Value> {
    Json(json!({
        "status": "healthy",
        "service": "jive-money-api",
        "version": "1.0.0",
        "features": ["websocket", "auth"],
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}

/// API信息接口
async fn api_info() -> Json<serde_json::Value> {
    Json(json!({
        "name": "Jive Money API",
        "version": "1.0.0",
        "description": "Financial management API with WebSocket support",
        "endpoints": {
            "websocket": "/ws",
            "auth": "/api/v1/auth",
            "accounts": "/api/v1/accounts",
            "transactions": "/api/v1/transactions",
            "payees": "/api/v1/payees",
            "rules": "/api/v1/rules",
            "templates": "/api/v1/templates"
        }
    }))
}

/// 服务静态图标文件
async fn serve_icon() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "message": "Icon serving endpoint"
    })))
}