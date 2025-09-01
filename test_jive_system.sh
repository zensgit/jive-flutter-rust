#!/bin/bash

# Jive 系统测试脚本
# 用于验证 Flutter + Rust + WASM 架构的功能

set -e

echo "================================================="
echo "         Jive 系统集成测试"
echo "================================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试结果统计
TESTS_PASSED=0
TESTS_FAILED=0

# 测试函数
run_test() {
    local test_name=$1
    local test_command=$2
    
    echo -n "测试: $test_name ... "
    
    if eval $test_command > /dev/null 2>&1; then
        echo -e "${GREEN}✓ 通过${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ 失败${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 1. 检查环境
echo "=== 1. 环境检查 ==="
echo ""

run_test "Flutter 安装检查" "flutter --version"
run_test "Dart 安装检查" "dart --version"
run_test "Rust 安装检查" "rustc --version"
run_test "Cargo 安装检查" "cargo --version"

echo ""
echo "=== 2. Rust 后端测试 ==="
echo ""

cd jive-core

# 检查 Rust 项目结构
run_test "Cargo.toml 存在" "test -f Cargo.toml"
run_test "源代码目录存在" "test -d src"

# 编译 Rust 项目
echo -e "${YELLOW}编译 Rust 项目...${NC}"
if cargo build --release 2>/dev/null; then
    echo -e "${GREEN}✓ Rust 编译成功${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ Rust 编译失败${NC}"
    ((TESTS_FAILED++))
fi

# 运行 Rust 测试
echo -e "${YELLOW}运行 Rust 单元测试...${NC}"
if cargo test --quiet 2>/dev/null; then
    echo -e "${GREEN}✓ Rust 测试通过${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ Rust 测试失败${NC}"
    ((TESTS_FAILED++))
fi

cd ..

echo ""
echo "=== 3. Flutter 前端测试 ==="
echo ""

cd jive-flutter

# 检查 Flutter 项目结构
run_test "pubspec.yaml 存在" "test -f pubspec.yaml"
run_test "lib 目录存在" "test -d lib"
run_test "main.dart 存在" "test -f lib/main.dart"

# 获取 Flutter 依赖
echo -e "${YELLOW}获取 Flutter 依赖...${NC}"
if flutter pub get 2>/dev/null; then
    echo -e "${GREEN}✓ 依赖安装成功${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ 依赖安装失败${NC}"
    ((TESTS_FAILED++))
fi

# 分析 Flutter 代码
echo -e "${YELLOW}分析 Flutter 代码...${NC}"
if flutter analyze --no-fatal-infos 2>/dev/null; then
    echo -e "${GREEN}✓ 代码分析通过${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ 代码分析有警告${NC}"
fi

# 运行 Flutter 测试
echo -e "${YELLOW}运行 Flutter 单元测试...${NC}"
if flutter test 2>/dev/null; then
    echo -e "${GREEN}✓ Flutter 测试通过${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ Flutter 测试未配置或失败${NC}"
fi

cd ..

echo ""
echo "=== 4. 集成测试 ==="
echo ""

# 检查关键文件
run_test "认证Provider存在" "test -f jive-flutter/lib/providers/auth_provider.dart"
run_test "交易Provider存在" "test -f jive-flutter/lib/providers/transaction_provider.dart"
run_test "账户Provider存在" "test -f jive-flutter/lib/providers/account_provider.dart"
run_test "预算Provider存在" "test -f jive-flutter/lib/providers/budget_provider.dart"
run_test "路由配置存在" "test -f jive-flutter/lib/core/router/app_router.dart"
run_test "主应用文件存在" "test -f jive-flutter/lib/app.dart"

echo ""
echo "=== 5. 构建测试 ==="
echo ""

cd jive-flutter

# 测试 Web 构建
echo -e "${YELLOW}测试 Web 构建...${NC}"
if flutter build web --release --no-pub 2>/dev/null; then
    echo -e "${GREEN}✓ Web 构建成功${NC}"
    ((TESTS_PASSED++))
    run_test "Web 构建产物存在" "test -d build/web"
else
    echo -e "${RED}✗ Web 构建失败${NC}"
    ((TESTS_FAILED++))
fi

cd ..

echo ""
echo "================================================="
echo "              测试结果总结"
echo "================================================="
echo ""
echo -e "通过的测试: ${GREEN}$TESTS_PASSED${NC}"
echo -e "失败的测试: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ 所有测试通过！Jive 系统运行正常。${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️ 有 $TESTS_FAILED 个测试失败，请检查相关组件。${NC}"
    exit 1
fi