# Transactions Filters & Grouping — Phase B Design (草案)

Purpose
- Deliver practical, performant filtering + grouping for transactions.
- Keep UI declarative, leverage existing providers; avoid duplicating domain rules.

Scope
- Filters: text (描述/备注/收款方), 日期范围, 类型(支出/收入/转账), 账户, 分类, 标签, 金额区间。
- Grouping: 按 日期 / 分类 / 账户；每组显示小计，总计在页眉/页脚。
- Persist: 轻量本地记忆最近一次筛选与分组（per-ledger）。
- Non-goals: 复杂多级排序、跨家庭聚合、导出（独立PR）。

UX Outline
- TransactionsScreen 顶部显示 FilterBar（收起/展开）。
- FilterBar：
  - 搜索框（回车触发）、“筛选”按钮打开面板（日期/类型/账户/分类/标签/金额）、“重置”按钮。
  - 右侧“分组切换”：日期/分类/账户；在移动端为 Segmented 形式。
- 列表：
  - 分组头包含：组名 + 小计金额（正/负色），可折叠。
  - 空状态支持“清空筛选”。

State & Providers
- transactionControllerProvider（现有）：
  - 扩展：`applyFilter(TransactionQuery q)`、`clearFilter()`、`setGrouping(Grouping g)`、`toggleGroupCollapse(key)`。
  - 状态新增：`currentQuery`、`grouping`、`groupCollapse: Set<String>`。
- Query 模型（新）：
  ```dart
  class TransactionQuery {
    final String? text;
    final DateTimeRange? dateRange;
    final Set<TransactionType>? types;
    final Set<String>? accountIds;
    final Set<String>? categoryIds;
    final Set<String>? tagIds;
    final double? amountMin;
    final double? amountMax;
    const TransactionQuery({ ... });
    TransactionQuery copyWith(...);
    bool get isEmpty;
  }
  ```
- Grouping（新枚举）：`date | category | account`。
- 组合选择器：账户/分类/标签用现有 providers 源数据，支持多选（Chip/BottomSheet）。

Data Flow
- UI → controller.applyFilter(query) → 计算/筛选 in-memory（Phase B）
- 未来 Phase C：若列表很大，落地到服务端 query（分页 + 去抖）。

API/Backend Impact
- Phase B：无服务端改动。
- Phase C（另案）：增量新增 `/transactions/search` 支持字段与分页；Rust 侧生成 SQLx 查询 + .sqlx 更新。

Persistence
- SharedPreferences key: `tx_ui_<ledgerId>_{query,grouping}`；
- 在 initState 读取并应用。

Accessibility & i18n
- 分组头可聚焦；筛选面板控件提供语义标签；所有文案纳入 i18n 字典（后续批量替换）。

Performance
- 过滤与分组在内存进行：
  - 先按日期预分桶（Map<Date, List>）复用；
  - 计算小计 O(n)；
  - 大列表按需构建（ListView.builder）。

Acceptance Criteria
- 可对任意组合条件过滤，切换分组视图，显示正确小计与总计。
- 刷新后保留上次筛选/分组。
- analyzer 0 hard errors；tests 通过。

Phasing
- B1：完成 Query 模型 + 控制器 + UI 面板（不含服务端）。
- B2：分组小计 + 折叠 + 持久化。
- B3：微交互与过渡动画；边界测试。

Risks / Out of Scope
- 非线性金额转换/多货币换算（另案）。
- 高维度组合过滤在低端机的性能（必要时分页）。
