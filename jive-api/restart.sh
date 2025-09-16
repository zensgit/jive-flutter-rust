#!/bin/bash

# Jive Money API 重启脚本

echo "🔄 正在重启 Jive Money API..."

# 1. 查找并终止现有进程
echo "📍 查找现有进程..."
PIDS=$(ps aux | grep "jive-api" | grep -v grep | awk '{print $2}')

if [ -z "$PIDS" ]; then
    echo "ℹ️  没有找到运行中的 jive-api 进程"
else
    echo "🛑 终止进程: $PIDS"
    echo $PIDS | xargs kill -9 2>/dev/null
    sleep 1
fi

# 2. 设置环境变量
export RUST_LOG=info
export API_PORT=8012
export DATABASE_URL="postgresql://huazhou:@localhost:5432/jive_money"

echo "📦 配置信息："
echo "   - 端口: $API_PORT"
echo "   - 日志级别: $RUST_LOG"
echo "   - 数据库: jive_money"
echo ""

# 3. 重新编译并启动
echo "🔨 编译并启动..."
cargo run --bin jive-api &

# 4. 等待启动
echo "⏳ 等待服务启动..."
sleep 3

# 5. 检查服务状态
echo "🔍 检查服务状态..."
if curl -s http://localhost:8012/health > /dev/null 2>&1; then
    echo "✅ API 服务已成功启动！"
    echo "📍 访问地址: http://localhost:8012"
    echo "🔌 WebSocket: ws://localhost:8012/ws"
    echo ""
    echo "📊 健康检查:"
    curl -s http://localhost:8012/health | python3 -m json.tool 2>/dev/null || curl http://localhost:8012/health
else
    echo "⚠️  服务可能还在启动中，请稍后再试"
    echo "💡 使用以下命令查看日志："
    echo "   ps aux | grep jive-api"
fi