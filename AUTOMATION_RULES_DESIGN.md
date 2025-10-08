# 自动化与规则系统设计

基于 Maybe Finance 的分析，为 Jive Money 设计自动化与规则功能

## Maybe Finance 核心设计理念

### 1. 规则引擎架构
Maybe Finance 采用了**条件-动作（Condition-Action）**模式：
- **Rule**: 规则主体，包含多个条件和动作
- **Condition**: 匹配条件（支持复合条件）
- **Action**: 执行动作（分类、标签、字段更新等）
- **Registry**: 注册中心，管理所有可用的条件过滤器和动作执行器
- **RuleLog**: 规则执行日志，追踪每次应用

### 2. 定时交易系统
- **ScheduledTransaction**: 定期交易模板
- **频率类型**: 一次性、每日、每周、每月、每年、自定义
- **结束条件**: 永不结束、指定日期、指定次数
- **智能功能**:
  - auto_pay: 自动创建交易
  - auto_skip: 自动跳过重复（防止银行同步重复）

## Jive Money 实现方案

### 第一部分：交易规则引擎 (feat/transaction-rules)

#### 数据库设计
```sql
-- 038: 交易规则引擎
-- 规则主表
CREATE TABLE transaction_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,

    -- 规则基本信息
    rule_name VARCHAR(100) NOT NULL,
    rule_description TEXT,
    resource_type VARCHAR(50) DEFAULT 'transaction', -- 可扩展到其他资源

    -- 优先级和状态
    priority INTEGER DEFAULT 100, -- 数字越小优先级越高
    is_active BOOLEAN DEFAULT true,
    is_system BOOLEAN DEFAULT false, -- 系统预设规则

    -- 执行策略
    apply_to_existing BOOLEAN DEFAULT false, -- 是否应用到已有交易
    apply_automatically BOOLEAN DEFAULT true, -- 新交易自动应用
    stop_on_match BOOLEAN DEFAULT false, -- 匹配后停止后续规则

    -- 统计信息
    match_count INTEGER DEFAULT 0,
    last_matched_at TIMESTAMPTZ,

    -- 元数据
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 规则条件表
CREATE TABLE rule_conditions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL REFERENCES transaction_rules(id) ON DELETE CASCADE,
    parent_condition_id UUID REFERENCES rule_conditions(id) ON DELETE CASCADE,

    -- 条件类型
    condition_type VARCHAR(50) NOT NULL, -- 'simple', 'compound'
    logical_operator VARCHAR(10), -- 'AND', 'OR' (用于复合条件)

    -- 简单条件字段
    field_name VARCHAR(50), -- 'amount', 'description', 'payee', 'category', 'date'
    operator VARCHAR(20), -- 'equals', 'contains', 'greater_than', 'less_than', 'between', 'regex'
    value_type VARCHAR(20), -- 'string', 'number', 'date', 'boolean'
    value_data JSONB, -- 存储条件值

    -- 条件顺序
    position INTEGER DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 规则动作表
CREATE TABLE rule_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL REFERENCES transaction_rules(id) ON DELETE CASCADE,

    -- 动作类型
    action_type VARCHAR(50) NOT NULL, -- 'set_category', 'add_tag', 'set_payee', 'mark_reimbursable'

    -- 动作参数
    target_field VARCHAR(50), -- 目标字段
    action_value JSONB, -- 动作值（支持复杂数据）

    -- 动作顺序
    position INTEGER DEFAULT 0,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 规则执行日志
CREATE TABLE rule_execution_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL REFERENCES transaction_rules(id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,

    -- 执行结果
    matched BOOLEAN NOT NULL,
    applied BOOLEAN NOT NULL,
    actions_taken JSONB, -- 记录具体执行的动作

    -- 性能指标
    execution_time_ms INTEGER,

    -- 错误处理
    error_message TEXT,

    executed_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX idx_transaction_rules_family_id ON transaction_rules(family_id);
CREATE INDEX idx_transaction_rules_active ON transaction_rules(is_active) WHERE is_active = true;
CREATE INDEX idx_rule_conditions_rule_id ON rule_conditions(rule_id);
CREATE INDEX idx_rule_actions_rule_id ON rule_actions(rule_id);
CREATE INDEX idx_rule_execution_logs_rule_id ON rule_execution_logs(rule_id);
CREATE INDEX idx_rule_execution_logs_transaction_id ON rule_execution_logs(transaction_id);
```

