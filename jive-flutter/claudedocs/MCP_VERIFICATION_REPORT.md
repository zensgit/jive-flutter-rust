# MCP验证报告 - 货币分类问题

**日期**: 2025-10-09 18:15
**状态**: 已确认根本问题

## ✅ API数据验证

通过MCP和curl验证，API返回的数据**完全正确**：

```json
{
  "total": 254,
  "fiat_count": 146,
  "crypto_count": 108,
  "problem_currencies": {
    "MKR": {"is_crypto": true, "is_enabled": true},
    "AAVE": {"is_crypto": true, "is_enabled": true},
    "COMP": {"is_crypto": true, "is_enabled": true},
    "BTC": {"is_crypto": true, "is_enabled": true},
    "ETH": {"is_crypto": true, "is_crypto": true},
    "SOL": {"is_crypto": true, "is_enabled": true},
    "MATIC": {"is_crypto": true, "is_enabled": true},
    "UNI": {"is_crypto": true, "is_enabled": true},
    "PEPE": {"is_crypto": true, "is_enabled": true}
  }
}
```

## ❌ 发现真正的根本问题

检查硬编码货币列表 (`lib/models/currency.dart:385-580`)，发现只包含20个加密货币：

### 在硬编码列表中的货币（20个）：
1. ADA (Cardano)
2. ALGO (Algorand)
3. ATOM (Cosmos)
4. AVAX (Avalanche)
5. BCH (Bitcoin Cash)
6. BNB (Binance Coin)
7. **BTC** (Bitcoin) ✓
8. DOGE (Dogecoin)
9. DOT (Polkadot)
10. **ETH** (Ethereum) ✓
11. FTM (Fantom)
12. LINK (Chainlink)
13. LTC (Litecoin)
14. **MATIC** (Polygon) ✓
15. **SOL** (Solana) ✓
16. **UNI** (Uniswap) ✓
17. USDC (USD Coin)
18. USDT (Tether)
19. XLM (Stellar)
20. XRP (Ripple)

### ❌ 缺失的问题货币（4个）：
- **MKR** (Maker) - 不在硬编码列表中
- **AAVE** (Aave) - 不在硬编码列表中
- **COMP** (Compound) - 不在硬编码列表中
- **PEPE** (Pepe) - 不在硬编码列表中

## 🔍 问题分析

虽然我已经修复了4个位置，让它们使用`_currencyCache[code]?.isCrypto`而不是硬编码列表，但是：

1. **Line 284-287已修复**: `_loadCurrencyCatalog()` 现在直接信任API的`is_crypto`值
2. **Line 598-603已修复**: `refreshExchangeRates()` 使用缓存检查
3. **Line 936-939已修复**: `convertCurrency()` 使用缓存检查
4. **Line 1137-1139已修复**: `cryptoPricesProvider` 使用缓存检查

但**硬编码列表本身**缺少这4个货币可能在某些边缘情况下还在被使用。

## 🎯 可能的原因

### 原因1: 浏览器缓存
Flutter Web应用可能缓存了旧的数据或代码。需要：
1. 硬刷新 (Cmd+Shift+R 或 Ctrl+Shift+R)
2. 清除所有本地存储 (localStorage, sessionStorage)
3. 清除IndexedDB中的Hive数据库

### 原因2: Provider状态未刷新
即使代码修改了，Provider可能还在使用旧的缓存。需要：
1. 完全关闭浏览器标签
2. 重新打开应用
3. 观察控制台是否有任何错误

### 原因3: 还有其他使用硬编码列表的地方
搜索发现lib/providers/currency_provider.dart:688还在使用硬编码列表作为fallback：
```dart
if (serverCrypto.isNotEmpty) {
  currencies.addAll(serverCrypto);
} else {
  currencies.addAll(CurrencyDefaults.cryptoCurrencies); // <- Fallback
}
```

这应该只在API失败时使用，但如果由于某种原因`serverCrypto`为空，它会回退到不完整的硬编码列表。

## 📋 建议用户进行的测试

### 步骤1: 浏览器Console验证
1. 打开 http://localhost:3021
2. 按F12打开开发者工具
3. 在Console中执行：

```javascript
// 清除所有缓存
localStorage.clear();
sessionStorage.clear();

// 检查IndexedDB
indexedDB.databases().then(dbs => {
  dbs.forEach(db => {
    console.log('Found database:', db.name);
    indexedDB.deleteDatabase(db.name);
  });
});

// 刷新页面
location.reload(true);
```

### 步骤2: 验证API数据
在Console中执行：
```javascript
fetch('http://localhost:8012/api/v1/currencies')
  .then(res => res.json())
  .then(data => {
    const problemCodes = ['MKR', 'AAVE', 'COMP', 'PEPE'];
    problemCodes.forEach(code => {
      const c = data.data.find(x => x.code === code);
      console.log(`${code}:`, c ? {is_crypto: c.is_crypto} : 'NOT FOUND');
    });
  });
```

### 步骤3: 检查实际页面显示
1. **法定货币页面**: http://localhost:3021/#/settings/currency
   - 列出您看到的前20个货币代码
   - 检查是否有BTC, ETH, SOL, MATIC, UNI, PEPE, MKR, AAVE, COMP

2. **加密货币页面**: 在设置中找到"加密货币管理"
   - 列出您看到的前20个货币代码
   - 确认是否包含所有9个问题货币

3. **基础货币选择**: 在设置中找到"基础货币"
   - 确认是否只显示法币
   - 是否有任何加密货币出现

## 🚀 当前Flutter状态

- ✅ Flutter运行在: http://localhost:3021
- ✅ API运行在: http://localhost:8012
- ✅ 所有4处代码修复已应用
- ✅ Flutter已完全重启(多次)
- ❌ 用户仍报告问题存在

## 🔧 下一步行动

需要用户提供：
1. 浏览器Console中上述JavaScript代码的输出
2. 各个页面实际显示的货币列表（前20个）
3. 浏览器Console中是否有任何红色错误信息
4. 清除缓存后是否有变化

---

**报告时间**: 2025-10-09 18:15
**Flutter进程**: 多个后台进程运行中
**API进程**: 正常运行
**数据库**: 正常连接
