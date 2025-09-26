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

# 运行迁移（推荐使用脚本，自动选择可用连接）
./scripts/migrate_local.sh --force
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

### 迁移清理与重跑（遇到迁移历史冲突时）

当本地数据库迁移历史与仓库迁移文件不一致（如迁移被重命名/调整）时，可能出现校验冲突。开发与测试环境可用以下方式重置：

```bash
# 重置开发库
export DATABASE_URL=postgresql://postgres:postgres@localhost:5433/jive_money
cd jive-api && ./scripts/reset-db.sh

# 重置测试库
export TEST_DATABASE_URL=postgresql://postgres:postgres@localhost:5433/jive_money_test
cd jive-api && ./scripts/reset-db.sh
```

注意：该脚本会 Drop 并重建 public schema，勿用于生产环境。

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

### 导出与审计

导出接口会自动写入审计日志，便于追踪数据导出活动。

- POST 导出（返回 data:URL）
  - `POST /api/v1/transactions/export`
  - 请求体：`{"format":"csv"|"json", 可选过滤: account_id/ledger_id/category_id/start_date/end_date}`
  - 响应体包含 `audit_id` 字段，同时返回 data:URL 便于前端直接下载；示例字段：
    - `file_name`, `mime_type`, `download_url`, `size`, `audit_id`

- GET 流式导出（浏览器友好）
  - `GET /api/v1/transactions/export.csv`
  - 支持同样的过滤参数，另支持 `include_header`（可选，默认 `true`）用于控制是否输出表头行
  - 响应头：
    - `Content-Type: text/csv; charset=utf-8`
    - `Content-Disposition: attachment; filename="transactions_export_YYYYMMDDHHMMSS.csv"`
    - `X-Audit-Id: <uuid>`（存在时）

#### 流式导出优化 (export_stream feature)

对于大数据集导出，可启用 `export_stream` feature 以实现内存高效的流式处理：

```bash
# 编译时启用流式导出
cargo build --features export_stream

# 或运行时启用
cargo run --features export_stream --bin jive-api
```

**性能特点**：
- ✅ **内存效率高**: 使用 tokio channel 流式处理，避免一次性加载所有数据
- ✅ **响应速度快**: 立即开始返回数据，无需等待全部查询完成
- ✅ **适合大数据集**: 可处理超过内存容量的数据集
- ✅ **实测性能**: 5k-20k 记录导出耗时仅 10-23ms

**注意事项**：
- 流式导出使用 `query_raw` 避免反序列化开销
- 需要 SQLx 在线模式编译（首次编译需数据库连接）
- 生产环境建议启用此 feature 以优化性能

审计日志 API：

- 列表：`GET /api/v1/families/:id/audit-logs`
  - 需要权限：`ViewAuditLog`
  - 支持过滤：`user_id`、`action`（如 `EXPORT`）、`entity_type`、`from_date`、`to_date`、`limit`、`offset`

- 导出：`GET /api/v1/families/:id/audit-logs/export?from_date=...&to_date=...`
  - 需要权限：`ViewAuditLog`
  - 返回 CSV 下载

- 清理：`POST /api/v1/families/:id/audit-logs/cleanup?older_than_days=90&limit=1000`
  - 需要权限：`ManageSettings`
  - 返回删除数量；操作本身也会写入审计（action=DELETE, entity_type=audit_logs）

说明：
- POST 导出在响应 JSON 中返回 `audit_id`，GET 流式导出在响应头返回 `X-Audit-Id`；前端可据此在 UI 展示“已记录导出编号”。
- 数据库层已为导出与审计常见查询创建优化索引（见 `migrations/024_add_export_indexes.sql` 与 `migrations/026_add_audit_indexes.sql`）。

#### 客户端示例（cURL 与 Flutter/Dart）

- cURL：POST 导出（CSV），提取 audit_id 与保存 data:URL 内容

```bash
TOKEN="<jwt>"
API="http://localhost:8012/api/v1"

# 请求导出（可选 include_header=false 关闭表头）
resp=$(curl -s -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"format":"csv","start_date":"2024-09-01","end_date":"2024-09-30","include_header":false}' \
  "$API/transactions/export")

audit_id=$(echo "$resp" | jq -r .audit_id)
url=$(echo "$resp" | jq -r .download_url)
echo "audit_id=$audit_id"

# 保存 data:URL 到文件
base64part=${url#*base64,}
echo "$base64part" | base64 --decode > transactions_export.csv
```

- cURL：GET 流式导出（带响应头 X-Audit-Id）

```bash
TOKEN="<jwt>"; API="http://localhost:8012/api/v1"
curl -sS -D headers.txt -H "Authorization: Bearer $TOKEN" \
  "$API/transactions/export.csv?ledger_id=<ledger_uuid>&start_date=2024-09-01&end_date=2024-09-30" \
  -o transactions_export_stream.csv
grep -i "^X-Audit-Id:" headers.txt | awk '{print $2}'
```

- Flutter/Dart（Dio）：POST 导出（CSV data:URL）

```dart
final dio = HttpClient.instance.dio; // 代码库已有封装
final resp = await dio.post(
  '/transactions/export',
  data: {
    'format': 'csv',
    'start_date': '2024-09-01',
    'end_date': '2024-09-30',
  },
);
final data = resp.data as Map<String, dynamic>;
final auditId = data['audit_id'];
final downloadUrl = data['download_url'];
// 解析 data:URL 并保存
final idx = downloadUrl.indexOf('base64,');
if (idx != -1) {
  final b64 = downloadUrl.substring(idx + 'base64,'.length);
  final bytes = base64Decode(b64);
  final file = File('/path/transactions_export.csv');
  await file.writeAsBytes(bytes, flush: true);
}
```

- Flutter/Dart（Dio）：GET 流式导出（读取 X-Audit-Id）

```dart
final resp = await dio.get<ResponseBody>(
  '/transactions/export.csv',
  queryParameters: {
    'ledger_id': '<ledger_uuid>',
    'start_date': '2024-09-01',
    'end_date': '2024-09-30',
  },
  options: Options(responseType: ResponseType.stream),
);
final auditId = resp.headers['x-audit-id']?.first;
final sink = File('/path/transactions_export_stream.csv').openWrite();
await resp.data!.stream.listen((chunk) => sink.add(chunk)).asFuture();
await sink.close();
```

- cURL：审计列表与清理

```bash
FAMILY_ID="<family_uuid>"; TOKEN="<jwt>"; API="http://localhost:8012/api/v1"

# 列表（最近导出）
curl -s -H "Authorization: Bearer $TOKEN" \
  "$API/families/$FAMILY_ID/audit-logs?action=EXPORT&entity_type=transactions&limit=20" | jq .

# 清理（需 ManageSettings 权限）
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  "$API/families/$FAMILY_ID/audit-logs/cleanup?older_than_days=90&limit=1000" | jq .
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
