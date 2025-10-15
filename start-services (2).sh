#!/bin/bash

# Jive Flutter Rust - 服务启动脚本
# 用法: ./start-services.sh

echo "=== 启动 Jive Money 服务 ==="
echo ""

# 确保日志目录存在（脚本中会将日志写到 ./logs）
mkdir -p logs
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查并杀死已存在的进程
echo "🔍 检查现有服务..."
if lsof -ti:8012 > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  端口 8012 已被占用，正在停止...${NC}"
    lsof -ti:8012 | xargs kill -9 2>/dev/null
    sleep 1
fi

if lsof -ti:3021 > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  端口 3021 已被占用，正在停止...${NC}"
    lsof -ti:3021 | xargs kill -9 2>/dev/null
    sleep 1
fi

# 启动 Rust API 服务
echo ""
echo "🚀 启动 Rust API 服务 (端口 8012)..."
cd jive-api
if [ -f "target/release/jive-api" ]; then
    DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5433/jive_money}" \
    REDIS_URL="${REDIS_URL:-redis://localhost:6380}" \
    API_PORT="${API_PORT:-8012}" \
    ./target/release/jive-api > ../logs/api.log 2>&1 &
    API_PID=$!
    echo -e "${GREEN}✓ API 服务已启动 (PID: $API_PID)${NC}"
else
    echo -e "${YELLOW}⚠️  Release 版本不存在，正在编译...${NC}"
    if ! command -v cargo >/dev/null 2>&1; then
        echo -e "${RED}✗ 未检测到 Rust/cargo，请先安装 Rust 或在 docker 环境中运行${NC}"
        exit 1
    fi
    cargo build --release
    DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5433/jive_money}" \
    REDIS_URL="${REDIS_URL:-redis://localhost:6380}" \
    API_PORT="${API_PORT:-8012}" \
    ./target/release/jive-api > ../logs/api.log 2>&1 &
    API_PID=$!
    echo -e "${GREEN}✓ API 服务已启动 (PID: $API_PID)${NC}"
fi
cd ..

# 等待 API 服务启动
echo "⏳ 等待 API 服务就绪..."
sleep 3

# 检查 API 健康状态
if curl -s http://localhost:8012/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ API 服务健康检查通过${NC}"
else
    echo -e "${RED}✗ API 服务健康检查失败${NC}"
fi

# 启动 Flutter Web 服务
echo ""
echo "🌐 启动 Flutter Web 服务 (端口 3021)..."
cd jive-flutter

# 检查是否需要构建
NEED_BUILD=0
FORCE_REBUILD=0
if [ "$1" = "--rebuild" ]; then
  FORCE_REBUILD=1
fi

if [ ! -f "build/web/index.html" ] || [ ! -f "build/web/main.dart.js" ]; then
  NEED_BUILD=1
fi

if [ $FORCE_REBUILD -eq 1 ] || [ $NEED_BUILD -eq 1 ]; then
  echo -e "${YELLOW}⚠️  触发 Web 构建...${NC}"
  if ! command -v flutter >/dev/null 2>&1; then
    echo -e "${RED}✗ 未检测到 Flutter，请先安装并配置 Flutter 环境${NC}"
    exit 1
  fi
  flutter clean
  # Disable PWA + wasm dry run + icon tree-shaking (workaround dynamic IconData)
  flutter build web --release \
    --no-wasm-dry-run \
    --pwa-strategy=none \
    --no-tree-shake-icons
else
  echo -e "${GREEN}✓ 发现现有 Web 构建，跳过构建${NC}"
fi

# 使用 Python HTTP 服务器（优先 python3，不存在则回退 python）
PY_BIN="python3"
if ! command -v python3 >/dev/null 2>&1; then
  if command -v python >/dev/null 2>&1; then
    PY_BIN="python"
  else
    echo -e "${RED}✗ 未检测到 Python，请安装 python3 或 python${NC}"
    exit 1
  fi
fi

$PY_BIN -m http.server 3021 --directory build/web > ../logs/web.log 2>&1 &
WEB_PID=$!
echo -e "${GREEN}✓ Web 服务已启动 (PID: $WEB_PID)${NC}"
cd ..

# 等待 Web 服务启动
sleep 2

# 显示服务状态
echo ""
echo "=== 服务状态 ==="
echo -e "${GREEN}✓ API 服务: http://localhost:8012${NC}"
echo -e "  健康检查: http://localhost:8012/health"
echo -e "  API 文档: http://localhost:8012/api-docs"
echo ""
echo -e "${GREEN}✓ Web 应用: http://localhost:3021${NC}"
echo ""
echo "📝 日志文件:"
echo "  - API 日志: logs/api.log"
echo "  - Web 日志: logs/web.log"
echo ""
echo -e "${YELLOW}提示: 使用 ./stop-services.sh 停止所有服务${NC}"

# 保存 PID 到文件以便停止脚本使用
echo $API_PID > .api.pid
echo $WEB_PID > .web.pid

echo ""
echo -e "${GREEN}🎉 所有服务已成功启动！${NC}"
echo "   请在浏览器中访问: http://localhost:3021"
