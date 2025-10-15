# Jive Money - 集腋记账

[![Core CI (Strict)](https://github.com/zensgit/jive-flutter-rust/actions/workflows/ci.yml/badge.svg)](https://github.com/zensgit/jive-flutter-rust/actions/workflows/ci.yml)

一个全功能的个人财务管理系统，采用 Flutter 前端和 Rust 后端架构。

> **集腋成裘，细水长流** - 用心记录每一笔收支，积小成大，理财从记账开始。

## 🚀 快速启动

### 方法 1: 使用智能启动脚本（推荐）

```bash
# 赋予执行权限
chmod +x start.sh

# 交互式启动
./start.sh

# 或直接启动所有服务
./start.sh start
```

启动脚本功能：
- ✅ 自动检查所有依赖（Rust、Flutter、数据库）
- ✅ 检测端口占用并提供处理选项
- ✅ 支持多平台运行（Web、iOS、Android、桌面）
- ✅ 开发模式热重载
- ✅ 服务状态监控
- ✅ 日志查看

### 方法 2: 使用 Make 命令

```bash
# 安装依赖
make install

# 检查环境
make check

# 启动服务
make start

# 开发模式
make dev

# 查看更多命令
make help

首次建议：
- 启用本地 pre-commit 钩子：`make hooks`
- 如涉及数据库迁移：`make api-sqlx-prepare-local`（迁移 + 刷新 `.sqlx/`）
```

### 方法 3: 使用 Docker Compose

```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

## 📋 系统要求

### 必需依赖
- **Rust**: 1.75+
- **Flutter**: 3.16+
- **PostgreSQL**: 14+

### 可选依赖
- **Redis**: 用于缓存和会话管理
- **Docker**: 容器化部署
- **Make**: 简化命令操作

## 🔧 配置

1. 复制环境配置文件：
```bash
cp .env.example .env
```

2. 根据需要修改 `.env` 文件中的配置

## 🏗️ 项目结构

```
jive-flutter-rust/
├── jive-core/          # Rust 后端
│   ├── src/
│   │   ├── domain/     # 领域模型
│   │   └── application/ # 业务逻辑
│   └── Cargo.toml
├── jive-flutter/       # Flutter 前端
│   ├── lib/
│   └── pubspec.yaml
├── start.sh           # 智能启动脚本
├── docker-compose.yml # Docker 配置
├── Makefile          # Make 命令
└── .env.example      # 环境配置模板
```

## ✨ 功能特性

### 核心功能
- 🏠 **Family 多用户协作**: 基于家庭的财务管理，支持多角色权限
- 🔐 **MFA 多因素认证**: TOTP 双因素认证，增强账户安全
- 💳 **信用卡管理**: 账单周期、还款提醒、多币种支持
- 📊 **智能分析报表**: 收支分析、预算跟踪、趋势预测
- 📱 **快速记账**: 智能分类、商户识别、语音输入
- 🤖 **规则引擎**: 自动分类、批量处理、智能提醒
- 💼 **投资组合**: 持仓管理、收益计算、风险分析
- 🔔 **通知系统**: 多渠道通知、个性化设置、成就系统

### 中国本地化
- 支持支付宝、微信支付数据导入
- 中国银行信用卡账单支持
- 微信通知渠道
- 人民币优先显示

## 🛠️ 开发命令

```bash
# 启动完整版 API（宽松 CORS，全部 Origin/Headers 放行，用于前端调试）
make api-dev

# 启动完整版 API（安全模式，白名单 + 指定自定义头）
make api-safe

# 运行测试
make test

# 代码格式化
make format

# 代码检查
make lint

# 清理构建文件
make clean

# 数据库迁移
make db-migrate

# 查看日志
make logs

## 🔒 安全与变更记录

- 安全总体文档：`docs/TRANSACTION_SECURITY_OVERVIEW.md`
- 安全修复报告：`TRANSACTION_SECURITY_FIX_REPORT.md`
- 完整修复报告：`TRANSACTION_SYSTEM_COMPLETE_FIX_REPORT.md`
- 关键变更记录：`CHANGELOG.md`

## 🧪 本地CI（不占用GitHub Actions分钟）

当你的GitHub Actions分钟不足时，可以使用本地CI脚本模拟CI流程：

```bash
chmod +x scripts/ci_local.sh
./scripts/ci_local.sh
```

### SQLx 离线校验（开发者速记）

- 离线校验用途：在不依赖在线数据库的情况下，编译期验证 SQL 宏的类型与签名。
- 何时需要更新 `.sqlx/`：任何迁移或查询签名变动后。

常用命令：

```bash
# 1) 跑迁移（确保 DB 最新）
cd jive-api && ./scripts/migrate_local.sh --force

# 2) 刷新离线缓存
SQLX_OFFLINE=false cargo sqlx prepare

# 3) 本地严格校验 + Clippy
make api-lint
```

CI 策略：
- 严格检查 `.sqlx` 与查询是否一致；若不一致：
  - 上传 `api-sqlx-diff` 工件（含新旧缓存与 diff patch）
  - 在 PR 自动评论首 80 行 diff 预览，便于定位
  - 失败退出，提示开发者提交更新后的 `.sqlx/`

该脚本会：
- 尝试用 Docker 启动本地 Postgres/Redis（如已安装）
- 运行迁移、校验 SQLx 离线缓存（仅校验，不生成）
- 运行 Rust 测试 + Clippy（警告视为错误）
- 运行 Flutter analyze（告警致命）与测试
- 将结果保存到 `./local-artifacts`

### SQLx 离线缓存策略（严格）

CI 仅校验已提交的 `.sqlx` 缓存，不在CI生成缓存。若你修改了查询或迁移，需要在本地生成并提交缓存：

```bash
docker compose -f jive-api/docker-compose.db.yml up -d postgres
cd jive-api && ./prepare-sqlx.sh && cd ..
git add jive-api/.sqlx
git commit -m "chore(sqlx): update offline cache"
```
```

### 默认管理员账号（开发环境）

- 账号：`superadmin@jive.money`
- 密码：`admin123`

说明：该账号由迁移 `016_fix_families_member_count_and_superadmin.sql` 统一创建/对齐，仅用于本地开发与测试。请勿在生产环境使用默认凭据，部署前务必更改密码或禁用该账号。

### 管理脚本 (一键启动)

使用 `jive-manager.sh` 可同时管理数据库 / Redis / API / Flutter Web：

```bash
# 全部服务（安全 CORS 模式 API）
./jive-manager.sh start all

# 全部服务（开发宽松模式：API 设置 CORS_DEV=1）
./jive-manager.sh start all-dev

# 仅启动宽松开发 API
./jive-manager.sh start api-dev

# 切换 API 运行模式（不影响数据库 / Redis）
./jive-manager.sh mode dev    # 切到开发宽松
./jive-manager.sh mode safe   # 切回安全

# 查看状态 / 停止
./jive-manager.sh status
./jive-manager.sh stop all-dev
```

说明：宽松模式适合前端快速迭代；提交代码前请使用安全模式验证。

状态显示说明：
- `API: ● 运行中 (... 模式: 开发宽松)` 表示使用 `CORS_DEV=1`（所有 Origin / Headers 放开）。
- `API: ● 运行中 (... 模式: 安全)` 表示白名单 + 指定头部策略（生产/预发布推荐）。
- 切换模式方式：`restart all-dev` 或 `restart all` / `restart api-dev`。
 - 也可直接使用 `./jive-manager.sh mode dev|safe` 快速切换。

### Docker 数据库 + 本地 API（推荐开发流程）

当你希望将数据库/Redis 放在 Docker 中，而在本机直接运行 Rust API 与 Flutter Web 时，使用以下流程：

```bash
# 1) 启动 Docker 中的数据库与 Redis
./jive-manager.sh start db
./jive-manager.sh start redis

# 2) 执行数据库迁移（新增命令）
./jive-manager.sh start migrate
# 目标默认指向: postgresql://postgres:postgres@localhost:5433/jive_money

# 3) 启动本地 API（二选一）
./jive-manager.sh mode safe   # 安全模式
# 或
./jive-manager.sh mode dev    # 开发宽松模式 (CORS_DEV=1)

# 4) 启动前端 Web（可选）
./jive-manager.sh start web
# 访问: http://localhost:3021

# 5) 健康检查
curl http://127.0.0.1:8012/health
```

排错提示：如出现 “role postgres does not exist”，通常是误连到本机 5432 或使用了错误用户。请确认连接的是 5433 端口，用户/密码为 `postgres/postgres`，或显式设置 `export DATABASE_URL=postgresql://postgres:postgres@localhost:5433/jive_money` 后重试。

### 数据库迁移说明（重要修复）

- 迁移 `016_fix_families_member_count_and_superadmin.sql`：
  - 为 `families` 表新增 `member_count` 列并回填，修复注册流程依赖该字段导致的 400 错误。
  - 统一开发环境的 superadmin 账号与密码（见上）。
- 若你的数据库卷较早创建，建议强制重放迁移以确保 016 被执行：
  - `./jive-api/scripts/migrate_local.sh --db-url postgresql://postgres:postgres@localhost:5433/jive_money --force`

## 📱 支持平台

- ✅ Web (Chrome, Firefox, Safari)
- ✅ iOS (10.0+)
- ✅ Android (API 21+)
- ✅ macOS (10.14+)
- ✅ Linux (Ubuntu 18.04+)
- ✅ Windows (10+)

## 🔍 故障排查

### 端口被占用
启动脚本会自动检测并提示处理，或手动修改 `.env` 文件中的端口配置。

### 依赖安装失败
- Rust: 访问 https://rustup.rs/
- Flutter: 访问 https://flutter.dev/docs/get-started/install
- PostgreSQL: 使用系统包管理器安装

### 查看详细日志
```bash
# 查看所有日志
tail -f logs/*.log

# 查看特定服务日志
tail -f logs/rust_server.log
tail -f logs/flutter_web.log
```

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 联系

如有问题，请提交 Issue 或联系维护者。
<!-- ci: routing tests verify -->
<!-- ci: routing tests verify 2 -->
