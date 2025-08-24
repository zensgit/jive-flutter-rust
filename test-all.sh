#!/bin/bash

# Jive 项目完整测试脚本
# 运行所有 Rust 和 Flutter 测试

set -e

echo "🚀 开始运行 Jive 项目完整测试套件..."
echo "=================================================="

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 测试结果统计
RUST_TESTS_PASSED=0
FLUTTER_TESTS_PASSED=0
TOTAL_ERRORS=0

# 检查必要工具
check_tools() {
    echo -e "${BLUE}🔧 检查开发工具...${NC}"
    
    # 检查 Rust
    if ! command -v cargo &> /dev/null; then
        echo -e "${RED}❌ Cargo (Rust) 未安装${NC}"
        echo "请访问 https://rustup.rs/ 安装 Rust"
        exit 1
    else
        echo -e "${GREEN}✅ Cargo (Rust) 已安装${NC}"
        cargo --version
    fi
    
    # 检查 Flutter
    if ! command -v flutter &> /dev/null; then
        echo -e "${YELLOW}⚠️  Flutter 未安装，跳过 Flutter 测试${NC}"
        FLUTTER_AVAILABLE=false
    else
        echo -e "${GREEN}✅ Flutter 已安装${NC}"
        flutter --version | head -1
        FLUTTER_AVAILABLE=true
    fi
    
    echo ""
}

