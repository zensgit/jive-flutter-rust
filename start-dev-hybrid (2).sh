#!/bin/bash
# 智能混合开发启动脚本 - 根据系统选择最佳方案

echo "🚀 启动Jive开发环境..."

# 检测操作系统
OS=$(uname -s)
ARCH=$(uname -m)

cd ~/jive-project

if [ "$OS" = "Darwin" ]; then
    echo "🍎 检测到macOS ($ARCH) - 使用本地模式"
    
    # macOS: 本地运行API，Docker只运行数据库
    echo "📦 启动数据库服务..."
    
    # 创建macOS专用的docker-compose
    cat > ~/jive-project/jive-api/docker-compose.mac.yml << 'DOCKER_EOF'
version: '3.8'

services:
  postgres:
    image: postgres:16-alpine
    container_name: jive-postgres-mac
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: jive_money
    ports:
      - "5432:5432"
    volumes:
      - postgres_mac_data:/var/lib/postgresql/data
      - ./migrations:/docker-entrypoint-initdb.d:ro
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: jive-redis-mac
    ports:
      - "6379:6379"
    volumes:
      - redis_mac_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  adminer:
    image: adminer
    container_name: jive-adminer-mac
    ports:
      - "8080:8080"
    environment:
      ADMINER_DEFAULT_SERVER: postgres
    depends_on:
      - postgres

volumes:
  postgres_mac_data:
  redis_mac_data:
DOCKER_EOF
    
    # 启动数据库服务
    cd jive-api
    docker-compose -f docker-compose.mac.yml down 2>/dev/null
    docker-compose -f docker-compose.mac.yml up -d
    
    # 等待数据库就绪
    echo "⏳ 等待数据库启动..."
    sleep 5
    
    # 运行迁移
    echo "📝 运行数据库迁移..."
    for file in migrations/*.sql; do
        docker exec -i jive-postgres-mac psql -U postgres -d jive_money < "$file" 2>/dev/null
    done
    
    # 启动API (本地)
    echo "🦀 启动Rust API (本地)..."
    cd ~/jive-project/jive-api
    export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/jive_money"
    export REDIS_URL="redis://localhost:6379"
    export API_PORT=8012
    export RUST_LOG=debug
    cargo run --release --bin jive-api &
    API_PID=$!
    
    # 启动Flutter
    echo "🎯 启动Flutter Web..."
    cd ~/jive-project/jive-flutter
    flutter run -d web-server --web-port 3021 &
    FLUTTER_PID=$!
    
    echo ""
    echo "✅ macOS开发环境已启动 (混合模式)"
    echo "  - API: http://localhost:8012 (本地Rust)"
    echo "  - Flutter: http://localhost:3021"
    echo "  - 数据库: localhost:5432 (Docker)"
    echo "  - Redis: localhost:6379 (Docker)"
    echo "  - Adminer: http://localhost:8080"
    echo ""
    echo "📝 进程ID:"
    echo "  - API PID: $API_PID"
    echo "  - Flutter PID: $FLUTTER_PID"
    echo ""
    echo "🛑 停止命令:"
    echo "  kill $API_PID $FLUTTER_PID"
    echo "  docker-compose -f docker-compose.mac.yml down"
    
elif [ "$OS" = "Linux" ]; then
    echo "🐧 检测到Linux - 使用Docker模式"
    
    # Linux: 全部使用Docker
    cd jive-api
    docker-compose -f docker-compose.dev.yml down 2>/dev/null
    docker-compose -f docker-compose.dev.yml up -d
    
    echo "⏳ 等待服务启动..."
    sleep 5
    
    # 启动Flutter
    cd ~/jive-project/jive-flutter
    flutter run -d web-server --web-port 3021 &
    
    echo ""
    echo "✅ Linux开发环境已启动 (Docker模式)"
    echo "  - API: http://localhost:8012 (Docker)"
    echo "  - Flutter: http://localhost:3021"
    echo "  - 数据库: localhost:5433 (Docker)"
    echo "  - Redis: localhost:6380 (Docker)"
    echo "  - Adminer: http://localhost:8080"
    
else
    echo "❌ 不支持的操作系统: $OS"
    exit 1
fi

echo ""
echo "✨ 开发环境已就绪!"
