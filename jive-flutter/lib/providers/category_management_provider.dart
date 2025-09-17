import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart' as models;
import '../models/tag.dart';
import '../services/api/category_service.dart';
import 'tag_provider.dart';
import 'category_provider.dart';

/// 分类管理Provider - 处理分类的高级操作
class CategoryProvider extends ChangeNotifier {
  final CategoryService _categoryService;
  final Ref _ref;

  // 撤销操作历史
  final List<UndoableAction> _actionHistory = [];
  static const int _maxHistorySize = 10;

  CategoryProvider({
    required CategoryService categoryService,
    required Ref ref,
  })  : _categoryService = categoryService,
        _ref = ref;

  /// 转换分类为标签
  Future<void> convertCategoryToTag(
    String categoryId,
    String tagName, {
    bool applyToTransactions = true,
    bool deleteCategory = false,
  }) async {
    try {
      // 调用API执行转换
      final result = await _categoryService.convertToTag(
        categoryId,
        tagName: tagName,
        applyToTransactions: applyToTransactions,
        deleteCategory: deleteCategory,
      );

      // 创建新标签并添加到标签列表
      final newTag = Tag(
        id: result.tagId,
        name: result.tagName,
        color: '#4da568', // 默认颜色
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 更新标签状态
      await _ref.read(tagsProvider.notifier).addTag(newTag);

      // 如果选择删除分类，从分类列表中移除
      if (deleteCategory) {
        await _ref
            .read(userCategoriesProvider.notifier)
            .deleteCategory(categoryId);
      }

      // 记录撤销操作
      _addToHistory(CategoryToTagAction(
        categoryId: categoryId,
        tagId: result.tagId,
        tagName: result.tagName,
        categoryDeleted: deleteCategory,
        transactionsUpdated: result.transactionsUpdated,
      ));

      notifyListeners();
    } catch (e) {
      throw Exception('分类转标签失败: $e');
    }
  }

  /// 复制分类
  Future<void> duplicateCategory(String categoryId, String newName) async {
    try {
      // 获取原分类信息
      final categories = _ref.read(userCategoriesProvider);
      final originalCategory = categories.firstWhere((c) => c.id == categoryId);

      // 创建新分类
      final newCategory = models.Category(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        ledgerId: originalCategory.ledgerId,
        name: newName,
        classification: originalCategory.classification,
        color: originalCategory.color,
        icon: originalCategory.icon,
        parentId: originalCategory.parentId,
        description: originalCategory.description,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _ref
          .read(userCategoriesProvider.notifier)
          .createCategory(newCategory);

      // 记录撤销操作
      _addToHistory(DuplicateCategoryAction(
        originalId: categoryId,
        duplicateId: newCategory.id,
      ));

      notifyListeners();
    } catch (e) {
      throw Exception('复制分类失败: $e');
    }
  }

  /// 批量删除分类
  Future<void> batchDeleteCategories(List<String> categoryIds) async {
    try {
      final deletedCategories = <models.Category>[];

      for (final categoryId in categoryIds) {
        final categories = _ref.read(userCategoriesProvider);
        final category = categories.firstWhere((c) => c.id == categoryId);
        deletedCategories.add(category);

        await _categoryService.deleteCategory(categoryId, force: true);
        await _ref
            .read(userCategoriesProvider.notifier)
            .deleteCategory(categoryId);
      }

      // 记录撤销操作
      _addToHistory(BatchDeleteAction(
        deletedCategories: deletedCategories,
      ));

      notifyListeners();
    } catch (e) {
      throw Exception('批量删除失败: $e');
    }
  }

  /// 批量移动分类
  Future<void> batchMoveCategories(
    List<String> categoryIds,
    String? newParentId,
  ) async {
    try {
      final movedCategories = <MovedCategory>[];

      for (final categoryId in categoryIds) {
        final categories = _ref.read(userCategoriesProvider);
        final category = categories.firstWhere((c) => c.id == categoryId);

        movedCategories.add(MovedCategory(
          categoryId: categoryId,
          oldParentId: category.parentId,
          newParentId: newParentId,
        ));

        await _categoryService.moveCategory(
          categoryId,
          newParentId: newParentId,
        );
      }

      // 记录撤销操作
      _addToHistory(BatchMoveAction(
        movedCategories: movedCategories,
      ));

      notifyListeners();
    } catch (e) {
      throw Exception('批量移动失败: $e');
    }
  }

  /// 撤销最后一个操作
  Future<void> undoLastAction() async {
    if (_actionHistory.isEmpty) return;

    final lastAction = _actionHistory.removeLast();

    try {
      await lastAction.undo(_ref, _categoryService);
      notifyListeners();
    } catch (e) {
      // 如果撤销失败，将操作放回历史
      _actionHistory.add(lastAction);
      throw Exception('撤销操作失败: $e');
    }
  }

  /// 添加操作到历史
  void _addToHistory(UndoableAction action) {
    _actionHistory.add(action);

    // 限制历史大小
    if (_actionHistory.length > _maxHistorySize) {
      _actionHistory.removeAt(0);
    }
  }

  /// 清空操作历史
  void clearHistory() {
    _actionHistory.clear();
    notifyListeners();
  }

  /// 是否可以撤销
  bool get canUndo => _actionHistory.isNotEmpty;

  /// 获取最后操作描述
  String? get lastActionDescription {
    if (_actionHistory.isEmpty) return null;
    return _actionHistory.last.description;
  }
}

/// 可撤销操作的基类
abstract class UndoableAction {
  String get description;
  Future<void> undo(Ref ref, CategoryService service);
}

/// 分类转标签操作
class CategoryToTagAction extends UndoableAction {
  final String categoryId;
  final String tagId;
  final String tagName;
  final bool categoryDeleted;
  final int transactionsUpdated;

  CategoryToTagAction({
    required this.categoryId,
    required this.tagId,
    required this.tagName,
    required this.categoryDeleted,
    required this.transactionsUpdated,
  });

  @override
  String get description => '将分类转换为标签"$tagName"';

  @override
  Future<void> undo(Ref ref, CategoryService service) async {
    // 删除创建的标签
    await ref.read(tagsProvider.notifier).deleteTag(tagId);

    // 如果分类被删除了，需要恢复（这需要后端支持）
    if (categoryDeleted) {
      // TODO: 实现分类恢复逻辑
      throw UnimplementedError('分类恢复功能尚未实现');
    }
  }
}

/// 复制分类操作
class DuplicateCategoryAction extends UndoableAction {
  final String originalId;
  final String duplicateId;

  DuplicateCategoryAction({
    required this.originalId,
    required this.duplicateId,
  });

  @override
  String get description => '复制分类';

  @override
  Future<void> undo(Ref ref, CategoryService service) async {
    await ref.read(userCategoriesProvider.notifier).deleteCategory(duplicateId);
  }
}

/// 批量删除操作
class BatchDeleteAction extends UndoableAction {
  final List<models.Category> deletedCategories;

  BatchDeleteAction({
    required this.deletedCategories,
  });

  @override
  String get description => '删除${deletedCategories.length}个分类';

  @override
  Future<void> undo(Ref ref, CategoryService service) async {
    // 恢复删除的分类（需要后端支持）
    for (final category in deletedCategories) {
      await ref.read(userCategoriesProvider.notifier).createCategory(category);
    }
  }
}

/// 批量移动操作
class BatchMoveAction extends UndoableAction {
  final List<MovedCategory> movedCategories;

  BatchMoveAction({
    required this.movedCategories,
  });

  @override
  String get description => '移动${movedCategories.length}个分类';

  @override
  Future<void> undo(Ref ref, CategoryService service) async {
    // 恢复原位置
    for (final moved in movedCategories) {
      await service.moveCategory(
        moved.categoryId,
        newParentId: moved.oldParentId,
      );
    }
  }
}

/// 移动的分类信息
class MovedCategory {
  final String categoryId;
  final String? oldParentId;
  final String? newParentId;

  MovedCategory({
    required this.categoryId,
    required this.oldParentId,
    required this.newParentId,
  });
}

/// 分类管理Provider
final categoryManagementProvider =
    ChangeNotifierProvider<CategoryProvider>((ref) {
  return CategoryProvider(
    categoryService: CategoryService(),
    ref: ref,
  );
});
