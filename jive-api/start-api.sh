#!/bin/bash

# Jive Money API 启动脚本

# 设置环境变量
export RUST_LOG=info
# Allow overriding via environment; default to local dev conventions
export API_PORT=${API_PORT:-8012}
# Prefer Docker/manager default 5433 for local dev; fall back to 5432
export DB_PORT=${DB_PORT:-5433}
export DATABASE_URL=${DATABASE_URL:-"postgresql://postgres:postgres@localhost:$DB_PORT/jive_money"}

echo "🚀 启动 Jive Money API..."
echo "📦 配置："
echo "   - 端口: $API_PORT"
echo "   - 数据库: jive_money"
echo "   - 日志级别: $RUST_LOG"
echo ""

# 编译并运行
cargo run --bin jive-api-simple

# 如果要运行完整版本（包含WebSocket），请使用：
# cargo run --bin jive-api-ws
