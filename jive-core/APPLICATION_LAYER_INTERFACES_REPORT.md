# 应用层接口定义开发报告

## 任务概述

**任务编号**: Task 2
**任务名称**: 定义应用层接口（Commands, Results, Services）
**开发日期**: 2025-10-14
**开发状态**: ✅ 已完成

## 开发目标

为实现"接口先行"设计策略，在 jive-core 应用层定义清晰的接口契约，确保：
1. **命令对象**（Commands）- 封装用户意图的不可变 DTO
2. **结果对象**（Results）- 结构化的执行结果
3. **服务接口**（Service Traits）- 定义应用服务契约
4. **防止重复实现** - API 层仅需调用应用层，避免直接实现业务逻辑

## 架构设计原则

### 接口先行策略

```
┌─────────────────────────────────────────────────┐
│          Phase 1: 接口冻结 (本任务)               │
│  ┌──────────────┐  ┌───────────────┐            │
│  │  Commands    │  │    Results    │            │
│  │  (输入契约)   │  │   (输出契约)   │            │
│  └──────────────┘  └───────────────┘            │
│           ↓                 ↑                    │
│  ┌──────────────────────────────────┐           │
│  │  Service Traits (行为契约)        │           │
│  └──────────────────────────────────┘           │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│        Phase 2-3: 实现层 (未来任务)              │
│  ┌──────────────────────────────────┐           │
│  │  Service Implementation           │           │
│  │  (使用 Money, IDs, Domain Logic)  │           │
│  └──────────────────────────────────┘           │
└─────────────────────────────────────────────────┘
                     ↓
┌─────────────────────────────────────────────────┐
│         Phase 4: API 适配层 (未来任务)           │
│  ┌──────────────────────────────────┐           │
│  │  HTTP Handlers                    │           │
│  │  (调用 Service Traits)             │           │
│  └──────────────────────────────────┘           │
└─────────────────────────────────────────────────┘
```

### CQRS 模式

- **命令服务**（TransactionAppService）- 写操作（create, update, delete）
- **查询服务**（ReportingQueryService）- 读操作（list, search, count）
- **关注点分离** - 优化读写性能和可扩展性

## 已完成的文件

### 1. Commands 模块

**目录**: `/jive-core/src/application/commands/`

#### transaction_commands.rs

定义了 10 个命令对象：

| 命令 | 用途 | 幂等性键 |
|------|------|---------|
| `CreateTransactionCommand` | 创建单笔交易 | request_id |
| `UpdateTransactionCommand` | 更新交易 | request_id |
| `TransferCommand` | 账户间转账 | request_id |
| `SplitTransactionCommand` | 拆分交易到多个分类 | request_id |
| `DeleteTransactionCommand` | 软删除交易 | request_id |
| `RestoreTransactionCommand` | 恢复已删除交易 | request_id |
| `BulkImportTransactionsCommand` | 批量导入 | request_id + external_id |
| `SettleTransactionsCommand` | 结算待处理交易 | request_id |
| `ReconcileTransactionsCommand` | 对账 | request_id |

**核心特性**:
- ✅ 所有命令都是不可变的（immutable）
- ✅ 使用强类型 ID（AccountId, TransactionId, etc.）
- ✅ 使用 Money 值对象保证金额精度
- ✅ 幂等性设计（RequestId）
- ✅ 完整的文档和示例

**示例代码**:

```rust
let cmd = CreateTransactionCommand {
    request_id: RequestId::new(),
    ledger_id: LedgerId::new(),
    account_id: AccountId::new(),
    name: "Grocery shopping".to_string(),
    description: Some("Weekly groceries".to_string()),
    amount: Money::new(
        Decimal::from_str("150.00").unwrap(),
        CurrencyCode::USD
    ).unwrap(),
    date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
    transaction_type: TransactionType::Expense,
    category_id: Some(CategoryId::new()),
    payee_id: None,
    status: None,
    tags: vec![],
    notes: None,
};
```

---

### 2. Results 模块

**目录**: `/jive-core/src/application/results/`

