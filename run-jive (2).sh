#!/bin/bash

# Jive Money - 一键运行脚本（使用nohup保持后台运行）
# 用法: ./run-jive.sh

echo "🚀 启动 Jive Money 系统..."
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 创建日志目录
mkdir -p logs

# 杀死已存在的进程
echo "🔍 清理已存在的进程..."
lsof -ti:8012 | xargs kill -9 2>/dev/null
lsof -ti:3021 | xargs kill -9 2>/dev/null
pkill -f "jive-api" 2>/dev/null
sleep 2

# 启动API服务
echo "📦 启动 API 服务器 (端口 8012)..."
cd jive-api
if [ -f "target/release/jive-api" ]; then
    nohup ./target/release/jive-api > ../logs/api.log 2>&1 &
    echo $! > ../.api.pid
    echo -e "${GREEN}✓ API服务已启动 (PID: $(cat ../.api.pid))${NC}"
else
    echo -e "${YELLOW}⚠️  正在编译 API 服务...${NC}"
    cargo build --release
    nohup ./target/release/jive-api > ../logs/api.log 2>&1 &
    echo $! > ../.api.pid
    echo -e "${GREEN}✓ API服务已启动 (PID: $(cat ../.api.pid))${NC}"
fi
cd ..

# 等待API启动
echo "⏳ 等待API服务就绪..."
for i in {1..10}; do
    if curl -s http://localhost:8012/health > /dev/null 2>&1; then
        echo -e "${GREEN}✓ API服务已就绪${NC}"
        break
    fi
    sleep 1
done

# 启动Web服务
echo "🌐 启动 Web 服务器 (端口 3021)..."
cd jive-flutter

# 检查构建
if [ ! -d "build/web" ]; then
    echo -e "${YELLOW}⚠️  Web构建不存在，正在构建...${NC}"
    flutter build web --release
fi

# 使用nohup启动Python服务器
nohup python3 -m http.server 3021 --directory build/web > ../logs/web.log 2>&1 &
echo $! > ../.web.pid
echo -e "${GREEN}✓ Web服务已启动 (PID: $(cat ../.web.pid))${NC}"
cd ..

# 验证服务
echo ""
echo "🔍 验证服务状态..."
sleep 2

API_OK=false
WEB_OK=false

if curl -s http://localhost:8012/health > /dev/null 2>&1; then
    API_OK=true
fi

if curl -s http://localhost:3021 > /dev/null 2>&1; then
    WEB_OK=true
fi

echo ""
echo "========================================="
echo "           Jive Money 系统状态            "
echo "========================================="
echo ""

if [ "$API_OK" = true ]; then
    echo -e "API 服务:  ${GREEN}✓ 运行中${NC}"
    echo "   地址:   http://localhost:8012"
    echo "   健康检查: http://localhost:8012/health"
else
    echo -e "API 服务:  ${RED}✗ 未运行${NC}"
    echo "   请查看日志: logs/api.log"
fi

echo ""

if [ "$WEB_OK" = true ]; then
    echo -e "Web 应用:  ${GREEN}✓ 运行中${NC}"
    echo "   地址:   http://localhost:3021"
else
    echo -e "Web 应用:  ${RED}✗ 未运行${NC}"
    echo "   请查看日志: logs/web.log"
fi

echo ""
echo "========================================="

if [ "$API_OK" = true ] && [ "$WEB_OK" = true ]; then
    echo ""
    echo -e "${GREEN}🎉 系统启动成功！${NC}"
    echo ""
    echo "📱 在浏览器中访问: http://localhost:3021"
    echo ""
    echo "📝 查看日志:"
    echo "   tail -f logs/api.log    # API日志"
    echo "   tail -f logs/web.log    # Web日志"
    echo ""
    echo "🛑 停止服务:"
    echo "   ./stop-services.sh"
else
    echo ""
    echo -e "${RED}⚠️  部分服务启动失败，请查看日志文件${NC}"
fi