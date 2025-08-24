#!/bin/bash

# Flutter 快速安装脚本
# 支持 Linux/macOS 系统

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flutter 版本
FLUTTER_VERSION="3.16.5"
FLUTTER_CHANNEL="stable"

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}         Flutter 快速安装脚本${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS="linux"
        echo -e "${GREEN}✓ 检测到 Linux 系统${NC}"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        echo -e "${GREEN}✓ 检测到 macOS 系统${NC}"
    else
        echo -e "${RED}✗ 不支持的操作系统: $OSTYPE${NC}"
        exit 1
    fi
}

# 检查依赖
check_dependencies() {
    echo -e "\n${YELLOW}检查依赖...${NC}"
    
    # 检查 Git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}✗ Git 未安装${NC}"
        if [[ "$OS" == "linux" ]]; then
            echo "  请运行: sudo apt install git"
        else
            echo "  请运行: brew install git"
        fi
        exit 1
    else
        echo -e "${GREEN}✓ Git 已安装${NC}"
    fi
    
    # 检查 curl
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}✗ curl 未安装${NC}"
        if [[ "$OS" == "linux" ]]; then
            echo "  请运行: sudo apt install curl"
        else
            echo "  请运行: brew install curl"
        fi
        exit 1
    else
        echo -e "${GREEN}✓ curl 已安装${NC}"
    fi
    
    # 检查 unzip
    if ! command -v unzip &> /dev/null; then
        echo -e "${RED}✗ unzip 未安装${NC}"
        if [[ "$OS" == "linux" ]]; then
            echo "  请运行: sudo apt install unzip"
        else
            echo "  请运行: brew install unzip"
        fi
        exit 1
    else
        echo -e "${GREEN}✓ unzip 已安装${NC}"
    fi
}

# 安装 Flutter
install_flutter() {
    echo -e "\n${YELLOW}开始安装 Flutter...${NC}"
    
    # 设置安装目录
    FLUTTER_DIR="$HOME/flutter"
    
    # 如果已存在，询问是否覆盖
    if [ -d "$FLUTTER_DIR" ]; then
        echo -e "${YELLOW}Flutter 目录已存在: $FLUTTER_DIR${NC}"
        read -p "是否要重新安装? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "跳过 Flutter 安装"
            return
        fi
        rm -rf "$FLUTTER_DIR"
    fi
    
    # 下载 Flutter
    echo -e "${YELLOW}下载 Flutter SDK...${NC}"
    
    if [[ "$OS" == "linux" ]]; then
        FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/$FLUTTER_CHANNEL/linux/flutter_linux_$FLUTTER_VERSION-$FLUTTER_CHANNEL.tar.xz"
        
        # 中国镜像
        if [[ -n "$USE_MIRROR" ]]; then
            FLUTTER_URL="https://storage.flutter-io.cn/flutter_infra_release/releases/$FLUTTER_CHANNEL/linux/flutter_linux_$FLUTTER_VERSION-$FLUTTER_CHANNEL.tar.xz"
        fi
        
        cd ~
        curl -LO "$FLUTTER_URL"
        tar xf flutter_linux_$FLUTTER_VERSION-$FLUTTER_CHANNEL.tar.xz
        rm flutter_linux_$FLUTTER_VERSION-$FLUTTER_CHANNEL.tar.xz
        
    elif [[ "$OS" == "macos" ]]; then
        FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/$FLUTTER_CHANNEL/macos/flutter_macos_$FLUTTER_VERSION-$FLUTTER_CHANNEL.zip"
        
        # 中国镜像
        if [[ -n "$USE_MIRROR" ]]; then
            FLUTTER_URL="https://storage.flutter-io.cn/flutter_infra_release/releases/$FLUTTER_CHANNEL/macos/flutter_macos_$FLUTTER_VERSION-$FLUTTER_CHANNEL.zip"
        fi
        
        cd ~
        curl -LO "$FLUTTER_URL"
        unzip -q flutter_macos_$FLUTTER_VERSION-$FLUTTER_CHANNEL.zip
        rm flutter_macos_$FLUTTER_VERSION-$FLUTTER_CHANNEL.zip
    fi
    
    echo -e "${GREEN}✓ Flutter SDK 下载完成${NC}"
}

