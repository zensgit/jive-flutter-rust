//! Mock API Server for Jive Money
//! 
//! A standalone API server without database dependencies for development
//! Listens on port 3020

use axum::{
    http::{header, Method, StatusCode},
    response::Json,
    routing::{get, post, put, delete},
    Router,
};
use serde_json::json;
use tower::ServiceBuilder;
use tower_http::{
    cors::{Any, CorsLayer},
    trace::TraceLayer,
};
use tracing::info;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use std::net::SocketAddr;
use tokio::net::TcpListener;
use uuid::Uuid;

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!("🚀 Starting Jive Money Mock API Server...");

    // CORS configuration
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
        .allow_headers([header::CONTENT_TYPE, header::AUTHORIZATION]);

    // Routes
    let app = Router::new()
        // Health check
        .route("/health", get(health_check))
        .route("/", get(api_info))
        
        // Auth endpoints
        .route("/api/v1/auth/login", post(mock_login))
        .route("/api/v1/auth/register", post(mock_register))
        .route("/api/v1/auth/profile", get(mock_profile))
        .route("/api/v1/auth/logout", post(mock_logout))
        .route("/api/v1/auth/refresh", post(mock_refresh_token))
        
        // Ledger endpoints
        .route("/api/v1/ledgers", get(mock_list_ledgers))
        .route("/api/v1/ledgers", post(mock_create_ledger))
        .route("/api/v1/ledgers/current", get(mock_current_ledger))
        
        // Account endpoints
        .route("/api/v1/accounts", get(mock_list_accounts))
        .route("/api/v1/accounts", post(mock_create_account))
        .route("/api/v1/accounts/:id", get(mock_get_account))
        .route("/api/v1/accounts/:id", put(mock_update_account))
        .route("/api/v1/accounts/:id", delete(mock_delete_account))
        
        // Transaction endpoints
        .route("/api/v1/transactions", get(mock_list_transactions))
        .route("/api/v1/transactions", post(mock_create_transaction))
        .route("/api/v1/transactions/categories", get(mock_transaction_categories))
        
        // Budget endpoints
        .route("/api/v1/budgets", get(mock_list_budgets))
        .route("/api/v1/budgets", post(mock_create_budget))
        
        // Category template endpoints (for compatibility with existing code)
        .route("/api/v1/templates/list", get(mock_templates_list))
        .route("/api/v1/icons/list", get(mock_icons_list))
        
        // Test endpoints
        .route("/api/v1/test", get(test_endpoint))
        
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(cors),
        );

    // Start server on port 3020
    let addr: SocketAddr = "127.0.0.1:3020".parse()?;
    let listener = TcpListener::bind(addr).await?;
    
    info!("🌐 Mock API Server running at http://{}", addr);
    info!("📋 Available endpoints:");
    info!("  GET /health - Health check");
    info!("  GET /api/v1/auth/login - Mock login");
    info!("  GET /api/v1/auth/profile - Mock user profile");
    info!("  GET /api/v1/test - Test endpoint");
    
    axum::serve(listener, app).await?;
    
    Ok(())
}

async fn health_check() -> Json<serde_json::Value> {
    Json(json!({
        "status": "healthy",
        "service": "jive-money-api-mock",
        "version": "1.0.0"
    }))
}

async fn api_info() -> Json<serde_json::Value> {
    Json(json!({
        "name": "Jive Money Mock API",
        "version": "1.0.0",
        "description": "Mock API server for development",
        "endpoints": {
            "health": "/health",
            "auth": {
                "login": "/api/v1/auth/login",
                "profile": "/api/v1/auth/profile"
            },
            "test": "/api/v1/test"
        }
    }))
}

async fn mock_login() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "token": "mock-jwt-token-12345",
            "user": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "email": "test@example.com",
                "name": "Test User"
            }
        }
    })))
}

async fn mock_profile() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "email": "test@example.com",
            "name": "Test User",
            "created_at": "2024-01-01T00:00:00Z"
        }
    })))
}

async fn test_endpoint() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "message": "API is working!",
        "timestamp": chrono::Utc::now().to_rfc3339(),
        "port": 3020
    })))
}

// Additional Auth endpoints
async fn mock_register() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "token": "mock-jwt-token-register",
            "user": {
                "id": Uuid::new_v4().to_string(),
                "email": "newuser@example.com",
                "name": "New User"
            }
        }
    })))
}

async fn mock_logout() -> StatusCode {
    StatusCode::OK
}

async fn mock_refresh_token() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "token": "mock-jwt-token-refreshed",
            "expires_at": "2025-12-31T23:59:59Z"
        }
    })))
}

// Ledger endpoints
async fn mock_list_ledgers() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": [
            {
                "id": Uuid::new_v4().to_string(),
                "name": "Personal Finance",
                "currency": "USD",
                "created_at": "2024-01-01T00:00:00Z"
            },
            {
                "id": Uuid::new_v4().to_string(),
                "name": "Business",
                "currency": "USD",
                "created_at": "2024-01-15T00:00:00Z"
            }
        ]
    })))
}

