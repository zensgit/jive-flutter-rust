#!/bin/bash

# 环境切换脚本 - 根据系统自动配置端口

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - 使用本地API
    echo "🍎 配置macOS本地开发环境..."
    API_PORT=8012
    DB_PORT=5432
    REDIS_PORT=6379

    # 更新Flutter配置
    sed -i '' "s|http://localhost:[0-9]*|http://localhost:$API_PORT|g" jive-flutter/lib/core/config/api_config.dart

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux/Ubuntu - 使用Docker
    echo "🐧 配置Ubuntu Docker环境..."
    API_PORT=18012
    DB_PORT=15432
    REDIS_PORT=16379

    # 更新Flutter配置
    sed -i "s|http://localhost:[0-9]*|http://localhost:$API_PORT|g" jive-flutter/lib/core/config/api_config.dart
fi

echo "✅ 环境配置完成："
echo "   API端口: $API_PORT"
echo "   数据库端口: $DB_PORT"
echo "   Redis端口: $REDIS_PORT"