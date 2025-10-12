const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  console.log('🚀 Starting Settings Page Direct Access Test\n');

  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  // Storage for captured data
  const consoleMessages = [];

  // Capture console messages
  page.on('console', msg => {
    const text = msg.text();
    const type = msg.type();
    consoleMessages.push({ type, text });

    const prefix = {
      'error': '❌',
      'warning': '⚠️',
      'info': 'ℹ️',
      'log': '📝'
    }[type] || '💬';

    console.log(`${prefix} ${text}`);
  });

  try {
    console.log('\n🌐 Step 1: Navigating to settings page directly\n');

    // Try to go directly to settings
    await page.goto('http://localhost:3021/#/settings', {
      waitUntil: 'networkidle',
      timeout: 30000
    });

    console.log('\n⏱️ Waiting 3 seconds to see if we are redirected...\n');
    await page.waitForTimeout(3000);

    // Check current URL
    const currentUrl = page.url();
    console.log(`📍 Current URL: ${currentUrl}\n`);

    if (currentUrl.includes('/login')) {
      console.log('🔐 Redirected to login page (expected)');
      console.log('✅ Settings page correctly requires authentication\n');

      // Take screenshot of login page
      const screenshotPath = path.join(__dirname, 'screenshots', 'settings_requires_login.png');
      await page.screenshot({ path: screenshotPath, fullPage: true });
      console.log('📸 Screenshot saved:', screenshotPath);

      console.log('\n📋 Test Result: Settings page requires login (as expected)');
    } else if (currentUrl.includes('/settings')) {
      console.log('✅ Successfully accessed settings page (user already logged in)');

      // Wait a bit more for rendering
      await page.waitForTimeout(2000);

      // Take screenshot
      const screenshotPath = path.join(__dirname, 'screenshots', 'settings_page_loaded.png');
      await page.screenshot({ path: screenshotPath, fullPage: true });
      console.log('📸 Screenshot saved:', screenshotPath);

      // Check for errors in console
      const errors = consoleMessages.filter(m => m.type === 'error');
      const warnings = consoleMessages.filter(m => m.type === 'warning');

      console.log(`\n📊 Console Summary:`);
      console.log(`   - Errors: ${errors.length}`);
      console.log(`   - Warnings: ${warnings.length}`);
      console.log(`   - Total Messages: ${consoleMessages.length}`);

      if (errors.length === 0) {
        console.log('\n✅ No errors found! Settings page rendered successfully');
      } else {
        console.log('\n⚠️ Found errors in console:');
        errors.forEach(e => console.log(`   ${e.text}`));
      }
    } else {
      console.log('❓ Unexpected URL:', currentUrl);
    }

  } catch (error) {
    console.error('\n❌ Test failed with error:', error.message);
  } finally {
    console.log('\n🏁 Test completed, closing browser in 5 seconds...');
    await page.waitForTimeout(5000);
    await browser.close();
  }
})();
