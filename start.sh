#!/bin/bash

# Jive Flutter-Rust 智能启动脚本
# 自动检查依赖、端口占用并启动所有服务

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认端口配置
RUST_API_PORT=${RUST_API_PORT:-8012}
FLUTTER_DEV_PORT=3021
POSTGRES_PORT=${POSTGRES_PORT:-5432}
REDIS_PORT=${REDIS_PORT:-6379}

# 项目目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUST_DIR="$PROJECT_ROOT/jive-api"
FLUTTER_DIR="$PROJECT_ROOT/jive-flutter"

# 日志文件
LOG_DIR="$PROJECT_ROOT/logs"
mkdir -p "$LOG_DIR"

# 打印带颜色的消息
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# 检查命令是否存在
check_command() {
    local cmd=$1
    local install_msg=$2
    
    if ! command -v $cmd &> /dev/null; then
        print_msg "$RED" "✗ $cmd 未安装"
        if [ ! -z "$install_msg" ]; then
            print_msg "$YELLOW" "  安装建议: $install_msg"
        fi
        return 1
    else
        local version=$(eval "$cmd --version 2>&1 | head -n1" || echo "版本未知")
        print_msg "$GREEN" "✓ $cmd 已安装 ($version)"
        return 0
    fi
}

# 检查端口是否被占用
check_port() {
    local port=$1
    local service=$2
    
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        local pid=$(lsof -Pi :$port -sTCP:LISTEN -t)
        local process=$(ps -p $pid -o comm= 2>/dev/null || echo "未知进程")
        print_msg "$RED" "✗ 端口 $port ($service) 已被占用 - PID: $pid ($process)"
        
        read -p "是否要终止占用端口的进程? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            kill -9 $pid
            print_msg "$GREEN" "  已终止进程 $pid"
            return 0
        else
            return 1
        fi
    else
        print_msg "$GREEN" "✓ 端口 $port ($service) 可用"
        return 0
    fi
}

# 自动安装 Rust
install_rust() {
    print_msg "$YELLOW" "  正在安装 Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    print_msg "$GREEN" "✓ Rust 安装完成"
}

# 检查 Rust 依赖
check_rust_deps() {
    print_msg "$CYAN" "\n=== 检查 Rust 依赖 ==="
    
    local all_good=true
    
    # 检查 Rust 是否安装，如果没有则自动安装
    if ! command -v rustc &> /dev/null; then
        print_msg "$YELLOW" "⚠ Rust 未安装"
        read -p "是否要自动安装 Rust? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_rust
            # 重新加载环境变量
            source "$HOME/.cargo/env"
        else
            all_good=false
        fi
    else
        local version=$(rustc --version 2>&1 | head -n1)
        print_msg "$GREEN" "✓ rustc 已安装 ($version)"
    fi
    
    # 检查 cargo
    if command -v cargo &> /dev/null; then
        local version=$(cargo --version 2>&1 | head -n1)
        print_msg "$GREEN" "✓ cargo 已安装 ($version)"
    else
        all_good=false
    fi
    
    # 检查 cargo-watch (用于热重载)
    if command -v cargo &> /dev/null; then
        if ! cargo watch --version &> /dev/null; then
            print_msg "$YELLOW" "  cargo-watch 未安装"
            read -p "是否要安装 cargo-watch (用于热重载)? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cargo install cargo-watch
                print_msg "$GREEN" "✓ cargo-watch 安装完成"
            fi
        else
            print_msg "$GREEN" "✓ cargo-watch 已安装"
        fi
    fi
    
    # 检查 wasm-pack (如果需要 WASM 支持)
    if [ -f "$RUST_DIR/Cargo.toml" ] && grep -q "wasm" "$RUST_DIR/Cargo.toml"; then
        if ! command -v wasm-pack &> /dev/null; then
            print_msg "$YELLOW" "⚠ wasm-pack 未安装"
            read -p "是否要安装 wasm-pack (WASM 支持)? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                curl https://rustwasm.github.io/wasm-pack/installer/init.sh -sSf | sh
                print_msg "$GREEN" "✓ wasm-pack 安装完成"
            fi
        else
            print_msg "$GREEN" "✓ wasm-pack 已安装"
        fi
    fi
    
    return $([ "$all_good" = true ] && echo 0 || echo 1)
}

