#!/bin/bash
# 跨平台API测试脚本

echo "🧪 测试API连接..."

# API测试
echo -n "API服务: "
if curl -s http://localhost:8012/ > /dev/null; then
    echo "✅ 运行中"
else
    echo "❌ 未响应"
fi

# 数据库测试
echo -n "数据库连接: "
OS=$(uname -s)
if [ "$OS" = "Darwin" ]; then
    DB_PORT=5432
else
    DB_PORT=5433
fi

if PGPASSWORD=postgres psql -h localhost -p $DB_PORT -U postgres -d jive_money -c "SELECT 1" > /dev/null 2>&1; then
    echo "✅ 正常 (端口 $DB_PORT)"
else
    echo "❌ 连接失败"
fi

# Redis测试
echo -n "Redis连接: "
if [ "$OS" = "Darwin" ]; then
    REDIS_PORT=6379
else
    REDIS_PORT=6380
fi

if redis-cli -p $REDIS_PORT ping > /dev/null 2>&1; then
    echo "✅ 正常 (端口 $REDIS_PORT)"
else
    echo "❌ 连接失败"
fi

# 登录测试
echo ""
echo "📝 测试登录功能..."
response=$(curl -s -X POST http://localhost:8012/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"superadmin@jive.com","password":"admin123"}')

if echo "$response" | grep -q "token"; then
    echo "✅ 登录成功"
else
    echo "❌ 登录失败"
    echo "响应: $response"
fi
