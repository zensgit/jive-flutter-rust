#!/bin/bash

# Jive API 本地Docker环境管理脚本
# 解决Docker Registry连接问题

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

# 显示使用帮助
show_help() {
    echo "Jive API 本地Docker环境管理"
    echo ""
    echo "使用方法:"
    echo "  ./docker-local.sh <command>"
    echo ""
    echo "命令:"
    echo "  setup     - 初始设置和镜像拉取"
    echo "  start     - 启动API服务（连接主机数据库）"
    echo "  stop      - 停止服务"
    echo "  restart   - 重启服务"
    echo "  logs      - 查看日志"
    echo "  shell     - 进入容器shell"
    echo "  clean     - 清理容器和镜像"
    echo "  status    - 查看服务状态"
    echo "  build     - 构建API镜像"
    echo "  help      - 显示此帮助"
    echo ""
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker 未安装，请先安装Docker"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "无法连接到Docker守护进程，请确保Docker正在运行"
        exit 1
    fi
}

# 初始设置
setup() {
    print_info "开始初始设置..."
    
    # 检查本地PostgreSQL是否运行
    if ! pg_isready -h localhost -p 5432 -U postgres &> /dev/null; then
        print_warning "本地PostgreSQL未运行，请先启动PostgreSQL服务"
        print_info "可以使用以下命令启动："
        echo "  sudo systemctl start postgresql"
        echo "  或"
        echo "  docker run --name postgres-dev -e POSTGRES_PASSWORD=postgres -p 5432:5432 -d postgres:15-alpine"
        exit 1
    fi
    
    # 构建API镜像
    build_image
    
    print_success "初始设置完成！"
}

# 构建镜像
build_image() {
    print_info "构建Jive API镜像..."
    docker build -f Dockerfile.dev -t jive-api:local .
    print_success "镜像构建完成"
}

# 启动服务
start_service() {
    print_info "启动Jive API服务（本地模式）..."
    
    # 使用docker-compose启动
    docker-compose -f docker-compose.local.yml up -d
    
    print_success "服务启动完成！"
    print_info "API服务地址: http://localhost:8012"
    print_info "调试端口: 9229"
    print_info "查看日志: ./docker-local.sh logs"
}

# 停止服务
stop_service() {
    print_info "停止服务..."
    docker-compose -f docker-compose.local.yml down
    print_success "服务已停止"
}

# 重启服务
restart_service() {
    print_info "重启服务..."
    stop_service
    start_service
}

# 查看日志
view_logs() {
    print_info "查看服务日志（Ctrl+C 退出）..."
    docker-compose -f docker-compose.local.yml logs -f
}

# 进入容器shell
enter_shell() {
    print_info "进入API容器shell..."
    docker exec -it jive-api-dev bash
}

# 清理
clean_up() {
    print_info "清理Docker容器和镜像..."
    docker-compose -f docker-compose.local.yml down -v --rmi all
    docker system prune -f
    print_success "清理完成"
}

# 查看状态
show_status() {
    print_info "服务状态:"
    docker-compose -f docker-compose.local.yml ps
}

# 主函数
main() {
    # 检查Docker
    check_docker
    
    case "${1:-help}" in
        setup)
            setup
            ;;
        start)
            start_service
            ;;
        stop)
            stop_service
            ;;
        restart)
            restart_service
            ;;
        logs)
            view_logs
            ;;
        shell)
            enter_shell
            ;;
        clean)
            clean_up
            ;;
        status)
            show_status
            ;;
        build)
            build_image
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 运行主函数
main "$@"