# 自动安装 Flutter
install_flutter() {
    print_msg "$YELLOW" "  正在安装 Flutter..."
    
    # 检测操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        cd /tmp
        wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.16.5-stable.tar.xz
        tar xf flutter_linux_3.16.5-stable.tar.xz
        sudo mv flutter /opt/
        echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.bashrc
        source ~/.bashrc
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install flutter
        else
            cd /tmp
            wget https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.16.5-stable.zip
            unzip flutter_macos_3.16.5-stable.zip
            sudo mv flutter /opt/
            echo 'export PATH="$PATH:/opt/flutter/bin"' >> ~/.zshrc
            source ~/.zshrc
        fi
    fi
    
    flutter doctor --android-licenses --accept 2>/dev/null || true
    print_msg "$GREEN" "✓ Flutter 安装完成"
}

# 检查 Flutter 依赖
check_flutter_deps() {
    print_msg "$CYAN" "\n=== 检查 Flutter 依赖 ==="
    
    local all_good=true
    
    if ! command -v flutter &> /dev/null; then
        print_msg "$YELLOW" "⚠ Flutter 未安装"
        read -p "是否要自动安装 Flutter? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_flutter
            # 重新加载环境变量
            export PATH="$PATH:/opt/flutter/bin"
        else
            print_msg "$YELLOW" "  请访问 https://flutter.dev/docs/get-started/install 手动安装"
            all_good=false
        fi
    else
        local version=$(flutter --version 2>&1 | head -n1)
        print_msg "$GREEN" "✓ Flutter 已安装"
        
        # 运行 flutter doctor
        print_msg "$BLUE" "  运行 flutter doctor..."
        flutter doctor -v > "$LOG_DIR/flutter_doctor.log" 2>&1
        
        if flutter doctor | grep -q "\[✗\]"; then
            print_msg "$YELLOW" "  Flutter 有一些问题需要解决:"
            flutter doctor | grep "\[✗\]"
            
            # 尝试自动修复常见问题
            read -p "是否要尝试自动修复 Flutter 问题? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                flutter doctor --android-licenses 2>/dev/null || true
                flutter config --enable-web
                flutter precache
                print_msg "$GREEN" "  已尝试修复常见问题"
            fi
        else
            print_msg "$GREEN" "  Flutter 环境正常"
        fi
    fi
    
    return $([ "$all_good" = true ] && echo 0 || echo 1)
}

# 自动安装 PostgreSQL
install_postgresql() {
    print_msg "$YELLOW" "  正在安装 PostgreSQL..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # 检测发行版
        if [ -f /etc/debian_version ]; then
            # Debian/Ubuntu
            sudo apt-get update
            sudo apt-get install -y postgresql postgresql-contrib
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
            
            # 创建数据库用户和数据库
            sudo -u postgres psql -c "CREATE USER jive WITH PASSWORD 'jive_password';"
            sudo -u postgres psql -c "CREATE DATABASE jive OWNER jive;"
            sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE jive TO jive;"
        elif [ -f /etc/redhat-release ]; then
            # RHEL/CentOS/Fedora
            sudo yum install -y postgresql postgresql-server postgresql-contrib
            sudo postgresql-setup initdb
            sudo systemctl start postgresql
            sudo systemctl enable postgresql
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install postgresql
            brew services start postgresql
            createdb jive
        fi
    fi
    
    print_msg "$GREEN" "✓ PostgreSQL 安装完成"
}

# 自动安装 Redis
install_redis() {
    print_msg "$YELLOW" "  正在安装 Redis..."
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/debian_version ]; then
            # Debian/Ubuntu
            sudo apt-get update
            sudo apt-get install -y redis-server
            sudo systemctl start redis-server
            sudo systemctl enable redis-server
        elif [ -f /etc/redhat-release ]; then
            # RHEL/CentOS/Fedora
            sudo yum install -y redis
            sudo systemctl start redis
            sudo systemctl enable redis
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install redis
            brew services start redis
        fi
    fi
    
    print_msg "$GREEN" "✓ Redis 安装完成"
}

