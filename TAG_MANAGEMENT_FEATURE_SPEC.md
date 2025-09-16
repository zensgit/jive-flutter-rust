# 标签管理功能规格（Feature Spec）

## 目标与范围
- 目标：提供稳定、易用、可扩展的交易标签（Tags）系统，支持标签与分组的全生命周期管理，并与交易、规则引擎、统计报表无缝协作。
- 范围：服务端标准化标签/分组 API、前端统一状态/缓存与 UI 管理页、交易编辑中的打标体验、批量加/移标签与标签合并、用量统计与推荐。

## 角色与权限
- 普通用户：读取/创建/编辑/删除自己家庭（family）下的标签与分组，给交易加/移标签。
- 家庭管理员：同上；可执行标签合并、批量操作策略等高级操作（后续可细化 RBAC）。

## 数据模型（PostgreSQL）
- 现状：`transactions.tags TEXT[]` 已存在；后端读写该字段，规则引擎可“add_tag”。
- 新增：标准化标签与分组表（幂等与唯一性约束），并维护与 `transactions.tags` 的一致性。

### 新表与索引
- `tag_groups`
  - id UUID PK
  - family_id UUID NOT NULL
  - name VARCHAR(64) NOT NULL
  - color VARCHAR(16) NULL, icon VARCHAR(32) NULL
  - archived BOOLEAN DEFAULT false
  - created_at/updated_at TIMESTAMPTZ
  - 唯一索引：`UNIQUE (family_id, lower(name))`

- `tags`
  - id UUID PK
  - family_id UUID NOT NULL
  - group_id UUID NULL REFERENCES tag_groups(id) ON DELETE SET NULL
  - name VARCHAR(64) NOT NULL
  - color VARCHAR(16) NULL, icon VARCHAR(32) NULL
  - archived BOOLEAN DEFAULT false
  - usage_count INTEGER DEFAULT 0
  - last_used_at TIMESTAMPTZ NULL
  - created_at/updated_at TIMESTAMPTZ
  - 唯一索引：`UNIQUE (family_id, lower(name))`

- 一致性维护（应用层优先）：
  - 在对交易调用“加/移标签”或更新交易 tags 时：
    - upsert 对应 `tags` 记录（可选：仅当名称不存在时自动创建，或开启“仅使用已存在标签”开关）。
    - 更新 `usage_count`、`last_used_at`。

## API 设计（/api/v1）
- 标签 CRUD
  - GET `/tags?group_id=&q=&archived=&page=&page_size=` → { items, total, etag }
  - POST `/tags` { name, color?, icon?, group_id? } → Tag
  - PUT `/tags/:id` { name?, color?, icon?, group_id?, archived? } → Tag
  - DELETE `/tags/:id` → 204
  - 批量接口（可选）：POST `/tags/batch` { create:[], update:[], delete:[] }

- 标签合并/重命名
  - POST `/tags/merge` { from_ids: UUID[], to_id: UUID } → { merged: n }
  - PUT `/tags/:id/rename` { new_name: string, merge_on_conflict: boolean }

- 标签分组 CRUD
  - GET `/tag-groups`、POST `/tag-groups`、PUT `/tag-groups/:id`、DELETE `/tag-groups/:id`

- 交易与标签
  - POST `/transactions/:id/tags` { add: string[] } → 200（幂等）
  - DELETE `/transactions/:id/tags` { remove: string[] } → 200（幂等）
  - 批量：POST `/transactions/batch/tags` { ids: UUID[], add?: string[], remove?: string[] }

- 统计/建议
  - GET `/tags/summary` → [{ id, name, usage_count, last_used_at }]
  - GET `/tags/suggestions?q=` → [{ name, score }]

- 缓存/一致性
  - GET 列表类返回 `ETag`，客户端携带 `If-None-Match` 支持 304；更新操作返回新 `ETag` 或递增 version。

## 客户端（Flutter）
- 状态架构：Riverpod + Repository + Service
  - TagRepository：本地缓存 + 远端 API；ETag 增量拉取；乐观更新与失败回滚。
  - Providers：`tagsProvider`、`tagGroupsProvider`、`tagSummaryProvider`、`tagSuggestionsProvider`。

- UI 模块
  - 标签管理页：搜索/筛选、按分组折叠、创建/编辑/删除、归档/恢复、拖拽排序（本地顺序）
  - 交易编辑：标签选择器（常用优先、搜索建议、快速创建开关）
  - 批量工具条：批量加/移标签、标签合并（二次确认）

- 交互细节
  - 建议：按 `usage_count` 与最近使用时间排序，提高常用标签选择效率。
  - 快速创建：当输入未命中现有标签时给出“+ 创建标签”入口（可由设置开关控制）。

## 非功能性
- 性能：列表分页（page/page_size）、服务端排序/过滤；建议接口做 100ms 级别缓存。
- 安全：鉴权（家庭成员）、数据隔离（family_id ），速率限制（可选）。
- 审计：重要变更（合并/重命名/删除）写入审计日志（后续阶段）。

## 迁移与兼容
- 初期继续使用 `transactions.tags TEXT[]`；
- 引入 `tags`/`tag_groups` 表后：
  - 交易写入/修改时同时维护 `tags` 表的 `usage_count/last_used_at`。
  - 可提供一次性脚本：扫描历史 transactions.tags，回填 `tags` 与统计（后台任务）。

## 验收准则（Phase 1）
- 标签/分组 CRUD API 完整可用，唯一性/归档生效。
- 交易加/移标签接口幂等；usage_count 与 last_used_at 正确更新。
- 前端：标签管理页可创建/编辑/删除/归档/搜索；交易编辑可加/移标签、快速创建；ETag 生效。

