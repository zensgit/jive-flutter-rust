#!/bin/bash

# API测试脚本
# 使用方法: ./test_api.sh

API_URL="http://localhost:8012/api/v1"
LEDGER_ID="550e8400-e29b-41d4-a716-446655440001"
ACCOUNT_ID="660e8400-e29b-41d4-a716-446655440001"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 测试函数
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo -e "${YELLOW}Testing: $description${NC}"
    echo "Method: $method"
    echo "Endpoint: $endpoint"
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "$API_URL$endpoint")
    elif [ "$method" = "POST" ]; then
        response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    elif [ "$method" = "PUT" ]; then
        response=$(curl -s -w "\n%{http_code}" -X PUT "$API_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    elif [ "$method" = "DELETE" ]; then
        response=$(curl -s -w "\n%{http_code}" -X DELETE "$API_URL$endpoint")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "${GREEN}✓ Success (HTTP $http_code)${NC}"
        if [ -n "$body" ]; then
            echo "$body" | jq '.' 2>/dev/null || echo "$body"
        fi
    else
        echo -e "${RED}✗ Failed (HTTP $http_code)${NC}"
        echo "$body"
    fi
    echo "---"
}

echo "================================"
echo "Jive API 测试脚本"
echo "================================"
echo ""

# 1. 健康检查
test_endpoint "GET" "/../../health" "" "健康检查"

# 2. 账户管理测试
echo -e "\n${YELLOW}=== 账户管理API测试 ===${NC}\n"

test_endpoint "GET" "/accounts?ledger_id=$LEDGER_ID" "" "获取账户列表"

test_endpoint "POST" "/accounts" '{
    "ledger_id": "'$LEDGER_ID'",
    "name": "测试账户",
    "account_type": "savings",
    "currency": "CNY",
    "initial_balance": 1000.00
}' "创建新账户"

test_endpoint "GET" "/accounts/statistics?ledger_id=$LEDGER_ID" "" "获取账户统计"

# 3. 交易管理测试
echo -e "\n${YELLOW}=== 交易管理API测试 ===${NC}\n"

test_endpoint "GET" "/transactions?ledger_id=$LEDGER_ID&page=1&per_page=5" "" "获取交易列表"

test_endpoint "POST" "/transactions" '{
    "account_id": "'$ACCOUNT_ID'",
    "ledger_id": "'$LEDGER_ID'",
    "amount": 88.88,
    "transaction_type": "expense",
    "transaction_date": "'$(date +%Y-%m-%d)'",
    "payee_name": "测试商户",
    "description": "API测试交易"
}' "创建新交易"

test_endpoint "GET" "/transactions/statistics?ledger_id=$LEDGER_ID" "" "获取交易统计"

# 4. 收款人管理测试
echo -e "\n${YELLOW}=== 收款人管理API测试 ===${NC}\n"

test_endpoint "GET" "/payees?ledger_id=$LEDGER_ID" "" "获取收款人列表"

test_endpoint "POST" "/payees" '{
    "ledger_id": "'$LEDGER_ID'",
    "name": "测试收款人",
    "is_vendor": true,
    "notes": "通过API创建的测试收款人"
}' "创建新收款人"

test_endpoint "GET" "/payees/suggestions?text=星巴&ledger_id=$LEDGER_ID" "" "获取收款人建议"

test_endpoint "GET" "/payees/statistics?ledger_id=$LEDGER_ID" "" "获取收款人统计"

# 5. 规则引擎测试
echo -e "\n${YELLOW}=== 规则引擎API测试 ===${NC}\n"

test_endpoint "GET" "/rules?ledger_id=$LEDGER_ID" "" "获取规则列表"

test_endpoint "POST" "/rules" '{
    "ledger_id": "'$LEDGER_ID'",
    "name": "测试规则",
    "rule_type": "categorization",
    "conditions": [
        {
            "field": "amount",
            "operator": "greater_than",
            "value": 500
        }
    ],
    "actions": [
        {
            "action_type": "add_tag",
            "target_field": "tags",
            "target_value": "高额消费"
        }
    ],
    "priority": 50,
    "is_active": true
}' "创建新规则"

test_endpoint "POST" "/rules/execute" '{
    "dry_run": true
}' "执行规则（干运行）"

# 6. 批量操作测试
echo -e "\n${YELLOW}=== 批量操作测试 ===${NC}\n"

# 先获取一些交易ID
echo "获取交易ID用于批量操作..."
tx_ids=$(curl -s "$API_URL/transactions?ledger_id=$LEDGER_ID&per_page=2" | jq -r '.[].id' | tr '\n' ',' | sed 's/,$//' | sed 's/,/","/g')

if [ -n "$tx_ids" ]; then
    test_endpoint "POST" "/transactions/bulk" '{
        "transaction_ids": ["'$tx_ids'"],
        "operation": "update_status",
        "status": "reconciled"
    }' "批量更新交易状态"
fi

# 7. 统计汇总
echo -e "\n${YELLOW}=== 统计汇总 ===${NC}\n"

echo "账户统计："
curl -s "$API_URL/accounts/statistics?ledger_id=$LEDGER_ID" | jq '.total_accounts, .net_worth'

echo ""
echo "交易统计："
curl -s "$API_URL/transactions/statistics?ledger_id=$LEDGER_ID" | jq '.total_count, .total_income, .total_expense'

echo ""
echo "收款人统计："
curl -s "$API_URL/payees/statistics?ledger_id=$LEDGER_ID" | jq '.total_payees, .active_payees'

echo ""
echo -e "${GREEN}测试完成！${NC}"
echo "================================"