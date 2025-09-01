#!/bin/bash

# Android SDK 设置脚本
set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}      Android SDK 配置脚本${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 设置环境变量
export ANDROID_HOME=/home/zou/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator

echo -e "${YELLOW}安装 Android SDK 基础组件...${NC}"
echo ""

# 先更新 SDK Manager
echo "更新 SDK Manager..."
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --update

# 安装平台工具
echo ""
echo "安装平台工具..."
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platform-tools"

# 安装构建工具
echo ""
echo "安装构建工具..."
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "build-tools;34.0.0"

# 安装 Android 平台
echo ""
echo "安装 Android 平台 (API 34)..."
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platforms;android-34"

# 安装系统镜像（可选，用于模拟器）
echo ""
read -p "是否安装 Android 模拟器系统镜像？(y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "安装模拟器和系统镜像..."
    $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "emulator"
    $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "system-images;android-34;google_apis;x86_64"
fi

echo ""
echo -e "${GREEN}✓ Android SDK 组件安装完成！${NC}"
echo ""

# 接受所有许可证
echo -e "${YELLOW}接受 Android 许可证...${NC}"
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}         Android SDK 配置完成！${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# 验证安装
echo "验证安装..."
flutter doctor

echo ""
echo -e "${YELLOW}提示：${NC}"
echo "1. 如果 flutter doctor 仍显示问题，请运行："
echo -e "   ${BLUE}source ~/.bashrc${NC}"
echo ""
echo "2. 现在可以运行 Jive 项目："
echo -e "   ${BLUE}cd ~/SynologyDrive/github/jive-flutter-rust/jive-flutter${NC}"
echo -e "   ${BLUE}flutter run -d chrome${NC}  # Web 版本"
echo -e "   ${BLUE}flutter run -d linux${NC}   # Linux 桌面版本"