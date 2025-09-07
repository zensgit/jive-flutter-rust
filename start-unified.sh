#!/bin/bash

# 统一启动脚本 - 自动适配 macOS 和 Ubuntu
set -e

echo "🚀 Jive Money 统一启动器"
echo "========================="

# 检测操作系统
OS="$(uname -s)"
case "${OS}" in
    Linux*)     SYSTEM=Linux;;
    Darwin*)    SYSTEM=Mac;;
    *)          SYSTEM="UNKNOWN:${OS}";;
esac

echo "📍 检测到系统: $SYSTEM"

# 设置项目根目录
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

# 启动Docker服务
start_docker_services() {
    echo "🐳 启动Docker服务..."
    
    # 检查Docker是否运行
    if ! docker info > /dev/null 2>&1; then
        echo "❌ Docker未运行，请先启动Docker"
        exit 1
    fi
    
    # 启动数据库和Redis
    cd jive-api
    docker-compose -f docker-compose.dev.yml up -d postgres redis
    
    # 等待数据库就绪
    echo "⏳ 等待数据库启动..."
    sleep 5
    
    # 初始化数据库
    echo "🗄️ 初始化数据库..."
    docker-compose -f docker-compose.dev.yml exec -T postgres psql -U postgres -c "CREATE DATABASE jive_money;" 2>/dev/null || true
    
    cd ..
}

# macOS策略: API本地 + Docker数据库
start_macos() {
    echo "🍎 使用macOS混合模式: API本地 + Docker数据库"
    
    # 启动Docker服务
    start_docker_services
    
    # 启动本地API
    echo "🦀 启动Rust API (本地)..."
    cd jive-api
    cargo build --release
    DATABASE_URL="postgresql://postgres:postgres@localhost:5433/jive_money" \
    REDIS_URL="redis://localhost:6380" \
    API_PORT=8012 \
    cargo run --release &
    API_PID=$!
    cd ..
    
    # 启动Flutter Web
    echo "🎯 启动Flutter Web..."
    cd jive-flutter
    flutter pub get
    flutter run -d web-server --web-port 3021 &
    FLUTTER_PID=$!
    cd ..
    
    echo "✅ 服务已启动:"
    echo "   - API: http://localhost:8012"
    echo "   - Web: http://localhost:3021"
    echo "   - 数据库: localhost:5433"
    echo "   - Redis: localhost:6380"
    
    # 等待退出信号
    echo ""
    echo "按 Ctrl+C 停止所有服务..."
    trap "kill $API_PID $FLUTTER_PID; docker-compose -f jive-api/docker-compose.dev.yml down" EXIT
    wait
}

# Ubuntu策略: 全Docker
start_ubuntu() {
    echo "🐧 使用Ubuntu Docker模式: 全容器化"
    
    cd jive-api
    
    # 构建镜像
    echo "🔨 构建Docker镜像..."
    docker-compose -f docker-compose.dev.yml build
    
    # 启动所有服务
    echo "🚀 启动所有服务..."
    docker-compose -f docker-compose.dev.yml up -d
    
    # 启动Flutter Web
    echo "🎯 启动Flutter Web..."
    cd ../jive-flutter
    flutter pub get
    flutter run -d web-server --web-port 3021 &
    FLUTTER_PID=$!
    cd ..
    
    echo "✅ 服务已启动:"
    echo "   - API: http://localhost:8012"
    echo "   - Web: http://localhost:3021"
    echo "   - 数据库: localhost:5433"
    echo "   - Redis: localhost:6380"
    echo "   - Adminer: http://localhost:8080"
    
    # 查看日志
    echo ""
    echo "📝 查看日志: docker-compose -f jive-api/docker-compose.dev.yml logs -f"
    
    # 等待退出信号
    echo ""
    echo "按 Ctrl+C 停止所有服务..."
    trap "kill $FLUTTER_PID; docker-compose -f jive-api/docker-compose.dev.yml down" EXIT
    wait
}

# 根据系统选择启动策略
case "$SYSTEM" in
    Mac)
        start_macos
        ;;
    Linux)
        start_ubuntu
        ;;
    *)
        echo "❌ 不支持的系统: $SYSTEM"
        exit 1
        ;;
esac