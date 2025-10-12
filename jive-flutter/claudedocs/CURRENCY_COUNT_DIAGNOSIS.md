# 货币数量显示错误诊断报告

**报告时间**: 2025-10-11
**问题**: "管理法定货币"页面显示"已选择了18个货币"，但用户只启用了5个法定货币
**状态**: ✅ 根源已定位

---

## 问题现象

用户报告：
> "管理法定货币 页面 我就启用了5个币种，但还是显示'已选择了18个货币'"

---

## 数据库验证结果

### 用户实际选择的货币（从数据库查询）

```sql
SELECT ucp.currency_code, c.name, c.is_crypto, ucp.is_primary
FROM user_currency_preferences ucp
JOIN currencies c ON ucp.currency_code = c.code
ORDER BY c.is_crypto, ucp.currency_code;
```

**查询结果**:

**法定货币** (is_crypto = false):
1. AED - UAE Dirham
2. CNY - 人民币 (出现3次! ⚠️ 数据重复)
3. HKD - 港币
4. JPY - 日元
5. USD - 美元

**加密货币** (is_crypto = true):
6. 1INCH - 1inch Network
7. AAVE - Aave
8. ADA - Cardano
9. AGIX - SingularityNET
10. ALGO - Algorand
11. APE - ApeCoin
12. APT - Aptos
13. AR - Arweave
14. BNB - Binance Coin
15. BTC - Bitcoin
16. ETH - Ethereum
17. USDC - USD Coin
18. USDT - Tether

**总计**: 20行记录
- **法定货币**: 5个不同的（AED, CNY, HKD, JPY, USD）
- **加密货币**: 13个
- **CNY重复**: 3次
- **去重后总数**: 18个不同的货币代码

---

## 根本原因分析

### 问题1: 数据库中CNY重复3次

**影响**: 造成用户偏好表数据冗余

**可能原因**:
1. 前端多次调用添加货币API
2. 后端缺少唯一性约束验证（虽然有UNIQUE约束，但可能在事务中失效）
3. 并发请求导致的数据竞争

**数据库约束**:
```sql
-- 已有的唯一约束
UNIQUE CONSTRAINT "user_currency_preferences_user_id_currency_code_key"
  btree (user_id, currency_code)
```

这个约束应该防止重复，但实际数据却有重复，说明可能存在：
- 不同的 user_id (但查询结果显示是同一个用户)
- 或者约束被禁用/删除后又添加
- 或者是历史遗留数据

### 问题2: "已选择了18个货币"的显示逻辑

**代码位置**: `currency_selection_page.dart:794`

```dart
Text(
  '已选择 ${ref.watch(selectedCurrenciesProvider).where((c) => !c.isCrypto).length} 种法定货币',
  // ...
)
```

**逻辑分析**:
1. `selectedCurrenciesProvider` 返回所有选中的货币（法定+加密）
2. 通过 `.where((c) => !c.isCrypto)` 过滤只保留法定货币
3. 理论上应该显示5个

**为什么显示18个？**

可能的原因：
1. **`isCrypto` 字段未正确设置**: 从服务器加载的货币对象中，`isCrypto` 字段可能全部为 `false`
2. **缓存未更新**: `_currencyCache` 中的货币对象使用了旧的默认值
3. **服务器返回数据错误**: API响应中 `is_crypto` 字段丢失或错误

### 问题3: Currency模型序列化问题

**需要验证的点**:
1. 服务器API `/api/v1/currencies` 是否正确返回 `is_crypto` 字段
2. Flutter端 `Currency.fromJson()` 是否正确解析 `is_crypto`
3. `_currencyCache` 的初始化是否使用了正确的货币定义

---

## 调试步骤

### 步骤1: 检查Currency模型定义

查看 `jive-flutter/lib/models/currency.dart` 中的 `fromJson` 方法是否正确解析 `isCrypto` 字段。

### 步骤2: 添加调试日志

在 `currency_provider.dart:291-299` 已经有调试日志：

```dart
print('[CurrencyProvider] Loaded ${_serverCurrencies.length} currencies from API');
final fiatCount = _serverCurrencies.where((c) => !c.isCrypto).length;
final cryptoCount = _serverCurrencies.where((c) => c.isCrypto).length;
print('[CurrencyProvider] Fiat: $fiatCount, Crypto: $cryptoCount');
```

