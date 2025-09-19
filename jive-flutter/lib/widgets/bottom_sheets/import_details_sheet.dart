import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api/category_service.dart';

class ImportDetailsSheet {
  static Future<void> show(BuildContext context, ImportResult result) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final groups = <String, List<ImportActionDetail>>{};
        for (final d in result.details) {
          groups.putIfAbsent(d.action, () => []).add(d);
        }
        final jsonPayload = jsonEncode({
          'imported': result.imported,
          'skipped': result.skipped,
          'failed': result.failed,
          'details': result.details.map((e) => {
                'template_id': e.templateId,
                'action': e.action,
                'original_name': e.originalName,
                if (e.finalName != null) 'final_name': e.finalName,
                if (e.categoryId != null) 'category_id': e.categoryId,
                if (e.reason != null) 'reason': e.reason,
              }).toList(),
        });

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('导入详情', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: jsonPayload));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: const Text('已复制 JSON 到剪贴板')));
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('复制JSON'),
                    ),
                  ],
                ),
                const Text('新增: ${result.imported}  跳过: ${result.skipped}  失败: ${result.failed}',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: .8))),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    controller: controller,
                    children: groups.entries.map((e) {
                      final action = e.key;
                      final items = e.value;
                      final color = (action == 'failed' || action == 'skipped') ? Colors.orange : Colors.green;
                      return ExpansionTile(
                        title: const Text('$action (${items.length})', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                        children: items.map((d) => ListTile(
                              dense: true,
                              title: const Text(d.predictedName ?? d.finalName ?? d.originalName),
                              subtitle: const Text(d.reason != null ? d.reason! : ''),
                              trailing: const Icon(
                                action == 'failed'
                                    ? Icons.error
                                    : (action == 'skipped' ? Icons.warning_amber : Icons.check_circle),
                                color: color,
                              ),
                            )).toList(),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
