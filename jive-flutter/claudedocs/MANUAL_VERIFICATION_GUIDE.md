# 货币功能手动验证指南

**日期**: 2025-10-11
**功能**: 两个货币管理新功能的验证指南

---

## 前提条件

确保服务正在运行：

```bash
# 检查API服务（端口8012）
curl http://localhost:8012/

# 检查Flutter Web服务（端口3021）
# 浏览器访问: http://localhost:3021
```

---

## 功能 1: 清除手动汇率后即时显示自动汇率

### 问题背景
- **之前**: 用户清除手动汇率后，需要刷新页面才能看到自动汇率
- **现在**: 清除手动汇率后，自动汇率立即显示，无需刷新

### 验证步骤

1. **登录应用**
   - 打开浏览器访问: http://localhost:3021
   - 使用测试账号登录：
     - Email: `testcurrency@example.com`
     - Password: `Test1234`

2. **进入多币种设置**
   - 点击底部导航栏的"设置"图标
   - 进入"多币种设置"页面
   - 如果未启用，打开"启用多币种"开关

3. **设置手动汇率**
   - 选择一个非基础货币（例如 USD）
   - 点击该货币进入详情
   - 设置一个手动汇率（例如 7.5000）
   - 保存设置

4. **验证手动汇率生效**
   - 返回货币列表
   - 确认该货币显示"手动汇率"标识
   - 记下当前显示的汇率值

5. **清除手动汇率**
   - 进入"手动汇率覆盖"页面
   - 点击"清除所有手动汇率"按钮
   - **关键观察点**: 无需刷新页面，自动汇率应该立即显示

6. **验证结果**
   - ✅ **通过**: 手动汇率清除后，自动汇率立即显示在界面上
   - ✅ **通过**: 汇率值变更为自动获取的值（通常与手动设置的值不同）
   - ✅ **通过**: 货币卡片上的"手动汇率"标识消失
   - ❌ **失败**: 如果需要刷新页面才能看到自动汇率

### 技术实现细节

**文件**: `lib/providers/currency_provider.dart` (lines 657-696)

**核心代码**:
```dart
Future<void> clearManualRates() async {
  final manualCodes = _manualRates.keys.toList();
  _manualRates.clear();
  await _hiveBox.delete('manual_rates');

  // ✅ 立即从缓存中移除旧的手动汇率
  for (final code in manualCodes) {
    _exchangeRates.remove(code);
  }

  // ✅ 触发UI立即重建
  state = state.copyWith();

  // ✅ 后台刷新自动汇率
  await refreshExchangeRates(forceRefresh: true);
}
```

**关键改进**:
1. 清除手动汇率后，立即从内存缓存中删除这些汇率
2. 触发状态更新，UI立即重建
3. 后台异步获取自动汇率并更新显示

---

## 功能 2: 手动汇率货币显示在基础货币下方

### 问题背景
- **之前**: 手动汇率的货币在列表中随机排序
- **现在**: 手动汇率的货币显示在基础货币的正下方，方便用户快速找到

### 验证步骤

1. **准备测试数据**
   - 登录应用（如已登录可跳过）
   - 确保多币种模式已启用
   - 清除所有现有的手动汇率（如有）

2. **设置多个手动汇率**
   - 选择2-3个不同的货币（例如 USD、EUR、JPY）
   - 为每个货币设置手动汇率
   - 保存设置

3. **进入货币选择页面**
   - 返回多币种设置主页
   - 点击"管理货币"或类似选项
   - 查看法定货币列表

4. **验证排序结果**
   - ✅ **通过**: 基础货币（例如 CNY）显示在列表最顶部
   - ✅ **通过**: 设置了手动汇率的货币（USD、EUR、JPY）紧跟在基础货币下方
   - ✅ **通过**: 其他没有手动汇率的货币显示在更下方
   - ✅ **通过**: 货币的排序顺序符合以下优先级：
     1. 基础货币
     2. 有手动汇率的货币
     3. 其他货币（按启用状态和名称排序）

5. **动态测试**
   - 添加一个新的手动汇率
   - 返回货币列表
   - **关键观察点**: 新添加手动汇率的货币应该自动移到基础货币下方

6. **清除测试**
   - 清除某个货币的手动汇率
   - 返回货币列表
   - **关键观察点**: 该货币应该从"手动汇率区"移到普通货币区

### 技术实现细节

**文件**: `lib/screens/management/currency_selection_page.dart` (lines 124-143)

