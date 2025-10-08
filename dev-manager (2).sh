#!/bin/bash

# Jive Money 开发环境管理器
# 专业级本地开发环境管理脚本

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 项目路径
PROJECT_ROOT="/home/zou/jive-project"
API_PATH="$PROJECT_ROOT/jive-api"
FLUTTER_PATH="$PROJECT_ROOT/jive-flutter"

# 打印函数
print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}      ${PURPLE}Jive Money 开发环境管理器${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
    echo
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✅ SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠️  WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[❌ ERROR]${NC} $1"
}

print_service() {
    echo -e "${PURPLE}[🔧 SERVICE]${NC} $1"
}

# 显示帮助
show_help() {
    print_header
    echo -e "${CYAN}使用方法:${NC}"
    echo "  ./dev-manager.sh <command>"
    echo
    echo -e "${CYAN}环境管理:${NC}"
    echo "  status      - 📊 检查所有服务状态"
    echo "  start       - 🚀 启动所有服务"
    echo "  stop        - 🛑 停止所有服务"
    echo "  restart     - 🔄 重启所有服务"
    echo "  logs        - 📋 查看服务日志"
    echo
    echo -e "${CYAN}单个服务:${NC}"
    echo "  api-start   - 🦀 启动Rust API服务"
    echo "  api-stop    - 🛑 停止Rust API服务"
    echo "  api-logs    - 📋 查看API日志"
    echo "  flutter-start - 🐦 启动Flutter Web服务"
    echo "  flutter-stop  - 🛑 停止Flutter Web服务"
    echo "  flutter-hot   - 🔥 Flutter热重载"
    echo
    echo -e "${CYAN}数据库管理:${NC}"
    echo "  db-status   - 📊 检查数据库状态"
    echo "  db-connect  - 🔗 连接数据库"
    echo "  db-backup   - 💾 备份数据库"
    echo "  db-restore  - 📥 恢复数据库"
    echo
    echo -e "${CYAN}开发工具:${NC}"
    echo "  test        - 🧪 运行测试"
    echo "  lint        - 🔍 代码检查"
    echo "  clean       - 🧹 清理临时文件"
    echo "  setup       - ⚙️  初始化开发环境"
    echo
    echo -e "${CYAN}快捷操作:${NC}"
    echo "  open        - 🌐 在浏览器中打开应用"
    echo "  code        - 💻 在VS Code中打开项目"
    echo "  monitor     - 👁️  实时监控服务状态"
    echo
}

# 检查服务状态
check_status() {
    print_header
    print_info "检查服务状态..."
    echo
    
    # 检查API服务
    print_service "Rust API 服务 (端口 8012):"
    if curl -s http://localhost:8012/health >/dev/null 2>&1; then
        local api_info=$(curl -s http://localhost:8012/health | jq -r '.service + " v" + .version' 2>/dev/null || echo "API Service")
        print_success "✅ $api_info - http://localhost:8012"
    else
        print_error "❌ API服务未运行"
    fi
    
    # 检查Flutter服务
    print_service "Flutter Web 应用 (端口 3022):"
    if curl -s http://localhost:3022 >/dev/null 2>&1; then
        print_success "✅ Flutter Web - http://localhost:3022"
    else
        print_error "❌ Flutter Web未运行"
    fi
    
    # 检查PostgreSQL
    print_service "PostgreSQL 数据库 (端口 5432):"
    if pg_isready -h localhost -p 5432 -U postgres >/dev/null 2>&1; then
        print_success "✅ PostgreSQL - localhost:5432"
    else
        print_error "❌ PostgreSQL未运行"
    fi
    
    echo
    print_info "服务状态检查完成"
}

# 启动所有服务
start_all() {
    print_header
    print_info "启动所有开发服务..."
    
    # 检查PostgreSQL
    if ! pg_isready -h localhost -p 5432 -U postgres >/dev/null 2>&1; then
        print_warning "PostgreSQL未运行，请先启动数据库服务"
        echo "可以使用: sudo systemctl start postgresql"
        return 1
    fi
    
    # 启动API服务
    print_info "启动Rust API服务..."
    cd "$API_PATH"
    nohup cargo run --bin jive-api > logs/api.log 2>&1 &
    echo $! > api.pid
    print_success "API服务已启动 (PID: $(cat api.pid))"
    
    # 等待API启动
    sleep 3
    
    # 启动Flutter服务
    print_info "启动Flutter Web服务..."
    cd "$FLUTTER_PATH"
    nohup flutter run -d web-server --web-port 3022 > logs/flutter.log 2>&1 &
    echo $! > flutter.pid
    print_success "Flutter服务已启动 (PID: $(cat flutter.pid))"
    
    echo
    print_success "🎉 所有服务启动完成！"
    echo
    print_info "服务地址:"
    echo "  • API服务: http://localhost:8012"
    echo "  • Web应用: http://localhost:3022"
    echo "  • 数据库: localhost:5432"
}

# 停止所有服务
stop_all() {
    print_header
    print_info "停止所有开发服务..."
    
    # 停止API服务
    if [ -f "$API_PATH/api.pid" ]; then
        local pid=$(cat "$API_PATH/api.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            print_success "API服务已停止 (PID: $pid)"
        fi
        rm -f "$API_PATH/api.pid"
    else
        print_warning "未找到API服务PID文件"
    fi
    
    # 停止Flutter服务
    if [ -f "$FLUTTER_PATH/flutter.pid" ]; then
        local pid=$(cat "$FLUTTER_PATH/flutter.pid")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            print_success "Flutter服务已停止 (PID: $pid)"
        fi
        rm -f "$FLUTTER_PATH/flutter.pid"
    else
        print_warning "未找到Flutter服务PID文件"
    fi
    
    # 清理可能的Flutter进程
    pkill -f "flutter run" 2>/dev/null || true
    pkill -f "jive-api" 2>/dev/null || true
    
    print_success "🛑 所有服务已停止"
}

# 在浏览器中打开应用
open_browser() {
    print_info "在浏览器中打开应用..."
    
    # 检查服务是否运行
    if curl -s http://localhost:3022 >/dev/null 2>&1; then
        if command -v xdg-open >/dev/null; then
            xdg-open http://localhost:3022
            print_success "应用已在默认浏览器中打开"
        else
            print_info "请手动打开: http://localhost:3022"
        fi
    else
        print_error "Flutter应用未运行，请先启动服务"
    fi
}

# 实时监控
monitor_services() {
    print_header
    print_info "开始实时监控服务状态 (Ctrl+C 退出)..."
    echo
    
    while true; do
        clear
        print_header
        check_status
        echo
        print_info "下次检查: 10秒后... (Ctrl+C 退出)"
        sleep 10
    done
}

# 主函数
main() {
    case "${1:-help}" in
        status)
            check_status
            ;;
        start)
            start_all
            ;;
        stop)
            stop_all
            ;;
        restart)
            stop_all
            sleep 2
            start_all
            ;;
        open)
            open_browser
            ;;
        monitor)
            monitor_services
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "未知命令: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# 创建日志目录
mkdir -p "$API_PATH/logs" "$FLUTTER_PATH/logs"

# 运行主函数
main "$@"