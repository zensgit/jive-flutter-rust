# Jive Money 功能实现TODO列表

## 📌 总体实施计划

基于功能差异分析和产品设计文档，以下是Jive Money完整功能实现的详细TODO列表。

## 第一阶段：核心基础设施 (P0 - 必须实现)

### 1.1 用户认证系统 【第1-2周】

- [ ] **后端认证服务** `jive-core/src/application/auth_service.rs`
  - [ ] 用户注册API
  - [ ] 用户登录API (JWT Token)
  - [ ] 密码加密 (Argon2)
  - [ ] Token刷新机制
  - [ ] 会话管理

- [ ] **用户数据模型** `jive-core/src/domain/user/mod.rs`
  ```rust
  - [ ] User实体
  - [ ] UserPreferences
  - [ ] Session管理
  - [ ] MFA设置
  ```

- [ ] **前端认证流程** `lib/screens/auth/`
  - [ ] 登录页面UI
  - [ ] 注册页面UI
  - [ ] 密码重置流程
  - [ ] 认证状态管理 (Riverpod)

- [ ] **安全功能**
  - [ ] 邮箱验证
  - [ ] 密码强度检查
  - [ ] 登录尝试限制
  - [ ] 安全日志

### 1.2 数据持久化层 【第2周】

- [ ] **数据库设计** `database/migrations/`
  - [ ] 创建核心表结构SQL
  - [ ] 索引优化
  - [ ] 外键约束
  - [ ] 初始数据脚本

- [ ] **ORM集成** `jive-core/src/infrastructure/database/`
  - [ ] SQLite本地存储
  - [ ] PostgreSQL云端支持
  - [ ] 连接池管理
  - [ ] 事务处理

- [ ] **数据访问层** `jive-core/src/infrastructure/repositories/`
  - [ ] UserRepository
  - [ ] AccountRepository
  - [ ] TransactionRepository
  - [ ] CategoryRepository

### 1.3 家庭管理系统 【第2周】

- [ ] **家庭模型** `jive-core/src/domain/family/`
  - [ ] Family实体
  - [ ] FamilyMember关系
  - [ ] 角色权限定义
  - [ ] 邀请系统

- [ ] **家庭服务** `jive-core/src/application/family_service.rs`
  - [ ] 创建家庭
  - [ ] 邀请成员
  - [ ] 权限管理
  - [ ] 成员管理

## 第二阶段：账户和交易管理完善 (P0)

### 2.1 账户管理增强 【第3周】

- [ ] **扩展账户类型** `jive-core/src/domain/account/`
  ```rust
  - [ ] Checking (支票)
  - [ ] Savings (储蓄)
  - [ ] CreditCard (信用卡)
  - [ ] Investment (投资)
  - [ ] Crypto (加密货币)
  - [ ] Loan (贷款)
  - [ ] Property (房产)
  - [ ] Vehicle (车辆)
  - [ ] PrepaidCard (预付卡)
  - [ ] OtherAsset (其他资产)
  - [ ] OtherLiability (其他负债)
  ```

- [ ] **账户功能** `jive-core/src/application/account_service.rs`
  - [ ] 账户CRUD完整API
  - [ ] 账户状态管理 (active/draft/disabled)
  - [ ] 账户分组功能
  - [ ] 余额历史追踪
  - [ ] 账户关联设置

- [ ] **账户UI增强** `lib/screens/accounts/`
  - [ ] 账户创建向导
  - [ ] 账户编辑页面
  - [ ] 账户分组管理
  - [ ] 账户详情页面
  - [ ] 余额趋势图表

### 2.2 交易管理完善 【第3-4周】

- [ ] **交易数据模型** `jive-core/src/domain/transaction/`
  - [ ] Transaction实体扩展
  - [ ] TransactionSplit (交易拆分)
  - [ ] TransactionAttachment (附件)
  - [ ] TransactionStatus状态机

