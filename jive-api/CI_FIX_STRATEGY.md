# CI修复策略说明

## 当前问题
- CI环境中数据库字段定义为可空(`symbol VARCHAR(10)`, `base_currency VARCHAR(10)`)
- SQLx根据数据库模式生成类型为`Option<String>`
- 本地环境中相同字段被识别为`String`类型(可能是SQLx缓存不一致)

## 解决策略
1. 让CI重新生成正确的SQLx缓存文件，发现真实的数据库类型
2. 基于CI生成的缓存文件修复Rust代码，正确处理`Option<String>`类型
3. 提交包含正确SQLx缓存的版本

## 错误字段
- `currencies.symbol`: Option<String> (CI) vs String (本地)
- `family_currency_settings.base_currency`: Option<String> (CI) vs String (本地)

## 下一步
提交当前代码让CI失败并生成正确的SQLx缓存，然后下载缓存文件并修复代码。