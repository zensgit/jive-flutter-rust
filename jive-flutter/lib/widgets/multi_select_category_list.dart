import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import 'batch_operation_bar.dart';

/// 支持多选的分类列表
class MultiSelectCategoryList extends ConsumerStatefulWidget {
  final String? ledgerId;
  final CategoryClassification? filterClassification;
  
  const MultiSelectCategoryList({
    Key? key,
    this.ledgerId,
    this.filterClassification,
  }) : super(key: key);
  
  @override
  ConsumerState<MultiSelectCategoryList> createState() => _MultiSelectCategoryListState();
}

class _MultiSelectCategoryListState extends ConsumerState<MultiSelectCategoryList> {
  bool _isMultiSelectMode = false;
  final Set<String> _selectedIds = {};
  
  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(userCategoriesProvider);
    
    // 过滤分类
    var filteredCategories = categories;
    if (widget.ledgerId != null) {
      filteredCategories = filteredCategories
          .where((c) => c.ledgerId == widget.ledgerId)
          .toList();
    }
    if (widget.filterClassification != null) {
      filteredCategories = filteredCategories
          .where((c) => c.classification == widget.filterClassification)
          .toList();
    }
    
    return Scaffold(
      body: Stack(
        children: [
          // 分类列表
          CustomScrollView(
            slivers: [
              // 批量操作栏占位
              if (_isMultiSelectMode)
                const SliverToBoxAdapter(
                  child: SizedBox(height: 60),
                ),
              
              // 操作提示
              if (!_isMultiSelectMode)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '共 ${filteredCategories.length} 个分类',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.checklist),
                          label: const Text('批量操作'),
                          onPressed: _enterMultiSelectMode,
                        ),
                      ],
                    ),
                  ),
                ),
              
              // 分类列表
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final category = filteredCategories[index];
                    final isSelected = _selectedIds.contains(category.id);
                    
                    return CategoryListTile(
                      category: category,
                      isMultiSelectMode: _isMultiSelectMode,
                      isSelected: isSelected,
                      onTap: () {
                        if (_isMultiSelectMode) {
                          _toggleSelection(category.id);
                        } else {
                          _showCategoryDetails(category);
                        }
                      },
                      onLongPress: !_isMultiSelectMode 
                          ? () => _enterMultiSelectModeWithSelection(category.id)
                          : null,
                    );
                  },
                  childCount: filteredCategories.length,
                ),
              ),
              
              // 底部留白
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ),
          
          // 批量操作栏
          if (_isMultiSelectMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: BatchOperationBar(
                selectedIds: _selectedIds.toList(),
                onCancel: _exitMultiSelectMode,
                onSelectAll: () => _selectAll(filteredCategories),
                isAllSelected: _selectedIds.length == filteredCategories.length,
                operationType: 'category',
              ),
            ),
        ],
      ),
      floatingActionButton: !_isMultiSelectMode
          ? FloatingActionButton.extended(
              onPressed: _createNewCategory,
              icon: const Icon(Icons.add),
              label: const Text('新建分类'),
            )
          : null,
    );
  }
  
  void _enterMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = true;
      _selectedIds.clear();
    });
  }
  
  void _enterMultiSelectModeWithSelection(String categoryId) {
    setState(() {
      _isMultiSelectMode = true;
      _selectedIds.clear();
      _selectedIds.add(categoryId);
    });
  }
  
  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedIds.clear();
    });
  }
  
  void _toggleSelection(String categoryId) {
    setState(() {
      if (_selectedIds.contains(categoryId)) {
        _selectedIds.remove(categoryId);
        if (_selectedIds.isEmpty) {
          _exitMultiSelectMode();
        }
      } else {
        _selectedIds.add(categoryId);
      }
    });
  }
  
  void _selectAll(List<Category> categories) {
    setState(() {
      if (_selectedIds.length == categories.length) {
        _selectedIds.clear();
        _exitMultiSelectMode();
      } else {
        _selectedIds.clear();
        _selectedIds.addAll(categories.map((c) => c.id));
      }
    });
  }
  
  void _showCategoryDetails(Category category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CategoryDetailSheet(category: category),
    );
  }
  
  void _createNewCategory() {
    // TODO: 实现创建新分类
    Navigator.pushNamed(context, '/category/create');
  }
}

