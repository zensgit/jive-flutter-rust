#!/bin/bash

# Jive API 启动脚本 - MacOS版本
# 使用Docker运行数据库，本地运行API

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Jive API 启动脚本 ===${NC}"
echo ""

# 1. 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    echo -e "${RED}❌ Docker未运行，请先启动Docker Desktop${NC}"
    exit 1
fi

# 2. 启动数据库容器
echo -e "${BLUE}📦 启动数据库容器...${NC}"
cd "$(dirname "$0")"

# 检查容器是否已经运行
if docker ps | grep -q "jive-postgres-docker"; then
    echo -e "${GREEN}✅ PostgreSQL容器已在运行${NC}"
else
    docker-compose -f docker-compose.macos.yml up -d postgres
    echo -e "${GREEN}✅ PostgreSQL容器已启动（端口5433）${NC}"
fi

if docker ps | grep -q "jive-redis-docker"; then
    echo -e "${GREEN}✅ Redis容器已在运行${NC}"
else
    docker-compose -f docker-compose.macos.yml up -d redis
    echo -e "${GREEN}✅ Redis容器已启动（端口6380）${NC}"
fi

# 3. 等待数据库就绪
echo -e "${BLUE}⏳ 等待数据库就绪...${NC}"
sleep 3

# 4. 检查数据库连接
if psql postgresql://postgres:postgres@localhost:5433/jive_money -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 数据库连接成功${NC}"
else
    echo -e "${YELLOW}⚠️  数据库连接失败，尝试创建数据库...${NC}"
    psql postgresql://postgres:postgres@localhost:5433 -c "CREATE DATABASE jive_money;" 2>/dev/null || true
fi

# 5. 运行API
echo -e "${BLUE}🚀 启动API服务...${NC}"
echo -e "${GREEN}API将运行在: http://localhost:8012${NC}"
echo ""
echo -e "${YELLOW}提示：${NC}"
echo "  - 健康检查: curl http://localhost:8012/health"
echo "  - 停止服务: Ctrl+C"
echo "  - 查看日志: docker-compose -f docker-compose.macos.yml logs -f"
echo ""

# 设置环境变量并运行
export DATABASE_URL="postgresql://postgres:postgres@localhost:5433/jive_money"
export REDIS_URL="redis://localhost:6380"
export API_PORT=8012
export RUST_LOG=info

cargo run --bin jive-api