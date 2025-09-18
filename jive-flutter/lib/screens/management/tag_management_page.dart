import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/tag.dart';
import '../../providers/tag_provider.dart';
import '../../widgets/tag_create_dialog.dart';
import '../../widgets/tag_edit_dialog.dart';
import '../../widgets/tag_deletion_dialog.dart';
import '../../widgets/tag_group_dialog.dart';

/// 标签管理页面 - 完整版
class TagManagementPage extends ConsumerStatefulWidget {
  const TagManagementPage({super.key});

  @override
  ConsumerState<TagManagementPage> createState() => _TagManagementPageState();
}

class _TagManagementPageState extends ConsumerState<TagManagementPage> {
  final _searchController = TextEditingController();
  bool _showArchived = false;
  final Map<String, bool> _expandedGroups = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(tagsProvider);
    final activeTags = tags.where((tag) => !tag.archived).toList();
    final archivedTags = tags.where((tag) => tag.archived).toList();
    final tagGroups = ref.watch(tagGroupsProvider);

    // 搜索过滤
    final searchQuery = _searchController.text.toLowerCase();
    final filteredTags = tags.where((tag) {
      if (searchQuery.isNotEmpty &&
          !tag.name.toLowerCase().contains(searchQuery)) {
        return false;
      }
      if (!_showArchived && tag.archived) {
        return false;
      }
      return true;
    }).toList();

