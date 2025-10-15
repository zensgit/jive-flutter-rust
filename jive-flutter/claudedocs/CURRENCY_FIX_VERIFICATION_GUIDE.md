# 货币数量显示问题验证指南

**创建时间**: 2025-10-11
**问题**: "管理法定货币"页面显示"已选择了18个货币"，但用户只启用了5个法定货币

---

## 🔍 已完成的调查

### ✅ 技术组件验证（全部正确）

1. **数据库** - 数据正确
   - superadmin用户: 5个法定货币 + 13个加密货币 = 18个总货币
   - 法定货币: AED, CNY, HKD, JPY, USD
   - 加密货币: 1INCH, AAVE, ADA, AGIX, ALGO, APE, APT, AR, BNB, BTC, ETH, USDC, USDT

2. **API** - 返回数据正确
   ```json
   {"code": "CNY", "is_crypto": false}  ✅
   {"code": "BTC", "is_crypto": true}   ✅
   ```

3. **Flutter代码** - 逻辑正确
   ```dart
   // currency_selection_page.dart:794-810
   final fiatCount = selectedCurrencies.where((c) => !c.isCrypto).length;
   Text('已选择 $fiatCount 种法定货币')
   ```

4. **调试日志** - 已添加详细输出
   - 行 98-108: 验证availableCurrencies过滤
   - 行 798-803: 验证selectedCurrenciesProvider内容

### ⚠️ 发现的问题

**401未授权错误**（从用户提供的日志）:
```
Error fetching preferences: Exception: Failed to load preferences: 401
```

这导致系统无法从服务器加载用户偏好设置，可能使用本地缓存或默认数据。

---

## 📋 验证步骤（请执行）

### 步骤1: 硬刷新浏览器

1. 在Chrome中访问: `http://localhost:3021/#/settings/currency`
2. 按 **Cmd + Shift + R** (Mac) 或 **Ctrl + Shift + R** (Windows/Linux)
3. 等待页面完全加载

### 步骤2: 打开浏览器开发者工具

1. 按 **F12** 或 **Right-click → 检查**
2. 切换到 **Console** 标签页

### 步骤3: 查看调试输出

查找以下两组日志：

**日志组1 - 页面过滤验证**:
```
[CurrencySelectionPage] Total currencies: 254
[CurrencySelectionPage] Fiat currencies: 146
[CurrencySelectionPage] ✅ OK: No crypto in fiat list
```

**日志组2 - 底部显示验证**（新添加的调试）:
```
[Bottom Stats] Total selected currencies: XX
[Bottom Stats] Fiat count: XX
[Bottom Stats] Selected currencies list:
  - CNY: isCrypto=false
  - USD: isCrypto=false
  - BTC: isCrypto=true
  ...
```

---

## 🤔 可能的问题根源

基于401错误和调查结果，可能的原因：

1. **认证Token过期** - 401 Unauthorized → 需要重新登录
2. **Hive本地缓存错误** - 缓存中混合了法币和加密货币
3. **默认数据使用** - 偏好加载失败时使用默认18种货币
4. **Provider状态同步问题** - selectedCurrenciesProvider与服务器数据不同步

---

## 📝 请提供以下信息

完成验证后，请告诉我：

1. **页面底部实际显示**: "已选择 XX 种法定货币"
2. **Console中[Bottom Stats]的输出** 
3. **是否看到401错误**: 是/否
4. **截图（可选）**: 页面底部显示的截图

---

**下一步**: 等待用户执行验证步骤并提供反馈
