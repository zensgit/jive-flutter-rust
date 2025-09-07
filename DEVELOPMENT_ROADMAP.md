# 🚀 Jive Money 功能完善开发计划

## 📅 开发计划概览

**预计总工期**: 4-6周  
**开发模式**: 迭代式开发，每阶段可独立交付  
**优先级**: P0(必须) > P1(重要) > P2(优化)

## 🎯 第一阶段：核心功能补全 (1-2周)

### 1.1 完整邀请系统 [P0]
**目标**: 实现完整的Family成员邀请流程

#### 后端任务
```yaml
任务清单:
  - [ ] 实现 POST /invitations API端点
  - [ ] 实现 GET /invitations 获取待处理邀请
  - [ ] 实现 POST /invitations/accept 接受邀请
  - [ ] 实现 DELETE /invitations/:id 取消邀请
  - [ ] 实现 GET /invitations/validate/:code 验证邀请码
  - [ ] 添加邀请过期自动清理任务
```

#### 前端任务
```yaml
任务清单:
  - [ ] 创建 Invitation 模型 (models/invitation.dart)
  - [ ] 扩展 FamilyService 添加邀请相关方法
  - [ ] 创建 PendingInvitationsScreen 页面
  - [ ] 创建 AcceptInvitationDialog 组件
  - [ ] 在 FamilySettingsScreen 添加邀请码管理
  - [ ] 添加邀请通知提醒
```

#### 文件修改清单
```
新建文件:
├── lib/models/invitation.dart
├── lib/screens/invitations/pending_invitations_screen.dart
├── lib/screens/invitations/accept_invitation_dialog.dart
└── lib/widgets/invitation_code_card.dart

修改文件:
├── lib/services/api/family_service.dart (添加5个方法)
├── lib/screens/family/family_settings_screen.dart (添加邀请码管理)
├── lib/providers/invitation_provider.dart (新建)
└── lib/core/router/app_router.dart (添加邀请路由)
```

### 1.2 删除Family功能 [P0]
**目标**: 安全地删除Family及其所有数据

#### 前端任务
```yaml
任务清单:
  - [ ] 在 FamilyService 添加 deleteFamily() 方法
  - [ ] 创建 DeleteFamilyConfirmDialog 组件
  - [ ] 在 FamilySettingsScreen 实现删除功能
  - [ ] 添加级联删除警告
  - [ ] 处理删除后的导航逻辑
```

#### 实现代码示例
```dart
// services/api/family_service.dart
Future<void> deleteFamily(String familyId) async {
  try {
    await _client.delete('/families/$familyId');
  } catch (e) {
    throw _handleError(e);
  }
}

// widgets/dialogs/delete_family_dialog.dart
class DeleteFamilyConfirmDialog extends StatefulWidget {
  final Family family;
  // 要求输入家庭名称确认
  // 显示将删除的数据统计
  // 二次确认机制
}
```

### 1.3 基础权限检查系统 [P0]
**目标**: 在UI层实现权限控制

#### 前端任务
```yaml
任务清单:
  - [ ] 创建 PermissionService 服务
  - [ ] 创建 PermissionGuard Widget
  - [ ] 实现 hasPermission() 辅助方法
  - [ ] 在所有敏感操作前添加权限检查
  - [ ] 创建 NoPermissionScreen 页面
```

#### 实现示例
```dart
// services/permission_service.dart
class PermissionService {
  bool hasPermission(LedgerMember member, Permission permission) {
    // 根据角色和自定义权限判断
  }
  
  bool canEditFamily(LedgerMember member) {
    return member.role == LedgerRole.owner || 
           member.role == LedgerRole.admin;
  }
}

// widgets/permission_guard.dart
class PermissionGuard extends StatelessWidget {
  final Permission requiredPermission;
  final Widget child;
  final Widget? fallback;
  
  @override
  Widget build(BuildContext context) {
    if (hasPermission(requiredPermission)) {
      return child;
    }
    return fallback ?? SizedBox.shrink();
  }
}
```

## 🔧 第二阶段：功能增强 (2周)

### 2.1 审计日志系统 [P1]
**目标**: 记录和查看Family内的重要操作

#### 后端任务
```yaml
任务清单:
  - [ ] 实现 AuditService
  - [ ] 在所有修改操作中添加审计记录
  - [ ] 实现 GET /families/:id/audit-logs
  - [ ] 实现审计日志导出功能
```

#### 前端任务
```yaml
任务清单:
  - [ ] 创建 AuditLog 模型
  - [ ] 创建 AuditLogService
  - [ ] 创建 AuditLogsScreen 页面
  - [ ] 实现日志筛选和搜索
  - [ ] 添加导出功能
```

#### UI设计
```dart
// screens/audit/audit_logs_screen.dart
class AuditLogsScreen extends ConsumerStatefulWidget {
  // 时间范围选择器
  // 用户筛选器
  // 操作类型筛选器
  // 分页列表展示
  // 导出按钮
}
```

### 2.2 自定义权限设置 [P1]
**目标**: 允许Owner/Admin为成员设置细粒度权限

#### 前端任务
```yaml
任务清单:
  - [ ] 创建 Permission 枚举完整定义
  - [ ] 创建 PermissionEditScreen
  - [ ] 实现权限矩阵UI
  - [ ] 在 FamilyMembersScreen 添加权限编辑入口
  - [ ] 实现权限模板功能
```

