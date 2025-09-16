# 标签管理实施计划（Implementation Plan）

## 概览
- 里程碑：
  - Phase 1 基础能力（后端 CRUD + 前端对接 + 交易打标幂等）
  - Phase 2 体验优化（建议、标签云、规则增强）
  - Phase 3 管理工具（合并/批量、分组工具、导入导出）
  - Phase 4 同步与报表（可选）

## Phase 1（1–2 周）
### 后端
1) 数据迁移（`jive-api/migrations/019_tags_tables.sql`）
- 建表：`tag_groups`、`tags`
- 索引：`UNIQUE (family_id, lower(name))`
- 外键：`tags.group_id → tag_groups.id`

2) 服务与处理器
- `src/services/tag_service.rs`：CRUD、查询、合并/重命名、统计
- `src/handlers/tag_handler.rs`：路由与入参校验
- 路由注册：/api/v1/tags、/api/v1/tag-groups、/api/v1/tags/merge、/api/v1/tags/summary
- 交易打标：/transactions/:id/tags、/transactions/batch/tags（幂等）
- ETag：GET 列表返回 ETag，If-None-Match→304

3) 一致性与用量
- 在 add/remove 时更新 `usage_count`、`last_used_at`
- 重命名/合并：更新所有受影响交易的 `transactions.tags` 数组

4) 测试
- 单元：CRUD、唯一性、合并/重命名、幂等
- 集成：交易打标 + usage_count 更新

### 前端
1) 数据层
- TagRepository（API + 本地缓存 + ETag）
- Providers：`tagsProvider`、`tagGroupsProvider`、`tagSummaryProvider`

2) UI 与交互
- 标签管理页：
  - 列表（搜索/筛选/折叠）、创建/编辑/删除/归档
  - ETag 增量刷新；失败回滚
- 交易编辑：
  - 标签选择器：常用优先、搜索关键字；快速创建（可配置）

3) 验收
- E2E：创建→选择→应用到交易→统计增长
- 刷新后仍能恢复；并发修改无报错（后端唯一性返回 409 → UI 处理）

## Phase 2（~1 周）
- 建议/常用：GET /tags/suggestions?q= 按 `usage_count/last_used_at` 建模
- 标签云：GET /tags/summary 展示词云/Top N
- 规则增强：条件扩展 & UI 动作“加标签”（已存在基础）

## Phase 3（~1 周）
- 合并：UI 批量选择 from → to；服务端事务处理
- 分组管理增强：批量移动、归档分组、排序
- 导入/导出：JSON/CSV；去重策略（lower(name)+group）

## Phase 4（可选）
- 云同步与冲突解决（简化：服务端裁决，客户端提示）
- 报表：时间维度的标签分析（周/月/年）

## 时间估算与责任
- 后端：4–6 人日（CRUD/一致性/测试）
- 前端：5–7 人日（Repo/Provider/页面/交易打标）
- 验收与优化：2–3 人日

## 风险与缓解
- 兼容历史数据：先保留 `transactions.tags`，逐步引导到标准化表；提供一次性回填脚本。
- 冲突/重名：服务端 409 明确错误；UI 提供“合并到现有标签”选项。
- 性能：列表分页 + 后端过滤/排序；大规模批量操作使用异步任务（后续）。

## 回滚方案
- 仅启用 CRUD 与交易幂等接口，不启用合并/批量等破坏性操作；
- 迁移脚本可逆（仅增表/索引）；
- 出现严重问题时关闭新路由开关，仅回退到 `transactions.tags` 使用路径。

## 验收清单（Phase 1）
- [ ] 标签/分组 CRUD OK（唯一性/归档）
- [ ] 交易加/移标签幂等，usage_count/last_used_at 正确
- [ ] 前端管理页与交易编辑可用；网络离线缓存后自动恢复
- [ ] 列表接口 ETag/304 生效
- [ ] 单元/集成测试通过

