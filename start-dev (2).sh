#!/bin/bash
# 跨平台开发启动脚本

echo "🚀 启动Jive开发环境..."

# 检测操作系统
OS=$(uname -s)
echo "📍 检测到系统: $OS"

# 进入项目目录
cd ~/jive-project/jive-api

# 停止可能存在的旧容器
docker-compose -f docker-compose.dev.yml down 2>/dev/null

# 启动Docker服务
echo "🐳 启动Docker服务..."
docker-compose -f docker-compose.dev.yml up -d

# 等待服务就绪
echo "⏳ 等待服务启动..."
sleep 5

# 检查服务状态
echo "✅ 服务状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(NAME|jive)"

echo ""
echo "📱 访问地址:"
echo "  - API服务: http://localhost:8012"
echo "  - Flutter Web: http://localhost:3021" 
echo "  - 数据库管理: http://localhost:8080"
echo ""
echo "🔧 常用命令:"
echo "  - 查看日志: docker logs -f jive-api-dev"
echo "  - 停止服务: docker-compose -f docker-compose.dev.yml down"
echo ""
echo "✨ 开发环境已就绪!"
