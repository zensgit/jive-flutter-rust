#!/bin/bash

# Flutter PATH 配置脚本

echo "================================================"
echo "         配置 Flutter 环境变量"
echo "================================================"
echo ""

# 1. 添加 Flutter 到 PATH
if ! grep -q "flutter/bin" ~/.bashrc; then
    echo "添加 Flutter 到 PATH..."
    echo '' >> ~/.bashrc
    echo '# Flutter' >> ~/.bashrc
    echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
    echo "✓ Flutter PATH 已添加到 ~/.bashrc"
else
    echo "✓ Flutter PATH 已存在"
fi

# 2. 配置 Android SDK 路径
if [ -d "$HOME/Android/Sdk" ]; then
    echo ""
    echo "配置 Android SDK 路径..."
    flutter config --android-sdk $HOME/Android/Sdk
    
    # 添加 Android 环境变量
    if ! grep -q "ANDROID_HOME" ~/.bashrc; then
        echo '' >> ~/.bashrc
        echo '# Android SDK' >> ~/.bashrc
        echo 'export ANDROID_HOME=$HOME/Android/Sdk' >> ~/.bashrc
        echo 'export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin"' >> ~/.bashrc
        echo 'export PATH="$PATH:$ANDROID_HOME/platform-tools"' >> ~/.bashrc
        echo "✓ Android SDK 环境变量已添加"
    fi
fi

echo ""
echo "================================================"
echo "              配置完成！"
echo "================================================"
echo ""
echo "请运行以下命令使配置生效："
echo ""
echo "    source ~/.bashrc"
echo ""
echo "然后您就可以直接使用："
echo "    flutter doctor"
echo ""
echo "当前 Flutter 状态："
export PATH="$PATH:$HOME/flutter/bin"
flutter doctor