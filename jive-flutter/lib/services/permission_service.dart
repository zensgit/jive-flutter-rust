import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family.dart' as family_model;
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/family_provider.dart';

/// 权限操作枚举
enum PermissionAction {
  // 家庭管理
  viewFamily,
  editFamily,
  deleteFamily,
  archiveFamily,
  
  // 成员管理
  viewMembers,
  inviteMembers,
  removeMembers,
  editMemberRoles,
  
  // 交易管理
  viewTransactions,
  createTransactions,
  editTransactions,
  deleteTransactions,
  exportTransactions,
  
  // 分类管理
  viewCategories,
  createCategories,
  editCategories,
  deleteCategories,
  
  // 标签管理
  viewTags,
  createTags,
  editTags,
  deleteTags,
  
  // 报表查看
  viewReports,
  exportReports,
  
  // 设置管理
  viewSettings,
  editSettings,
  
  // 审计日志
  viewAuditLogs,
}

/// 权限服务
class PermissionService {
  final Ref _ref;
  
  PermissionService(this._ref);
  
  /// 获取当前用户
  User? get currentUser => _ref.read(authStateProvider).value;
  
  /// 检查用户是否有权限执行特定操作
  bool hasPermission({
    required String familyId,
    required PermissionAction action,
    String? targetUserId,
  }) {
    if (currentUser == null) return false;
    
    // 获取用户在家庭中的角色
    final userRole = getUserRole(familyId);
    if (userRole == null) return false;
    
    // 根据角色和操作类型判断权限
    return _checkPermission(userRole, action, targetUserId);
  }
  
  /// 批量检查权限
  Map<PermissionAction, bool> checkPermissions({
    required String familyId,
    required List<PermissionAction> actions,
  }) {
    final results = <PermissionAction, bool>{};
    
    for (final action in actions) {
      results[action] = hasPermission(
        familyId: familyId,
        action: action,
      );
    }
    
    return results;
  }
  
  /// 获取用户在家庭中的角色
  family_model.FamilyRole? getUserRole(String familyId) {
    final families = _ref.read(familyProvider);
    
    if (families == null) return null;
    
    try {
      final family = families.firstWhere((f) => f.id == familyId);
      
      // 检查是否是拥有者
      if (family.ownerId == currentUser?.id) {
        return family_model.FamilyRole.owner;
      }
      
      // 从成员列表中获取角色
      // TODO: 需要从成员列表中获取实际角色
      // 这里暂时返回默认角色
      return family_model.FamilyRole.member;
    } catch (e) {
      return null;
    }
  }
  
  /// 检查是否是家庭拥有者
  bool isOwner(String familyId) {
    return getUserRole(familyId) == family_model.FamilyRole.owner;
  }
  
  /// 检查是否是管理员或更高权限
  bool isAdmin(String familyId) {
    final role = getUserRole(familyId);
    return role == family_model.FamilyRole.owner || 
           role == family_model.FamilyRole.admin;
  }
  
  /// 检查是否可以编辑（成员或更高权限）
  bool canEdit(String familyId) {
    final role = getUserRole(familyId);
    return role != null && role != family_model.FamilyRole.viewer;
  }
  
  /// 检查是否可以查看（任何角色）
  bool canView(String familyId) {
    return getUserRole(familyId) != null;
  }
  
  /// 根据角色检查具体权限
  bool _checkPermission(
    family_model.FamilyRole role,
    PermissionAction action,
    String? targetUserId,
  ) {
    // 拥有者拥有所有权限
    if (role == family_model.FamilyRole.owner) {
      return true;
    }
    
    // 根据不同角色和操作类型判断
    switch (action) {
      // 查看权限 - 所有角色都有
      case PermissionAction.viewFamily:
      case PermissionAction.viewMembers:
      case PermissionAction.viewTransactions:
      case PermissionAction.viewCategories:
      case PermissionAction.viewTags:
      case PermissionAction.viewReports:
      case PermissionAction.viewSettings:
        return true;
      
      // 管理员权限
      case PermissionAction.editFamily:
      case PermissionAction.inviteMembers:
      case PermissionAction.removeMembers:
      case PermissionAction.editMemberRoles:
      case PermissionAction.exportTransactions:
      case PermissionAction.exportReports:
      case PermissionAction.editSettings:
      case PermissionAction.viewAuditLogs:
        return role == family_model.FamilyRole.admin;
      
      // 成员权限
      case PermissionAction.createTransactions:
      case PermissionAction.editTransactions:
      case PermissionAction.createCategories:
      case PermissionAction.editCategories:
      case PermissionAction.createTags:
      case PermissionAction.editTags:
        return role == family_model.FamilyRole.admin || 
               role == family_model.FamilyRole.member;
      
      // 删除权限 - 仅管理员
      case PermissionAction.deleteTransactions:
      case PermissionAction.deleteCategories:
      case PermissionAction.deleteTags:
        return role == family_model.FamilyRole.admin;
      
      // 危险操作 - 仅拥有者
      case PermissionAction.deleteFamily:
      case PermissionAction.archiveFamily:
        return false; // 已在开始检查过owner权限
      
      default:
        return false;
    }
  }
  
