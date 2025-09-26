#!/bin/bash

# 修复 Java 版本并配置 Android SDK
set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}    修复 Java 版本并配置 Android SDK${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# 1. 安装 Java 17
echo -e "${YELLOW}=== 安装 Java 17 ===${NC}"
sudo apt update
sudo apt install -y openjdk-17-jdk

# 设置 Java 17 为默认版本
sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java
sudo update-alternatives --set javac /usr/lib/jvm/java-17-openjdk-amd64/bin/javac

echo -e "${GREEN}✓ Java 17 安装完成${NC}"
java -version
echo ""

# 2. 配置 JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export PATH=$JAVA_HOME/bin:$PATH

# 添加到 bashrc
if ! grep -q "JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# Java 17" >> ~/.bashrc
    echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" >> ~/.bashrc
    echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
fi

# 3. 配置 Android SDK 环境变量
export ANDROID_HOME=/home/zou/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# 4. 安装 Android SDK 组件
echo -e "${YELLOW}=== 安装 Android SDK 组件 ===${NC}"

# 接受许可证
echo "接受 Android 许可证..."
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses

# 安装基础组件
echo "安装平台工具..."
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platform-tools"

echo "安装构建工具..."
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "build-tools;34.0.0"

echo "安装 Android 平台..."
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager "platforms;android-34"

echo -e "${GREEN}✓ Android SDK 组件安装完成${NC}"
echo ""

# 5. 验证安装
echo -e "${YELLOW}=== 验证安装 ===${NC}"
export PATH=$PATH:/home/zou/flutter/bin
flutter doctor

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}         配置完成！${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo "请运行以下命令使环境变量生效："
echo -e "   ${BLUE}source ~/.bashrc${NC}"
echo ""
echo "然后运行："
echo -e "   ${BLUE}flutter doctor${NC}"