# 检查数据库
check_database() {
    print_msg "$CYAN" "\n=== 检查数据库服务 ==="
    
    # 检查 PostgreSQL
    if ! command -v psql &> /dev/null; then
        print_msg "$YELLOW" "⚠ PostgreSQL 未安装"
        read -p "是否要自动安装 PostgreSQL? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_postgresql
        fi
    else
        if pg_isready -p $POSTGRES_PORT &> /dev/null; then
            print_msg "$GREEN" "✓ PostgreSQL 正在运行 (端口 $POSTGRES_PORT)"
        else
            print_msg "$YELLOW" "⚠ PostgreSQL 未运行"
            read -p "是否要启动 PostgreSQL? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if command -v systemctl &> /dev/null; then
                    sudo systemctl start postgresql
                    print_msg "$GREEN" "✓ PostgreSQL 已启动"
                elif command -v brew &> /dev/null; then
                    brew services start postgresql
                    print_msg "$GREEN" "✓ PostgreSQL 已启动"
                else
                    print_msg "$RED" "  无法自动启动 PostgreSQL，请手动启动"
                fi
            fi
        fi
    fi
    
    # 检查 Redis（可选）
    if ! command -v redis-cli &> /dev/null; then
        print_msg "$YELLOW" "⚠ Redis 未安装（可选）"
        read -p "是否要安装 Redis? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_redis
        fi
    else
        if redis-cli -p $REDIS_PORT ping &> /dev/null; then
            print_msg "$GREEN" "✓ Redis 正在运行 (端口 $REDIS_PORT)"
        else
            print_msg "$YELLOW" "⚠ Redis 未运行"
            read -p "是否要启动 Redis? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if command -v systemctl &> /dev/null; then
                    sudo systemctl start redis-server 2>/dev/null || sudo systemctl start redis
                    print_msg "$GREEN" "✓ Redis 已启动"
                elif command -v brew &> /dev/null; then
                    brew services start redis
                    print_msg "$GREEN" "✓ Redis 已启动"
                fi
            fi
        fi
    fi
}

# 构建 Rust 项目
build_rust() {
    print_msg "$CYAN" "\n=== 构建 Rust 后端 ==="
    
    # 确保 Rust 环境变量已加载
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    
    cd "$RUST_DIR"
    
    # 检查 Cargo.toml 是否存在
    if [ ! -f "Cargo.toml" ]; then
        print_msg "$RED" "✗ Cargo.toml 不存在"
        return 1
    fi
    
    print_msg "$BLUE" "  运行 cargo build..."
    # 使用 server feature 而不是默认的 wasm
    cargo build --release 2>&1 | tee "$LOG_DIR/rust_build.log"
    
    if [ $? -eq 0 ]; then
        print_msg "$GREEN" "✓ Rust 构建成功"
        return 0
    else
        print_msg "$RED" "✗ Rust 构建失败，查看日志: $LOG_DIR/rust_build.log"
        return 1
    fi
}

# 启动 Rust 服务
start_rust_server() {
    print_msg "$CYAN" "\n=== 启动 Rust API 服务 ==="
    
    # 确保 Rust 环境变量已加载
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    fi
    
    cd "$RUST_DIR"
    
    # 检查是否已经在运行
    if pgrep -f "target/release/jive-core" > /dev/null; then
        print_msg "$YELLOW" "⚠ Rust 服务已在运行"
        return 0
    fi
    
    # 设置环境变量
    export DATABASE_URL=${DATABASE_URL:-"postgresql://jive:jive_password@localhost:$POSTGRES_PORT/jive"}
    export RUST_LOG=${RUST_LOG:-"info"}
    export API_PORT=$RUST_API_PORT
    
    print_msg "$BLUE" "  启动服务 (端口 $RUST_API_PORT)..."
    
    # 使用 cargo watch 进行热重载开发
    if [ "$1" = "dev" ]; then
        cargo watch -x "run" > "$LOG_DIR/rust_server.log" 2>&1 &
    else
        cargo run --release > "$LOG_DIR/rust_server.log" 2>&1 &
    fi
    
    local pid=$!
    echo $pid > "$PROJECT_ROOT/.rust_server.pid"
    
    # 等待服务启动
    sleep 3
    
    if kill -0 $pid 2>/dev/null; then
        print_msg "$GREEN" "✓ Rust 服务已启动 (PID: $pid)"
        print_msg "$BLUE" "  API 地址: http://localhost:$RUST_API_PORT"
        return 0
    else
        print_msg "$RED" "✗ Rust 服务启动失败"
        cat "$LOG_DIR/rust_server.log" | tail -20
        return 1
    fi
}

