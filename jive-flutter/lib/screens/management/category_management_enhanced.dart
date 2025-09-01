import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../models/category.dart';
import '../../core/theme/app_theme.dart';

/// 增强版分类管理页面
/// 实现设计文档中的所有交互功能
class CategoryManagementEnhancedPage extends StatefulWidget {
  const CategoryManagementEnhancedPage({Key? key}) : super(key: key);

  @override
  State<CategoryManagementEnhancedPage> createState() => _CategoryManagementEnhancedPageState();
}

class _CategoryManagementEnhancedPageState extends State<CategoryManagementEnhancedPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  CategoryClassification _selectedClassification = CategoryClassification.expense;
  bool _isSelectionMode = false;
  final Set<String> _selectedCategories = {};
  String? _draggedCategoryId;
  bool _showSystemTemplates = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedClassification = CategoryClassification.values[_tabController.index];
      });
    });
    
    // 加载分类数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatisticsPanel(),
          _buildSearchBar(),
          _buildTabBar(),
          Expanded(
            child: _buildCategoryContent(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
      bottomSheet: _isSelectionMode ? _buildBatchOperationBar() : null,
    );
  }

  /// 构建应用栏
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(_isSelectionMode 
        ? '已选择 ${_selectedCategories.length} 个分类'
        : '分类管理'),
      actions: [
        if (_isSelectionMode) ...[
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: '全选',
            onPressed: _selectAll,
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '退出选择',
            onPressed: () {
              setState(() {
                _isSelectionMode = false;
                _selectedCategories.clear();
              });
            },
          ),
        ] else ...[
          IconButton(
            icon: const Icon(Icons.library_books),
            tooltip: '分类模板库',
            onPressed: _showTemplateLibrary,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_upload),
                  title: Text('导入分类'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('导出分类'),
                  dense: true,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'batch',
                child: ListTile(
                  leading: Icon(Icons.checklist),
                  title: Text('批量操作'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'stats',
                child: ListTile(
                  leading: Icon(Icons.analytics),
                  title: Text('使用统计'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 构建统计面板
  Widget _buildStatisticsPanel() {
    return Consumer<CategoryProvider>(
      builder: (context, provider, _) {
        final stats = provider.categoryStats;
        
        return Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatCard(
                icon: Icons.category,
                label: '总分类',
                value: '${stats?.totalCategories ?? 0}',
                color: Colors.blue,
              ),
              _StatCard(
                icon: Icons.add_circle,
                label: '收入',
                value: '${stats?.incomeCategories ?? 0}',
                color: Colors.green,
              ),
              _StatCard(
                icon: Icons.remove_circle,
                label: '支出',
                value: '${stats?.expenseCategories ?? 0}',
                color: Colors.red,
              ),
              _StatCard(
                icon: Icons.swap_horiz,
                label: '转账',
                value: '${stats?.transferCategories ?? 0}',
                color: Colors.orange,
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索分类...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context.read<CategoryProvider>().clearSearch();
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
        ),
        onChanged: (value) {
          context.read<CategoryProvider>().searchCategories(value);
        },
      ),
    );
  }

  /// 构建Tab栏
  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      tabs: const [
        Tab(text: '支出', icon: Icon(Icons.remove_circle_outline)),
        Tab(text: '收入', icon: Icon(Icons.add_circle_outline)),
        Tab(text: '转账', icon: Icon(Icons.swap_horiz)),
      ],
    );
  }

  /// 构建分类内容
  Widget _buildCategoryContent() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildCategoryList(CategoryClassification.expense),
        _buildCategoryList(CategoryClassification.income),
        _buildCategoryList(CategoryClassification.transfer),
      ],
    );
  }

  /// 构建分类列表
  Widget _buildCategoryList(CategoryClassification classification) {
    return Consumer<CategoryProvider>(
      builder: (context, provider, _) {
        final categories = provider.getCategoriesByClassification(classification);
        
        if (categories.isEmpty) {
          return _buildEmptyState();
        }
        
        return ReorderableListView.builder(
          onReorder: (oldIndex, newIndex) {
            _handleReorder(categories, oldIndex, newIndex);
          },
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final hasChildren = provider.hasChildren(category.id);
            
            return _CategoryListItem(
              key: ValueKey(category.id),
              category: category,
              hasChildren: hasChildren,
              isSelected: _selectedCategories.contains(category.id),
              isSelectionMode: _isSelectionMode,
              onTap: () => _handleCategoryTap(category),
              onLongPress: () => _enterSelectionMode(category.id),
              onTransactionCountTap: () => _showCategoryTransactions(category),
              onMenuSelected: (action) => _handleCategoryAction(action, category),
              onDragStarted: () {
                setState(() {
                  _draggedCategoryId = category.id;
                });
              },
              onDragEnd: () {
                setState(() {
                  _draggedCategoryId = null;
                });
              },
              onAcceptDrop: (droppedCategory) {
                _handleDrop(droppedCategory, category);
              },
            );
          },
        );
      },
    );
  }

  /// 构建空状态
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.category_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无分类',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮创建分类或从模板导入',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showTemplateLibrary,
            icon: const Icon(Icons.library_books),
            label: const Text('浏览模板库'),
          ),
        ],
      ),
    );
  }

  /// 构建浮动操作按钮
  Widget _buildFloatingActionButtons() {
    if (_isSelectionMode) return const SizedBox.shrink();
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: 'template',
          mini: true,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          onPressed: _showTemplateLibrary,
          tooltip: '从模板导入',
          child: const Icon(Icons.library_add),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'add',
          onPressed: _createNewCategory,
          tooltip: '新建分类',
          child: const Icon(Icons.add),
        ),
      ],
    );
  }

  /// 构建批量操作栏
  Widget _buildBatchOperationBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: _selectedCategories.isEmpty ? null : _batchMove,
            icon: const Icon(Icons.drive_file_move),
            label: const Text('移动'),
          ),
          TextButton.icon(
            onPressed: _selectedCategories.isEmpty ? null : _batchConvertToTags,
            icon: const Icon(Icons.label),
            label: const Text('转为标签'),
          ),
          TextButton.icon(
            onPressed: _selectedCategories.isEmpty ? null : _batchMerge,
            icon: const Icon(Icons.merge),
            label: const Text('合并'),
          ),
          TextButton.icon(
            onPressed: _selectedCategories.isEmpty ? null : _batchDelete,
            icon: const Icon(Icons.delete),
            label: const Text('删除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  // ============= 事件处理方法 =============

  void _handleCategoryTap(Category category) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedCategories.contains(category.id)) {
          _selectedCategories.remove(category.id);
        } else {
          _selectedCategories.add(category.id);
        }
      });
    } else {
      _editCategory(category);
    }
  }

  void _enterSelectionMode(String categoryId) {
    setState(() {
      _isSelectionMode = true;
      _selectedCategories.add(categoryId);
    });
  }

  void _selectAll() {
    final provider = context.read<CategoryProvider>();
    final categories = provider.getCategoriesByClassification(_selectedClassification);
    
    setState(() {
      if (_selectedCategories.length == categories.length) {
        _selectedCategories.clear();
      } else {
        _selectedCategories.clear();
        _selectedCategories.addAll(categories.map((c) => c.id));
      }
    });
  }

  void _handleReorder(List<Category> categories, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    final category = categories[oldIndex];
    context.read<CategoryProvider>().reorderCategory(
      category.id,
      newIndex,
    );
  }

  void _handleDrop(Category draggedCategory, Category targetCategory) {
    // 验证是否可以接受拖放
    if (!_canAcceptDrop(draggedCategory, targetCategory)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法移动到该位置')),
      );
      return;
    }
    
    // 更新父级关系
    context.read<CategoryProvider>().updateCategoryParent(
      draggedCategory.id,
      targetCategory.id,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将"${draggedCategory.name}"移动到"${targetCategory.name}"'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            context.read<CategoryProvider>().undoLastAction();
          },
        ),
      ),
    );
  }

  bool _canAcceptDrop(Category dragged, Category target) {
    // 不能拖到自己
    if (dragged.id == target.id) return false;
    
    // 不能拖到自己的子分类
    final provider = context.read<CategoryProvider>();
    if (provider.isDescendant(target.id, dragged.id)) return false;
    
    // 分类类型必须一致
    if (dragged.classification != target.classification) return false;
    
    // 层级限制：最多两层
    if (target.parentId != null && provider.hasChildren(dragged.id)) return false;
    
    return true;
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'import':
        _importCategories();
        break;
      case 'export':
        _exportCategories();
        break;
      case 'batch':
        setState(() {
          _isSelectionMode = true;
        });
        break;
      case 'stats':
        _showStatistics();
        break;
    }
  }

  void _handleCategoryAction(String action, Category category) {
    switch (action) {
      case 'edit':
        _editCategory(category);
        break;
      case 'convert':
        _convertToTag(category);
        break;
      case 'duplicate':
        _duplicateCategory(category);
        break;
      case 'delete':
        _deleteCategory(category);
        break;
    }
  }

  // ============= 功能方法 =============

  void _createNewCategory() {
    Navigator.pushNamed(context, '/category/create', arguments: {
      'classification': _selectedClassification,
    });
  }

  void _editCategory(Category category) {
    Navigator.pushNamed(context, '/category/edit', arguments: category);
  }

  void _showCategoryTransactions(Category category) {
    Navigator.pushNamed(context, '/category/transactions', arguments: category);
  }

  void _showTemplateLibrary() {
    Navigator.pushNamed(context, '/category/templates');
  }

  void _convertToTag(Category category) {
    showDialog(
      context: context,
      builder: (context) => _CategoryToTagDialog(category: category),
    );
  }

  void _duplicateCategory(Category category) {
    showDialog(
      context: context,
      builder: (context) => _DuplicateCategoryDialog(category: category),
    );
  }

  void _deleteCategory(Category category) {
    final provider = context.read<CategoryProvider>();
    final hasTransactions = category.transactionCount > 0;
    
    if (hasTransactions) {
      showDialog(
        context: context,
        builder: (context) => _CategoryDeletionDialog(category: category),
      );
    } else {
      // 直接删除
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除分类'),
          content: Text('确定要删除分类"${category.name}"吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                provider.deleteCategory(category.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已删除分类"${category.name}"')),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        ),
      );
    }
  }

  void _importCategories() {
    // TODO: 实现导入功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导入功能开发中...')),
    );
  }

  void _exportCategories() {
    // TODO: 实现导出功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中...')),
    );
  }

  void _showStatistics() {
    Navigator.pushNamed(context, '/category/statistics');
  }

  void _batchMove() {
    // TODO: 实现批量移动
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('批量移动功能开发中...')),
    );
  }

  void _batchConvertToTags() {
    // TODO: 实现批量转标签
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('批量转标签功能开发中...')),
    );
  }

  void _batchMerge() {
    // TODO: 实现批量合并
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('批量合并功能开发中...')),
    );
  }

  void _batchDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量删除'),
        content: Text('确定要删除选中的 ${_selectedCategories.length} 个分类吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final provider = context.read<CategoryProvider>();
              for (final id in _selectedCategories) {
                provider.deleteCategory(id);
              }
              Navigator.pop(context);
              setState(() {
                _isSelectionMode = false;
                _selectedCategories.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除 ${_selectedCategories.length} 个分类')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 统计卡片组件
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// 分类列表项组件
class _CategoryListItem extends StatelessWidget {
  final Category category;
  final bool hasChildren;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onTransactionCountTap;
  final Function(String) onMenuSelected;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final Function(Category) onAcceptDrop;

  const _CategoryListItem({
    Key? key,
    required this.category,
    required this.hasChildren,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onTransactionCountTap,
    required this.onMenuSelected,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onAcceptDrop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DragTarget<Category>(
      onWillAccept: (data) => data != null && data.id != category.id,
      onAccept: onAcceptDrop,
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;
        
        return LongPressDraggable<Category>(
          data: category,
          onDragStarted: onDragStarted,
          onDragEnd: (_) => onDragEnd(),
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                    ),
                    child: category.icon != null
                        ? Center(child: Text(category.icon!, style: const TextStyle(fontSize: 12)))
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(category.name),
                ],
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildListTile(context, false),
          ),
          child: _buildListTile(context, isDropTarget),
        );
      },
    );
  }

  Widget _buildListTile(BuildContext context, bool isDropTarget) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected 
            ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
            : isDropTarget
                ? Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3)
                : null,
        border: isDropTarget
            ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
            : null,
      ),
      child: ListTile(
        leading: isSelectionMode
            ? Checkbox(
                value: isSelected,
                onChanged: (_) => onTap(),
              )
            : Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
                  shape: BoxShape.circle,
                ),
                child: category.icon != null
                    ? Center(child: Text(category.icon!, style: const TextStyle(fontSize: 20)))
                    : const Icon(Icons.category, color: Colors.white),
              ),
        title: Text(
          category.name,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          category.parentId != null ? '子分类' : '主分类',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 可点击的交易数量
            InkWell(
              onTap: onTransactionCountTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${category.transactionCount}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!isSelectionMode) ...[
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                onSelected: onMenuSelected,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('编辑'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'convert',
                    child: ListTile(
                      leading: Icon(Icons.label),
                      title: Text('转为标签'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(
                      leading: Icon(Icons.copy),
                      title: Text('复制'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('删除', style: TextStyle(color: Colors.red)),
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
            if (hasChildren)
              const Icon(Icons.arrow_drop_down, size: 20),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

/// 分类转标签对话框
class _CategoryToTagDialog extends StatefulWidget {
  final Category category;

  const _CategoryToTagDialog({Key? key, required this.category}) : super(key: key);

  @override
  State<_CategoryToTagDialog> createState() => _CategoryToTagDialogState();
}

class _CategoryToTagDialogState extends State<_CategoryToTagDialog> {
  final TextEditingController _tagNameController = TextEditingController();
  bool _applyToTransactions = true;
  bool _deleteCategory = false;

  @override
  void initState() {
    super.initState();
    _tagNameController.text = widget.category.name;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('转换为标签'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(int.parse(widget.category.color.replaceFirst('#', '0xFF'))),
                shape: BoxShape.circle,
              ),
              child: widget.category.icon != null
                  ? Center(child: Text(widget.category.icon!))
                  : const Icon(Icons.category, color: Colors.white),
            ),
            title: Text(widget.category.name),
            subtitle: Text('使用次数: ${widget.category.transactionCount}'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tagNameController,
            decoration: const InputDecoration(
              labelText: '标签名称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('应用到历史交易'),
            subtitle: const Text('将该分类的所有交易添加此标签'),
            value: _applyToTransactions,
            onChanged: (value) {
              setState(() {
                _applyToTransactions = value;
              });
            },
          ),
          SwitchListTile(
            title: const Text('删除原分类'),
            subtitle: const Text('转换后删除该分类'),
            value: _deleteCategory,
            onChanged: (value) {
              setState(() {
                _deleteCategory = value;
              });
            },
          ),
          if (_applyToTransactions && widget.category.transactionCount > 0)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '将更新 ${widget.category.transactionCount} 笔交易',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_tagNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入标签名称')),
              );
              return;
            }
            
            // TODO: 执行转换
            context.read<CategoryProvider>().convertCategoryToTag(
              widget.category.id,
              _tagNameController.text.trim(),
              applyToTransactions: _applyToTransactions,
              deleteCategory: _deleteCategory,
            );
            
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已将"${widget.category.name}"转换为标签'),
                action: SnackBarAction(
                  label: '撤销',
                  onPressed: () {
                    context.read<CategoryProvider>().undoLastAction();
                  },
                ),
              ),
            );
          },
          child: const Text('确认转换'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tagNameController.dispose();
    super.dispose();
  }
}

/// 复制分类对话框
class _DuplicateCategoryDialog extends StatefulWidget {
  final Category category;

  const _DuplicateCategoryDialog({Key? key, required this.category}) : super(key: key);

  @override
  State<_DuplicateCategoryDialog> createState() => _DuplicateCategoryDialogState();
}

class _DuplicateCategoryDialogState extends State<_DuplicateCategoryDialog> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameController.text = '${widget.category.name} (副本)';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('复制分类'),
      content: TextField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: '新分类名称',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请输入分类名称')),
              );
              return;
            }
            
            context.read<CategoryProvider>().duplicateCategory(
              widget.category.id,
              _nameController.text.trim(),
            );
            
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('已创建分类"${_nameController.text.trim()}"')),
            );
          },
          child: const Text('复制'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

/// 分类删除对话框（有交易时）
class _CategoryDeletionDialog extends StatefulWidget {
  final Category category;

  const _CategoryDeletionDialog({Key? key, required this.category}) : super(key: key);

  @override
  State<_CategoryDeletionDialog> createState() => _CategoryDeletionDialogState();
}

class _CategoryDeletionDialogState extends State<_CategoryDeletionDialog> {
  String _selectedOption = 'move';
  String? _targetCategoryId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('删除分类'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('分类"${widget.category.name}"有 ${widget.category.transactionCount} 笔交易'),
          const SizedBox(height: 16),
          const Text('请选择处理方式：'),
          const SizedBox(height: 8),
          RadioListTile<String>(
            title: const Text('移动到其他分类'),
            subtitle: const Text('将交易转移到指定分类'),
            value: 'move',
            groupValue: _selectedOption,
            onChanged: (value) {
              setState(() {
                _selectedOption = value!;
              });
            },
          ),
          if (_selectedOption == 'move')
            Padding(
              padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
              child: Consumer<CategoryProvider>(
                builder: (context, provider, _) {
                  final categories = provider.getCategoriesByClassification(
                    widget.category.classification,
                  ).where((c) => c.id != widget.category.id).toList();
                  
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: '目标分类',
                      border: OutlineInputBorder(),
                    ),
                    value: _targetCategoryId,
                    items: categories.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        _targetCategoryId = value;
                      });
                    },
                  );
                },
              ),
            ),
          RadioListTile<String>(
            title: const Text('转换为标签'),
            subtitle: const Text('创建同名标签并应用到交易'),
            value: 'tag',
            groupValue: _selectedOption,
            onChanged: (value) {
              setState(() {
                _selectedOption = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: const Text('设为未分类'),
            subtitle: const Text('清除交易的分类信息'),
            value: 'uncategorize',
            groupValue: _selectedOption,
            onChanged: (value) {
              setState(() {
                _selectedOption = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            if (_selectedOption == 'move' && _targetCategoryId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('请选择目标分类')),
              );
              return;
            }
            
            // TODO: 执行删除
            final provider = context.read<CategoryProvider>();
            
            switch (_selectedOption) {
              case 'move':
                provider.deleteCategoryWithMove(
                  widget.category.id,
                  _targetCategoryId!,
                );
                break;
              case 'tag':
                provider.deleteCategoryWithConversion(widget.category.id);
                break;
              case 'uncategorize':
                provider.deleteCategoryWithUncategorize(widget.category.id);
                break;
            }
            
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已删除分类"${widget.category.name}"'),
                action: SnackBarAction(
                  label: '撤销',
                  onPressed: () {
                    provider.undoLastAction();
                  },
                ),
              ),
            );
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('确认删除'),
        ),
      ],
    );
  }
}