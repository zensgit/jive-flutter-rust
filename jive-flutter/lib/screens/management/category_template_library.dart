import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api/category_service.dart';
import '../../models/category.dart';
import '../../models/category_template.dart';
import '../../utils/constants.dart';
import '../../widgets/common/custom_card.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/error_widget.dart';

/// 分类模板库页面 - 浏览和导入系统预设分类模板
class CategoryTemplateLibraryPage extends StatefulWidget {
  const CategoryTemplateLibraryPage({Key? key}) : super(key: key);

  @override
  State<CategoryTemplateLibraryPage> createState() =>
      _CategoryTemplateLibraryPageState();
}

class _CategoryTemplateLibraryPageState
    extends State<CategoryTemplateLibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CategoryService _categoryService;

  // 模板数据
  List<SystemCategoryTemplate> _allTemplates = [];
  List<SystemCategoryTemplate> _filteredTemplates = [];
  Map<String, List<SystemCategoryTemplate>> _templatesByGroup = {};

  // UI状态
  bool _isLoading = true;
  String _error = '';
  String _searchQuery = '';
  CategoryGroup? _selectedGroup;
  Set<String> _selectedTemplateIds = {};
  bool _isSelectionMode = false;
  bool _showOnlyFeatured = false;

  // 分类组
  final List<CategoryGroup> _groups = [
    CategoryGroup.income,
    CategoryGroup.dailyExpense,
    CategoryGroup.housing,
    CategoryGroup.transportation,
    CategoryGroup.healthEducation,
    CategoryGroup.entertainmentSocial,
    CategoryGroup.financial,
    CategoryGroup.business,
    CategoryGroup.other,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _categoryService = context.read<CategoryService>();
    _loadTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // 加载所有模板
      final templates = await _categoryService.getAllTemplates();

      // 按组分类
      _templatesByGroup.clear();
      for (final template in templates) {
        final group = template.categoryGroup;
        _templatesByGroup.putIfAbsent(group, () => []).add(template);
      }

      setState(() {
        _allTemplates = templates;
        _filteredTemplates = templates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载模板失败: $e';
        _isLoading = false;
      });
    }
  }

  void _filterTemplates() {
    setState(() {
      _filteredTemplates = _allTemplates.where((template) {
        // 搜索过滤
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = template.name.toLowerCase().contains(query) ||
              (template.nameEn?.toLowerCase().contains(query) ?? false) ||
              template.tags.any((tag) => tag.toLowerCase().contains(query));
          if (!matchesSearch) return false;
        }

        // 分组过滤
        if (_selectedGroup != null) {
          if (template.categoryGroup != _selectedGroup) return false;
        }

        // 精选过滤
        if (_showOnlyFeatured && !template.isFeatured) {
          return false;
        }

        // 分类类型过滤（根据当前标签页）
        final classification = _getCurrentClassification();
        if (classification != null &&
            template.classification != classification) {
          return false;
        }

        return true;
      }).toList();
    });
  }

  AccountClassification? _getCurrentClassification() {
    switch (_tabController.index) {
      case 0:
        return AccountClassification.income;
      case 1:
        return AccountClassification.expense;
      case 2:
        return AccountClassification.transfer;
      default:
        return null;
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedTemplateIds.clear();
      }
    });
  }

  void _toggleTemplateSelection(String templateId) {
    setState(() {
      if (_selectedTemplateIds.contains(templateId)) {
        _selectedTemplateIds.remove(templateId);
      } else {
        _selectedTemplateIds.add(templateId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedTemplateIds = _filteredTemplates.map((t) => t.id).toSet();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTemplateIds.clear();
    });
  }

  Future<void> _importSelectedTemplates() async {
    if (_selectedTemplateIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入分类模板'),
        content: Text('确定要导入 ${_selectedTemplateIds.length} 个分类模板吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // 批量导入模板
        for (final templateId in _selectedTemplateIds) {
          final template = _allTemplates.firstWhere((t) => t.id == templateId);
          await _categoryService.importTemplateAsCategory(template);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('成功导入 ${_selectedTemplateIds.length} 个分类'),
            backgroundColor: Colors.green,
          ),
        );

        // 清除选择并退出选择模式
        _clearSelection();
        _toggleSelectionMode();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importSingleTemplate(SystemCategoryTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要导入"${template.name}"作为分类吗？'),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Color(
                        int.parse(template.color.replaceFirst('#', '0xFF'))),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(template.icon ?? ''),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    template.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('导入'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _categoryService.importTemplateAsCategory(template);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('分类导入成功'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类模板库'),
        bottom: TabBar(
          controller: _tabController,
          onTap: (_) => _filterTemplates(),
          tabs: const [
            Tab(text: '收入'),
            Tab(text: '支出'),
            Tab(text: '转账'),
          ],
        ),
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: _selectAll,
              tooltip: '全选',
            ),
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: '清除选择',
            ),
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _selectedTemplateIds.isNotEmpty
                  ? _importSelectedTemplates
                  : null,
              tooltip: '导入选中',
            ),
          ],
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
            onPressed: _toggleSelectionMode,
            tooltip: _isSelectionMode ? '退出选择' : '批量选择',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
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
                    // 搜索和过滤栏
                    _buildSearchAndFilterBar(),

                    // 模板列表
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildTemplateList(AccountClassification.income),
                          _buildTemplateList(AccountClassification.expense),
                          _buildTemplateList(AccountClassification.transfer),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              hintText: '搜索模板...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        _filterTemplates();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _filterTemplates();
            },
          ),
          const SizedBox(height: 12),

          // 分组过滤和精选开关
          Row(
            children: [
              // 分组下拉
              Expanded(
                child: DropdownButtonFormField<CategoryGroup?>(
                  initialValue: _selectedGroup,
                  decoration: InputDecoration(
                    labelText: '分类组',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<CategoryGroup?>(
                      value: null,
                      child: Text('全部分组'),
                    ),
                    ..._groups.map((group) => DropdownMenuItem(
                          value: group,
                          child: Row(
                            children: [
                              Text(group.icon),
                              const SizedBox(width: 8),
                              Text(group.displayName),
                            ],
                          ),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedGroup = value;
                    });
                    _filterTemplates();
                  },
                ),
              ),
              const SizedBox(width: 16),

              // 精选开关
              Row(
                children: [
                  const Text('仅显示精选'),
                  Switch(
                    value: _showOnlyFeatured,
                    onChanged: (value) {
                      setState(() {
                        _showOnlyFeatured = value;
                      });
                      _filterTemplates();
                    },
                  ),
                ],
              ),
            ],
          ),

          // 统计信息
          if (_isSelectionMode) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '已选择 ${_selectedTemplateIds.length} / ${_filteredTemplates.length} 个模板',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateList(AccountClassification classification) {
    final templates = _filteredTemplates
        .where((t) => t.classification == classification)
        .toList();

    if (templates.isEmpty) {
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

    // 按分组组织模板
    final groupedTemplates = <CategoryGroup, List<SystemCategoryTemplate>>{};
    for (final template in templates) {
      groupedTemplates
          .putIfAbsent(template.categoryGroup, () => [])
          .add(template);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedTemplates.length,
      itemBuilder: (context, index) {
        final group = groupedTemplates.keys.elementAt(index);
        final groupTemplates = groupedTemplates[group]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 分组标题
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    group.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    group.displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${groupTemplates.length}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // 模板网格
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.5,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: groupTemplates.length,
              itemBuilder: (context, index) {
                final template = groupTemplates[index];
                return _buildTemplateCard(template);
              },
            ),

            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildTemplateCard(SystemCategoryTemplate template) {
    final isSelected = _selectedTemplateIds.contains(template.id);
    final color = Color(int.parse(template.color.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: () {
        if (_isSelectionMode) {
          _toggleTemplateSelection(template.id);
        } else {
          _showTemplateDetails(template);
        }
      },
      onLongPress: () {
        if (!_isSelectionMode) {
          _toggleSelectionMode();
          _toggleTemplateSelection(template.id);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color:
              isSelected ? color.withOpacity(0.1) : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 颜色和图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    template.icon ?? '📂',
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 名称和标签
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            template.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (template.isFeatured)
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
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
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: template.tags
                          .take(2)
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),

              // 选择指示器或操作按钮
              if (_isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleTemplateSelection(template.id),
                  activeColor: color,
                )
              else
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => _importSingleTemplate(template),
                  color: color,
                  tooltip: '导入',
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTemplateDetails(SystemCategoryTemplate template) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(int.parse(
                              template.color.replaceFirst('#', '0xFF')))
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        template.icon ?? '📂',
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
                          template.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (template.nameEn != null)
                          Text(
                            template.nameEn!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 详细信息
              _buildDetailRow('分类组', template.categoryGroup.displayName),
              _buildDetailRow(
                  '类型', _getClassificationName(template.classification)),
              _buildDetailRow('颜色', template.color,
                  showColor: true, color: template.color),

              if (template.description != null) ...[
                const SizedBox(height: 16),
                Text(
                  '描述',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  template.description!,
                  style: const TextStyle(fontSize: 16),
                ),
              ],

              // 标签
              if (template.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: template.tags
                      .map((tag) => Chip(
                            label: Text(tag),
                            backgroundColor: Colors.grey[200],
                          ))
                      .toList(),
                ),
              ],

              // 统计信息
              if (template.globalUsageCount > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        '${template.globalUsageCount} 人使用',
                        style: TextStyle(color: Colors.blue[700]),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // 操作按钮
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('关闭'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _importSingleTemplate(template);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('导入分类'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value,
      {bool showColor = false, String? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          if (showColor && color != null) ...[
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Color(int.parse(color.replaceFirst('#', '0xFF'))),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
