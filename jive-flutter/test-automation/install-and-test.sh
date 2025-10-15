#!/bin/bash

set -e  # Exit on error

echo "🚀 Starting Playwright test setup and execution..."
echo ""

# Navigate to script directory
cd "$(dirname "$0")"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
  echo "📦 Installing npm dependencies..."
  npm install
  echo ""
fi

# Check if Playwright is installed
if [ ! -d "node_modules/playwright" ]; then
  echo "📦 Installing Playwright..."
  npm install playwright
  echo ""
fi

# Install browser if needed
if ! npx playwright --version > /dev/null 2>&1; then
  echo "🌐 Installing Chromium browser..."
  npx playwright install chromium
  echo ""
fi

# Check if Flutter app is running
echo "🔍 Checking if Flutter app is running on http://localhost:3021..."
if curl -s -f http://localhost:3021 > /dev/null 2>&1; then
  echo "✅ Flutter app is running"
  echo ""
else
  echo "❌ ERROR: Flutter app is not running on http://localhost:3021"
  echo ""
  echo "Please start the Flutter app first with:"
  echo "  cd /Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust/jive-flutter"
  echo "  flutter run -d web-server --web-port 3021"
  echo ""
  exit 1
fi

# Run the test
echo "🧪 Running Playwright test..."
echo ""
node test_settings_page.js

echo ""
echo "✅ Test completed!"
echo "📄 Report: ../claudedocs/settings_page_test_report.md"
echo "📸 Screenshot: screenshots/settings_page.png"
