#!/bin/bash

# Jive API Docker 管理脚本 (网络修复版)
# 支持 MacBook M4 (ARM64) 和 Ubuntu (AMD64)
# 解决Docker Registry连接问题

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Docker Compose 命令
DOCKER_COMPOSE="docker compose"

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
Jive Money API Docker 管理脚本 (网络修复版)

用法: ./docker-run-fixed.sh [命令] [选项]

命令:
    fix-network   自动修复Docker网络连接问题
    build         构建镜像
    dev           启动开发环境 (带热重载)
    prod          启动生产环境
    stop          停止所有服务
    restart       重启服务
    logs          查看日志 (-f 实时查看)
    status        查看服务状态
    clean         清理所有容器和数据
    shell         进入 API 容器 shell
    db-shell      进入数据库容器 shell
    health        检查服务健康状态
    test-network  测试网络连接
    help          显示此帮助信息

网络修复选项:
    --mirrors     使用国内镜像源
    --offline     离线模式 (使用本地镜像)
    --proxy       使用代理服务器

示例:
    ./docker-run-fixed.sh fix-network    # 修复网络问题
    ./docker-run-fixed.sh dev --mirrors  # 使用镜像源启动开发环境
    ./docker-run-fixed.sh build --offline # 离线构建镜像

EOF
}

# 检查 Docker 是否安装并运行
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker 守护进程未运行，请启动 Docker"
        exit 1
    fi
    
    # 检查 Docker Compose
    if ! docker compose version &> /dev/null; then
        if ! command -v docker-compose &> /dev/null; then
            print_error "Docker Compose 未安装"
            exit 1
        fi
        DOCKER_COMPOSE="docker-compose"
    fi
}

# 测试网络连接
test_network() {
    print_info "测试Docker网络连接..."
    
    # 测试Docker Hub连接
    print_info "测试 Docker Hub 连接..."
    if timeout 10 curl -s https://registry-1.docker.io/v2/ &>/dev/null; then
        print_success "✅ Docker Hub 连接正常"
        return 0
    else
        print_error "❌ Docker Hub 连接失败"
        
        # 测试国内镜像源
        print_info "测试国内镜像源..."
        for mirror in "docker.mirrors.ustc.edu.cn" "hub-mirror.c.163.com" "mirror.ccs.tencentyun.com"; do
            if timeout 10 curl -s https://$mirror &>/dev/null; then
                print_success "✅ $mirror 可用"
                return 0
            else
                print_warning "⚠️  $mirror 不可用"
            fi
        done
        
        return 1
    fi
}

# 修复Docker网络问题
fix_network() {
    print_info "开始修复Docker网络问题..."
    
    # 备份现有配置
    if [ -f /etc/docker/daemon.json ]; then
        print_info "备份现有Docker配置..."
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
    fi
    
    # 创建新的daemon.json
    print_info "配置Docker镜像源..."
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com",
    "https://registry.docker-cn.com",
    "https://dockerhub.azk8s.cn"
  ],
  "insecure-registries": [],
  "debug": false,
  "experimental": false,
  "features": {
    "buildkit": true
  },
  "dns": ["8.8.8.8", "114.114.114.114"]
}
EOF
    
    # 重启Docker服务
    print_info "重启Docker服务..."
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    
    # 等待Docker启动
    print_info "等待Docker服务启动..."
    sleep 5
    
    # 验证修复
    if test_network; then
        print_success "🎉 网络问题修复成功！"
        return 0
    else
        print_error "网络问题仍然存在，尝试其他解决方案..."
        return 1
    fi
}

# 创建离线docker-compose文件
create_offline_compose() {
    print_info "创建离线Docker Compose配置..."
    
    cat > docker-compose.offline.yml <<EOF
version: '3.8'

services:
  # PostgreSQL 数据库 (使用已有本地镜像或系统安装)
  postgres:
    image: postgres:15-alpine
    container_name: jive-postgres-offline
    restart: unless-stopped
    environment:
      POSTGRES_DB: jive_money
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      PGDATA: /var/lib/postgresql/data/pgdata
    ports:
      - "5433:5432"  # 使用不同端口避免冲突
    volumes:
      - postgres-offline-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d jive_money"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Redis 缓存 (简化版本)
  redis:
    image: redis:7-alpine
    container_name: jive-redis-offline
    restart: unless-stopped
    command: redis-server --appendonly yes
    ports:
      - "6380:6379"  # 使用不同端口避免冲突
    volumes:
      - redis-offline-data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  postgres-offline-data:
    driver: local
  redis-offline-data:
    driver: local

networks:
  default:
    name: jive-offline-network
EOF

    print_success "离线Docker Compose配置已创建"
}

