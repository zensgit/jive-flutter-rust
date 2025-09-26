# Jive Money 产品功能设计文档

## 1. 产品愿景

### 1.1 产品定位
Jive Money 是一款基于 Flutter + Rust + WebAssembly 技术栈的现代化个人财务管理应用，目标是提供与 Maybe 同等甚至更优的财务管理体验。

### 1.2 核心价值
- **全平台统一体验**：一套代码，支持 Web、iOS、Android、Desktop
- **高性能**：Rust 后端 + WASM，提供原生级性能
- **隐私优先**：支持完全本地化部署，数据完全掌控
- **智能化**：AI 驱动的财务分析和建议
- **家庭协作**：支持多用户家庭财务管理

## 2. 用户画像

### 主要用户群体
1. **个人理财用户** (60%)
   - 年龄：25-45岁
   - 需求：日常收支管理、预算控制、储蓄规划
   
2. **家庭财务管理者** (30%)
   - 需求：家庭共同账本、成员支出追踪、家庭预算
   
3. **投资者** (10%)
   - 需求：投资组合管理、收益分析、资产配置

## 3. 核心功能设计

### 3.1 用户和认证系统 【P0】

#### 3.1.1 用户注册和登录
```yaml
功能描述: 
  - 邮箱注册/登录
  - 社交账号登录 (Google/Apple/微信)
  - 手机号注册 (中国用户)
  
技术方案:
  - JWT Token 认证
  - OAuth2.0 社交登录
  - 密码使用 Argon2 加密
  
用户流程:
  1. 用户选择注册方式
  2. 填写必要信息
  3. 邮箱/手机验证
  4. 设置初始偏好
  5. 进入应用主页
```

#### 3.1.2 多因素认证 (MFA)
```yaml
功能描述:
  - TOTP (Google Authenticator)
  - 短信验证码
  - 生物识别 (指纹/Face ID)
  
安全级别:
  - 低: 仅密码
  - 中: 密码 + 短信
  - 高: 密码 + TOTP + 生物识别
```

#### 3.1.3 家庭管理
```yaml
功能描述:
  - 创建/加入家庭
  - 成员角色管理
  - 权限控制
  
角色定义:
  - 管理员: 全部权限
  - 成员: 查看和添加交易
  - 观察者: 仅查看权限
```

### 3.2 账户管理系统 【P0】

#### 3.2.1 账户类型扩展
```rust
pub enum AccountType {
    // 资产类
    Checking,        // 支票账户
    Savings,         // 储蓄账户
    Cash,           // 现金
    Investment,      // 投资账户
    Crypto,         // 加密货币
    PrepaidCard,    // 预付卡
    Property,       // 房产
    Vehicle,        // 车辆
    OtherAsset,     // 其他资产
    
    // 负债类
    CreditCard,     // 信用卡
    Loan,           // 贷款
    Mortgage,       // 房贷
    OtherLiability, // 其他负债
}
```

#### 3.2.2 账户功能矩阵

| 账户类型 | 交易记录 | 余额追踪 | 自动同步 | 投资管理 | 贷款计算 |
|---------|---------|---------|---------|---------|---------|
| 支票账户 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 储蓄账户 | ✅ | ✅ | ✅ | ❌ | ❌ |
| 信用卡 | ✅ | ✅ | ✅ | ❌ | ✅ |
| 投资账户 | ✅ | ✅ | ✅ | ✅ | ❌ |
| 房产 | ⚠️ | ✅ | ❌ | ❌ | ✅ |
| 贷款 | ✅ | ✅ | ⚠️ | ❌ | ✅ |

#### 3.2.3 账户管理功能
```yaml
基础功能:
  - 创建/编辑/删除账户
  - 账户分组管理
  - 账户图标和颜色自定义
  - 账户备注和标签
  
高级功能:
  - 账户余额历史图表
  - 账户关联 (如信用卡关联还款账户)
  - 账户限额设置
  - 账户冻结/解冻
```

### 3.3 交易管理系统 【P0】

