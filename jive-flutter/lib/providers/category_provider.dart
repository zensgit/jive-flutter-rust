import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../models/category_template.dart';
import '../services/api/category_service_integrated.dart';

/// 分类服务提供器
final categoryServiceProvider = Provider<CategoryServiceIntegrated>((ref) {
  return CategoryServiceIntegrated();
});

/// 系统模板状态提供器
final systemTemplatesProvider = StateNotifierProvider<SystemTemplatesNotifier, AsyncValue<List<SystemCategoryTemplate>>>((ref) {
  return SystemTemplatesNotifier(ref.watch(categoryServiceProvider));
});

/// 用户分类状态提供器
final userCategoriesProvider = StateNotifierProvider<UserCategoriesNotifier, List<Category>>((ref) {
  return UserCategoriesNotifier(ref.watch(categoryServiceProvider));
});

/// 系统模板状态管理器
class SystemTemplatesNotifier extends StateNotifier<AsyncValue<List<SystemCategoryTemplate>>> {
  final CategoryServiceIntegrated _service;

  SystemTemplatesNotifier(this._service) : super(const AsyncValue.loading()) {
    _loadTemplates();
  }

  /// 加载模板
  Future<void> _loadTemplates() async {
    try {
      state = const AsyncValue.loading();
      final templates = await _service.getAllTemplates();
      state = AsyncValue.data(templates);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// 刷新模板
  Future<void> refresh({bool forceRefresh = false}) async {
    try {
      state = const AsyncValue.loading();
      final templates = await _service.getAllTemplates(forceRefresh: forceRefresh);
      state = AsyncValue.data(templates);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// 按分类获取模板
  Future<void> loadByClassification(CategoryClassification classification) async {
    try {
      state = const AsyncValue.loading();
      final templates = await _service.getTemplatesByClassification(classification);
      state = AsyncValue.data(templates);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// 按分组获取模板
  Future<void> loadByGroup(CategoryGroup group) async {
    try {
      state = const AsyncValue.loading();
      final templates = await _service.getTemplatesByGroup(group);
      state = AsyncValue.data(templates);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// 获取精选模板
  Future<void> loadFeatured() async {
    try {
      state = const AsyncValue.loading();
      final templates = await _service.getFeaturedTemplates();
      state = AsyncValue.data(templates);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// 搜索模板
  Future<void> search(String query) async {
    try {
      state = const AsyncValue.loading();
      final templates = await _service.searchTemplates(query);
      state = AsyncValue.data(templates);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// 用户分类状态管理器
class UserCategoriesNotifier extends StateNotifier<List<Category>> {
  final CategoryServiceIntegrated _service;

  UserCategoriesNotifier(this._service) : super([]) {
    _loadCategories();
  }

  /// 加载用户分类
  void _loadCategories() {
    state = _service.userCategories;
  }

  /// 创建分类
  Future<void> createCategory(Category category) async {
    try {
      final newCategory = await _service.createCategory(category);
      state = [...state, newCategory];
    } catch (error) {
      rethrow;
    }
  }

  /// 更新分类
  Future<void> updateCategory(Category category) async {
    try {
      await _service.updateCategory(category);
      final index = state.indexWhere((c) => c.id == category.id);
      if (index >= 0) {
        final newState = [...state];
        newState[index] = category;
        state = newState;
      }
    } catch (error) {
      rethrow;
    }
  }

  /// 删除分类
  Future<void> deleteCategory(String categoryId) async {
    try {
      await _service.deleteCategory(categoryId);
      state = state.where((c) => c.id != categoryId).toList();
    } catch (error) {
      rethrow;
    }
  }

  /// 从模板导入分类
  Future<void> importFromTemplate(
    SystemCategoryTemplate template,
    String ledgerId,
  ) async {
    try {
      final category = await _service.importTemplateAsCategory(template, ledgerId);
      state = [...state, category];
    } catch (error) {
      rethrow;
    }
  }

  /// 按账本ID获取分类
  List<Category> getCategoriesByLedger(String ledgerId) {
    return state.where((c) => c.ledgerId == ledgerId).toList();
  }

  /// 按分类类型获取分类
  List<Category> getCategoriesByClassification(CategoryClassification classification) {
    return state.where((c) => c.classification == classification).toList();
  }
}

/// 网络状态提供器
final networkStatusProvider = StateNotifierProvider<NetworkStatusNotifier, NetworkStatus>((ref) {
  return NetworkStatusNotifier(ref.watch(categoryServiceProvider));
});

/// 网络状态
class NetworkStatus {
  final bool isLoading;
  final bool hasNetworkData;
  final String? error;
  final DateTime? lastSync;

  const NetworkStatus({
    this.isLoading = false,
    this.hasNetworkData = false,
    this.error,
    this.lastSync,
  });

  NetworkStatus copyWith({
    bool? isLoading,
    bool? hasNetworkData,
    String? error,
    DateTime? lastSync,
  }) {
    return NetworkStatus(
      isLoading: isLoading ?? this.isLoading,
      hasNetworkData: hasNetworkData ?? this.hasNetworkData,
      error: error ?? this.error,
      lastSync: lastSync ?? this.lastSync,
    );
  }
}

/// 网络状态管理器
class NetworkStatusNotifier extends StateNotifier<NetworkStatus> {
  final CategoryServiceIntegrated _service;

  NetworkStatusNotifier(this._service) : super(const NetworkStatus()) {
    _service.addListener(_onServiceChanged);
    _updateState();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    _updateState();
  }

  void _updateState() {
    state = NetworkStatus(
      isLoading: _service.isLoading,
      hasNetworkData: _service.hasNetworkData,
      error: _service.error,
      lastSync: _service.lastSync,
    );
  }
}

/// 图标URL提供器
final iconUrlsProvider = Provider<Map<String, String>>((ref) {
  final service = ref.watch(categoryServiceProvider);
  return service.iconUrls;
});