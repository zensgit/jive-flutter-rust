#!/bin/bash

# Jive API Docker 管理脚本
# 支持 MacBook M4 (ARM64) 和 Ubuntu (AMD64)

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检测系统架构
detect_architecture() {
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        *)
            print_error "不支持的架构: $ARCH"
            exit 1
            ;;
    esac
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        print_error "不支持的操作系统: $OSTYPE"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
Jive API Docker 管理工具

使用方法:
    ./docker-run.sh [命令] [选项]

命令:
    build       构建 Docker 镜像
    up          启动所有服务
    down        停止所有服务
    restart     重启所有服务
    logs        查看日志
    status      查看服务状态
    clean       清理容器和卷
    dev         启动开发环境（热重载）
    prod        启动生产环境
    test        运行测试
    shell       进入容器 shell
    db-shell    进入数据库 shell
    migrate     运行数据库迁移
    backup      备份数据库
    restore     恢复数据库

选项:
    -h, --help      显示帮助信息
    -v, --verbose   详细输出
    -f, --force     强制执行

示例:
    ./docker-run.sh build      # 构建镜像
    ./docker-run.sh dev        # 启动开发环境
    ./docker-run.sh logs -f    # 实时查看日志

EOF
}

# 检查 Docker 是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        if ! docker compose version &> /dev/null; then
            print_error "Docker Compose 未安装"
            exit 1
        fi
        DOCKER_COMPOSE="docker compose"
    else
        DOCKER_COMPOSE="docker-compose"
    fi
}

# 构建镜像
build_image() {
    print_info "检测系统架构..."
    ARCH=$(detect_architecture)
    OS=$(detect_os)
    print_info "系统: $OS, 架构: $ARCH"
    
    print_info "构建 Docker 镜像..."
    docker buildx create --use --name jive-builder 2>/dev/null || true
    docker buildx build \
        --platform linux/$ARCH \
        --tag jive-api:latest \
        --tag jive-api:$(date +%Y%m%d) \
        --load \
        .
    
    print_success "镜像构建完成"
}

# 启动服务
start_services() {
    MODE=${1:-prod}
    
    if [ "$MODE" = "dev" ]; then
        print_info "启动开发环境..."
        $DOCKER_COMPOSE -f docker-compose.yml -f docker-compose.dev.yml up -d
        print_success "开发环境已启动"
        print_info "API: http://localhost:8012"
        print_info "Adminer: http://localhost:8080"
        print_info "RedisInsight: http://localhost:8001"
    else
        print_info "启动生产环境..."
        $DOCKER_COMPOSE up -d
        print_success "生产环境已启动"
        print_info "API: http://localhost:8012"
    fi
    
    print_info "等待服务就绪..."
    sleep 5
    check_health
}

# 停止服务
stop_services() {
    print_info "停止所有服务..."
    $DOCKER_COMPOSE down
    print_success "服务已停止"
}

# 重启服务
restart_services() {
    stop_services
    start_services
}

# 查看日志
view_logs() {
    if [ "$1" = "-f" ] || [ "$1" = "--follow" ]; then
        $DOCKER_COMPOSE logs -f
    else
        $DOCKER_COMPOSE logs --tail=100
    fi
}

# 检查服务状态
check_status() {
    print_info "服务状态:"
    $DOCKER_COMPOSE ps
}

# 健康检查
check_health() {
    print_info "执行健康检查..."
    
    # 检查 API
    if curl -f http://localhost:8012/health &>/dev/null; then
        print_success "API 服务正常"
    else
        print_warning "API 服务未就绪"
    fi
    
    # 检查数据库
    if docker exec jive-postgres pg_isready -U postgres &>/dev/null; then
        print_success "PostgreSQL 正常"
    else
        print_warning "PostgreSQL 未就绪"
    fi
    
    # 检查 Redis
    if docker exec jive-redis redis-cli ping &>/dev/null; then
        print_success "Redis 正常"
    else
        print_warning "Redis 未就绪"
    fi
}

# 清理
clean_all() {
    print_warning "将删除所有容器、镜像和卷，是否继续？(y/n)"
    read -r response
    if [ "$response" = "y" ]; then
        print_info "清理中..."
        $DOCKER_COMPOSE down -v --remove-orphans
        docker system prune -af
        print_success "清理完成"
    else
        print_info "取消清理"
    fi
}

# 进入容器 shell
enter_shell() {
    SERVICE=${1:-jive-api}
    print_info "进入 $SERVICE 容器..."
    docker exec -it $SERVICE /bin/bash
}

# 进入数据库 shell
enter_db_shell() {
    print_info "进入 PostgreSQL shell..."
    docker exec -it jive-postgres psql -U postgres -d jive_money
}

# 运行数据库迁移
run_migration() {
    print_info "运行数据库迁移..."
    docker exec jive-api ./jive-api migrate
    print_success "迁移完成"
}

# 备份数据库
backup_database() {
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="backup_${TIMESTAMP}.sql"
    
    print_info "备份数据库到 $BACKUP_FILE..."
    docker exec jive-postgres pg_dump -U postgres jive_money > backups/$BACKUP_FILE
    print_success "备份完成: backups/$BACKUP_FILE"
}

# 恢复数据库
restore_database() {
    if [ -z "$1" ]; then
        print_error "请指定备份文件"
        exit 1
    fi
    
    print_warning "将恢复数据库，现有数据将被覆盖，是否继续？(y/n)"
    read -r response
    if [ "$response" = "y" ]; then
        print_info "恢复数据库..."
        docker exec -i jive-postgres psql -U postgres jive_money < "$1"
        print_success "恢复完成"
    else
        print_info "取消恢复"
    fi
}

# 主函数
main() {
    check_docker
    
    case "$1" in
        build)
            build_image
            ;;
        up)
            start_services prod
            ;;
        down)
            stop_services
            ;;
        restart)
            restart_services
            ;;
        logs)
            view_logs "$2"
            ;;
        status)
            check_status
            ;;
        clean)
            clean_all
            ;;
        dev)
            start_services dev
            ;;
        prod)
            start_services prod
            ;;
        test)
            print_info "运行测试..."
            docker exec jive-api cargo test
            ;;
        shell)
            enter_shell "$2"
            ;;
        db-shell)
            enter_db_shell
            ;;
        migrate)
            run_migration
            ;;
        backup)
            backup_database
            ;;
        restore)
            restore_database "$2"
            ;;
        -h|--help|help)
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 创建必要的目录
mkdir -p logs backups static

# 运行主函数
main "$@"