- [ ] **分类系统** `jive-core/src/domain/category/`
  - [ ] 多层级分类树
  - [ ] 预设分类模板
  - [ ] 自定义分类
  - [ ] 分类图标和颜色

- [ ] **商家管理** `jive-core/src/domain/payee/`
  - [ ] Payee实体
  - [ ] 商家自动识别
  - [ ] 商家分类映射
  - [ ] 商家Logo获取

- [ ] **标签系统** `jive-core/src/domain/tag/`
  - [ ] Tag实体
  - [ ] 标签关联
  - [ ] 标签统计
  - [ ] 标签搜索

- [ ] **交易功能** `jive-core/src/application/transaction_service.rs`
  - [ ] 交易CRUD完整API
  - [ ] 批量操作API
  - [ ] 交易搜索和过滤
  - [ ] 转账匹配算法
  - [ ] 交易拆分逻辑
  - [ ] 退款处理

- [ ] **交易UI完善** `lib/screens/transactions/`
  - [ ] 交易创建/编辑表单
  - [ ] 高级搜索界面
  - [ ] 批量操作界面
  - [ ] 交易拆分界面
  - [ ] 附件上传功能

## 第三阶段：数据同步和导入 (P0)

### 3.1 CSV导入功能 【第5周】

- [ ] **导入引擎** `jive-core/src/application/import_service.rs`
  - [ ] CSV解析器
  - [ ] 字段映射逻辑
  - [ ] 数据验证
  - [ ] 重复检测算法

- [ ] **导入模板** `jive-core/src/domain/import/`
  - [ ] 支付宝账单模板
  - [ ] 微信账单模板
  - [ ] 银行对账单模板
  - [ ] 通用CSV模板

- [ ] **导入UI** `lib/screens/import/`
  - [ ] 文件上传界面
  - [ ] 字段映射配置
  - [ ] 数据预览表格
  - [ ] 导入进度显示
  - [ ] 导入历史记录

### 3.2 银行同步基础 【第6周】

- [ ] **同步框架** `jive-core/src/infrastructure/sync/`
  - [ ] 同步任务调度
  - [ ] 同步状态管理
  - [ ] 错误处理和重试
  - [ ] 同步日志

- [ ] **Plaid集成** (可选)
  - [ ] Plaid API客户端
  - [ ] 账户连接流程
  - [ ] 交易同步
  - [ ] Webhook处理

## 第四阶段：高级功能实现 (P1)

### 4.1 预算管理系统 【第7周】

- [ ] **预算模型** `jive-core/src/domain/budget/`
  - [ ] Budget实体
  - [ ] BudgetCategory
  - [ ] BudgetPeriod
  - [ ] BudgetAlert

- [ ] **预算服务** `jive-core/src/application/budget_service.rs`
  - [ ] 预算创建和编辑
  - [ ] 预算执行跟踪
  - [ ] 预算vs实际计算
  - [ ] 预算告警逻辑
  - [ ] 预算复制/模板

- [ ] **预算UI** `lib/screens/budgets/`
  - [ ] 预算设置界面
  - [ ] 预算进度展示
  - [ ] 预算分析图表
  - [ ] 预算告警通知

### 4.2 多账本系统 【第8-9周】

- [ ] **账本模型** `jive-core/src/domain/ledger/`
  - [ ] Ledger实体
  - [ ] LedgerType枚举
  - [ ] LedgerMember权限
  - [ ] LedgerTransfer转账

- [ ] **账本服务** `jive-core/src/application/ledger_service.rs`
  - [ ] 账本CRUD
  - [ ] 账本切换逻辑
  - [ ] 账本间转账
  - [ ] 权限控制
  - [ ] 账本统计

- [ ] **账本UI** `lib/screens/ledgers/`
  - [ ] 账本选择器
  - [ ] 账本创建向导
  - [ ] 账本设置页面
  - [ ] 成员管理界面
  - [ ] 账本间转账界面

### 4.3 规则引擎 【第10周】

