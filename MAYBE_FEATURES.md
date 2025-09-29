# Maybe Finance 功能实现计划

基于 Maybe Finance 源码分析，为 Jive Money 提出以下功能实现计划：

## 核心功能对比

### 已分析的 Maybe Finance 核心特性

1. **净值追踪 (Net Worth Tracking)**
   - ✅ Balance Sheet 模型实现资产负债表
   - ✅ 实时计算净值 (assets - liabilities)
   - ✅ 历史净值趋势图表
   - ✅ 多币种支持与汇率转换

2. **投资管理 (Investment Portfolio)**
   - ✅ 多种投资账户类型 (股票、基金、债券、黄金等)
   - ✅ Holdings 持仓管理
   - ✅ Valuations 估值追踪
   - ✅ Trades 交易记录

3. **高级交易功能**
   - ✅ 交易拆分 (Transaction Splitting)
   - ✅ 报销管理 (Reimbursement Tracking)
   - ✅ 定时交易 (Scheduled Transactions)
   - ✅ 快速记账 (Quick Transaction Entry)
   - ✅ 交易标签系统 (Tagging System)
   - ✅ 附件管理 (Attachments)

4. **多账本支持 (Multi-Ledger)**
   - ✅ 账本切换
   - ✅ 账本级别的数据隔离
   - ✅ 账本模板

5. **自动化与规则**
   - ✅ 交易规则引擎
   - ✅ 自动分类
   - ✅ 智能默认值

## 实现优先级与分支规划

### 第一阶段：核心财务功能 (P0)

#### 1. feat/net-worth-tracking
```sql
-- 需要的数据表
CREATE TABLE valuations (
    id UUID PRIMARY KEY,
    account_id UUID REFERENCES accounts(id),
    amount DECIMAL(15,2),
    currency_id UUID REFERENCES currencies(id),
    valuation_date DATE,
    valuation_type VARCHAR(50) -- 'manual', 'market', 'automated'
);

CREATE TABLE balance_snapshots (
    id UUID PRIMARY KEY,
    family_id UUID REFERENCES families(id),
    snapshot_date DATE,
    total_assets DECIMAL(15,2),
    total_liabilities DECIMAL(15,2),
    net_worth DECIMAL(15,2),
    currency_id UUID REFERENCES currencies(id)
);
```

**实现要点：**
- 创建净值计算服务
- 实现资产负债表 API
- 添加历史趋势图表接口
- Flutter 端实现净值仪表板

#### 2. feat/investment-portfolio
```sql
-- 投资账户扩展
CREATE TABLE investment_accounts (
    id UUID PRIMARY KEY,
    account_id UUID REFERENCES accounts(id),
    investment_type VARCHAR(50), -- 'stocks', 'funds', 'bonds', 'crypto'
    broker_name VARCHAR(100),
    account_number VARCHAR(100)
);

CREATE TABLE holdings (
    id UUID PRIMARY KEY,
    investment_account_id UUID REFERENCES investment_accounts(id),
    security_id UUID REFERENCES securities(id),
    quantity DECIMAL(15,6),
    cost_basis DECIMAL(15,2),
    current_value DECIMAL(15,2),
    last_updated TIMESTAMPTZ
);

CREATE TABLE securities (
    id UUID PRIMARY KEY,
    symbol VARCHAR(20),
    name VARCHAR(200),
    type VARCHAR(50),
    exchange VARCHAR(50),
    currency_id UUID REFERENCES currencies(id)
);
```

### 第二阶段：交易增强功能 (P1)

#### 3. feat/transaction-splitting
```sql
CREATE TABLE transaction_splits (
    id UUID PRIMARY KEY,
    original_transaction_id UUID REFERENCES transactions(id),
    split_transaction_id UUID REFERENCES transactions(id),
    description TEXT,
    amount DECIMAL(15,2),
    percentage DECIMAL(5,2)
);
```

**功能点：**
- 支持按金额或百分比拆分
- 拆分后的子交易独立分类
- 保持原交易与子交易的关联

#### 4. feat/reimbursement-system
```sql
CREATE TABLE reimbursements (
    id UUID PRIMARY KEY,
    transaction_id UUID REFERENCES transactions(id),
    reimbursement_status VARCHAR(50), -- 'pending', 'submitted', 'approved', 'reimbursed'
    submitted_date DATE,
    approved_date DATE,
    reimbursed_date DATE,
    reimbursement_amount DECIMAL(15,2),
    batch_id UUID REFERENCES reimbursement_batches(id)
);

CREATE TABLE reimbursement_batches (
    id UUID PRIMARY KEY,
    family_id UUID REFERENCES families(id),
    batch_name VARCHAR(100),
    total_amount DECIMAL(15,2),
    status VARCHAR(50),
    created_date DATE
);
```

