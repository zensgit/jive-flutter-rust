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

### 本地端口与钩子（建议）
- 端口约定：本地 Docker/管理脚本默认映射 PostgreSQL 到 `5433`，Redis 到 `6380`，Adminer 到 `9080`；API 默认 `8012`。
  - `jive-api/docker-compose.dev.yml` 已与 `jive-manager.sh` 对齐：`5433:5432`、`6380:6379`、`9080:8080`。
- 启用预提交钩子（保证本地提交即跑 SQLx 严格校验与 Clippy）：
  ```bash
  make hooks
  ```

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

### Docker 数据库 + 本地 API（推荐开发流程）

```bash
# 1) 启动 Docker 开发数据库/Redis/Adminer（端口：PG=5433, Redis=6380, Adminer=9080）
make db-dev-up

# 2) 本地运行 API，连接 Docker 数据库（CORS_DEV=1, SQLX_OFFLINE=true, API 默认 8012）
make api-dev-docker-db

# 3) 健康检查
curl -s http://localhost:8012/health

# 4) 管理数据库（Adminer）
# 打开 http://localhost:9080 ，使用 postgres/postgres 登录，数据库 jive_money

# 5) 停止 Docker 开发栈
make db-dev-down
```

### JWT 密钥配置

环境变量 `JWT_SECRET` 用于签发与验证访问令牌：

```bash
export JWT_SECRET=$(openssl rand -hex 32)
```

未设置时（或留空）API 会在开发 / 测试自动使用一个不安全的占位并打印警告，不可在生产依赖该默认值。

### 监控与指标 (Metrics)

| Endpoint    | 用途              | 认证 | 备注 |
|-------------|-------------------|------|------|
| `/health`   | 探活 + 快照       | 否   | 轻量 JSON：hash 分布、rehash 状态、汇率指标等 |
| `/metrics`  | Prometheus 拉取    | 否   | 文本格式指标（适合长期监控） |

规范指标（推荐使用）：
```
password_hash_bcrypt_total              # bcrypt (2a+2b+2y)
password_hash_argon2id_total            # argon2id 数量
password_hash_unknown_total             # 未识别前缀
password_hash_total_count               # 总数
password_hash_bcrypt_variant{variant="2b"} X  # 每个变体
jive_password_rehash_total              # 成功重哈希次数（bcrypt→argon2id）
jive_password_rehash_fail_total         # 重哈希失败次数（不会阻断登录）
jive_password_rehash_fail_breakdown_total{cause="hash"|"update"} # 重哈希失败按原因
export_requests_buffered_total          # 缓冲导出请求次数（POST CSV/JSON）
export_requests_stream_total            # 流式导出请求次数（GET CSV streaming, feature=export_stream）
export_rows_buffered_total              # 缓冲导出累计行数
export_rows_stream_total                # 流式导出累计行数
jive_build_info{...}                   # 构建信息 (value=1)
auth_login_fail_total                  # 登录失败（未知用户 / 密码不匹配）
auth_login_inactive_total              # 非激活账号登录尝试
auth_login_rate_limited_total          # 登录被速率限制次数 (429)
jive_build_info{commit,time,rustc,version} 1  # 构建信息 gauge
export_duration_buffered_seconds_*     # 缓冲导出耗时直方图 (bucket/sum/count)
export_duration_stream_seconds_*       # 流式导出耗时直方图 (bucket/sum/count)
process_uptime_seconds                 # 进程运行时长（秒）
jive_build_info{commit,time,rustc,version} 1  # 构建信息 gauge
```

兼容旧指标（DEPRECATED，将在 2 个发布周期后移除，详见 docs/METRICS_DEPRECATION_PLAN.md）：
```
jive_password_hash_users{algo="bcrypt_2b"}
```

Prometheus 抓取示例：
```yaml
scrape_configs:
  - job_name: jive-api
    metrics_path: /metrics
    scrape_interval: 15s
    static_configs:
      - targets: ["api-host:8012"]
```

一致性快速校验（bcrypt 聚合与 /metrics 是否匹配）：
```bash
H=$(curl -s http://localhost:8012/health)
M=$(curl -s http://localhost:8012/metrics)
echo "Health bcrypt sum:" \
  $(echo "$H" | jq '.metrics.hash_distribution.bcrypt | (."2a"+."2b"+."2y")')
echo "Metrics bcrypt total:" \
  $(grep '^password_hash_bcrypt_total' <<<"$M" | awk '{print $2}')
```

