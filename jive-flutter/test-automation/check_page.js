const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

(async () => {
  console.log('🔍 Checking page rendering...\n');

  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext();
  const page = await context.newPage();

  const issues = [];

  // Capture console
  page.on('console', msg => {
    const text = msg.text();
    const type = msg.type();
    if (type === 'error' && !text.includes('Font')) {
      issues.push(`Console Error: ${text}`);
    }
  });

  page.on('pageerror', err => {
    issues.push(`Page Error: ${err.message}`);
  });

  try {
    console.log('📍 Navigating to http://localhost:3021...');
    await page.goto('http://localhost:3021', {
      waitUntil: 'networkidle',
      timeout: 30000
    });

    console.log('⏱️ Waiting 3 seconds for rendering...');
    await page.waitForTimeout(3000);

    const url = page.url();
    console.log(`✅ Current URL: ${url}\n`);

    // Take screenshot
    const screenshotDir = path.join(__dirname, 'screenshots');
    if (!fs.existsSync(screenshotDir)) {
      fs.mkdirSync(screenshotDir, { recursive: true });
    }

    const screenshotPath = path.join(screenshotDir, 'current_page.png');
    await page.screenshot({ path: screenshotPath, fullPage: true });
    console.log(`📸 Screenshot saved: ${screenshotPath}\n`);

    // Check if page has visible content
    const bodyText = await page.evaluate(() => document.body.innerText);
    const hasText = bodyText && bodyText.trim().length > 0;

    console.log('📊 Page Analysis:');
    console.log(`  - Has visible text: ${hasText}`);
    console.log(`  - Text length: ${bodyText ? bodyText.length : 0} characters`);

    if (bodyText && bodyText.length > 0) {
      console.log(`  - First 200 chars: "${bodyText.substring(0, 200).replace(/\n/g, ' ')}"`);
    }

    // Check for specific elements
    const hasBody = await page.evaluate(() => !!document.body);
    const hasCanvas = await page.$$eval('canvas', canvases => canvases.length);
    const hasFwfCanvas = await page.$$eval('flt-glass-pane', panes => panes.length);

    console.log(`  - Body element: ${hasBody ? 'Present' : 'Missing'}`);
    console.log(`  - Canvas elements: ${hasCanvas}`);
    console.log(`  - Flutter glass pane: ${hasFwfCanvas}`);

    // Check computed styles
    const bodyStyles = await page.evaluate(() => {
      const body = document.body;
      const styles = window.getComputedStyle(body);
      return {
        fontFamily: styles.fontFamily,
        fontSize: styles.fontSize,
        color: styles.color,
        backgroundColor: styles.backgroundColor,
        display: styles.display,
        visibility: styles.visibility
      };
    });

    console.log(`\n🎨 Body Styles:`);
    console.log(`  - Font Family: ${bodyStyles.fontFamily}`);
    console.log(`  - Font Size: ${bodyStyles.fontSize}`);
    console.log(`  - Color: ${bodyStyles.color}`);
    console.log(`  - Background: ${bodyStyles.backgroundColor}`);
    console.log(`  - Display: ${bodyStyles.display}`);
    console.log(`  - Visibility: ${bodyStyles.visibility}`);

    if (issues.length > 0) {
      console.log(`\n⚠️ Issues found (${issues.length}):`);
      issues.forEach(issue => console.log(`  - ${issue}`));
    } else {
      console.log(`\n✅ No JavaScript errors detected`);
    }

    console.log(`\n💡 Check the screenshot at: ${screenshotPath}`);

  } catch (error) {
    console.error('\n❌ Error:', error.message);
  } finally {
    console.log('\n⏰ Keeping browser open for 10 seconds for manual inspection...');
    await page.waitForTimeout(10000);
    await browser.close();
  }
})();
