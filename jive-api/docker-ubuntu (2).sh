#!/bin/bash

# Ubuntu Docker 开发环境管理脚本
# 支持不间断开发和测试

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_DIR"

# 函数：打印带颜色的消息
print_msg() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 函数：检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker未安装，请先安装Docker"
        exit 1
    fi
    
    # 检查docker compose或docker-compose
    if docker compose version &> /dev/null; then
        COMPOSE_CMD="docker compose"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_CMD="docker-compose"
    else
        print_error "Docker Compose未安装，请先安装Docker Compose"
        exit 1
    fi
}

# 函数：构建镜像
build() {
    print_msg "构建Docker镜像..."
    $COMPOSE_CMD -f docker-compose.ubuntu.yml build
    print_msg "镜像构建完成"
}

# 函数：启动服务
start() {
    print_msg "启动Docker服务..."
    $COMPOSE_CMD -f docker-compose.ubuntu.yml up -d
    print_msg "服务已启动"
    print_msg "API: http://localhost:8012"
    print_msg "PostgreSQL: localhost:5433"
    print_msg "Redis: localhost:6380"
    print_msg "Adminer: http://localhost:8080"
}

# 函数：停止服务
stop() {
    print_msg "停止Docker服务..."
    $COMPOSE_CMD -f docker-compose.ubuntu.yml down
    print_msg "服务已停止"
}

# 函数：重启服务
restart() {
    stop
    start
}

# 函数：查看日志
logs() {
    $COMPOSE_CMD -f docker-compose.ubuntu.yml logs -f jive-api
}

# 函数：进入容器shell
shell() {
    print_msg "进入API容器..."
    $COMPOSE_CMD -f docker-compose.ubuntu.yml exec jive-api /bin/bash
}

# 函数：查看服务状态
status() {
    print_msg "服务状态："
    $COMPOSE_CMD -f docker-compose.ubuntu.yml ps
}

# 函数：清理所有数据
clean() {
    print_warning "这将删除所有容器和数据卷，是否确认？(y/N)"
    read -r confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        $COMPOSE_CMD -f docker-compose.ubuntu.yml down -v
        print_msg "清理完成"
    else
        print_msg "取消清理"
    fi
}

# 函数：热重载开发模式
dev() {
    print_msg "启动开发模式（支持热重载）..."
    # 先停止现有服务
    $COMPOSE_CMD -f docker-compose.ubuntu.yml down
    
    # 启动服务并查看日志
    $COMPOSE_CMD -f docker-compose.ubuntu.yml up
}

# 函数：运行数据库迁移
migrate() {
    print_msg "运行数据库迁移..."
    $COMPOSE_CMD -f docker-compose.ubuntu.yml exec jive-api sh -c "
        cd /app && 
        if [ -d migrations ]; then
            for file in migrations/*.sql; do
                echo \"执行迁移: \$file\"
                psql \$DATABASE_URL -f \$file
            done
        else
            echo '未找到migrations目录'
        fi
    "
    print_msg "迁移完成"
}

# 函数：健康检查
health() {
    print_msg "检查服务健康状态..."
    
    # 检查API
    if curl -f http://localhost:8012/health &>/dev/null; then
        print_msg "API服务正常 ✓"
    else
        print_error "API服务异常 ✗"
    fi
    
    # 检查PostgreSQL
    if docker compose -f docker-compose.ubuntu.yml exec -T postgres pg_isready &>/dev/null; then
        print_msg "PostgreSQL正常 ✓"
    else
        print_error "PostgreSQL异常 ✗"
    fi
    
    # 检查Redis
    if docker compose -f docker-compose.ubuntu.yml exec -T redis redis-cli ping &>/dev/null; then
        print_msg "Redis正常 ✓"
    else
        print_error "Redis异常 ✗"
    fi
}

# 函数：快速重编译（不重启容器）
rebuild() {
    print_msg "重新编译Rust代码..."
    $COMPOSE_CMD -f docker-compose.ubuntu.yml exec jive-api sh -c "
        cd /app && 
        SQLX_OFFLINE=true cargo build --release --bin jive-api &&
        supervisorctl restart jive-api || 
        pkill -f jive-api && ./target/release/jive-api &
    "
    print_msg "重编译完成"
}

# 主菜单
main() {
    check_docker
    
    case "${1:-}" in
        build)
            build
            ;;
        start)
            start
            ;;
        stop)
            stop
            ;;
        restart)
            restart
            ;;
        logs)
            logs
            ;;
        shell)
            shell
            ;;
        status)
            status
            ;;
        clean)
            clean
            ;;
        dev)
            dev
            ;;
        migrate)
            migrate
            ;;
        health)
            health
            ;;
        rebuild)
            rebuild
            ;;
        *)
            echo "Ubuntu Docker开发环境管理"
            echo ""
            echo "用法: $0 {build|start|stop|restart|logs|shell|status|clean|dev|migrate|health|rebuild}"
            echo ""
            echo "命令说明:"
            echo "  build    - 构建Docker镜像"
            echo "  start    - 启动所有服务"
            echo "  stop     - 停止所有服务"
            echo "  restart  - 重启所有服务"
            echo "  logs     - 查看API日志"
            echo "  shell    - 进入API容器"
            echo "  status   - 查看服务状态"
            echo "  clean    - 清理所有容器和数据"
            echo "  dev      - 开发模式（前台运行，支持热重载）"
            echo "  migrate  - 运行数据库迁移"
            echo "  health   - 健康检查"
            echo "  rebuild  - 快速重编译（不重启容器）"
            exit 1
            ;;
    esac
}

main "$@"