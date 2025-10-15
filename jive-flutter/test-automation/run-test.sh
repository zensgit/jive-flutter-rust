#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Jive Flutter Settings Page Test${NC}\n"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
  echo -e "${YELLOW}📦 Installing dependencies...${NC}"
  npm install

  echo -e "${YELLOW}🌐 Installing Chromium browser for Playwright...${NC}"
  npx playwright install chromium
fi

# Check if Flutter app is running
echo -e "${YELLOW}🔍 Checking if Flutter app is running on http://localhost:3021...${NC}"
if ! curl -s http://localhost:3021 > /dev/null 2>&1; then
  echo -e "${RED}❌ Flutter app is not running!${NC}"
  echo -e "${YELLOW}Please start the Flutter app with:${NC}"
  echo -e "  cd ../jive-flutter"
  echo -e "  flutter run -d web-server --web-port 3021"
  exit 1
fi

echo -e "${GREEN}✅ Flutter app is running${NC}\n"

# Run the test
echo -e "${GREEN}🧪 Running Playwright test...${NC}\n"
node test_settings_page.js

# Check exit code
if [ $? -eq 0 ]; then
  echo -e "\n${GREEN}✅ Test completed successfully!${NC}"
  echo -e "${YELLOW}📄 Report saved to: ../claudedocs/settings_page_test_report.md${NC}"
  echo -e "${YELLOW}📸 Screenshot saved to: screenshots/settings_page.png${NC}"
else
  echo -e "\n${RED}❌ Test failed!${NC}"
  exit 1
fi
