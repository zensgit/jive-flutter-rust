import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../services/api/category_service.dart';

/// 可拖拽排序的分类列表
class DraggableCategoryList extends ConsumerStatefulWidget {
  final String? ledgerId;
  final CategoryClassification? filterClassification;
  final bool enableDragSort;

  const DraggableCategoryList({
    Key? key,
    this.ledgerId,
    this.filterClassification,
    this.enableDragSort = true,
  }) : super(key: key);

  @override
  ConsumerState<DraggableCategoryList> createState() =>
      _DraggableCategoryListState();
}

class _DraggableCategoryListState extends ConsumerState<DraggableCategoryList>
    with TickerProviderStateMixin {
  late List<Category> _categories;
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late AnimationController _dragIndicatorController;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _dragIndicatorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _dragIndicatorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = ref.watch(userCategoriesProvider);

    // 过滤分类
    _categories = [...allCategories];
    if (widget.ledgerId != null) {
      _categories =
          _categories.where((c) => c.ledgerId == widget.ledgerId).toList();
    }
    if (widget.filterClassification != null) {
      _categories = _categories
          .where((c) => c.classification == widget.filterClassification)
          .toList();
    }

    // 按位置排序
    _categories.sort((a, b) => (a.position ?? 0).compareTo(b.position ?? 0));

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        actions: [
          // 排序模式切换
          IconButton(
            icon: AnimatedBuilder(
              animation: _dragIndicatorController,
              builder: (context, child) {
                return Icon(
                  widget.enableDragSort ? Icons.drag_handle : Icons.sort,
                  color: _isDragging ? theme.colorScheme.primary : null,
                );
              },
            ),
            onPressed: () {
              setState(() {
                _isDragging = !_isDragging;
                if (_isDragging) {
                  _dragIndicatorController.forward();
                } else {
                  _dragIndicatorController.reverse();
                }
              });
            },
            tooltip: _isDragging ? '完成排序' : '调整顺序',
          ),
        ],
      ),
      body: widget.enableDragSort && _isDragging
          ? _buildDraggableList()
          : _buildNormalList(),
    );
  }

  Widget _buildDraggableList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return _DraggableCategoryItem(
          key: ValueKey(category.id),
          category: category,
          index: index,
          isDragging: _isDragging,
        );
      },
      onReorder: _onReorder,
      proxyDecorator: _buildDragProxy,
    );
  }

  Widget _buildNormalList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return _CategoryListItem(
          category: category,
          index: index,
          onTap: () => _showCategoryOptions(category),
        );
      },
    );
  }

  Widget _buildDragProxy(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final double elevation = Tween<double>(
          begin: 0,
          end: 6,
        ).evaluate(animation);

        return Material(
          elevation: elevation,
          borderRadius: BorderRadius.circular(8),
          child: child,
        );
      },
      child: child,
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final Category item = _categories.removeAt(oldIndex);
      _categories.insert(newIndex, item);

      // 更新位置
      _updatePositions();
    });
  }

  void _updatePositions() async {
    final service = CategoryService();

    // 批量更新位置
    for (int i = 0; i < _categories.length; i++) {
      final category = _categories[i];
      if (category.position != i) {
        // 调用API更新位置
        await service.moveCategory(
          category.id,
          position: i,
        );

        // 更新本地状态
        _categories[i] = category.copyWith(position: i);
      }
    }

    // 显示保存成功提示
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('顺序已保存'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _showCategoryOptions(Category category) {
    showModalBottomSheet(
      context: context,
      builder: (context) => _CategoryOptionsSheet(category: category),
    );
  }
}

/// 可拖拽的分类项
class _DraggableCategoryItem extends StatelessWidget {
  final Category category;
  final int index;
  final bool isDragging;

  const _DraggableCategoryItem({
    Key? key,
    required this.category,
    required this.index,
    required this.isDragging,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽手柄
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isDragging ? 24 : 0,
              child: isDragging
                  ? Icon(
                      Icons.drag_indicator,
                      color: theme.colorScheme.onSurfaceVariant,
                    )
                  : const SizedBox.shrink(),
            ),
            // 分类图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  category.icon,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
          ],
        ),
        title: Text(category.name),
        subtitle: Text(
          '${_getClassificationText(category.classification)} • ${category.transactionCount} 笔交易',
          style: theme.textTheme.bodySmall,
        ),
        trailing: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isDragging ? 0.5 : 1.0,
          child: Text(
            '#${index + 1}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  String _getClassificationText(CategoryClassification classification) {
    switch (classification) {
      case CategoryClassification.income:
        return '收入';
      case CategoryClassification.expense:
        return '支出';
      case CategoryClassification.transfer:
        return '转账';
    }
  }
}

/// 普通分类列表项
class _CategoryListItem extends StatelessWidget {
  final Category category;
  final int index;
  final VoidCallback onTap;

  const _CategoryListItem({
    Key? key,
    required this.category,
    required this.index,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 分类图标
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(
                      int.parse(category.color.replaceFirst('#', '0xFF'))),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    category.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 分类信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          _getClassificationIcon(category.classification),
                          size: 14,
                          color:
                              _getClassificationColor(category.classification),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getClassificationText(category.classification),
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.receipt_long,
                            size: 14, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(
                          '${category.transactionCount}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 更多选项
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getClassificationIcon(CategoryClassification classification) {
    switch (classification) {
      case CategoryClassification.income:
        return Icons.arrow_downward;
      case CategoryClassification.expense:
        return Icons.arrow_upward;
      case CategoryClassification.transfer:
        return Icons.swap_horiz;
    }
  }

  Color _getClassificationColor(CategoryClassification classification) {
    switch (classification) {
      case CategoryClassification.income:
        return Colors.green;
      case CategoryClassification.expense:
        return Colors.red;
      case CategoryClassification.transfer:
        return Colors.blue;
    }
  }

  String _getClassificationText(CategoryClassification classification) {
    switch (classification) {
      case CategoryClassification.income:
        return '收入';
      case CategoryClassification.expense:
        return '支出';
      case CategoryClassification.transfer:
        return '转账';
    }
  }
}

/// 分类选项底部弹窗
class _CategoryOptionsSheet extends StatelessWidget {
  final Category category;

  const _CategoryOptionsSheet({
    Key? key,
    required this.category,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 分类信息头部
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(
                        int.parse(category.color.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      category.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: theme.textTheme.titleLarge,
                      ),
                      Text(
                        category.description ?? '暂无描述',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 32),

          // 操作选项
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('编辑分类'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/category/edit',
                  arguments: category);
            },
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text('转为标签'),
            subtitle: const Text('将此分类转换为标签'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 显示转换对话框
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('复制分类'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 显示复制对话框
            },
          ),
          ListTile(
            leading: const Icon(Icons.archive_outlined),
            title: const Text('归档分类'),
            onTap: () {
              Navigator.pop(context);
              // TODO: 归档分类
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete, color: theme.colorScheme.error),
            title:
                Text('删除分类', style: TextStyle(color: theme.colorScheme.error)),
            onTap: () {
              Navigator.pop(context);
              // TODO: 显示删除确认对话框
            },
          ),
        ],
      ),
    );
  }
}
