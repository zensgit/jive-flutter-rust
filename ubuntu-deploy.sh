#!/bin/bash

# Ubuntu 自动化部署脚本
# 完全容器化部署，适合 Ubuntu/Linux 环境

set -e

echo "🐧 Ubuntu/Linux 自动化部署脚本"
echo "================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查系统
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo -e "${RED}❌ 此脚本仅适用于 Linux 系统${NC}"
    exit 1
fi

# 设置项目路径
PROJECT_ROOT="/home/$(whoami)/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust"
SYMLINK_PATH="$HOME/jive-project"

echo "📍 项目路径: $PROJECT_ROOT"

# 创建软链接
if [ ! -L "$SYMLINK_PATH" ]; then
    echo "🔗 创建软链接..."
    ln -s "$PROJECT_ROOT" "$SYMLINK_PATH"
    echo -e "${GREEN}✅ 软链接创建成功: $SYMLINK_PATH${NC}"
else
    echo "✅ 软链接已存在"
fi

cd "$PROJECT_ROOT"

# 检查依赖
check_dependencies() {
    echo ""
    echo "🔍 检查系统依赖..."
    
    local missing_deps=()
    
    # 检查 Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    else
        echo "✅ Docker 已安装: $(docker --version)"
    fi
    
    # 检查 Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        # 尝试 docker compose
        if ! docker compose version &> /dev/null; then
            missing_deps+=("docker-compose")
        else
            echo "✅ Docker Compose 已安装: $(docker compose version)"
        fi
    else
        echo "✅ Docker Compose 已安装: $(docker-compose --version)"
    fi
    
    # 检查 Flutter
    if ! command -v flutter &> /dev/null; then
        missing_deps+=("flutter")
    else
        echo "✅ Flutter 已安装: $(flutter --version | head -n 1)"
    fi
    
    # 检查 Git
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    else
        echo "✅ Git 已安装: $(git --version)"
    fi
    
    # 如果有缺失的依赖
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠️ 缺失以下依赖:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "   - $dep"
        done
        echo ""
        echo "是否自动安装缺失的依赖? (y/n)"
        read -r install_deps
        if [[ "$install_deps" == "y" ]]; then
            install_dependencies "${missing_deps[@]}"
        else
            echo -e "${RED}❌ 请手动安装缺失的依赖后重试${NC}"
            exit 1
        fi
    fi
}

# 安装依赖
install_dependencies() {
    echo ""
    echo "📦 开始安装依赖..."
    
    # 更新包列表
    sudo apt-get update
    
    for dep in "$@"; do
        case $dep in
            docker)
                echo "🐳 安装 Docker..."
                curl -fsSL https://get.docker.com -o get-docker.sh
                sudo sh get-docker.sh
                sudo usermod -aG docker $USER
                rm get-docker.sh
                echo -e "${GREEN}✅ Docker 安装完成${NC}"
                echo -e "${YELLOW}⚠️ 请重新登录以使 Docker 权限生效${NC}"
                ;;
            docker-compose)
                echo "🐳 安装 Docker Compose..."
                sudo apt-get install -y docker-compose-plugin
                echo -e "${GREEN}✅ Docker Compose 安装完成${NC}"
                ;;
            flutter)
                echo "🎯 安装 Flutter..."
                sudo snap install flutter --classic
                flutter doctor
                echo -e "${GREEN}✅ Flutter 安装完成${NC}"
                ;;
            git)
                echo "📦 安装 Git..."
                sudo apt-get install -y git
                echo -e "${GREEN}✅ Git 安装完成${NC}"
                ;;
        esac
    done
}

