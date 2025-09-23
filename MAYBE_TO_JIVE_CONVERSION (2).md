# Maybe 到 Jive 转换文档

## 项目概述

### 源项目：Maybe
- **架构**：Ruby on Rails 单体应用
- **定位**：开源个人财务管理应用
- **特色**：账户管理、交易追踪、多账本支持

### 目标项目：Jive
- **架构**：Flutter + Rust + WASM 微服务架构
- **定位**：现代化多平台财务管理应用
- **特色**：跨平台支持、高性能、现代化UI

## 架构转换对比

| 方面 | Maybe (Rails) | Jive (Flutter+Rust) |
|------|---------------|---------------------|
| 后端语言 | Ruby | Rust |
| 前端技术 | ERB + Stimulus | Flutter + Dart |
| 数据库 | PostgreSQL | PostgreSQL + 离线存储 |
| 部署方式 | 单体部署 | 微服务 + 客户端应用 |
| 平台支持 | Web | Android/iOS/鸿蒙/Windows/Mac/Linux/Web |
| 状态管理 | Rails Session | Riverpod + 本地状态 |
| 实时同步 | ActionCable | WebSocket + 离线优先 |

## 核心功能转换映射

### 1. 用户认证与授权
| Maybe 功能 | Jive 实现 | 转换状态 |
|-----------|----------|----------|
| User 模型 | UserService + Auth Domain | ✅ 已规划 |
| Session 管理 | AuthService + JWT | ✅ 已规划 |
| 密码重置 | AuthService.resetPassword | ✅ 已规划 |
| 邀请系统 | UserService.inviteUser | ✅ 已规划 |

### 2. 账本管理
| Maybe 功能 | Jive 实现 | 转换状态 |
|-----------|----------|----------|
| Family 模型 | Ledger Domain | ✅ 已完成 |
| Current.family | LedgerService.switchLedger | ✅ 已完成 |
| 多用户共享 | LedgerService.inviteMember | ✅ 已完成 |
| 权限管理 | LedgerPermission 枚举 | ✅ 已完成 |

### 3. 账户管理
| Maybe 功能 | Jive 实现 | 转换状态 |
|-----------|----------|----------|
| Account 模型 | Account Domain | ✅ 已完成 |
| Accountable 多态 | AccountType 枚举 | ✅ 已完成 |
| 余额计算 | AccountService.updateBalance | ✅ 已完成 |
| 账户分组 | AccountService.groupByType | ✅ 已完成 |

### 4. 交易管理
| Maybe 功能 | Jive 实现 | 转换状态 |
|-----------|----------|----------|
| Transaction 模型 | Transaction Domain | ✅ 已完成 |
| Entry 模型 | Transaction.entries | ✅ 已完成 |
| 交易搜索 | TransactionService.search | ✅ 已完成 |
| 批量操作 | TransactionService.bulkUpdate | ✅ 已完成 |
| 标签系统 | Transaction.tags | ✅ 已完成 |

### 5. 分类管理
| Maybe 功能 | Jive 实现 | 转换状态 |
|-----------|----------|----------|
| Category 模型 | Category Domain | ✅ 已完成 |
| 分类层级 | CategoryService.getCategoryTree | ✅ 已完成 |
| 自动分类 | CategoryService.suggestCategory | ✅ 已完成 |
| 分类合并 | CategoryService.mergeCategories | ✅ 已完成 |

### 6. 数据导入导出
| Maybe 功能 | Jive 实现 | 转换状态 |
|-----------|----------|----------|
| CSV 导入 | ImportService.importCsv | 🔄 规划中 |
| Mint 导入 | ImportService.importMint | 🔄 规划中 |
| 数据导出 | ExportService.exportData | 🔄 规划中 |
| 同步服务 | SyncService | 🔄 规划中 |

### 7. 规则引擎
| Maybe 功能 | Jive 实现 | 转换状态 |
|-----------|----------|----------|
| Rule 模型 | RuleService | 🔄 规划中 |
| 条件匹配 | RuleService.evaluateRules | 🔄 规划中 |
| 自动执行 | RuleService.applyRules | 🔄 规划中 |

### 8. 报表分析
| Maybe 功能 | Jive 实现 | 转换状态 |
|-----------|----------|----------|
| 净值趋势 | ReportService.getNetWorthTrend | 🔄 规划中 |
| 支出分析 | ReportService.getExpenseAnalysis | 🔄 规划中 |
| 现金流 | ReportService.getCashFlow | 🔄 规划中 |

## 技术实现对比

### 数据模型
```ruby
# Maybe (Rails)
class Account < ApplicationRecord
  belongs_to :family
  has_many :entries
  monetize :balance_cents
end
```

```rust
// Jive (Rust)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Account {
    id: String,
    name: String,
    account_type: AccountType,
    balance: Decimal,
    currency: String,
    // ...
}
```

