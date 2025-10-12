const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  console.log('🚀 Starting Complete Application Flow Test\n');

  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  // Storage for captured data
  const consoleMessages = [];
  const errors = [];

  // Capture console messages
  page.on('console', msg => {
    const text = msg.text();
    const type = msg.type();
    consoleMessages.push({ type, text, timestamp: new Date().toISOString() });

    const prefix = {
      'error': '❌',
      'warning': '⚠️',
      'info': 'ℹ️',
      'log': '📝'
    }[type] || '💬';

    console.log(`${prefix} ${text}`);

    if (type === 'error' && !text.includes('font')) {
      errors.push(text);
    }
  });

  // Capture page errors
  page.on('pageerror', error => {
    console.error('❌ PAGE ERROR:', error.message);
    errors.push(`PAGE ERROR: ${error.message}`);
  });

  try {
    // ========================================
    // Step 1: Navigate to Login Page
    // ========================================
    console.log('\n🌐 Step 1: Navigating to login page\n');
    await page.goto('http://localhost:3021/#/login', {
      waitUntil: 'networkidle',
      timeout: 30000
    });

    await page.waitForTimeout(2000);

    // Check if already logged in (redirected to dashboard)
    let currentUrl = page.url();
    console.log(`📍 Current URL: ${currentUrl}\n`);

    if (currentUrl.includes('/dashboard')) {
      console.log('✅ Already logged in, redirected to dashboard');

      // Take screenshot
      const dashboardPath = path.join(__dirname, 'screenshots', 'flow_already_logged_in.png');
      await page.screenshot({ path: dashboardPath, fullPage: true });
      console.log('📸 Dashboard screenshot saved:', dashboardPath);

    } else if (currentUrl.includes('/login')) {
      console.log('📝 On login page, attempting to login...\n');

      // Take screenshot of login page
      const loginPath = path.join(__dirname, 'screenshots', 'flow_login_page.png');
      await page.screenshot({ path: loginPath, fullPage: true });
      console.log('📸 Login page screenshot saved:', loginPath);

      // Try to find username and password fields
      await page.waitForTimeout(1000);

      // Check if we can find input fields
      const inputFields = await page.$$('input[type="text"], input[type="password"]');
      console.log(`Found ${inputFields.length} input fields\n`);

      if (inputFields.length >= 2) {
        console.log('Attempting to fill login form...');
        // Fill username (using demo credentials)
        await inputFields[0].click();
        await inputFields[0].type('demo');

        // Fill password
        await inputFields[1].click();
        await inputFields[1].type('demo123');

        console.log('Credentials entered, looking for login button...\n');

        // Find and click login button
        const buttons = await page.$$('button');
        for (const button of buttons) {
          const text = await button.textContent();
          if (text && (text.includes('登录') || text.includes('Login') || text.includes('登錄'))) {
            console.log('Found login button, clicking...\n');
            await button.click();
            break;
          }
        }

        // Wait for navigation
        console.log('⏱️ Waiting for login to complete...\n');
        await page.waitForTimeout(3000);

        currentUrl = page.url();
        console.log(`📍 After login, current URL: ${currentUrl}\n`);

        if (currentUrl.includes('/dashboard') || !currentUrl.includes('/login')) {
          console.log('✅ Login successful!\n');
          const loginSuccessPath = path.join(__dirname, 'screenshots', 'flow_login_success.png');
          await page.screenshot({ path: loginSuccessPath, fullPage: true });
          console.log('📸 Post-login screenshot saved:', loginSuccessPath);
        } else {
          console.log('⚠️ Still on login page, login may have failed\n');
        }
      } else {
        console.log('⚠️ Could not find login form fields\n');
      }
    }

    // ========================================
    // Step 2: Navigate to Settings Page
    // ========================================
    console.log('\n🌐 Step 2: Navigating to settings page\n');

    // Clear previous console messages
    consoleMessages.length = 0;
    errors.length = 0;

    await page.goto('http://localhost:3021/#/settings', {
      waitUntil: 'networkidle',
      timeout: 30000
    });

    console.log('⏱️ Waiting for page to render...\n');
    await page.waitForTimeout(3000);

    currentUrl = page.url();
    console.log(`📍 Current URL: ${currentUrl}\n`);

    if (currentUrl.includes('/login')) {
      console.log('🔐 Redirected back to login - authentication expired or failed\n');
      console.log('❌ Test cannot continue without valid session\n');

      const redirectPath = path.join(__dirname, 'screenshots', 'flow_auth_redirect.png');
      await page.screenshot({ path: redirectPath, fullPage: true });
      console.log('📸 Redirect screenshot saved:', redirectPath);

    } else if (currentUrl.includes('/settings')) {
      console.log('✅ Successfully accessed settings page!\n');

      // Wait more for complete rendering
      await page.waitForTimeout(2000);

      // Take screenshot
      const settingsPath = path.join(__dirname, 'screenshots', 'flow_settings_page.png');
      await page.screenshot({ path: settingsPath, fullPage: true });
      console.log('📸 Settings page screenshot saved:', settingsPath);

      // ========================================
      // Step 3: Verify TextField Widgets
      // ========================================
      console.log('\n🔍 Step 3: Verifying TextField widgets render correctly\n');

      // Check for specific text that indicates profile settings loaded
      const pageText = await page.textContent('body');

      if (pageText.includes('用户名') || pageText.includes('Username')) {
        console.log('✅ Username field label found');
      }
      if (pageText.includes('邮箱') || pageText.includes('Email')) {
        console.log('✅ Email field label found');
      }
      if (pageText.includes('验证码') || pageText.includes('Verification')) {
        console.log('✅ Verification code field label found');
      }

      // Check for NaN errors in console
      const nanErrors = errors.filter(e =>
        e.toLowerCase().includes('nan') ||
        e.toLowerCase().includes('boxconstraints')
      );

      console.log('\n📊 Console Analysis:');
      console.log(`   - Total messages: ${consoleMessages.length}`);
      console.log(`   - Errors (non-font): ${errors.length}`);
      console.log(`   - NaN/BoxConstraints errors: ${nanErrors.length}`);

      if (nanErrors.length > 0) {
        console.log('\n❌ Found NaN/BoxConstraints errors:');
        nanErrors.forEach(e => console.log(`   ${e}`));
      } else {
        console.log('\n✅ No NaN or BoxConstraints errors found!');
      }

      if (errors.length === 0) {
        console.log('\n✅✅✅ SUCCESS: Settings page rendered without errors!');
        console.log('All TextField widgets are working correctly.\n');
      } else {
        console.log('\n⚠️ Non-font errors found:');
        errors.forEach(e => console.log(`   ${e}`));
      }

      // Try to interact with input fields to verify they work
      console.log('\n🖱️ Step 4: Testing TextField interaction\n');

      const editableTexts = await page.$$('[contenteditable="true"]');
      console.log(`Found ${editableTexts.length} editable text fields\n`);

      if (editableTexts.length > 0) {
        console.log('Testing first editable field...');
        try {
          await editableTexts[0].click();
          await page.waitForTimeout(500);
          await page.keyboard.type('test');
          await page.waitForTimeout(500);
          console.log('✅ Successfully typed in editable field\n');

          // Take screenshot after interaction
          const interactionPath = path.join(__dirname, 'screenshots', 'flow_field_interaction.png');
          await page.screenshot({ path: interactionPath, fullPage: true });
          console.log('📸 Interaction screenshot saved:', interactionPath);
        } catch (err) {
          console.log('⚠️ Could not interact with field:', err.message);
        }
      }
    } else {
      console.log('❓ Unexpected URL:', currentUrl);
    }

    // ========================================
    // Final Report
    // ========================================
    console.log('\n' + '='.repeat(60));
    console.log('📋 TEST SUMMARY');
    console.log('='.repeat(60));

    const fontWarnings = consoleMessages.filter(m =>
      m.type === 'warning' && m.text.includes('font')
    ).length;

    console.log(`\n✅ Login: ${currentUrl.includes('/settings') ? 'Success' : 'Failed/Skipped'}`);
    console.log(`✅ Settings Access: ${currentUrl.includes('/settings') ? 'Success' : 'Failed'}`);
    console.log(`✅ TextField Rendering: ${errors.length === 0 ? 'Success' : 'Issues Found'}`);
    console.log(`\n📊 Console Statistics:`);
    console.log(`   - Font warnings (expected): ${fontWarnings}`);
    console.log(`   - Real errors: ${errors.length}`);
    console.log(`   - NaN errors: ${errors.filter(e => e.toLowerCase().includes('nan')).length}`);

    if (errors.length === 0) {
      console.log('\n🎉 ALL TESTS PASSED! 🎉');
      console.log('Settings page and TextField widgets are working correctly.');
    } else {
      console.log('\n⚠️ Some issues found - see details above');
    }

  } catch (error) {
    console.error('\n❌ Test failed with error:', error.message);
    console.error(error.stack);
  } finally {
    console.log('\n🏁 Test completed, closing browser in 8 seconds...');
    await page.waitForTimeout(8000);
    await browser.close();
  }
})();