# 启动 Flutter 应用
start_flutter_app() {
    print_msg "$CYAN" "\n=== 启动 Flutter 应用 ==="
    
    cd "$FLUTTER_DIR"
    
    # 检查 pubspec.yaml 是否存在
    if [ ! -f "pubspec.yaml" ]; then
        print_msg "$RED" "✗ pubspec.yaml 不存在"
        return 1
    fi
    
    # 获取依赖
    print_msg "$BLUE" "  获取 Flutter 依赖..."
    flutter pub get 2>&1 | tee "$LOG_DIR/flutter_pub.log"
    
    # 选择运行平台
    print_msg "$MAGENTA" "\n选择运行平台:"
    echo "  1) Web (浏览器)"
    echo "  2) iOS 模拟器"
    echo "  3) Android 模拟器"
    echo "  4) macOS 桌面"
    echo "  5) Linux 桌面"
    echo "  6) Windows 桌面"
    
    read -p "请选择 (1-6): " platform_choice
    
    case $platform_choice in
        1)
            print_msg "$BLUE" "  启动 Flutter Web..."
            flutter run lib/main_simple.dart -d chrome --web-port=$FLUTTER_DEV_PORT > "$LOG_DIR/flutter_web.log" 2>&1 &
            local pid=$!
            echo $pid > "$PROJECT_ROOT/.flutter_web.pid"
            print_msg "$GREEN" "✓ Flutter Web 已启动"
            print_msg "$BLUE" "  访问地址: http://localhost:$FLUTTER_DEV_PORT"
            ;;
        2)
            print_msg "$BLUE" "  启动 iOS 模拟器..."
            open -a Simulator
            sleep 5
            flutter run -d iphone > "$LOG_DIR/flutter_ios.log" 2>&1 &
            ;;
        3)
            print_msg "$BLUE" "  启动 Android 模拟器..."
            flutter emulators --launch
            sleep 10
            flutter run -d android > "$LOG_DIR/flutter_android.log" 2>&1 &
            ;;
        4)
            print_msg "$BLUE" "  启动 macOS 应用..."
            flutter run -d macos > "$LOG_DIR/flutter_macos.log" 2>&1 &
            ;;
        5)
            print_msg "$BLUE" "  启动 Linux 应用..."
            flutter run -d linux > "$LOG_DIR/flutter_linux.log" 2>&1 &
            ;;
        6)
            print_msg "$BLUE" "  启动 Windows 应用..."
            flutter run -d windows > "$LOG_DIR/flutter_windows.log" 2>&1 &
            ;;
        *)
            print_msg "$RED" "无效选择"
            return 1
            ;;
    esac
}

# 停止所有服务
stop_all_services() {
    print_msg "$CYAN" "\n=== 停止所有服务 ==="
    
    # 停止 Rust 服务
    if [ -f "$PROJECT_ROOT/.rust_server.pid" ]; then
        local pid=$(cat "$PROJECT_ROOT/.rust_server.pid")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            print_msg "$GREEN" "✓ 已停止 Rust 服务"
        fi
        rm "$PROJECT_ROOT/.rust_server.pid"
    fi
    
    # 停止 Flutter Web
    if [ -f "$PROJECT_ROOT/.flutter_web.pid" ]; then
        local pid=$(cat "$PROJECT_ROOT/.flutter_web.pid")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            print_msg "$GREEN" "✓ 已停止 Flutter Web"
        fi
        rm "$PROJECT_ROOT/.flutter_web.pid"
    fi
    
    # 停止其他 Flutter 进程
    pkill -f "flutter run" 2>/dev/null || true
}