#### 权限定义
```dart
enum Permission {
  // Family管理
  viewFamilyInfo,
  updateFamilyInfo,
  deleteFamily,
  
  // 成员管理
  viewMembers,
  inviteMembers,
  removeMembers,
  updateMemberRoles,
  
  // 账户管理
  viewAccounts,
  createAccounts,
  editAccounts,
  deleteAccounts,
  
  // 交易管理
  viewTransactions,
  createTransactions,
  editTransactions,
  deleteTransactions,
  bulkEditTransactions,
  
  // 预算管理
  viewBudgets,
  createBudgets,
  editBudgets,
  deleteBudgets,
  
  // 报表查看
  viewReports,
  exportReports,
  
  // 设置管理
  manageSettings,
  viewAuditLog,
}
```

### 2.3 邀请链接和二维码 [P1]
**目标**: 支持通过链接或二维码加入Family

#### 前端任务
```yaml
任务清单:
  - [ ] 生成邀请链接功能
  - [ ] 生成二维码功能 (qr_flutter包)
  - [ ] 创建 ShareInvitationSheet
  - [ ] 实现深链接处理
  - [ ] 创建扫码加入功能
```

## 🎨 第三阶段：用户体验优化 (1-2周)

### 3.1 权限可视化 [P2]
**目标**: 清晰展示用户在各Family中的权限

```yaml
任务清单:
  - [ ] 创建 MyPermissionsScreen
  - [ ] 权限对比表格
  - [ ] 权限变更历史
  - [ ] 权限说明文档
```

### 3.2 批量操作支持 [P2]
**目标**: 支持批量管理成员和权限

```yaml
任务清单:
  - [ ] 批量邀请成员
  - [ ] 批量更新权限
  - [ ] 批量移除成员
  - [ ] 操作确认和回滚
```

### 3.3 Family切换优化 [P2]
**目标**: 改善多Family切换体验

```yaml
任务清单:
  - [ ] Family快速切换手势
  - [ ] 最近使用的Family
  - [ ] Family搜索功能
  - [ ] 切换动画优化
```

## 📊 第四阶段：高级功能 (2周)

### 4.1 资源级权限控制 [P2]
**目标**: 实现账户/交易级别的权限控制

```yaml
任务清单:
  - [ ] 账户所有者概念
  - [ ] 私有/共享账户
  - [ ] 交易可见性控制
  - [ ] 预算访问控制
```

### 4.2 高级统计和报表 [P2]
**目标**: 提供更丰富的Family统计功能

```yaml
任务清单:
  - [ ] 成员贡献统计
  - [ ] 权限使用分析
  - [ ] 活跃度报表
  - [ ] 成本分摊计算
```

### 4.3 通知系统 [P2]
**目标**: 实时通知重要事件

```yaml
任务清单:
  - [ ] 邀请通知
  - [ ] 权限变更通知
  - [ ] 重要操作通知
  - [ ] 通知中心UI
```

## 🛠️ 技术债务清理

### 代码质量改进
```yaml
任务清单:
  - [ ] 添加单元测试 (目标覆盖率>60%)
  - [ ] 添加集成测试
  - [ ] 代码重构和优化
  - [ ] 文档完善
  - [ ] 性能优化
```

### 错误处理增强
```yaml
任务清单:
  - [ ] 统一错误处理机制
  - [ ] 用户友好的错误提示
  - [ ] 错误恢复机制
  - [ ] 离线模式支持
```

## 📝 每个阶段的交付标准

### 阶段交付要求
1. **功能完整性**: 所有计划功能已实现
2. **测试覆盖**: 核心功能有测试覆盖
3. **文档更新**: API文档和用户指南更新
4. **代码审查**: 通过代码质量检查
5. **用户测试**: 基础用户测试通过

### 验收标准
- [ ] 功能可正常使用
- [ ] 无阻塞性bug
- [ ] 性能符合要求
- [ ] UI/UX符合设计规范
- [ ] 安全性检查通过

## 🎯 快速开始建议

### 本周可完成的任务 (Quick Wins)
1. **Day 1-2**: 实现删除Family功能
2. **Day 3-4**: 完善邀请系统API调用
3. **Day 5**: 添加基础权限检查

### 下周重点
1. 完整的邀请流程UI
2. 权限系统框架
3. 审计日志基础

## 📊 进度追踪模板

```markdown
## Week 1 Progress
- [x] 删除Family功能
- [ ] 邀请API集成
- [ ] 权限检查框架
- [ ] 邀请UI页面

完成度: ██░░░░░░░░ 20%
```

## 🔗 相关资源

- API设计文档: `/jive-api/docs/TODO_*.md`
- Flutter项目: `/jive-flutter/`
- 数据库架构: `/database/`
- 测试用例: `/tests/`

## 💡 开发建议

1. **优先完成P0任务** - 这些是核心功能缺失
2. **迭代式开发** - 每个功能独立完成和测试
3. **保持向后兼容** - 不破坏现有功能
4. **注重用户体验** - 添加loading状态和错误处理
5. **及时更新文档** - 保持文档与代码同步

---

**计划创建日期**: 2025-01-06  
**预计完成日期**: 2025-02-20  
**负责人**: Development Team  
**状态**: 📝 待开始