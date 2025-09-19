import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/category.dart';
import '../../models/category_template.dart';
import '../../providers/category_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../services/api/category_service.dart';
import '../../widgets/bottom_sheets/import_details_sheet.dart';

class CategoryManagementEnhancedPage extends ConsumerStatefulWidget {
  const CategoryManagementEnhancedPage({super.key});

  @override
  ConsumerState<CategoryManagementEnhancedPage> createState() => _CategoryManagementEnhancedPageState();
}

class _CategoryManagementEnhancedPageState extends ConsumerState<CategoryManagementEnhancedPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        actions: [
          IconButton(
            tooltip: '从模板库导入',
            icon: const Icon(Icons.library_add),
            onPressed: _busy ? null : _showTemplateLibrary,
          ),
        ],
      ),
      body: Center(
        child: _busy
            ? const CircularProgressIndicator()
            : const Text('分类管理（最小版）：点击右上角导入模板')
      ),
    );
  }

  Future<void> _showTemplateLibrary() async {
    final ledgerId = ref.read(currentLedgerProvider)?.id;
    if (ledgerId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无当前账本，无法导入模板')));
      return;
    }

    setState(() { _busy = true; });
    List<SystemCategoryTemplate> templates = [];
    try {
      templates = await CategoryService().getAllTemplates(forceRefresh: true);
    } catch (_) {}
    if (!mounted) return;
    setState(() { _busy = false; });

    final selected = <SystemCategoryTemplate>{};
    String conflict = 'skip'; // skip|rename|update
    ImportResult? preview;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('从模板库导入'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('冲突策略: '),
                      const SizedBox(width: 8),
                      DropdownButton<String>(
                        value: conflict,
                        items: const [
                          DropdownMenuItem(value: 'skip', child: Text('跳过')),
                          DropdownMenuItem(value: 'rename', child: Text('重命名')),
                          DropdownMenuItem(value: 'update', child: Text('覆盖')),
                        ],
                        onChanged: (v) { if (v!=null) setLocal((){ conflict = v; }); },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 320,
                    child: ListView.builder(
                      itemCount: templates.length,
                      itemBuilder: (_, i) {
                        final t = templates[i];
                        final checked = selected.contains(t);
                        return CheckboxListTile(
                          value: checked,
                          onChanged: (_) => setLocal((){
                            if (checked) { selected.remove(t); } else { selected.add(t); }
                          }),
                          dense: true,
                          title: Text(t.name),
                          subtitle: Text(t.classification.name),
                        );
                      },
                    ),
                  ),
                  if (preview != null) ...[
                    const Divider(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('预览（服务端 dry-run ）', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    SizedBox(
                      height: 160,
                      child: ListView.builder(
                        itemCount: preview!.details.length,
                        itemBuilder: (_, i) {
                          final d = preview!.details[i];
                          final color = (d.action == 'failed' || d.action == 'skipped') ? Colors.orange : Colors.green;
                          return ListTile(
                            dense: true,
                            title: Text(d.finalName ?? d.originalName),
                            subtitle: Text(d.action + (d.reason!=null ? ' (${d.reason})' : '')),
                            trailing: Icon(
                              d.action == 'failed' ? Icons.error : (d.action=='skipped'? Icons.warning_amber : Icons.check_circle),
                              color: color,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              TextButton(
                onPressed: selected.isEmpty ? null : () async {
                  try {
                    final items = selected.map((t) => { 'template_id': t.id }).toList();
                    final res = await CategoryService().importTemplatesAdvanced(
                      ledgerId: ledgerId,
                      items: items,
                      onConflict: conflict,
                      dryRun: true,
                    );
                    setLocal((){ preview = res; });
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('预览失败: $e')));
                    }
                  }
                },
                child: const Text('预览'),
              ),
              FilledButton(
                onPressed: (selected.isEmpty) ? null : () async {
                  Navigator.pop(ctx);
                  try {
                    final items = selected.map((t) => { 'template_id': t.id }).toList();
                    final result = await CategoryService().importTemplatesAdvanced(
                      ledgerId: ledgerId,
                      items: items,
                      onConflict: conflict,
                    );
                    if (!mounted) return;
                    await ref.read(userCategoriesProvider.notifier).refreshFromBackend(ledgerId: ledgerId);
                    await ImportDetailsSheet.show(context, result);
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('导入失败: $e')));
                  }
                },
                child: const Text('确认导入'),
              ),
            ],
          ),
        );
      },
    );
  }
}