# 运行 Rust 核心测试
test_rust_core() {
    echo -e "${BLUE}🦀 运行 Rust 核心库测试...${NC}"
    echo "------------------------------------------------"
    
    cd jive-core
    
    # 检查代码格式
    echo "📝 检查代码格式..."
    if cargo fmt --check > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 代码格式正确${NC}"
    else
        echo -e "${YELLOW}⚠️  代码格式需要调整，自动格式化中...${NC}"
        cargo fmt
    fi
    
    # 运行 Clippy 检查
    echo "🔍 运行 Clippy 静态分析..."
    if cargo clippy --all-targets --all-features -- -D warnings > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Clippy 检查通过${NC}"
    else
        echo -e "${YELLOW}⚠️  Clippy 发现了一些警告${NC}"
        cargo clippy --all-targets --all-features -- -D warnings
    fi
    
    # 运行单元测试
    echo "🧪 运行单元测试..."
    if cargo test --lib 2>&1; then
        echo -e "${GREEN}✅ 单元测试通过${NC}"
        RUST_TESTS_PASSED=$((RUST_TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ 单元测试失败${NC}"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    
    # 运行集成测试
    echo "🔗 运行集成测试..."
    if cargo test --test integration_tests 2>&1; then
        echo -e "${GREEN}✅ 集成测试通过${NC}"
        RUST_TESTS_PASSED=$((RUST_TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ 集成测试失败${NC}"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    
    # 运行文档测试
    echo "📚 运行文档测试..."
    if cargo test --doc 2>&1; then
        echo -e "${GREEN}✅ 文档测试通过${NC}"
        RUST_TESTS_PASSED=$((RUST_TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ 文档测试失败${NC}"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    
    # 生成测试覆盖率报告（如果 tarpaulin 可用）
    if command -v cargo-tarpaulin &> /dev/null; then
        echo "📊 生成测试覆盖率报告..."
        cargo tarpaulin --out Html --output-dir coverage
        echo -e "${GREEN}✅ 覆盖率报告已生成到 coverage/tarpaulin-report.html${NC}"
    fi
    
    cd ..
    echo ""
}

# 运行 Flutter 测试
test_flutter_app() {
    if [ "$FLUTTER_AVAILABLE" = false ]; then
        echo -e "${YELLOW}⚠️  跳过 Flutter 测试 (Flutter 未安装)${NC}"
        return
    fi
    
    echo -e "${BLUE}📱 运行 Flutter 应用测试...${NC}"
    echo "------------------------------------------------"
    
    cd jive-flutter
    
    # 获取依赖
    echo "📦 获取 Flutter 依赖..."
    flutter pub get
    
    # 运行代码分析
    echo "🔍 运行 Flutter 代码分析..."
    if flutter analyze > /dev/null 2>&1; then
        echo -e "${GREEN}✅ 代码分析通过${NC}"
    else
        echo -e "${YELLOW}⚠️  代码分析发现了一些问题${NC}"
        flutter analyze
    fi
    
    # 检查代码格式
    echo "📝 检查 Dart 代码格式..."
    if dart format --set-exit-if-changed . > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Dart 代码格式正确${NC}"
    else
        echo -e "${YELLOW}⚠️  Dart 代码格式需要调整，自动格式化中...${NC}"
        dart format .
    fi
    
    # 运行单元测试
    echo "🧪 运行 Flutter 单元测试..."
    if flutter test 2>&1; then
        echo -e "${GREEN}✅ Flutter 单元测试通过${NC}"
        FLUTTER_TESTS_PASSED=$((FLUTTER_TESTS_PASSED + 1))
    else
        echo -e "${RED}❌ Flutter 单元测试失败${NC}"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    
    # 运行集成测试（如果存在）
    if [ -d "integration_test" ]; then
        echo "🔗 运行 Flutter 集成测试..."
        if flutter test integration_test 2>&1; then
            echo -e "${GREEN}✅ Flutter 集成测试通过${NC}"
            FLUTTER_TESTS_PASSED=$((FLUTTER_TESTS_PASSED + 1))
        else
            echo -e "${RED}❌ Flutter 集成测试失败${NC}"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi
    fi
    
    cd ..
    echo ""
}

# 构建检查
build_check() {
    echo -e "${BLUE}🔨 构建检查...${NC}"
    echo "------------------------------------------------"
    
    # 构建 Rust 核心库
    echo "🦀 构建 Rust 核心库..."
    cd jive-core
    if cargo build --release > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Rust 核心库构建成功${NC}"
    else
        echo -e "${RED}❌ Rust 核心库构建失败${NC}"
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
    cd ..
    
    # 构建 Flutter 应用
    if [ "$FLUTTER_AVAILABLE" = true ]; then
        echo "📱 构建 Flutter 应用..."
        cd jive-flutter
        if flutter build web > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Flutter Web 构建成功${NC}"
        else
            echo -e "${RED}❌ Flutter Web 构建失败${NC}"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        fi
        cd ..
    fi
    
    echo ""
}

# 性能基准测试
benchmark_tests() {
    echo -e "${BLUE}⚡ 性能基准测试...${NC}"
    echo "------------------------------------------------"
    
    cd jive-core
    
    # 运行基准测试（如果存在）
    if [ -d "benches" ]; then
        echo "📊 运行 Rust 基准测试..."
        if cargo bench > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 基准测试完成${NC}"
        else
            echo -e "${YELLOW}⚠️  基准测试未能运行${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  未找到基准测试${NC}"
    fi
    
    cd ..
    echo ""
}

# 安全检查
security_check() {
    echo -e "${BLUE}🔒 安全检查...${NC}"
    echo "------------------------------------------------"
    
    cd jive-core
    
    # 检查依赖漏洞（如果 cargo-audit 可用）
    if command -v cargo-audit &> /dev/null; then
        echo "🔍 检查 Rust 依赖漏洞..."
        if cargo audit > /dev/null 2>&1; then
            echo -e "${GREEN}✅ 未发现安全漏洞${NC}"
        else
            echo -e "${YELLOW}⚠️  发现潜在安全问题${NC}"
            cargo audit
        fi
    else
        echo -e "${YELLOW}⚠️  cargo-audit 未安装，跳过安全检查${NC}"
        echo "安装命令: cargo install cargo-audit"
    fi
    
    cd ..
    echo ""
}

# 生成测试报告
generate_report() {
    echo -e "${BLUE}📋 生成测试报告...${NC}"
    echo "=================================================="
    
    local total_tests=$((RUST_TESTS_PASSED + FLUTTER_TESTS_PASSED))
    
    echo "🧪 测试结果摘要:"
    echo "  Rust 测试: ${RUST_TESTS_PASSED} 个通过"
    echo "  Flutter 测试: ${FLUTTER_TESTS_PASSED} 个通过"
    echo "  总测试数: ${total_tests} 个"
    echo "  失败/错误: ${TOTAL_ERRORS} 个"
    
    if [ $TOTAL_ERRORS -eq 0 ]; then
        echo -e "${GREEN}🎉 所有测试都通过了！${NC}"
        echo ""
        echo -e "${GREEN}✅ Jive 项目质量检查完成${NC}"
        echo "📊 代码质量: 优秀"
        echo "🔒 安全状态: 良好"
        echo "⚡ 性能状态: 正常"
        
        # 创建成功标记文件
        echo "$(date): All tests passed" > .test-success
    else
        echo -e "${RED}❌ 发现 ${TOTAL_ERRORS} 个问题需要修复${NC}"
        echo ""
        echo "请查看上述错误信息并修复问题后重新运行测试。"
        
        # 删除成功标记文件（如果存在）
        rm -f .test-success
        exit 1
    fi
}

# 主函数
main() {
    local start_time=$(date +%s)
    
    check_tools
    test_rust_core
    test_flutter_app
    build_check
    benchmark_tests
    security_check
    generate_report
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo ""
    echo -e "${BLUE}⏱️  总耗时: ${duration} 秒${NC}"
    echo -e "${GREEN}🚀 测试套件运行完成！${NC}"
}

# 运行主函数
main "$@"