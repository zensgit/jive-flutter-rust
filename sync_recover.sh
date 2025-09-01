#!/bin/bash

# OneDrive同步后的环境恢复脚本

echo "🔄 OneDrive同步环境恢复工具"
echo "================================"

# 检测操作系统
if [[ "$OSTYPE" == "darwin"* ]]; then
    SYSTEM="MacBook"
    echo "📍 检测到系统: MacBook"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    SYSTEM="Ubuntu"
    echo "📍 检测到系统: Ubuntu"
else
    echo "❌ 不支持的操作系统"
    exit 1
fi

# 等待同步完成
echo ""
echo "⏳ 请确保OneDrive同步已完成..."
echo "   按Enter继续，或Ctrl+C取消"
read

# 更新会话状态
echo ""
echo "📝 更新Claude会话状态..."
DATE=$(date '+%Y-%m-%d %H:%M')
sed -i.bak "s/最后同步时间.*/最后同步时间\": $DATE/" CLAUDE_SESSION.md
sed -i.bak "s/最后工作系统.*/最后工作系统\": $SYSTEM/" CLAUDE_SESSION.md

# 清理Flutter环境
echo ""
echo "🧹 清理Flutter缓存..."
cd jive-flutter
flutter clean

# 重建Flutter依赖
echo ""
echo "📦 重建Flutter依赖..."
flutter pub get

# 处理iOS依赖（仅MacBook）
if [[ "$SYSTEM" == "MacBook" ]] && [ -d "ios" ]; then
    echo ""
    echo "🍎 更新iOS依赖..."
    cd ios
    pod install 2>/dev/null || echo "   提示: 如需iOS开发，请安装CocoaPods"
    cd ..
fi

# 重建Rust项目
echo ""
echo "🦀 重建Rust项目..."
cd ../jive-core
cargo clean
cargo build --release

# 返回项目根目录
cd ..

# 显示状态
echo ""
echo "✅ 环境恢复完成！"
echo ""
echo "📋 当前状态："
echo "   - 系统: $SYSTEM"
echo "   - 时间: $DATE"
echo "   - Flutter依赖: 已更新"
echo "   - Rust构建: 已完成"
echo ""
echo "💡 提示："
echo "   1. 现在可以在Claude中使用 /resume 恢复会话"
echo "   2. 开始工作前检查 CLAUDE_SESSION.md 了解最新进度"
echo "   3. 完成工作后运行此脚本更新状态"
echo ""