### 第三阶段：自动化与智能功能 (P2)

#### 5. feat/scheduled-transactions
```sql
CREATE TABLE scheduled_transactions (
    id UUID PRIMARY KEY,
    family_id UUID REFERENCES families(id),
    template_transaction_id UUID REFERENCES transactions(id),
    frequency VARCHAR(50), -- 'daily', 'weekly', 'monthly', 'yearly'
    next_date DATE,
    end_date DATE,
    is_active BOOLEAN
);
```

#### 6. feat/transaction-rules
```sql
CREATE TABLE transaction_rules (
    id UUID PRIMARY KEY,
    family_id UUID REFERENCES families(id),
    rule_name VARCHAR(100),
    conditions JSONB, -- 存储匹配条件
    actions JSONB, -- 存储执行动作
    priority INTEGER,
    is_active BOOLEAN
);

CREATE TABLE rule_logs (
    id UUID PRIMARY KEY,
    rule_id UUID REFERENCES transaction_rules(id),
    transaction_id UUID REFERENCES transactions(id),
    applied_at TIMESTAMPTZ,
    actions_taken JSONB
);
```

### 第四阶段：用户体验增强 (P3)

#### 7. feat/quick-transaction
- 快速记账按钮 (FAB)
- 智能建议与自动填充
- 最近交易模板
- 语音输入支持

#### 8. feat/advanced-tagging
```sql
CREATE TABLE tag_groups (
    id UUID PRIMARY KEY,
    family_id UUID REFERENCES families(id),
    group_name VARCHAR(100),
    color VARCHAR(7)
);

CREATE TABLE tags (
    id UUID PRIMARY KEY,
    tag_group_id UUID REFERENCES tag_groups(id),
    tag_name VARCHAR(50),
    icon VARCHAR(50)
);

CREATE TABLE transaction_tags (
    transaction_id UUID REFERENCES transactions(id),
    tag_id UUID REFERENCES tags(id),
    PRIMARY KEY (transaction_id, tag_id)
);
```

## 技术实现建议

### 后端 (Rust/Axum)
1. **服务层架构**
   - `NetWorthService`: 净值计算与快照
   - `InvestmentService`: 投资组合管理
   - `TransactionEnhancementService`: 拆分、报销等
   - `AutomationService`: 规则引擎与定时任务

2. **性能优化**
   - 使用 Redis 缓存净值计算结果
   - 批量处理交易规则
   - 异步处理估值更新

### 前端 (Flutter)
1. **新增页面**
   - 净值仪表板
   - 投资组合页
   - 交易详情增强页
   - 规则管理页

2. **组件开发**
   - 净值趋势图表组件
   - 持仓列表组件
   - 交易拆分对话框
   - 快速记账浮动按钮

## 实施时间表

| 阶段 | 功能分支 | 预计工时 | 优先级 |
|------|----------|----------|---------|
| 1 | feat/net-worth-tracking | 2周 | P0 |
| 1 | feat/investment-portfolio | 3周 | P0 |
| 2 | feat/transaction-splitting | 1周 | P1 |
| 2 | feat/reimbursement-system | 1.5周 | P1 |
| 3 | feat/scheduled-transactions | 1周 | P2 |
| 3 | feat/transaction-rules | 2周 | P2 |
| 4 | feat/quick-transaction | 1周 | P3 |
| 4 | feat/advanced-tagging | 1周 | P3 |

## Maybe Finance 精华功能总结

### 值得借鉴的设计模式
1. **Delegated Types** - 账户的多态设计
2. **Concern Modules** - 功能模块化 (Monetizable, Chartable, Syncable)
3. **Service Objects** - 业务逻辑封装
4. **State Machines** - 账户状态管理 (AASM)

### 数据模型亮点
1. **Entry 模式** - 统一的记账凭证设计
2. **Classification** - 资产/负债分类
3. **Accountable** - 账户类型多态
4. **Taggable** - 灵活的标签系统

### 用户体验创新
1. **Quick Add Button** - 快速记账入口
2. **Sankey Diagram** - 收支流向可视化
3. **Smart Defaults** - 智能默认值
4. **Batch Operations** - 批量操作支持

## 下一步行动

1. ✅ 创建 feat/net-worth-tracking 分支
2. ⏳ 实现净值计算服务
3. ⏳ 添加资产负债表 API
4. ⏳ 开发 Flutter 净值仪表板

## 参考文件
- Maybe Finance 源码：`/Users/huazhou/Library/CloudStorage/SynologyDrive-mac/github/maybe-main`
- 核心模型：
  - `app/models/account.rb` - 账户模型
  - `app/models/transaction.rb` - 交易模型
  - `app/models/investment.rb` - 投资账户
  - `app/models/balance_sheet.rb` - 资产负债表