# 显示服务状态
show_status() {
    print_msg "$CYAN" "\n=== 服务状态 ==="
    
    # Rust 服务状态
    if [ -f "$PROJECT_ROOT/.rust_server.pid" ]; then
        local pid=$(cat "$PROJECT_ROOT/.rust_server.pid")
        if kill -0 $pid 2>/dev/null; then
            print_msg "$GREEN" "✓ Rust API: 运行中 (PID: $pid, 端口: $RUST_API_PORT)"
        else
            print_msg "$RED" "✗ Rust API: 未运行"
        fi
    else
        print_msg "$YELLOW" "⚠ Rust API: 状态未知"
    fi
    
    # Flutter 状态
    if [ -f "$PROJECT_ROOT/.flutter_web.pid" ]; then
        local pid=$(cat "$PROJECT_ROOT/.flutter_web.pid")
        if kill -0 $pid 2>/dev/null; then
            print_msg "$GREEN" "✓ Flutter Web: 运行中 (PID: $pid, 端口: $FLUTTER_DEV_PORT)"
        else
            print_msg "$RED" "✗ Flutter Web: 未运行"
        fi
    else
        print_msg "$YELLOW" "⚠ Flutter Web: 状态未知"
    fi
    
    # 数据库状态
    if command -v pg_isready &> /dev/null && pg_isready -p $POSTGRES_PORT &> /dev/null; then
        print_msg "$GREEN" "✓ PostgreSQL: 运行中 (端口: $POSTGRES_PORT)"
    else
        print_msg "$YELLOW" "⚠ PostgreSQL: 未运行或未安装"
    fi
    
    if command -v redis-cli &> /dev/null && redis-cli -p $REDIS_PORT ping &> /dev/null; then
        print_msg "$GREEN" "✓ Redis: 运行中 (端口: $REDIS_PORT)"
    else
        print_msg "$YELLOW" "⚠ Redis: 未运行或未安装"
    fi
}

# 主菜单
show_menu() {
    print_msg "$MAGENTA" "\n========================================="
    print_msg "$MAGENTA" "     Jive Money - 集腋记账 启动器"
    print_msg "$MAGENTA" "========================================="
    echo
    echo "1) 完整启动 (检查依赖 + 启动所有服务)"
    echo "2) 仅检查依赖和端口"
    echo "3) 仅启动 Rust 后端"
    echo "4) 仅启动 Flutter 前端"
    echo "5) 开发模式 (热重载)"
    echo "6) 查看服务状态"
    echo "7) 停止所有服务"
    echo "8) 快速重启 Flutter"
    echo "9) 查看日志"
    echo "10) 退出"
    echo
    read -p "请选择操作 (1-10): " choice
}

# 快速重启 Flutter
quick_restart_flutter() {
    print_msg "$CYAN" "\n=== 快速重启 Flutter 应用 ==="
    
    cd "$FLUTTER_DIR"
    
    # 停止现有的 Flutter 进程
    if [ -f "$PROJECT_ROOT/.flutter_web.pid" ]; then
        local pid=$(cat "$PROJECT_ROOT/.flutter_web.pid")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            print_msg "$YELLOW" "已停止现有 Flutter 进程 (PID: $pid)"
        fi
        rm "$PROJECT_ROOT/.flutter_web.pid"
    fi
    
    # 杀死所有 Flutter 相关进程
    pkill -f "flutter run" 2>/dev/null || true
    pkill -f "dart.*web_entrypoint" 2>/dev/null || true
    
    # 等待进程完全结束
    sleep 2
    
    # 检查端口是否释放
    if lsof -Pi :$FLUTTER_DEV_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        local pid=$(lsof -Pi :$FLUTTER_DEV_PORT -sTCP:LISTEN -t)
        print_msg "$YELLOW" "强制终止占用端口 $FLUTTER_DEV_PORT 的进程 (PID: $pid)"
        kill -9 $pid 2>/dev/null || true
        sleep 1
    fi
    
    # 重新启动 Flutter
    print_msg "$BLUE" "正在重新启动 Flutter 应用..."
    flutter run lib/main_simple.dart -d chrome --web-port=$FLUTTER_DEV_PORT > "$LOG_DIR/flutter_web.log" 2>&1 &
    
    local pid=$!
    echo $pid > "$PROJECT_ROOT/.flutter_web.pid"
    
    print_msg "$GREEN" "✓ Flutter 应用重启成功 (PID: $pid)"
    print_msg "$BLUE" "  访问地址: http://localhost:$FLUTTER_DEV_PORT"
    
    # 显示启动日志
    print_msg "$BLUE" "等待应用启动..."
    sleep 3
    
    if kill -0 $pid 2>/dev/null; then
        print_msg "$GREEN" "✅ 应用启动成功!"
    else
        print_msg "$RED" "❌ 应用启动失败，查看日志:"
        tail -20 "$LOG_DIR/flutter_web.log"
    fi
}

