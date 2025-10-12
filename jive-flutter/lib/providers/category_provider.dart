import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/models/category.dart' as category_model;
import 'package:jive_money/models/category_template.dart';

/// 分类服务提供器 (简化版本，暂不使用API服务)
// final categoryServiceProvider = Provider<CategoryService>((ref) {
//   return CategoryService();
// });

/// 系统模板状态提供器 (简化版本)
final systemTemplatesProvider = StateNotifierProvider<SystemTemplatesNotifier,
    AsyncValue<List<SystemCategoryTemplate>>>((ref) {
  return SystemTemplatesNotifier();
});

/// 用户分类状态提供器 (简化版本)
final userCategoriesProvider = StateNotifierProvider<UserCategoriesNotifier,
    List<category_model.Category>>((ref) {
  return UserCategoriesNotifier();
});

/// 系统模板管理器 (简化版本)
class SystemTemplatesNotifier extends StateNotifier<AsyncValue<List<SystemCategoryTemplate>>> {
  SystemTemplatesNotifier() : super(const AsyncValue.data([]));

  /// 加载所有模板 (简化实现)
  Future<void> loadAllTemplates({bool forceRefresh = false}) async {
    state = const AsyncValue.loading();
    try {
      // 简化：返回空列表，避免网络依赖
      state = const AsyncValue.data([]);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// 刷新模板 (简化实现)
  Future<void> refresh({bool forceRefresh = false}) async {
    return loadAllTemplates(forceRefresh: forceRefresh);
  }
}

/// 用户分类管理器 (简化版本)
class UserCategoriesNotifier extends StateNotifier<List<category_model.Category>> {
  UserCategoriesNotifier() : super([]);

  /// 加载用户分类 (简化实现)
  Future<void> loadUserCategories() async {
    // 简化：保持当前状态，避免API调用错误
    // 实际的分类加载逻辑将在后续PR中完善
  }

  /// 添加分类 (简化实现)
  Future<void> addCategory(category_model.Category category) async {
    // 简化：直接添加到本地状态
    state = [...state, category];
  }

  /// 创建分类 (简化实现)
  Future<void> createCategory(category_model.Category category) async {
    // 简化：与addCategory相同的逻辑
    return addCategory(category);
  }

  /// 更新分类 (简化实现)
  Future<void> updateCategory(category_model.Category category) async {
    // 简化：更新本地状态
    state = [
      for (final item in state)
        if (item.id == category.id) category else item,
    ];
  }

  /// 删除分类 (简化实现)
  Future<void> deleteCategory(String categoryId) async {
    // 简化：从本地状态移除
    state = state.where((item) => item.id != categoryId).toList();
  }

  /// 从后端刷新分类数据
  Future<void> refreshFromBackend({required String ledgerId}) async {
    // TODO: 实现从后端加载分类的逻辑
    // 目前简化实现，保持当前状态
  }
}

/// 模板网络状态提供器 (简化版本)
final templateNetworkStateProvider = Provider<TemplateNetworkState>((ref) {
  return const TemplateNetworkState(
    isLoading: false,
    hasLocalData: true,
    hasNetworkData: false,
    error: null,
    lastSync: null,
  );
});

/// 模板图标URL提供器 (简化版本)
final templateIconUrlsProvider = Provider<Map<String, String>>((ref) {
  return <String, String>{}; // 空的图标映射
});

/// 网络状态数据类
class TemplateNetworkState {
  final bool isLoading;
  final bool hasLocalData;
  final bool hasNetworkData;
  final String? error;
  final DateTime? lastSync;

  const TemplateNetworkState({
    required this.isLoading,
    required this.hasLocalData,
    required this.hasNetworkData,
    required this.error,
    required this.lastSync,
  });
}

/// 网络状态提供器（用于向后兼容）
final networkStatusProvider = Provider<TemplateNetworkState>((ref) {
  return const TemplateNetworkState(
    isLoading: false,
    hasLocalData: true,
    hasNetworkData: false,
    error: null,
    lastSync: null,
  );
});

/// 分类服务提供器（用于向后兼容）
final categoryServiceProvider = Provider((ref) {
  // 返回一个简化的服务实例，避免网络依赖
  return null; // 或者返回一个mock service
});