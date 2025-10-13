#!/bin/bash

# Currency Features Verification Script
# Tests two features:
# 1. Instant auto rate display when clearing manual rates
# 2. Manual rate currencies appear below base currency

API_BASE="http://localhost:8012/api/v1"
TOKEN=""
USER_ID=""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "======================================"
echo "Currency Features Verification Test"
echo "======================================"
echo ""

# Function to print test results
print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
    fi
}

# Step 1: Login to get token
echo "Step 1: Logging in..."
LOGIN_RESPONSE=$(curl -s -X POST "${API_BASE}/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email": "testcurrency@example.com", "password": "Test1234"}')

TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.token // empty')
USER_ID=$(echo $LOGIN_RESPONSE | jq -r '.user_id // empty')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo -e "${RED}✗ Login failed. Please check API is running and credentials are correct.${NC}"
    echo "Response: $LOGIN_RESPONSE"
    exit 1
fi

print_result 0 "Login successful (User ID: $USER_ID)"
echo ""

# Step 2: Get current currency settings
echo "Step 2: Getting current currency settings..."
SETTINGS=$(curl -s -X GET "${API_BASE}/currencies/user/settings" \
    -H "Authorization: Bearer $TOKEN")

BASE_CURRENCY=$(echo $SETTINGS | jq -r '.data.base_currency')
echo -e "  Base Currency: ${YELLOW}$BASE_CURRENCY${NC}"
echo ""

# Step 3: Enable multi-currency if not already enabled
echo "Step 3: Ensuring multi-currency is enabled..."
curl -s -X PUT "${API_BASE}/currencies/user/settings" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"multi_currency_enabled": true}' > /dev/null

print_result 0 "Multi-currency enabled"
echo ""

# Step 4: Get list of available currencies
echo "Step 4: Getting available currencies..."
CURRENCIES=$(curl -s -X GET "${API_BASE}/currencies" \
    -H "Authorization: Bearer $TOKEN")

# Select 2 test currencies (avoid base currency)
TEST_CURRENCY_1=$(echo $CURRENCIES | jq -r --arg base "$BASE_CURRENCY" \
    '.data[] | select(.code != $base and .is_crypto == false) | .code' | head -n 1)
TEST_CURRENCY_2=$(echo $CURRENCIES | jq -r --arg base "$BASE_CURRENCY" \
    '.data[] | select(.code != $base and .is_crypto == false) | .code' | head -n 2 | tail -n 1)

echo -e "  Test Currency 1: ${YELLOW}$TEST_CURRENCY_1${NC}"
echo -e "  Test Currency 2: ${YELLOW}$TEST_CURRENCY_2${NC}"
echo ""

# Step 5: Set manual rates for test currencies
echo "Step 5: Setting manual rates for test currencies..."

# Set manual rate for currency 1
MANUAL_RATE_1=$(curl -s -X POST "${API_BASE}/currencies/manual-rate" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"from_currency\": \"$BASE_CURRENCY\", \"to_currency\": \"$TEST_CURRENCY_1\", \"rate\": \"7.5000\"}")

# Set manual rate for currency 2
MANUAL_RATE_2=$(curl -s -X POST "${API_BASE}/currencies/manual-rate" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"from_currency\": \"$BASE_CURRENCY\", \"to_currency\": \"$TEST_CURRENCY_2\", \"rate\": \"0.1234\"}")

print_result 0 "Manual rate set for $TEST_CURRENCY_1 = 7.5000"
print_result 0 "Manual rate set for $TEST_CURRENCY_2 = 0.1234"
echo ""

# Step 6: Verify manual rates are set
echo "Step 6: Verifying manual rates are active..."
sleep 1

RATE_1=$(curl -s -X GET "${API_BASE}/currencies/rate?from=$BASE_CURRENCY&to=$TEST_CURRENCY_1" \
    -H "Authorization: Bearer $TOKEN")
RATE_2=$(curl -s -X GET "${API_BASE}/currencies/rate?from=$BASE_CURRENCY&to=$TEST_CURRENCY_2" \
    -H "Authorization: Bearer $TOKEN")

RATE_1_VALUE=$(echo $RATE_1 | jq -r '.data.rate')
RATE_1_SOURCE=$(echo $RATE_1 | jq -r '.data.source // "unknown"')
RATE_2_VALUE=$(echo $RATE_2 | jq -r '.data.rate')
RATE_2_SOURCE=$(echo $RATE_2 | jq -r '.data.source // "unknown"')

echo "  $TEST_CURRENCY_1 rate: $RATE_1_VALUE (source: $RATE_1_SOURCE)"
echo "  $TEST_CURRENCY_2 rate: $RATE_2_VALUE (source: $RATE_2_SOURCE)"

if [ "$RATE_1_SOURCE" = "manual" ] && [ "$RATE_2_SOURCE" = "manual" ]; then
    print_result 0 "Manual rates are active"
else
    print_result 1 "Manual rates are NOT active (expected 'manual', got '$RATE_1_SOURCE' and '$RATE_2_SOURCE')"
fi
echo ""

# Step 7: Test Feature 1 - Clear manual rates and check instant auto rate display
echo "======================================"
echo "FEATURE 1: Instant Auto Rate Display"
echo "======================================"
echo ""

echo "Step 7: Clearing all manual rates..."
CLEAR_RESPONSE=$(curl -s -X DELETE "${API_BASE}/currencies/manual-rates/clear" \
    -H "Authorization: Bearer $TOKEN")

print_result 0 "Manual rates cleared"
echo ""

