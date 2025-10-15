# Jive Money API

基于Rust的个人财务管理API服务，支持多用户、多账本、分类管理等功能。

## 技术栈

- **后端框架**: Rust + Axum
- **数据库**: PostgreSQL 16
- **缓存**: Redis 7
- **认证**: JWT
- **容器化**: Docker & Docker Compose

## 快速开始

### 前置要求

- Rust 1.75+ 
- PostgreSQL 15+
- Redis 6+
- Docker & Docker Compose (可选)

### 本地开发

#### 1. 克隆项目

```bash
git clone <repository-url>
cd jive-api
```

#### 2. 环境配置

复制环境变量示例文件：

```bash
cp .env.example .env
```

编辑 `.env` 文件，配置数据库连接等信息。

#### 3. 数据库初始化

运行数据库迁移脚本：

```bash
# 创建数据库
psql -U postgres -c "CREATE DATABASE jive_money;"

# 运行迁移
psql postgresql://postgres:postgres@localhost:5432/jive_money -f migrations/001_create_templates_table.sql
psql postgresql://postgres:postgres@localhost:5432/jive_money -f migrations/002_create_all_tables.sql
psql postgresql://postgres:postgres@localhost:5432/jive_money -f migrations/003_insert_test_data.sql
psql postgresql://postgres:postgres@localhost:5432/jive_money -f migrations/004_fix_missing_columns.sql
psql postgresql://postgres:postgres@localhost:5432/jive_money -f migrations/005_create_superadmin.sql
```

#### 4. 启动服务

```bash
# 安装依赖并运行
cargo run --bin jive-api

# 或指定环境变量
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/jive_money \
REDIS_URL=redis://localhost:6379 \
FIAT_PROVIDER_ORDER=frankfurter,exchangerate-api \
CRYPTO_PROVIDER_ORDER=coingecko,coincap \
cargo run --bin jive-api
```

服务将在 http://localhost:8012 启动

### 新增可配置项（017）

- `FIAT_PROVIDER_ORDER`: 以逗号分隔的法币汇率提供商顺序，默认 `frankfurter,exchangerate-api`
- `CRYPTO_PROVIDER_ORDER`: 以逗号分隔的加密价格提供商顺序，默认 `coingecko,coincap`

017 迁移还会：
- 为 `currencies` 表添加 `country_code`, `is_popular`, `display_order`, `min_amount`, `max_amount` 列（若不存在）
- 预置 150+ 法币和更多主流加密货币

### Docker部署

#### MacOS (Apple Silicon)

使用专用的Docker配置：

```bash
# 启动数据库和Redis（使用不同端口避免冲突）
docker-compose -f docker-compose.macos.yml up -d postgres redis

# 本地运行API（推荐）
DATABASE_URL=postgresql://postgres:postgres@localhost:5433/jive_money \
REDIS_URL=redis://localhost:6380 \
cargo run --bin jive-api
```

#### Ubuntu/Linux

```bash
# 使用标准docker-compose
docker-compose up -d

# 或使用Ubuntu专用Dockerfile
docker build -f Dockerfile.ubuntu -t jive-api:ubuntu .
docker run -d -p 8012:8012 jive-api:ubuntu
```

## API端点

### 健康检查

```bash
GET /health
```

响应示例：
```json
{
  "service": "jive-money-api",
  "status": "healthy",
  "timestamp": "2025-09-03T12:46:40.952539+00:00",
  "version": "1.0.0"
}
```

### 分类模板

```bash
# 获取模板列表
GET /api/v1/templates/list

# 获取图标列表
GET /api/v1/icons/list

# 增量更新
GET /api/v1/templates/updates?version=1

# 提交使用统计
POST /api/v1/templates/usage
```

### 账户管理

```bash
# 账户列表
GET /api/v1/accounts?ledger_id={ledger_id}

# 创建账户
POST /api/v1/accounts

# 获取账户详情
GET /api/v1/accounts/{id}

# 更新账户
PUT /api/v1/accounts/{id}

# 删除账户
DELETE /api/v1/accounts/{id}

# 账户统计
GET /api/v1/accounts/statistics?ledger_id={ledger_id}
```