# Docker 服务管理
manage_docker_services() {
    echo ""
    echo "🐳 Docker 服务管理"
    echo "=================="
    
    cd jive-api
    
    # 检查 docker-compose.dev.yml 是否存在
    if [ ! -f "docker-compose.dev.yml" ]; then
        echo -e "${RED}❌ docker-compose.dev.yml 文件不存在${NC}"
        exit 1
    fi
    
    # 构建镜像
    echo "🔨 构建 Docker 镜像..."
    docker-compose -f docker-compose.dev.yml build
    
    # 启动服务
    echo "🚀 启动 Docker 服务..."
    docker-compose -f docker-compose.dev.yml up -d
    
    # 等待服务启动
    echo "⏳ 等待服务启动..."
    sleep 10
    
    # 检查服务状态
    echo ""
    echo "📊 服务状态:"
    docker-compose -f docker-compose.dev.yml ps
    
    # 初始化数据库
    echo ""
    echo "🗄️ 初始化数据库..."
    docker-compose -f docker-compose.dev.yml exec -T postgres psql -U postgres -c "CREATE DATABASE jive_money;" 2>/dev/null || true
    
    # 运行迁移
    if [ -d "../database/migrations" ]; then
        echo "📝 运行数据库迁移..."
        for migration in ../database/migrations/*.sql; do
            if [ -f "$migration" ]; then
                echo "   执行: $(basename $migration)"
                docker-compose -f docker-compose.dev.yml exec -T postgres psql -U postgres -d jive_money -f "/docker-entrypoint-initdb.d/$(basename $migration)" 2>/dev/null || true
            fi
        done
    fi
    
    cd ..
}

# Flutter 应用管理
manage_flutter_app() {
    echo ""
    echo "🎯 Flutter 应用管理"
    echo "==================="
    
    cd jive-flutter
    
    # 获取依赖
    echo "📦 获取 Flutter 依赖..."
    flutter pub get
    
    # 启动 Web 服务器
    echo "🌐 启动 Flutter Web 服务器..."
    flutter run -d web-server --web-port 3021 > /tmp/flutter.log 2>&1 &
    FLUTTER_PID=$!
    
    echo "✅ Flutter Web 服务已启动 (PID: $FLUTTER_PID)"
    echo "   URL: http://localhost:3021"
    
    cd ..
    
    return $FLUTTER_PID
}

# 显示服务信息
show_service_info() {
    echo ""
    echo "========================================="
    echo -e "${GREEN}✅ 所有服务已成功启动！${NC}"
    echo "========================================="
    echo ""
    echo "📍 服务访问地址:"
    echo "   • API 服务: http://localhost:8012"
    echo "   • Web 应用: http://localhost:3021"
    echo "   • 数据库管理: http://localhost:8080"
    echo "   • Redis 管理: http://localhost:8001"
    echo ""
    echo "🔧 常用命令:"
    echo "   • 查看日志: docker-compose -f jive-api/docker-compose.dev.yml logs -f"
    echo "   • 停止服务: docker-compose -f jive-api/docker-compose.dev.yml down"
    echo "   • 重启服务: docker-compose -f jive-api/docker-compose.dev.yml restart"
    echo "   • 进入容器: docker-compose -f jive-api/docker-compose.dev.yml exec jive-api bash"
    echo ""
    echo "📝 注意事项:"
    echo "   • 首次运行可能需要较长时间下载镜像"
    echo "   • 确保端口 8012, 3021, 5433, 6380, 8080 未被占用"
    echo "   • 数据库数据保存在 Docker 卷中"
    echo ""
}

# 健康检查
health_check() {
    echo "🏥 执行健康检查..."
    
    # 检查 API
    if curl -s http://localhost:8012/health > /dev/null; then
        echo "✅ API 服务正常"
    else
        echo -e "${YELLOW}⚠️ API 服务未响应${NC}"
    fi
    
    # 检查数据库
    if docker-compose -f jive-api/docker-compose.dev.yml exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
        echo "✅ 数据库服务正常"
    else
        echo -e "${YELLOW}⚠️ 数据库服务未响应${NC}"
    fi
    
    # 检查 Redis
    if docker-compose -f jive-api/docker-compose.dev.yml exec -T redis redis-cli ping > /dev/null 2>&1; then
        echo "✅ Redis 服务正常"
    else
        echo -e "${YELLOW}⚠️ Redis 服务未响应${NC}"
    fi
}

# 清理函数
cleanup() {
    echo ""
    echo "🧹 清理中..."
    
    # 停止 Flutter
    if [ ! -z "$FLUTTER_PID" ]; then
        kill $FLUTTER_PID 2>/dev/null || true
    fi
    
    # 停止 Docker 服务
    cd jive-api
    docker-compose -f docker-compose.dev.yml down
    cd ..
    
    echo "✅ 清理完成"
}

# 主流程
main() {
    # 设置清理钩子
    trap cleanup EXIT
    
    # 拉取最新代码
    echo "📥 拉取最新代码..."
    git pull origin main || true
    
    # 检查依赖
    check_dependencies
    
    # 管理 Docker 服务
    manage_docker_services
    
    # 管理 Flutter 应用
    manage_flutter_app
    FLUTTER_PID=$?
    
    # 健康检查
    echo ""
    health_check
    
    # 显示服务信息
    show_service_info
    
    # 保持运行
    echo -e "${YELLOW}按 Ctrl+C 停止所有服务...${NC}"
    
    # 等待用户中断
    while true; do
        sleep 1
    done
}

# 运行主程序
main "$@"