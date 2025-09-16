#!/bin/bash

# Jive Money API 完整版启动脚本
# 包含 WebSocket 和所有功能

# 设置环境变量
export RUST_LOG=info
export API_PORT=8012
export DATABASE_URL="postgresql://huazhou:@localhost:5432/jive_money"

echo "🚀 启动 Jive Money API (完整版)..."
echo "📦 功能："
echo "   ✅ WebSocket 实时通信"
echo "   ✅ 数据库连接"
echo "   ✅ 用户认证"
echo "   ✅ 账本管理"
echo "   ✅ 所有业务 API"
echo ""
echo "📋 配置："
echo "   - 端口: $API_PORT"
echo "   - WebSocket: ws://localhost:$API_PORT/ws"
echo "   - 数据库: jive_money"
echo ""

# 编译并运行主程序（完整版）
cargo run --bin jive-api