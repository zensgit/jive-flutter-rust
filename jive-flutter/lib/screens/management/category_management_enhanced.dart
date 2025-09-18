import 'package:flutter/material.dart';

// 占位版：增强分类管理页面暂时下线以稳定测试。
// 后续 PR 将恢复原完整交互（模板导入 / 拖拽排序 / 批量操作 / 转标签 / 统计等）。
class CategoryManagementEnhancedPage extends StatelessWidget {
  const CategoryManagementEnhancedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('分类管理 (占位)')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.category_outlined, size: 72, color: cs.primary),
              const SizedBox(height: 16),
              const Text(
                '增强版分类管理暂时下线',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                '为稳定当前 PR 的测试环境，复杂分类增强功能已暂时移除。',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface.withOpacity(.72)),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('提示'),
                    content: const Text('完整功能将于后续 PR 恢复'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('关闭'),
                      )
                    ],
                  ),
                ),
                child: const Text('占位'),
              ),
              const SizedBox(height: 12),
              const Text(
                'TODO: 模板导入 / 拖拽排序 / 批量操作 / 统计 重新引入',
                style: TextStyle(fontSize: 11, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
