//! Jive Money API Server - Simple Version
//! 
//! 测试版本，不连接数据库，返回模拟数据

use axum::{response::Json, routing::get, Router};
use serde_json::json;
use std::net::SocketAddr;
use tokio::net::TcpListener;
use jive_money_api::middleware::cors::create_cors_layer;
use tracing::info;
// tracing_subscriber is used via fully-qualified path below
// chrono is referenced via fully-qualified path below

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // 初始化日志
    tracing_subscriber::fmt::init();

    info!("🚀 Starting Jive Money API Server (Simple Version)...");

    // 统一使用中间件 CORS（支持 CORS_DEV=1）
    let cors = create_cors_layer();

    // 路由配置
    let app = Router::new()
        .route("/health", get(health_check))
        .route("/", get(api_info))
        .route("/api/v1/templates/list", get(get_mock_templates))
        .route("/api/v1/icons/list", get(get_mock_icons))
        .layer(cors);

    // 启动服务器
    let port = std::env::var("API_PORT").unwrap_or_else(|_| "8012".to_string());
    let addr: SocketAddr = format!("127.0.0.1:{}", port).parse()?;
    let listener = TcpListener::bind(addr).await?;
    
    info!("🌐 Server running at http://{}", addr);
    info!("📋 API Endpoints:");
    info!("  GET  /health                   - 健康检查");
    info!("  GET  /api/v1/templates/list    - 获取模板列表");
    info!("  GET  /api/v1/icons/list        - 获取图标列表");
    info!("💡 Test with: curl http://{}/api/v1/templates/list", addr);
    
    axum::serve(listener, app).await?;
    
    Ok(())
}

async fn health_check() -> Json<serde_json::Value> {
    Json(json!({
        "status": "healthy",
        "service": "jive-money-api",
        "version": "1.0.0-simple",
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}

async fn api_info() -> Json<serde_json::Value> {
    Json(json!({
        "name": "Jive Money API (Simple)",
        "version": "1.0.0",
        "description": "Category template management API - Mock Data Version",
        "endpoints": {
            "templates": "/api/v1/templates/list",
            "icons": "/api/v1/icons/list"
        }
    }))
}

async fn get_mock_templates() -> Json<serde_json::Value> {
    Json(json!({
        "templates": [
            {
                "id": "tmpl-001",
                "name": "工资收入",
                "name_en": "Salary",
                "name_zh": "工资收入",
                "description": "月度工资收入",
                "classification": "income",
                "color": "#10B981",
                "icon": "💰",
                "category_group": "income",
                "is_featured": true,
                "is_active": true,
                "global_usage_count": 15420,
                "tags": ["必备", "常用"],
                "version": "1.0.0",
                "created_at": "2024-01-01T00:00:00Z",
                "updated_at": "2024-01-01T00:00:00Z"
            },
            {
                "id": "tmpl-002",
                "name": "餐饮美食",
                "name_en": "Food & Dining",
                "name_zh": "餐饮美食",
                "description": "日常餐饮支出",
                "classification": "expense",
                "color": "#EF4444",
                "icon": "🍽️",
                "category_group": "dailyExpense",
                "is_featured": true,
                "is_active": true,
                "global_usage_count": 25680,
                "tags": ["热门", "必备"],
                "version": "1.0.0",
                "created_at": "2024-01-01T00:00:00Z",
                "updated_at": "2024-01-01T00:00:00Z"
            },
            {
                "id": "tmpl-003",
                "name": "交通出行",
                "name_en": "Transportation",
                "name_zh": "交通出行",
                "description": "各类交通费用",
                "classification": "expense",
                "color": "#F97316",
                "icon": "🚗",
                "category_group": "transportation",
                "is_featured": true,
                "is_active": true,
                "global_usage_count": 18350,
                "tags": ["必备"],
                "version": "1.0.0",
                "created_at": "2024-01-01T00:00:00Z",
                "updated_at": "2024-01-01T00:00:00Z"
            },
            {
                "id": "tmpl-004",
                "name": "购物消费",
                "name_en": "Shopping",
                "name_zh": "购物消费",
                "description": "日常购物支出",
                "classification": "expense",
                "color": "#F59E0B",
                "icon": "🛒",
                "category_group": "dailyExpense",
                "is_featured": false,
                "is_active": true,
                "global_usage_count": 12450,
                "tags": ["常用"],
                "version": "1.0.0",
                "created_at": "2024-01-01T00:00:00Z",
                "updated_at": "2024-01-01T00:00:00Z"
            },
            {
                "id": "tmpl-005",
                "name": "娱乐休闲",
                "name_en": "Entertainment",
                "name_zh": "娱乐休闲",
                "description": "娱乐休闲支出",
                "classification": "expense",
                "color": "#8B5CF6",
                "icon": "🎬",
                "category_group": "entertainmentSocial",
                "is_featured": false,
                "is_active": true,
                "global_usage_count": 9870,
                "tags": ["热门"],
                "version": "1.0.0",
                "created_at": "2024-01-01T00:00:00Z",
                "updated_at": "2024-01-01T00:00:00Z"
            }
        ],
        "version": "1.0.0",
        "last_updated": chrono::Utc::now().to_rfc3339(),
        "total": 5
    }))
}

async fn get_mock_icons() -> Json<serde_json::Value> {
    Json(json!({
        "icons": {
            "💰": "salary.png",
            "🍽️": "dining.png",
            "🚗": "transport.png",
            "🛒": "shopping.png",
            "🎬": "entertainment.png",
            "🏠": "housing.png",
            "🏥": "medical.png",
            "💳": "finance.png"
        },
        "cdn_base": "http://127.0.0.1:8080/static/icons",
        "version": "1.0.0"
    }))
}
