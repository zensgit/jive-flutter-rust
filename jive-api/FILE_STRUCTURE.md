# Jive Money API 文件结构说明

## 📁 主程序文件 (src/)

### ✅ 活跃使用的文件

#### **main_complete.rs** 🌟
- **用途**: 完整版 API（推荐使用）
- **功能**: WebSocket + 所有功能
- **启动**: `cargo run --bin jive-api-complete`
- **状态**: ✅ 正在使用

#### **main_simple_ws.rs**
- **用途**: 精简版带认证
- **功能**: 核心 API + 认证，无 WebSocket
- **启动**: `cargo run --bin jive-api-core`
- **状态**: ✅ 备用版本

#### **main_simple.rs**
- **用途**: 最简化测试版
- **功能**: 仅模拟 API，用于快速测试
- **启动**: `cargo run --bin jive-api-simple`
- **状态**: ✅ 测试用

### ⚠️ 参考文件

#### **main.rs**
- **用途**: 原始完整版
- **状态**: ⚠️ 有编译问题，仅作参考
- **建议**: 可考虑删除或修复

## 📦 核心模块文件

### ✅ 必需的模块

- **error.rs** - 错误处理（ApiError, ApiResult）
- **auth.rs** - 认证功能（JWT, Claims）
- **ws.rs** - WebSocket 实现（新版）
- **lib.rs** - 库定义文件

### 📂 目录结构

```
src/
├── handlers/           # API 处理器
│   ├── accounts.rs
│   ├── auth.rs
│   ├── transactions.rs
│   ├── payees.rs
│   ├── rules.rs
│   ├── ledgers.rs
│   └── ...
├── models/            # 数据模型
│   ├── mod.rs
│   ├── family.rs
│   ├── membership.rs
│   └── ...
├── services/          # 业务服务
│   ├── mod.rs
│   ├── auth_service.rs
│   ├── family_service.rs
│   └── ...
├── middleware/        # 中间件
│   └── cors.rs
└── migrations/        # 数据库迁移

```

## 🗑️ 已删除的文件

以下文件已被删除，因为不再使用：

- **websocket.rs** - 旧的 WebSocket 实现，已被 ws.rs 替代
- **db.rs** - 未使用的数据库模块
- **main_full.rs** - 早期尝试版本
- **main_with_ws.rs** - 有问题的版本
- **main_ws.rs** - 旧版本

## 🚀 快速命令

```bash
# 查看所有可用的二进制目标
cargo build --bins

# 运行完整版（推荐）
cargo run --bin jive-api-complete

# 运行精简版
cargo run --bin jive-api-core

# 运行测试版
cargo run --bin jive-api-simple
```

## 📝 维护建议

1. **主要维护**: `main_complete.rs`
2. **保留备份**: `main_simple_ws.rs` 作为稳定备选
3. **测试用途**: `main_simple.rs` 用于快速测试
4. **考虑清理**: `main.rs` 可以删除或修复

## 更新日期: 2025-09-07