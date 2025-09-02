#!/bin/bash

# Jive Flutter Rust - 服务启动脚本
# 用法: ./start-services.sh

echo "=== 启动 Jive Money 服务 ==="
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
    ./target/release/jive-api > ../logs/api.log 2>&1 &
    API_PID=$!
    echo -e "${GREEN}✓ API 服务已启动 (PID: $API_PID)${NC}"
else
    echo -e "${YELLOW}⚠️  Release 版本不存在，正在编译...${NC}"
    cargo build --release
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
if [ ! -d "build/web" ]; then
    echo -e "${YELLOW}⚠️  Web 构建不存在，正在构建...${NC}"
    flutter build web --release
fi

# 使用 Python HTTP 服务器
python3 -m http.server 3021 --directory build/web > ../logs/web.log 2>&1 &
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