# WebSocket实时更新 - 设计与测试文档

## 功能概述

WebSocket实时更新功能为Jive系统提供双向实时通信能力，支持：
- 交易实时更新推送
- 账户余额变动通知
- 规则执行结果推送
- 收款人建议实时推送
- 系统通知广播

## 架构设计

### 后端架构 (Rust + Axum)

```rust
// WebSocket连接管理器
pub struct WsConnectionManager {
    connections: Arc<RwLock<HashMap<Uuid, Arc<Mutex<WebSocket>>>>>,
    subscriptions: Arc<RwLock<HashMap<String, Vec<Uuid>>>>,
}

// 消息类型
pub enum WsMessage {
    Connected { user_id: Uuid },
    TransactionUpdate { transaction_id: Uuid, action: String, data: Value },
    AccountBalanceUpdate { account_id: Uuid, balance: f64 },
    RuleExecuted { rule_id: Uuid, matched_count: i32 },
    PayeeSuggestion { description: String, suggestions: Vec<String> },
    Notification { level: String, title: String, message: String },
    Ping/Pong,
    Error { code: String, message: String },
}
```

### 前端架构 (Flutter)

```dart
// WebSocket服务
class WebSocketService {
  WebSocketChannel? _channel;
  Stream<WsMessage> get messages;
  
  Future<void> connect(String token);
  void subscribe(String topic);
  void unsubscribe(String topic);
  void requestData(String resource, Map params);
}

// WebSocket监听器Mixin
mixin WebSocketListener {
  void initWebSocket(String token);
  void handleWsMessage(WsMessage message);
  void subscribeFamilyChannel(String familyId);
  void subscribeUserChannel(String userId);
}
```

## 实现细节

### 1. 连接管理

**连接流程：**
1. 客户端通过JWT令牌建立WebSocket连接
2. 服务器验证令牌并获取用户信息
3. 自动订阅用户相关频道（家庭频道、个人频道）
4. 发送连接成功消息

**断线重连：**
- 客户端自动检测连接断开
- 使用指数退避策略重连（2s, 4s, 8s, 16s, 32s）
- 最多重试5次

### 2. 订阅机制

**频道类型：**
- `family:{uuid}` - 家庭频道，推送家庭内所有成员的数据变更
- `user:{uuid}` - 用户频道，推送个人相关数据
- `account:{uuid}` - 账户频道，推送特定账户的变更
- `global` - 全局频道，推送系统级通知

**权限验证：**
- 验证用户是否属于订阅的家庭
- 验证用户是否有权访问特定账户
- 防止越权订阅

### 3. 消息推送

**推送触发点：**

| 操作 | 推送内容 | 目标频道 |
|-----|---------|---------|
| 创建交易 | TransactionUpdate | family:{id} |
| 更新交易 | TransactionUpdate | family:{id} |
| 删除交易 | TransactionUpdate | family:{id} |
| 账户余额变化 | AccountBalanceUpdate | account:{id}, family:{id} |
| 规则执行完成 | RuleExecuted | user:{id} |
| 收款人匹配 | PayeeSuggestion | user:{id} |

### 4. 心跳机制

- 服务端每30秒发送Ping消息
- 客户端收到Ping后回复Pong
- 超过60秒无响应断开连接

## API端点

### WebSocket连接
```
ws://localhost:8012/ws?token={jwt_token}
```

### 客户端命令
```json
// 订阅
{
  "command": "Subscribe",
  "data": { "topic": "family:uuid" }
}

// 取消订阅
{
  "command": "Unsubscribe", 
  "data": { "topic": "family:uuid" }
}

// 请求数据
{
  "command": "Request",
  "data": {
    "resource": "account_balance",
    "params": { "account_id": "uuid" }
  }
}

// 心跳
{
  "command": "Ping"
}
```

### 服务端消息
```json
// 连接成功
{
  "type": "Connected",
  "data": { "user_id": "uuid" }
}

// 交易更新
{
  "type": "TransactionUpdate",
  "data": {
    "transaction_id": "uuid",
    "action": "created",
    "data": { /* transaction object */ }
  }
}

// 余额更新
{
  "type": "AccountBalanceUpdate",
  "data": {
    "account_id": "uuid",
    "balance": 1000.00,
    "available_balance": 900.00
  }
}
```

## 集成点

