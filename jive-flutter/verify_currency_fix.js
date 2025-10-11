// 🧪 货币分类修复验证脚本
// 在浏览器 Console (F12) 中执行此脚本来验证修复是否生效

(async function verifyCurrencyFix() {
  console.log('🔍 开始验证货币分类修复...\n');

  // 等待 Flutter 应用加载
  console.log('⏳ 等待应用加载...');
  await new Promise(resolve => setTimeout(resolve, 2000));

  try {
    // 1. 检查当前页面
    console.log('📍 当前页面:', window.location.href);
    console.log('📄 页面标题:', document.title);

    // 2. 尝试从 DOM 中提取货币信息
    const currencyElements = document.querySelectorAll('[data-code], .currency-item, .list-item');
    console.log(`\n📊 页面中找到 ${currencyElements.length} 个货币元素`);

    // 提取所有可见的货币代码
    const visibleCodes = [];
    currencyElements.forEach(el => {
      // 尝试多种方式提取货币代码
      const code = el.getAttribute('data-code') ||
                   el.getAttribute('data-currency-code') ||
                   el.querySelector('[data-code]')?.getAttribute('data-code') ||
                   el.textContent.match(/\b([A-Z]{3,})\b/)?.[1];

      if (code && code.length >= 3 && code.length <= 6) {
        visibleCodes.push(code);
      }
    });

    // 去重
    const uniqueCodes = [...new Set(visibleCodes)];
    console.log(`\n✅ 提取到 ${uniqueCodes.length} 个唯一货币代码`);
    console.log('前 20 个:', uniqueCodes.slice(0, 20).join(', '));

    // 3. 检查问题加密货币
    const problemCryptos = ['1INCH', 'AAVE', 'ADA', 'AGIX', 'PEPE', 'MKR', 'COMP', 'SOL', 'MATIC', 'UNI', 'BTC', 'ETH'];
    const foundProblems = uniqueCodes.filter(code => problemCryptos.includes(code));

    console.log('\n🔍 检查问题加密货币:');
    console.log('问题货币列表:', problemCryptos.join(', '));
    console.log('在当前页面找到:', foundProblems.length > 0 ? foundProblems.join(', ') : '无');

    // 4. 判断当前页面类型
    const url = window.location.href;
    const isFiatPage = url.includes('/settings/currency') ||
                       url.includes('/currency-selection') ||
                       document.querySelector('h1, h2, .title')?.textContent.includes('法定货币');

    const isCryptoPage = url.includes('/crypto') ||
                         document.querySelector('h1, h2, .title')?.textContent.includes('加密货币');

    // 5. 验证结果
    console.log('\n' + '='.repeat(60));
    if (isFiatPage) {
      console.log('📄 当前页面: 法定货币管理');
      if (foundProblems.length === 0) {
        console.log('✅ 验证通过: 法币页面中没有加密货币！');
      } else {
        console.log('❌ 验证失败: 法币页面中出现了加密货币:', foundProblems.join(', '));
        console.log('⚠️  这些货币应该只出现在加密货币页面中！');
      }
    } else if (isCryptoPage) {
      console.log('📄 当前页面: 加密货币管理');
      if (foundProblems.length > 0) {
        console.log('✅ 验证通过: 加密货币页面正确显示加密货币！');
        console.log('找到的加密货币:', foundProblems.join(', '));
      } else {
        console.log('⚠️  加密货币页面中没有找到预期的加密货币');
        console.log('这可能是因为页面还在加载或者没有启用这些货币');
      }
    } else {
      console.log('📄 当前页面: 其他页面');
      console.log('提示: 请导航到"法定货币管理"或"加密货币管理"页面进行验证');
    }
    console.log('='.repeat(60));

    // 6. 检查 localStorage 中的数据
    console.log('\n💾 检查本地缓存数据:');
    const storageKeys = Object.keys(localStorage);
    const currencyKeys = storageKeys.filter(key =>
      key.includes('currency') || key.includes('Currency')
    );

    if (currencyKeys.length > 0) {
      console.log('找到货币相关缓存键:', currencyKeys.join(', '));

      // 尝试解析缓存数据
      currencyKeys.forEach(key => {
        try {
          const data = JSON.parse(localStorage.getItem(key));
          if (Array.isArray(data)) {
            console.log(`\n📦 ${key}:`, data.length, '条记录');

            // 检查是否有 isCrypto 字段
            if (data.length > 0 && data[0].isCrypto !== undefined) {
              const cryptoCount = data.filter(c => c.isCrypto).length;
              const fiatCount = data.filter(c => !c.isCrypto).length;
              console.log(`  - 加密货币: ${cryptoCount}`);
              console.log(`  - 法定货币: ${fiatCount}`);

              // 检查问题货币
              const problemsInCache = data.filter(c =>
                problemCryptos.includes(c.code)
              );
              if (problemsInCache.length > 0) {
                console.log('  - 问题货币分类:');
                problemsInCache.forEach(c => {
                  console.log(`    ${c.code}: isCrypto=${c.isCrypto} ${c.isCrypto ? '✅' : '❌'}`);
                });
              }
            }
          }
        } catch (e) {
          // 忽略解析错误
        }
      });
    } else {
      console.log('未找到货币缓存数据');
    }

    // 7. 提供下一步建议
    console.log('\n📋 下一步验证建议:');
    console.log('1. 访问 http://localhost:3021/#/settings/currency (法定货币页面)');
    console.log('2. 确认只看到法币 (USD, EUR, CNY 等)，没有加密货币');
    console.log('3. 访问加密货币管理页面');
    console.log('4. 确认看到所有加密货币 (BTC, ETH, 1INCH, AAVE 等)');
    console.log('\n💡 如需重新验证，刷新页面后再次运行此脚本\n');

    return {
      success: true,
      pageType: isFiatPage ? 'fiat' : (isCryptoPage ? 'crypto' : 'other'),
      visibleCurrencies: uniqueCodes.length,
      problemCryptosFound: foundProblems,
      hasProblem: isFiatPage && foundProblems.length > 0
    };

  } catch (error) {
    console.error('❌ 验证过程出错:', error);
    return {
      success: false,
      error: error.message
    };
  }
})();
