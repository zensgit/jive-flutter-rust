import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lib/models/tag.dart';
import 'lib/providers/tag_provider.dart';
import 'lib/widgets/tag_create_dialog.dart';

/// Simple test app to verify tag management functionality
void main() {
  runApp(const ProviderScope(
    child: TagTestApp(),
  ));
}

class TagTestApp extends StatelessWidget {
  const TagTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tag Test App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TagTestScreen(),
    );
  }
}

class TagTestScreen extends ConsumerWidget {
  const TagTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(tagsProvider);
    final tagGroups = ref.watch(tagGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('标签管理测试'),
        actions: [
          IconButton(
            onPressed: () => _showCreateTagDialog(context),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          // 标签组信息
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '标签组 (${tagGroups.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: tagGroups
                        .map((group) => Chip(
                              label: Text(group.name),
                              backgroundColor: Color(int.parse(
                                      group.color!.replaceFirst('#', '0xff')))
                                  .withOpacity(0.2),
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

          // 标签信息
          Expanded(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '标签 (${tags.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: tags.length,
                      itemBuilder: (context, index) {
                        final tag = tags[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(int.parse(
                                tag.displayColor.replaceFirst('#', '0xff'))),
                            child: tag.icon != null
                                ? const Icon(Icons.star, color: Colors.white)
                                : Text(
                                    tag.name[0],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                          ),
                          title: Text(tag.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (tag.groupId != null)
                                Text(
                                    '分组: ${_getGroupName(tagGroups, tag.groupId!)}'),
                              Text('使用次数: ${tag.usageCount}'),
                              if (tag.archived)
                                const Text('已归档',
                                    style: TextStyle(color: Colors.orange)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _testTagUsage(ref, tag),
                                icon: const Icon(Icons.add_circle_outline),
                                tooltip: '增加使用次数',
                              ),
                              IconButton(
                                onPressed: () => _testTagArchive(ref, tag),
                                icon: Icon(
                                  tag.archived
                                      ? Icons.unarchive
                                      : Icons.archive,
                                ),
                                tooltip: tag.archived ? '取消归档' : '归档',
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGroupName(List<TagGroup> groups, String groupId) {
    final group = groups.firstWhere((g) => g.id == groupId,
        orElse: () => TagGroup(
              id: groupId,
              name: '未知分组',
              createdAt: DateTime.now(),
            ));
    return group.name;
  }

  void _showCreateTagDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TagCreateDialog(
        onCreated: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('新标签已创建!')),
          );
        },
      ),
    );
  }

  void _testTagUsage(WidgetRef ref, Tag tag) {
    ref.read(tagsProvider.notifier).incrementUsageCount(tag.id!);
  }

  void _testTagArchive(WidgetRef ref, Tag tag) {
    ref.read(tagsProvider.notifier).archiveTag(tag.id!, !tag.archived);
  }
}