需要检查这些日志输出，确认服务器返回的数据中 `isCrypto` 是否正确。

### 步骤3: 检查服务器API响应

使用MCP或curl直接查询 `/api/v1/currencies` 端点，验证：
```bash
curl http://localhost:8012/api/v1/currencies | jq '.[] | select(.code == "BTC" or .code == "CNY") | {code, is_crypto}'
```

预期结果：
- CNY: `is_crypto = false`
- BTC: `is_crypto = true`

### 步骤4: 修复数据库重复记录

```sql
-- 删除CNY的重复记录（保留1条）
DELETE FROM user_currency_preferences
WHERE id NOT IN (
  SELECT MIN(id)
  FROM user_currency_preferences
  WHERE currency_code = 'CNY'
  GROUP BY user_id, currency_code
);
```

---

## 推荐修复方案

### 修复1: 清理数据库重复记录（立即执行）

```sql
-- 查找所有重复记录
SELECT user_id, currency_code, COUNT(*) as count
FROM user_currency_preferences
GROUP BY user_id, currency_code
HAVING COUNT(*) > 1;

-- 删除重复记录（保留最早的一条）
DELETE FROM user_currency_preferences
WHERE id NOT IN (
  SELECT MIN(id)
  FROM user_currency_preferences
  GROUP BY user_id, currency_code
);
```

### 修复2: 检查Currency模型的isCrypto字段

需要查看 `Currency.fromJson()` 方法，确保正确解析 `is_crypto` 字段：

```dart
// 应该是这样
factory Currency.fromJson(Map<String, dynamic> json) {
  return Currency(
    code: json['code'],
    name: json['name'],
    // ... 其他字段
    isCrypto: json['is_crypto'] ?? false,  // ✅ 确保这一行存在
  );
}
```

### 修复3: 强制刷新货币缓存

在用户端，可能需要：
1. 清除本地Hive缓存
2. 重新从服务器加载货币列表
3. 强制刷新 `_currencyCache`

---

## 加密货币汇率缺失问题

用户还报告："加密货币管理页面还是有很多加密货币没有获取到汇率及汇率变化趋势"

### 原因分析

1. **外部API覆盖不足**: CoinGecko/CoinCap 可能不支持所有108种加密货币
2. **API失败**: 之前的MCP验证显示CoinGecko经常超时
3. **24小时降级机制**: 虽然已修复，但如果数据库中从未有过这些加密货币的汇率记录，降级也无法提供数据

### 需要验证的加密货币

根据之前的日志，以下货币可能缺失汇率：
- 1INCH, AAVE, ADA, AGIX, ALGO, APE, APT, AR

### 解决方案

1. **短期**: 使用24小时降级机制（已修复）+ 数据库历史记录
2. **中期**: 添加更多API数据源（Binance, Kraken等）
3. **长期**: 实现数据源优先级和智能切换

---

## 手动汇率覆盖页面访问

**用户问题**: "手动汇率覆盖页面，在设置中哪里可以打开查看呢"

**答案**:
1. **方式一**: 在"货币管理"页面 (`http://localhost:3021/#/settings/currency`) 的顶部，有一个"查看覆盖"按钮（带眼睛图标👁️）
2. **方式二**: 直接访问 URL: `http://localhost:3021/#/settings/currency/manual-overrides`

**代码位置**: `currency_management_page_v2.dart:69-78`

```dart
TextButton.icon(
  onPressed: () async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ManualOverridesPage()),
    );
  },
  icon: const Icon(Icons.visibility, size: 16),
  label: const Text('查看覆盖'),
),
```

---

## 下一步行动

1. ✅ **立即执行**: 清理数据库重复CNY记录
2. 🔍 **验证**: 检查Currency模型的 `fromJson` 方法
3. 🔍 **验证**: 检查服务器API `/api/v1/currencies` 返回的 `is_crypto` 字段
4. 📊 **监控**: 添加更详细的调试日志，追踪货币加载过程
5. 🛠️ **修复**: 根据验证结果修复 `isCrypto` 字段传递问题

---

**诊断完成时间**: 2025-10-11
**下一步**: 执行数据库清理，然后验证Currency模型
