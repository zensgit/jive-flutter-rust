# Jive Money 服务端口配置

## 服务状态
- ✅ **Rust API**: 运行中 (PID: 155201, 端口: 8012)
- ✅ **Flutter Web**: 运行中 (PID: 155801, 端口: 3021)  
- ✅ **PostgreSQL**: 运行中 (端口: 5432)
- ✅ **Redis**: 运行中 (端口: 6379)

## 端口配置详情

### Rust API 服务
- **端口**: 8012
- **协议**: HTTP
- **URL**: http://localhost:8012
- **API路径**: /api/v1
- **健康检查**: http://localhost:8012/api/v1/health
- **配置文件**: `jive-api/.env`

### Flutter Web 前端
- **端口**: 3021
- **协议**: HTTP  
- **URL**: http://localhost:3021
- **配置**: `lib/core/config/environment_config.dart`

### PostgreSQL 数据库
- **端口**: 5432
- **数据库**: jive_money
- **用户**: postgres
- **连接字符串**: postgresql://postgres:postgres@localhost:5432/jive_money

### Redis 缓存
- **端口**: 6379
- **主机**: localhost
- **用途**: 会话管理、缓存

## 配置文件位置

### Flutter 配置
- `lib/core/config/environment_config.dart` - 环境和端口配置
- `lib/core/config/api_config.dart` - API配置
- `lib/core/utils/service_health_check.dart` - 服务健康检查

### Rust API 配置  
- `jive-api/.env` - 环境变量
- `jive-api/src/main.rs` - 主要服务配置

## 开发命令

### 启动 Rust API
```bash
cd jive-api
cargo run
# 或使用环境变量
API_PORT=8012 cargo run
```

### 启动 Flutter Web
```bash
cd jive-flutter  
flutter run -d web-server --web-port 3021
```

### 数据库连接测试
```bash
psql -h localhost -p 5432 -U postgres -d jive_money
```

### Redis 连接测试
```bash
redis-cli -h localhost -p 6379 ping
```

## API 端点

### 认证相关
- POST `/api/v1/auth/login` - 登录
- POST `/api/v1/auth/register` - 注册
- POST `/api/v1/auth/logout` - 登出
- GET `/api/v1/auth/profile` - 获取用户信息

### 数据相关
- GET `/api/v1/ledgers` - 获取账本列表
- GET `/api/v1/accounts` - 获取账户列表
- GET `/api/v1/transactions` - 获取交易列表
- GET `/api/v1/budgets` - 获取预算列表

### 健康检查
- GET `/api/v1/health` - API健康状态
- GET `/api/v1/health/db` - 数据库连接状态
- GET `/api/v1/health/cache` - 缓存服务状态

## 故障排除

### 端口冲突
如需更改端口，请更新以下配置：
1. `jive-api/.env` 中的 `API_PORT`
2. `lib/core/config/environment_config.dart` 中的端口常量
3. 重启相应服务

### 数据库连接问题
1. 确认PostgreSQL服务运行在端口5432
2. 检查数据库 `jive_money` 是否存在
3. 验证用户权限

### API连接问题
1. 确认Rust API在端口8012运行
2. 检查防火墙设置
3. 验证API健康检查端点

## 更新日志
- 2025-09-02: 配置端口从8080更改为8012 (Rust API)
- 2025-09-02: Flutter Web端口设置为3021
- 2025-09-02: 添加环境配置管理和健康检查工具