# 查看日志
view_logs() {
    print_msg "$CYAN" "\n=== 日志文件 ==="
    echo "1) Rust 构建日志"
    echo "2) Rust 服务日志"
    echo "3) Flutter 依赖日志"
    echo "4) Flutter Web 日志"
    echo "5) Flutter Doctor 日志"
    echo "6) 所有日志"
    
    read -p "选择要查看的日志 (1-6): " log_choice
    
    case $log_choice in
        1) less "$LOG_DIR/rust_build.log" ;;
        2) tail -f "$LOG_DIR/rust_server.log" ;;
        3) less "$LOG_DIR/flutter_pub.log" ;;
        4) tail -f "$LOG_DIR/flutter_web.log" ;;
        5) less "$LOG_DIR/flutter_doctor.log" ;;
        6) tail -f "$LOG_DIR"/*.log ;;
        *) print_msg "$RED" "无效选择" ;;
    esac
}

# 完整启动流程
full_start() {
    print_msg "$CYAN" "\n开始完整启动流程...\n"
    
    # 1. 检查依赖
    local deps_ok=true
    check_rust_deps || deps_ok=false
    check_flutter_deps || deps_ok=false
    
    if [ "$deps_ok" = false ]; then
        print_msg "$RED" "\n依赖检查失败，请先安装缺失的依赖"
        return 1
    fi
    
    # 2. 检查端口
    print_msg "$CYAN" "\n=== 检查端口占用 ==="
    local ports_ok=true
    check_port $RUST_API_PORT "Rust API" || ports_ok=false
    check_port $FLUTTER_DEV_PORT "Flutter Dev" || ports_ok=false
    
    if [ "$ports_ok" = false ]; then
        print_msg "$RED" "\n端口检查失败"
        return 1
    fi
    
    # 3. 检查数据库
    check_database
    
    # 4. 构建和启动服务
    build_rust || return 1
    start_rust_server || return 1
    start_flutter_app || return 1
    
    print_msg "$GREEN" "\n✅ 所有服务已成功启动!"
    show_status
}

# 开发模式
dev_mode() {
    print_msg "$CYAN" "\n启动开发模式 (热重载)...\n"
    
    # 检查依赖
    check_rust_deps || return 1
    check_flutter_deps || return 1
    
    # 检查端口
    check_port $RUST_API_PORT "Rust API" || return 1
    check_port $FLUTTER_DEV_PORT "Flutter Dev" || return 1
    
    # 启动开发服务
    start_rust_server "dev" || return 1
    
    # Flutter 热重载
    cd "$FLUTTER_DIR"
    print_msg "$BLUE" "启动 Flutter 热重载..."
    flutter run lib/main_simple.dart -d chrome --web-port=$FLUTTER_DEV_PORT
}

# 清理函数
cleanup() {
    if [ "$SKIP_CLEANUP" != "true" ]; then
        print_msg "$YELLOW" "\n正在清理..."
        stop_all_services
    fi
    exit 0
}

# 捕获退出信号
trap cleanup EXIT INT TERM

# 主程序
main() {
    # 检查是否以 root 运行
    if [ "$EUID" -eq 0 ]; then 
        print_msg "$RED" "请不要以 root 用户运行此脚本"
        exit 1
    fi
    
    # 处理命令行参数
    case "$1" in
        start)
            full_start
            ;;
        stop)
            stop_all_services
            ;;
        status)
            show_status
            ;;
        dev)
            dev_mode
            ;;
        restart)
            SKIP_CLEANUP=true
            quick_restart_flutter
            ;;
        *)
            # 显示交互式菜单
            while true; do
                show_menu
                case $choice in
                    1) full_start ;;
                    2) 
                        check_rust_deps
                        check_flutter_deps
                        check_port $RUST_API_PORT "Rust API"
                        check_port $FLUTTER_DEV_PORT "Flutter Dev"
                        check_database
                        ;;
                    3) 
                        build_rust && start_rust_server
                        ;;
                    4) 
                        start_flutter_app
                        ;;
                    5) 
                        dev_mode
                        ;;
                    6) 
                        show_status
                        ;;
                    7) 
                        stop_all_services
                        ;;
                    8) 
                        quick_restart_flutter
                        ;;
                    9) 
                        view_logs
                        ;;
                    10) 
                        print_msg "$GREEN" "再见!"
                        exit 0
                        ;;
                    *)
                        print_msg "$RED" "无效选择，请重试"
                        ;;
                esac
                
                echo
                read -p "按回车键继续..."
            done
            ;;
    esac
}

# 运行主程序
main "$@"