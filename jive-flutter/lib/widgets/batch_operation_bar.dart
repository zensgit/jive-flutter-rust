import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/category_management_provider.dart';

/// 批量操作栏
class BatchOperationBar extends ConsumerStatefulWidget {
  final List<String> selectedIds;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final bool isAllSelected;
  final String operationType; // 'category' or 'tag'

  const BatchOperationBar({
    Key? key,
    required this.selectedIds,
    required this.onCancel,
    required this.onSelectAll,
    required this.isAllSelected,
    this.operationType = 'category',
  }) : super(key: key);

  @override
  ConsumerState<BatchOperationBar> createState() => _BatchOperationBarState();
}

class _BatchOperationBarState extends ConsumerState<BatchOperationBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SlideTransition(
      position: _slideAnimation.drive(
        Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                // 取消按钮
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: widget.onCancel,
                  tooltip: '取消批量操作',
                ),

                // 选中数量
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '已选择 ${widget.selectedIds.length} 项',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // 全选/取消全选
                TextButton.icon(
                  icon: Icon(
                    widget.isAllSelected ? Icons.deselect : Icons.select_all,
                  ),
                  label: Text(widget.isAllSelected ? '取消全选' : '全选'),
                  onPressed: widget.onSelectAll,
                ),

                const Spacer(),

                // 批量操作按钮
                if (widget.selectedIds.isNotEmpty) ...[
                  // 批量移动
                  if (widget.operationType == 'category')
                    _buildActionButton(
                      icon: Icons.drive_file_move_outline,
                      label: '移动',
                      onPressed: () => _showBatchMoveDialog(context),
                      color: colorScheme.primary,
                    ),

                  // 批量转换（分类转标签）
                  if (widget.operationType == 'category')
                    _buildActionButton(
                      icon: Icons.label_outline,
                      label: '转标签',
                      onPressed: () => _showBatchConvertDialog(context),
                      color: colorScheme.secondary,
                    ),

                  // 批量归档
                  _buildActionButton(
                    icon: Icons.archive_outlined,
                    label: '归档',
                    onPressed: () => _showBatchArchiveDialog(context),
                    color: colorScheme.tertiary,
                  ),

                  // 批量删除
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    label: '删除',
                    onPressed: () => _showBatchDeleteDialog(context),
                    color: colorScheme.error,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBatchMoveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BatchMoveDialog(
        selectedIds: widget.selectedIds,
        onConfirm: () {
          widget.onCancel(); // 退出批量操作模式
        },
      ),
    );
  }

  void _showBatchConvertDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BatchConvertToTagDialog(
        selectedIds: widget.selectedIds,
        onConfirm: () {
          widget.onCancel(); // 退出批量操作模式
        },
      ),
    );
  }

  void _showBatchArchiveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('批量归档'),
        content: Text('确定要归档选中的 ${widget.selectedIds.length} 个项目吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              // TODO: 实现批量归档
              Navigator.pop(context);
              widget.onCancel();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已归档 ${widget.selectedIds.length} 个项目'),
                ),
              );
            },
            child: Text('归档'),
          ),
        ],
      ),
    );
  }

  void _showBatchDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Text('批量删除'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要删除选中的 ${widget.selectedIds.length} 个项目吗？'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '此操作不可恢复！',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontSize: 12,
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
            child: Text('取消'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final provider = ref.read(categoryManagementProvider);
              await provider.batchDeleteCategories(widget.selectedIds);
              Navigator.pop(context);
              widget.onCancel();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已删除 ${widget.selectedIds.length} 个项目'),
                  action: SnackBarAction(
                    label: '撤销',
                    onPressed: () {
                      provider.undoLastAction();
                    },
                  ),
                ),
              );
            },
            child: Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 批量移动对话框
class BatchMoveDialog extends ConsumerStatefulWidget {
  final List<String> selectedIds;
  final VoidCallback onConfirm;

  const BatchMoveDialog({
    Key? key,
    required this.selectedIds,
    required this.onConfirm,
  }) : super(key: key);

  @override
  ConsumerState<BatchMoveDialog> createState() => _BatchMoveDialogState();
}

class _BatchMoveDialogState extends ConsumerState<BatchMoveDialog> {
  String? _targetParentId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('批量移动分类'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('将 ${widget.selectedIds.length} 个分类移动到：'),
          const SizedBox(height: 16),
          // TODO: 添加分类选择器
          DropdownButtonFormField<String>(
            value: _targetParentId,
            decoration: const InputDecoration(
              labelText: '目标父分类',
              border: OutlineInputBorder(),
              helperText: '留空表示移动到根目录',
            ),
            items: const [
              DropdownMenuItem(
                value: null,
                child: Text('根目录'),
              ),
              // TODO: 从provider获取分类列表
            ],
            onChanged: (value) {
              setState(() {
                _targetParentId = value;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            final provider = ref.read(categoryManagementProvider);
            await provider.batchMoveCategories(
              widget.selectedIds,
              _targetParentId,
            );
            Navigator.pop(context);
            widget.onConfirm();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已移动 ${widget.selectedIds.length} 个分类'),
              ),
            );
          },
          child: Text('移动'),
        ),
      ],
    );
  }
}

/// 批量转换为标签对话框
class BatchConvertToTagDialog extends ConsumerStatefulWidget {
  final List<String> selectedIds;
  final VoidCallback onConfirm;

  const BatchConvertToTagDialog({
    Key? key,
    required this.selectedIds,
    required this.onConfirm,
  }) : super(key: key);

  @override
  ConsumerState<BatchConvertToTagDialog> createState() =>
      _BatchConvertToTagDialogState();
}

class _BatchConvertToTagDialogState
    extends ConsumerState<BatchConvertToTagDialog> {
  bool _applyToTransactions = true;
  bool _deleteCategories = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('批量转换为标签'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('将 ${widget.selectedIds.length} 个分类转换为标签'),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: Text('应用到历史交易'),
            subtitle: Text('将分类下的交易添加对应标签'),
            value: _applyToTransactions,
            onChanged: (value) {
              setState(() {
                _applyToTransactions = value ?? true;
              });
            },
          ),
          CheckboxListTile(
            title: Text('删除原分类'),
            subtitle: Text('转换后删除原分类'),
            value: _deleteCategories,
            onChanged: (value) {
              setState(() {
                _deleteCategories = value ?? false;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            final provider = ref.read(categoryManagementProvider);

            for (final categoryId in widget.selectedIds) {
              // TODO: 获取分类名称
              await provider.convertCategoryToTag(
                categoryId,
                'Category Name', // 需要从分类获取
                applyToTransactions: _applyToTransactions,
                deleteCategory: _deleteCategories,
              );
            }

            Navigator.pop(context);
            widget.onConfirm();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已转换 ${widget.selectedIds.length} 个分类为标签'),
              ),
            );
          },
          child: Text('转换'),
        ),
      ],
    );
  }
}
