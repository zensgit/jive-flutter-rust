#!/bin/bash

# 修复 Flutter 开发版本图标显示问题
# 该脚本将构建资源文件并复制到开发目录

echo "🔧 修复 Flutter 开发版本图标..."

# 确保在 Flutter 项目目录
cd "$(dirname "$0")"

# 1. 构建 Web 版本以生成资源文件
echo "📦 构建资源文件..."
flutter build web --no-tree-shake-icons --quiet

# 2. 创建 web/assets 目录
echo "📁 创建资源目录..."
mkdir -p web/assets

# 3. 复制必要的资源文件
echo "📋 复制资源文件..."
cp build/web/assets/FontManifest.json web/assets/
cp build/web/assets/AssetManifest.json web/assets/
cp build/web/assets/AssetManifest.bin web/assets/
cp build/web/assets/AssetManifest.bin.json web/assets/
cp -r build/web/assets/fonts web/assets/
cp -r build/web/assets/packages web/assets/ 2>/dev/null || true

# 4. 复制图标字体
echo "🎨 复制图标字体..."
if [ -d "build/web/canvaskit" ]; then
    cp -r build/web/canvaskit web/ 2>/dev/null || true
fi

echo "✅ 修复完成！"
echo ""
echo "现在可以运行开发服务器："
echo "  flutter run -d web-server --web-port 3021"
echo ""
echo "或刷新浏览器："
echo "  http://localhost:3021"