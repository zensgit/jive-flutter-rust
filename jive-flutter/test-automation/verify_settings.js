const { chromium } = require('playwright');

(async () => {
  console.log('='.repeat(80));
  console.log('Settings Page TextField Verification Test');
  console.log('='.repeat(80) + '\n');

  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  const errors = [];
  const nanErrors = [];

  // Capture errors
  page.on('console', msg => {
    if (msg.type() === 'error') {
      const text = msg.text();
      if (!text.includes('font') && !text.includes('Font')) {
        errors.push(text);
        if (text.toLowerCase().includes('nan') || text.toLowerCase().includes('boxconstraints')) {
          nanErrors.push(text);
        }
      }
    }
  });

  page.on('pageerror', error => {
    const msg = error.message;
    errors.push(`PAGE ERROR: ${msg}`);
    if (msg.toLowerCase().includes('nan') || msg.toLowerCase().includes('boxconstraints')) {
      nanErrors.push(msg);
    }
  });

  try {
    // Navigate directly to settings - expect redirect to login if not authenticated
    console.log('Step 1: Navigating to settings page...');
    await page.goto('http://localhost:3021/#/settings', {
      waitUntil: 'networkidle',
      timeout: 30000
    });

    await page.waitForTimeout(3000);

    let url = page.url();
    console.log(`Current URL: ${url}`);

    if (url.includes('/login')) {
      console.log('\n✅ Not authenticated - redirected to login (expected)\n');
      console.log('Step 2: Attempting automatic login...');

      // Wait for page to render
      await page.waitForTimeout(2000);

      // Try to find and fill username field (EditableText)
      const editableElements = await page.$$('[contenteditable="true"]');
      console.log(`Found ${editableElements.length} editable elements`);

      if (editableElements.length >= 2) {
        console.log('Filling username...');
        await editableElements[0].click();
        await page.keyboard.type('demo');

        console.log('Filling password...');
        await editableElements[1].click();
        await page.keyboard.type('demo123');

        // Find login button
        const buttons = await page.$$('button');
        for (const button of buttons) {
          const text = await button.textContent();
          if (text && (text.includes('登录') || text.toLowerCase().includes('login'))) {
            console.log('Clicking login button...');
            await button.click();
            break;
          }
        }

        // Wait for login to process
        console.log('Waiting for login...\n');
        await page.waitForTimeout(4000);

        url = page.url();
        console.log(`After login, URL: ${url}`);

        if (!url.includes('/login')) {
          console.log('✅ Login successful!\n');

          // Now try to navigate to settings
          console.log('Step 3: Navigating to settings page...');
          await page.goto('http://localhost:3021/#/settings', {
            waitUntil: 'networkidle',
            timeout: 30000
          });

          await page.waitForTimeout(3000);
          url = page.url();
        }
      } else {
        console.log('⚠️ Could not find login form fields');
      }
    }

    // Check if we're on settings page
    if (url.includes('/settings')) {
      console.log('\n' + '='.repeat(80));
      console.log('✅ SUCCESSFULLY ACCESSED SETTINGS PAGE');
      console.log('='.repeat(80) + '\n');

      // Wait for complete rendering
      await page.waitForTimeout(2000);

      // Check for specific elements that indicate profile settings loaded
      const pageContent = await page.content();

      const indicators = {
        '用户名 field': pageContent.includes('用户名'),
        '邮箱 field': pageContent.includes('邮箱'),
        '验证码 field': pageContent.includes('验证码')
      };

      console.log('Page Content Verification:');
      for (const [key, found] of Object.entries(indicators)) {
        console.log(`  ${found ? '✅' : '❌'} ${key}: ${found ? 'FOUND' : 'NOT FOUND'}`);
      }

      // Test editable fields
      console.log('\nEditable Fields Test:');
      const editableFields = await page.$$('[contenteditable="true"]');
      console.log(`  Found ${editableFields.length} editable fields`);

      if (editableFields.length > 0) {
        try {
          console.log('  Testing first editable field...');
          await editableFields[0].click();
          await page.waitForTimeout(300);
          await page.keyboard.type('TEST');
          await page.waitForTimeout(300);
          console.log('  ✅ Successfully typed in editable field');
        } catch (err) {
          console.log(`  ❌ Could not interact with field: ${err.message}`);
        }
      }

      // Final error report
      console.log('\n' + '='.repeat(80));
      console.log('ERROR ANALYSIS');
      console.log('='.repeat(80));
      console.log(`\nTotal errors (excluding fonts): ${errors.length}`);
      console.log(`NaN/BoxConstraints errors: ${nanErrors.length}`);

      if (nanErrors.length > 0) {
        console.log('\n❌ FOUND NaN/BoxConstraints ERRORS:');
        nanErrors.forEach(err => console.log(`  - ${err}`));
        console.log('\n❌ TEST FAILED: TextField rendering errors detected');
      } else if (errors.length > 0) {
        console.log('\n⚠️ Found other errors:');
        errors.forEach(err => console.log(`  - ${err}`));
        console.log('\n⚠️ TEST PARTIALLY PASSED: No NaN errors but other issues exist');
      } else {
        console.log('\n✅ NO ERRORS DETECTED!');
        console.log('✅✅✅ TEST PASSED: Settings page TextField widgets work correctly!');
      }

    } else {
      console.log('\n❌ Could not access settings page');
      console.log(`Stuck at: ${url}`);
    }

  } catch (error) {
    console.error('\n❌ Test error:', error.message);
  } finally {
    console.log('\n' + '='.repeat(80));
    console.log('Test complete. Closing browser in 5 seconds...');
    console.log('='.repeat(80) + '\n');
    await page.waitForTimeout(5000);
    await browser.close();
  }
})();