# 配置环境变量
setup_environment() {
    echo -e "\n${YELLOW}配置环境变量...${NC}"
    
    # 检测 shell
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.profile"
    fi
    
    # 添加 Flutter 到 PATH
    echo "" >> "$SHELL_RC"
    echo "# Flutter" >> "$SHELL_RC"
    echo 'export PATH="$PATH:$HOME/flutter/bin"' >> "$SHELL_RC"
    
    # 中国镜像配置
    if [[ -n "$USE_MIRROR" ]]; then
        echo "# Flutter 中国镜像" >> "$SHELL_RC"
        echo 'export PUB_HOSTED_URL=https://pub.flutter-io.cn' >> "$SHELL_RC"
        echo 'export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn' >> "$SHELL_RC"
    fi
    
    # 立即生效
    export PATH="$PATH:$HOME/flutter/bin"
    
    if [[ -n "$USE_MIRROR" ]]; then
        export PUB_HOSTED_URL=https://pub.flutter-io.cn
        export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
    fi
    
    echo -e "${GREEN}✓ 环境变量配置完成${NC}"
    echo -e "  配置文件: $SHELL_RC"
}

# 安装额外依赖
install_additional_deps() {
    echo -e "\n${YELLOW}安装额外依赖...${NC}"
    
    if [[ "$OS" == "linux" ]]; then
        echo "安装 Linux 开发依赖..."
        sudo apt update
        sudo apt install -y \
            clang \
            cmake \
            ninja-build \
            pkg-config \
            libgtk-3-dev \
            liblzma-dev \
            libstdc++-12-dev
        
    elif [[ "$OS" == "macos" ]]; then
        # 检查 Homebrew
        if ! command -v brew &> /dev/null; then
            echo -e "${YELLOW}Homebrew 未安装，正在安装...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        echo "安装 macOS 开发依赖..."
        
        # 安装 CocoaPods
        if ! command -v pod &> /dev/null; then
            sudo gem install cocoapods
        fi
        
        # 安装 Xcode 命令行工具
        xcode-select --install 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓ 额外依赖安装完成${NC}"
}

# 验证安装
verify_installation() {
    echo -e "\n${YELLOW}验证 Flutter 安装...${NC}"
    
    # 检查 Flutter 版本
    if $HOME/flutter/bin/flutter --version &> /dev/null; then
        echo -e "${GREEN}✓ Flutter 安装成功!${NC}"
        $HOME/flutter/bin/flutter --version
    else
        echo -e "${RED}✗ Flutter 安装失败${NC}"
        exit 1
    fi
    
    echo -e "\n${YELLOW}运行 Flutter Doctor...${NC}"
    $HOME/flutter/bin/flutter doctor
}

# 安装 VS Code 扩展
install_vscode_extensions() {
    if command -v code &> /dev/null; then
        echo -e "\n${YELLOW}安装 VS Code Flutter 扩展...${NC}"
        code --install-extension Dart-Code.flutter
        code --install-extension Dart-Code.dart-code
        echo -e "${GREEN}✓ VS Code 扩展安装完成${NC}"
    fi
}

# 创建测试项目
create_test_project() {
    echo -e "\n${YELLOW}是否创建测试项目? (y/n)${NC}"
    read -p "> " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd ~
        $HOME/flutter/bin/flutter create flutter_test_app
        echo -e "${GREEN}✓ 测试项目创建成功: ~/flutter_test_app${NC}"
        echo -e "  运行项目: cd ~/flutter_test_app && flutter run"
    fi
}

# 主函数
main() {
    # 询问是否使用中国镜像
    echo -e "${YELLOW}是否使用中国镜像加速? (y/n)${NC}"
    read -p "> " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        USE_MIRROR=1
        echo -e "${GREEN}✓ 将使用中国镜像${NC}"
    fi
    
    # 执行安装步骤
    detect_os
    check_dependencies
    install_flutter
    setup_environment
    install_additional_deps
    verify_installation
    install_vscode_extensions
    create_test_project
    
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}         Flutter 安装完成！${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${YELLOW}重要提示:${NC}"
    echo "1. 请运行以下命令使环境变量生效:"
    echo -e "   ${BLUE}source ~/.bashrc${NC} (或 source ~/.zshrc)"
    echo ""
    echo "2. 验证安装:"
    echo -e "   ${BLUE}flutter doctor${NC}"
    echo ""
    echo "3. 接受 Android 许可证:"
    echo -e "   ${BLUE}flutter doctor --android-licenses${NC}"
    echo ""
    echo "4. 运行 Jive 项目:"
    echo -e "   ${BLUE}cd ~/jive-flutter-rust/jive-flutter${NC}"
    echo -e "   ${BLUE}flutter pub get${NC}"
    echo -e "   ${BLUE}flutter run${NC}"
    echo ""
    echo -e "${GREEN}祝您使用愉快！${NC}"
}

# 运行主函数
main