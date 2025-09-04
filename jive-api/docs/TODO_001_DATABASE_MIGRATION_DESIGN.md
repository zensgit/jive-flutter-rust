# TODO 001: 数据库迁移脚本设计说明

## 设计目标

增强现有数据库结构以支持多Family协作功能，包括：
- 用户多Family归属
- 智能邀请机制
- 细粒度权限管理
- 审计日志

## 数据库变更详情

### 1. users 表增强
- **current_family_id**: 记录用户当前选择的Family
- **preferences**: 存储用户偏好设置（JSON格式）

### 2. families 表增强
- **currency**: 货币类型（默认CNY）
- **timezone**: 时区设置（默认Asia/Shanghai）
- **locale**: 地区语言（默认zh-CN）
- **date_format**: 日期格式（默认YYYY-MM-DD）

### 3. family_members 表增强
- **permissions**: 细粒度权限列表（JSON数组）
- **invited_by**: 邀请人ID
- **is_active**: 成员状态
- **last_active_at**: 最后活跃时间

### 4. 新增 invitations 表
用于管理Family邀请流程：
- 支持邀请码和邀请链接
- 自动过期机制（7天）
- 状态追踪（pending/accepted/expired/cancelled）

### 5. 新增 family_audit_logs 表
记录Family内的重要操作：
- 成员变更
- 权限修改
- 数据删除
- IP和User-Agent追踪

## 设计考虑

### 向后兼容性
- 所有字段使用 IF NOT EXISTS 确保幂等性
- 新字段都有默认值，不影响现有数据

### 性能优化
- 为常用查询字段创建索引
- 使用JSONB而非JSON以支持索引

### 数据完整性
- 外键约束确保引用完整性
- CHECK约束验证角色合法性
- 级联删除防止孤儿数据

## 实施影响

### 对现有功能的影响
- 无破坏性变更
- 现有API继续正常工作
- 逐步迁移到新架构

### 数据迁移需求
- 为现有用户设置current_family_id
- 为现有families补充默认设置
- 创建缺失的family_members记录