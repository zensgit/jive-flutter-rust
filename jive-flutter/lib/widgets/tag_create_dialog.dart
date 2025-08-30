import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../providers/tag_provider.dart';

class TagCreateDialog extends ConsumerStatefulWidget {
  final String? initialGroupId;
  final VoidCallback? onCreated;

  const TagCreateDialog({
    super.key,
    this.initialGroupId,
    this.onCreated,
  });

  @override
  ConsumerState<TagCreateDialog> createState() => _TagCreateDialogState();
}

class _TagCreateDialogState extends ConsumerState<TagCreateDialog> {
  final _nameController = TextEditingController();
  final _groupController = TextEditingController();
  String? _selectedColor;
  String? _selectedIcon;
  String? _selectedGroupId;
  String? _selectedGroupName;
  bool _isLoading = false;
  bool _showGroupSuggestions = false;

  final List<String> _availableColors = [
    '#e99537', '#4da568', '#6471eb', '#db5a54', '#df4e92',
    '#c44fe9', '#eb5429', '#61c9ea', '#805dee', '#6ad28a',
  ];

  final Map<String, IconData> _availableIcons = {
    'work': Icons.work,
    'home': Icons.home,
    'restaurant': Icons.restaurant,
    'shopping_cart': Icons.shopping_cart,
    'directions_car': Icons.directions_car,
    'flight': Icons.flight,
    'medical_services': Icons.medical_services,
    'school': Icons.school,
    'sports': Icons.sports_soccer,
    'movie': Icons.movie,
    'priority': Icons.flag,
    'personal': Icons.person,
    'lifestyle': Icons.spa,
  };

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.initialGroupId;
    _selectedColor = _availableColors.first;
    