async fn mock_create_ledger() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "id": Uuid::new_v4().to_string(),
            "name": "New Ledger",
            "currency": "USD",
            "created_at": chrono::Utc::now().to_rfc3339()
        }
    })))
}

async fn mock_current_ledger() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "id": "550e8400-e29b-41d4-a716-446655440001",
            "name": "Personal Finance",
            "currency": "USD",
            "created_at": "2024-01-01T00:00:00Z"
        }
    })))
}

// Account endpoints
async fn mock_list_accounts() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": [
            {
                "id": Uuid::new_v4().to_string(),
                "name": "Checking Account",
                "type": "checking",
                "balance": 5000.00,
                "currency": "USD"
            },
            {
                "id": Uuid::new_v4().to_string(),
                "name": "Savings Account",
                "type": "savings",
                "balance": 10000.00,
                "currency": "USD"
            },
            {
                "id": Uuid::new_v4().to_string(),
                "name": "Credit Card",
                "type": "credit_card",
                "balance": -1500.00,
                "currency": "USD"
            }
        ]
    })))
}

async fn mock_create_account() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "id": Uuid::new_v4().to_string(),
            "name": "New Account",
            "type": "checking",
            "balance": 0.00,
            "currency": "USD",
            "created_at": chrono::Utc::now().to_rfc3339()
        }
    })))
}

async fn mock_get_account() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "id": Uuid::new_v4().to_string(),
            "name": "Checking Account",
            "type": "checking",
            "balance": 5000.00,
            "currency": "USD",
            "transactions": []
        }
    })))
}

async fn mock_update_account() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "id": Uuid::new_v4().to_string(),
            "name": "Updated Account",
            "type": "checking",
            "balance": 5000.00,
            "currency": "USD"
        }
    })))
}

async fn mock_delete_account() -> StatusCode {
    StatusCode::NO_CONTENT
}

// Transaction endpoints
async fn mock_list_transactions() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": [
            {
                "id": Uuid::new_v4().to_string(),
                "date": "2024-03-01",
                "description": "Grocery Store",
                "amount": -150.00,
                "category": "Food",
                "account_id": Uuid::new_v4().to_string()
            },
            {
                "id": Uuid::new_v4().to_string(),
                "date": "2024-03-02",
                "description": "Salary",
                "amount": 5000.00,
                "category": "Income",
                "account_id": Uuid::new_v4().to_string()
            }
        ]
    })))
}

async fn mock_create_transaction() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "id": Uuid::new_v4().to_string(),
            "date": chrono::Utc::now().format("%Y-%m-%d").to_string(),
            "description": "New Transaction",
            "amount": 100.00,
            "category": "Other",
            "account_id": Uuid::new_v4().to_string()
        }
    })))
}

async fn mock_transaction_categories() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": [
            {"id": "1", "name": "Food", "icon": "restaurant", "type": "expense"},
            {"id": "2", "name": "Transport", "icon": "directions_car", "type": "expense"},
            {"id": "3", "name": "Shopping", "icon": "shopping_cart", "type": "expense"},
            {"id": "4", "name": "Entertainment", "icon": "movie", "type": "expense"},
            {"id": "5", "name": "Salary", "icon": "account_balance_wallet", "type": "income"},
            {"id": "6", "name": "Investment", "icon": "trending_up", "type": "income"}
        ]
    })))
}

// Budget endpoints
async fn mock_list_budgets() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": [
            {
                "id": Uuid::new_v4().to_string(),
                "name": "Monthly Budget",
                "amount": 3000.00,
                "spent": 1500.00,
                "period": "monthly",
                "category": "All"
            }
        ]
    })))
}

async fn mock_create_budget() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "id": Uuid::new_v4().to_string(),
            "name": "New Budget",
            "amount": 1000.00,
            "spent": 0.00,
            "period": "monthly",
            "category": "Food"
        }
    })))
}

// Category template endpoints
async fn mock_templates_list() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "templates": [
                {
                    "id": "personal",
                    "name": "Personal Finance",
                    "categories": [
                        {"name": "Food", "icon": "restaurant", "type": "expense"},
                        {"name": "Transport", "icon": "directions_car", "type": "expense"},
                        {"name": "Salary", "icon": "account_balance_wallet", "type": "income"}
                    ]
                },
                {
                    "id": "business",
                    "name": "Business",
                    "categories": [
                        {"name": "Sales", "icon": "point_of_sale", "type": "income"},
                        {"name": "Marketing", "icon": "campaign", "type": "expense"},
                        {"name": "Operations", "icon": "business", "type": "expense"}
                    ]
                }
            ]
        }
    })))
}

async fn mock_icons_list() -> Result<Json<serde_json::Value>, StatusCode> {
    Ok(Json(json!({
        "success": true,
        "data": {
            "icons": [
                {"id": "restaurant", "name": "Restaurant", "category": "food"},
                {"id": "shopping_cart", "name": "Shopping", "category": "shopping"},
                {"id": "directions_car", "name": "Car", "category": "transport"},
                {"id": "home", "name": "Home", "category": "housing"},
                {"id": "movie", "name": "Entertainment", "category": "entertainment"}
            ]
        }
    })))
}