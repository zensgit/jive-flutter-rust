const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

async function testSettingsPage() {
  console.log('🚀 Starting Playwright test for Settings page...\n');

  const browser = await chromium.launch({
    headless: false,  // Show browser for debugging
    args: ['--disable-web-security'] // Allow CORS for local development
  });

  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
  });

  const page = await context.newPage();

  // Capture console messages
  const consoleMessages = {
    log: [],
    info: [],
    warn: [],
    error: [],
    debug: []
  };

  page.on('console', msg => {
    const type = msg.type();
    const text = msg.text();
    const timestamp = new Date().toISOString();

    const message = {
      timestamp,
      type,
      text,
      location: msg.location()
    };

    if (consoleMessages[type]) {
      consoleMessages[type].push(message);
    }

    // Real-time output
    const emoji = {
      log: '📝',
      info: 'ℹ️',
      warn: '⚠️',
      error: '❌',
      debug: '🔍'
    }[type] || '📄';

    console.log(`${emoji} [${type.toUpperCase()}] ${text}`);
  });

  // Capture page errors
  const pageErrors = [];
  page.on('pageerror', error => {
    const errorInfo = {
      timestamp: new Date().toISOString(),
      message: error.message,
      stack: error.stack
    };
    pageErrors.push(errorInfo);
    console.log('💥 PAGE ERROR:', error.message);
  });

  // Capture network failures
  const networkFailures = [];
  page.on('requestfailed', request => {
    const failure = {
      timestamp: new Date().toISOString(),
      url: request.url(),
      method: request.method(),
      failure: request.failure()?.errorText || 'Unknown error'
    };
    networkFailures.push(failure);
    console.log('🌐 NETWORK FAILURE:', request.url(), '-', failure.failure);
  });

  // Capture successful network requests (for context)
  const networkRequests = [];
  page.on('response', async response => {
    const request = {
      timestamp: new Date().toISOString(),
      url: response.url(),
      status: response.status(),
      statusText: response.statusText(),
      method: response.request().method()
    };
    networkRequests.push(request);

    if (response.status() >= 400) {
      console.log(`🔴 HTTP ${response.status()}: ${response.url()}`);
    }
  });

  try {
    console.log('\n🌐 Navigating to http://localhost:3021/#/settings\n');

    // Navigate to the page
    await page.goto('http://localhost:3021/#/settings', {
      waitUntil: 'networkidle',
      timeout: 30000
    });

    console.log('\n✅ Page loaded, waiting for 3 seconds to capture all messages...\n');

    // Wait for any dynamic content to load
    await page.waitForTimeout(3000);

    // Take screenshot
    const screenshotPath = path.join(__dirname, 'screenshots', 'settings_page.png');
    const screenshotDir = path.dirname(screenshotPath);

    if (!fs.existsSync(screenshotDir)) {
      fs.mkdirSync(screenshotDir, { recursive: true });
    }

    await page.screenshot({
      path: screenshotPath,
      fullPage: true
    });
    console.log('📸 Screenshot saved to:', screenshotPath);

    // Check if page has visible content
    const bodyText = await page.textContent('body');
    const hasContent = bodyText && bodyText.trim().length > 0;

    // Generate detailed report
    const report = generateReport({
      consoleMessages,
      pageErrors,
      networkFailures,
      networkRequests,
      hasContent,
      screenshotPath,
      url: 'http://localhost:3021/#/settings'
    });

    // Save report to file
    const reportPath = path.join(__dirname, 'claudedocs', 'settings_page_test_report.md');
    const reportDir = path.dirname(reportPath);

    if (!fs.existsSync(reportDir)) {
      fs.mkdirSync(reportDir, { recursive: true });
    }

    fs.writeFileSync(reportPath, report, 'utf8');
    console.log('\n📄 Report saved to:', reportPath);

    // Print summary to console
    console.log('\n' + '='.repeat(80));
    console.log('📊 TEST SUMMARY');
    console.log('='.repeat(80));
    console.log(`Total Console Messages: ${Object.values(consoleMessages).flat().length}`);
    console.log(`  - Errors: ${consoleMessages.error.length}`);
    console.log(`  - Warnings: ${consoleMessages.warn.length}`);
    console.log(`  - Logs: ${consoleMessages.log.length}`);
    console.log(`  - Info: ${consoleMessages.info.length}`);
    console.log(`Page Errors: ${pageErrors.length}`);
    console.log(`Network Failures: ${networkFailures.length}`);
    console.log(`Page Has Content: ${hasContent ? 'YES ✅' : 'NO ❌'}`);
    console.log('='.repeat(80));

  } catch (error) {
    console.error('❌ Test failed:', error);
    throw error;
  } finally {
    await browser.close();
  }
}

