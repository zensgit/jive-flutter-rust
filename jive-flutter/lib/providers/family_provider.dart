import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family.dart' as family_model;
import '../services/api/family_service.dart';
import 'auth_provider.dart';

/// Family状态
class FamilyState {
  final family_model.Family? currentFamily;
  final List<family_model.UserFamilyInfo> userFamilies;
  final bool isLoading;
  final String? error;

  const FamilyState({
    this.currentFamily,
    this.userFamilies = const [],
    this.isLoading = false,
    this.error,
  });

  FamilyState copyWith({
    family_model.Family? currentFamily,
    List<family_model.UserFamilyInfo>? userFamilies,
    bool? isLoading,
    String? error,
  }) {
    return FamilyState(
      currentFamily: currentFamily ?? this.currentFamily,
      userFamilies: userFamilies ?? this.userFamilies,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 获取当前用户在当前Family中的角色
  family_model.FamilyRole? get currentRole {
    if (currentFamily == null) return null;

    final familyInfo = userFamilies.firstWhere(
      (info) => info.family.id == currentFamily!.id,
      orElse: () => family_model.UserFamilyInfo(
        family: currentFamily!,
        role: family_model.FamilyRole.viewer,
        joinedAt: DateTime.now(),
      ),
    );

    return familyInfo.role;
  }

  /// 是否有管理权限
  bool get canManage => currentRole?.canManage ?? false;

  /// 是否可以记账
  bool get canWrite => currentRole?.canWrite ?? false;

  /// 是否是Owner
  bool get isOwner => currentRole?.isOwner ?? false;
}

/// Family控制器
class FamilyController extends StateNotifier<FamilyState> {
  final FamilyService _familyService;
  final Ref _ref;

  FamilyController(this._familyService, this._ref)
      : super(const FamilyState()) {
    _initialize();
  }

  /// 初始化
  Future<void> _initialize() async {
    // 监听认证状态变化
    _ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next.isAuthenticated && previous?.isAuthenticated != true) {
        // 用户刚登录，加载Family信息
        loadUserFamilies();
      } else if (!next.isAuthenticated && previous?.isAuthenticated == true) {
        // 用户登出，清空Family信息
        state = const FamilyState();
      }
    });