  /// 获取角色的权限列表
  List<PermissionAction> getRolePermissions(family_model.FamilyRole role) {
    switch (role) {
      case family_model.FamilyRole.owner:
        return PermissionAction.values;
      
      case family_model.FamilyRole.admin:
        return [
          PermissionAction.viewFamily,
          PermissionAction.editFamily,
          PermissionAction.viewMembers,
          PermissionAction.inviteMembers,
          PermissionAction.removeMembers,
          PermissionAction.editMemberRoles,
          PermissionAction.viewTransactions,
          PermissionAction.createTransactions,
          PermissionAction.editTransactions,
          PermissionAction.deleteTransactions,
          PermissionAction.exportTransactions,
          PermissionAction.viewCategories,
          PermissionAction.createCategories,
          PermissionAction.editCategories,
          PermissionAction.deleteCategories,
          PermissionAction.viewTags,
          PermissionAction.createTags,
          PermissionAction.editTags,
          PermissionAction.deleteTags,
          PermissionAction.viewReports,
          PermissionAction.exportReports,
          PermissionAction.viewSettings,
          PermissionAction.editSettings,
          PermissionAction.viewAuditLogs,
        ];
      
      case family_model.FamilyRole.member:
        return [
          PermissionAction.viewFamily,
          PermissionAction.viewMembers,
          PermissionAction.viewTransactions,
          PermissionAction.createTransactions,
          PermissionAction.editTransactions,
          PermissionAction.viewCategories,
          PermissionAction.createCategories,
          PermissionAction.editCategories,
          PermissionAction.viewTags,
          PermissionAction.createTags,
          PermissionAction.editTags,
          PermissionAction.viewReports,
          PermissionAction.viewSettings,
        ];
      
      case family_model.FamilyRole.viewer:
        return [
          PermissionAction.viewFamily,
          PermissionAction.viewMembers,
          PermissionAction.viewTransactions,
          PermissionAction.viewCategories,
          PermissionAction.viewTags,
          PermissionAction.viewReports,
          PermissionAction.viewSettings,
        ];
    }
  }
  
  /// 获取权限操作的显示名称
  String getActionDisplayName(PermissionAction action) {
    switch (action) {
      case PermissionAction.viewFamily:
        return '查看家庭信息';
      case PermissionAction.editFamily:
        return '编辑家庭信息';
      case PermissionAction.deleteFamily:
        return '删除家庭';
      case PermissionAction.archiveFamily:
        return '归档家庭';
      case PermissionAction.viewMembers:
        return '查看成员';
      case PermissionAction.inviteMembers:
        return '邀请成员';
      case PermissionAction.removeMembers:
        return '移除成员';
      case PermissionAction.editMemberRoles:
        return '编辑成员角色';
      case PermissionAction.viewTransactions:
        return '查看交易';
      case PermissionAction.createTransactions:
        return '创建交易';
      case PermissionAction.editTransactions:
        return '编辑交易';
      case PermissionAction.deleteTransactions:
        return '删除交易';
      case PermissionAction.exportTransactions:
        return '导出交易';
      case PermissionAction.viewCategories:
        return '查看分类';
      case PermissionAction.createCategories:
        return '创建分类';
      case PermissionAction.editCategories:
        return '编辑分类';
      case PermissionAction.deleteCategories:
        return '删除分类';
      case PermissionAction.viewTags:
        return '查看标签';
      case PermissionAction.createTags:
        return '创建标签';
      case PermissionAction.editTags:
        return '编辑标签';
      case PermissionAction.deleteTags:
        return '删除标签';
      case PermissionAction.viewReports:
        return '查看报表';
      case PermissionAction.exportReports:
        return '导出报表';
      case PermissionAction.viewSettings:
        return '查看设置';
      case PermissionAction.editSettings:
        return '编辑设置';
      case PermissionAction.viewAuditLogs:
        return '查看审计日志';
    }
  }
  
  /// 获取权限操作的描述
  String getActionDescription(PermissionAction action) {
    switch (action) {
      case PermissionAction.viewFamily:
        return '查看家庭的基本信息和统计数据';
      case PermissionAction.editFamily:
        return '修改家庭名称、描述和设置';
      case PermissionAction.deleteFamily:
        return '永久删除家庭及所有相关数据';
      case PermissionAction.archiveFamily:
        return '归档家庭，暂时隐藏但保留数据';
      case PermissionAction.viewMembers:
        return '查看家庭成员列表和角色';
      case PermissionAction.inviteMembers:
        return '邀请新成员加入家庭';
      case PermissionAction.removeMembers:
        return '将成员从家庭中移除';
      case PermissionAction.editMemberRoles:
        return '修改成员的角色和权限';
      case PermissionAction.viewTransactions:
        return '查看所有交易记录';
      case PermissionAction.createTransactions:
        return '添加新的收入或支出记录';
      case PermissionAction.editTransactions:
        return '修改现有交易信息';
      case PermissionAction.deleteTransactions:
        return '删除交易记录';
      case PermissionAction.exportTransactions:
        return '导出交易数据到文件';
      case PermissionAction.viewCategories:
        return '查看分类列表';
      case PermissionAction.createCategories:
        return '创建新的分类';
      case PermissionAction.editCategories:
        return '修改分类信息';
      case PermissionAction.deleteCategories:
        return '删除分类';
      case PermissionAction.viewTags:
        return '查看标签列表';
      case PermissionAction.createTags:
        return '创建新的标签';
      case PermissionAction.editTags:
        return '修改标签信息';
      case PermissionAction.deleteTags:
        return '删除标签';
      case PermissionAction.viewReports:
        return '查看统计报表和图表';
      case PermissionAction.exportReports:
        return '导出报表数据';
      case PermissionAction.viewSettings:
        return '查看家庭设置';
      case PermissionAction.editSettings:
        return '修改家庭设置';
      case PermissionAction.viewAuditLogs:
        return '查看操作日志和历史记录';
    }
  }
}

/// Provider for PermissionService
final permissionServiceProvider = Provider((ref) => PermissionService(ref));