### 服务层
```ruby
# Maybe (Rails)
class AccountsController < ApplicationController
  def update_balance
    @account.update!(balance: params[:balance])
    redirect_to @account
  end
end
```

```rust
// Jive (Rust)
impl AccountService {
    pub async fn update_balance(
        &self,
        account_id: String,
        new_balance: String,
        context: ServiceContext,
    ) -> Result<Account> {
        // 业务逻辑实现
    }
}
```

### 前端交互
```erb
<!-- Maybe (ERB) -->
<%= form_with model: @account do |form| %>
  <%= form.number_field :balance %>
  <%= form.submit %>
<% end %>
```

```dart
// Jive (Flutter)
class AccountForm extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Form(
      child: Column(
        children: [
          TextFormField(
            decoration: InputDecoration(labelText: 'Balance'),
            onSaved: (value) => // 保存逻辑,
          ),
          ElevatedButton(
            onPressed: () => ref.read(accountProvider.notifier).updateBalance(),
            child: Text('Save'),
          ),
        ],
      ),
    );
  }
}
```

## 架构优势

### 1. 性能提升
- **Rust 核心**：内存安全 + 零成本抽象
- **WASM 执行**：接近原生性能
- **Flutter 渲染**：60fps 流畅体验

### 2. 平台支持
- **一套代码**：支持所有主流平台
- **原生体验**：每个平台的原生UI规范
- **离线优先**：本地数据存储和同步

### 3. 可维护性
- **类型安全**：Rust 强类型系统
- **模块化**：清晰的服务边界
- **测试友好**：单元测试和集成测试

### 4. 扩展性
- **微服务架构**：独立部署和扩展
- **插件系统**：支持第三方扩展
- **API 优先**：RESTful + GraphQL

## 迁移计划

### 阶段 1：核心服务（已完成）
- ✅ 域模型设计
- ✅ 核心服务实现
- ✅ WASM 绑定

### 阶段 2：扩展服务（进行中）
- 🔄 用户认证服务
- 🔄 数据同步服务
- 🔄 导入导出服务
- 🔄 规则引擎服务

### 阶段 3：UI 实现（规划中）
- 📋 Flutter UI 组件库
- 📋 状态管理实现
- 📋 路由和导航
- 📋 主题和国际化

### 阶段 4：集成测试（规划中）
- 📋 单元测试覆盖
- 📋 集成测试
- 📋 性能测试
- 📋 用户验收测试

### 阶段 5：部署上线（规划中）
- 📋 CI/CD 流水线
- 📋 多平台打包
- 📋 应用商店发布
- 📋 Web 部署

## 开发指南

### 环境搭建
```bash
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 安装 Flutter
git clone https://github.com/flutter/flutter.git
export PATH="$PWD/flutter/bin:$PATH"

# 安装依赖
cd jive-core && cargo build
cd ../jive-flutter && flutter pub get
```

### 开发流程
1. **Rust 核心开发**：实现业务逻辑和 WASM 绑定
2. **Flutter UI 开发**：创建用户界面和交互
3. **集成测试**：确保 Rust 和 Flutter 正确协作
4. **性能优化**：分析和优化关键路径

### 代码规范
- **Rust**：遵循 Rustfmt 和 Clippy 规范
- **Dart**：遵循 Dart 官方代码规范
- **文档**：所有公共 API 必须有文档注释
- **测试**：核心功能必须有单元测试覆盖

## 风险评估

### 技术风险
- **学习曲线**：团队需要学习 Rust 和 Flutter
- **工具链成熟度**：flutter_rust_bridge 相对较新
- **调试复杂性**：跨语言调试可能较困难

### 缓解措施
- **渐进迁移**：分阶段完成转换
- **原型验证**：先验证关键技术栈
- **备选方案**：准备回退到纯 Flutter 方案

## 成功指标

### 性能指标
- 启动时间 < 2秒
- 页面切换 < 100ms
- 内存使用 < 100MB
- 电池续航影响 < 5%

### 功能指标
- 功能覆盖率 100%（与 Maybe 对等）
- 离线支持 90% 功能可用
- 数据同步准确率 99.9%
- 多平台一致性 95%

### 质量指标
- 代码覆盖率 > 80%
- 用户满意度 > 4.5/5
- 崩溃率 < 0.1%
- 安全漏洞 = 0

## 结论

Maybe 到 Jive 的转换是一次重大的架构升级，将带来：

1. **技术现代化**：从传统 Web 应用升级到现代多平台应用
2. **性能提升**：显著改善用户体验和应用性能
3. **功能扩展**：支持更多平台和使用场景
4. **维护优化**：更好的代码组织和测试覆盖

通过分阶段实施和风险控制，这次转换将为用户提供更好的财务管理体验。