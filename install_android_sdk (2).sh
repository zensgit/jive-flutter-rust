#!/bin/bash

# Android SDK 完整安装脚本
set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}      Android SDK 完整安装脚本${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 1. 下载并安装 Android 命令行工具
install_android_cmdline_tools() {
    echo -e "${YELLOW}=== 步骤 1: 下载 Android 命令行工具 ===${NC}"
    
    # 设置安装目录
    ANDROID_HOME="$HOME/Android/Sdk"
    
    # 清理旧的安装（如果存在）
    if [ -d "$ANDROID_HOME/cmdline-tools" ]; then
        echo "发现已存在的命令行工具，清理中..."
        rm -rf "$ANDROID_HOME/cmdline-tools"
    fi
    
    # 创建目录
    mkdir -p "$ANDROID_HOME"
    cd "$ANDROID_HOME"
    
    # 下载最新的命令行工具
    echo "下载 Android 命令行工具..."
    wget -q --show-progress https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
    
    # 解压
    echo "解压命令行工具..."
    unzip -q commandlinetools-linux-11076708_latest.zip
    
    # 移动到正确的位置
    mkdir -p cmdline-tools/latest
    mv cmdline-tools/* cmdline-tools/latest/ 2>/dev/null || true
    
    # 清理下载文件
    rm commandlinetools-linux-11076708_latest.zip
    
    echo -e "${GREEN}✓ 命令行工具安装完成${NC}"
    echo ""
}

# 2. 配置环境变量
setup_environment() {
    echo -e "${YELLOW}=== 步骤 2: 配置环境变量 ===${NC}"
    
    ANDROID_HOME="$HOME/Android/Sdk"
    
    # 检测 shell 类型
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_RC="$HOME/.bashrc"
    else
        SHELL_RC="$HOME/.profile"
    fi
    
    # 备份配置文件
    cp "$SHELL_RC" "$SHELL_RC.backup.$(date +%Y%m%d_%H%M%S)"
    
    # 移除旧的 Android 配置（如果存在）
    sed -i '/# Android SDK/d' "$SHELL_RC"
    sed -i '/ANDROID_HOME/d' "$SHELL_RC"
    sed -i '/Android\/Sdk/d' "$SHELL_RC"
    
    # 添加新的配置
    echo "" >> "$SHELL_RC"
    echo "# Android SDK" >> "$SHELL_RC"
    echo "export ANDROID_HOME=$ANDROID_HOME" >> "$SHELL_RC"
    echo "export ANDROID_SDK_ROOT=$ANDROID_HOME" >> "$SHELL_RC"
    echo 'export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin' >> "$SHELL_RC"
    echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> "$SHELL_RC"
    echo 'export PATH=$PATH:$ANDROID_HOME/emulator' >> "$SHELL_RC"
    echo 'export PATH=$PATH:$ANDROID_HOME/tools' >> "$SHELL_RC"
    echo 'export PATH=$PATH:$ANDROID_HOME/tools/bin' >> "$SHELL_RC"
    
    # 立即生效
    export ANDROID_HOME="$ANDROID_HOME"
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"
    export PATH="$PATH:$ANDROID_HOME/platform-tools"
    export PATH="$PATH:$ANDROID_HOME/emulator"
    export PATH="$PATH:$ANDROID_HOME/tools"
    export PATH="$PATH:$ANDROID_HOME/tools/bin"
    
    echo -e "${GREEN}✓ 环境变量配置完成${NC}"
    echo "  配置文件: $SHELL_RC"
    echo ""
}

# 3. 安装必要的 SDK 组件
install_sdk_components() {
    echo -e "${YELLOW}=== 步骤 3: 安装 SDK 组件 ===${NC}"
    
    SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
    
    # 更新 SDK Manager
    echo "更新 SDK Manager..."
    $SDKMANAGER --update
    
    # 安装平台工具
    echo ""
    echo "安装平台工具..."
    $SDKMANAGER "platform-tools"
    
    # 安装构建工具
    echo ""
    echo "安装构建工具..."
    $SDKMANAGER "build-tools;34.0.0"
    $SDKMANAGER "build-tools;33.0.2"
    
    # 安装 Android 平台
    echo ""
    echo "安装 Android 平台..."
    $SDKMANAGER "platforms;android-34"
    $SDKMANAGER "platforms;android-33"
    
    # 安装源代码（用于调试）
    echo ""
    echo "安装源代码..."
    $SDKMANAGER "sources;android-34"
    
    # 安装 CMake 和 NDK（用于原生开发）
    echo ""
    echo "安装 CMake 和 NDK..."
    $SDKMANAGER "cmake;3.22.1"
    $SDKMANAGER "ndk;25.2.9519653"
    
    echo -e "${GREEN}✓ SDK 组件安装完成${NC}"
    echo ""
}

# 4. 安装模拟器（可选）
install_emulator() {
    echo -e "${YELLOW}=== 步骤 4: 安装 Android 模拟器（可选）===${NC}"
    echo ""
    
    read -p "是否安装 Android 模拟器？这将需要额外的磁盘空间 (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
        
        # 安装模拟器
        echo "安装模拟器..."
        $SDKMANAGER "emulator"
        
        # 安装系统镜像
        echo ""
        echo "安装系统镜像 (x86_64)..."
        $SDKMANAGER "system-images;android-34;google_apis;x86_64"
        
        # 创建 AVD
        echo ""
        echo "创建虚拟设备..."
        echo "no" | $ANDROID_HOME/cmdline-tools/latest/bin/avdmanager create avd \
            -n "Pixel_7_API_34" \
            -k "system-images;android-34;google_apis;x86_64" \
            -d "pixel_7" \
            --force
        
        echo -e "${GREEN}✓ 模拟器安装完成${NC}"
        echo "  虚拟设备名称: Pixel_7_API_34"
        echo "  启动命令: emulator -avd Pixel_7_API_34"
    else
        echo "跳过模拟器安装"
    fi
    
    echo ""
}

# 5. 接受所有许可证
accept_licenses() {
    echo -e "${YELLOW}=== 步骤 5: 接受 Android 许可证 ===${NC}"
    
    SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
    
    # 自动接受所有许可证
    yes | $SDKMANAGER --licenses
    
    echo -e "${GREEN}✓ 所有许可证已接受${NC}"
    echo ""
}

# 6. 验证安装
verify_installation() {
    echo -e "${YELLOW}=== 步骤 6: 验证安装 ===${NC}"
    echo ""
    
    # 检查 ANDROID_HOME
    echo "ANDROID_HOME: $ANDROID_HOME"
    
    # 检查 sdkmanager
    if command -v sdkmanager &> /dev/null; then
        echo -e "${GREEN}✓ sdkmanager 可用${NC}"
    else
        echo -e "${YELLOW}⚠ sdkmanager 不在 PATH 中${NC}"
    fi
    
    # 检查 adb
    if [ -f "$ANDROID_HOME/platform-tools/adb" ]; then
        echo -e "${GREEN}✓ adb 已安装${NC}"
        $ANDROID_HOME/platform-tools/adb version
    else
        echo -e "${RED}✗ adb 未找到${NC}"
    fi
    
    # 运行 flutter doctor
    echo ""
    echo "运行 Flutter Doctor..."
    export PATH="$PATH:$HOME/flutter/bin"
    flutter doctor
    
    echo ""
}

# 主函数
main() {
    echo "此脚本将安装 Android SDK 及相关组件"
    echo "预计需要下载约 1-2 GB 的数据"
    echo ""
    read -p "是否继续？(y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "安装已取消"
        exit 0
    fi
    
    echo ""
    
    # 执行安装步骤
    install_android_cmdline_tools
    setup_environment
    install_sdk_components
    install_emulator
    accept_licenses
    verify_installation
    
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}       Android SDK 安装完成！${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo "重要提示："
    echo ""
    echo "1. 请运行以下命令使环境变量生效："
    echo -e "   ${BLUE}source ~/.bashrc${NC} (或 source ~/.zshrc)"
    echo ""
    echo "2. 验证安装："
    echo -e "   ${BLUE}flutter doctor${NC}"
    echo ""
    echo "3. 创建 Android 项目："
    echo -e "   ${BLUE}flutter create --platforms android my_app${NC}"
    echo ""
    echo "4. 运行 Android 应用："
    echo -e "   ${BLUE}flutter run -d android${NC}  # 需要连接设备或运行模拟器"
    echo ""
    echo "5. 启动模拟器（如果已安装）："
    echo -e "   ${BLUE}emulator -avd Pixel_7_API_34${NC}"
    echo ""
}

# 运行主函数
main