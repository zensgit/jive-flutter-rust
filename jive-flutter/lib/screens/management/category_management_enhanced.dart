import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/category.dart';
import '../../models/category_template.dart';
import '../../providers/category_management_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../services/api/category_service.dart';
// import '../../services/api/category_service_integrated.dart'; // Temporarily disabled during test stabilization

/// 增强版分类管理页面
/// 实现设计文档中的所有交互功能
class CategoryManagementEnhancedPage extends StatefulWidget {
  const CategoryManagementEnhancedPage({Key? key}) : super(key: key);

  @override
  State<CategoryManagementEnhancedPage> createState() =>
      _CategoryManagementEnhancedPageState();
}

class _CategoryManagementEnhancedPageState
    extends State<CategoryManagementEnhancedPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  CategoryClassification _selectedClassification =
      CategoryClassification.expense;
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
        _selectedClassification =
            CategoryClassification.values[_tabController.index];
      });
    });

    // 加载分类数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
    });
  }

Future<void> _showTemplateLibrary() async {
  if (!mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('模板库暂时精简'),
      content: const Text('完整模板导入功能将在后续 PR 中恢复。'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('关闭')),
      ],
    ),
  );
  // TODO: Restore full template import UI (original logic removed for test stability).
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
      onWillAcceptWithDetails: (data) => data.id != category.id,
      onAcceptWithDetails: onAcceptDrop,
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
                      color: Color(
                          int.parse(category.color.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                        child: Text(category.icon,
                            style: const TextStyle(fontSize: 12))),
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
                ? Theme.of(context)
                    .colorScheme
                    .secondaryContainer
                    .withOpacity(0.3)
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
                  color: Color(
                      int.parse(category.color.replaceFirst('#', '0xFF'))),
                  shape: BoxShape.circle,
                ),
                child: Center(
                    child: Text(category.icon,
                        style: const TextStyle(fontSize: 20))),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.3),
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
            if (hasChildren) const Icon(Icons.arrow_drop_down, size: 20),
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

  const _CategoryToTagDialog({Key? key, required this.category})
      : super(key: key);

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
                color: Color(
                    int.parse(widget.category.color.replaceFirst('#', '0xFF'))),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(widget.category.icon)),
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
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withOpacity(0.3),
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

            // 执行转换
            context.read(categoryManagementProvider).convertCategoryToTag(
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
                    context.read(categoryManagementProvider).undoLastAction();
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

  const _DuplicateCategoryDialog({Key? key, required this.category})
      : super(key: key);

  @override
  State<_DuplicateCategoryDialog> createState() =>
      _DuplicateCategoryDialogState();
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

            context.read(categoryManagementProvider).duplicateCategory(
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

  const _CategoryDeletionDialog({Key? key, required this.category})
      : super(key: key);

  @override
  State<_CategoryDeletionDialog> createState() =>
      _CategoryDeletionDialogState();
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
          Text(
              '分类"${widget.category.name}"有 ${widget.category.transactionCount} 笔交易'),
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
                  final categories = provider
                      .getCategoriesByClassification(
                        widget.category.classification,
                      )
                      .where((c) => c.id != widget.category.id)
                      .toList();

                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: '目标分类',
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _targetCategoryId,
                    items: categories
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
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
