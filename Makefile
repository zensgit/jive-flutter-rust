.PHONY: help install check start stop dev build test clean docker-up docker-down api-dev api-safe

# 默认目标
help:
	@echo "Jive Flutter-Rust 项目命令"
	@echo ""
	@echo "可用命令:"
	@echo "  make install      - 安装所有依赖"
	@echo "  make check        - 检查依赖和端口"
	@echo "  make start        - 启动所有服务"
	@echo "  make stop         - 停止所有服务"
	@echo "  make dev          - 开发模式（热重载）"
	@echo "  make build        - 构建生产版本"
	@echo "  make test         - 运行所有测试"
	@echo "  make clean        - 清理构建文件"
	@echo "  make docker-up    - 使用 Docker 启动"
	@echo "  make docker-down  - 停止 Docker 服务"
	@echo "  make status       - 查看服务状态"
	@echo "  make logs         - 查看日志"
	@echo "  make api-dev      - 启动完整版 API (CORS_DEV=1)"
	@echo "  make api-safe     - 启动完整版 API (安全CORS模式)"
	@echo "  make sqlx-prepare-core - 准备 jive-core (server,db) 的 SQLx 元数据"
	@echo "  make api-dev-core-export - 启动 API 并启用 core_export（走核心导出路径）"
	@echo "  make db-dev-up    - 启动 Docker 开发数据库/Redis/Adminer (15432/16379/19080)"
	@echo "  make db-dev-down  - 停止 Docker 开发数据库/Redis/Adminer"
	@echo "  make api-dev-docker-db - 本地 API 连接 Docker 开发数据库 (15432)"
	@echo "  make db-dev-status - 显示 Docker 开发数据库/Redis/Adminer 与 API 端口状态"
	@echo "  make metrics-check  - 基础指标一致性校验 (/health vs /metrics)"
	@echo "  make seed-bcrypt-user - 插入一个 bcrypt 测试用户 (触发登录重哈希)"

# 安装依赖
install:
	@echo "安装 Rust 依赖..."
	@cd jive-core && cargo build --no-default-features --features server
	@echo "安装 Flutter 依赖..."
	@cd jive-flutter && flutter pub get
	@echo "✅ 依赖安装完成"

# 检查环境
check:
	@./start.sh 2

# 启动服务
start:
	@./start.sh start

# 停止服务
stop:
	@./start.sh stop

# 开发模式
dev:
	@./start.sh dev

# 查看状态
status:
	@./start.sh status

# 构建生产版本
build: build-rust build-flutter

build-rust:
	@echo "构建 Rust 生产版本..."
	@cd jive-core && cargo build --release --no-default-features --features server
	@echo "✅ Rust 构建完成"

build-flutter:
	@echo "构建 Flutter Web 生产版本..."
	@cd jive-flutter && flutter build web --release
	@echo "✅ Flutter 构建完成"

# 运行测试
test: test-rust test-flutter

test-rust:
	@echo "运行 Rust API 测试 (SQLX_OFFLINE=true)..."
	@cd jive-api && SQLX_OFFLINE=true cargo test --tests

test-flutter:
	@echo "运行 Flutter 测试..."
	@cd jive-flutter && flutter test

# 清理构建文件
clean:
	@echo "清理构建文件..."
	@cd jive-core && cargo clean
	@cd jive-flutter && flutter clean
	@rm -rf logs/
	@echo "✅ 清理完成"

# Docker 命令
docker-up:
	@echo "启动 Docker 服务..."
	@docker-compose up -d
	@echo "✅ Docker 服务已启动"
	@echo "访问: http://localhost:3000"

docker-down:
	@echo "停止 Docker 服务..."
	@docker-compose down
	@echo "✅ Docker 服务已停止"

docker-build:
	@echo "构建 Docker 镜像..."
	@docker-compose build
	@echo "✅ Docker 镜像构建完成"

docker-logs:
	@docker-compose logs -f

