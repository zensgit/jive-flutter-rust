import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/models/tag.dart';
import 'package:jive_money/providers/tag_provider.dart';

class TagDeletionDialog extends ConsumerWidget {
  final Tag tag;
  final VoidCallback? onDeleted;

  const TagDeletionDialog({
    super.key,
    required this.tag,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      title: const Text('删除标签'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('确定要删除标签"${tag.name}"吗？'),
          if (tag.usageCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '该标签已被使用 ${tag.usageCount} 次。',
              style: TextStyle(color: Colors.orange[700]),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () async {
            final tagNotifier = ref.read(tagsProvider.notifier);
            await tagNotifier.deleteTag(tag.id!);

            if (context.mounted) {
              Navigator.pop(context);
              onDeleted?.call();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('标签"${tag.name}"已删除')),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('删除'),
        ),
      ],
    );
  }
}
