#!/bin/bash

# 快速启动脚本 - 使用Release模式编译以提高性能
set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== Jive API 快速启动 (Release模式) ==="

# 检查是否已编译
if [ -f "target/release/jive-api" ]; then
    BINARY_TIME=$(stat -f "%m" target/release/jive-api 2>/dev/null || stat -c "%Y" target/release/jive-api 2>/dev/null)
    SOURCE_TIME=$(find src -type f -name "*.rs" -exec stat -f "%m" {} \; 2>/dev/null | sort -n | tail -1 || \
                  find src -type f -name "*.rs" -exec stat -c "%Y" {} \; 2>/dev/null | sort -n | tail -1)
    
    if [ "$BINARY_TIME" -ge "$SOURCE_TIME" ] 2>/dev/null; then
        echo -e "${GREEN}✅ 使用已编译的Release版本${NC}"
        SKIP_BUILD=true
    fi
fi

# 清理端口
PORT=${API_PORT:-8012}
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  端口${PORT}已被占用，正在停止...${NC}"
    lsof -Pi :$PORT -sTCP:LISTEN -t | xargs kill -9 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}✅ 已清理端口${PORT}${NC}"
fi

# 快速启动Docker服务（如果未运行）
echo "📦 检查Docker服务..."
if ! docker ps | grep -q jive-postgres-docker; then
    echo "启动数据库..."
    docker-compose -f docker-compose.macos.yml up -d postgres redis 2>/dev/null || true
    sleep 2
fi

# 只在需要时编译
if [ "$SKIP_BUILD" != "true" ]; then
    echo "🔨 编译Release版本..."
    # 使用更快的编译选项
    CARGO_BUILD_JOBS=4 cargo build --release --quiet 2>/dev/null || cargo build --release
    echo -e "${GREEN}✅ 编译完成${NC}"
fi

# 设置环境变量（减少不必要的功能）
DB_PORT=${DB_PORT:-5433}
export DATABASE_URL=${DATABASE_URL:-"postgresql://postgres:postgres@localhost:$DB_PORT/jive_money"}
export REDIS_URL=${REDIS_URL:-"redis://localhost:6380"}
export API_PORT=$PORT
export JWT_SECRET="your-secret-key-here"
export RUST_LOG="warn,jive_api=info"  # 减少日志输出
export CORS_DEV=1
export SQLX_OFFLINE=true

# 禁用自动更新任务以加快启动
export DISABLE_SCHEDULED_TASKS=true

echo ""
echo "🚀 启动API服务..."
echo "================================"
echo "API地址: http://localhost:${PORT}"
echo "================================"
echo ""
echo "快速测试："
echo "  curl http://localhost:${PORT}/health"
echo ""
echo "停止服务："
echo "  按 Ctrl+C"
echo ""

# 运行Release版本
exec target/release/jive-api