# 数据库操作
db-migrate:
	@echo "运行数据库迁移 (jive-api/scripts/migrate_local.sh)..."
	@cd jive-api && ./scripts/migrate_local.sh --force

db-seed:
	@echo "填充测试数据 (运行迁移并可选导入种子)..."
	@cd jive-api && ./scripts/migrate_local.sh || true
	@echo "如需创建/更新超级管理员，可设置 DATABASE_URL 后执行: psql $$DATABASE_URL -f scripts/upsert_superadmin.sql"

db-reset:
	@echo "重置数据库 (jive-api/scripts/reset-db.sh)..."
	@cd jive-api && ./scripts/reset-db.sh

# 查看日志
logs:
	@tail -f logs/*.log

# ---- API helpers ----
api-clippy:
	@echo "Clippy (API, deny warnings, SQLx offline)..."
	@cd jive-api && SQLX_OFFLINE=true cargo clippy -- -D warnings

api-sqlx-check:
	@echo "SQLx offline cache check (API strict)..."
	@cd jive-api && SQLX_OFFLINE=true cargo sqlx prepare --check

sqlx-prepare-api:
	@echo "Prepare SQLx metadata for API (requires DB ready + migrations applied)..."
	@cd jive-api && cargo install sqlx-cli --no-default-features --features postgres || true
	@cd jive-api && SQLX_OFFLINE=false cargo sqlx prepare

api-lint:
	@echo "API lint: SQLx offline check + Clippy (deny warnings)"
	@$(MAKE) api-sqlx-check
	@$(MAKE) api-clippy

# One-shot: migrate local DB (5433) and refresh SQLx cache for API
api-sqlx-prepare-local:
	@echo "Migrating local DB (default DB_PORT=5433) and preparing SQLx cache..."
	@cd jive-api && DB_PORT=$${DB_PORT:-5433} ./scripts/migrate_local.sh --force
	@cd jive-api && cargo install sqlx-cli --no-default-features --features postgres || true
	@cd jive-api && SQLX_OFFLINE=false cargo sqlx prepare

# Prepare SQLx metadata for jive-core (server,db)
sqlx-prepare-core:
	@echo "准备 jive-core SQLx 元数据 (features=server,db)..."
	@echo "确保数据库与迁移就绪 (优先 5433)..."
	@cd jive-api && DB_PORT=$${DB_PORT:-5433} ./scripts/migrate_local.sh --force || true
	@cd jive-core && cargo install sqlx-cli --no-default-features --features postgres || true
	@cd jive-core && \
		DATABASE_URL=$${DATABASE_URL:-postgresql://postgres:postgres@localhost:$${DB_PORT:-5433}/jive_money} \
		SQLX_OFFLINE=false cargo sqlx prepare -- --features "server,db"
	@echo "✅ 已生成 jive-core/.sqlx 元数据"


# 启动完整版 API（宽松 CORS 开发模式，支持自定义端口 API_PORT）
api-dev:
	@echo "启动完整版 API (CORS_DEV=1, 端口 $${API_PORT:-8012})..."
	@cd jive-api && CORS_DEV=1 API_PORT=$${API_PORT:-8012} cargo run --bin jive-api

# 启动完整版 API（安全 CORS：白名单 + 受控头部）
api-safe:
	@echo "启动完整版 API (安全 CORS 模式, 端口 $${API_PORT:-8012})..."
	@cd jive-api && unset CORS_DEV && API_PORT=$${API_PORT:-8012} cargo run --bin jive-api
# 启动完整版 API（宽松 CORS + 启用 core_export，导出走 jive-core Service）
api-dev-core-export:
	@echo "启动 API (CORS_DEV=1, 启用 core_export, 端口 $${API_PORT:-8012})..."
	@cd jive-api && CORS_DEV=1 API_PORT=$${API_PORT:-8012} cargo run --features core_export --bin jive-api

# ---- Docker DB + Local API (Dev) ----
db-dev-up:
	@echo "启动 Docker 开发数据库/Redis/Adminer (端口: PG=5433, Redis=6380, Adminer=9080)..."
	@cd jive-api && docker-compose -f docker-compose.dev.yml up -d postgres redis adminer
	@echo "✅ Postgres: postgresql://postgres:postgres@localhost:5433/jive_money"
	@echo "✅ Redis:    redis://localhost:6380"
	@echo "✅ Adminer:  http://localhost:9080"

db-dev-down:
	@echo "停止 Docker 开发数据库/Redis/Adminer..."
	@cd jive-api && docker-compose -f docker-compose.dev.yml down
	@echo "✅ 已停止"

api-dev-docker-db:
	@echo "本地运行 API (连接 Docker 开发数据库 5433; CORS_DEV=1, SQLX_OFFLINE=true)..."
	@cd jive-api && \
		CORS_DEV=1 \
		API_PORT=$${API_PORT:-8012} \
		SQLX_OFFLINE=true \
		RUST_LOG=$${RUST_LOG:-info} \
		DATABASE_URL=$${DATABASE_URL:-postgresql://postgres:postgres@localhost:5433/jive_money} \
		cargo run --bin jive-api

db-dev-status:
	@echo "🔎 Docker 开发栈容器状态 (postgres/redis/adminer):"
	@docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'jive-(postgres|redis|adminer)-dev' || echo "(未启动)"
	@echo ""
	@echo "📡 建议的连接信息:"
	@echo "  - Postgres: postgresql://postgres:postgres@localhost:5433/jive_money"
	@echo "  - Redis:    redis://localhost:6380"
	@echo "  - Adminer:  http://localhost:9080"
	@echo ""
	@echo "🩺 API (本地) 端口状态:"
	@lsof -iTCP:$${API_PORT:-8012} -sTCP:LISTEN 2>/dev/null || echo "(端口 $${API_PORT:-8012} 未监听)"
	@echo ""
	@echo "🌿 /health:"
	@curl -fsS http://localhost:$${API_PORT:-8012}/health 2>/dev/null || echo "(API 未响应)"

# ---- Metrics & Dev Utilities ----
metrics-check:
	@echo "运行指标一致性脚本..."
	@cd jive-api && ./scripts/check_metrics_consistency.sh || true
	@echo "抓取 /metrics 关键行:" && curl -fsS http://localhost:$${API_PORT:-8012}/metrics | grep -E 'password_hash_|jive_build_info|export_requests_' || true

seed-bcrypt-user:
	@echo "插入 bcrypt 测试用户 (若不存在)..."
	@cd jive-api && cargo run --bin hash_password --quiet -- 'TempBcrypt123!' >/dev/null 2>&1 || true
	@psql $${DATABASE_URL:-postgresql://postgres:postgres@localhost:5433/jive_money} -c "DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM users WHERE email='bcrypt_test@example.com') THEN INSERT INTO users (email,password_hash,name,is_active,created_at,updated_at) VALUES ('bcrypt_test@example.com', crypt('TempBcrypt123!','bf'), 'Bcrypt Test', true, NOW(), NOW()); END IF; END $$;" 2>/dev/null || echo "⚠️ 需要本地 Postgres 运行 (5433)"
	@echo "测试登录: curl -X POST -H 'Content-Type: application/json' -d '{\"email\":\"bcrypt_test@example.com\",\"password\":\"TempBcrypt123!\"}' http://localhost:$${API_PORT:-8012}/api/v1/auth/login"

# 代码格式化
format:
	@echo "格式化 Rust 代码..."
	@cd jive-core && cargo fmt
	@echo "格式化 Flutter 代码..."
	@cd jive-flutter && dart format .
	@echo "✅ 代码格式化完成"

# 代码检查
lint:
	@echo "检查 Rust 代码..."
	@cd jive-core && cargo clippy
	@echo "检查 Flutter 代码..."
	@cd jive-flutter && flutter analyze
	@echo "✅ 代码检查完成"
