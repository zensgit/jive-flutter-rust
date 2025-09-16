# Jive Money API 版本说明

## 🎯 当前可用版本

### 1. **jive-api** ✅ (主程序，推荐)
- **文件**: `src/main.rs`
- **启动**: `./start-complete.sh` 或 `cargo run --bin jive-api`
- **功能**:
  - ✅ WebSocket 实时通信
  - ✅ 完整的业务 API
  - ✅ 账本管理 (Ledgers)
  - ✅ 用户认证系统
  - ✅ FromRef 适配层（兼容所有处理器）
- **状态**: **完全可用，推荐使用**

### 2. **jive-api-simple** ✅
- **文件**: `src/main_simple.rs`
- **启动**: `./start-api.sh` 或 `cargo run --bin jive-api-simple`
- **功能**:
  - ✅ 核心业务 API
  - ❌ 无 WebSocket
  - ❌ 无账本管理
- **状态**: 可用，适合不需要实时功能的场景

### 3. **jive-api-core** (jive-api-simple-ws) ✅
- **文件**: `src/main_simple_ws.rs`
- **启动**: `cargo run --bin jive-api-core`
- **功能**:
  - ✅ 完整的业务 API
  - ✅ 用户认证
  - ❌ 无 WebSocket
- **状态**: 可用，精简版带认证

### 4. **jive-api** ⚠️
- **文件**: `src/main.rs`
- **启动**: `cargo run --bin jive-api`
- **功能**: 原始完整版
- **状态**: 有编译问题，不推荐使用

## 🚀 快速启动

```bash
# 推荐：启动完整版（包含 WebSocket）
cd ~/jive-project/jive-api
./start-complete.sh

# 或者启动精简版（无 WebSocket）
./start-api.sh
```

## 📊 版本对比

| 功能 | complete | simple | core | main |
|-----|----------|--------|------|------|
| WebSocket | ✅ | ❌ | ❌ | ⚠️ |
| 数据库 | ✅ | ✅ | ✅ | ✅ |
| 认证 API | ✅ | ✅ | ✅ | ✅ |
| 账本管理 | ✅ | ❌ | ❌ | ✅ |
| 交易管理 | ✅ | ✅ | ✅ | ✅ |
| 规则引擎 | ✅ | ✅ | ✅ | ✅ |
| 编译状态 | ✅ | ✅ | ✅ | ❌ |

## 🗑️ 已删除的文件

以下文件已被删除以避免混淆：
- `main_full.rs` - 早期尝试版本，已被 main_complete.rs 替代
- `main_with_ws.rs` - 有编译问题的版本
- `main_ws.rs` - 旧的 WebSocket 版本

## 💡 开发建议

- **开发测试**: 使用 `jive-api-simple`（快速启动）
- **生产环境**: 使用 `jive-api-complete`（功能完整）
- **需要 WebSocket**: 必须使用 `jive-api-complete`

## 📝 环境变量

所有版本都支持以下环境变量：
```bash
RUST_LOG=info          # 日志级别
API_PORT=8012          # API 端口
DATABASE_URL=...       # 数据库连接字符串
HOST=127.0.0.1        # 监听地址（complete 版本）
```