#### Rust 实现示例
```rust
// services/rule_engine_service.rs
pub struct RuleEngineService {
    pool: Arc<PgPool>,
    condition_registry: ConditionRegistry,
    action_registry: ActionRegistry,
}

impl RuleEngineService {
    /// 评估交易是否匹配规则条件
    pub async fn evaluate_conditions(
        &self,
        rule_id: Uuid,
        transaction: &Transaction,
    ) -> Result<bool> {
        let conditions = self.load_conditions(rule_id).await?;
        self.evaluate_condition_tree(&conditions, transaction)
    }

    /// 执行规则动作
    pub async fn execute_actions(
        &self,
        rule_id: Uuid,
        transaction_id: Uuid,
    ) -> Result<Vec<ActionResult>> {
        let actions = self.load_actions(rule_id).await?;
        let mut results = Vec::new();

        for action in actions {
            let executor = self.action_registry.get(&action.action_type)?;
            let result = executor.execute(transaction_id, &action.action_value).await?;
            results.push(result);
        }

        Ok(results)
    }

    /// 批量应用规则到交易
    pub async fn apply_rules_to_transaction(
        &self,
        transaction: &Transaction,
    ) -> Result<ApplyResult> {
        // 获取适用的规则（按优先级排序）
        let rules = self.get_applicable_rules(transaction.family_id).await?;

        for rule in rules {
            if self.evaluate_conditions(rule.id, transaction).await? {
                self.execute_actions(rule.id, transaction.id).await?;

                // 记录执行日志
                self.log_execution(rule.id, transaction.id, true).await?;

                if rule.stop_on_match {
                    break;
                }
            }
        }

        Ok(ApplyResult { /* ... */ })
    }
}
```

### 第二部分：定时交易系统 (feat/scheduled-transactions)

#### 数据库设计
```sql
-- 039: 定时交易系统
CREATE TABLE scheduled_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,

    -- 基本信息
    name VARCHAR(100) NOT NULL,
    description TEXT,

    -- 交易模板
    account_id UUID NOT NULL REFERENCES accounts(id),
    amount DECIMAL(15, 2) NOT NULL,
    currency_id UUID REFERENCES currencies(id),
    transaction_type VARCHAR(20) NOT NULL CHECK (transaction_type IN ('income', 'expense', 'transfer')),

    -- 关联信息
    category_id UUID REFERENCES categories(id),
    payee_id UUID REFERENCES payees(id),
    target_account_id UUID REFERENCES accounts(id), -- 用于转账

    -- 频率设置
    frequency_type VARCHAR(20) NOT NULL CHECK (frequency_type IN ('once', 'daily', 'weekly', 'monthly', 'yearly', 'custom')),
    frequency_value INTEGER DEFAULT 1, -- 自定义频率的数值
    frequency_unit VARCHAR(20), -- 'days', 'weeks', 'months' (用于custom)

    -- 月度特殊设置
    monthly_day_type VARCHAR(20), -- 'fixed_day' (每月15号) 或 'weekday' (每月第2个周三)
    monthly_day INTEGER, -- 具体的日期 (1-31)
    monthly_week INTEGER, -- 第几个星期 (1-5)
    monthly_weekday INTEGER, -- 星期几 (0-6)

    -- 时间范围
    start_date DATE NOT NULL,
    end_condition VARCHAR(20) DEFAULT 'never' CHECK (end_condition IN ('never', 'date', 'count')),
    end_date DATE,
    end_count INTEGER,

    -- 执行控制
    next_due_date DATE NOT NULL,
    last_executed_at TIMESTAMPTZ,
    execution_count INTEGER DEFAULT 0,

    -- 自动化设置
    auto_pay BOOLEAN DEFAULT false, -- 自动创建交易
    auto_skip BOOLEAN DEFAULT false, -- 自动跳过重复
    notification_days INTEGER DEFAULT 0, -- 提前通知天数

    -- 状态
    is_paused BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,

    -- 元数据
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_end_condition CHECK (
        (end_condition = 'date' AND end_date IS NOT NULL) OR
        (end_condition = 'count' AND end_count IS NOT NULL) OR
        (end_condition = 'never')
    )
);

-- 定时交易执行记录
CREATE TABLE scheduled_transaction_executions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scheduled_transaction_id UUID NOT NULL REFERENCES scheduled_transactions(id) ON DELETE CASCADE,

    -- 执行结果
    execution_status VARCHAR(20) NOT NULL CHECK (execution_status IN ('success', 'skipped', 'failed', 'manual')),
    generated_transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,

    -- 跳过原因
    skip_reason VARCHAR(50), -- 'duplicate_found', 'user_skipped', 'holiday'

    -- 执行详情
    scheduled_date DATE NOT NULL,
    executed_at TIMESTAMPTZ DEFAULT NOW(),

    -- 错误信息
    error_message TEXT,

    -- 元数据
    executed_by UUID REFERENCES users(id),
    notes TEXT
);

-- 定时交易通知
CREATE TABLE scheduled_transaction_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scheduled_transaction_id UUID NOT NULL REFERENCES scheduled_transactions(id) ON DELETE CASCADE,

    -- 通知类型
    notification_type VARCHAR(50) NOT NULL, -- 'upcoming', 'due', 'overdue', 'failed'

    -- 通知状态
    is_sent BOOLEAN DEFAULT false,
    is_read BOOLEAN DEFAULT false,

    -- 时间
    scheduled_for TIMESTAMPTZ NOT NULL,
    sent_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX idx_scheduled_transactions_family_id ON scheduled_transactions(family_id);
CREATE INDEX idx_scheduled_transactions_next_due ON scheduled_transactions(next_due_date) WHERE is_active = true AND is_paused = false;
CREATE INDEX idx_scheduled_executions_scheduled_id ON scheduled_transaction_executions(scheduled_transaction_id);
CREATE INDEX idx_scheduled_notifications_scheduled_id ON scheduled_transaction_notifications(scheduled_transaction_id);
```

