//! Jive Money API Server
//! 
//! 本地测试API服务器，提供分类模板的网络加载功能
//! 监听地址: 127.0.0.1:8012

use axum::{
    extract::FromRef,
    http::{header, Method, StatusCode},
    response::Json,
    routing::{get, post, put, delete},
    serve,
    Router,
};
use serde_json::json;
use sqlx::{postgres::PgPoolOptions, PgPool};
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
mod websocket;
use handlers::template_handler::*;
use handlers::accounts::*;
use handlers::transactions::*;
use handlers::payees::*;
use handlers::rules::*;
use handlers::auth as auth_handlers;
use websocket::{WsConnectionManager, handle_websocket};

/// 应用状态
#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub ws_manager: std::sync::Arc<WsConnectionManager>,
}

// 实现FromRef trait以便子状态可以从AppState中提取
impl FromRef<AppState> for PgPool {
    fn from_ref(app_state: &AppState) -> PgPool {
        app_state.pool.clone()
    }
}

impl FromRef<AppState> for std::sync::Arc<WsConnectionManager> {
    fn from_ref(app_state: &AppState) -> std::sync::Arc<WsConnectionManager> {
        app_state.ws_manager.clone()
    }
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

    // 创建WebSocket连接管理器
    let ws_manager = std::sync::Arc::new(WsConnectionManager::new());
    
    let app_state = AppState { 
        pool: pool.clone(),
        ws_manager: ws_manager.clone(),
    };

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
        
        // WebSocket端点
        .route("/ws", get(handle_websocket))
        
        // 静态文件 (模拟CDN)
        .route("/static/icons/*path", get(serve_icon))
        
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(cors),
        )
        .with_state(app_state);

    // 启动服务器
    let port = std::env::var("API_PORT").unwrap_or_else(|_| "8012".to_string());
    let addr: SocketAddr = format!("127.0.0.1:{}", port).parse()?;
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
    info!("  GET  /api/v1/accounts          - 获取账户列表");
    info!("  POST /api/v1/accounts          - 创建账户");
    info!("  GET  /api/v1/accounts/:id      - 获取账户详情");
    info!("  PUT  /api/v1/accounts/:id      - 更新账户");
    info!("  DELETE /api/v1/accounts/:id    - 删除账户");
    info!("  GET  /api/v1/accounts/statistics - 获取账户统计");
    info!("  GET  /api/v1/transactions       - 获取交易列表");
    info!("  POST /api/v1/transactions       - 创建交易");
    info!("  GET  /api/v1/transactions/:id   - 获取交易详情");
    info!("  PUT  /api/v1/transactions/:id   - 更新交易");
    info!("  DELETE /api/v1/transactions/:id - 删除交易");
    info!("  POST /api/v1/transactions/bulk  - 批量操作");
    info!("  GET  /api/v1/transactions/statistics - 获取交易统计");
    info!("💡 Test with: curl http://{}/api/v1/templates/list", addr);
    
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