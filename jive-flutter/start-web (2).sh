#!/bin/bash

# Flutter Web 启动脚本
# 构建并服务Flutter Web应用

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Jive Flutter Web 启动脚本 ===${NC}"
echo ""

cd "$(dirname "$0")"

# 1. 清理旧端口
if lsof -i :3021 > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  端口3021已被占用，正在停止...${NC}"
    lsof -ti :3021 | xargs kill -9 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}✅ 已清理端口3021${NC}"
fi

# 2. 获取依赖
echo -e "${BLUE}📦 获取Flutter依赖...${NC}"
flutter pub get

# 3. 构建Web应用
echo -e "${BLUE}🔨 构建Flutter Web应用...${NC}"
flutter build web --no-tree-shake-icons

# 4. 启动服务器
echo -e "${BLUE}🚀 启动Web服务器...${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Flutter Web地址: http://localhost:3021${NC}"
echo -e "${GREEN}API服务地址: http://localhost:8012${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo -e "${YELLOW}提示：按 Ctrl+C 停止服务器${NC}"
echo ""

# 使用Python服务器托管构建的文件
cd build/web
python3 -m http.server 3021