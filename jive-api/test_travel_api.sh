#!/bin/bash

# Travel API 完整测试脚本
# 测试所有 CRUD 操作

API_BASE="http://localhost:18012"
EMAIL="testuser@jive.com"
PASSWORD="test123456"

echo "========================================="
echo "Travel API 完整功能测试"
echo "========================================="
echo ""

# 1. 登录获取 Token
echo "1. 登录获取 JWT Token..."
LOGIN_RESPONSE=$(curl -s -X POST "$API_BASE/api/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}")

TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.token')

if [ "$TOKEN" = "null" ] || [ -z "$TOKEN" ]; then
  echo "❌ 登录失败"
  echo "$LOGIN_RESPONSE" | jq .
  exit 1
fi

echo "✅ 登录成功"
echo "Token: ${TOKEN:0:50}..."
echo ""

# 2. 创建旅行事件
echo "2. 创建旅行事件..."
CREATE_RESPONSE=$(curl -s -X POST "$API_BASE/api/v1/travel/events" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "trip_name": "东京之旅",
    "start_date": "2025-12-01",
    "end_date": "2025-12-07",
    "total_budget": 50000,
    "budget_currency_code": "JPY",
    "home_currency_code": "CNY",
    "settings": {
      "auto_tag": true,
      "notify_budget": true
    }
  }')

echo "$CREATE_RESPONSE" | jq .

# 提取旅行事件 ID
TRAVEL_ID=$(echo "$CREATE_RESPONSE" | jq -r '.id // empty')

if [ -z "$TRAVEL_ID" ]; then
  echo "⚠️  创建旅行事件失败或返回格式不同"
  echo "Response: $CREATE_RESPONSE"
else
  echo "✅ 创建成功，Travel ID: $TRAVEL_ID"
fi
echo ""

# 3. 获取旅行事件列表
echo "3. 获取旅行事件列表..."
LIST_RESPONSE=$(curl -s -X GET "$API_BASE/api/v1/travel/events" \
  -H "Authorization: Bearer $TOKEN")

echo "$LIST_RESPONSE" | jq .
EVENT_COUNT=$(echo "$LIST_RESPONSE" | jq 'length')
echo "✅ 获取成功，共 $EVENT_COUNT 个旅行事件"
echo ""

# 如果创建成功，继续测试其他操作
if [ ! -z "$TRAVEL_ID" ]; then
  # 4. 获取单个旅行事件详情
  echo "4. 获取旅行事件详情..."
  DETAIL_RESPONSE=$(curl -s -X GET "$API_BASE/api/v1/travel/events/$TRAVEL_ID" \
    -H "Authorization: Bearer $TOKEN")

  echo "$DETAIL_RESPONSE" | jq .
  echo "✅ 获取详情成功"
  echo ""

  # 5. 更新旅行事件
  echo "5. 更新旅行事件..."
  UPDATE_RESPONSE=$(curl -s -X PUT "$API_BASE/api/v1/travel/events/$TRAVEL_ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "trip_name": "东京之旅 (已更新)",
      "end_date": "2025-12-10",
      "total_budget": 60000
    }')

  echo "$UPDATE_RESPONSE" | jq .
  echo "✅ 更新成功"
  echo ""

  # 6. 获取旅行统计
  echo "6. 获取旅行统计..."
  STATS_RESPONSE=$(curl -s -X GET "$API_BASE/api/v1/travel/events/$TRAVEL_ID/statistics" \
    -H "Authorization: Bearer $TOKEN")

  echo "$STATS_RESPONSE" | jq .
  echo "✅ 获取统计成功"
  echo ""

  # 7. 删除旅行事件（可选，注释掉以保留测试数据）
  # echo "7. 删除旅行事件..."
  # DELETE_RESPONSE=$(curl -s -X DELETE "$API_BASE/api/v1/travel/events/$TRAVEL_ID" \
  #   -H "Authorization: Bearer $TOKEN")
  # echo "✅ 删除成功"
  # echo ""
fi

echo "========================================="
echo "测试完成！"
echo "========================================="
