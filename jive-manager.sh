#!/bin/bash

# ================================================================
# Jive Money 服务管理器
# ================================================================
# 功能:
#   - 启动/停止/重启单个或所有服务
#   - 自动释放占用端口
#   - 查看服务状态和日志
#   - 清理缓存和临时文件
# ================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 配置
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
API_PORT=8012
WEB_PORT=3021
DB_PORT=5433
REDIS_PORT=6380
ADMINER_PORT=8080
ADMINER_DEV_PORT=9080

# PID 文件位置
PID_DIR="$PROJECT_ROOT/.pids"
mkdir -p "$PID_DIR"

# 日志文件位置
LOG_DIR="$PROJECT_ROOT/.logs"
mkdir -p "$LOG_DIR"

# ================================================================
# 工具函数
# ================================================================

print_header() {
    echo -e "${PURPLE}================================================================${NC}"
    echo -e "${CYAN}🚀 Jive Money 服务管理器${NC}"
    echo -e "${PURPLE}================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# 检测操作系统
detect_os() {
    OS="$(uname -s)"
    case "${OS}" in
        Linux*)     SYSTEM="Linux";;
        Darwin*)    SYSTEM="Mac";;
        *)          SYSTEM="UNKNOWN";;
    esac
    echo "$SYSTEM"
}

# 释放端口
kill_port() {
    local port=$1
    local service_name=$2
    
    print_info "检查端口 $port ($service_name)..."
    
    if [ "$SYSTEM" = "Mac" ]; then
        # macOS
        local pids=$(lsof -ti:$port 2>/dev/null || true)
        if [ ! -z "$pids" ]; then
            print_warning "端口 $port 被占用，正在释放..."
            for pid in $pids; do
                kill -9 $pid 2>/dev/null || true
                print_success "已终止进程 $pid"
            done
        fi
    else
        # Linux
        local pids=$(lsof -ti:$port 2>/dev/null || fuser -n tcp $port 2>/dev/null || true)
        if [ ! -z "$pids" ]; then
            print_warning "端口 $port 被占用，正在释放..."
            for pid in $pids; do
                kill -9 $pid 2>/dev/null || true
                print_success "已终止进程 $pid"
            done
        fi
    fi
}

# 检查端口是否被占用
is_port_used() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        return 0  # 端口被占用
    else
        return 1  # 端口空闲
    fi
}

