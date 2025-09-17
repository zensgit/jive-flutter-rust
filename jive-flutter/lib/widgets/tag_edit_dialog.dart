import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../providers/tag_provider.dart';

class TagEditDialog extends ConsumerStatefulWidget {
  final Tag tag;
  final VoidCallback? onUpdated;

  const TagEditDialog({
    super.key,
    required this.tag,
    this.onUpdated,
  });

  @override
  ConsumerState<TagEditDialog> createState() => _TagEditDialogState();
}

class _TagEditDialogState extends ConsumerState<TagEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _groupController;
  String? _selectedColor;
  String? _selectedIcon;
  String? _selectedGroupId;
  String? _selectedGroupName;
  bool _isLoading = false;
  bool _showGroupSuggestions = false;

  final List<String> _availableColors = [
    '#e99537',
    '#4da568',
    '#6471eb',
    '#db5a54',
    '#df4e92',
    '#c44fe9',
    '#eb5429',
    '#61c9ea',
    '#805dee',
    '#6ad28a',
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
    _nameController = TextEditingController(text: widget.tag.name);
    _groupController = TextEditingController();
    _selectedColor = widget.tag.color ?? _availableColors.first;
    _selectedIcon = widget.tag.icon;
    _selectedGroupId = widget.tag.groupId;

    // 设置分组名称
    if (widget.tag.groupId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final tagGroups = ref.read(tagGroupsProvider);
        try {
          final group = tagGroups.firstWhere(
            (group) => group.id == widget.tag.groupId,
          );
          _groupController.text = group.name;
          _selectedGroupName = group.name;
        } catch (e) {
          // 分组不存在
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
          setState(() {
            _showGroupSuggestions = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 500,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题
                Row(
                  children: [
                    const Text(
                      '编辑标签',
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
                const Text('选择颜色',
                    style: TextStyle(fontWeight: FontWeight.w500)),
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
                          color:
                              Color(int.parse(color.replaceFirst('#', '0xff'))),
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
                const Text('选择图标 (可选)',
                    style: TextStyle(fontWeight: FontWeight.w500)),
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
                            onTap: () =>
                                setState(() => _selectedIcon = entry.key),
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

                // 分组选择
                const Text('选择分组 (可选)',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                _buildGroupSelector(tagGroups),
                const SizedBox(height: 16),

                // 预览
                if (_nameController.text.isNotEmpty) ...[
                  const Text('预览',
                      style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(int.parse((_selectedColor ?? '#6471eb')
                              .replaceFirst('#', '0xff')))
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Color(int.parse((_selectedColor ?? '#6471eb')
                                .replaceFirst('#', '0xff')))
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_selectedIcon != null) ...[
                          Icon(
                            _availableIcons[_selectedIcon!],
                            size: 16,
                            color: Color(int.parse((_selectedColor ?? '#6471eb')
                                .replaceFirst('#', '0xff'))),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _nameController.text,
                          style: TextStyle(
                            color: Color(int.parse((_selectedColor ?? '#6471eb')
                                .replaceFirst('#', '0xff'))),
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
                      onPressed: _isLoading ? null : _updateTag,
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('保存'),
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

  Widget _buildGroupSelector(List<TagGroup> tagGroups) {
    final filteredGroups = tagGroups.where((group) {
      final query = _groupController.text.toLowerCase().trim();
      return query.isEmpty || group.name.toLowerCase().contains(query);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    _showGroupSuggestions
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _showGroupSuggestions = !_showGroupSuggestions;
                    });
                  },
                ),
              ],
            ),
          ),
          onChanged: (value) {
            setState(() {
              _showGroupSuggestions = true;
              try {
                final exactMatch = tagGroups.firstWhere(
                  (group) =>
                      group.name.toLowerCase().trim() ==
                      value.toLowerCase().trim(),
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
              _showGroupSuggestions = true;
            });
          },
        ),

        // 分组建议列表
        if (_showGroupSuggestions && filteredGroups.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
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
            child: ListView(
              shrinkWrap: true,
              children: filteredGroups.map((group) {
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: Color(int.parse((group.color ?? '#6471eb')
                            .replaceFirst('#', '0xff')))
                        .withOpacity(0.2),
                    child: Icon(
                      _getGroupIcon(group.icon),
                      size: 16,
                      color: Color(int.parse((group.color ?? '#6471eb')
                          .replaceFirst('#', '0xff'))),
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
                    setState(() {
                      _groupController.text = group.name;
                      _selectedGroupId = group.id;
                      _selectedGroupName = group.name;
                      _showGroupSuggestions = false;
                    });
                  },
                );
              }).toList(),
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

  Future<void> _updateTag() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标签名称')),
      );
      return;
    }

    if (name.replaceAll(RegExp(r'\s+'), '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('标签名称不能为空白字符')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tagNotifier = ref.read(tagsProvider.notifier);

      // 检查名称重复（排除自己）
      final tags = ref.read(tagsProvider);
      final existingTag = tags.firstWhereOrNull(
        (tag) =>
            tag.id != widget.tag.id &&
            tag.name.toLowerCase().trim() == name.toLowerCase().trim(),
      );

      if (existingTag != null) {
        final groupInfo = existingTag.groupId != null
            ? (() {
                final groups = ref.read(tagGroupsProvider);
                try {
                  final group = groups.firstWhere(
                    (g) => g.id == existingTag.groupId,
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
          ),
        );
        return;
      }

      // 如果输入了新分组名称但不是现有分组，先创建分组
      if (_groupController.text.trim().isNotEmpty && _selectedGroupId == null) {
        final groupName = _groupController.text.trim();
        final groupNotifier = ref.read(tagGroupsProvider.notifier);
        final newGroup = TagGroup(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: groupName,
          color: _availableColors[
              DateTime.now().millisecondsSinceEpoch % _availableColors.length],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await groupNotifier.addTagGroup(newGroup);
        _selectedGroupId = newGroup.id;
      }

      final updatedTag = widget.tag.copyWith(
        name: name,
        color: _selectedColor,
        icon: _selectedIcon,
        groupId: _selectedGroupId,
        updatedAt: DateTime.now(),
      );

      await tagNotifier.updateTag(updatedTag);

      if (mounted) {
        Navigator.pop(context);
        widget.onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('标签"$name"更新成功')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// Extension to handle firstWhereOrNull
extension IterableExtension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}
