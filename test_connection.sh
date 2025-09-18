#!/bin/bash

echo "🔍 测试Jive开发环境连接状态..."
echo ""

# 测试Docker服务
echo "1. Docker服务状态："
echo "   PostgreSQL (15432): $(nc -zv localhost 15432 2>&1 | grep -o 'succeeded' || echo '❌ 未连接')"
echo "   Redis (16379): $(nc -zv localhost 16379 2>&1 | grep -o 'succeeded' || echo '❌ 未连接')"
echo "   API (18012): $(nc -zv localhost 18012 2>&1 | grep -o 'succeeded' || echo '❌ 未连接')"
echo ""

# 测试API健康检查
echo "2. API健康检查："
API_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18012/)
if [ "$API_RESPONSE" = "200" ]; then
    echo "   ✅ API服务正常 (HTTP $API_RESPONSE)"
    curl -s http://localhost:18012/ | python3 -m json.tool 2>/dev/null | head -n 5 || curl -s http://localhost:18012/ | head -n 1
else
    echo "   ❌ API服务异常 (HTTP $API_RESPONSE)"
fi
echo ""

# 测试Flutter Web
echo "3. Flutter Web应用："
WEB_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3021/)
if [ "$WEB_RESPONSE" = "200" ]; then
    echo "   ✅ Flutter Web正常运行 (HTTP $WEB_RESPONSE)"
    echo "   访问: http://localhost:3021"
else
    echo "   ❌ Flutter Web未运行 (HTTP $WEB_RESPONSE)"
fi
echo ""

echo "✨ 开发环境准备就绪！"
echo "   - API文档: http://localhost:18012/docs"
echo "   - 数据库管理: http://localhost:19080"
echo "   - Flutter应用: http://localhost:3021"