运维建议：
- 大规模用户场景可为 hash 查询加 30s 内存缓存（计划中）。
- 迁移所有看板后移除旧的 jive_password_hash_users* 系列（目标 v1.2.0）。
- 监控 `jive_password_rehash_fail_total`，持续增长提示 DB 更新/并发异常。
- 导出耗时直方图示例：
```promql
# P95 缓冲导出耗时
histogram_quantile(0.95, sum(rate(export_duration_buffered_seconds_bucket[5m])) by (le))

# 最近 1 分钟流式导出平均耗时
sum(rate(export_duration_stream_seconds_sum[1m])) / sum(rate(export_duration_stream_seconds_count[1m]))
```

### 密码重哈希（bcrypt → Argon2id）

登录成功后，如检测到旧 bcrypt 哈希，系统会在 `REHASH_ON_LOGIN` 未显式关闭时（默认开启）尝试透明升级为 Argon2id：

```bash
# 关闭重哈希（例如压测环境需要保留原样）
export REHASH_ON_LOGIN=0
```

失败不会阻断登录，仅记录 warn 日志。设计说明见 `docs/PASSWORD_REHASH_DESIGN.md`。

### 超级管理员默认密码说明

仓库历史存在两个默认密码基线：

| 密码 | 出现来源 | 当前优先级 |
|------|----------|------------|
| `admin123` | 早期迁移：`005_create_superadmin.sql` / `006_update_superadmin_password.sql` / `016_fix_families_member_count_and_superadmin.sql` | 旧（可能仍在本地旧库残留） |
| `SuperAdmin@123` | 后续迁移：`009_create_superadmin_user.sql` 与补偿脚本 | 新（建议统一） |

实际生效取决于“最后一次在你的数据库中执行成功的迁移顺序”。如果你基于较新的全量迁移（包含 009 及之后）初始化数据库，默认应为 `SuperAdmin@123`（Argon2）。如果本地数据库较早创建，仍可能是 `admin123`（bcrypt 或 Argon2）。

判定与处理建议：
1. 直接尝试两次登录（先 `SuperAdmin@123`，再 `admin123`）。
2. 若均失败，可在本地用工具重置：
   ```bash
   cargo run -p jive-money-api --bin hash_password -- SuperAdmin@123
   # 得到哈希后：
   psql "$DATABASE_URL" -c "UPDATE users SET password_hash='<HASH>' WHERE LOWER(email)='superadmin@jive.money';"
   ```
3. 重置后立即登录并修改为你的本地私有密码（不要提交哈希）。

注意事项：
- 重新“干净”初始化数据库（删除数据卷 / 新建数据库）后会再次回到迁移脚本指定的默认值。
- 请勿将生产环境实际超级管理员密码写入仓库或日志。
- 如果团队决定最终统一为 `SuperAdmin@123` 以外的基线，请新增新的迁移并在此表格中更新来源说明。

快速登录测试（假设使用新基线）：
```bash
curl -s -X POST http://localhost:8012/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"superadmin@jive.money","password":"SuperAdmin@123"}'
```
若返回 JSON 含 `token` 字段表示成功。生产中请务必改成强随机密码并限制暴露。 

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
  - 在 PR 自动评论首 80 行 diff 预览（仓库内 PR；Fork PR 仅 artifact）
  - 失败退出，提示提交更新后的 `.sqlx/`

该脚本会：
- 尝试用 Docker 启动本地 Postgres/Redis（如已安装）
- 运行迁移、校验 SQLx 离线缓存（仅校验，不生成）
  - 可选：配置 Docker Hub 认证以避免镜像拉取限流（公共镜像 postgres/redis 等）
    - 参见 `.github/DOCKER_AUTH_SETUP.md`（添加 DOCKERHUB_USERNAME / DOCKERHUB_TOKEN Secrets）
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

### CI 必要检查（main 分支保护）

当前 main 的 Required checks：

- `Flutter Tests`
- `Rust API Tests`
- `Rust API Clippy (blocking)`（`-D warnings`）
- `Rustfmt Check`（阻塞）
- `Cargo Deny Check`（安全与许可）

注意：
- PR 首次不稳定阶段，可将 `Cargo Deny` 保持非阻塞，但推荐尽快修复并转为阻塞。
- 本地建议：启用 git hooks（一次性）：`make hooks`，自动在提交前执行 `make api-lint`。
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

