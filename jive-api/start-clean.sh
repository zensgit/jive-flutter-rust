#!/bin/bash

# Jive API 清洁启动脚本 - 自动处理端口占用和孤立容器

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Jive API 清洁启动 ===${NC}"
echo ""

cd "$(dirname "$0")"

# 1. 检查并停止占用8012端口的进程
if lsof -i :8012 > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  端口8012已被占用，正在停止...${NC}"
    PID=$(lsof -ti :8012)
    kill $PID 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}✅ 已清理端口8012${NC}"
fi

# 2. 清理孤立的Docker容器
echo -e "${BLUE}🧹 清理Docker环境...${NC}"
docker-compose -f docker-compose.macos.yml down --remove-orphans 2>/dev/null || true
docker-compose -f docker-compose.full.yml down --remove-orphans 2>/dev/null || true

# 3. 启动数据库和Redis
echo -e "${BLUE}📦 启动数据库容器...${NC}"
docker-compose -f docker-compose.macos.yml up -d postgres redis

# 4. 等待服务就绪
echo -e "${BLUE}⏳ 等待服务就绪...${NC}"
sleep 3

# 检查PostgreSQL
if docker exec jive-postgres-docker pg_isready -U postgres > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PostgreSQL就绪（端口5433）${NC}"
else
    echo -e "${RED}❌ PostgreSQL未就绪${NC}"
    exit 1
fi

# 检查Redis
if docker exec jive-redis-docker redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Redis就绪（端口6380）${NC}"
else
    echo -e "${RED}❌ Redis未就绪${NC}"
    exit 1
fi

# 5. 检查数据库
DB_PORT=${DB_PORT:-5433}
if psql postgresql://postgres:postgres@localhost:$DB_PORT/jive_money -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ 数据库jive_money存在${NC}"
else
    echo -e "${YELLOW}📝 创建数据库jive_money...${NC}"
    psql postgresql://postgres:postgres@localhost:$DB_PORT -c "CREATE DATABASE jive_money;" 2>/dev/null || true
    
    # 运行迁移
    echo -e "${YELLOW}🔄 运行数据库迁移...${NC}"
    for migration in migrations/*.sql; do
        if [ -f "$migration" ]; then
            echo "  - $(basename $migration)"
            psql postgresql://postgres:postgres@localhost:$DB_PORT/jive_money -f "$migration" > /dev/null 2>&1 || true
        fi
    done
    echo -e "${GREEN}✅ 数据库初始化完成${NC}"
fi

# 6. 启动API
echo ""
echo -e "${BLUE}🚀 启动API服务...${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}API地址: http://localhost:8012${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}快速测试：${NC}"
echo "  curl http://localhost:8012/health"
echo ""
echo -e "${YELLOW}停止服务：${NC}"
echo "  按 Ctrl+C"
echo ""

# 设置环境变量并运行
export DATABASE_URL=${DATABASE_URL:-"postgresql://postgres:postgres@localhost:$DB_PORT/jive_money"}
export REDIS_URL="redis://localhost:6380"
export API_PORT=8012
export RUST_LOG=info

# 运行API
cargo run --bin jive-api