# 启动服务 (修复版)
start_services() {
    MODE=${1:-prod}
    USE_MIRRORS=${2:-false}
    OFFLINE_MODE=${3:-false}
    
    check_docker
    
    if [ "$OFFLINE_MODE" = "true" ]; then
        print_info "启动离线模式..."
        create_offline_compose
        $DOCKER_COMPOSE -f docker-compose.offline.yml up -d
        print_success "离线环境已启动"
        print_info "PostgreSQL: localhost:5433"
        print_info "Redis: localhost:6380"
        return 0
    fi
    
    # 测试网络连接
    if ! test_network; then
        print_warning "网络连接有问题，建议运行: ./docker-run-fixed.sh fix-network"
        
        # 询问是否自动修复
        read -p "是否自动修复网络问题? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! fix_network; then
                print_error "自动修复失败，请手动配置网络或使用离线模式"
                print_info "离线模式: ./docker-run-fixed.sh dev --offline"
                exit 1
            fi
        else
            print_info "跳过网络修复，尝试使用现有配置..."
        fi
    fi
    
    if [ "$MODE" = "dev" ]; then
        print_info "启动开发环境..."
        
        # 尝试拉取镜像
        print_info "检查和更新Docker镜像..."
        if ! $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.dev.yml pull --quiet; then
            print_warning "镜像拉取失败，尝试使用现有镜像..."
        fi
        
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.dev.yml up -d
        
        if [ $? -eq 0 ]; then
            print_success "🎉 开发环境已启动"
            print_info "服务地址:"
            echo "  🦀 API服务: http://localhost:8012"
            echo "  🗄️  数据库管理: http://localhost:8080 (用户: postgres, 密码: postgres)"
            echo "  📊 Redis管理: http://localhost:8001"
            echo "  🔧 调试端口: 9229"
        else
            print_error "启动失败，请检查日志: ./docker-run-fixed.sh logs"
        fi
    else
        print_info "启动生产环境..."
        $DOCKER_COMPOSE up -d
        print_success "生产环境已启动"
        print_info "API: http://localhost:8012"
    fi
}

# 停止服务
stop_services() {
    print_info "停止所有服务..."
    
    # 停止标准服务
    $DOCKER_COMPOSE down 2>/dev/null || true
    
    # 停止开发环境服务
    $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.dev.yml down 2>/dev/null || true
    
    # 停止离线服务
    $DOCKER_COMPOSE -f docker-compose.offline.yml down 2>/dev/null || true
    
    print_success "所有服务已停止"
}

# 查看服务状态
check_status() {
    print_info "检查服务状态..."
    
    echo "=== 标准服务 ==="
    $DOCKER_COMPOSE ps 2>/dev/null || echo "无标准服务运行"
    
    echo -e "\n=== 开发环境服务 ==="
    $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.dev.yml ps 2>/dev/null || echo "无开发环境服务运行"
    
    if [ -f docker-compose.offline.yml ]; then
        echo -e "\n=== 离线服务 ==="
        $DOCKER_COMPOSE -f docker-compose.offline.yml ps 2>/dev/null || echo "无离线服务运行"
    fi
}

# 清理所有数据
clean_all() {
    print_warning "这将删除所有容器、镜像和数据卷！"
    read -p "确认继续? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "清理所有Docker数据..."
        
        # 停止并删除容器
        stop_services
        
        # 删除相关镜像
        docker images --format "table {{.Repository}}:{{.Tag}}" | grep -E "(jive|postgres|redis)" | xargs -r docker rmi -f
        
        # 删除数据卷
        docker volume ls -q | grep -E "(jive|postgres|redis)" | xargs -r docker volume rm
        
        # 删除离线配置文件
        rm -f docker-compose.offline.yml
        
        # 系统清理
        docker system prune -f --volumes
        
        print_success "清理完成"
    else
        print_info "取消清理操作"
    fi
}

# 健康检查
health_check() {
    print_info "执行健康检查..."
    
    # 检查API服务
    print_info "检查API服务..."
    if curl -f -s http://localhost:8012/health >/dev/null; then
        print_success "✅ API服务正常"
    else
        print_error "❌ API服务异常"
    fi
    
    # 检查数据库
    print_info "检查数据库服务..."
    for port in 5432 5433; do
        if pg_isready -h localhost -p $port -U postgres >/dev/null 2>&1; then
            print_success "✅ PostgreSQL (端口$port) 正常"
            break
        fi
    done
    
    # 检查Redis
    print_info "检查Redis服务..."
    for port in 6379 6380; do
        if redis-cli -h localhost -p $port ping >/dev/null 2>&1; then
            print_success "✅ Redis (端口$port) 正常"
            break
        fi
    done
}

# 主函数
main() {
    local cmd=${1:-help}
    local use_mirrors=false
    local offline_mode=false
    
    # 解析参数
    shift || true
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mirrors)
                use_mirrors=true
                shift
                ;;
            --offline)
                offline_mode=true
                shift
                ;;
            -f|--follow)
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    case "$cmd" in
        fix-network)
            fix_network
            ;;
        test-network)
            test_network
            ;;
        build)
            print_info "构建Docker镜像..."
            docker build -f Dockerfile.dev -t jive-api:dev .
            ;;
        dev)
            start_services dev $use_mirrors $offline_mode
            ;;
        prod)
            start_services prod $use_mirrors $offline_mode
            ;;
        stop|down)
            stop_services
            ;;
        restart)
            stop_services
            sleep 2
            start_services dev $use_mirrors $offline_mode
            ;;
        logs)
            $DOCKER_COMPOSE logs --tail=100
            ;;
        status)
            check_status
            ;;
        health)
            health_check
            ;;
        clean)
            clean_all
            ;;
        shell)
            docker exec -it jive-api-dev bash 2>/dev/null || docker exec -it jive-api bash 2>/dev/null || print_error "无可用容器"
            ;;
        db-shell)
            docker exec -it jive-postgres psql -U postgres -d jive_money 2>/dev/null || docker exec -it jive-postgres-offline psql -U postgres -d jive_money 2>/dev/null || print_error "无可用数据库容器"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $cmd"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"