**核心代码**:
```dart
fiatCurrencies.sort((a, b) {
  // 1️⃣ 基础货币永远排第一
  if (a.code == baseCurrency.code) return -1;
  if (b.code == baseCurrency.code) return 1;

  // 2️⃣ 有手动汇率的货币排第二
  final aIsManual = rates[a.code]?.source == 'manual';
  final bIsManual = rates[b.code]?.source == 'manual';
  if (aIsManual != bIsManual) return aIsManual ? -1 : 1;

  // 3️⃣ 启用状态优先
  final aEnabled = enabledCurrencies.contains(a.code);
  final bEnabled = enabledCurrencies.contains(b.code);
  if (aEnabled != bEnabled) return aEnabled ? -1 : 1;

  // 4️⃣ 按名称排序
  return a.name.compareTo(b.name);
});
```

**关键改进**:
1. 三级排序优先级
2. 手动汇率货币优先于其他货币
3. 动态响应手动汇率的添加和删除

---

## 预期UI效果示例

### 功能1 - 清除手动汇率前后对比

**清除前**:
```
USD  美元
汇率: 7.5000
来源: 手动设置 [标识]
```

**清除后（立即显示，无需刷新）**:
```
USD  美元
汇率: 7.1364
来源: 自动获取
最后更新: 刚刚
```

### 功能2 - 货币列表排序示例

**设置手动汇率后的列表顺序**:
```
1. ⭐ CNY 人民币 (基础货币)

2. 📌 USD 美元 (手动汇率: 7.5000)
3. 📌 EUR 欧元 (手动汇率: 8.2000)
4. 📌 JPY 日元 (手动汇率: 0.0520)

5. GBP 英镑 (自动汇率)
6. AUD 澳元 (自动汇率)
7. CAD 加元 (自动汇率)
...
```

---

## 故障排查

### 功能1 问题

**问题**: 清除手动汇率后，自动汇率没有立即显示

**可能原因**:
1. 网络延迟导致后台刷新失败
2. 缓存未正确清除
3. 状态更新未触发UI重建

**解决方法**:
1. 检查浏览器控制台是否有错误
2. 检查网络请求是否成功
3. 手动刷新页面验证数据是否正确

### 功能2 问题

**问题**: 手动汇率货币没有显示在基础货币下方

**可能原因**:
1. 汇率数据中的`source`字段不是'manual'
2. 排序逻辑未正确执行
3. 货币列表未刷新

**解决方法**:
1. 检查`exchangeRateObjectsProvider`返回的数据
2. 验证`rates[code]?.source`的值
3. 查看浏览器控制台日志

---

## API验证（可选）

如果需要通过API验证功能，可以使用以下命令：

```bash
# 1. 登录获取Token
TOKEN=$(curl -s -X POST 'http://localhost:8012/api/v1/auth/login' \
  -H 'Content-Type: application/json' \
  -d '{"email": "testcurrency@example.com", "password": "Test1234"}' \
  | jq -r '.token')

# 2. 设置手动汇率
curl -X POST "http://localhost:8012/api/v1/currencies/manual-rate" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"from_currency": "CNY", "to_currency": "USD", "rate": "7.5000"}'

# 3. 查询汇率（应显示手动汇率）
curl -X GET "http://localhost:8012/api/v1/currencies/rate?from=CNY&to=USD" \
  -H "Authorization: Bearer $TOKEN" | jq .

# 4. 清除手动汇率
curl -X DELETE "http://localhost:8012/api/v1/currencies/manual-rates/clear" \
  -H "Authorization: Bearer $TOKEN"

# 5. 再次查询（应显示自动汇率）
curl -X GET "http://localhost:8012/api/v1/currencies/rate?from=CNY&to=USD" \
  -H "Authorization: Bearer $TOKEN" | jq .
```

---

## 总结

### 功能1: 即时显示自动汇率 ✅
- **实现文件**: `lib/providers/currency_provider.dart`
- **关键方法**: `clearManualRates()`
- **验证方式**: 清除手动汇率后观察UI是否立即更新

### 功能2: 手动汇率货币排序 ✅
- **实现文件**: `lib/screens/management/currency_selection_page.dart`
- **关键逻辑**: 多级排序（基础货币 → 手动汇率 → 启用状态 → 名称）
- **验证方式**: 检查货币列表的显示顺序

两个功能都已完整实现，建议在实际应用中进行上述手动测试以确认功能正常工作。

---

**测试完成检查清单**:

- [ ] 功能1: 清除手动汇率后，自动汇率立即显示
- [ ] 功能1: 无需刷新页面
- [ ] 功能1: UI更新流畅无延迟
- [ ] 功能2: 基础货币显示在列表最顶部
- [ ] 功能2: 手动汇率货币紧跟在基础货币下方
- [ ] 功能2: 添加/删除手动汇率时排序动态更新
- [ ] 功能2: 其他货币按正确优先级排序

**测试人员**: ___________
**测试日期**: ___________
**测试结果**: ⬜ 通过 ⬜ 失败 ⬜ 部分通过
**备注**: _______________________________