#### 3.3.1 交易数据模型
```rust
pub struct Transaction {
    // 基础信息
    id: Uuid,
    account_id: Uuid,
    amount: Decimal,
    transaction_date: DateTime,
    
    // 分类信息
    category_id: Option<Uuid>,
    subcategory_id: Option<Uuid>,
    tags: Vec<Tag>,
    
    // 交易对象
    payee_id: Option<Uuid>,
    payee_name: String,
    
    // 扩展信息
    transaction_type: TransactionType,
    status: TransactionStatus,
    notes: Option<String>,
    location: Option<Location>,
    attachments: Vec<Attachment>,
    
    // 特殊标记
    is_transfer: bool,
    is_reimbursable: bool,
    is_recurring: bool,
    parent_id: Option<Uuid>, // 用于拆分交易
}

pub enum TransactionType {
    Income,
    Expense,
    Transfer,
    Investment,
    Refund,
}
```

#### 3.3.2 分类系统设计
```yaml
分类层级:
  餐饮:
    - 早餐
    - 午餐
    - 晚餐
    - 咖啡茶饮
    - 外卖
    - 聚餐
  
  交通:
    - 公共交通
    - 打车
    - 加油
    - 停车费
    - 过路费
    
  购物:
    - 日用品
    - 服装鞋包
    - 电子产品
    - 家居用品
    
自定义分类:
  - 用户可创建自定义分类
  - 支持分类图标和颜色
  - 分类预算关联
```

#### 3.3.3 商家管理
```yaml
功能设计:
  - 自动识别商家
  - 商家信息编辑
  - 商家分类映射
  - 常用商家列表
  
商家数据:
  - 名称标准化
  - Logo获取
  - 地理位置
  - 消费统计
```

#### 3.3.4 高级交易功能
```yaml
交易拆分:
  场景: 一笔交易包含多个分类
  示例: 超市购物 ¥200
    - 食品 ¥120
    - 日用品 ¥50
    - 酒水 ¥30

转账匹配:
  - 自动识别转账对
  - 避免重复计算
  - 支持跨账户转账

批量操作:
  - 批量分类
  - 批量标记
  - 批量删除
  - 批量导出
```

### 3.4 预算管理系统 【P1】

#### 3.4.1 预算类型
```yaml
月度预算:
  - 总预算设定
  - 分类预算分配
  - 弹性预算调整

年度预算:
  - 年度目标设定
  - 季度分解
  - 年终总结

项目预算:
  - 特定项目预算
  - 如: 旅行、装修、婚礼
```

#### 3.4.2 预算功能设计
```rust
pub struct Budget {
    id: Uuid,
    ledger_id: Uuid,
    period_type: PeriodType,
    period_start: Date,
    period_end: Date,
    
    // 预算项
    items: Vec<BudgetItem>,
    
    // 预算设置
    total_amount: Decimal,
    alert_threshold: f32, // 0.8 = 80%警告
    rollover_enabled: bool, // 未用完金额是否滚动到下期
}

pub struct BudgetItem {
    category_id: Uuid,
    budgeted_amount: Decimal,
    spent_amount: Decimal,
    remaining_amount: Decimal,
}
```

#### 3.4.3 预算监控和提醒
```yaml
实时监控:
  - 支出进度条
  - 剩余金额显示
  - 日均可支出计算

智能提醒:
  - 接近预算限额 (80%)
  - 超出预算
  - 异常支出检测
  - 月度预算报告
```

### 3.5 多账本系统 【P1】

#### 3.5.1 账本类型设计
```rust
pub enum LedgerType {
    Personal,       // 个人账本
    Family,         // 家庭账本
    Business,       // 生意账本
    Project,        // 项目账本
    Travel,         // 旅行账本
    Event,          // 事件账本 (婚礼、装修等)
}

pub struct Ledger {
    id: Uuid,
    name: String,
    ledger_type: LedgerType,
    owner_id: Uuid,
    members: Vec<LedgerMember>,
    
    // 账本设置
    currency: String,
    timezone: String,
    fiscal_year_start: u8, // 财年开始月份
    
    // 自定义
    color: String,
    icon: String,
    cover_image: Option<String>,
}
```

