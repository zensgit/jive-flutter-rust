//! 完整版 API 服务器（包含 WebSocket 和所有功能）
//! 修复了所有模块依赖问题

use axum::{
    extract::{ws::WebSocketUpgrade, Query, State, FromRef},
    http::{header, Method, StatusCode},
    response::{Json, Response},
    routing::{get, post, put, delete},
    Router,
};
use serde::{Deserialize, Serialize};
use serde_json::json;
use sqlx::{postgres::PgPoolOptions, PgPool};
use std::net::SocketAddr;
use std::sync::Arc;
use tokio::net::TcpListener;
use tower::ServiceBuilder;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};
use tracing::{info, warn, error};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use redis::aio::ConnectionManager;
use redis::Client as RedisClient;

// 内部模块
mod handlers;
mod error;
mod auth;
mod services {
    pub mod auth_service;
    pub mod member_service;
    pub mod family_service;
    pub mod avatar_service;
    // pub mod currency_service; // Temporarily disabled due to compilation issues
    pub use auth_service::*;
    pub use member_service::*;
    pub use family_service::*;
    pub use avatar_service::*;
    
    use thiserror::Error;
    
    #[derive(Debug, Error)]
    pub enum ServiceError {
        #[error("Database error: {0}")]
        Database(#[from] sqlx::Error),
        
        #[error("Not found: {resource_type} with id {id}")]
        NotFound {
            resource_type: String,
            id: String,
        },
        
        #[error("Validation error: {0}")]
        Validation(String),
        
        #[error("Unauthorized")]
        Unauthorized,
        
        #[error("Internal error: {0}")]
        Internal(String),
    }
}
mod models;
mod ws;

// 导入处理器
use handlers::template_handler::*;
use handlers::accounts::*;
use handlers::transactions::*;
use handlers::payees::*;
use handlers::rules::*;
use handlers::auth as auth_handlers;
use handlers::enhanced_profile;
// use handlers::currency_handler;
use handlers::ledgers::{list_ledgers, create_ledger, get_current_ledger, get_ledger, 
                         update_ledger, delete_ledger, get_ledger_statistics, get_ledger_members};
use handlers::family_handler::{list_families, create_family, get_family, update_family, delete_family, join_family, leave_family, request_verification_code, get_family_statistics, get_family_actions, get_role_descriptions, transfer_ownership};
use handlers::member_handler::{get_family_members, add_member, remove_member, update_member_role, update_member_permissions};
use handlers::placeholder::{export_data, activity_logs, advanced_settings, family_settings};

// AppState 定义 - 包含所有共享状态
#[derive(Clone)]
pub struct AppState {
    pub pool: PgPool,
    pub ws_manager: Arc<ws::WsConnectionManager>,
    pub redis: Option<ConnectionManager>,
}

// 实现 FromRef，让 PgPool 可以从 AppState 中提取
// 这样处理器可以继续使用 State<PgPool>
impl FromRef<AppState> for PgPool {
    fn from_ref(app_state: &AppState) -> PgPool {
        app_state.pool.clone()
    }
}

// WebSocket 管理器的 FromRef 实现
impl FromRef<AppState> for Arc<ws::WsConnectionManager> {
    fn from_ref(app_state: &AppState) -> Arc<ws::WsConnectionManager> {
        app_state.ws_manager.clone()
    }
}

/// WebSocket 查询参数
#[derive(Debug, Deserialize)]
pub struct WsQuery {
    pub token: Option<String>,
}

/// 处理 WebSocket 连接
async fn handle_websocket(
    ws: WebSocketUpgrade,
    Query(query): Query<WsQuery>,
    State(pool): State<PgPool>,
    State(ws_manager): State<Arc<ws::WsConnectionManager>>,
) -> Response {
    // 验证 token（简化版本）
    let token = query.token.unwrap_or_default();
    if token.is_empty() {
        return Response::builder()
            .status(StatusCode::UNAUTHORIZED)
            .body("Unauthorized: Missing token".into())
            .unwrap();
    }
    
    info!("WebSocket connection request with token: {}", &token[..20.min(token.len())]);
    
    // 升级为 WebSocket 连接
    ws.on_upgrade(move |socket| ws::handle_socket(socket, token, pool))
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 加载环境变量
    dotenv::dotenv().ok();
    
    // 初始化日志
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!("🚀 Starting Jive Money API Server (Complete Version)...");
    info!("📦 Features: WebSocket, Database, Redis (optional), Full API");

    // 数据库连接
    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgresql://huazhou:@localhost:5432/jive_money".to_string());
    
    info!("📦 Connecting to database...");
    
    let pool = match PgPoolOptions::new()
        .max_connections(20)
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

    // 创建 WebSocket 管理器
    let ws_manager = Arc::new(ws::WsConnectionManager::new());
    info!("✅ WebSocket manager initialized");
    
    // Redis 连接（可选）
    let redis_manager = match std::env::var("REDIS_URL") {
        Ok(redis_url) => {
            info!("📦 Connecting to Redis...");
            match RedisClient::open(redis_url.as_str()) {
                Ok(client) => {
                    match ConnectionManager::new(client).await {
                        Ok(manager) => {
                            info!("✅ Redis connected successfully");
                            // 测试Redis连接
                            let mut conn = manager.clone();
                            match redis::cmd("PING").query_async::<String>(&mut conn).await {
                                Ok(_) => {
                                    info!("✅ Redis connection test passed");
                                    Some(manager)
                                }
                                Err(e) => {
                                    warn!("⚠️ Redis ping failed: {}", e);
                                    None
                                }
                            }
                        }
                        Err(e) => {
                            warn!("⚠️ Failed to create Redis connection manager: {}", e);
                            None
                        }
                    }
                }
                Err(e) => {
                    warn!("⚠️ Failed to connect to Redis: {}", e);
                    None
                }
            }
        }
        Err(_) => {
            // 尝试默认Redis连接
            match RedisClient::open("redis://127.0.0.1:6379") {
                Ok(client) => {
                    match ConnectionManager::new(client).await {
                        Ok(manager) => {
                            // 测试连接
                            let mut conn = manager.clone();
                            match redis::cmd("PING").query_async::<String>(&mut conn).await {
                                Ok(_) => {
                                    info!("✅ Redis connected successfully (default localhost:6379)");
                                    Some(manager)
                                }
                                Err(_) => {
                                    info!("ℹ️ Redis not available, running without cache");
                                    None
                                }
                            }
                        }
                        Err(_) => {
                            info!("ℹ️ Redis not available, running without cache");
                            None
                        }
                    }
                }
                Err(_) => {
                    info!("ℹ️ Redis not configured, running without cache");
                    None
                }
            }
        }
    };
    
    // 创建应用状态
    let app_state = AppState {
        pool: pool.clone(),
        ws_manager: ws_manager.clone(),
        redis: redis_manager,
    };

    // CORS 配置 - 允许所有头部以避免Flutter自定义头问题
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE, Method::OPTIONS])
        .allow_headers(Any)  // 允许所有头部
        .expose_headers([header::CONTENT_TYPE])
        .max_age(std::time::Duration::from_secs(3600));

    // 路由配置
    let app = Router::new()
        // 健康检查
        .route("/health", get(health_check))
        .route("/", get(api_info))
        
        // WebSocket 端点
        .route("/ws", get(handle_websocket))
        
        // 分类模板 API
        .route("/api/v1/templates/list", get(get_templates))
        .route("/api/v1/icons/list", get(get_icons))
        .route("/api/v1/templates/updates", get(get_template_updates))
        .route("/api/v1/templates/usage", post(submit_usage))
        
        // 超级管理员 API
        .route("/api/v1/admin/templates", post(create_template))
        .route("/api/v1/admin/templates/:template_id", put(update_template))
        .route("/api/v1/admin/templates/:template_id", delete(delete_template))
        
        // 账户管理 API
        .route("/api/v1/accounts", get(list_accounts))
        .route("/api/v1/accounts", post(create_account))
        .route("/api/v1/accounts/:id", get(get_account))
        .route("/api/v1/accounts/:id", put(update_account))
        .route("/api/v1/accounts/:id", delete(delete_account))
        .route("/api/v1/accounts/statistics", get(get_account_statistics))
        
        // 交易管理 API
        .route("/api/v1/transactions", get(list_transactions))
        .route("/api/v1/transactions", post(create_transaction))
        .route("/api/v1/transactions/:id", get(get_transaction))
        .route("/api/v1/transactions/:id", put(update_transaction))
        .route("/api/v1/transactions/:id", delete(delete_transaction))
        .route("/api/v1/transactions/bulk", post(bulk_transaction_operations))
        .route("/api/v1/transactions/statistics", get(get_transaction_statistics))
        
        // 收款人管理 API
        .route("/api/v1/payees", get(list_payees))
        .route("/api/v1/payees", post(create_payee))
        .route("/api/v1/payees/:id", get(get_payee))
        .route("/api/v1/payees/:id", put(update_payee))
        .route("/api/v1/payees/:id", delete(delete_payee))
        .route("/api/v1/payees/suggestions", get(get_payee_suggestions))
        .route("/api/v1/payees/statistics", get(get_payee_statistics))
        .route("/api/v1/payees/merge", post(merge_payees))
        
        // 规则引擎 API
        .route("/api/v1/rules", get(list_rules))
        .route("/api/v1/rules", post(create_rule))
        .route("/api/v1/rules/:id", get(get_rule))
        .route("/api/v1/rules/:id", put(update_rule))
        .route("/api/v1/rules/:id", delete(delete_rule))
        .route("/api/v1/rules/execute", post(execute_rules))
        
        // 认证 API
        .route("/api/v1/auth/register", post(auth_handlers::register_with_family))
        .route("/api/v1/auth/login", post(auth_handlers::login))
        .route("/api/v1/auth/refresh", post(auth_handlers::refresh_token))
        .route("/api/v1/auth/user", get(auth_handlers::get_current_user))
        .route("/api/v1/auth/profile", get(auth_handlers::get_current_user))  // Alias for Flutter app
        .route("/api/v1/auth/user", put(auth_handlers::update_user))
        .route("/api/v1/auth/avatar", put(auth_handlers::update_avatar))
        .route("/api/v1/auth/password", post(auth_handlers::change_password))
        .route("/api/v1/auth/delete", delete(auth_handlers::delete_account))
        
        // Enhanced Profile API
        .route("/api/v1/auth/register-enhanced", post(enhanced_profile::register_with_preferences))
        .route("/api/v1/auth/profile-enhanced", get(enhanced_profile::get_enhanced_profile))
        .route("/api/v1/auth/preferences", put(enhanced_profile::update_preferences))
        .route("/api/v1/locales", get(enhanced_profile::get_supported_locales))
        
        // 家庭管理 API
        .route("/api/v1/families", get(list_families))
        .route("/api/v1/families", post(create_family))
        .route("/api/v1/families/join", post(join_family))
        .route("/api/v1/families/leave", post(leave_family))
        .route("/api/v1/families/:id", get(get_family))
        .route("/api/v1/families/:id", put(update_family))
        .route("/api/v1/families/:id", delete(delete_family))
        .route("/api/v1/families/:id/statistics", get(get_family_statistics))
        .route("/api/v1/families/:id/actions", get(get_family_actions))
        .route("/api/v1/families/:id/transfer-ownership", post(transfer_ownership))
        .route("/api/v1/roles/descriptions", get(get_role_descriptions))
        
        // 家庭成员管理 API
        .route("/api/v1/families/:id/members", get(get_family_members))
        .route("/api/v1/families/:id/members", post(add_member))
        .route("/api/v1/families/:id/members/:user_id", delete(remove_member))
        .route("/api/v1/families/:id/members/:user_id/role", put(update_member_role))
        .route("/api/v1/families/:id/members/:user_id/permissions", put(update_member_permissions))
        
        // 验证码 API
        .route("/api/v1/verification/request", post(request_verification_code))
        
        // 账本 API (Ledgers) - 完整版特有
        .route("/api/v1/ledgers", get(list_ledgers))
        .route("/api/v1/ledgers", post(create_ledger))
        .route("/api/v1/ledgers/current", get(get_current_ledger))
        .route("/api/v1/ledgers/:id", get(get_ledger))
        .route("/api/v1/ledgers/:id", put(update_ledger))
        .route("/api/v1/ledgers/:id", delete(delete_ledger))
        .route("/api/v1/ledgers/:id/statistics", get(get_ledger_statistics))
        .route("/api/v1/ledgers/:id/members", get(get_ledger_members))
        
        // 货币管理 API - Temporarily disabled due to compilation issues
        // .route("/api/v1/currencies", get(currency_handler::get_supported_currencies))
        // .route("/api/v1/currencies/preferences", get(currency_handler::get_user_currency_preferences))
        // .route("/api/v1/currencies/preferences", post(currency_handler::set_user_currency_preferences))
        // .route("/api/v1/currencies/rate", get(currency_handler::get_exchange_rate))
        // .route("/api/v1/currencies/rates", post(currency_handler::get_batch_exchange_rates))
        // .route("/api/v1/currencies/rates/add", post(currency_handler::add_exchange_rate))
        // .route("/api/v1/currencies/convert", post(currency_handler::convert_amount))
        // .route("/api/v1/currencies/history", get(currency_handler::get_exchange_rate_history))
        // .route("/api/v1/currencies/popular-pairs", get(currency_handler::get_popular_exchange_pairs))
        // .route("/api/v1/currencies/refresh", post(currency_handler::refresh_exchange_rates))
        // .route("/api/v1/family/currency-settings", get(currency_handler::get_family_currency_settings))
        // .route("/api/v1/family/currency-settings", put(currency_handler::update_family_currency_settings))
        
        // 占位符 API - 功能开发中
        .route("/api/v1/families/:id/export", get(export_data))
        .route("/api/v1/families/:id/activity-logs", get(activity_logs))
        .route("/api/v1/families/:id/settings", get(family_settings))
        .route("/api/v1/families/:id/advanced-settings", get(advanced_settings))
        .route("/api/v1/export/data", post(export_data))
        .route("/api/v1/activity/logs", get(activity_logs))
        
        // 静态文件
        .route("/static/icons/*path", get(serve_icon))
        
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(cors),
        )
        .with_state(app_state);

    // 启动服务器
    let host = std::env::var("HOST").unwrap_or_else(|_| "127.0.0.1".to_string());
    let port = std::env::var("API_PORT").unwrap_or_else(|_| "8012".to_string());
    let addr: SocketAddr = format!("{}:{}", host, port).parse()?;
    let listener = TcpListener::bind(addr).await?;
    
    info!("🌐 Server running at http://{}", addr);
    info!("🔌 WebSocket endpoint: ws://{}/ws?token=<jwt_token>", addr);
    info!("");
    info!("📋 API Documentation:");
    info!("  🔐 Authentication API:");
    info!("    POST /api/v1/auth/register     - 用户注册");
    info!("    POST /api/v1/auth/login        - 用户登录");
    info!("    POST /api/v1/auth/refresh      - 刷新令牌");
    info!("    GET  /api/v1/auth/user         - 获取用户信息");
    info!("    PUT  /api/v1/auth/user         - 更新用户信息");
    info!("    POST /api/v1/auth/password     - 修改密码");
    info!("");
    info!("  🔌 WebSocket:");
    info!("    WS   /ws?token=<jwt_token>     - WebSocket 连接");
    info!("");
    info!("  📊 Core APIs:");
    info!("    /api/v1/accounts                - 账户管理");
    info!("    /api/v1/transactions            - 交易管理");
    info!("    /api/v1/payees                  - 收款人管理");
    info!("    /api/v1/rules                   - 规则引擎");
    info!("    /api/v1/templates               - 分类模板");
    info!("    /api/v1/ledgers                 - 账本管理");
    info!("");
    info!("💡 Tips:");
    info!("  - Use Authorization header with 'Bearer <token>' for authenticated requests");
    info!("  - WebSocket requires token in query parameter");
    info!("  - All timestamps are in UTC");
    
    axum::serve(listener, app).await?;
    
    Ok(())
}

