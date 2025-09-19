import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api/category_service.dart';
import '../../models/category_template.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';
import '../../models/account_classification.dart';

/// 超级管理员模板管理页面
///
/// 仅超级管理员可访问，用于管理系统分类模板
class TemplateAdminPage extends StatefulWidget {
  const TemplateAdminPage({Key? key}) : super(key: key);

  @override
  State<TemplateAdminPage> createState() => _TemplateAdminPageState();
}

class _TemplateAdminPageState extends State<TemplateAdminPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CategoryService _categoryService;
  late AuthService _authService;

  // 模板数据
  List<SystemCategoryTemplate> _templates = [];
  List<SystemCategoryTemplate> _filteredTemplates = [];

  // UI状态
  bool _isLoading = true;
  String _error = '';
  String _searchQuery = '';
  CategoryGroup? _selectedGroup;
  AccountClassification? _selectedClassification;
  bool _showOnlyFeatured = false;

  // 编辑状态
  SystemCategoryTemplate? _editingTemplate;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 全部、收入、支出、转账
    _categoryService = context.read<CategoryService>();
    _authService = context.read<AuthService>();
    _checkAdminAccess();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccess() async {
    // 检查是否为超级管理员
    final user = _authService.currentUser;
    if (user == null || !user.isSuperAdmin) {
      setState(() {
        _error = '无权访问：需要超级管理员权限';
        _isLoading = false;
      });
      return;
    }
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final templates = await _categoryService.getAllTemplates();
      setState(() {
        _templates = templates;
        _filteredTemplates = templates;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      setState(() {
        _error = '加载模板失败: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredTemplates = _templates.where((template) {
        // 搜索过滤
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = template.name.toLowerCase().contains(query) ||
              (template.nameEn?.toLowerCase().contains(query) ?? false) ||
              (template.nameZh?.toLowerCase().contains(query) ?? false) ||
              template.tags.any((tag) => tag.toLowerCase().contains(query));
          if (!matchesSearch) return false;
        }

        // 分组过滤
        if (_selectedGroup != null) {
          if (template.categoryGroup != _selectedGroup) return false;
        }

        // 分类类型过滤
        if (_selectedClassification != null) {
          if (template.classification != _selectedClassification) return false;
        }

        // 精选过滤
        if (_showOnlyFeatured && !template.isFeatured) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  void _showTemplateEditor([SystemCategoryTemplate? template]) {
    setState(() {
      _editingTemplate = template;
      _isCreating = template == null;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _TemplateEditorDialog(
        template: template,
        onSave: (updatedTemplate) async {
          try {
            if (_isCreating) {
              await _categoryService.createTemplate(updatedTemplate);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('模板创建成功'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              await _categoryService.updateTemplate(updatedTemplate);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('模板更新成功'),
                  backgroundColor: Colors.green,
                ),
              );
            }
            Navigator.pop(context);
            _loadTemplates();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('保存失败: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        onCancel: () {
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _deleteTemplate(SystemCategoryTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除模板'),
        content: Text('确定要删除模板"${template.name}"吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _categoryService.deleteTemplate(template.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('模板已删除'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTemplates();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleFeatured(SystemCategoryTemplate template) async {
    try {
      template.setFeatured(!template.isFeatured);
      await _categoryService.updateTemplate(template);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            template.isFeatured ? '已设为精选' : '已取消精选',
          ),
        ),
      );
      _loadTemplates();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('操作失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error.isNotEmpty && _error.contains('无权访问')) {
      return Scaffold(
        appBar: AppBar(
          title: Text('模板管理'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _error,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('系统模板管理'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '全部'),
            Tab(text: '收入'),
            Tab(text: '支出'),
            Tab(text: '转账'),
          ],
          onTap: (index) {
            setState(() {
              _selectedClassification = index == 0
                  ? null
                  : index == 1
                      ? AccountClassification.income
                      : index == 2
                          ? AccountClassification.expense
                          : AccountClassification.transfer;
            });
            _applyFilters();
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showTemplateEditor(),
            tooltip: '创建模板',
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadTemplates,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _error.isNotEmpty
              ? ErrorWidget(
                  message: _error,
                  onRetry: _loadTemplates,
                )
              : Column(
                  children: [
                    _buildFilterBar(),
                    _buildStatistics(),
                    Expanded(
                      child: _buildTemplateList(),
                    ),
                  ],
                ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // 搜索框
          TextField(
            decoration: InputDecoration(
              hintText: '搜索模板名称、标签...',
              prefixIcon: Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        _applyFilters();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _applyFilters();
            },
          ),
          const SizedBox(height: 12),

          // 过滤选项
          Row(
            children: [
              // 分组过滤
              Expanded(
                child: DropdownButtonFormField<CategoryGroup?>(
                  initialValue: _selectedGroup,
                  decoration: InputDecoration(
                    labelText: '分类组',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<CategoryGroup?>(
                      value: null,
                      child: Text('全部分组'),
                    ),
                    ...CategoryGroup.values.map((group) => DropdownMenuItem(
                          value: group,
                          child: Text(group.displayName),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGroup = value;
                    });
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 16),

              // 精选过滤
              Row(
                children: [
                  Text('仅精选'),
                  Switch(
                    value: _showOnlyFeatured,
                    onChanged: (value) {
                      setState(() {
                        _showOnlyFeatured = value;
                      });
                      _applyFilters();
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final totalTemplates = _filteredTemplates.length;
    final featuredCount = _filteredTemplates.where((t) => t.isFeatured).length;
    final groupCounts = <CategoryGroup, int>{};

    for (final template in _filteredTemplates) {
      groupCounts[template.categoryGroup] =
          (groupCounts[template.categoryGroup] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCard(
            label: '总模板数',
            value: totalTemplates.toString(),
            icon: Icons.category,
            color: Colors.blue,
          ),
          _StatCard(
            label: '精选模板',
            value: featuredCount.toString(),
            icon: Icons.star,
            color: Colors.orange,
          ),
          _StatCard(
            label: '分组数',
            value: groupCounts.keys.length.toString(),
            icon: Icons.folder,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateList() {
    if (_filteredTemplates.isEmpty) {
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
              _searchQuery.isNotEmpty ? '没有找到匹配的模板' : '暂无模板',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredTemplates.length,
      itemBuilder: (context, index) {
        final template = _filteredTemplates[index];
        return _buildTemplateCard(template);
      },
    );
  }

  Widget _buildTemplateCard(SystemCategoryTemplate template) {
    final color = Color(int.parse(template.color.replaceFirst('#', '0xFF')));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              template.icon ?? '📂',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              template.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (template.isFeatured)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '精选',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${template.categoryGroup.displayName} | ${_getClassificationName(template.classification)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (template.nameEn != null)
              Text(
                template.nameEn!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            if (template.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: template.tags
                    .take(3)
                    .map((tag) => Chip(
                          label: Text(
                            tag,
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.grey[200],
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                template.isFeatured ? Icons.star : Icons.star_border,
                color: template.isFeatured ? Colors.orange : null,
              ),
              onPressed: () => _toggleFeatured(template),
              tooltip: template.isFeatured ? '取消精选' : '设为精选',
            ),
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: () => _showTemplateEditor(template),
              tooltip: '编辑',
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteTemplate(template),
              tooltip: '删除',
            ),
          ],
        ),
      ),
    );
  }

  String _getClassificationName(AccountClassification classification) {
    switch (classification) {
      case AccountClassification.income:
        return '收入';
      case AccountClassification.expense:
        return '支出';
      case AccountClassification.transfer:
        return '转账';
      default:
        return '未知';
    }
  }
}

/// 统计卡片
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

/// 模板编辑对话框
class _TemplateEditorDialog extends StatefulWidget {
  final SystemCategoryTemplate? template;
  final Function(SystemCategoryTemplate) onSave;
  final VoidCallback onCancel;

  const _TemplateEditorDialog({
    this.template,
    required this.onSave,
    required this.onCancel,
  });

  @override
  State<_TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<_TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _nameEnController;
  late TextEditingController _nameZhController;
  late TextEditingController _descriptionController;
  late TextEditingController _iconController;
  late TextEditingController _colorController;
  late TextEditingController _tagsController;

  AccountClassification _classification = AccountClassification.expense;
  CategoryGroup _categoryGroup = CategoryGroup.dailyExpense;
  bool _isFeatured = false;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final t = widget.template;
    _nameController = TextEditingController(text: t?.name ?? '');
    _nameEnController = TextEditingController(text: t?.nameEn ?? '');
    _nameZhController = TextEditingController(text: t?.nameZh ?? '');
    _descriptionController = TextEditingController(text: t?.description ?? '');
    _iconController = TextEditingController(text: t?.icon ?? '');
    _colorController = TextEditingController(text: t?.color ?? '#6B7280');
    _tagsController = TextEditingController(text: t?.tags.join(', ') ?? '');

    if (t != null) {
      _classification = t.classification;
      _categoryGroup = t.categoryGroup;
      _isFeatured = t.isFeatured;
      _isActive = t.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _nameZhController.dispose();
    _descriptionController.dispose();
    _iconController.dispose();
    _colorController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.template == null ? '创建模板' : '编辑模板',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // 基本信息
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '模板名称（中文）',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入模板名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nameEnController,
                  decoration: const InputDecoration(
                    labelText: '英文名称',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _nameZhController,
                  decoration: const InputDecoration(
                    labelText: '中文名称（可选）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '描述',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // 分类和分组
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<AccountClassification>(
                        initialValue: _classification,
                        decoration: const InputDecoration(
                          labelText: '分类类型',
                          border: OutlineInputBorder(),
                        ),
                        items: AccountClassification.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(_getClassificationName(c)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _classification = value!;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<CategoryGroup>(
                        initialValue: _categoryGroup,
                        decoration: const InputDecoration(
                          labelText: '分类组',
                          border: OutlineInputBorder(),
                        ),
                        items: CategoryGroup.values
                            .map(
                              (g) => DropdownMenuItem(
                                value: g,
                                child: Text(g.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _categoryGroup = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 图标和颜色
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _iconController,
                        decoration: const InputDecoration(
                          labelText: '图标（Emoji）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        decoration: InputDecoration(
                          labelText: '颜色（HEX）',
                          border: const OutlineInputBorder(),
                          suffixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _getColorFromHex(_colorController.text),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null ||
                              !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
                            return '请输入有效的颜色值（如：#FF0000）';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 标签
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: '标签（逗号分隔）',
                    border: OutlineInputBorder(),
                    hintText: '例如：热门, 必备, 常用',
                  ),
                ),
                const SizedBox(height: 12),

                // 开关选项
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: Text('精选'),
                        value: _isFeatured,
                        onChanged: (value) {
                          setState(() {
                            _isFeatured = value;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        title: Text('启用'),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.onCancel,
                      child: Text('取消'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saveTemplate,
                      child: Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _saveTemplate() {
    if (_formKey.currentState!.validate()) {
      // 创建或更新模板
      final template = SystemCategoryTemplate(
        id: widget.template?.id ?? '',
        name: _nameController.text,
        nameEn: _nameEnController.text.isEmpty ? null : _nameEnController.text,
        nameZh: _nameZhController.text.isEmpty ? null : _nameZhController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        classification: _classification,
        color: _colorController.text,
        icon: _iconController.text.isEmpty ? null : _iconController.text,
        categoryGroup: _categoryGroup,
        isFeatured: _isFeatured,
        isActive: _isActive,
        tags: _tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toList(),
        globalUsageCount: widget.template?.globalUsageCount ?? 0,
      );

      widget.onSave(template);
    }
  }

  Color _getColorFromHex(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }

  String _getClassificationName(AccountClassification classification) {
    switch (classification) {
      case AccountClassification.income:
        return '收入';
      case AccountClassification.expense:
        return '支出';
      case AccountClassification.transfer:
        return '转账';
      default:
        return '未知';
    }
  }
}