#### 3.5.2 账本权限管理
```yaml
权限级别:
  - 所有者: 完全控制
  - 管理员: 除删除账本外的所有权限
  - 编辑者: 添加/编辑交易
  - 查看者: 仅查看

权限矩阵:
  功能         所有者  管理员  编辑者  查看者
  查看交易      ✅      ✅      ✅      ✅
  添加交易      ✅      ✅      ✅      ❌
  编辑交易      ✅      ✅      ✅      ❌
  删除交易      ✅      ✅      ❌      ❌
  管理预算      ✅      ✅      ❌      ❌
  邀请成员      ✅      ✅      ❌      ❌
  删除账本      ✅      ❌      ❌      ❌
```

### 3.6 数据同步系统 【P0】

#### 3.6.1 银行同步
```yaml
同步方式:
  1. Plaid (国际)
  2. 银联开放平台 (中国)
  3. Open Banking API
  4. 网银爬虫 (备选)

同步内容:
  - 账户余额
  - 交易记录
  - 账单信息
  - 信用卡账单

同步策略:
  - 自动同步 (每日)
  - 手动同步
  - 实时推送 (Webhook)
```

#### 3.6.2 数据导入
```yaml
支持格式:
  - CSV (通用格式)
  - Excel (支付宝/微信账单)
  - OFX (Quicken)
  - QIF (Quicken Interchange)
  - JSON (API导入)

导入流程:
  1. 选择文件
  2. 识别格式
  3. 字段映射
  4. 数据预览
  5. 去重检查
  6. 确认导入
```

### 3.7 规则引擎 【P1】

#### 3.7.1 规则设计
```rust
pub struct Rule {
    id: Uuid,
    name: String,
    priority: i32,
    conditions: Vec<RuleCondition>,
    actions: Vec<RuleAction>,
    enabled: bool,
}

pub enum RuleCondition {
    AmountRange { min: Decimal, max: Decimal },
    PayeeContains(String),
    DescriptionMatches(Regex),
    AccountEquals(Uuid),
    DayOfWeek(Vec<Weekday>),
}

pub enum RuleAction {
    SetCategory(Uuid),
    AddTag(String),
    SetPayee(Uuid),
    MarkAsReimbursable,
    MarkAsTransfer,
}
```

#### 3.7.2 规则应用场景
```yaml
自动分类:
  条件: 商家包含"星巴克"
  动作: 分类设为"咖啡茶饮"

自动标记:
  条件: 金额 > 1000 且 分类 = "购物"
  动作: 添加标签"大额支出"

转账识别:
  条件: 描述包含"转账"或"还款"
  动作: 标记为转账类型
```

### 3.8 投资管理 【P2】

#### 3.8.1 投资账户功能
```yaml
持仓管理:
  - 股票/基金/债券/加密货币
  - 实时价格更新
  - 成本基础跟踪
  - 收益率计算

交易记录:
  - 买入/卖出
  - 分红/派息
  - 拆股/合并
  - 转入/转出

性能分析:
  - 总收益率
  - 年化收益率
  - 与基准对比
  - 资产配置分析
```

### 3.9 报表分析 【P1】

#### 3.9.1 财务报表
```yaml
资产负债表:
  - 资产明细
  - 负债明细
  - 净资产计算
  - 环比/同比分析

损益表:
  - 收入分类统计
  - 支出分类统计
  - 净收入趋势
  - 预算对比

现金流量表:
  - 经营现金流
  - 投资现金流
  - 筹资现金流
```

#### 3.9.2 可视化分析
```yaml
图表类型:
  - 趋势图: 余额/收支趋势
  - 饼图: 支出分类占比
  - 柱状图: 月度对比
  - 热力图: 日历支出分布
  - Sankey图: 资金流向
  
交互功能:
  - 时间范围选择
  - 数据钻取
  - 对比分析
  - 导出图表
```

### 3.10 AI财务助手 【P2】

#### 3.10.1 功能设计
```yaml
自然语言查询:
  - "我这个月在餐饮上花了多少钱？"
  - "对比上个月的支出情况"
  - "我的投资收益率是多少？"

智能分析:
  - 消费习惯分析
  - 异常支出提醒
  - 预算优化建议
  - 投资组合建议

预测功能:
  - 现金流预测
  - 支出趋势预测
  - 财务目标达成预测
```

