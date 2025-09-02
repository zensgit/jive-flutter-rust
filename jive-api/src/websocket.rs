//! WebSocket实时更新模块
//! 提供实时数据推送功能

use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State, Query,
    },
    response::Response,
};
use futures_util::{sink::SinkExt, stream::{StreamExt, SplitSink}};
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row};
use std::{
    collections::HashMap,
    sync::Arc,
    time::Duration,
};
use tokio::sync::{Mutex, RwLock};
use uuid::Uuid;
use tracing::{info, warn, error};
use crate::AppState;

/// WebSocket连接管理器
pub struct WsConnectionManager {
    /// 用户ID到连接的映射
    connections: Arc<RwLock<HashMap<Uuid, Arc<Mutex<WebSocket>>>>>,
    /// 订阅管理：主题 -> 用户ID列表
    subscriptions: Arc<RwLock<HashMap<String, Vec<Uuid>>>>,
}

impl WsConnectionManager {
    pub fn new() -> Self {
        Self {
            connections: Arc::new(RwLock::new(HashMap::new())),
            subscriptions: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    /// 添加新连接
    pub async fn add_connection(&self, user_id: Uuid, socket: WebSocket) {
        let mut connections = self.connections.write().await;
        connections.insert(user_id, Arc::new(Mutex::new(socket)));
        info!("User {} connected via WebSocket", user_id);
    }

    /// 移除连接
    pub async fn remove_connection(&self, user_id: &Uuid) {
        let mut connections = self.connections.write().await;
        connections.remove(user_id);
        
        // 清理订阅
        let mut subscriptions = self.subscriptions.write().await;
        for (_, users) in subscriptions.iter_mut() {
            users.retain(|id| id != user_id);
        }
        
        info!("User {} disconnected from WebSocket", user_id);
    }

    /// 订阅主题
    pub async fn subscribe(&self, user_id: Uuid, topic: String) {
        let mut subscriptions = self.subscriptions.write().await;
        subscriptions
            .entry(topic.clone())
            .or_insert_with(Vec::new)
            .push(user_id);
        info!("User {} subscribed to topic: {}", user_id, topic);
    }

    /// 取消订阅
    pub async fn unsubscribe(&self, user_id: &Uuid, topic: &str) {
        let mut subscriptions = self.subscriptions.write().await;
        if let Some(users) = subscriptions.get_mut(topic) {
            users.retain(|id| id != user_id);
            if users.is_empty() {
                subscriptions.remove(topic);
            }
        }
        info!("User {} unsubscribed from topic: {}", user_id, topic);
    }

    /// 向特定用户发送消息
    pub async fn send_to_user(&self, user_id: &Uuid, message: WsMessage) -> Result<(), String> {
        let connections = self.connections.read().await;
        if let Some(socket) = connections.get(user_id) {
            let mut socket = socket.lock().await;
            let json = serde_json::to_string(&message).map_err(|e| e.to_string())?;
            socket.send(Message::Text(json)).await
                .map_err(|e| e.to_string())?;
            Ok(())
        } else {
            Err(format!("User {} not connected", user_id))
        }
    }

    /// 向订阅主题的所有用户广播消息
    pub async fn broadcast_to_topic(&self, topic: &str, message: WsMessage) {
        let subscriptions = self.subscriptions.read().await;
        if let Some(users) = subscriptions.get(topic) {
            for user_id in users {
                if let Err(e) = self.send_to_user(user_id, message.clone()).await {
                    warn!("Failed to send message to user {}: {}", user_id, e);
                }
            }
        }
    }

    /// 向家庭成员广播消息
    pub async fn broadcast_to_family(&self, family_id: Uuid, message: WsMessage) {
        let topic = format!("family:{}", family_id);
        self.broadcast_to_topic(&topic, message).await;
    }
}

/// WebSocket消息类型
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum WsMessage {
    /// 连接成功
    Connected { user_id: Uuid },
    
    /// 订阅确认
    Subscribed { topic: String },
    
    /// 取消订阅确认
    Unsubscribed { topic: String },
    
    /// 交易更新
    TransactionUpdate {
        transaction_id: Uuid,
        action: String, // created, updated, deleted
        data: serde_json::Value,
    },
    
    /// 账户余额更新
    AccountBalanceUpdate {
        account_id: Uuid,
        balance: f64,
        available_balance: f64,
    },
    
    /// 规则执行通知
    RuleExecuted {
        rule_id: Uuid,
        matched_count: i32,
        executed_at: chrono::DateTime<chrono::Utc>,
    },
    
    /// 收款人建议
    PayeeSuggestion {
        description: String,
        suggestions: Vec<String>,
    },
    
    /// 系统通知
    Notification {
        level: String, // info, warning, error
        title: String,
        message: String,
    },
    
    /// 心跳
    Ping,
    Pong,
    
    /// 错误
    Error {
        code: String,
        message: String,
    },
}

/// WebSocket客户端命令
#[derive(Debug, Deserialize)]
#[serde(tag = "command", content = "data")]
pub enum WsCommand {
    /// 订阅主题
    Subscribe { topic: String },
    
    /// 取消订阅
    Unsubscribe { topic: String },
    
    /// 心跳
    Ping,
    
    /// 请求数据
    Request {
        resource: String,
        params: serde_json::Value,
    },
}

/// WebSocket连接查询参数
#[derive(Debug, Deserialize)]
pub struct WsQuery {
    pub token: String,
}

/// 处理WebSocket连接
pub async fn handle_websocket(
    ws: WebSocketUpgrade,
    Query(query): Query<WsQuery>,
    State(app_state): State<AppState>,
) -> Response {
    // 验证JWT令牌
    let user_id = match validate_token(&query.token).await {
        Ok(id) => id,
        Err(e) => {
            warn!("WebSocket connection rejected: {}", e);
            return ws.on_upgrade(|mut socket| async move {
                let _ = socket.send(Message::Text(
                    serde_json::to_string(&WsMessage::Error {
                        code: "AUTH_FAILED".to_string(),
                        message: "Invalid authentication token".to_string(),
                    }).unwrap()
                )).await;
                let _ = socket.close().await;
            });
        }
    };

    // 获取用户家庭ID
    let family_id = get_user_family_id(&app_state.pool, user_id).await.ok();

    ws.on_upgrade(move |socket| handle_socket(socket, user_id, family_id, app_state.pool, app_state.ws_manager))
}

/// 处理WebSocket连接的主循环
async fn handle_socket(
    socket: WebSocket,
    user_id: Uuid,
    family_id: Option<Uuid>,
    pool: PgPool,
    manager: Arc<WsConnectionManager>,
) {
    // 分离发送和接收
    let (mut sender, mut receiver) = socket.split();
    
    // 发送连接成功消息
    if let Err(e) = sender.send(Message::Text(
        serde_json::to_string(&WsMessage::Connected { user_id }).unwrap()
    )).await {
        error!("Failed to send connected message: {}", e);
        return;
    }
    let sender = Arc::new(Mutex::new(sender));
    
    // 自动订阅家庭频道
    if let Some(fid) = family_id {
        manager.subscribe(user_id, format!("family:{}", fid)).await;
    }

    // 心跳定时器
    let heartbeat = tokio::spawn({
        let sender = sender.clone();
        async move {
            let mut interval = tokio::time::interval(Duration::from_secs(30));
            loop {
                interval.tick().await;
                let mut s = sender.lock().await;
                if s.send(Message::Text(
                    serde_json::to_string(&WsMessage::Ping).unwrap()
                )).await.is_err() {
                    break;
                }
            }
        }
    });

    // 消息处理循环
    while let Some(msg) = receiver.next().await {
        match msg {
            Ok(Message::Text(text)) => {
                if let Ok(command) = serde_json::from_str::<WsCommand>(&text) {
                    handle_command(
                        command,
                        user_id,
                        &pool,
                        &manager,
                        &sender,
                    ).await;
                }
            }
            Ok(Message::Close(_)) => {
                info!("WebSocket closed for user {}", user_id);
                break;
            }
            Err(e) => {
                error!("WebSocket error for user {}: {}", user_id, e);
                break;
            }
            _ => {}
        }
    }

    // 清理
    heartbeat.abort();
    manager.remove_connection(&user_id).await;
}

/// 处理客户端命令
async fn handle_command(
    command: WsCommand,
    user_id: Uuid,
    pool: &PgPool,
    manager: &Arc<WsConnectionManager>,
    sender: &Arc<Mutex<SplitSink<WebSocket, Message>>>,
) {
    match command {
        WsCommand::Subscribe { topic } => {
            // 验证用户是否有权限订阅该主题
            if validate_subscription(&topic, user_id, pool).await {
                manager.subscribe(user_id, topic.clone()).await;
                let _ = send_message(sender, WsMessage::Subscribed { topic }).await;
            } else {
                let _ = send_message(sender, WsMessage::Error {
                    code: "FORBIDDEN".to_string(),
                    message: "No permission to subscribe to this topic".to_string(),
                }).await;
            }
        }
        WsCommand::Unsubscribe { topic } => {
            manager.unsubscribe(&user_id, &topic).await;
            let _ = send_message(sender, WsMessage::Unsubscribed { topic }).await;
        }
        WsCommand::Ping => {
            let _ = send_message(sender, WsMessage::Pong).await;
        }
        WsCommand::Request { resource, params } => {
            // 处理数据请求
            handle_data_request(resource, params, user_id, pool, sender).await;
        }
    }
}

/// 发送消息辅助函数
async fn send_message(
    sender: &Arc<Mutex<SplitSink<WebSocket, Message>>>,
    message: WsMessage,
) -> Result<(), String> {
    let mut s = sender.lock().await;
    let json = serde_json::to_string(&message).map_err(|e| e.to_string())?;
    s.send(Message::Text(json)).await.map_err(|e| e.to_string())
}

/// 验证JWT令牌
async fn validate_token(token: &str) -> Result<Uuid, String> {
    use crate::auth::Claims;
    
    Claims::from_token(token)
        .map_err(|e| format!("Token validation failed: {:?}", e))?
        .user_id()
        .map_err(|e| format!("Failed to get user ID: {:?}", e))
}

/// 获取用户家庭ID
async fn get_user_family_id(pool: &PgPool, user_id: Uuid) -> Result<Uuid, String> {
    let result = sqlx::query("SELECT family_id FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| e.to_string())?;
    
    if let Some(row) = result {
        if let Ok(family_id) = row.try_get::<Option<Uuid>, _>("family_id") {
            return family_id.ok_or_else(|| "User has no family".to_string());
        }
    }
    
    Err("User not found".to_string())
}

/// 验证订阅权限
async fn validate_subscription(topic: &str, user_id: Uuid, pool: &PgPool) -> bool {
    // 实现基于主题的权限验证
    if topic.starts_with("family:") {
        // 验证用户是否属于该家庭
        if let Some(family_id) = topic.strip_prefix("family:") {
            if let Ok(fid) = Uuid::parse_str(family_id) {
                if let Ok(user_family) = get_user_family_id(pool, user_id).await {
                    return user_family == fid;
                }
            }
        }
    } else if topic.starts_with("user:") {
        // 验证是否是用户自己的频道
        if let Some(uid) = topic.strip_prefix("user:") {
            if let Ok(topic_user_id) = Uuid::parse_str(uid) {
                return topic_user_id == user_id;
            }
        }
    }
    
    false
}

/// 处理数据请求
async fn handle_data_request(
    resource: String,
    params: serde_json::Value,
    _user_id: Uuid,
    pool: &PgPool,
    sender: &Arc<Mutex<SplitSink<WebSocket, Message>>>,
) {
    // 根据资源类型处理请求
    match resource.as_str() {
        "account_balance" => {
            if let Some(account_id) = params.get("account_id").and_then(|v| v.as_str()) {
                if let Ok(aid) = Uuid::parse_str(account_id) {
                    // 查询账户余额
                    if let Ok(balance) = get_account_balance(pool, aid).await {
                        let _ = send_message(sender, WsMessage::AccountBalanceUpdate {
                            account_id: aid,
                            balance: balance.0,
                            available_balance: balance.1,
                        }).await;
                    }
                }
            }
        }
        _ => {
            let _ = send_message(sender, WsMessage::Error {
                code: "UNKNOWN_RESOURCE".to_string(),
                message: format!("Unknown resource: {}", resource),
            }).await;
        }
    }
}

/// 获取账户余额
async fn get_account_balance(pool: &PgPool, account_id: Uuid) -> Result<(f64, f64), String> {
    let result = sqlx::query("SELECT balance, available_balance FROM accounts WHERE id = $1")
        .bind(account_id)
        .fetch_optional(pool)
        .await
        .map_err(|e| e.to_string())?
        .ok_or_else(|| "Account not found".to_string())?;
    
    use rust_decimal::prelude::ToPrimitive;
    use rust_decimal::Decimal;
    
    let balance = result.try_get::<Decimal, _>("balance")
        .map(|d| d.to_f64().unwrap_or(0.0))
        .unwrap_or(0.0);
    
    let available_balance = result.try_get::<Decimal, _>("available_balance")
        .map(|d| d.to_f64().unwrap_or(0.0))
        .unwrap_or(0.0);
    
    Ok((balance, available_balance))
}

/// 通知函数：交易创建
#[allow(dead_code)]
pub async fn notify_transaction_created(
    manager: &Arc<WsConnectionManager>,
    family_id: Uuid,
    transaction: serde_json::Value,
) {
    manager.broadcast_to_family(family_id, WsMessage::TransactionUpdate {
        transaction_id: Uuid::parse_str(
            transaction.get("id")
                .and_then(|v| v.as_str())
                .unwrap_or("00000000-0000-0000-0000-000000000000")
        ).unwrap_or_default(),
        action: "created".to_string(),
        data: transaction,
    }).await;
}

/// 通知函数：账户余额更新
#[allow(dead_code)]
pub async fn notify_balance_update(
    manager: &Arc<WsConnectionManager>,
    family_id: Uuid,
    account_id: Uuid,
    balance: f64,
    available_balance: f64,
) {
    manager.broadcast_to_family(family_id, WsMessage::AccountBalanceUpdate {
        account_id,
        balance,
        available_balance,
    }).await;
}