#### transaction_results.rs

定义了 10 个结果对象：

| 结果 | 用途 | 包含数据 |
|------|------|---------|
| `TransactionResult` | 交易详情 | 交易信息 + 分录 + 余额 |
| `EntryResult` | 分录详情 | 账户 + 金额 + 余额 |
| `TransferResult` | 转账结果 | 源交易 + 目标交易 + 双方余额 |
| `SplitTransactionResult` | 拆分结果 | 原交易 + 拆分后交易列表 |
| `BulkImportResult` | 导入统计 | 成功/失败/跳过计数 + 错误详情 |
| `SettlementResult` | 结算结果 | 结算交易 ID 列表 |
| `ReconciliationResult` | 对账结果 | 账单余额 vs 计算余额 + 差异 |
| `DeleteResult` | 删除确认 | 交易 ID + 时间戳 |
| `RestoreResult` | 恢复确认 | 交易 ID + 时间戳 |
| `BalanceSummary` | 余额摘要 | 当前余额 + 待处理 + 可用余额 |

**核心特性**:
- ✅ 丰富的元数据（创建时间、更新时间）
- ✅ 包含相关实体（分录、余额变化）
- ✅ 统计信息（批量操作）
- ✅ 错误详情（导入失败原因）

**示例代码**:

```rust
pub struct TransactionResult {
    pub transaction_id: TransactionId,
    pub ledger_id: LedgerId,
    pub account_id: AccountId,
    pub name: String,
    pub amount: Money,
    pub date: NaiveDate,
    pub transaction_type: TransactionType,
    pub status: TransactionStatus,
    pub entries: Vec<EntryResult>,        // 相关分录
    pub new_balance: Money,                // 新余额
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
```

---

### 3. Services 模块

**目录**: `/jive-core/src/application/services/`

#### transaction_service.rs

定义了 2 个服务 trait：

##### TransactionAppService (命令服务)

提供 11 个方法：

```rust
#[async_trait]
pub trait TransactionAppService: Send + Sync {
    // 基础 CRUD
    async fn create_transaction(&self, cmd: CreateTransactionCommand)
        -> Result<TransactionResult>;

    async fn update_transaction(&self, cmd: UpdateTransactionCommand)
        -> Result<TransactionResult>;

    async fn delete_transaction(&self, cmd: DeleteTransactionCommand)
        -> Result<DeleteResult>;

    async fn restore_transaction(&self, cmd: RestoreTransactionCommand)
        -> Result<RestoreResult>;

    // 特殊操作
    async fn transfer(&self, cmd: TransferCommand)
        -> Result<TransferResult>;

    async fn split_transaction(&self, cmd: SplitTransactionCommand)
        -> Result<SplitTransactionResult>;

    // 批量操作
    async fn bulk_import(&self, cmd: BulkImportTransactionsCommand)
        -> Result<BulkImportResult>;

    // 状态管理
    async fn settle_transactions(&self, cmd: SettleTransactionsCommand)
        -> Result<SettlementResult>;

    async fn reconcile_transactions(&self, cmd: ReconcileTransactionsCommand)
        -> Result<ReconciliationResult>;

    // 查询
    async fn get_transaction(&self, id: TransactionId)
        -> Result<TransactionResult>;

    async fn get_balance_summary(&self, account_id: AccountId)
        -> Result<BalanceSummary>;
}
```

##### ReportingQueryService (查询服务)

提供 4 个方法：

```rust
#[async_trait]
pub trait ReportingQueryService: Send + Sync {
    // 列表查询
    async fn list_transactions(
        &self,
        account_id: AccountId,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
        limit: usize,
        offset: usize,
    ) -> Result<Vec<TransactionResult>>;

    async fn list_ledger_transactions(
        &self,
        ledger_id: LedgerId,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
        limit: usize,
        offset: usize,
    ) -> Result<Vec<TransactionResult>>;

    // 统计
    async fn count_transactions(
        &self,
        account_id: AccountId,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
    ) -> Result<usize>;

    // 搜索
    async fn search_transactions(
        &self,
        ledger_id: LedgerId,
        query: String,
        limit: usize,
    ) -> Result<Vec<TransactionResult>>;
}
```

