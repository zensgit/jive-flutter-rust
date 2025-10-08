#!/bin/bash

# 简单的Docker构建脚本（使用本地PostgreSQL）

set -e

echo "构建Docker镜像（使用本地数据库）..."

# 设置环境变量
export DATABASE_URL="postgresql://postgres:postgres@host.docker.internal:5432/jive_money"
export SQLX_OFFLINE=false

# 构建镜像
docker build \
    --build-arg DATABASE_URL="${DATABASE_URL}" \
    --platform linux/arm64 \
    -t jive-api:latest \
    -f Dockerfile.simple \
    .

echo "镜像构建完成！"
echo ""
echo "运行容器："
echo "docker run -d -p 8012:8012 --name jive-api jive-api:latest"