function generateReport(data) {
  const { consoleMessages, pageErrors, networkFailures, networkRequests, hasContent, screenshotPath, url } = data;

  let report = `# Settings Page Test Report\n\n`;
  report += `**Test URL:** ${url}\n`;
  report += `**Test Time:** ${new Date().toISOString()}\n`;
  report += `**Screenshot:** ${screenshotPath}\n\n`;

  report += `## 📊 Summary\n\n`;
  report += `- **Page Rendered:** ${hasContent ? '✅ YES' : '❌ NO'}\n`;
  report += `- **Total Console Messages:** ${Object.values(consoleMessages).flat().length}\n`;
  report += `- **Console Errors:** ${consoleMessages.error.length}\n`;
  report += `- **Console Warnings:** ${consoleMessages.warn.length}\n`;
  report += `- **Page Errors:** ${pageErrors.length}\n`;
  report += `- **Network Failures:** ${networkFailures.length}\n\n`;

  // Critical Issues
  report += `## 🚨 Critical Issues\n\n`;

  const fontErrors = consoleMessages.error.filter(m =>
    m.text.toLowerCase().includes('font')
  );

  const avatarErrors = [...consoleMessages.error, ...consoleMessages.warn].filter(m =>
    m.text.toLowerCase().includes('avatar') ||
    m.text.toLowerCase().includes('dicebear') ||
    m.text.toLowerCase().includes('ui-avatars')
  );

  if (fontErrors.length > 0) {
    report += `### Font-Related Errors (${fontErrors.length})\n\n`;
    fontErrors.forEach((msg, idx) => {
      report += `${idx + 1}. **${msg.text}**\n`;
      report += `   - Location: ${msg.location?.url || 'Unknown'}\n`;
      report += `   - Time: ${msg.timestamp}\n\n`;
    });
  } else {
    report += `### Font-Related Errors\n✅ No font errors detected\n\n`;
  }

  if (avatarErrors.length > 0) {
    report += `### Avatar-Related Issues (${avatarErrors.length})\n\n`;
    avatarErrors.forEach((msg, idx) => {
      report += `${idx + 1}. [${msg.type.toUpperCase()}] **${msg.text}**\n`;
      report += `   - Location: ${msg.location?.url || 'Unknown'}\n`;
      report += `   - Time: ${msg.timestamp}\n\n`;
    });
  } else {
    report += `### Avatar-Related Issues\n✅ No avatar-related issues detected\n\n`;
  }

  // All Console Errors
  if (consoleMessages.error.length > 0) {
    report += `## ❌ Console Errors (${consoleMessages.error.length})\n\n`;
    consoleMessages.error.forEach((msg, idx) => {
      report += `${idx + 1}. **${msg.text}**\n`;
      report += `   - Location: ${msg.location?.url || 'Unknown'}\n`;
      report += `   - Line: ${msg.location?.lineNumber || 'N/A'}:${msg.location?.columnNumber || 'N/A'}\n`;
      report += `   - Time: ${msg.timestamp}\n\n`;
    });
  }

  // Console Warnings
  if (consoleMessages.warn.length > 0) {
    report += `## ⚠️ Console Warnings (${consoleMessages.warn.length})\n\n`;
    consoleMessages.warn.forEach((msg, idx) => {
      report += `${idx + 1}. **${msg.text}**\n`;
      report += `   - Location: ${msg.location?.url || 'Unknown'}\n`;
      report += `   - Time: ${msg.timestamp}\n\n`;
    });
  }

  // Page Errors
  if (pageErrors.length > 0) {
    report += `## 💥 Page Errors (${pageErrors.length})\n\n`;
    pageErrors.forEach((error, idx) => {
      report += `${idx + 1}. **${error.message}**\n`;
      report += `\`\`\`\n${error.stack}\n\`\`\`\n\n`;
    });
  }

  // Network Failures
  if (networkFailures.length > 0) {
    report += `## 🌐 Network Failures (${networkFailures.length})\n\n`;
    networkFailures.forEach((failure, idx) => {
      report += `${idx + 1}. **${failure.url}**\n`;
      report += `   - Method: ${failure.method}\n`;
      report += `   - Error: ${failure.failure}\n`;
      report += `   - Time: ${failure.timestamp}\n\n`;
    });
  }

  // Failed HTTP Requests (4xx, 5xx)
  const failedRequests = networkRequests.filter(r => r.status >= 400);
  if (failedRequests.length > 0) {
    report += `## 🔴 Failed HTTP Requests (${failedRequests.length})\n\n`;
    failedRequests.forEach((req, idx) => {
      report += `${idx + 1}. **HTTP ${req.status}** - ${req.url}\n`;
      report += `   - Method: ${req.method}\n`;
      report += `   - Status: ${req.statusText}\n`;
      report += `   - Time: ${req.timestamp}\n\n`;
    });
  }

  // Console Logs (for context)
  if (consoleMessages.log.length > 0) {
    report += `## 📝 Console Logs (${consoleMessages.log.length})\n\n`;
    report += `<details>\n<summary>Click to expand</summary>\n\n`;
    consoleMessages.log.forEach((msg, idx) => {
      report += `${idx + 1}. ${msg.text}\n`;
    });
    report += `\n</details>\n\n`;
  }

  // Recommendations
  report += `## 💡 Recommendations\n\n`;

  if (fontErrors.length > 0) {
    report += `- ⚠️ **Font Loading Issues Detected**: Check font file paths and ensure fonts are properly loaded\n`;
  }

  if (avatarErrors.length > 0) {
    report += `- ⚠️ **Avatar Service Issues**: Verify avatar generation service (DiceBear/UI-Avatars) configuration and network access\n`;
  }

  if (networkFailures.length > 0) {
    report += `- ⚠️ **Network Failures Detected**: Check API endpoints and CORS configuration\n`;
  }

  if (consoleMessages.error.length === 0 && networkFailures.length === 0) {
    report += `- ✅ No critical issues detected. Page appears to be functioning correctly.\n`;
  }

  report += `\n---\n*Report generated by Playwright automated test*\n`;

  return report;
}

// Run the test
testSettingsPage().catch(console.error);
