#!/bin/bash

# Test Currency API Endpoints
API_URL="http://localhost:8012/api/v1"

echo "Testing Currency API Endpoints..."
echo "================================="

# 1. Get supported currencies (no auth required)
echo -e "\n1. Getting supported currencies..."
curl -s -X GET "$API_URL/currencies" | jq '.'

# 2. Get popular exchange pairs
echo -e "\n2. Getting popular exchange pairs..."
curl -s -X GET "$API_URL/currencies/popular-pairs" | jq '.'

# 3. Get exchange rate
echo -e "\n3. Getting exchange rate (CNY to USD)..."
curl -s -X GET "$API_URL/currencies/rate?from=CNY&to=USD" | jq '.'

# 4. Convert amount
echo -e "\n4. Converting 100 CNY to USD..."
curl -s -X POST "$API_URL/currencies/convert" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 100,
    "from_currency": "CNY",
    "to_currency": "USD"
  }' | jq '.'

# 5. Get batch exchange rates
echo -e "\n5. Getting batch exchange rates..."
curl -s -X POST "$API_URL/currencies/rates" \
  -H "Content-Type: application/json" \
  -d '{
    "base_currency": "CNY",
    "target_currencies": ["USD", "EUR", "JPY", "HKD"]
  }' | jq '.'

echo -e "\n================================="
echo "Currency API test complete!"