    // 如果已登录，加载Family信息
    final authState = _ref.read(authControllerProvider);
    if (authState.isAuthenticated) {
      await loadUserFamilies();
    }
  }

  /// 加载用户的所有Family
  Future<void> loadUserFamilies() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 获取用户的所有Family
      final families = await _familyService.getUserFamilies();

      // 获取当前Family
      family_model.Family? currentFamily;
      if (families.isNotEmpty) {
        // 优先选择标记为current的Family
        final currentFamilyInfo = families.firstWhere(
          (f) => f.isCurrent,
          orElse: () => families.first,
        );
        currentFamily = currentFamilyInfo.family;
      }

      state = state.copyWith(
        userFamilies: families,
        currentFamily: currentFamily,
        isLoading: false,
      );
    } catch (e) {
      debugPrint('加载Family失败: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 切换Family
  Future<bool> switchFamily(String familyId) async {
    // 检查是否是有效的Family
    final familyInfo = state.userFamilies.firstWhere(
      (f) => f.family.id == familyId,
      orElse: () => throw Exception('无效的Family'),
    );

    state = state.copyWith(isLoading: true, error: null);

    try {
      // 调用API切换Family
      await _familyService.switchFamily(familyId);

      // 更新本地状态
      final updatedFamilies = state.userFamilies.map((f) {
        return family_model.UserFamilyInfo(
          family: f.family,
          role: f.role,
          joinedAt: f.joinedAt,
          isCurrent: f.family.id == familyId,
        );
      }).toList();

      state = state.copyWith(
        currentFamily: familyInfo.family,
        userFamilies: updatedFamilies,
        isLoading: false,
      );

      // 触发数据刷新（如账本、交易等）
      _notifyDataRefresh();

      return true;
    } catch (e) {
      debugPrint('切换Family失败: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 创建新Family
  Future<bool> createFamily(family_model.CreateFamilyRequest request) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // 创建Family
      final newFamilyInfo = await _familyService.createFamily(request);

      // 更新本地状态
      final updatedFamilies = [
        ...state.userFamilies,
        newFamilyInfo,
      ];

      state = state.copyWith(
        userFamilies: updatedFamilies,
        currentFamily: newFamilyInfo.family,
        isLoading: false,
      );

      // 自动切换到新创建的Family
      await switchFamily(newFamilyInfo.family.id);

      return true;
    } catch (e) {
      debugPrint('创建Family失败: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 更新Family信息
  Future<bool> updateFamily(
      String familyId, Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedFamily =
          await _familyService.updateFamily(familyId, updates);

      // 更新本地状态
      final updatedFamilies = state.userFamilies.map((f) {
        if (f.family.id == familyId) {
          return family_model.UserFamilyInfo(
            family: updatedFamily,
            role: f.role,
            joinedAt: f.joinedAt,
            isCurrent: f.isCurrent,
          );
        }
        return f;
      }).toList();

      state = state.copyWith(
        userFamilies: updatedFamilies,
        currentFamily: state.currentFamily?.id == familyId
            ? updatedFamily
            : state.currentFamily,
        isLoading: false,
      );

      return true;
    } catch (e) {
      debugPrint('更新Family失败: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 离开Family
  Future<bool> leaveFamily(String familyId) async {
    // 不能离开最后一个Family
    if (state.userFamilies.length <= 1) {
      state = state.copyWith(error: '不能离开最后一个Family');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _familyService.leaveFamily(familyId);

      // 从列表中移除
      final updatedFamilies =
          state.userFamilies.where((f) => f.family.id != familyId).toList();

      // 如果离开的是当前Family，切换到另一个
      family_model.Family? newCurrentFamily = state.currentFamily;
      if (state.currentFamily?.id == familyId && updatedFamilies.isNotEmpty) {
        newCurrentFamily = updatedFamilies.first.family;
        await _familyService.switchFamily(newCurrentFamily.id);
      }

      state = state.copyWith(
        userFamilies: updatedFamilies,
        currentFamily: newCurrentFamily,
        isLoading: false,
      );

      return true;
    } catch (e) {
      debugPrint('离开Family失败: $e');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 通知数据刷新
  void _notifyDataRefresh() {
    // 这里可以触发其他Provider刷新数据
    // 例如：ledger、transaction等
    debugPrint('Family切换，触发数据刷新');
  }
}

/// Provider定义
final familyServiceProvider = Provider<FamilyService>((ref) {
  return FamilyService();
});

final familyControllerProvider =
    StateNotifierProvider<FamilyController, FamilyState>((ref) {
  final familyService = ref.watch(familyServiceProvider);
  return FamilyController(familyService, ref);
});

/// 当前Family Provider
final currentFamilyProvider = Provider<family_model.Family?>((ref) {
  final familyState = ref.watch(familyControllerProvider);
  return familyState.currentFamily;
});

/// 当前用户角色 Provider
final currentFamilyRoleProvider = Provider<family_model.FamilyRole?>((ref) {
  final familyState = ref.watch(familyControllerProvider);
  return familyState.currentRole;
});

/// 用户的所有Family Provider
final userFamiliesProvider = Provider<List<family_model.UserFamilyInfo>>((ref) {
  final familyState = ref.watch(familyControllerProvider);
  return familyState.userFamilies;
});

/// 是否可以管理当前Family
final canManageFamilyProvider = Provider<bool>((ref) {
  final familyState = ref.watch(familyControllerProvider);
  return familyState.canManage;
});

/// 是否可以在当前Family记账
final canWriteInFamilyProvider = Provider<bool>((ref) {
  final familyState = ref.watch(familyControllerProvider);
  return familyState.canWrite;
});
