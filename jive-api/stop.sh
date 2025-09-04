#!/bin/bash

# Jive API 停止脚本

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== 停止Jive API服务 ===${NC}"
echo ""

cd "$(dirname "$0")"

# 停止Docker容器
echo -e "${BLUE}🛑 停止Docker容器...${NC}"
docker-compose -f docker-compose.macos.yml down

echo -e "${GREEN}✅ 所有服务已停止${NC}"

# 可选：清理数据
echo ""
echo -e "如需清理数据，运行:"
echo "  docker-compose -f docker-compose.macos.yml down -v"