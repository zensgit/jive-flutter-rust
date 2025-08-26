use axum::{
    extract::State,
    http::StatusCode,
    response::Json,
    routing::{get, post},
    Router,
};
use serde::{Deserialize, Serialize};
use std::net::SocketAddr;
use tower_http::cors::CorsLayer;
use tracing_subscriber;
use uuid::Uuid;
use chrono::{DateTime, Utc};

#[derive(Clone)]
struct AppState {
    // 在实际应用中，这里会包含数据库连接等
}

#[tokio::main]
async fn main() {
    // 初始化日志
    tracing_subscriber::fmt::init();

    let state = AppState {};

    // 构建路由
    let app = Router::new()
        .route("/", get(root))
        .route("/health", get(health_check))
        .route("/api/transactions", get(get_transactions))
        .route("/api/transactions", post(create_transaction))
        .route("/api/accounts", get(get_accounts))
        .route("/api/budget", get(get_budget))
        .route("/api/reports/summary", get(get_summary))
        .layer(CorsLayer::permissive())
        .with_state(state);

    let port = std::env::var("API_PORT")
        .unwrap_or_else(|_| "8012".to_string())
        .parse::<u16>()
        .unwrap_or(8012);
    
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    println!("🚀 Jive Money API Server running at http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn root() -> &'static str {
    "Jive Money API Server v1.0.0"
}

async fn health_check() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "healthy".to_string(),
        timestamp: Utc::now(),
    })
}

#[derive(Serialize)]
struct HealthResponse {
    status: String,
    timestamp: DateTime<Utc>,
}

// 交易相关
#[derive(Serialize, Deserialize)]
struct Transaction {
    id: String,
    amount: f64,
    description: String,
    category: String,
    date: DateTime<Utc>,
    transaction_type: String, // income or expense
}

async fn get_transactions() -> Json<Vec<Transaction>> {
    // 模拟数据
    let transactions = vec![
        Transaction {
            id: Uuid::new_v4().to_string(),
            amount: -35.0,
            description: "星巴克".to_string(),
            category: "餐饮".to_string(),
            date: Utc::now(),
            transaction_type: "expense".to_string(),
        },
        Transaction {
            id: Uuid::new_v4().to_string(),
            amount: 15000.0,
            description: "工资".to_string(),
            category: "收入".to_string(),
            date: Utc::now(),
            transaction_type: "income".to_string(),
        },
    ];
    
    Json(transactions)
}

async fn create_transaction(
    Json(payload): Json<CreateTransactionRequest>,
) -> (StatusCode, Json<Transaction>) {
    let transaction = Transaction {
        id: Uuid::new_v4().to_string(),
        amount: payload.amount,
        description: payload.description,
        category: payload.category,
        date: Utc::now(),
        transaction_type: if payload.amount < 0.0 { "expense" } else { "income" }.to_string(),
    };
    
    (StatusCode::CREATED, Json(transaction))
}

#[derive(Deserialize)]
struct CreateTransactionRequest {
    amount: f64,
    description: String,
    category: String,
}

// 账户相关
#[derive(Serialize)]
struct Account {
    id: String,
    name: String,
    balance: f64,
    account_type: String,
}

async fn get_accounts() -> Json<Vec<Account>> {
    let accounts = vec![
        Account {
            id: Uuid::new_v4().to_string(),
            name: "储蓄账户".to_string(),
            balance: 50000.0,
            account_type: "savings".to_string(),
        },
        Account {
            id: Uuid::new_v4().to_string(),
            name: "支票账户".to_string(),
            balance: 25360.0,
            account_type: "checking".to_string(),
        },
        Account {
            id: Uuid::new_v4().to_string(),
            name: "投资账户".to_string(),
            balance: 50000.0,
            account_type: "investment".to_string(),
        },
    ];
    
    Json(accounts)
}

// 预算相关
#[derive(Serialize)]
struct Budget {
    category: String,
    limit: f64,
    spent: f64,
    remaining: f64,
}

async fn get_budget() -> Json<Vec<Budget>> {
    let budgets = vec![
        Budget {
            category: "餐饮".to_string(),
            limit: 3000.0,
            spent: 1200.0,
            remaining: 1800.0,
        },
        Budget {
            category: "交通".to_string(),
            limit: 1000.0,
            spent: 450.0,
            remaining: 550.0,
        },
        Budget {
            category: "购物".to_string(),
            limit: 5000.0,
            spent: 3200.0,
            remaining: 1800.0,
        },
    ];
    
    Json(budgets)
}

// 报表相关
#[derive(Serialize)]
struct Summary {
    total_assets: f64,
    total_liabilities: f64,
    net_worth: f64,
    monthly_income: f64,
    monthly_expenses: f64,
    savings_rate: f64,
}

async fn get_summary() -> Json<Summary> {
    let summary = Summary {
        total_assets: 125360.0,
        total_liabilities: 0.0,
        net_worth: 125360.0,
        monthly_income: 15000.0,
        monthly_expenses: 8520.0,
        savings_rate: 0.432,
    };
    
    Json(summary)
}