#### 定时任务处理器
```rust
// services/scheduled_transaction_service.rs
pub struct ScheduledTransactionService {
    pool: Arc<PgPool>,
    notification_service: Arc<NotificationService>,
}

impl ScheduledTransactionService {
    /// 执行到期的定时交易
    pub async fn process_due_transactions(&self) -> Result<ProcessResult> {
        let due_transactions = self.get_due_transactions().await?;
        let mut results = ProcessResult::new();

        for scheduled in due_transactions {
            match self.process_single_transaction(&scheduled).await {
                Ok(execution) => {
                    results.add_success(execution);
                    self.update_next_due_date(&scheduled).await?;
                }
                Err(e) => {
                    results.add_failure(scheduled.id, e);
                    self.log_failure(&scheduled, e).await?;
                }
            }
        }

        Ok(results)
    }

    /// 处理单个定时交易
    async fn process_single_transaction(
        &self,
        scheduled: &ScheduledTransaction,
    ) -> Result<Execution> {
        // 检查是否需要跳过
        if scheduled.auto_skip {
            if let Some(duplicate) = self.find_duplicate_transaction(scheduled).await? {
                return self.skip_execution(scheduled, SkipReason::DuplicateFound).await;
            }
        }

        // 检查是否自动支付
        if scheduled.auto_pay {
            let transaction = self.create_transaction_from_template(scheduled).await?;
            return self.record_execution(scheduled, transaction).await;
        }

        // 仅创建通知，等待用户确认
        self.create_due_notification(scheduled).await?;
        Ok(Execution::Pending)
    }

    /// 计算下次到期日期
    pub fn calculate_next_due_date(
        &self,
        scheduled: &ScheduledTransaction,
        from_date: Option<NaiveDate>,
    ) -> NaiveDate {
        let base_date = from_date.unwrap_or(scheduled.next_due_date);

        match scheduled.frequency_type.as_str() {
            "daily" => base_date + Duration::days(scheduled.frequency_value as i64),
            "weekly" => base_date + Duration::weeks(scheduled.frequency_value as i64),
            "monthly" => self.calculate_monthly_date(scheduled, base_date),
            "yearly" => base_date + Duration::days(365 * scheduled.frequency_value as i64),
            "custom" => self.calculate_custom_date(scheduled, base_date),
            _ => base_date,
        }
    }
}
```

### 第三部分：智能默认值系统 (feat/smart-defaults)

#### 概念设计
基于 Maybe Finance 的 `update_smart_defaults` 理念：
1. **学习用户习惯**：分析历史交易模式
2. **智能建议**：基于上下文提供默认值
3. **自动填充**：减少重复输入