# 等待端口可用
wait_for_port() {
    local port=$1
    local service=$2
    local max_wait=30
    # 对 Flutter Web 首次编译放宽等待（默认 120 秒，可用 WEB_START_TIMEOUT 覆盖）
    if [[ $service == Web* ]]; then
        max_wait=${WEB_START_TIMEOUT:-120}
    fi
    local count=0
    
    while [ $count -lt $max_wait ]; do
        if is_port_used $port; then
            # 如果是 API，尝试健康检查进一步确认
            if [[ $service == API* ]]; then
                if command -v curl >/dev/null 2>&1; then
                    local health_json
                    health_json=$(curl -fs -m 2 http://127.0.0.1:$port/health 2>/dev/null || true)
                    if echo "$health_json" | grep -q '"status"\s*:\s*"healthy"'; then
                        print_success "$service 已在端口 $port 启动 (健康)"
                        return 0
                    fi
                fi
            else
                print_success "$service 已在端口 $port 启动"
                return 0
            fi
        fi
        sleep 1
        count=$((count + 1))
    done
    
    print_error "$service 启动超时 (等待 ${max_wait}s 未检测到端口 $port)"
    if [[ $service == Web* ]]; then
        echo "建议排查:"
        echo "  1. 查看日志: tail -n 60 .logs/web.log"
        echo "  2. 如首次运行，Flutter 编译可能耗时较长，可再次执行: ./jive-manager.sh restart web"
        echo "  3. 确认依赖: flutter doctor -v"
        echo "  4. 如端口被占用: lsof -i :$port 并结束旧进程"
    fi
    return 1
}

# 保存PID
save_pid() {
    local service=$1
    local pid=$2
    echo "$pid" > "$PID_DIR/$service.pid"
}

# 获取PID
get_pid() {
    local service=$1
    if [ -f "$PID_DIR/$service.pid" ]; then
        cat "$PID_DIR/$service.pid"
    else
        echo ""
    fi
}

# 检查服务是否运行
is_service_running() {
    local service=$1
    local pid=$(get_pid $service)
    
    if [ ! -z "$pid" ] && ps -p $pid > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ================================================================
# Docker 服务管理
# ================================================================

docker_start() {
    local service=$1
    
    cd "$PROJECT_ROOT/jive-api"
    
    if [ "$service" = "all" ] || [ "$service" = "postgres" ] || [ "$service" = "db" ]; then
        print_info "启动 PostgreSQL..."
        docker-compose -f docker-compose.dev.yml up -d postgres
        print_success "PostgreSQL 已启动 (端口: $DB_PORT)"
    fi
    
    if [ "$service" = "all" ] || [ "$service" = "redis" ]; then
        print_info "启动 Redis..."
        docker-compose -f docker-compose.dev.yml up -d redis
        print_success "Redis 已启动 (端口: $REDIS_PORT)"
    fi
    
    if [ "$service" = "all" ] || [ "$service" = "adminer" ]; then
        # 逻辑修正：仅当目标实际使用的 9080 被占用才跳过。
        # 之前因为 8080 被其它程序占用也会整体跳过，导致 9080 空闲时不启动 Adminer。
        if is_port_used $ADMINER_DEV_PORT; then
            print_warning "Adminer 目标端口 9080 已被占用，跳过启动"
        else
            print_info "启动 Adminer (映射 9080 -> 8080)..."
            if docker-compose -f docker-compose.dev.yml up -d adminer; then
                # 再次确认端口是否监听
                if is_port_used $ADMINER_DEV_PORT; then
                    print_success "Adminer 已启动 (http://localhost:$ADMINER_DEV_PORT)"
                else
                    print_warning "Adminer 容器已创建但端口未监听，请检查 'docker logs jive-adminer-dev'"
                fi
            else
                print_warning "Adminer 启动失败，稍后可手动执行: cd jive-api && docker-compose -f docker-compose.dev.yml up -d adminer"
            fi
        fi
    fi
    
    cd "$PROJECT_ROOT"
}

docker_stop() {
    local service=$1
    
    cd "$PROJECT_ROOT/jive-api"
    
    if [ "$service" = "all" ]; then
        print_info "停止所有 Docker 服务..."
        docker-compose -f docker-compose.dev.yml down
        print_success "所有 Docker 服务已停止"
    else
        print_info "停止 $service..."
        docker-compose -f docker-compose.dev.yml stop $service
        print_success "$service 已停止"
    fi
    
    cd "$PROJECT_ROOT"
}

# ================================================================
# API 服务管理
# ================================================================

api_start_safe() {
    if is_service_running "api"; then
        print_warning "API (安全模式) 已在运行"
        return
    fi
    kill_port $API_PORT "API"
    print_info "启动 Rust API (安全模式)..."
    cd "$PROJECT_ROOT/jive-api"
    # 智能 SQLX 离线：存在缓存文件则开启，否则在线模式
    if [ -d .sqlx ] && ls .sqlx/*.json >/dev/null 2>&1; then
        print_info "检测到 .sqlx 缓存 -> 启用 SQLX_OFFLINE"
        SQLX_PREFIX="SQLX_OFFLINE=1"
    else
        SQLX_PREFIX=""
    fi
    eval $SQLX_PREFIX cargo build --release --bin jive-api
    # Use existing DATABASE_URL if set; otherwise prefer Docker dev DB
    DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@127.0.0.1:$DB_PORT/jive_money}" \
    REDIS_URL="redis://localhost:$REDIS_PORT" \
    API_PORT=$API_PORT \
    eval $SQLX_PREFIX nohup cargo run --release --bin jive-api > "$LOG_DIR/api.log" 2>&1 &
    local pid=$!
    save_pid "api" $pid
    wait_for_port $API_PORT "API(安全)"
    cd "$PROJECT_ROOT"
}

api_start_dev() {
    if is_service_running "api"; then
        print_warning "API (开发宽松模式) 已在运行"
        return
    fi
    kill_port $API_PORT "API"
    print_info "启动 Rust API (开发宽松 CORS_DEV=1)..."
    cd "$PROJECT_ROOT/jive-api"
    if [ -d .sqlx ] && ls .sqlx/*.json >/dev/null 2>&1; then
        print_info "检测到 .sqlx 缓存 -> 启用 SQLX_OFFLINE"
        SQLX_PREFIX="SQLX_OFFLINE=1"
    else
        SQLX_PREFIX=""
    fi
    eval $SQLX_PREFIX cargo build --bin jive-api
    CORS_DEV=1 \
    DATABASE_URL="${DATABASE_URL:-postgresql://postgres:postgres@127.0.0.1:$DB_PORT/jive_money}" \
    REDIS_URL="redis://localhost:$REDIS_PORT" \
    API_PORT=$API_PORT \
    RUST_LOG=info \
    eval $SQLX_PREFIX nohup cargo run --bin jive-api > "$LOG_DIR/api.log" 2>&1 &
    local pid=$!
    save_pid "api" $pid
    wait_for_port $API_PORT "API(开发)"
    cd "$PROJECT_ROOT"
}

# 向后兼容旧函数名（默认安全模式）
api_start() {
    api_start_safe
}

api_stop() {
    local pid=$(get_pid "api")
    
    if [ ! -z "$pid" ]; then
        print_info "停止 API 服务 (PID: $pid)..."
        kill -15 $pid 2>/dev/null || true
        sleep 2
        kill -9 $pid 2>/dev/null || true
        rm -f "$PID_DIR/api.pid" "$PID_DIR/api.mode"
        print_success "API 服务已停止"
    else
        print_warning "API 服务未运行"
    fi
    
    # 确保端口释放
    kill_port $API_PORT "API"
}

# ================================================================
# Flutter Web 服务管理
# ================================================================

web_start() {
    if is_service_running "web"; then
        print_warning "Web 服务已在运行"
        return
    fi

    # Flutter SDK 可写性与缓存完整性检查
    ensure_flutter_available || return 1
    ensure_flutter_writable || return 1
    detect_stale_dart_snapshot || true
    
    # 释放端口
    kill_port $WEB_PORT "Web"
    
    print_info "启动 Flutter Web..."
    cd "$PROJECT_ROOT/jive-flutter"
    
    # 获取依赖
    # 仅在 pubspec 变更或缺失 .dart_tool 时获取依赖（加速重启）
    if [ ! -d .dart_tool ] || [ ! -f .dart_tool/.packages_hash ] || ! cmp -s pubspec.yaml .dart_tool/.packages_src 2>/dev/null; then
        print_info "获取依赖 (pub get)..."
        flutter pub get || { print_error "flutter pub get 失败"; return 1; }
        cp pubspec.yaml .dart_tool/.packages_src 2>/dev/null || true
        shasum pubspec.yaml 2>/dev/null | awk '{print $1}' > .dart_tool/.packages_hash 2>/dev/null || true
    else
        print_info "依赖缓存命中，跳过 pub get"
    fi
    
    # 启动
    # 检测 flutter 是否支持 --web-renderer 参数
    local RENDERER_FLAG=""
    # 使用 -- 终止 grep 选项解析，避免把模式当作参数
    if flutter run -h 2>&1 | grep -q -- "--web-renderer"; then
        # 可通过环境变量 WEB_RENDERER 指定 (html | canvaskit | auto)
        local renderer=${WEB_RENDERER:-html}
        RENDERER_FLAG="--web-renderer $renderer"
        print_info "检测到 --web-renderer 支持，使用: $renderer"
    else
        print_warning "Flutter 版本不支持 --web-renderer，使用默认渲染器"
    fi

    # 运行（不引用空参数以避免旧版本报错）
    local EXTRA_FLAGS="--no-version-check --disable-service-auth-codes"
    if [ -n "$RENDERER_FLAG" ]; then
        nohup flutter run -d web-server --web-port $WEB_PORT $RENDERER_FLAG $EXTRA_FLAGS > "$LOG_DIR/web.log" 2>&1 &
    else
        nohup flutter run -d web-server --web-port $WEB_PORT $EXTRA_FLAGS > "$LOG_DIR/web.log" 2>&1 &
    fi
    
    local pid=$!
    save_pid "web" $pid
    
    # 等待服务启动
    wait_for_port $WEB_PORT "Web"
    
    cd "$PROJECT_ROOT"
}

# 检查 flutter 命令是否可用
ensure_flutter_available() {
    if ! command -v flutter >/dev/null 2>&1; then
        print_error "未找到 flutter 命令，请先安装或配置 PATH"
        return 1
    fi
}

# 检查 flutter SDK 写权限（避免 engine.stamp 权限导致使用旧缓存）
ensure_flutter_writable() {
    local flutter_bin
    # 若用户指定本地 SDK 路径，优先使用
    if [ -n "$USE_LOCAL_FLUTTER" ] && [ -x "$USE_LOCAL_FLUTTER/bin/flutter" ]; then
        flutter_bin="$USE_LOCAL_FLUTTER/bin/flutter"
    else
        flutter_bin=$(command -v flutter)
    fi

    # 解析符号链接获取真实目录 (macOS Homebrew flutter 通常是一个 symlink)
    local resolved
    if command -v realpath >/dev/null 2>&1; then
        resolved=$(realpath "$flutter_bin" 2>/dev/null || echo "$flutter_bin")
    else
        resolved=$(readlink "$flutter_bin" 2>/dev/null || echo "$flutter_bin")
        case "$resolved" in
          /*) ;; # absolute
          *) resolved="$(dirname "$flutter_bin")/$resolved";;
        esac
    fi

    # sdk_root = 真实 flutter 可执行文件向上两级 (…/flutter/bin/flutter -> …/flutter)
    local sdk_root
    sdk_root=$(cd "$(dirname "$resolved")/.." && pwd)

    # 某些 Homebrew 安装结构: /opt/homebrew/bin/flutter -> ../share/flutter/bin/flutter
    # 确认 share/flutter 存在时再折返到它
    if [ -d "$sdk_root/share/flutter" ] && [ -x "$sdk_root/share/flutter/bin/flutter" ]; then
        sdk_root="$sdk_root/share/flutter"
    fi

    # 检测写权限 (仅在 cache 目录; 若不存在创建)
    mkdir -p "$sdk_root/bin/cache" 2>/dev/null || true
    if ! touch "$sdk_root/bin/cache/.perm_test" 2>/dev/null; then
        print_warning "Flutter SDK 无写权限: $sdk_root"
        echo "  修复示例: sudo chown -R $(whoami) $sdk_root && chmod -R u+w $sdk_root" >&2
        echo "  或: git clone https://github.com/flutter/flutter.git \$HOME/flutter-sdk && export USE_LOCAL_FLUTTER=\$HOME/flutter-sdk" >&2
        return 1
    fi
    return 0
}

# 检测是否仍引用旧的编译快照（例如报早已删除的常量）
detect_stale_dart_snapshot() {
    if [ -f "$LOG_DIR/web.log" ] && grep -q "static const String _baseUrl" "$LOG_DIR/web.log"; then
        print_warning "检测到旧构建错误 (const _baseUrl)，将触发清理"
        (cd "$PROJECT_ROOT/jive-flutter" && flutter clean >/dev/null 2>&1 || true)
    fi
}

web_stop() {
    local pid=$(get_pid "web")
    
    if [ ! -z "$pid" ]; then
        print_info "停止 Web 服务 (PID: $pid)..."
        kill -15 $pid 2>/dev/null || true
        sleep 2
        kill -9 $pid 2>/dev/null || true
        rm -f "$PID_DIR/web.pid"
        print_success "Web 服务已停止"
    else
        print_warning "Web 服务未运行"
    fi
    
    # 确保端口释放
    kill_port $WEB_PORT "Web"
}

# ================================================================
# 主要命令
# ================================================================

# 启动服务
start_service() {
    local service=${1:-all}
    case "$service" in
        migrate)
            print_header
            print_info "执行数据库迁移 (Docker DB + 本地 API 场景)..."
            # 确保 Docker DB 运行
            docker_start "postgres"
            sleep 2
            # 使用 Docker 开发库作为默认
            local url="${DATABASE_URL:-postgresql://postgres:postgres@127.0.0.1:$DB_PORT/jive_money}"
            print_info "迁移目标: $url"
            if [ -x "$PROJECT_ROOT/jive-api/scripts/migrate_local.sh" ]; then
                "$PROJECT_ROOT/jive-api/scripts/migrate_local.sh" --db-url "$url" || {
                    print_error "迁移失败"; exit 1; }
            else
                print_error "未找到迁移脚本: jive-api/scripts/migrate_local.sh"; exit 1;
            fi
            print_success "迁移完成"
            ;;
        all|all-safe)
            print_header
            print_info "启动所有服务 (安全模式 API)..."
            docker_start "all"
            sleep 3  # 等待数据库就绪
            api_start_safe
            web_start
            print_success "所有服务已启动 (安全模式)"
            show_status
            ;;
        all-dev)
            print_header
            print_info "启动所有服务 (开发宽松模式 API)..."
            docker_start "all"
            sleep 3
            api_start_dev
            web_start
            print_success "所有服务已启动 (开发宽松模式)"
            show_status
            ;;
        api)
            api_start_safe
            ;;
        api-safe)
            api_start_safe
            ;;
        api-dev)
            api_start_dev
            ;;
        web|flutter)
            web_start
            ;;
        db|postgres|database)
            docker_start "postgres"
            ;;
        redis)
            docker_start "redis"
            ;;
        adminer)
            docker_start "adminer"
            ;;
        docker)
            docker_start "all"
            ;;
        *)
            print_error "未知服务: $service"
            show_usage
            exit 1
            ;;
    esac
}

# 停止服务
stop_service() {
    local service=${1:-all}
    
    case "$service" in
        all|all-safe|all-dev)
            print_header
            print_info "停止所有服务..."
            web_stop
            api_stop
            docker_stop "all"
            print_success "所有服务已停止"
            ;;
        api)
            api_stop
            ;;
        web|flutter)
            web_stop
            ;;
        db|postgres|database)
            docker_stop "postgres"
            ;;
        redis)
            docker_stop "redis"
            ;;
        adminer)
            docker_stop "adminer"
            ;;
        docker)
            docker_stop "all"
            ;;
        *)
            print_error "未知服务: $service"
            show_usage
            exit 1
            ;;
    esac
}

# 重启服务
restart_service() {
    local service=${1:-all}
    local extra=$2
    
    print_info "重启服务: $service"
    # 对 adminer 支持 --force 重建
    if [ "$service" = "adminer" ] && [ "$extra" = "--force" ]; then
        print_info "强制移除旧 Adminer 容器..."
        docker rm -f jive-adminer-dev 2>/dev/null || true
    fi
    stop_service "$service"
    sleep 2
    start_service "$service"
}

# 显示状态
show_status() {
    echo ""
    echo -e "${CYAN}📊 服务状态：${NC}"
    echo -e "${BLUE}────────────────────────────────────────${NC}"
    
    # API 状态
    if is_service_running "api"; then
        local mode="safe"
        if [ -f "$PID_DIR/api.mode" ]; then
            mode=$(cat "$PID_DIR/api.mode" 2>/dev/null || echo safe)
        fi
        if [ "$mode" = "dev" ]; then
            echo -e "API:      ${GREEN}● 运行中${NC} (http://localhost:$API_PORT, 模式: 开发宽松)"
        else
            echo -e "API:      ${GREEN}● 运行中${NC} (http://localhost:$API_PORT, 模式: 安全)"
        fi
    else
        echo -e "API:      ${RED}○ 已停止${NC}"
    fi
    
    # Web 状态
    if is_service_running "web"; then
        echo -e "Web:      ${GREEN}● 运行中${NC} (http://localhost:$WEB_PORT)"
    else
        echo -e "Web:      ${RED}○ 已停止${NC}"
    fi
    
    # Docker 服务状态
    if docker ps | grep -q "postgres" 2>/dev/null; then
        echo -e "数据库:    ${GREEN}● 运行中${NC} (localhost:$DB_PORT)"
    else
        echo -e "数据库:    ${RED}○ 已停止${NC}"
    fi
    
    if docker ps | grep -q "redis" 2>/dev/null; then
        echo -e "Redis:    ${GREEN}● 运行中${NC} (localhost:$REDIS_PORT)"
    else
        echo -e "Redis:    ${RED}○ 已停止${NC}"
    fi
    
    if docker ps | grep -q "adminer" 2>/dev/null; then
        if lsof -Pi :$ADMINER_DEV_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
            # 轻量健康探测
            if command -v curl >/dev/null 2>&1; then
                if curl -fs -m 2 http://127.0.0.1:$ADMINER_DEV_PORT >/dev/null 2>&1; then
                    echo -e "Adminer:  ${GREEN}● 运行中${NC} (http://localhost:$ADMINER_DEV_PORT)"
                else
                    echo -e "Adminer:  ${YELLOW}● 端口监听但无响应${NC} (http://localhost:$ADMINER_DEV_PORT)"
                fi
            else
                echo -e "Adminer:  ${GREEN}● 运行中${NC} (http://localhost:$ADMINER_DEV_PORT)"
            fi
        else
            echo -e "Adminer:  ${YELLOW}● 容器存在但端口未监听${NC} (检查: docker logs jive-adminer-dev)"
        fi
    else
        echo -e "Adminer:  ${RED}○ 已停止${NC}"
    fi
    
    echo -e "${BLUE}────────────────────────────────────────${NC}"
}

# 查看日志
show_logs() {
    local service=${1:-all}
    
    case "$service" in
        api)
            print_info "API 日志:"
            tail -f "$LOG_DIR/api.log"
            ;;
        web|flutter)
            print_info "Web 日志:"
            tail -f "$LOG_DIR/web.log"
            ;;
        docker)
            cd "$PROJECT_ROOT/jive-api"
            docker-compose -f docker-compose.dev.yml logs -f
            ;;
        all)
            print_info "所有日志 (Ctrl+C 退出):"
            tail -f "$LOG_DIR"/*.log
            ;;
        *)
            print_error "未知服务: $service"
            ;;
    esac
}

# 清理
clean_all() {
    print_header
    print_warning "清理所有服务和数据..."
    
    # 停止所有服务
    stop_service "all"
    
    # 清理 PID 文件
    rm -rf "$PID_DIR"
    
    # 清理日志
    rm -rf "$LOG_DIR"
    
    # 清理 Docker 卷
    cd "$PROJECT_ROOT/jive-api"
    docker-compose -f docker-compose.dev.yml down -v
    cd "$PROJECT_ROOT"
    
    # 清理 Flutter 构建
    if [ -d "$PROJECT_ROOT/jive-flutter" ]; then
        cd "$PROJECT_ROOT/jive-flutter"
        flutter clean
        cd "$PROJECT_ROOT"
    fi
    
    # 清理 Rust 构建
    if [ -d "$PROJECT_ROOT/jive-api" ]; then
        cd "$PROJECT_ROOT/jive-api"
        cargo clean
        cd "$PROJECT_ROOT"
    fi
    
    print_success "清理完成"
}

# 释放所有端口
release_ports() {
    print_header
    print_info "释放所有服务端口..."
    
    kill_port $API_PORT "API"
    kill_port $WEB_PORT "Web"
    kill_port $DB_PORT "PostgreSQL"
    kill_port $REDIS_PORT "Redis"
    kill_port $ADMINER_PORT "Adminer"
    
    print_success "所有端口已释放"
}

# 显示使用帮助
show_usage() {
    print_header
    echo "用法: $0 <命令> [服务]"
    echo ""
    echo -e "${CYAN}命令:${NC}"
    echo "  start [服务]    - 启动服务"
    echo "  stop [服务]     - 停止服务"
    echo "  restart [服务]  - 重启服务"
    echo "  start migrate   - 执行数据库迁移 (连接 Docker DB: localhost:$DB_PORT)"
    echo "  restart adminer --force  - 强制重建 Adminer 容器"
    echo "  reload [服务]   - 轻量重载(API/Web 保留依赖)"
    echo "  mode <dev|safe> - 切换或启动 API 到指定模式"
    echo "  health          - 快速健康检查 (API/DB/Redis/Adminer)"
    echo "  status          - 查看服务状态"
    echo "  logs [服务]     - 查看服务日志"
    echo "  clean           - 清理所有服务和数据"
    echo "  ports           - 释放所有端口"
    echo "  help            - 显示此帮助"
    echo ""
    echo -e "${CYAN}服务:${NC}"
    echo "  all             - 所有服务 (安全模式 API)"
    echo "  all-safe        - 同 all (显式安全)"
    echo "  all-dev         - 所有服务 (API 宽松 CORS_DEV=1)"
    echo "  api             - Rust API 服务(安全模式)"
    echo "  api-safe        - 同 api (显式安全模式)"
    echo "  api-dev         - Rust API 服务(宽松 CORS_DEV 模式)"
    echo "  web/flutter     - Flutter Web 服务"
    echo "  db/postgres     - PostgreSQL 数据库"
    echo "  redis           - Redis 缓存"
    echo "  docker          - 所有 Docker 服务"
    echo "  migrate         - 仅执行数据库迁移"
    echo ""
    echo -e "${CYAN}示例:${NC}"
    echo "  $0 start              # 启动所有服务"
    echo "  $0 restart api        # 重启 API 服务"
    echo "  $0 stop web           # 停止 Web 服务"
    echo "  $0 logs api           # 查看 API 日志"
    echo "  $0 status             # 查看所有服务状态"
    echo "  $0 ports              # 释放所有端口"
    echo ""
    echo -e "${CYAN}快捷操作:${NC}"
    echo "  $0                    # 显示状态"
    echo "  $0 up                 # 启动所有服务 (安全模式)"
    echo "  $0 start all-dev      # 启动所有服务 (宽松开发模式)"
    echo "  $0 reload api         # 重载 API (保持当前模式)"
    echo "  $0 reload web         # 重载前端 Web"
    echo "  $0 start migrate      # 对 Docker DB 执行迁移"
    echo "  $0 restart all-dev    # 重启所有服务 (宽松模式)"
    echo "  $0 restart api-dev    # 重启 API (宽松模式)"
    echo "  $0 mode dev           # 将 API 切换到开发宽松模式"
    echo "  $0 mode safe          # 将 API 切换到安全模式"
    echo "  $0 down               # 停止所有服务"
}

# 健康检查
health_check() {
    print_header
    echo -e "${CYAN}🔍 健康检查${NC}"
    echo ""
    # API
    if curl -fs -m 3 http://127.0.0.1:$API_PORT/health >/dev/null 2>&1; then
        echo -e "API:       ${GREEN}健康${NC} (http://localhost:$API_PORT)"
    else
        echo -e "API:       ${RED}不可达${NC} (http://localhost:$API_PORT/health)"
    fi
    # 数据库 (TCP 层)
    if lsof -Pi :$DB_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "Postgres:  ${GREEN}端口监听${NC} ($DB_PORT)"
    else
        echo -e "Postgres:  ${RED}未监听${NC} ($DB_PORT)"
    fi
    # Redis
    if lsof -Pi :$REDIS_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "Redis:     ${GREEN}端口监听${NC} ($REDIS_PORT)"
    else
        echo -e "Redis:     ${RED}未监听${NC} ($REDIS_PORT)"
    fi
    # Adminer
    if lsof -Pi :$ADMINER_DEV_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        if curl -fs -m 3 http://127.0.0.1:$ADMINER_DEV_PORT >/dev/null 2>&1; then
            echo -e "Adminer:   ${GREEN}健康${NC} (http://localhost:$ADMINER_DEV_PORT)"
        else
            echo -e "Adminer:   ${YELLOW}端口监听但无响应${NC} (http://localhost:$ADMINER_DEV_PORT)"
        fi
    else
        echo -e "Adminer:   ${RED}未监听${NC} ($ADMINER_DEV_PORT)"
    fi
}

# ================================================================
# 主程序
# ================================================================

# 检测系统
SYSTEM=$(detect_os)

# 检查依赖
check_dependencies() {
    local missing=()
    
    command -v docker >/dev/null 2>&1 || missing+=("docker")
    command -v flutter >/dev/null 2>&1 || missing+=("flutter")
    command -v cargo >/dev/null 2>&1 || missing+=("cargo")
    command -v lsof >/dev/null 2>&1 || missing+=("lsof")
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "缺少以下依赖："
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

# 主命令处理
main() {
    local command=${1:-status}
    local service=${2:-}
    
    # 检查依赖
    check_dependencies
    
case "$command" in
        start|up)
            start_service "$service"
            ;;
        stop|down)
            stop_service "$service"
            ;;
        restart)
            # 支持: restart adminer --force
            if [ "$service" = "adminer" ] && [ "${3:-}" = "--force" ]; then
                restart_service "adminer" "--force"
            else
                restart_service "$service"
            fi
            ;;
        migrate)
            start_service migrate
            ;;
        reload)
            case "${service:-api}" in
                api|api-safe|api-dev)
                    if is_service_running "api"; then
                        local current_mode="safe"
                        [ -f "$PID_DIR/api.mode" ] && current_mode=$(cat "$PID_DIR/api.mode" 2>/dev/null || echo safe)
                        print_info "重载 API (当前模式: $current_mode)..."
                        api_stop
                        if [ "$current_mode" = "dev" ]; then
                            api_start_dev
                        else
                            api_start_safe
                        fi
                        print_success "API 已重载 ($current_mode)"
                    else
                        print_warning "API 未运行，直接启动 (安全模式)"
                        api_start_safe
                    fi
                    ;;
                web|flutter)
                    if is_service_running "web"; then
                        print_info "重载 Web..."
                        web_stop
                        web_start
                        print_success "Web 已重载"
                    else
                        print_warning "Web 未运行，直接启动"
                        web_start
                    fi
                    ;;
                all|all-safe|all-dev)
                    print_info "轻量重载全栈：仅 API + Web (保留数据库/Redis)"
                    local current_mode="safe"
                    [ -f "$PID_DIR/api.mode" ] && current_mode=$(cat "$PID_DIR/api.mode" 2>/dev/null || echo safe)
                    web_stop || true
                    api_stop || true
                    if [ "$current_mode" = "dev" ]; then
                        api_start_dev
                    else
                        api_start_safe
                    fi
                    web_start
                    print_success "全栈已重载 (API 模式: $current_mode)"
                    ;;
                *)
                    print_error "未知服务用于 reload: $service"
                    show_usage
                    exit 1
                    ;;
            esac
            ;;
        mode)
            local target=${service:-}
            if [ -z "$target" ]; then
                print_error "缺少模式参数 (dev | safe)"; show_usage; exit 1; fi
            case "$target" in
                dev)
                    print_info "切换 API 到开发宽松模式 (CORS_DEV=1)..."
                    if is_service_running "api"; then api_stop; fi
                    api_start_dev
                    print_success "API 已运行于开发宽松模式"
                    ;;
                safe)
                    print_info "切换 API 到安全模式..."
                    if is_service_running "api"; then api_stop; fi
                    api_start_safe
                    print_success "API 已运行于安全模式"
                    ;;
                *)
                    print_error "未知模式: $target (需 dev 或 safe)"; show_usage; exit 1;
                    ;;
            esac
            ;;
        status|ps)
            print_header
            show_status
            ;;
        logs|log)
            show_logs "$service"
            ;;
        clean)
            clean_all
            ;;
        ports|release)
            release_ports
            ;;
        help|-h|--help)
            show_usage
            ;;
        health)
            health_check
            ;;
        *)
            print_error "未知命令: $command"
            show_usage
            exit 1
            ;;
    esac
}

# 执行主程序
main "$@"
