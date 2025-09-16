#!/bin/bash

# Flutter 开发服务器启动脚本
# 确保在端口 3021 启动

echo "🚀 启动 Flutter 开发服务器..."

# 1. 清理可能存在的进程
echo "🧹 清理旧进程..."
pkill -f "flutter.*3021" 2>/dev/null
sleep 2

# 2. 检查端口是否可用
if lsof -i :3021 > /dev/null 2>&1; then
    echo "⚠️  端口 3021 被占用，尝试清理..."
    lsof -ti :3021 | xargs kill -9 2>/dev/null
    sleep 2
fi

# 3. 确保资源文件存在
if [ ! -f "web/assets/FontManifest.json" ]; then
    echo "📦 修复资源文件..."
    ./fix-dev-icons.sh
fi

# 4. 启动 Flutter
echo "✨ 在端口 3021 启动 Flutter..."
flutter run -d web-server --web-port 3021 --web-hostname localhost

echo "
🎯 Flutter 开发服务器已启动！
📍 访问地址: http://localhost:3021
🔥 支持热重载 (按 r 键)
"