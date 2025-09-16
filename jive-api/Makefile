# Jive API Makefile
# 支持 MacBook M4 和 Ubuntu 的便捷命令

.PHONY: help build dev prod up down restart logs status clean test shell db-shell migrate

# 默认目标：显示帮助
help:
	@echo "Jive API 快捷命令"
	@echo ""
	@echo "Docker 命令:"
	@echo "  make build      - 构建 Docker 镜像"
	@echo "  make dev        - 启动开发环境（热重载）"
	@echo "  make prod       - 启动生产环境"
	@echo "  make up         - 启动服务（生产模式）"
	@echo "  make down       - 停止所有服务"
	@echo "  make restart    - 重启所有服务"
	@echo "  make logs       - 查看日志"
	@echo "  make status     - 查看服务状态"
	@echo "  make clean      - 清理容器和卷"
	@echo ""
	@echo "开发命令:"
	@echo "  make test       - 运行测试"
	@echo "  make shell      - 进入容器 shell"
	@echo "  make db-shell   - 进入数据库 shell"
	@echo "  make migrate    - 运行数据库迁移"
	@echo ""
	@echo "本地开发:"
	@echo "  make local-run  - 本地运行（不使用 Docker）"
	@echo "  make local-test - 本地测试"
	@echo "  make fmt        - 格式化代码"
	@echo "  make lint       - 代码检查"

# Docker 相关命令
build:
	./docker-run.sh build

dev:
	./docker-run.sh dev

prod:
	./docker-run.sh prod

up:
	./docker-run.sh up

down:
	./docker-run.sh down

restart:
	./docker-run.sh restart

logs:
	./docker-run.sh logs -f

status:
	./docker-run.sh status

clean:
	./docker-run.sh clean

test:
	./docker-run.sh test

shell:
	./docker-run.sh shell

db-shell:
	./docker-run.sh db-shell

	migrate:
	./docker-run.sh migrate

# Run migrations against local DB (no Docker)
.PHONY: migrate-local
migrate-local:
	@chmod +x scripts/migrate_local.sh
	./scripts/migrate_local.sh

# 本地开发命令
local-run:
	cargo run --bin jive-api

local-test:
	cargo test

fmt:
	cargo fmt

lint:
	cargo clippy -- -D warnings

# SQLx 离线缓存
.PHONY: sqlx-prepare sqlx-check
sqlx-prepare:
	@echo "Preparing SQLx offline cache..."
	@DATABASE_URL=${DATABASE_URL} ./prepare-sqlx.sh

sqlx-check:
	@echo "Checking SQLx offline cache against current schema..."
	@SQLX_OFFLINE=true cargo sqlx prepare --check || (echo "SQLx cache out of date. Run 'make sqlx-prepare'" && exit 1)

# 快速启动开发环境
quick-start: build dev
	@echo "开发环境已启动！"
	@echo "API: http://localhost:8012"
	@echo "Adminer: http://localhost:8080"
	@echo "RedisInsight: http://localhost:8001"