**核心特性**:
- ✅ async_trait 支持异步操作
- ✅ Send + Sync 保证线程安全
- ✅ 完整的文档注释（每个方法的职责、验证规则、副作用）
- ✅ Mock 实现示例（用于测试）

---

## 模块组织

### application/mod.rs

```rust
// 应用层接口定义（Commands, Results, Service Traits）
pub mod commands;
pub mod results;
pub mod services;

// 导出所有应用服务 (现有实现)
pub mod account_service;
pub mod auth_service;
// ... 其他服务
```

### commands/mod.rs

```rust
pub mod transaction_commands;

pub use transaction_commands::*;
```

### results/mod.rs

```rust
pub mod transaction_results;

pub use transaction_results::*;
```

### services/mod.rs

```rust
pub mod transaction_service;

pub use transaction_service::*;
```

---

## 设计决策记录 (ADR)

### ADR-1: 接口先行策略

**背景**: 避免 API 层重复实现业务逻辑（如 jive-api 使用 f64）。

**决策**: 先定义 Commands、Results 和 Service Traits，冻结接口契约，再实现。

**理由**:
1. 明确边界 - API 层只能调用定义的接口
2. 防止绕过 - 没有实现就无法绕过
3. 文档先行 - 接口即文档，清晰表达意图

**后果**:
- ✅ API 层被迫使用正确的抽象（Money, IDs）
- ✅ 业务逻辑集中在应用层
- ⚠️ 需要先完成接口设计才能开始实现

### ADR-2: CQRS 分离

**背景**: 读写操作特性不同，优化需求不同。

**决策**: 分为 TransactionAppService（写）和 ReportingQueryService（读）。

**理由**:
1. 读写分离 - 优化各自性能
2. 扩展性 - 未来可独立扩展（读副本、CQRS 架构）
3. 清晰职责 - 命令改变状态，查询不改变状态

**后果**:
- ✅ 更清晰的接口语义
- ✅ 未来可独立优化读写
- ⚠️ 需要两个 trait 而不是一个

### ADR-3: 幂等性设计

**背景**: 网络不可靠，需要支持安全重试。

**决策**: 所有写命令都包含 `request_id: RequestId`。

**理由**:
1. 防止重复 - 相同 request_id 不重复执行
2. 审计追踪 - 可追踪请求来源
3. 分布式安全 - 支持微服务环境

**后果**:
- ✅ 安全的重试机制
- ✅ 防止网络问题导致的重复提交
- ⚠️ 需要实现幂等性存储（Task 3）

### ADR-4: 丰富的结果对象

**背景**: API 需要返回足够信息给客户端。

**决策**: Result 对象包含完整的交易信息、分录、余额变化等。

**理由**:
1. 减少往返 - 一次请求获取完整信息
2. 即时反馈 - 余额立即更新显示
3. 审计数据 - 包含时间戳、变更记录

**后果**:
- ✅ 更好的用户体验
- ✅ 减少网络请求
- ⚠️ 响应体积略大（可接受）

---

## 接口契约详解

### 幂等性保证

所有写操作使用 `request_id` 实现幂等性：

```rust
// 客户端生成唯一 request_id
let request_id = RequestId::new();

// 首次执行 - 创建交易
let result1 = service.create_transaction(cmd.clone()).await?;

// 重试（网络错误等）- 返回相同结果，不重复创建
let result2 = service.create_transaction(cmd.clone()).await?;

assert_eq!(result1.transaction_id, result2.transaction_id);
```

### 验证规则

Service trait 定义了每个方法的验证规则：

**CreateTransactionCommand 验证**:
- Account 必须存在且激活
- Ledger 必须存在且属于用户家庭
- Amount 必须符合货币精度规则
- Date 必须有效

**TransferCommand 验证**:
- 双方账户必须存在且激活
- 双方账户必须属于同一 Ledger
- 源账户余额必须充足
- 跨货币转账必须提供 fx_spec