    // 如果有初始分组ID，设置对应的分组名称
    if (widget.initialGroupId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tagGroups = ref.read(tagGroupsProvider);
        TagGroup? group;
        try {
          group = tagGroups.firstWhere(
            (group) => group.id == widget.initialGroupId,
          );
        } catch (e) {
          group = tagGroups.isNotEmpty ? tagGroups.first : null;
        }
        if (group != null) {
          _groupController.text = group.name;
          _selectedGroupName = group.name;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagGroups = ref.watch(tagGroupsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: GestureDetector(
        onTap: () {
          // 点击其他地方时隐藏分组建议
          setState(() {
            _showGroupSuggestions = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                const Text(
                  '创建标签',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 标签名称
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '标签名称',
                hintText: '请输入标签名称',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 选择颜色
            const Text('选择颜色', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _availableColors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(int.parse(color.replaceFirst('#', '0xff'))),
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 2)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 选择图标
            const Text('选择图标 (可选)', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              height: 80,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 无图标选项
                    GestureDetector(
                      onTap: () => setState(() => _selectedIcon = null),
                      child: Container(
                        width: 50,
                        height: 50,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _selectedIcon == null
                                ? Colors.blue
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.cancel, color: Colors.grey),
                      ),
                    ),
                    // 图标选项
                    ..._availableIcons.entries.map((entry) {
                      final isSelected = _selectedIcon == entry.key;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIcon = entry.key),
                        child: Container(
                          width: 50,
                          height: 50,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue
                                  : Colors.grey[300]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(entry.value, color: Colors.grey[700]),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 分组选择 - 增强版
            const Text('选择分组 (可选)', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            _buildGroupSelector(tagGroups),
            const SizedBox(height: 16),

            // 预览
            if (_nameController.text.isNotEmpty) ...[
              const Text('预览', style: TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Color(int.parse(
                    (_selectedColor ?? '#6471eb').replaceFirst('#', '0xff')
                  )).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Color(int.parse(
                      (_selectedColor ?? '#6471eb').replaceFirst('#', '0xff')
                    )).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedIcon != null) ...[
                      Icon(
                        _availableIcons[_selectedIcon!],
                        size: 16,
                        color: Color(int.parse(
                          (_selectedColor ?? '#6471eb').replaceFirst('#', '0xff')
                        )),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      _nameController.text,
                      style: TextStyle(
                        color: Color(int.parse(
                          (_selectedColor ?? '#6471eb').replaceFirst('#', '0xff')
                        )),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createTag,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('创建'),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupSelector(List<TagGroup> tagGroups) {
    // 过滤匹配的分组
    final filteredGroups = tagGroups.where((group) {
      final query = _groupController.text.toLowerCase().trim();
      return query.isEmpty || group.name.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 输入框
        TextField(
          controller: _groupController,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: '输入分组名称或选择现有分组',
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_groupController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _groupController.clear();
                      setState(() {
                        _selectedGroupId = null;
                        _selectedGroupName = null;
                        _showGroupSuggestions = false;
                      });
                    },
                  ),
                IconButton(
                  icon: Icon(
                    _showGroupSuggestions ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.blue,
                  ),
                  tooltip: _showGroupSuggestions ? '隐藏分组列表' : '显示所有分组',
                  onPressed: () {
                    setState(() {
                      _showGroupSuggestions = !_showGroupSuggestions;
                    });
                  },
                ),
                if (_canCreateNewGroup())
                  IconButton(
                    icon: const Icon(Icons.add, size: 18, color: Colors.green),
                    tooltip: '创建新分组',
                    onPressed: _createQuickGroup,
                  ),
              ],
            ),
          ),
          onChanged: (value) {
            setState(() {
              _showGroupSuggestions = true; // 只要有输入就显示建议
              // 检查是否匹配现有分组
              try {
                final exactMatch = tagGroups.firstWhere(
                  (group) => group.name.toLowerCase().trim() == value.toLowerCase().trim(),
                );
                _selectedGroupId = exactMatch.id;
                _selectedGroupName = exactMatch.name;
              } catch (e) {
                _selectedGroupId = null;
                _selectedGroupName = value.trim();
              }
            });
          },
          onTap: () {
            setState(() {
              _showGroupSuggestions = true; // 点击输入框就显示所有分组
            });
          },
        ),
        
        // 分组建议列表
        if (_showGroupSuggestions && (filteredGroups.isNotEmpty || tagGroups.isNotEmpty))
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 现有分组列表
                if (filteredGroups.isNotEmpty) ...filteredGroups.take(5).map((group) {
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: Color(int.parse(
                        (group.color ?? '#6471eb').replaceFirst('#', '0xff')
                      )).withOpacity(0.2),
                      child: Icon(
                        _getGroupIcon(group.icon),
                        size: 16,
                        color: Color(int.parse(
                          (group.color ?? '#6471eb').replaceFirst('#', '0xff')
                        )),
                      ),
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(fontSize: 14),
                    ),
                    subtitle: Text(
                      '${_getGroupTagCount(group.id!)} 个标签',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    onTap: () {
                      _selectGroup(group);
                    },
                  );
                }),
                
                // 如果输入框为空，显示所有分组
                if (_groupController.text.trim().isEmpty && tagGroups.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      '选择现有分组:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  ...tagGroups.map((group) {
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12,
                        backgroundColor: Color(int.parse(
                          (group.color ?? '#6471eb').replaceFirst('#', '0xff')
                        )).withOpacity(0.2),
                        child: Icon(
                          _getGroupIcon(group.icon),
                          size: 16,
                          color: Color(int.parse(
                            (group.color ?? '#6471eb').replaceFirst('#', '0xff')
                          )),
                        ),
                      ),
                      title: Text(
                        group.name,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        '${_getGroupTagCount(group.id!)} 个标签',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      onTap: () {
                        _selectGroup(group);
                      },
                    );
                  }),
                ],
                
                // 创建新分组选项
                if (_canCreateNewGroup())
                  ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                    title: Text(
                      '创建新分组 "${_groupController.text.trim()}"',
                      style: const TextStyle(fontSize: 14, color: Colors.green),
                    ),
                    onTap: _createQuickGroup,
                  ),
                
                // 如果没有匹配的分组且不能创建新分组，显示提示
                if (filteredGroups.isEmpty && !_canCreateNewGroup() && _groupController.text.trim().isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      '没有匹配的分组',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _getGroupIcon(String? iconKey) {
    final iconMap = {
      'work': Icons.work,
      'home': Icons.home,
      'restaurant': Icons.restaurant,
      'shopping_cart': Icons.shopping_cart,
      'directions_car': Icons.directions_car,
      'flight': Icons.flight,
      'medical_services': Icons.medical_services,
      'school': Icons.school,
      'sports': Icons.sports_soccer,
      'movie': Icons.movie,
      'priority': Icons.flag,
      'personal': Icons.person,
      'lifestyle': Icons.spa,
    };
    return iconMap[iconKey] ?? Icons.folder;
  }

  int _getGroupTagCount(String groupId) {
    final tags = ref.read(tagsProvider);
    return tags.where((tag) => tag.groupId == groupId).length;
  }

  bool _canCreateNewGroup() {
    final groupName = _groupController.text.trim();
    if (groupName.isEmpty) return false;
    
    final tagGroups = ref.read(tagGroupsProvider);
    final nameExists = tagGroups.any((group) => 
      group.name.toLowerCase().trim() == groupName.toLowerCase().trim()
    );
    
    return !nameExists;
  }

  void _selectGroup(TagGroup group) {
    setState(() {
      _groupController.text = group.name;
      _selectedGroupId = group.id;
      _selectedGroupName = group.name;
      _showGroupSuggestions = false;
    });
  }

  Future<void> _createQuickGroup() async {
    final groupName = _groupController.text.trim();
    if (groupName.isEmpty) return;
    
    try {
      final groupNotifier = ref.read(tagGroupsProvider.notifier);
      final newGroup = TagGroup(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: groupName,
        color: _availableColors[
          DateTime.now().millisecondsSinceEpoch % _availableColors.length
        ],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await groupNotifier.addTagGroup(newGroup);
      
      setState(() {
        _selectedGroupId = newGroup.id;
        _selectedGroupName = newGroup.name;
        _showGroupSuggestions = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分组"$groupName"创建成功')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建分组失败: $error')),
        );
      }
    }
  }

  Future<void> _createTag() async {
    final name = _nameController.text.trim();
    
    // 空白标签过滤
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标签名称')),
      );
      return;
    }
    
    // 过滤纯空白字符的标签
    if (name.replaceAll(RegExp(r'\s+'), '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标签名称不能为空白字符')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tagNotifier = ref.read(tagsProvider.notifier);
      
      // 检查名称重复 - 家庭范围内唯一性
      final tags = ref.read(tagsProvider);
      Tag? existingTag;
      try {
        existingTag = tags.firstWhere(
          (tag) => tag.name.toLowerCase().trim() == name.toLowerCase().trim(),
        );
      } catch (e) {
        existingTag = null;
      }
      
      if (existingTag != null) {
        final groupInfo = existingTag.groupId != null 
          ? (() {
              final groups = ref.read(tagGroupsProvider);
              try {
                final group = groups.firstWhere(
                  (g) => g.id == existingTag!.groupId,
                );
                return group.name;
              } catch (e) {
                return '未知分组';
              }
            })()
          : '无分组';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('标签名称"$name"已存在于分组"$groupInfo"中'),
            action: SnackBarAction(
              label: '查看',
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        );
        return;
      }

      final tag = Tag(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        color: _selectedColor,
        icon: _selectedIcon,
        groupId: _selectedGroupId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tagNotifier.addTag(tag);

      if (mounted) {
        Navigator.pop(context);
        widget.onCreated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('标签"$name"创建成功')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}