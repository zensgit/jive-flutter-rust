#!/bin/bash

# Flutter 环境修复脚本
# 安装缺失的 Android SDK 和 Chrome

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}      Flutter 环境修复脚本${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 1. 安装 Android SDK
install_android_sdk() {
    echo -e "${YELLOW}=== 安装 Android SDK ===${NC}"
    echo ""
    
    # 创建 Android SDK 目录
    ANDROID_HOME="$HOME/Android/Sdk"
    mkdir -p "$ANDROID_HOME"
    
    # 下载命令行工具
    echo "下载 Android 命令行工具..."
    cd /tmp
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip
    
    # 解压到 SDK 目录
    echo "解压命令行工具..."
    unzip -q commandlinetools-linux-9477386_latest.zip
    mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
    mv cmdline-tools/* "$ANDROID_HOME/cmdline-tools/latest/" 2>/dev/null || true
    rm -rf commandlinetools-linux-9477386_latest.zip cmdline-tools
    
    # 设置环境变量
    echo "配置环境变量..."
    echo "" >> ~/.bashrc
    echo "# Android SDK" >> ~/.bashrc
    echo "export ANDROID_HOME=$ANDROID_HOME" >> ~/.bashrc
    echo "export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin" >> ~/.bashrc
    echo "export PATH=\$PATH:\$ANDROID_HOME/platform-tools" >> ~/.bashrc
    echo "export PATH=\$PATH:\$ANDROID_HOME/emulator" >> ~/.bashrc
    
    # 立即生效
    export ANDROID_HOME="$ANDROID_HOME"
    export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
    export PATH="$PATH:$ANDROID_HOME/platform-tools"
    export PATH="$PATH:$ANDROID_HOME/emulator"
    
    # 安装必要的 SDK 组件
    echo "安装 Android SDK 组件..."
    cd "$ANDROID_HOME"
    
    # 接受许可证
    yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses > /dev/null 2>&1
    
    # 安装平台工具和构建工具
    "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" \
        "platform-tools" \
        "platforms;android-33" \
        "build-tools;33.0.0" \
        "emulator" \
        "system-images;android-33;google_apis;x86_64"
    
    echo -e "${GREEN}✓ Android SDK 安装完成${NC}"
    echo "  位置: $ANDROID_HOME"
    echo ""
}

# 2. 安装 Google Chrome
install_chrome() {
    echo -e "${YELLOW}=== 安装 Google Chrome ===${NC}"
    echo ""
    
    # 检查是否已安装
    if command -v google-chrome-stable &> /dev/null; then
        echo -e "${GREEN}✓ Chrome 已安装${NC}"
        return
    fi
    
    echo "下载 Chrome..."
    cd /tmp
    wget -q -O google-chrome-stable.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    
    echo "安装 Chrome..."
    sudo apt update
    sudo apt install -y ./google-chrome-stable.deb
    rm google-chrome-stable.deb
    
    echo -e "${GREEN}✓ Chrome 安装完成${NC}"
    echo ""
}

# 3. 修复 Android 许可证
fix_android_licenses() {
    echo -e "${YELLOW}=== 接受 Android 许可证 ===${NC}"
    echo ""
    
    flutter doctor --android-licenses
    
    echo -e "${GREEN}✓ 许可证配置完成${NC}"
    echo ""
}

# 4. 验证安装
verify_installation() {
    echo -e "${YELLOW}=== 验证安装 ===${NC}"
    echo ""
    
    flutter doctor -v
    
    echo ""
}

# 主函数
main() {
    # 询问用户要安装什么
    echo "检测到以下组件缺失："
    echo "1. Android SDK"
    echo "2. Google Chrome"
    echo ""
    
    read -p "是否安装 Android SDK? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_android_sdk
        fix_android_licenses
    fi
    
    read -p "是否安装 Google Chrome? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        install_chrome
    fi
    
    # 验证安装
    verify_installation
    
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}         环境修复完成！${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo "重要提示："
    echo "1. 请运行以下命令使环境变量生效："
    echo -e "   ${BLUE}source ~/.bashrc${NC}"
    echo ""
    echo "2. 运行 Jive 项目："
    echo -e "   ${BLUE}cd ~/SynologyDrive/github/jive-flutter-rust/jive-flutter${NC}"
    echo -e "   ${BLUE}flutter pub get${NC}"
    echo -e "   ${BLUE}flutter run -d chrome${NC}  # 在 Chrome 中运行"
    echo -e "   ${BLUE}flutter run -d linux${NC}   # 作为 Linux 桌面应用运行"
    echo ""
}

# 运行主函数
main