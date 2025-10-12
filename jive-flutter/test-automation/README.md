# Jive Flutter - Playwright Test Automation

Automated testing for the Jive Flutter web application using Playwright.

## Prerequisites

- Node.js (v16 or higher)
- Flutter app running on http://localhost:3021

## Installation

```bash
# Install dependencies
npm install

# Install Playwright browsers
npx playwright install chromium
```

## Running Tests

### Quick Run (Recommended)
```bash
chmod +x run-test.sh
./run-test.sh
```

### Manual Run
```bash
# Make sure Flutter app is running first
cd ../
flutter run -d web-server --web-port 3021

# In another terminal
cd test-automation
node test_settings_page.js
```

## Test Output

The test generates:
- **Console Output**: Real-time logging of all browser console messages
- **Screenshot**: Full-page screenshot saved to `screenshots/settings_page.png`
- **Report**: Detailed markdown report saved to `../claudedocs/settings_page_test_report.md`

## What the Test Does

1. Opens http://localhost:3021/#/settings in Chromium
2. Captures all browser console messages (log, warn, error, debug, info)
3. Monitors network requests and failures
4. Detects page errors and exceptions
5. Takes a full-page screenshot
6. Generates a comprehensive report with:
   - Summary statistics
   - Font-related errors
   - Avatar-related issues
   - All console errors and warnings
   - Network failures
   - Failed HTTP requests
   - Recommendations for fixes

## Special Focus Areas

The test specifically looks for:
- Font loading errors
- Avatar service issues (DiceBear, UI-Avatars)
- Network request failures
- HTTP errors (4xx, 5xx)
- JavaScript exceptions

## Troubleshooting

**Flutter app not running:**
```bash
cd ../
flutter run -d web-server --web-port 3021
```

**Playwright not installed:**
```bash
npm install
npx playwright install chromium
```

**Permission denied on run-test.sh:**
```bash
chmod +x run-test.sh
```

## Test Configuration

- **Browser**: Chromium (headless: false for debugging)
- **Viewport**: 1280x720
- **Timeout**: 30 seconds for page load
- **Wait Time**: 3 seconds after load for dynamic content

## Report Location

- Screenshot: `test-automation/screenshots/settings_page.png`
- Report: `claudedocs/settings_page_test_report.md`
