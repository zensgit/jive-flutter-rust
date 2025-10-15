# Playwright Test Automation Setup

## Overview

Automated browser testing for the Jive Flutter Settings page using Playwright. This test captures all console messages, errors, network failures, and generates detailed reports.

## Directory Structure

```
jive-flutter/
├── test-automation/
│   ├── package.json              # Node.js dependencies
│   ├── test_settings_page.js     # Main test script
│   ├── install-and-test.sh       # Quick setup and run script
│   ├── run-test.sh              # Run test only
│   ├── README.md                # Test automation documentation
│   └── screenshots/             # Generated screenshots (gitignored)
│       └── settings_page.png
└── claudedocs/
    └── settings_page_test_report.md  # Generated test report
```

## Quick Start

### 1. Ensure Flutter App is Running

```bash
# In terminal 1
cd /Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust/jive-flutter
flutter run -d web-server --web-port 3021
```

### 2. Run the Test

```bash
# In terminal 2
cd /Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust/jive-flutter/test-automation
chmod +x install-and-test.sh
./install-and-test.sh
```

The script will:
1. Install Node.js dependencies (if needed)
2. Install Playwright browser (if needed)
3. Check if Flutter app is running
4. Execute the test
5. Generate report and screenshot

## What the Test Does

### Captures:
1. **Console Messages**: All log, info, warn, error, debug messages
2. **Page Errors**: JavaScript exceptions and runtime errors
3. **Network Failures**: Failed HTTP requests
4. **HTTP Errors**: 4xx and 5xx responses
5. **Screenshots**: Full-page screenshot of the settings page

### Analyzes:
- Font-related errors (loading issues, missing fonts)
- Avatar-related issues (DiceBear, UI-Avatars service failures)
- Network request failures
- Page rendering status
- JavaScript errors and warnings

### Generates:
- **Console Output**: Real-time logging during test execution
- **Screenshot**: `test-automation/screenshots/settings_page.png`
- **Markdown Report**: `claudedocs/settings_page_test_report.md`

## Test Report Contents

The generated report includes:

1. **Summary Section**
   - Page rendered status
   - Total console messages count
   - Error and warning counts
   - Network failure statistics

2. **Critical Issues**
   - Font-related errors
   - Avatar-related issues

3. **Detailed Logs**
   - All console errors (with location and timestamp)
   - All console warnings
   - Page errors (with stack traces)
   - Network failures
   - Failed HTTP requests

4. **Recommendations**
   - Actionable fixes for detected issues

## Manual Execution

If you prefer to run commands manually:

```bash
# Navigate to test-automation directory
cd /Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust/jive-flutter/test-automation

# Install dependencies (first time only)
npm install

# Install Playwright browsers (first time only)
npx playwright install chromium

# Run the test
node test_settings_page.js
```

## Test Configuration

The test is configured with:
- **Browser**: Chromium (non-headless for debugging)
- **Viewport**: 1280x720
- **Page Load Timeout**: 30 seconds
- **Wait After Load**: 3 seconds for dynamic content
- **CORS**: Disabled for local development testing

## Troubleshooting

### Flutter App Not Running
**Error**: `❌ ERROR: Flutter app is not running on http://localhost:3021`

**Solution**:
```bash
cd /Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust/jive-flutter
flutter run -d web-server --web-port 3021
```

### Playwright Not Installed
**Error**: `Cannot find module 'playwright'`

**Solution**:
```bash
cd test-automation
npm install
npx playwright install chromium
```

### Permission Denied
**Error**: `Permission denied: ./install-and-test.sh`

**Solution**:
```bash
chmod +x install-and-test.sh
chmod +x run-test.sh
```

### Port Already in Use
**Error**: Flutter can't start on port 3021

**Solution**:
```bash
# Find process using port 3021
lsof -i :3021

# Kill the process
kill -9 <PID>

# Or use a different port
flutter run -d web-server --web-port 3022
# Update test script to use port 3022
```

## Gitignore Configuration

The following are automatically ignored by git:
- `test-automation/node_modules/`
- `test-automation/package-lock.json`
- `test-automation/screenshots/`
- `test-automation/.playwright/`
- `test-automation/test-results/`
- `test-automation/playwright-report/`

## Expected Output

### Successful Test Run

```
🚀 Starting Playwright test for Settings page...

🌐 Navigating to http://localhost:3021/#/settings

✅ Page loaded, waiting for 3 seconds to capture all messages...

📸 Screenshot saved to: /path/to/screenshots/settings_page.png

📄 Report saved to: /path/to/claudedocs/settings_page_test_report.md

================================================================================
📊 TEST SUMMARY
================================================================================
Total Console Messages: 25
  - Errors: 2
  - Warnings: 5
  - Logs: 18
  - Info: 0
Page Errors: 0
Network Failures: 1
Page Has Content: YES ✅
================================================================================
```

### Console Message Examples

```
📝 [LOG] Flutter initialized
⚠️ [WARN] Font loading delayed: MaterialIcons
❌ [ERROR] Failed to load resource: https://api.dicebear.com/avatar.svg
🌐 NETWORK FAILURE: https://api.example.com/data - net::ERR_CONNECTION_REFUSED
🔴 HTTP 404: http://localhost:3021/assets/fonts/custom.ttf
```

## Next Steps

1. Review the generated report in `claudedocs/settings_page_test_report.md`
2. Check the screenshot in `test-automation/screenshots/settings_page.png`
3. Fix any critical issues identified
4. Re-run the test to verify fixes

## Additional Tests

To add more tests, create new test files in `test-automation/` following the same pattern:

```javascript
// test-automation/test_login_page.js
const { chromium } = require('playwright');

async function testLoginPage() {
  // Your test code here
}

testLoginPage().catch(console.error);
```

## Resources

- [Playwright Documentation](https://playwright.dev/)
- [Playwright Node.js API](https://playwright.dev/docs/api/class-playwright)
- [Flutter Web Testing](https://flutter.dev/docs/testing)

---

**Created**: 2025-10-09
**Author**: Claude Code (Test Automation Engineer)
**Purpose**: Document Playwright test automation setup for Jive Flutter application