### 余额更新语义

**收入 (Income)**:
```
新余额 = 当前余额 + 收入金额
```

**支出 (Expense)**:
```
新余额 = 当前余额 - 支出金额
```

**转账 (Transfer)**:
```
源账户: 新余额 = 当前余额 - 转账金额
目标账户: 新余额 = 当前余额 + 转账金额（或转换后金额）
```

### 错误处理

Service methods 返回 `Result<T>` ，错误类型为 `JiveError`:

```rust
match service.create_transaction(cmd).await {
    Ok(result) => {
        // 成功 - 处理 TransactionResult
        println!("Created: {}", result.transaction_id);
    }
    Err(JiveError::CurrencyMismatch { expected, actual }) => {
        // 货币不匹配错误
        eprintln!("Currency error: expected {}, got {}", expected, actual);
    }
    Err(JiveError::InsufficientBalance { .. }) => {
        // 余额不足
        eprintln!("Insufficient balance");
    }
    Err(e) => {
        // 其他错误
        eprintln!("Error: {}", e);
    }
}
```

---

## 测试策略

### 单元测试

已为 Commands 和 Results 提供基础测试：

**Commands 测试** (3 个测试):
- ✅ test_create_transaction_command
- ✅ test_transfer_command
- ✅ test_split_transaction_command

**Results 测试** (3 个测试):
- ✅ test_transaction_result
- ✅ test_bulk_import_result
- ✅ test_reconciliation_result_balanced

**Service 测试**:
- ✅ Mock 实现验证 trait 编译

### 集成测试（未来）

Task 3 完成后，将添加：
- 幂等性测试
- 余额正确性测试
- 并发安全性测试
- 跨货币转账测试

---

## 使用示例

### 示例 1: 创建交易

```rust
use jive_core::application::{commands::*, services::*};
use jive_core::domain::value_objects::money::{Money, CurrencyCode};
use jive_core::domain::ids::*;
use jive_core::domain::types::TransactionType;
use chrono::NaiveDate;
use rust_decimal::Decimal;
use std::str::FromStr;

// 1. 构造命令
let cmd = CreateTransactionCommand {
    request_id: RequestId::new(),
    ledger_id: LedgerId::new(),
    account_id: AccountId::new(),
    name: "Grocery Shopping".to_string(),
    description: Some("Weekly groceries at Walmart".to_string()),
    amount: Money::new(
        Decimal::from_str("125.50").unwrap(),
        CurrencyCode::USD
    ).unwrap(),
    date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
    transaction_type: TransactionType::Expense,
    category_id: Some(CategoryId::new()),
    payee_id: None,
    status: None,
    tags: vec!["food".to_string(), "groceries".to_string()],
    notes: None,
};

// 2. 调用服务
let service: Box<dyn TransactionAppService> = get_service();
let result = service.create_transaction(cmd).await?;

// 3. 处理结果
println!("Created transaction: {}", result.transaction_id);
println!("New balance: {}", result.new_balance.format());
println!("Entries created: {}", result.entries.len());
```

### 示例 2: 账户间转账

```rust
// 1. 构造转账命令
let cmd = TransferCommand {
    request_id: RequestId::new(),
    ledger_id: LedgerId::new(),
    from_account_id: checking_account_id,
    to_account_id: savings_account_id,
    amount: Money::new(
        Decimal::from_str("1000.00").unwrap(),
        CurrencyCode::USD
    ).unwrap(),
    date: NaiveDate::from_ymd_opt(2025, 10, 14).unwrap(),
    description: "Monthly savings transfer".to_string(),
    category_id: None,
    fx_spec: None,  // 同货币，无需汇率
    tags: vec!["savings".to_string()],
    notes: None,
};

// 2. 执行转账
let result = service.transfer(cmd).await?;

// 3. 查看双方余额
println!("From balance: {}", result.from_balance.format());
println!("To balance: {}", result.to_balance.format());
```

### 示例 3: 批量导入

