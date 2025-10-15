//! 简化的WebSocket模块

use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        Query, State,
    },
    response::Response,
};
use futures_util::{sink::SinkExt, stream::StreamExt};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{error, info};

/// WebSocket连接管理器
pub struct WsConnectionManager {
    connections: Arc<RwLock<HashMap<String, tokio::sync::mpsc::UnboundedSender<String>>>>,
}

impl WsConnectionManager {
    pub fn new() -> Self {
        Self {
            connections: Arc::new(RwLock::new(HashMap::new())),
        }
    }

    pub async fn add_connection(&self, id: String, tx: tokio::sync::mpsc::UnboundedSender<String>) {
        self.connections.write().await.insert(id, tx);
    }

    pub async fn remove_connection(&self, id: &str) {
        self.connections.write().await.remove(id);
    }

    pub async fn send_message(&self, id: &str, message: String) -> Result<(), String> {
        if let Some(tx) = self.connections.read().await.get(id) {
            tx.send(message).map_err(|e| e.to_string())
        } else {
            Err("Connection not found".to_string())
        }
    }
}

impl Default for WsConnectionManager {
    fn default() -> Self {
        Self::new()
    }
}

/// WebSocket查询参数
#[derive(Debug, Deserialize)]
pub struct WsQuery {
    pub token: String,
}

/// WebSocket消息
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum WsMessage {
    Connected { user_id: String },
    Ping,
    Pong,
    Error { message: String },
}

/// 处理WebSocket升级请求
pub async fn ws_handler(
    ws: WebSocketUpgrade,
    Query(query): Query<WsQuery>,
    State(pool): State<PgPool>,
) -> Response {
    // 简单的令牌验证（实际应验证JWT）
    if query.token.is_empty() {
        return ws.on_upgrade(|mut socket| async move {
            let _ = socket
                .send(Message::Text(
                    serde_json::to_string(&WsMessage::Error {
                        message: "Invalid token".to_string(),
                    })
                    .unwrap(),
                ))
                .await;
            let _ = socket.close().await;
        });
    }

    ws.on_upgrade(move |socket| handle_socket(socket, query.token, pool))
}

/// 处理WebSocket连接
pub async fn handle_socket(socket: WebSocket, token: String, _pool: PgPool) {
    let (mut sender, mut receiver) = socket.split();

    // 发送连接成功消息
    let connected_msg = WsMessage::Connected {
        user_id: "test-user".to_string(),
    };

    if let Ok(msg_str) = serde_json::to_string(&connected_msg) {
        let _ = sender.send(Message::Text(msg_str)).await;
    }

    info!("WebSocket connected with token: {}", token);

    // 处理消息循环
    while let Some(msg) = receiver.next().await {
        match msg {
            Ok(Message::Text(text)) => {
                // 简单的ping/pong处理
                if text.contains("\"Ping\"") || text.contains("ping") {
                    let pong = serde_json::to_string(&WsMessage::Pong).unwrap();
                    let _ = sender.send(Message::Text(pong)).await;
                }
            }
            Ok(Message::Close(_)) => {
                info!("WebSocket connection closed");
                break;
            }
            Err(e) => {
                error!("WebSocket error: {}", e);
                break;
            }
            _ => {}
        }
    }
}