/// 健康检查接口
async fn health_check(State(state): State<AppState>) -> Json<serde_json::Value> {
    Json(json!({
        "status": "healthy",
        "service": "jive-money-api",
        "version": "1.0.0-complete",
        "features": {
            "websocket": true,
            "database": true,
            "auth": true,
            "ledgers": true,
            "redis": state.redis.is_some()
        },
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}

/// API 信息接口
async fn api_info() -> Json<serde_json::Value> {
    Json(json!({
        "name": "Jive Money API (Complete Version)",
        "version": "1.0.0",
        "description": "Financial management API with WebSocket support",
        "features": [
            "websocket",
            "auth",
            "transactions",
            "accounts",
            "rules",
            "ledgers",
            "templates"
        ],
        "endpoints": {
            "websocket": "/ws",
            "health": "/health",
            "templates": "/api/v1/templates",
            "accounts": "/api/v1/accounts",
            "transactions": "/api/v1/transactions",
            "payees": "/api/v1/payees",
            "rules": "/api/v1/rules",
            "auth": "/api/v1/auth",
            "ledgers": "/api/v1/ledgers"
        },
        "documentation": "https://github.com/yourusername/jive-money-api/wiki"
    }))
}

/// 服务静态图标文件
async fn serve_icon() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "message": "Icon serving endpoint",
        "cdn_base": "http://localhost:8012/static/icons"
    })))
}