- [ ] **规则模型** `jive-core/src/domain/rule/`
  - [ ] Rule实体
  - [ ] RuleCondition条件
  - [ ] RuleAction动作
  - [ ] RuleExecution执行记录

- [ ] **规则引擎** `jive-core/src/application/rule_engine.rs`
  - [ ] 条件匹配算法
  - [ ] 动作执行器
  - [ ] 规则优先级处理
  - [ ] 规则性能优化
  - [ ] 批量应用规则

- [ ] **规则UI** `lib/screens/rules/`
  - [ ] 规则列表管理
  - [ ] 规则创建向导
  - [ ] 条件构建器
  - [ ] 规则测试界面
  - [ ] 规则执行日志

### 4.4 定时交易 【第11周】

- [ ] **定时交易模型** `jive-core/src/domain/scheduled/`
  - [ ] ScheduledTransaction
  - [ ] RecurrencePattern
  - [ ] ExecutionLog

- [ ] **定时服务** `jive-core/src/application/scheduled_service.rs`
  - [ ] 频率计算引擎
  - [ ] 自动执行任务
  - [ ] 智能跳过逻辑
  - [ ] 执行历史记录

- [ ] **定时UI** `lib/screens/scheduled/`
  - [ ] 定时交易列表
  - [ ] 创建定时交易
  - [ ] 频率设置器
  - [ ] 执行历史查看

### 4.5 报表分析增强 【第12周】

- [ ] **报表计算** `jive-core/src/application/report_service.rs`
  - [ ] 资产负债表计算
  - [ ] 损益表计算
  - [ ] 现金流计算
  - [ ] 趋势分析算法

- [ ] **图表组件** `lib/widgets/charts/`
  - [ ] 趋势图组件
  - [ ] 饼图组件
  - [ ] 柱状图组件
  - [ ] 热力图组件
  - [ ] Sankey图组件

- [ ] **报表UI** `lib/screens/reports/`
  - [ ] 财务概览仪表板
  - [ ] 自定义报表生成器
  - [ ] 报表导出功能
  - [ ] 对比分析界面

## 第五阶段：智能化和高级功能 (P2)

### 5.1 投资管理 【第13-14周】

- [ ] **投资模型** `jive-core/src/domain/investment/`
  - [ ] Security证券
  - [ ] Trade交易
  - [ ] Holding持仓
  - [ ] Valuation估值

- [ ] **投资服务** `jive-core/src/application/investment_service.rs`
  - [ ] 交易记录管理
  - [ ] 持仓计算
  - [ ] 收益率计算
  - [ ] 市场数据集成

- [ ] **投资UI** `lib/screens/investments/`
  - [ ] 投资组合概览
  - [ ] 交易记录界面
  - [ ] 持仓详情
  - [ ] 收益分析图表

### 5.2 AI财务助手 【第15-16周】

- [ ] **AI集成** `jive-core/src/application/ai_service.rs`
  - [ ] LLM API集成
  - [ ] 提示词工程
  - [ ] 上下文管理
  - [ ] 工具调用接口

- [ ] **聊天功能** `jive-core/src/domain/chat/`
  - [ ] Chat会话
  - [ ] Message消息
  - [ ] ToolCall工具调用

- [ ] **AI UI** `lib/screens/assistant/`
  - [ ] 聊天界面
  - [ ] 语音输入
  - [ ] 建议卡片
  - [ ] 历史记录

### 5.3 通知系统 【第17周】

- [ ] **通知模型** `jive-core/src/domain/notification/`
  - [ ] Notification实体
  - [ ] NotificationPreference
  - [ ] NotificationChannel

- [ ] **通知服务** `jive-core/src/application/notification_service.rs`
  - [ ] 通知触发器
  - [ ] 通知分发
  - [ ] 通知模板
  - [ ] 批量发送

- [ ] **通知UI** `lib/widgets/notifications/`
  - [ ] 通知中心
  - [ ] 通知设置
  - [ ] 推送权限
  - [ ] 通知历史

