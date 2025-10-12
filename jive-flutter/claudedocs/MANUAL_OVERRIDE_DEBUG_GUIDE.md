# 手动覆盖清单调试指南

**日期**: 2025-10-10 03:40
**问题**: 在"管理加密货币"页面设置了JPY的手动汇率,但在"手动覆盖清单"中显示"暂无手动覆盖"

---

## 🔍 问题诊断

### 系统设计逻辑

**手动汇率的设计原理**:
1. ✅ **仅针对当天**: 手动汇率总是插入今天的日期 (`date = CURRENT_DATE`)
2. ✅ **查询当天**: 查询也只查询今天的手动汇率
3. ✅ **自动过期**: 超过 `manual_rate_expiry` 时间后自动失效

**相关代码**:
- **插入**: `jive-api/src/services/currency_service.rs:372`
  ```rust
  let effective_date = Utc::now().date_naive();  // 使用今天的日期
  ```

- **查询**: `jive-api/src/handlers/currency_handler_enhanced.rs:339-342`
  ```sql
  WHERE from_currency = $1 AND date = CURRENT_DATE AND is_manual = true
    AND (manual_rate_expiry IS NULL OR manual_rate_expiry > NOW())
  ```

---

## 🐛 可能的原因

### 1. ❌ 手动汇率未成功保存

**检查方法**:
```sql
-- 直接查询数据库
SELECT from_currency, to_currency, rate, date, is_manual, manual_rate_expiry, updated_at
FROM exchange_rates
WHERE is_manual = true
ORDER BY updated_at DESC
LIMIT 20;
```

**预期结果**: 应该看到 JPY 的手动汇率记录

### 2. ❌ 基础货币不匹配

**问题**: 手动覆盖清单使用 `base_currency` 查询,但您可能设置的是其他币种对

**检查步骤**:
1. 确认您的基础货币是什么 (设置 → 多币种管理 → 基础货币)
2. 确认您设置的是 `基础货币 → JPY` 还是 `JPY → 其他货币`

**Flutter代码** (`manual_overrides_page.dart:31-32`):
```dart
final base = ref.read(baseCurrencyProvider).code;
final resp = await dio.get('/currencies/manual-overrides', queryParameters: {
  'base_currency': base,  // 只查询从基础货币出发的汇率
```

### 3. ❌ is_manual 标志未设置

**检查SQL**:
```sql
SELECT from_currency, to_currency, is_manual, source
FROM exchange_rates
WHERE to_currency = 'JPY' AND date = CURRENT_DATE;
```

**预期**: `is_manual` 应该是 `true`, `source` 应该是 `'manual'`

### 4. ❌ 手动汇率已过期

如果您设置的 `manual_rate_expiry` 时间已经过去,则不会显示:

```sql
SELECT from_currency, to_currency, manual_rate_expiry, NOW()
FROM exchange_rates
WHERE to_currency = 'JPY' AND date = CURRENT_DATE AND is_manual = true;
```

---

## 📋 完整诊断SQL

请在数据库中执行以下查询:

```sql
-- 1. 检查是否有任何手动汇率记录
SELECT COUNT(*) as manual_rate_count
FROM exchange_rates
WHERE is_manual = true;

-- 2. 检查今天的手动汇率
SELECT from_currency, to_currency, rate, manual_rate_expiry, updated_at
FROM exchange_rates
WHERE date = CURRENT_DATE AND is_manual = true;

-- 3. 检查JPY相关的所有汇率
SELECT from_currency, to_currency, date, is_manual, source, rate, manual_rate_expiry
FROM exchange_rates
WHERE to_currency = 'JPY' OR from_currency = 'JPY'
ORDER BY date DESC, updated_at DESC
LIMIT 10;

-- 4. 检查您基础货币的手动汇率
-- (假设基础货币是CNY,请根据实际情况修改)
SELECT to_currency, rate, manual_rate_expiry, updated_at
FROM exchange_rates
WHERE from_currency = 'CNY'
  AND date = CURRENT_DATE
  AND is_manual = true
  AND (manual_rate_expiry IS NULL OR manual_rate_expiry > NOW());
```

---

## 🔧 手动测试步骤

### 测试场景: 设置 CNY → JPY 手动汇率