### 交易管理

```bash
# 交易列表
GET /api/v1/transactions?ledger_id={ledger_id}

# 创建交易
POST /api/v1/transactions

# 获取交易详情
GET /api/v1/transactions/{id}

# 更新交易
PUT /api/v1/transactions/{id}

# 删除交易
DELETE /api/v1/transactions/{id}

# 批量操作
POST /api/v1/transactions/bulk

# 交易统计
GET /api/v1/transactions/statistics?ledger_id={ledger_id}
```

## 数据库结构

### 核心表

- `users` - 用户表
- `families` - 家庭/组织表
- `family_members` - 家庭成员表
- `ledgers` - 账本表
- `accounts` - 账户表
- `categories` - 分类表
- `transactions` - 交易表
- `budgets` - 预算表
- `system_category_templates` - 系统分类模板

### 测试账户

| 邮箱 | 密码 | 角色 | 说明 |
|------|------|------|------|
| superadmin@jive.com | admin123 | superadmin | 超级管理员 |
| test@example.com | test123 | user | 测试用户 |
| admin@example.com | admin123 | user | 管理员用户 |

## 项目结构

```
jive-api/
├── src/
│   ├── main.rs                 # 主入口
│   ├── handlers/               # 请求处理器
│   │   ├── accounts.rs        # 账户相关
│   │   ├── transactions.rs    # 交易相关
│   │   ├── templates.rs       # 模板相关
│   │   └── auth.rs           # 认证相关
│   ├── models/                # 数据模型
│   ├── middleware/            # 中间件
│   ├── config.rs              # 配置
│   ├── error.rs               # 错误处理
│   └── auth.rs                # 认证逻辑
├── migrations/                 # 数据库迁移
├── docker/                     # Docker配置
├── Cargo.toml                 # 项目配置
└── README.md                  # 项目说明
```

## 开发指南

### 环境变量

```bash
# 数据库配置
DATABASE_URL=postgresql://user:password@localhost:5432/jive_money
DATABASE_MAX_CONNECTIONS=25

# Redis配置
REDIS_URL=redis://localhost:6379

# API配置
API_PORT=8012
HOST=0.0.0.0
RUST_LOG=info

# JWT配置
JWT_SECRET=your-secret-key
JWT_EXPIRY=86400

# CORS配置
CORS_ORIGIN=http://localhost:3021
CORS_ALLOW_CREDENTIALS=true
```

### 编译优化

```bash
# 开发模式
cargo build

# 生产模式（优化编译）
cargo build --release

# 运行测试
cargo test

# 代码检查
cargo clippy

# 格式化
cargo fmt
```

### Docker构建

```bash
# MacOS M4 (ARM64)
./build-macos.sh

# Ubuntu (AMD64)
docker build -f Dockerfile.ubuntu -t jive-api:ubuntu .

# 多架构构建
./build-multiarch.sh
```

## 故障排查

### 常见问题

1. **端口冲突**
   - MacOS Docker使用5433(PostgreSQL)和6380(Redis)避免冲突
   - 确保8012端口未被占用

2. **数据库连接失败**
   - 检查PostgreSQL服务是否运行
   - 验证DATABASE_URL配置
   - 确认数据库jive_money已创建

3. **SQLx编译错误**
   - 设置环境变量 `SQLX_OFFLINE=true` 跳过编译时检查
   - 或确保数据库可访问

4. **Docker构建失败**
   - MacOS需要使用专用的Dockerfile.macos
   - Ubuntu使用Dockerfile.ubuntu
   - 检查Docker daemon是否运行

## 许可证

MIT License

## 贡献指南

欢迎提交Issue和Pull Request！

## 联系方式

- 项目维护者：Jive Money Team
- 邮箱：support@jive.com
