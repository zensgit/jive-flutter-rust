# 货币名称显示优化报告

**日期**: 2025-10-10 01:45
**状态**: ✅ 已完成

## 🎯 用户需求

在中文界面下，货币列表应该**优先显示中文名称**，而不是货币代码。

### 修改前 ❌
```
标题: USD
副标题: 美元
```

### 修改后 ✅
```
标题: 美元
副标题: $ · USD
```

## 📝 修改内容

### 文件: `lib/screens/management/currency_selection_page.dart`

#### 修改 1: 基础货币选择页面（ListTile）
**位置**: 第 196-213 行

```dart
// 修改前
Text(currency.code, ...)  // 显示 "USD"
subtitle: Text(currency.nameZh, ...)  // 显示 "美元"

// 修改后  
Text(currency.nameZh, ...)  // 显示 "美元"
subtitle: Text('${currency.symbol} · ${currency.code}', ...)  // 显示 "$ · USD"
```

#### 修改 2: 普通货币列表（ExpansionTile）
**位置**: 第 275-301 行

```dart
// 修改前
Text(currency.code, ...)  // 显示 "CNY"
Text(currency.nameZh, ...)  // 显示 "人民币"

// 修改后
Text(currency.nameZh, ...)  // 显示 "人民币"  
Text('${currency.symbol} · ${currency.code}', ...)  // 显示 "¥ · CNY"
```

## 📊 显示效果

| 货币 | 主标题 | 副标题 | 标签 |
|-----|--------|--------|------|
| 美元 | 美元 | $ · USD | USD |
| 人民币 | 人民币 | ¥ · CNY | CNY |
| 阿联酋迪拉姆 | 阿联酋迪拉姆 | د.إ · AED | AED |
| 欧元 | 欧元 | € · EUR | EUR |

## ✅ 优势

1. **直观性**：用户直接看到货币中文名
2. **完整性**：副标题包含符号和代码，信息不丢失
3. **一致性**：两种列表样式都统一使用中文名
4. **国际化友好**：未来可根据语言环境动态切换 name/nameZh

## 🚀 应用状态

- ✅ Flutter 应用运行中: http://localhost:3021
- ✅ 代码修改完成
- ✅ 等待用户验证

---

**修改完成**: 2025-10-10 01:45
**影响范围**: 法定货币选择页面、基础货币选择页面
