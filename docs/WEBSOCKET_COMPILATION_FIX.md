# WebSocket编译问题解决方案

## 问题描述

在实现WebSocket功能时遇到以下编译问题：
1. SQLX离线模式错误
2. Axum状态管理问题
3. AuthError到ApiError的转换问题
4. sqlx::query!宏的编译时验证问题

## 解决方案

### 1. 替换sqlx::query!宏

**问题**：`sqlx::query!`宏需要编译时数据库连接，导致离线编译失败。

**解决**：将所有`sqlx::query!`替换为动态查询`sqlx::query`。

```rust
// 之前
let user = sqlx::query!(
    "SELECT * FROM users WHERE id = $1",
    user_id
).fetch_one(&pool).await?;

// 之后
let row = sqlx::query("SELECT * FROM users WHERE id = $1")
    .bind(user_id)
    .fetch_one(&pool)
    .await?;

use sqlx::Row;
let user = User {
    id: row.try_get("id")?,
    email: row.try_get("email")?,
    // ...
};
```

### 2. 添加错误转换

**问题**：AuthError无法自动转换为ApiError。

**解决**：在error.rs中实现From trait。

```rust
impl From<AuthError> for ApiError {
    fn from(err: AuthError) -> Self {
        match err {
            AuthError::WrongCredentials => ApiError::Unauthorized,
            AuthError::MissingCredentials => ApiError::BadRequest("Missing credentials".to_string()),
            AuthError::TokenCreation => ApiError::InternalServerError,
            AuthError::InvalidToken => ApiError::Unauthorized,
        }
    }
}
```

### 3. 创建简化的WebSocket模块

**问题**：复杂的WebSocket管理器导致编译问题。

**解决**：创建简化版ws.rs模块。

```rust
// ws.rs - 简化的WebSocket处理
pub async fn ws_handler(
    ws: WebSocketUpgrade,
    Query(query): Query<WsQuery>,
    State(pool): State<PgPool>,
) -> Response {
    // 简单的令牌验证和连接处理
}
```

### 4. 模块化主程序

创建多个二进制目标，分离关注点：

- `jive-api-core` - 核心API功能
- `jive-api-ws` - 包含WebSocket的完整版本
- `jive-api` - 原始版本（保留用于调试）

## 编译步骤

```bash
# 1. 清理之前的构建
cargo clean

# 2. 编译带WebSocket的版本
cargo build --bin jive-api-ws

# 3. 运行服务器
./target/debug/jive-api-ws
```

## 测试验证

### 健康检查
```bash
curl http://localhost:8012/health
```

### WebSocket连接测试
```bash
# 安装wscat
npm install -g wscat

# 测试连接
wscat -c 'ws://localhost:8012/ws?token=test'

# 发送Ping消息
> {"command":"Ping"}
# 应收到Pong响应
< {"type":"Pong"}
```

## 项目结构

```
jive-api/
├── src/
│   ├── main.rs              # 原始主程序
│   ├── main_with_ws.rs      # 带WebSocket的主程序
│   ├── main_simple_ws.rs    # 核心API主程序
│   ├── ws.rs                # 简化的WebSocket模块
│   ├── websocket.rs         # 完整WebSocket实现（未使用）
│   ├── auth.rs              # JWT认证
│   ├── error.rs             # 错误处理（包含转换）
│   └── handlers/
│       ├── auth.rs          # 认证处理器（已修复）
│       ├── accounts.rs      # 账户API
│       ├── transactions.rs  # 交易API
│       ├── payees.rs        # 收款人API
│       └── rules.rs         # 规则引擎API
└── Cargo.toml               # 多个二进制目标配置
```

## 关键改动

1. **handlers/auth.rs**
   - 替换所有sqlx::query!为sqlx::query
   - 手动处理Row到结构体的转换

2. **error.rs**
   - 添加AuthError到ApiError的From实现

3. **handlers/mod.rs**
   - 导出auth模块

4. **Cargo.toml**
   - 添加ws特性到axum
   - 定义多个二进制目标

## 当前状态

✅ **编译成功**
✅ **服务器正常运行**
✅ **WebSocket端点可访问**
✅ **所有API端点正常工作**

服务器运行在：http://localhost:8012
WebSocket端点：ws://localhost:8012/ws