```rust
// 1. 准备导入数据
let transactions = vec![
    ImportTransactionData {
        external_id: Some("CSV-001".to_string()),
        account_id: AccountId::new(),
        name: "Restaurant".to_string(),
        description: None,
        amount: Money::new(Decimal::from_str("45.00").unwrap(), CurrencyCode::USD).unwrap(),
        date: NaiveDate::from_ymd_opt(2025, 10, 10).unwrap(),
        transaction_type: TransactionType::Expense,
        category_id: Some(CategoryId::new()),
        payee_id: None,
        tags: vec![],
        notes: None,
    },
    // ... 更多交易
];

// 2. 构造导入命令
let cmd = BulkImportTransactionsCommand {
    request_id: RequestId::new(),
    ledger_id: LedgerId::new(),
    transactions,
    policy: ImportPolicy {
        upsert: false,
        conflict_strategy: ConflictStrategy::Skip,
    },
};

// 3. 执行导入
let result = service.bulk_import(cmd).await?;

// 4. 查看统计
println!("Total: {}", result.total);
println!("Imported: {}", result.imported);
println!("Skipped: {}", result.skipped);
println!("Failed: {}", result.failed);

// 5. 处理错误
for error in result.errors {
    eprintln!("Row {}: {}", error.row_index, error.error_message);
}
```

### 示例 4: 对账

```rust
// 1. 构造对账命令
let cmd = ReconcileTransactionsCommand {
    request_id: RequestId::new(),
    account_id: AccountId::new(),
    transaction_ids: vec![
        txn_id_1,
        txn_id_2,
        txn_id_3,
    ],
    statement_date: NaiveDate::from_ymd_opt(2025, 10, 31).unwrap(),
    statement_balance: Money::new(
        Decimal::from_str("5432.10").unwrap(),
        CurrencyCode::USD
    ).unwrap(),
};

// 2. 执行对账
let result = service.reconcile_transactions(cmd).await?;

// 3. 检查对账结果
if result.is_balanced {
    println!("✅ Reconciliation successful!");
} else {
    println!("⚠️ Discrepancy found:");
    println!("Statement: {}", result.statement_balance.format());
    println!("Computed: {}", result.computed_balance.format());
    println!("Difference: {}", result.difference.format());
}
```

---

## 编译验证

```bash
$ env SQLX_OFFLINE=true cargo build --lib
   Compiling jive-core v0.1.0
    Finished dev [unoptimized + debuginfo] target(s) in 2.15s
warning: `jive-core` (lib) generated 1 warning
```

**编译状态**: ✅ 成功
**警告数量**: 1 个（非关键）
**错误数量**: 0

```bash
$ env SQLX_OFFLINE=true cargo test --lib
running 61 tests
...
test result: ok. 61 passed; 0 failed; 0 ignored
```

**测试状态**: ✅ 全部通过

---

## API 与应用层映射

### HTTP -> Command 映射

```rust
// API Layer (jive-api/src/handlers/transaction_handler.rs)
async fn create_transaction(
    State(service): State<Arc<dyn TransactionAppService>>,
    Json(api_request): Json<CreateTransactionRequest>,
) -> Result<Json<ApiResponse<TransactionResponse>>, ApiError> {
    // 1. API Request -> Command (Adapter 层)
    let command = CreateTransactionCommand {
        request_id: RequestId::from_uuid(api_request.request_id),
        ledger_id: LedgerId::from_uuid(api_request.ledger_id),
        account_id: AccountId::from_uuid(api_request.account_id),
        name: api_request.name,
        description: api_request.description,
        amount: Money::new(api_request.amount, api_request.currency)?,
        date: api_request.date,
        transaction_type: api_request.transaction_type.parse()?,
        category_id: api_request.category_id.map(CategoryId::from_uuid),
        payee_id: api_request.payee_id.map(PayeeId::from_uuid),
        status: api_request.status,
        tags: api_request.tags,
        notes: api_request.notes,
    };

    // 2. 调用应用层服务
    let result = service.create_transaction(command).await?;

    // 3. Result -> API Response (Adapter 层)
    let response = TransactionResponse {
        id: result.transaction_id.as_uuid(),
        amount: result.amount.amount,
        currency: result.amount.currency.code().to_string(),
        new_balance: result.new_balance.amount,
        created_at: result.created_at,
        // ... 其他字段映射
    };

    Ok(Json(ApiResponse::success(response)))
}
```