1. **确认基础货币**
   - 打开: 设置 → 多币种管理
   - 查看: 基础货币是什么 (假设是CNY)

2. **设置手动汇率**
   ```bash
   # 使用API直接测试
   curl -X POST http://localhost:18012/api/v1/currencies/rates/add \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer YOUR_TOKEN" \
     -d '{
       "from_currency": "CNY",
       "to_currency": "JPY",
       "rate": 20.5,
       "source": "manual",
       "manual_rate_expiry": "2025-10-11T00:00:00Z"
     }'
   ```

3. **查询手动覆盖**
   ```bash
   curl "http://localhost:18012/api/v1/currencies/manual-overrides?base_currency=CNY" \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

4. **预期结果**:
   ```json
   {
     "success": true,
     "data": {
       "base_currency": "CNY",
       "overrides": [
         {
           "to_currency": "JPY",
           "rate": "20.5",
           "manual_rate_expiry": "2025-10-11T00:00:00",
           "updated_at": "2025-10-10T03:40:00"
         }
       ]
     }
   }
   ```

---

## 🚨 常见误区

### 误区1: 在"管理加密货币"页面设置手动价格

**问题**: "管理加密货币"页面的手动价格功能是临时的,可能不会持久化到 `exchange_rates` 表

**位置**: `crypto_selection_page.dart:408-412`
```dart
// 这里可能只是临时设置价格,不一定保存到数据库
```

**建议**: 使用"多币种管理"页面的"手动设置"功能

### 误区2: 混淆"法定货币"和"加密货币"的手动汇率

- **法定货币**: 使用 `exchange_rates` 表, `is_crypto = false`
- **加密货币**: 可能使用不同的机制

**检查JPY是否被标记为加密货币**:
```sql
SELECT code, is_crypto, is_enabled
FROM currencies
WHERE code = 'JPY';
```

**预期**: `is_crypto` 应该是 `false`

### 误区3: 未在正确的位置设置

**正确位置**:
1. 设置 → 多币种管理
2. 点击"管理法定货币"
3. 找到JPY
4. 点击展开 → 设置手动汇率

---

## ✅ 验证步骤

### 步骤1: 在Flutter应用中设置手动汇率

1. 打开: 设置 → 多币种管理
2. 确认基础货币 (假设是CNY)
3. 点击"管理法定货币"
4. 找到JPY并展开
5. 点击"手动汇率"按钮
6. 输入汇率值 (如: 20.5)
7. 选择有效期 (如: 明天)
8. 点击"确定"

### 步骤2: 检查后端日志

查看 `jive-api` 的日志,确认API调用:
```bash
# 应该看到类似的日志
POST /api/v1/currencies/rates/add
{
  "from_currency": "CNY",
  "to_currency": "JPY",
  "rate": 20.5,
  "source": "manual",
  "manual_rate_expiry": "2025-10-11T00:00:00Z"
}
```

### 步骤3: 查看手动覆盖清单

1. 返回: 设置 → 多币种管理
2. 点击"手动覆盖清单"
3. 应该看到: `1 CNY = 20.5 JPY`

---

## 🎯 预期修复

如果问题确实存在,可能的修复方向:

### 方案1: 扩展查询范围

修改 `get_manual_overrides` 查询,不仅查询今天的:

```sql
-- 修改前
WHERE from_currency = $1 AND date = CURRENT_DATE AND is_manual = true

-- 修改后
WHERE from_currency = $1 AND is_manual = true
  AND (manual_rate_expiry IS NULL OR manual_rate_expiry > NOW())
```

### 方案2: 检查加密货币页面的手动价格功能

如果在"管理加密货币"页面设置的手动价格没有保存到数据库,需要:
1. 确认该功能是否应该保存
2. 如果应该保存,添加持久化逻辑

---

## 📊 调试信息收集

请提供以下信息以便进一步诊断:

1. **基础货币**: [您的基础货币代码]
2. **设置位置**: 在哪个页面设置的手动汇率?
   - [ ] 多币种管理 → 管理法定货币
   - [ ] 管理加密货币页面
3. **数据库查询结果**: 执行上述SQL的结果
4. **API响应**: 调用 `/currencies/manual-overrides` 的完整响应

---

**下一步**: 请执行上述诊断SQL并分享结果,我们可以进一步定位问题。
