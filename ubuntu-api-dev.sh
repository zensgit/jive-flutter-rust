#!/bin/bash

echo "🚀 Ubuntu API开发模式启动脚本"
echo ""

# 选择模式
echo "请选择API运行模式："
echo "1. Docker模式（隔离环境）"
echo "2. 本地模式（快速开发）"
echo "3. 混合模式（Docker数据库+本地API）"
read -p "选择 (1/2/3): " choice

case $choice in
    1)
        echo "启动Docker模式..."
        cd jive-api
        docker-compose -f docker-compose.dev.yml up -d
        echo "✅ Docker API运行在: http://localhost:18012"
        ;;
    2)
        echo "启动本地模式..."
        # 停止Docker API
        docker-compose -f jive-api/docker-compose.dev.yml stop jive-api

        # 启动本地API
        cd jive-api
        export DATABASE_URL=postgresql://postgres:postgres@localhost:15432/jive_money
        export REDIS_URL=redis://localhost:16379
        export API_PORT=18012
        cargo run
        ;;
    3)
        echo "启动混合模式..."
        # 只启动数据库服务
        cd jive-api
        docker-compose -f docker-compose.dev.yml up -d postgres redis

        # 本地运行API
        export DATABASE_URL=postgresql://postgres:postgres@localhost:15432/jive_money
        export REDIS_URL=redis://localhost:16379
        export API_PORT=18012
        cargo run
        ;;
    *)
        echo "无效选择"
        exit 1
        ;;
esac