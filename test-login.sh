#!/bin/bash

echo "🔐 测试API登录功能..."
echo ""

# 测试用户凭据
declare -A users=(
    ["test@example.com"]="password123"
    ["demo@demo.com"]="demo123"
    ["admin@example.com"]="admin123"
)

echo "可用的测试账户："
echo "=================="
for email in "${!users[@]}"; do
    password="${users[$email]}"
    echo "📧 邮箱: $email"
    echo "🔑 密码: $password"

    # 测试登录
    echo -n "   测试登录... "
    response=$(curl -s -X POST http://localhost:18012/api/v1/auth/login \
        -H "Content-Type: application/json" \
        -d "{\"email\":\"$email\",\"password\":\"$password\"}" \
        -w "\n%{http_code}")

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [ "$http_code" = "200" ]; then
        echo "✅ 成功!"
        token=$(echo "$body" | grep -o '"token":"[^"]*' | cut -d'"' -f4)
        if [ ! -z "$token" ]; then
            echo "   Token: ${token:0:20}..."
        fi
    else
        echo "❌ 失败 (HTTP $http_code)"
    fi
    echo ""
done

echo "💡 提示："
echo "   - 如果所有登录都失败，可能需要重置密码"
echo "   - 访问 http://localhost:3021 使用上述凭据登录"
echo "   - 或使用注册功能创建新账户"