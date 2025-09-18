import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/category.dart';
import '../../models/category_template.dart';
import '../../providers/category_provider.dart';
import '../../providers/ledger_provider.dart';

/// 简化版分类管理页面
/// 使用正确的Riverpod模式
class CategoryManagementSimplePage extends ConsumerStatefulWidget {
  const CategoryManagementSimplePage({Key? key}) : super(key: key);

  @override
  ConsumerState<CategoryManagementSimplePage> createState() =>
      _CategoryManagementSimplePageState();
}

class _CategoryManagementSimplePageState
    extends ConsumerState<CategoryManagementSimplePage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userCategories = ref.watch(userCategoriesProvider);
    final systemTemplates = ref.watch(systemTemplatesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '收入'),
            Tab(text: '支出'),
            Tab(text: '转账'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(CategoryClassification.income, userCategories),
          _buildCategoryList(CategoryClassification.expense, userCategories),
          _buildCategoryList(CategoryClassification.transfer, userCategories),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryList(
    CategoryClassification classification,
    List<Category> allCategories,
  ) {
    final categories = allCategories
        .where((cat) => cat.classification == classification)
        .toList();

    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '暂无${_getClassificationName(classification)}分类',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => _showAddCategoryDialog(classification),
              child: const Text('添加分类'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _parseColor(category.color),
              child: Text(
                category.icon,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(category.name),
            subtitle: category.description != null
                ? Text(category.description!)
                : null,
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleCategoryAction(value, category),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('编辑'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('删除'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getClassificationName(CategoryClassification classification) {
    switch (classification) {
      case CategoryClassification.income:
        return '收入';
      case CategoryClassification.expense:
        return '支出';
      case CategoryClassification.transfer:
        return '转账';
    }
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  void _handleCategoryAction(String action, Category category) {
    switch (action) {
      case 'edit':
        _showEditCategoryDialog(category);
        break;
      case 'delete':
        _showDeleteCategoryDialog(category);
        break;
    }
  }

  void _showAddCategoryDialog([CategoryClassification? classification]) {
    final currentTab = _tabController.index;
    final targetClassification = classification ??
        CategoryClassification.values[currentTab];

    showDialog(
      context: context,
      builder: (context) => _CategoryFormDialog(
        classification: targetClassification,
        onSave: (category) {
          ref.read(userCategoriesProvider.notifier).createCategory(category);
        },
      ),
    );
  }

  void _showEditCategoryDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => _CategoryFormDialog(
        category: category,
        classification: category.classification,
        onSave: (updatedCategory) {
          ref.read(userCategoriesProvider.notifier).updateCategory(updatedCategory);
        },
      ),
    );
  }

  void _showDeleteCategoryDialog(Category category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定要删除分类"${category.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (category.id != null) {
                ref.read(userCategoriesProvider.notifier).deleteCategory(category.id!);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

/// 分类表单对话框
class _CategoryFormDialog extends StatefulWidget {
  final Category? category;
  final CategoryClassification classification;
  final Function(Category) onSave;

  const _CategoryFormDialog({
    this.category,
    required this.classification,
    required this.onSave,
  });

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _iconController;
  late String _selectedColor;

  final List<String> _availableColors = [
    '#e99537', '#4da568', '#6471eb', '#db5a54', '#df4e92',
    '#c44fe9', '#eb5429', '#61c9ea', '#805dee', '#6ad28a',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _descriptionController = TextEditingController(text: widget.category?.description ?? '');
    _iconController = TextEditingController(text: widget.category?.icon ?? '💰');
    _selectedColor = widget.category?.color ?? _availableColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.category == null ? '添加分类' : '编辑分类'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '分类名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: '描述（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _iconController,
              decoration: const InputDecoration(
                labelText: '图标',
                border: OutlineInputBorder(),
                hintText: '输入emoji或符号',
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('选择颜色：'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _availableColors.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saveCategory,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _saveCategory() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入分类名称')),
      );
      return;
    }

    final category = Category(
      id: widget.category?.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      color: _selectedColor,
      icon: _iconController.text.trim().isEmpty ? '💰' : _iconController.text.trim(),
      classification: widget.classification,
      createdAt: widget.category?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    widget.onSave(category);
    Navigator.pop(context);
  }
}