    // 按组分类
    final ungroupedTags = filteredTags
        .where((tag) => tag.groupId == null && !tag.archived)
        .toList();
    final Map<String, List<Tag>> tagsByGroup = {};
    for (final tag in filteredTags) {
      if (tag.groupId != null && !tag.archived) {
        tagsByGroup.putIfAbsent(tag.groupId!, () => []).add(tag);
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0.5,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 16, bottom: 16, right: 16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '标签管理',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(
                        icon: Icons.add,
                        label: '新建标签',
                        onPressed: _showAddTagDialog,
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        icon: Icons.folder_open,
                        label: '新建分组',
                        onPressed: _showAddGroupDialog,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 搜索和过滤
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 搜索框
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '搜索标签...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  // 过滤选项
                  Row(
                    children: [
                      FilterChip(
                        label: const Text('显示归档'),
                        selected: _showArchived,
                        onSelected: (value) {
                          setState(() {
                            _showArchived = value;
                          });
                        },
                        selectedColor: Colors.blue.withOpacity(0.2),
                        checkmarkColor: Colors.blue,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '共 ${filteredTags.length} 个标签',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 统计信息
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    title: '活跃标签',
                    count: activeTags.length,
                    color: Colors.blue,
                    icon: Icons.label,
                  ),
                  _buildStatCard(
                    title: '归档标签',
                    count: archivedTags.length,
                    color: Colors.orange,
                    icon: Icons.archive,
                  ),
                  _buildStatCard(
                    title: '标签分组',
                    count: tagGroups.length,
                    color: Colors.green,
                    icon: Icons.folder,
                  ),
                  _buildStatCard(
                    title: '总使用次数',
                    count: tags.fold(0, (sum, tag) => sum + tag.usageCount),
                    color: Colors.purple,
                    icon: Icons.trending_up,
                  ),
                ],
              ),
            ),
          ),

          // 标签列表
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 未分组标签
                if (ungroupedTags.isNotEmpty) ...[
                  _buildTagSection(
                    title: '未分组标签',
                    tags: ungroupedTags,
                    icon: Icons.label_outline,
                  ),
                  const SizedBox(height: 16),
                ],

                // 分组标签
                ...tagGroups.map((group) {
                  final groupTags = tagsByGroup[group.id] ?? [];
                  // 显示所有分组，即使是空的分组也显示
                  return _buildGroupSection(group, groupTags);
                }).toList(),

                // 归档标签
                if (_showArchived && archivedTags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildTagSection(
                    title: '归档标签',
                    tags: archivedTags,
                    icon: Icons.archive_outlined,
                    isArchived: true,
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.blue.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: Colors.blue),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewGroupCard() {
    return InkWell(
      onTap: _showAddGroupDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue.withOpacity(0.3),
            width: 1.5,
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              color: Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              '新建分组',
              style: TextStyle(
                color: Colors.blue,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTagSection({
    required String title,
    required List<Tag> tags,
    required IconData icon,
    bool isArchived = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tags.length}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const Spacer(),
              // 添加快速创建标签按钮
              if (!isArchived)
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 20),
                  color: Colors.blue,
                  tooltip: '快速添加标签',
                  onPressed: () => _showAddTagDialog(),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                tags.map((tag) => _buildTagChip(tag, isArchived)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(TagGroup group, List<Tag> groupTags) {
    final isExpanded = _expandedGroups[group.id] ?? false;
    final groupColor =
        Color(int.parse((group.color ?? '#6471eb').replaceFirst('#', '0xff')));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expandedGroups[group.id!] = !isExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.chevron_right,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: groupColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (group.icon != null) ...[
                          Icon(
                            _getIconData(group.icon!),
                            size: 16,
                            color: groupColor,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          group.name,
                          style: TextStyle(
                            color: groupColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
                      '${groupTags.length} 个标签',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // 分组操作按钮
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 快速添加标签到分组
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        color: Colors.blue,
                        onPressed: () => _showAddTagDialog(groupId: group.id),
                        tooltip: '在此分组中添加标签',
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        onPressed: () => _showEditGroupDialog(group),
                        tooltip: '编辑分组',
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete,
                          size: 18,
                          color:
                              groupTags.isEmpty ? Colors.red : Colors.grey[400],
                        ),
                        onPressed: groupTags.isEmpty
                            ? () => _deleteGroup(group)
                            : null,
                        tooltip: groupTags.isEmpty ? '删除分组' : '分组内有标签，无法删除',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              child: groupTags.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          '该分组暂无标签',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: groupTags
                          .map((tag) => _buildTagChip(tag, false))
                          .toList(),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTagChip(Tag tag, bool isArchived) {
    final color =
        Color(int.parse((tag.color ?? '#6471eb').replaceFirst('#', '0xff')));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tag.icon != null) ...[
            Icon(
              _getIconData(tag.icon!),
              size: 16,
              color: color,
            ),
            const SizedBox(width: 6),
          ],
          InkWell(
            onTap: isArchived ? null : () => _showEditTagDialog(tag),
            child: Text(
              tag.name,
              style: TextStyle(
                color: isArchived ? color.withOpacity(0.6) : color,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                decoration: isArchived ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              tag.usageCount.toString(),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black54,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 操作按钮组
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: isArchived ? null : () => _showEditTagDialog(tag),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.edit,
                    size: 16,
                    color: isArchived ? Colors.grey[300] : Colors.grey[600],
                  ),
                ),
              ),
              InkWell(
                onTap: () => _toggleArchive(tag),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    tag.archived ? Icons.unarchive : Icons.archive,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              InkWell(
                onTap: isArchived ? null : () => _showDeleteTagDialog(tag),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete,
                    size: 16,
                    color: isArchived ? Colors.grey[300] : Colors.red[400],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTagMenu(Tag tag) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标签预览
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(int.parse((tag.color ?? '#6471eb')
                              .replaceFirst('#', '0xff')))
                          .withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      tag.icon != null ? _getIconData(tag.icon!) : Icons.label,
                      color: Color(int.parse(
                          (tag.color ?? '#6471eb').replaceFirst('#', '0xff'))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tag.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '已使用 ${tag.usageCount} 次',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 操作选项
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑标签'),
              onTap: () {
                Navigator.pop(context);
                _showEditTagDialog(tag);
              },
            ),
            ListTile(
              leading: Icon(
                tag.archived ? Icons.unarchive : Icons.archive,
              ),
              title: Text(tag.archived ? '恢复标签' : '归档标签'),
              onTap: () {
                Navigator.pop(context);
                _toggleArchive(tag);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除标签', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteTagDialog(tag);
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String iconKey) {
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
    return iconMap[iconKey] ?? Icons.label;
  }

  void _showAddTagDialog({String? groupId}) {
    debugPrint('DEBUG: _showAddTagDialog called with groupId: $groupId');
    showDialog(
      context: context,
      builder: (context) => TagCreateDialog(
        initialGroupId: groupId,
        onCreated: () {
          debugPrint('DEBUG: Tag created successfully');
          setState(() {});
        },
      ),
    ).then((_) {
      debugPrint('DEBUG: Dialog closed');
    }).catchError((error) {
      debugPrint('ERROR: Failed to show dialog: $error');
    });
  }

  void _showEditTagDialog(Tag tag) {
    showDialog(
      context: context,
      builder: (context) => TagEditDialog(
        tag: tag,
        onUpdated: () {
          setState(() {});
        },
      ),
    );
  }

  void _showDeleteTagDialog(Tag tag) {
    showDialog(
      context: context,
      builder: (context) => TagDeletionDialog(
        tag: tag,
        onDeleted: () {
          setState(() {});
        },
      ),
    );
  }

  void _showAddGroupDialog() {
    debugPrint('DEBUG: _showAddGroupDialog called');
    showDialog(
      context: context,
      builder: (context) => TagGroupDialog(
        onSaved: () {
          debugPrint('DEBUG: Group saved successfully');
          setState(() {
            // 展开新创建的分组（最后一个分组）
            final groups = ref.read(tagGroupsProvider);
            if (groups.isNotEmpty) {
              final latestGroup = groups.last;
              _expandedGroups[latestGroup.id!] = true;
            }
          });
        },
      ),
    ).then((_) {
      debugPrint('DEBUG: Group dialog closed');
    }).catchError((error) {
      debugPrint('ERROR: Failed to show group dialog: $error');
    });
  }

  void _showEditGroupDialog(TagGroup group) {
    showDialog(
      context: context,
      builder: (context) => TagGroupDialog(
        group: group,
        onSaved: () {
          setState(() {});
        },
      ),
    );
  }

  void _deleteGroup(TagGroup group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除分组'),
        content: Text('确定要删除分组"${group.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              final groupNotifier = ref.read(tagGroupsProvider.notifier);
              await groupNotifier.deleteTagGroup(group.id!);
              Navigator.pop(context);
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('分组"${group.name}"已删除'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _toggleArchive(Tag tag) async {
    final tagNotifier = ref.read(tagsProvider.notifier);
    final updatedTag = tag.copyWith(archived: !tag.archived);
    await tagNotifier.updateTag(updatedTag);
    setState(() {});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(tag.archived ? '标签"${tag.name}"已恢复' : '标签"${tag.name}"已归档'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () => _toggleArchive(updatedTag),
          ),
        ),
      );
    }
  }
}
