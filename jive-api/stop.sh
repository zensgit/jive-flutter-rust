#!/bin/bash

# 停止 Jive Money API

echo "🛑 停止 Jive Money API..."

PIDS=$(ps aux | grep "target/debug/jive-api" | grep -v grep | awk '{print $2}')

if [ -z "$PIDS" ]; then
    echo "ℹ️  没有找到运行中的进程"
else
    echo "终止进程: $PIDS"
    echo $PIDS | xargs kill -9 2>/dev/null
    echo "✅ 已停止"
fi