## 🚨 CI 故障排查

### SQLx 离线缓存不匹配

CI 中最常见的失败是 SQLx 离线缓存不匹配。当你修改了数据库查询或模型时，需要更新 SQLx 缓存：

#### 三步修复法：
```bash
# 1. 确保数据库是最新的
cd jive-api && ./scripts/migrate_local.sh --force

# 2. 重新生成离线缓存
SQLX_OFFLINE=false cargo sqlx prepare

# 3. 提交更新后的缓存
git add .sqlx && git commit -m "chore(sqlx): update offline cache"
```

#### 端口配置说明：
- **开发环境**: PostgreSQL 运行在 `5433` 端口（避免与系统数据库冲突）
- **CI 环境**: PostgreSQL 运行在 `5432` 端口（标准端口）
- **API 服务**: 统一使用 `8012` 端口
- **Flutter Web**: 使用 `3021` 端口

#### 常见 CI 错误及解决方案：

**1. SQLx 缓存不匹配**
```
Error: SQLx offline cache mismatch detected
```
解决：按照上述三步修复法更新缓存

**2. 端口冲突**
```
Error: Address already in use (os error 98)
```
解决：检查端口占用或修改配置文件中的端口

**3. 数据库连接失败**
```
Error: Failed to connect to database
```
解决：
- 检查数据库服务是否启动
- 验证连接字符串格式
- 确认防火墙设置

**4. Rust Core 双模式检查失败**
```
Error: jive-core server mode failed
```
解决：
- 检查 `jive-core/Cargo.toml` 中的 feature 配置
- 确保所有依赖都支持指定的 feature
- 运行 `cd jive-core && cargo check --features server`

**5. Flutter 分析器警告**
```
Warning: flutter analyze found issues
```
解决：
- 运行 `cd jive-flutter && flutter analyze`
- 修复所有报告的问题
- 考虑在 `analysis_options.yaml` 中调整规则

**6. Cargo Deny 检查失败**
```
Error: cargo deny check failed
```
解决：
- 检查 `deny.toml` 配置
- 更新有问题的依赖版本
- 在必要时添加例外规则

**7. Rustfmt 格式检查失败**
```
Error: rustfmt check failed
```
解决：
- 运行 `cargo fmt --all`
- 提交格式化后的代码

#### 本地 CI 测试

在推送代码前，可以运行本地 CI 检查：

```bash
# 完整的本地 CI 流程
chmod +x scripts/ci_local.sh
./scripts/ci_local.sh

# 单独测试 SQLx
cd jive-api
SQLX_OFFLINE=true cargo sqlx prepare --check

# 单独测试格式化
cargo fmt --all -- --check

# 单独测试 Clippy
cargo clippy --all-features -- -D warnings
```

#### CI 配置概览

- **Rust Core Check**: 恢复为阻断模式（fail-fast: true）
- **Cargo Deny**: 非阻断模式（初期警告，后期可改为阻断）
- **Rustfmt Check**: 非阻断模式（初期警告，后期可改为阻断）
- **Flutter Tests**: 继续进行模式（允许部分测试失败）
- **SQLx Check**: 严格阻断模式（必须通过）

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 联系

如有问题，请提交 Issue 或联系维护者。
环境变量 (Metrics & 安全):
```
AUTH_RATE_LIMIT=30/60               # 60 秒窗口内最多 30 次登录尝试 (默认 30/60)
AUTH_RATE_LIMIT_HASH_EMAIL=1        # 限流键中对 email 做哈希截断 (默认1)
ALLOW_PUBLIC_METRICS=1              # 设为 0 时启用白名单
METRICS_ALLOW_CIDRS=127.0.0.1/32    # 逗号分隔 CIDR 列表 (ALLOW_PUBLIC_METRICS=0 生效)
METRICS_DENY_CIDRS=                 # 可选拒绝 CIDR (deny 优先)
METRICS_CACHE_TTL=30                # /metrics 缓存秒数 (0 禁用)
```

Grafana 仪表板: `docs/GRAFANA_DASHBOARD_TEMPLATE.json`
Alert 规则示例: `docs/ALERT_RULES_EXAMPLE.yaml`
安全清单: `docs/SECURITY_CHECKLIST.md`
快速验证脚本: `scripts/verify_observability.sh`