### 5.4 API系统 【第18周】

- [ ] **RESTful API** `jive-core/src/api/rest/`
  - [ ] 路由定义
  - [ ] 认证中间件
  - [ ] 限流控制
  - [ ] API文档

- [ ] **API管理** `jive-core/src/application/api_service.rs`
  - [ ] API Key管理
  - [ ] OAuth2实现
  - [ ] Webhook支持
  - [ ] 使用统计

## 第六阶段：优化和完善 (P3)

### 6.1 性能优化 【第19周】

- [ ] **后端优化**
  - [ ] 数据库查询优化
  - [ ] 缓存策略实施
  - [ ] 批量操作优化
  - [ ] WASM性能调优

- [ ] **前端优化**
  - [ ] 懒加载实现
  - [ ] 虚拟滚动
  - [ ] 图片优化
  - [ ] 代码分割

### 6.2 测试和质量保证 【第20周】

- [ ] **单元测试**
  - [ ] Rust服务测试
  - [ ] Flutter Widget测试
  - [ ] 数据模型测试

- [ ] **集成测试**
  - [ ] API测试
  - [ ] 端到端测试
  - [ ] 性能测试

- [ ] **文档完善**
  - [ ] API文档
  - [ ] 用户手册
  - [ ] 部署指南

## 📊 进度追踪

| 阶段 | 功能模块 | 预计工时 | 完成状态 | 负责人 |
|-----|---------|---------|---------|--------|
| 1 | 用户认证 | 40h | ⏳ 进行中 | - |
| 1 | 数据持久化 | 24h | ⏳ 待开始 | - |
| 1 | 家庭管理 | 16h | ⏳ 待开始 | - |
| 2 | 账户增强 | 32h | ⏳ 待开始 | - |
| 2 | 交易完善 | 40h | ⏳ 待开始 | - |
| 3 | CSV导入 | 24h | ⏳ 待开始 | - |
| 3 | 银行同步 | 32h | ⏳ 待开始 | - |
| 4 | 预算管理 | 24h | ⏳ 待开始 | - |
| 4 | 多账本 | 40h | ⏳ 待开始 | - |
| 4 | 规则引擎 | 32h | ⏳ 待开始 | - |
| 4 | 定时交易 | 24h | ⏳ 待开始 | - |
| 4 | 报表分析 | 32h | ⏳ 待开始 | - |
| 5 | 投资管理 | 40h | ⏳ 待开始 | - |
| 5 | AI助手 | 40h | ⏳ 待开始 | - |
| 5 | 通知系统 | 16h | ⏳ 待开始 | - |
| 5 | API系统 | 24h | ⏳ 待开始 | - |
| 6 | 性能优化 | 24h | ⏳ 待开始 | - |
| 6 | 测试完善 | 32h | ⏳ 待开始 | - |

**总计：约 516 小时 (约13周全职开发)**

## 🎯 关键里程碑

- [ ] **M1 (第4周)**: 核心基础设施完成，用户可注册登录
- [ ] **M2 (第8周)**: 账户和交易功能完整，可日常使用
- [ ] **M3 (第12周)**: 高级功能完成，功能覆盖度达80%
- [ ] **M4 (第16周)**: 智能化功能上线，达到Maybe功能水平
- [ ] **M5 (第20周)**: 产品优化完成，准备正式发布

## 📝 注意事项

1. **优先级调整**: 根据用户反馈动态调整功能优先级
2. **迭代开发**: 每2周发布一个版本，快速迭代
3. **技术债务**: 定期重构，避免技术债务积累
4. **文档同步**: 代码和文档同步更新
5. **测试覆盖**: 核心功能测试覆盖率>80%

## 🚀 下一步行动

1. 立即开始用户认证系统开发
2. 搭建数据库和ORM框架
3. 创建基础UI组件库
4. 建立CI/CD流程
5. 招募测试用户

---

*本TODO列表将随着开发进展持续更新*