### 3.11 通知系统 【P2】

#### 3.11.1 通知类型
```yaml
账户通知:
  - 大额交易提醒
  - 余额不足警告
  - 同步完成通知

预算通知:
  - 预算超支警告
  - 月度预算报告
  - 预算重置提醒

系统通知:
  - 安全提醒
  - 功能更新
  - 数据备份提醒
```

## 4. 技术架构设计

### 4.1 整体架构
```
┌─────────────────────────────────────────────┐
│             Flutter 前端应用                  │
│  (Web / iOS / Android / Desktop)            │
└─────────────────────────────────────────────┘
                      ↕
┌─────────────────────────────────────────────┐
│            WebAssembly 层                    │
│         (Rust 编译的 WASM 模块)              │
└─────────────────────────────────────────────┘
                      ↕
┌─────────────────────────────────────────────┐
│              Rust 后端服务                   │
│   (业务逻辑 / 数据处理 / API)               │
└─────────────────────────────────────────────┘
                      ↕
┌─────────────────────────────────────────────┐
│              数据存储层                      │
│  (SQLite本地 / PostgreSQL云端)              │
└─────────────────────────────────────────────┘
```

### 4.2 数据库设计

#### 核心表结构
```sql
-- 用户和家庭
users, families, family_members

-- 账本和账户
ledgers, accounts, account_balances

-- 交易相关
transactions, categories, payees, tags

-- 预算
budgets, budget_items

-- 投资
securities, trades, holdings

-- 规则和同步
rules, rule_conditions, syncs, imports
```

### 4.3 API设计

#### RESTful API
```yaml
认证:
  POST   /api/v1/auth/register
  POST   /api/v1/auth/login
  POST   /api/v1/auth/logout
  POST   /api/v1/auth/refresh

账户:
  GET    /api/v1/accounts
  POST   /api/v1/accounts
  GET    /api/v1/accounts/{id}
  PUT    /api/v1/accounts/{id}
  DELETE /api/v1/accounts/{id}

交易:
  GET    /api/v1/transactions
  POST   /api/v1/transactions
  GET    /api/v1/transactions/{id}
  PUT    /api/v1/transactions/{id}
  DELETE /api/v1/transactions/{id}
```

## 5. 实施计划

### 第一阶段：核心功能 (4周)
- 周1-2: 用户认证系统
- 周3: 账户管理增强
- 周4: 交易管理完善

### 第二阶段：数据和同步 (4周)
- 周5-6: 数据持久化和迁移
- 周7: CSV导入功能
- 周8: 基础同步机制

### 第三阶段：高级功能 (6周)
- 周9-10: 多账本系统
- 周11: 预算管理完善
- 周12: 规则引擎
- 周13: 报表分析
- 周14: 多货币支持

### 第四阶段：智能化 (4周)
- 周15-16: AI助手集成
- 周17: 投资管理
- 周18: 通知系统

### 第五阶段：优化和发布 (2周)
- 周19: 性能优化
- 周20: 测试和发布

## 6. 成功指标

### 功能完整性
- [ ] 100% Maybe核心功能覆盖
- [ ] 至少3个创新功能

### 性能指标
- [ ] 页面加载 < 2秒
- [ ] 交易查询 < 500ms
- [ ] 报表生成 < 3秒

### 用户体验
- [ ] 移动端适配良好
- [ ] 支持离线使用
- [ ] 数据同步无感知

### 可靠性
- [ ] 99.9% 可用性
- [ ] 数据零丢失
- [ ] 自动备份恢复

## 7. 风险和挑战

### 技术风险
- WASM性能优化复杂度
- 跨平台兼容性问题
- 数据同步冲突处理

### 市场风险
- 用户迁移成本高
- 竞品功能快速迭代
- 合规要求变化

### 缓解措施
- 分阶段发布，快速迭代
- 建立用户反馈机制
- 保持技术架构灵活性

## 8. 总结

Jive Money通过借鉴Maybe的成功经验，结合现代技术栈的优势，将打造一款功能完整、体验优秀、性能卓越的个人财务管理应用。通过分阶段实施，预计在20周内完成全部功能开发，达到并超越Maybe的产品水平。