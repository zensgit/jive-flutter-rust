import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../providers/tag_provider.dart';

class TagGroupDialog extends ConsumerStatefulWidget {
  final TagGroup? group;
  final VoidCallback? onSaved;

  const TagGroupDialog({
    super.key,
    this.group,
    this.onSaved,
  });

  @override
  ConsumerState<TagGroupDialog> createState() => _TagGroupDialogState();
}

class _TagGroupDialogState extends ConsumerState<TagGroupDialog> {
  final _nameController = TextEditingController();
  String? _selectedColor;
  bool _isLoading = false;

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

  @override
  void initState() {
    super.initState();
    if (widget.group != null) {
      _nameController.text = widget.group!.name;
      _selectedColor = widget.group!.color;
    } else {
      _selectedColor = _availableColors.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.group != null ? '编辑分组' : '创建分组',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '分组名称',
                hintText: '请输入分组名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _saveGroup,
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(widget.group != null ? '保存' : '创建'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveGroup() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入分组名称')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final groupNotifier = ref.read(tagGroupsProvider.notifier);

      if (widget.group != null) {
        // 编辑现有分组
        final updatedGroup = widget.group!.copyWith(
          name: name,
          color: _selectedColor,
          updatedAt: DateTime.now(),
        );
        await groupNotifier.updateTagGroup(updatedGroup);
      } else {
        // 创建新分组
        final group = TagGroup(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name,
          color: _selectedColor,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await groupNotifier.addTagGroup(group);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(widget.group != null ? '分组"$name"更新成功' : '分组"$name"创建成功'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('操作失败: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
