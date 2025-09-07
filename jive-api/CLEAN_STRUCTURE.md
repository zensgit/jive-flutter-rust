# Jive Money API - 清理后的文件结构

## ✅ 当前文件结构（已清理）

```
src/
├── main.rs              # 🌟 主程序（完整版，包含 WebSocket）
├── main_simple.rs       # 精简测试版（无认证）
├── main_simple_ws.rs    # 精简版带认证（无 WebSocket）
├── auth.rs              # JWT 认证模块
├── error.rs             # 错误处理模块
├── lib.rs               # 库定义文件
├── ws.rs                # WebSocket 实现
│
├── bin/                 # 命令行工具
│   ├── generate_password.rs  # 密码生成工具
│   └── hash_password.rs      # 密码哈希工具
│
├── handlers/            # API 处理器
│   ├── mod.rs
│   ├── accounts.rs      # 账户管理
│   ├── auth.rs          # 认证处理
│   ├── auth_handler.rs  # 认证辅助
│   ├── transactions.rs  # 交易管理
│   ├── payees.rs        # 收款人管理
│   ├── rules.rs         # 规则引擎
│   ├── ledgers.rs       # 账本管理
│   ├── template_handler.rs    # 模板管理
│   ├── family_handler.rs      # 家庭管理
│   ├── member_handler.rs      # 成员管理
│   ├── invitation_handler.rs  # 邀请管理
│   └── audit_handler.rs       # 审计日志
│
├── models/              # 数据模型
│   ├── mod.rs
│   ├── audit.rs         # 审计模型
│   ├── family.rs        # 家庭模型
│   ├── invitation.rs    # 邀请模型
│   ├── membership.rs    # 成员关系
│   └── permission.rs    # 权限模型
│
├── services/            # 业务服务
│   ├── mod.rs
│   ├── auth_service.rs         # 认证服务
│   ├── family_service.rs       # 家庭服务
│   ├── member_service.rs       # 成员服务
│   ├── invitation_service.rs   # 邀请服务
│   ├── audit_service.rs        # 审计服务
│   ├── transaction_service.rs  # 交易服务
│   ├── budget_service.rs       # 预算服务
│   ├── context.rs              # 服务上下文
│   └── error.rs                # 服务错误
│
└── middleware/          # 中间件
    ├── mod.rs
    ├── auth_check.rs    # 认证检查
    ├── permission_check.rs  # 权限检查
    └── cors.rs          # CORS 配置
```

## 🗑️ 已删除的无用文件

以下文件已被删除，因为它们没有被使用：

1. **config.rs** - 配置文件（未使用）
2. **routes.rs** - 旧路由定义（已被内联）
3. **routes_with_permissions.rs** - 权限路由（未使用）
4. **websocket.rs** - 旧 WebSocket 实现（已被 ws.rs 替代）
5. **db.rs** - 数据库模块（未使用）
6. **main_full.rs** - 早期尝试版本
7. **main_with_ws.rs** - 有问题的版本
8. **main_ws.rs** - 旧版本
9. **.DS_Store** - Mac 系统文件

## 📊 文件用途说明

### 核心文件
- **main.rs** - 主程序入口，完整功能版本
- **auth.rs** - JWT 令牌生成和验证
- **error.rs** - 统一错误处理
- **ws.rs** - WebSocket 连接管理

### 备选版本
- **main_simple.rs** - 快速测试用，模拟数据
- **main_simple_ws.rs** - 稳定备选版本

### 目录说明
- **handlers/** - 处理 HTTP 请求
- **models/** - 定义数据结构
- **services/** - 业务逻辑实现
- **middleware/** - 请求拦截和处理

## 🚀 使用建议

```bash
# 运行主程序（推荐）
cargo run --bin jive-api

# 运行精简版（测试）
cargo run --bin jive-api-simple

# 运行备选版本
cargo run --bin jive-api-core

# 生成密码哈希
cargo run --bin hash_password

# 生成随机密码
cargo run --bin generate_password
```

## ✨ 特点

- 文件结构清晰，没有冗余
- 模块职责分明
- 支持多种运行模式
- 包含实用工具

## 更新时间: 2025-09-07