```sql
-- 040: 智能默认值系统
CREATE TABLE smart_defaults (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,

    -- 默认值类型
    default_type VARCHAR(50) NOT NULL, -- 'payee_category', 'amount_range', 'account_preference'

    -- 匹配条件
    context_key VARCHAR(200) NOT NULL, -- 如 "payee:星巴克"

    -- 默认值数据
    default_values JSONB NOT NULL, -- 存储具体的默认值

    -- 使用统计
    usage_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMPTZ,

    -- 置信度
    confidence_score DECIMAL(3, 2) DEFAULT 0.5, -- 0.0 到 1.0

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_smart_default UNIQUE (family_id, default_type, context_key)
);

-- 用户偏好设置
CREATE TABLE user_preferences (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- 自动化偏好
    enable_smart_defaults BOOLEAN DEFAULT true,
    enable_auto_categorization BOOLEAN DEFAULT true,
    enable_duplicate_detection BOOLEAN DEFAULT true,

    -- 规则偏好
    auto_apply_rules BOOLEAN DEFAULT true,
    require_rule_confirmation BOOLEAN DEFAULT false,

    -- 定时交易偏好
    scheduled_notification_days INTEGER DEFAULT 3,
    auto_pay_threshold DECIMAL(15, 2), -- 自动支付金额上限

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 功能特性对比

| 功能 | Maybe Finance | Jive Money 设计 |
|------|--------------|----------------|
| **规则条件** | ✅ 复合条件，支持 AND/OR | ✅ 支持嵌套条件树 |
| **规则动作** | ✅ 分类、标签、字段更新 | ✅ + 批量操作、通知 |
| **定时交易** | ✅ 多种频率类型 | ✅ + 中国节假日支持 |
| **自动执行** | ✅ auto_pay, auto_skip | ✅ + 智能阈值控制 |
| **智能建议** | ✅ 基于历史数据 | ✅ + 机器学习预测 |
| **执行日志** | ✅ 规则日志 | ✅ + 性能监控 |
| **批量应用** | ✅ 应用到已有交易 | ✅ + 并行处理优化 |

## 实施优先级

### 阶段1：基础规则引擎 (2周)
1. 实现规则 CRUD API
2. 条件匹配引擎
3. 动作执行器框架
4. 基本的分类和标签动作

### 阶段2：定时交易 (1.5周)
1. 定时交易管理
2. 频率计算器
3. 自动执行服务
4. 通知系统集成

### 阶段3：智能化增强 (2周)
1. 智能默认值学习
2. 重复检测算法
3. 批量规则应用
4. 性能优化

## 技术要点

### 1. 规则引擎性能优化
- 使用 Redis 缓存活跃规则
- 批量处理交易，减少数据库查询
- 异步执行非关键动作

### 2. 定时任务调度
- 使用 Tokio 的定时器
- 分布式锁防止重复执行
- 优雅的错误恢复机制

### 3. 智能学习算法
```rust
/// 贝叶斯分类器用于智能分类
pub struct BayesianCategorizer {
    word_frequencies: HashMap<String, HashMap<Uuid, f64>>,
    category_probabilities: HashMap<Uuid, f64>,
}

impl BayesianCategorizer {
    pub fn predict_category(&self, description: &str) -> Option<Uuid> {
        let words = self.tokenize(description);
        let mut scores = HashMap::new();

        for (category_id, prior) in &self.category_probabilities {
            let mut score = prior.ln();

            for word in &words {
                if let Some(freq) = self.word_frequencies.get(word) {
                    if let Some(cat_freq) = freq.get(category_id) {
                        score += cat_freq.ln();
                    }
                }
            }

            scores.insert(*category_id, score);
        }

        scores.into_iter()
            .max_by(|a, b| a.1.partial_cmp(&b.1).unwrap())
            .map(|(cat, _)| cat)
    }
}
```

## Flutter UI 设计建议

### 1. 规则管理界面
- 拖拽式条件构建器
- 实时预览匹配结果
- 规则模板库

### 2. 定时交易日历视图
- 月历展示即将到期的交易
- 快速操作按钮（执行、跳过、编辑）
- 批量管理功能

### 3. 智能助手组件
- 浮动提示框显示建议
- 一键接受/拒绝
- 学习反馈机制

## 总结

Maybe Finance 的自动化系统设计精巧，核心理念值得借鉴：
1. **灵活的规则引擎**：条件-动作分离，支持复杂逻辑
2. **智能的定时系统**：考虑银行同步场景，防止重复
3. **渐进式自动化**：从建议到自动执行，给用户控制权
4. **数据驱动优化**：通过执行日志不断改进

Jive Money 在此基础上可以增加：
- 中国本地化功能（节假日、支付方式）
- 更强的批处理能力
- 机器学习增强的分类
- 可视化规则构建器