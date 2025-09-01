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

  /// 添加分类
  void addCategory(Category category) {
    final newCategory = category.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    state = [...state, newCategory];
    // TODO: 保存到存储
  }

  /// 更新分类
  void updateCategory(Category updatedCategory) {
    state = state.map((category) {
      if (category.id == updatedCategory.id) {
        return updatedCategory.copyWith(updatedAt: DateTime.now());
      }
      return category;
    }).toList();
    // TODO: 保存到存储
  }

  /// 删除分类
  void deleteCategory(String categoryId) {
    state = state.where((category) => 
      category.id != categoryId && category.parentId != categoryId
    ).toList();
    // TODO: 保存到存储
  }

  /// 添加子分类
  void addSubcategory(String parentId, Category subcategory) {
    final newSubcategory = subcategory.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      parentId: parentId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    
    state = [...state, newSubcategory];
    // TODO: 保存到存储
  }

  /// 合并分类
  void mergeCategories(String fromCategoryId, String toCategoryId) {
    // TODO: 实现分类合并逻辑
    // 1. 更新所有使用fromCategory的交易
    // 2. 删除fromCategory
    deleteCategory(fromCategoryId);
  }

  /// 更新分类使用次数
  void incrementUsageCount(String categoryId) {
    state = state.map((category) {
      if (category.id == categoryId) {
        return category.copyWith(
          usageCount: (category.usageCount ?? 0) + 1,
          updatedAt: DateTime.now(),
        );
      }
      return category;
    }).toList();
    // TODO: 保存到存储
  }

  /// 按分类获取子分类
  List<Category> getSubcategories(String parentId) {
    return state.where((category) => category.parentId == parentId).toList();
  }

  /// 按分类类型获取分类
  List<Category> getCategoriesByClassification(CategoryClassification classification) {
    return state.where((category) => category.classification == classification).toList();
  }
}

/// 分类Provider
final categoriesProvider = StateNotifierProvider<CategoryNotifier, List<Category>>((ref) {
  return CategoryNotifier();
});

/// 按分类类型过滤的Provider
final categoriesByClassificationProvider = Provider.family<List<Category>, CategoryClassification>((ref, classification) {
  final categories = ref.watch(categoriesProvider);
  return categories.where((category) => category.classification == classification).toList();
});

/// 父分类Provider
final parentCategoriesProvider = Provider.family<List<Category>, CategoryClassification>((ref, classification) {
  final categories = ref.watch(categoriesByClassificationProvider(classification));
  return categories.where((category) => category.parentId == null).toList();
});

/// 子分类Provider
final subcategoriesProvider = Provider.family<List<Category>, String>((ref, parentId) {
  final categories = ref.watch(categoriesProvider);
  return categories.where((category) => category.parentId == parentId).toList();
});