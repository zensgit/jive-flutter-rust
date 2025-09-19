import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/category_provider.dart';

/// 基础版分类列表页面（恢复最小可用功能）
/// 后续增强（拖拽/批量/模板/统计）将在独立 PR 中逐步回填。
class CategoryListPage extends ConsumerWidget {
  const CategoryListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(userCategoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
      ),
      body: categories.isEmpty
          ? _EmptyState(colorScheme: colorScheme)
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final c = categories[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _parseColor(c.color, colorScheme.primary),
                    child: const Text(c.icon, style: const TextStyle(fontSize: 14)),
                  ),
                  title: const Text(c.name),
                  subtitle: c.parentId != null
                      ? const Text('子分类', style: TextStyle(fontSize: 11))
                      : null,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 占位：后续 PR 将实现创建分类对话框
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: const Text('创建分类功能后续 PR 提供')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _parseColor(String? hex, Color fallback) {
    if (hex == null || hex.isEmpty) return fallback;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return fallback;
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  const _EmptyState({required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 56, color: colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              '暂无分类',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '点击右下角 + 按钮创建你的第一个分类',
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurface.withValues(alpha: .65)),
            ),
          ],
        ),
      ),
    );
  }
}

