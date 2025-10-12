// 使用 Puppeteer 验证页面货币分类
const puppeteer = require('puppeteer');

async function verifyCurrencyPages() {
  console.log('🔍 启动浏览器验证...\n');

  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  });

  try {
    const page = await browser.newPage();

    // 等待页面加载
    await page.goto('http://localhost:3021/#/settings/currency', {
      waitUntil: 'networkidle2',
      timeout: 30000
    });

    console.log('✅ 页面已加载: http://localhost:3021/#/settings/currency\n');

    // 等待 Flutter 渲染
    await page.waitForTimeout(3000);

    // 获取页面标题
    const title = await page.title();
    console.log('📄 页面标题:', title);

    // 获取页面 URL
    const url = await page.url();
    console.log('📍 当前 URL:', url, '\n');

    // 尝试提取文本内容
    const bodyText = await page.evaluate(() => {
      return document.body.innerText;
    });

    console.log('📝 页面文本内容 (前 1000 字符):');
    console.log(bodyText.substring(0, 1000));
    console.log('\n' + '='.repeat(60) + '\n');

    // 检查问题加密货币
    const problemCryptos = ['1INCH', 'AAVE', 'ADA', 'AGIX', 'PEPE', 'MKR', 'COMP', 'SOL', 'MATIC', 'UNI', 'BTC', 'ETH'];
    const foundCryptos = problemCryptos.filter(crypto => bodyText.includes(crypto));

    console.log('🔍 加密货币检测结果:');
    console.log('检查的货币:', problemCryptos.join(', '));
    console.log('在法币页面找到:', foundCryptos.length > 0 ? foundCryptos.join(', ') : '❌ 无 (正确！)');

    if (foundCryptos.length === 0) {
      console.log('\n✅ 验证通过: 法币页面中没有发现加密货币！');
    } else {
      console.log('\n❌ 验证失败: 法币页面中出现了以下加密货币:', foundCryptos.join(', '));
    }

    console.log('\n' + '='.repeat(60) + '\n');

    // 截图保存
    await page.screenshot({
      path: '/tmp/fiat_currency_page.png',
      fullPage: true
    });
    console.log('📸 页面截图已保存: /tmp/fiat_currency_page.png\n');

    // 检查加密货币页面
    console.log('🔄 正在导航到加密货币页面...\n');

    // 尝试点击或导航到加密货币页面
    // Flutter 应用可能使用特定的路由
    const cryptoUrls = [
      'http://localhost:3021/#/settings/crypto',
      'http://localhost:3021/#/crypto-selection',
      'http://localhost:3021/#/settings/cryptocurrency',
    ];

    let cryptoPageFound = false;
    for (const cryptoUrl of cryptoUrls) {
      try {
        await page.goto(cryptoUrl, {
          waitUntil: 'networkidle2',
          timeout: 10000
        });

        await page.waitForTimeout(2000);

        const cryptoBodyText = await page.evaluate(() => {
          return document.body.innerText;
        });

        // 检查是否是加密货币页面
        if (cryptoBodyText.includes('加密货币') || cryptoBodyText.includes('Crypto')) {
          cryptoPageFound = true;
          console.log('✅ 找到加密货币页面:', cryptoUrl);
          console.log('📝 页面内容 (前 500 字符):');
          console.log(cryptoBodyText.substring(0, 500));
          console.log('\n');

          const foundCryptosInCryptoPage = problemCryptos.filter(crypto => cryptoBodyText.includes(crypto));
          console.log('🔍 在加密货币页面找到:', foundCryptosInCryptoPage.length > 0 ? foundCryptosInCryptoPage.join(', ') : '无');

          await page.screenshot({
            path: '/tmp/crypto_currency_page.png',
            fullPage: true
          });
          console.log('📸 加密货币页面截图: /tmp/crypto_currency_page.png\n');

          break;
        }
      } catch (e) {
        // 继续尝试下一个 URL
      }
    }

    if (!cryptoPageFound) {
      console.log('⚠️  未能自动找到加密货币管理页面');
      console.log('建议手动在应用中导航到该页面进行验证');
    }

  } catch (error) {
    console.error('❌ 验证过程出错:', error.message);
  } finally {
    await browser.close();
    console.log('\n✅ 验证完成！');
  }
}

verifyCurrencyPages().catch(console.error);
