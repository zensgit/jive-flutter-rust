# 交易系统安全总体方案与落地说明 (Transaction Security Overview)

## 目标与范围
- 覆盖交易域的认证、授权（RBAC）、多租户隔离（Family）、输入校验（排序/分页）、导出安全（CSV）、审计追踪（created_by + 审计日志）与数据一致性（余额与交易）。
- 达成最小权限、强隔离、可追溯、可审计和可持续维护。

## 核心原则
- 最小权限：每个端点按功能粒度校验 Permission。
- 强隔离：所有查询均以 family 维度过滤（JOIN ledgers）。
- 零信任输入：用户可控字段一律白名单（排序字段/方向）。
- 可审计：创建写入 created_by；导出/敏感操作写审计日志并返回 x-audit-id。
- 安全导出：CSV 防公式注入与特殊字符转义，防止客户端工具被利用。

## 架构与代码形态
- 统一 Handler 签名顺序（利于中间件与审计一致性）：claims -> Path -> State -> Query/Json。
- 家庭隔离（multi-tenant）：
  - JOIN ledgers l ON t.ledger_id = l.id AND l.family_id = $family_id。
  - WHERE t.deleted_at IS NULL AND l.family_id = $family_id。
- 授权模型（RBAC）：
  - Validate: AuthService::validate_family_access(user_id, family_id)。
  - Authorize: ctx.require_permission(Permission::Xxx)。
- SQL 注入防护（排序白名单）：仅允许受控字段与方向（ASC/DESC），非法输入回退默认。
- 审计与追责：
  - 写操作：transactions.created_by = user_id。
  - 导出：记录导出参数/估算行数/UA/IP，返回 x-audit-id。
- CSV 安全：
  - 公式触发字符（= + - @ 及全角变体、管道、制表、回车）前缀保护。
  - 含分隔符/引号/换行/回车/制表的单元格整体加引号，内部引号翻倍。

## 关键端点落地（参考位置）
- 列表 list_transactions：权限 + family 限定 + 过滤 + 排序白名单 + 分页。
  - jive-api/src/handlers/transactions.rs:659-782
- 详情 get_transaction：权限 + family 限定 + payee 文本回退（t.payee AS payee_text）。
  - jive-api/src/handlers/transactions.rs:840-914
- 创建 create_transaction：权限 + ledger 归属校验 + INSERT(含 created_by) + 余额更新（单事务）。
  - jive-api/src/handlers/transactions.rs:922-1060
- 更新 update_transaction：权限 + family 校验 + 动态字段更新。
  - jive-api/src/handlers/transactions.rs:1027-1128
- 删除 delete_transaction：权限 + family 校验 + 软删 + 余额回滚（单事务）。
  - jive-api/src/handlers/transactions.rs:1139-1218
- 批量 bulk_transaction_operations：按操作分类权限 + family 限定的批量 UPDATE/软删。
  - jive-api/src/handlers/transactions.rs:1219-1386
- 导出 export_transactions / export_transactions_csv_stream：权限 + family 过滤 + 安全 CSV + 审计。
  - jive-api/src/handlers/transactions.rs:73-214, 340-512

## 迁移与模型对齐
- payees 表与外键：
  - 新增迁移：jive-api/migrations/043_create_payees_table.sql。
  - transactions.payee_id -> payees(id) 外键（ON DELETE SET NULL）。
- 避免列名歧义：
  - 显式选择列而非 t.*，并使用 t.payee AS payee_text 回退展示。

## 测试与验证
- 单元/集成测试覆盖：RBAC 权限、family 隔离、排序白名单、CSV 注入绕过（含全角）、审计字段与导出。
- 结果：28/28 通过（详见 TRANSACTION_SECURITY_FIX_REPORT.md）。

## 运维与部署
- 先迁移再部署：`sqlx migrate run`（或 `make db-migrate`）。
- 环境：JWT_SECRET、数据库连接、（可选）Redis。
- CORS：开发 `make api-dev`（CORS_DEV=1）；生产 `make api-safe`（白名单）。
- 观测：导出审计日志、失败数、生成时延、行数分布；403/非法排序记录。

## 面向未来的 Checklist（新端点）
- 签名顺序：claims -> Path -> State -> Query/Json。
- 必经：validate_family_access + require_permission。
- 查询：JOIN ledgers + family 过滤 + 删除态过滤。
- 白名单：排序/方向/投影字段。
- 审计：写 created_by；敏感操作写审计并回传 x-audit-id。
- CSV/文件：注入与转义处理。

## 已知非阻断改进（后续优化）
- CSV 换行/回车检测使用真实字符 '\n'/'\r'（已修正）。
- 批量删除与余额一致性：如需严格平衡，可在批量路径聚合回滚或由定期对账任务平衡。

