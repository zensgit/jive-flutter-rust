#!/bin/bash

# 多架构Docker构建脚本
# 同时支持MacBook M4 (ARM64) 和 Ubuntu (AMD64)

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== 多架构Docker镜像构建 ===${NC}"
echo ""

# 检查Docker buildx
if ! docker buildx version > /dev/null 2>&1; then
    echo -e "${RED}错误: Docker buildx 未安装${NC}"
    exit 1
fi

# 创建或使用现有的buildx构建器
BUILDER_NAME="jive-multiarch-builder"

if ! docker buildx ls | grep -q $BUILDER_NAME; then
    echo -e "${YELLOW}创建新的buildx构建器...${NC}"
    docker buildx create --name $BUILDER_NAME --use
else
    echo -e "${GREEN}使用现有的buildx构建器${NC}"
    docker buildx use $BUILDER_NAME
fi

# 启动构建器
docker buildx inspect --bootstrap

# 选择构建模式
echo ""
echo "选择构建模式:"
echo "1. 仅构建当前架构 (快速)"
echo "2. 构建多架构 (ARM64 + AMD64)"
echo "3. 构建并推送到Docker Hub (需要登录)"
read -p "请选择 [1-3]: " choice

case $choice in
    1)
        echo -e "${BLUE}构建当前架构...${NC}"
        docker buildx build \
            --platform local \
            --tag jive-api:latest \
            --file Dockerfile.multiarch \
            --load \
            .
        ;;
    2)
        echo -e "${BLUE}构建多架构镜像...${NC}"
        docker buildx build \
            --platform linux/amd64,linux/arm64 \
            --tag jive-api:multiarch \
            --file Dockerfile.multiarch \
            .
        echo -e "${YELLOW}注意: 多架构镜像已构建但未加载到本地${NC}"
        echo -e "${YELLOW}使用 'docker buildx build --load' 加载单一架构到本地${NC}"
        ;;
    3)
        read -p "Docker Hub 用户名: " username
        echo -e "${BLUE}构建并推送多架构镜像...${NC}"
        docker buildx build \
            --platform linux/amd64,linux/arm64 \
            --tag $username/jive-api:latest \
            --tag $username/jive-api:$(date +%Y%m%d) \
            --file Dockerfile.multiarch \
            --push \
            .
        ;;
    *)
        echo -e "${RED}无效选择${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}=== 构建完成 ===${NC}"
echo ""
echo "运行容器示例:"
echo "  docker run -d -p 8012:8012 \\"
echo "    -e DATABASE_URL=postgresql://user:pass@host:5432/db \\"
echo "    -e REDIS_URL=redis://host:6379 \\"
echo "    --name jive-api \\"
echo "    jive-api:latest"