/// 分类列表项
class CategoryListTile extends StatelessWidget {
  final Category category;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  
  const CategoryListTile({
    Key? key,
    required this.category,
    required this.isMultiSelectMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected 
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : null,
        border: Border(
          left: BorderSide(
            color: isSelected 
                ? colorScheme.primary 
                : Colors.transparent,
            width: 4,
          ),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isMultiSelectMode
                ? (isSelected 
                    ? colorScheme.primary 
                    : colorScheme.surfaceVariant)
                : Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isMultiSelectMode
                ? AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            key: const ValueKey('check'),
                            color: colorScheme.onPrimary,
                            size: 20,
                          )
                        : const SizedBox.shrink(),
                  )
                : Text(
                    category.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
          ),
        ),
        title: Text(
          category.name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : null,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(
              category.classification == CategoryClassification.income
                  ? Icons.arrow_downward
                  : category.classification == CategoryClassification.expense
                      ? Icons.arrow_upward
                      : Icons.swap_horiz,
              size: 14,
              color: category.classification == CategoryClassification.income
                  ? Colors.green
                  : category.classification == CategoryClassification.expense
                      ? Colors.red
                      : Colors.blue,
            ),
            const SizedBox(width: 4),
            Text(
              _getClassificationText(category.classification),
              style: theme.textTheme.bodySmall,
            ),
            if (category.transactionCount > 0) ...[
              const SizedBox(width: 8),
              Icon(Icons.receipt_long, size: 14, color: colorScheme.outline),
              const SizedBox(width: 2),
              Text(
                '${category.transactionCount}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
        trailing: !isMultiSelectMode
            ? PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) => _handleMenuAction(context, value),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('编辑'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'convert',
                    child: ListTile(
                      leading: Icon(Icons.label_outline),
                      title: Text('转为标签'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'duplicate',
                    child: ListTile(
                      leading: Icon(Icons.copy),
                      title: Text('复制'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: colorScheme.error),
                      title: Text('删除', style: TextStyle(color: colorScheme.error)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              )
            : null,
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
  
  void _handleMenuAction(BuildContext context, String action) {
    // TODO: 处理菜单操作
    switch (action) {
      case 'edit':
        Navigator.pushNamed(context, '/category/edit', arguments: category);
        break;
      case 'convert':
        // 转为标签
        break;
      case 'duplicate':
        // 复制
        break;
      case 'delete':
        // 删除
        break;
    }
  }
}

/// 分类详情底部弹窗
class CategoryDetailSheet extends StatelessWidget {
  final Category category;
  
  const CategoryDetailSheet({
    Key? key,
    required this.category,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // 拖动指示器
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // 分类信息
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // 头部信息
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Color(int.parse(category.color.replaceFirst('#', '0xFF'))),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              category.icon,
                              style: const TextStyle(fontSize: 30),
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
                                style: theme.textTheme.headlineSmall,
                              ),
                              const SizedBox(height: 4),
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
                    
                    const SizedBox(height: 24),
                    
                    // 统计信息
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '统计信息',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _buildStatRow('交易次数', '${category.transactionCount}'),
                            _buildStatRow('本月使用', '${category.monthlyCount ?? 0}'),
                            _buildStatRow('创建时间', _formatDate(category.createdAt)),
                            if (category.updatedAt != null)
                              _buildStatRow('最后更新', _formatDate(category.updatedAt!)),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // 操作按钮
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildActionChip(
                          icon: Icons.edit,
                          label: '编辑',
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/category/edit', arguments: category);
                          },
                        ),
                        _buildActionChip(
                          icon: Icons.label_outline,
                          label: '转为标签',
                          onPressed: () {
                            // TODO: 转为标签
                            Navigator.pop(context);
                          },
                        ),
                        _buildActionChip(
                          icon: Icons.copy,
                          label: '复制',
                          onPressed: () {
                            // TODO: 复制
                            Navigator.pop(context);
                          },
                        ),
                        _buildActionChip(
                          icon: Icons.delete,
                          label: '删除',
                          onPressed: () {
                            // TODO: 删除
                            Navigator.pop(context);
                          },
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
  
  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isDestructive = false,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: isDestructive ? Colors.red.withOpacity(0.1) : null,
      side: isDestructive ? const BorderSide(color: Colors.red) : null,
    );
  }
  
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}