### 关键点

1. **API 层职责**:
   - HTTP 请求解析
   - 认证/授权
   - API Request DTO → Command 转换
   - Result → API Response DTO 转换
   - HTTP 响应格式化

2. **应用层职责**:
   - 业务逻辑编排
   - 领域规则验证
   - 事务管理
   - 持久化调用
   - 事件发布

3. **防止越界**:
   - ❌ API 层不能直接操作 Repository
   - ❌ API 层不能直接实现业务逻辑
   - ✅ API 层只能调用 Service Traits
   - ✅ 所有金额使用 Money (不能用 f64)

---

## 对比分析：旧 vs 新

### 旧方式（jive-api 问题）

```rust
// ❌ 错误示例：API 直接实现业务逻辑
async fn create_transaction(
    State(pool): State<PgPool>,
    Json(data): Json<CreateTransactionData>,
) -> Result<Json<Transaction>> {
    // 直接使用 f64 - 精度问题！
    let amount: f64 = data.amount.parse()?;

    // 直接 SQL 操作 - 绕过领域层！
    let balance: f64 = sqlx::query_scalar("SELECT balance FROM accounts WHERE id = $1")
        .bind(&data.account_id)
        .fetch_one(&pool)
        .await?;

    // 直接计算余额 - 业务逻辑泄漏到 API 层！
    let new_balance = balance + amount;

    // 直接插入 - 没有幂等性保护！
    sqlx::query("INSERT INTO transactions ...")
        .execute(&pool)
        .await?;

    Ok(Json(transaction))
}
```

### 新方式（本任务设计）

```rust
// ✅ 正确示例：API 调用应用层
async fn create_transaction(
    State(service): State<Arc<dyn TransactionAppService>>,
    Json(data): Json<CreateTransactionData>,
) -> Result<Json<TransactionResponse>> {
    // 1. API DTO -> Command (使用 Money!)
    let command = CreateTransactionCommand {
        request_id: RequestId::new(),
        amount: Money::new(data.amount, data.currency)?,  // ✅ Decimal
        // ... 其他字段
    };

    // 2. 调用应用层（所有逻辑在这里）
    let result = service.create_transaction(command).await?;
    // ✅ 幂等性、验证、余额计算都在应用层完成

    // 3. Result -> API Response
    Ok(Json(TransactionResponse::from(result)))
}
```

---

## 下一步工作

根据总体计划，下一个任务是：

**Task 3: 创建基础设施补充（IdempotencyRepository）**

将包括：
1. 定义 IdempotencyRepository trait
2. 实现 PostgreSQL 幂等性存储
3. 实现 Redis 缓存幂等性存储
4. 创建幂等性中间件
5. 测试幂等性保证

---

## 总结

本次任务成功建立了应用层的接口契约，为后续实现奠定了坚实基础：

### ✅ 已完成

1. **Commands** - 9 个命令对象，封装用户意图
2. **Results** - 10 个结果对象，结构化响应
3. **Service Traits** - 2 个服务接口（命令/查询分离）
4. **文档完备** - 每个接口都有详细说明
5. **测试框架** - 基础测试和 Mock 实现

### 💡 关键价值

- **防止重复错误** - API 层无法绕过应用层直接实现逻辑
- **强制使用正确抽象** - 接口要求使用 Money, IDs
- **清晰的契约** - 输入输出明确定义
- **可测试性** - Mock 实现支持单元测试

### 📊 统计数据

- 新增文件: 6 个
- Commands: 9 个
- Results: 10 个
- Service 方法: 15 个
- 测试用例: 7 个
- 代码行数: ~800 行
- 编译时间: 2.15s
- 错误数: 0 ✅

---

**开发人**: Claude Code
**审核状态**: 待审核
**下一步**: Task 3 - 创建基础设施补充
