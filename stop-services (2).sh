#!/bin/bash

# Jive Flutter Rust - 服务停止脚本
# 用法: ./stop-services.sh

echo "=== 停止 Jive Money 服务 ==="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 停止服务的函数
stop_service() {
    local port=$1
    local name=$2
    
    if lsof -ti:$port > /dev/null 2>&1; then
        echo -e "${YELLOW}⏹  正在停止 $name (端口 $port)...${NC}"
        lsof -ti:$port | xargs kill -9 2>/dev/null
        sleep 1
        echo -e "${GREEN}✓ $name 已停止${NC}"
    else
        echo -e "ℹ️  $name 未运行"
    fi
}

# 从 PID 文件停止服务
stop_from_pid() {
    local pidfile=$1
    local name=$2
    
    if [ -f "$pidfile" ]; then
        PID=$(cat $pidfile)
        if ps -p $PID > /dev/null 2>&1; then
            echo -e "${YELLOW}⏹  正在停止 $name (PID: $PID)...${NC}"
            kill -9 $PID 2>/dev/null
            echo -e "${GREEN}✓ $name 已停止${NC}"
        fi
        rm -f $pidfile
    fi
}

# 停止 API 服务
echo "🔍 检查 API 服务..."
stop_from_pid ".api.pid" "API 服务"
stop_service 8012 "API 服务"

# 停止 Web 服务
echo ""
echo "🔍 检查 Web 服务..."
stop_from_pid ".web.pid" "Web 服务"
stop_service 3021 "Web 服务"

# 清理其他可能的 jive 进程
echo ""
echo "🔍 清理其他 Jive 进程..."
pkill -f "jive-api" 2>/dev/null
pkill -f "flutter run" 2>/dev/null

# 检查状态
echo ""
echo "=== 最终状态 ==="

if ! lsof -ti:8012 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 端口 8012 已释放${NC}"
else
    echo -e "${RED}✗ 端口 8012 仍被占用${NC}"
fi

if ! lsof -ti:3021 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 端口 3021 已释放${NC}"
else
    echo -e "${RED}✗ 端口 3021 仍被占用${NC}"
fi

echo ""
echo -e "${GREEN}🎉 服务停止完成！${NC}"