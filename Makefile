.PHONY: help install check start stop dev build test clean docker-up docker-down

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

# 安装依赖
install:
	@echo "安装 Rust 依赖..."
	@cd jive-core && cargo build
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
	@cd jive-core && cargo build --release
	@echo "✅ Rust 构建完成"

build-flutter:
	@echo "构建 Flutter Web 生产版本..."
	@cd jive-flutter && flutter build web --release
	@echo "✅ Flutter 构建完成"

# 运行测试
test: test-rust test-flutter

test-rust:
	@echo "运行 Rust 测试..."
	@cd jive-core && cargo test

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
	@echo "运行数据库迁移..."
	@cd jive-core && cargo run --bin migrate

db-seed:
	@echo "填充测试数据..."
	@cd jive-core && cargo run --bin seed

db-reset:
	@echo "重置数据库..."
	@cd jive-core && cargo run --bin reset

# 查看日志
logs:
	@tail -f logs/*.log

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