### 1. 交易处理器集成
```rust
// handlers/transactions.rs
pub async fn create_transaction(
    State(pool): State<PgPool>,
    State(ws_manager): State<Arc<WsConnectionManager>>,
    Json(req): Json<CreateTransactionRequest>,
) -> ApiResult<Json<TransactionResponse>> {
    // ... 创建交易逻辑
    
    // 推送WebSocket通知
    notify_transaction_created(&ws_manager, family_id, transaction_json).await;
    
    // 推送余额更新
    notify_balance_update(&ws_manager, family_id, account_id, new_balance).await;
}
```

### 2. Flutter页面集成
```dart
class TransactionListScreen extends StatefulWidget 
    with WebSocketListener {
    
  @override
  void initState() {
    super.initState();
    // 初始化WebSocket
    initWebSocket(authService.token);
    subscribeFamilyChannel(authService.familyId);
  }
  
  @override
  void handleWsMessage(WsMessage message) {
    if (message.isTransactionUpdate) {
      // 刷新交易列表
      _refreshTransactions();
    } else if (message.isAccountBalanceUpdate) {
      // 更新余额显示
      _updateBalance(message.accountId, message.balance);
    }
  }
}
```

## 测试方案

### 1. 连接测试
```bash
# 使用wscat测试WebSocket连接
npm install -g wscat
wscat -c "ws://localhost:8012/ws?token=your_jwt_token"

# 发送订阅命令
> {"command":"Subscribe","data":{"topic":"family:550e8400-e29b-41d4-a716-446655440001"}}

# 发送心跳
> {"command":"Ping"}
```

### 2. 推送测试
```bash
# 创建交易触发推送
curl -X POST http://localhost:8012/api/v1/transactions \
  -H "Authorization: Bearer your_jwt_token" \
  -H "Content-Type: application/json" \
  -d '{
    "account_id": "uuid",
    "amount": 100.00,
    "description": "Test transaction"
  }'
  
# 观察WebSocket客户端收到的消息
```

### 3. 性能测试
```javascript
// 使用Artillery进行WebSocket压力测试
// artillery.yml
config:
  target: "ws://localhost:8012"
  phases:
    - duration: 60
      arrivalRate: 10
  processor: "./websocket-test.js"
  
scenarios:
  - engine: "ws"
    flow:
      - send: '{"command":"Subscribe","data":{"topic":"family:test"}}'
      - think: 5
      - send: '{"command":"Ping"}'
      - think: 30
```

## 性能指标

| 指标 | 目标值 | 实际值 |
|-----|-------|-------|
| 最大并发连接数 | 10000 | 待测试 |
| 消息延迟 | < 100ms | 待测试 |
| 消息吞吐量 | 1000 msg/s | 待测试 |
| 内存占用/连接 | < 10KB | 待测试 |
| 重连成功率 | > 95% | 待测试 |

## 安全考虑

1. **认证授权**
   - JWT令牌验证
   - 频道订阅权限检查
   - 防止越权访问

2. **消息安全**
   - 敏感数据脱敏
   - 消息大小限制（1MB）
   - 防止消息注入

3. **连接管理**
   - 连接数限制
   - 心跳超时断开
   - IP限流保护

## 故障处理

### 常见问题

1. **连接失败**
   - 检查JWT令牌是否有效
   - 确认WebSocket端口开放
   - 查看服务器日志

2. **消息未收到**
   - 确认已订阅相关频道
   - 检查权限配置
   - 验证消息格式

3. **频繁断线**
   - 检查网络稳定性
   - 调整心跳间隔
   - 查看服务器资源

## 后续优化

1. **消息队列集成**
   - 集成Redis Pub/Sub支持多实例
   - 消息持久化防丢失
   - 离线消息缓存

2. **性能优化**
   - 消息批量发送
   - 连接池管理
   - 消息压缩

3. **功能扩展**
   - 支持二进制消息
   - 文件传输能力
   - 视频流支持

## 总结

WebSocket实时更新功能已完成基础实现：
- ✅ 连接管理和认证
- ✅ 订阅机制和权限控制
- ✅ 消息推送框架
- ✅ 心跳和重连机制
- ✅ Flutter客户端集成
- ⚠️ 待完成完整测试
- ⚠️ 待优化性能

**实现状态：基础功能完成，需进一步测试和优化**