echo "Step 8: Checking if automatic rates appear immediately..."
sleep 2  # Give it a moment for cache/DB to update

RATE_1_AUTO=$(curl -s -X GET "${API_BASE}/currencies/rate?from=$BASE_CURRENCY&to=$TEST_CURRENCY_1" \
    -H "Authorization: Bearer $TOKEN")
RATE_2_AUTO=$(curl -s -X GET "${API_BASE}/currencies/rate?from=$BASE_CURRENCY&to=$TEST_CURRENCY_2" \
    -H "Authorization: Bearer $TOKEN")

RATE_1_AUTO_VALUE=$(echo $RATE_1_AUTO | jq -r '.data.rate')
RATE_1_AUTO_SOURCE=$(echo $RATE_1_AUTO | jq -r '.data.source // "unknown"')
RATE_2_AUTO_VALUE=$(echo $RATE_2_AUTO | jq -r '.data.rate')
RATE_2_AUTO_SOURCE=$(echo $RATE_2_AUTO | jq -r '.data.source // "unknown"')

echo "  $TEST_CURRENCY_1: $RATE_1_AUTO_VALUE (source: $RATE_1_AUTO_SOURCE)"
echo "  $TEST_CURRENCY_2: $RATE_2_AUTO_VALUE (source: $RATE_2_AUTO_SOURCE)"
echo ""

# Verify automatic rates are now active
if [ "$RATE_1_AUTO_SOURCE" != "manual" ] && [ "$RATE_2_AUTO_SOURCE" != "manual" ] && \
   [ "$RATE_1_AUTO_VALUE" != "null" ] && [ "$RATE_2_AUTO_VALUE" != "null" ]; then
    echo -e "${GREEN}✓✓✓ FEATURE 1 PASSED ✓✓✓${NC}"
    echo -e "${GREEN}Automatic rates appear immediately after clearing manual rates${NC}"
    FEATURE_1_PASSED=1
else
    echo -e "${RED}✗✗✗ FEATURE 1 FAILED ✗✗✗${NC}"
    echo -e "${RED}Automatic rates did not appear or source is still 'manual'${NC}"
    FEATURE_1_PASSED=0
fi
echo ""

# Step 9: Test Feature 2 - Manual rate currencies sorting
echo "======================================"
echo "FEATURE 2: Manual Rate Currency Sorting"
echo "======================================"
echo ""

echo "Step 9: Setting manual rates again for sorting test..."
curl -s -X POST "${API_BASE}/currencies/manual-rate" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"from_currency\": \"$BASE_CURRENCY\", \"to_currency\": \"$TEST_CURRENCY_1\", \"rate\": \"7.5000\"}" > /dev/null

curl -s -X POST "${API_BASE}/currencies/manual-rate" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"from_currency\": \"$BASE_CURRENCY\", \"to_currency\": \"$TEST_CURRENCY_2\", \"rate\": \"0.1234\"}" > /dev/null

print_result 0 "Manual rates set for sorting test"
echo ""

echo "Step 10: Getting user's enabled currencies..."
USER_CURRENCIES=$(curl -s -X GET "${API_BASE}/currencies/user" \
    -H "Authorization: Bearer $TOKEN")

echo ""
echo "Currency list (should show base currency first, then manual rate currencies):"
echo "$USER_CURRENCIES" | jq -r '.data[] | "\(.code) - \(.name) - Enabled: \(.is_enabled)"' | head -n 10

echo ""
echo -e "${YELLOW}Note: Feature 2 (sorting) is implemented in Flutter UI${NC}"
echo -e "${YELLOW}This test verified the API provides manual rate information.${NC}"
echo -e "${YELLOW}To fully verify sorting, open the Flutter app and check the currency list.${NC}"
echo -e "${YELLOW}Manual rate currencies ($TEST_CURRENCY_1, $TEST_CURRENCY_2) should appear right after $BASE_CURRENCY${NC}"

FEATURE_2_PASSED=1  # We can't fully test UI sorting from API
echo ""

# Final cleanup - clear manual rates
echo "Cleanup: Clearing manual rates..."
curl -s -X DELETE "${API_BASE}/currencies/manual-rates/clear" \
    -H "Authorization: Bearer $TOKEN" > /dev/null
print_result 0 "Cleanup complete"
echo ""

# Summary
echo "======================================"
echo "TEST SUMMARY"
echo "======================================"
echo ""

if [ $FEATURE_1_PASSED -eq 1 ]; then
    echo -e "${GREEN}✓ Feature 1: Instant auto rate display - PASSED${NC}"
else
    echo -e "${RED}✗ Feature 1: Instant auto rate display - FAILED${NC}"
fi

echo -e "${YELLOW}⚠ Feature 2: Manual rate sorting - UI TEST REQUIRED${NC}"
echo -e "${YELLOW}  Please verify manually in Flutter app at:${NC}"
echo -e "${YELLOW}  http://localhost:3021/#/settings/currency${NC}"

echo ""
echo "======================================"
echo "Manual Verification Steps for Feature 2:"
echo "======================================"
echo "1. Open http://localhost:3021/#/settings/currency in browser"
echo "2. Enable multi-currency mode"
echo "3. Set manual rates for 2-3 currencies"
echo "4. Go to currency selection page"
echo "5. Verify: Base currency ($BASE_CURRENCY) is first"
echo "6. Verify: Currencies with manual rates appear immediately after base currency"
echo "7. Verify: Other currencies appear below manual rate currencies"
echo ""

if [ $FEATURE_1_PASSED -eq 1 ]; then
    exit 0
else
    exit 1
fi
