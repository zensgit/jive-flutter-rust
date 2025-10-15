# 手动汇率持久化问题分析

**日期**: 2025-10-11
**问题**: 手动汇率设置后不保存到数据库，且刷新页面后汇率值消失

---

## 🔍 根本原因分析

### 问题1: API调用失败（已修复）
**原因**: URL路径错误
- ❌ 错误: `/api/v1/currencies/rates/add`
- ✅ 正确: `/currencies/rates/add` (HttpClient自动添加前缀)

**修复位置**: `lib/providers/currency_provider.dart:586`

### 问题2: rethrow导致本地保存失败（已修复）
**原因**: API失败时抛出异常，阻止了Hive本地保存
- ❌ 之前: `rethrow` 会中断整个保存流程
- ✅ 修复: 移除rethrow，允许本地保存即使API失败

**修复位置**: `lib/providers/currency_provider.dart:595`

### 问题3: UI没有加载已保存的数据（已修复）✅
**原因**: 页面初始化时，没有从provider读取Hive中的手动汇率
-  `_localRateOverrides` Map为空
- 输入框初始化时使用自动汇率，而不是已保存的手动汇率

**问题位置**: `lib/screens/management/currency_selection_page.dart`
- Line 31: `final Map<String, double> _localRateOverrides = {};` - 初始为空
- Line 149-151: 原来没有检查rate source，现已修复

**修复方案**: 检查rate source是否为'manual'
- provider的`_loadExchangeRates()`已经将手动汇率叠加到`_exchangeRates`，并设置`source: 'manual'`
- UI在Line 150-151添加检查，优先使用manual source的汇率

---

## 🔧 需要的修复

### 方案1: 在initState中加载数据 ✅ 推荐
```dart
@override
void initState() {
  super.initState();
  _compact = widget.compact;
  // 加载已保存的手动汇率到本地state
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _loadSavedManualRates(); // 新增方法
    _fetchLatestRates();
  });
}

Future<void> _loadSavedManualRates() async {
  // 从provider的Hive存储中读取已保存的手动汇率
  final notifier = ref.read(currencyProvider.notifier);
  // 需要在CurrencyNotifier中添加getter来访问_manualRates
}
```

### 方案2: 从exchangeRates中读取 ✅ 更简单
由于`_loadExchangeRates()`已经将手动汇率叠加到`_exchangeRates`中：
```dart
// currency_provider.dart Line 429-437
if (_manualRates.isNotEmpty) {
  for (final entry in _manualRates.entries) {
    final code = entry.key;
    final value = entry.value;
    // ... 有效性检查
    if (isValid) {
      _exchangeRates[code] = ExchangeRate(..., source: 'manual');
    }
  }
}
```

所以UI应该检查`rateObj.source == 'manual'`并使用该汇率值：
```dart
// Line 115修改为:
final isManual = rateObj?.source == 'manual';
final displayRate = isManual ? rate : (_localRateOverrides[currency.code] ?? rate);
```

---

## 🧪 验证步骤

1. **清除旧数据测试**:
   ```bash
   # 清空Hive缓存
   rm -rf ~/.jive_money/hive_cache
   ```

2. **功能测试**:
   - 设置手动汇率 (如 JPY = 20.5)
   - 保存成功提示显示
   - 刷新浏览器
   - 再次进入"管理法定货币"页面
   - **预期**: 输入框应显示20.5，不是自动汇率

3. **数据库验证**:
   ```sql
   SELECT * FROM exchange_rates
   WHERE is_manual = true
   ORDER BY created_at DESC;
   ```

4. **Hive验证**:
   检查Flutter DevTools或调试日志中的`_manualRates` Map

---

## 📋 完整修复清单

- [x] 修复API路径 (`/currencies/rates/add`)
- [x] 移除rethrow，允许离线保存
- [x] 添加时间选择器（精确到分钟）
- [x] 更新显示格式（显示小时:分钟）
- [x] **从provider加载已保存的手动汇率到UI** ✅ 已修复
  - 修改位置: `currency_selection_page.dart:149-151`
  - 检查 `rateObj?.source == 'manual'` 并优先使用该汇率值
- [ ] 测试完整流程（等待用户验证）

---

## 💡 临时解决方案

在修复之前，用户可以：
1. 设置手动汇率后**不要刷新页面**
2. 或者每次都重新输入汇率值

但这不是理想体验，需要完整修复。

---

## ✅ 修复完成

**已实现**: Line 149-151的displayRate逻辑已修复，优先使用manual source的汇率。

**修复代码**:
```dart
// currency_selection_page.dart Line 149-151
final isManual = rateObj?.source == 'manual';
final displayRate = isManual ? rate : (_localRateOverrides[currency.code] ?? rate);
```

**测试说明**:
1. 访问 http://localhost:3021/#/settings/currency
2. 设置手动汇率（如 JPY = 20.5，有效期设置为将来某个时间）
3. 保存后，刷新浏览器
4. 再次进入"管理法定货币"页面
5. **预期结果**: 输入框应显示20.5（之前保存的手动汇率）

Flutter已重新启动，修复已生效。请测试并验证功能是否正常工作。
