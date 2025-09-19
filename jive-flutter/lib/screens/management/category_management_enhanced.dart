import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  String _renderDryRunSubtitle(ImportActionDetail d) {
    switch (d.action) {
      case 'renamed':
        return '将重命名' + (d.predictedName != null ? ' → ${d.predictedName}' : '');
      case 'updated':
        return '将覆盖同名分类';
      case 'skipped':
        return '将跳过' + (d.reason != null ? '（${d.reason}）' : '');
      case 'failed':
        return '预检失败' + (d.reason != null ? '（${d.reason}）' : '');
      case 'imported':
      default:
        return '将创建';
    }
  }

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: const Text('无当前账本，无法导入模板')));
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
          builder: (ctx, setLocal) {
            // ETag + pagination local state
            List<SystemCategoryTemplate> list = List<SystemCategoryTemplate>.from(templates);
            String? etag;
            int page = 1;
            const int perPage = 50;
            int total = list.length;
            bool fetching = false;
            bool initialized = false;

            Future<void> fetch({bool reset = false, bool next = false}) async {
              if (fetching) return;
              fetching = true; setLocal((){});
              try {
                if (reset) page = 1; else if (next) page += 1;
                final res = await CategoryService().getTemplatesWithEtag(
                  etag: etag,
                  page: page,
                  perPage: perPage,
                );
                if (!res.notModified) {
                  if (page == 1) {
                    list = List<SystemCategoryTemplate>.from(res.items);
                  } else {
                    list = List<SystemCategoryTemplate>.from(list)..addAll(res.items);
                  }
                  etag = res.etag ?? etag;
                  total = res.total;
                }
              } catch (_) {
                // ignore errors, keep current list
              } finally {
                fetching = false; setLocal((){});
              }
            }

            if (!initialized) {
              initialized = true;
              // Kick off a fresh fetch to get total/etag even if we had a warmup list
              // ignore: discarded_futures
              fetch(reset: true);
            }

            return AlertDialog(
              title: const Text('从模板库导入'),
              content: const SizedBox(
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
                          DropdownMenuItem(value: 'skip', child: const Text('跳过')),
                          DropdownMenuItem(value: 'rename', child: const Text('重命名')),
                          DropdownMenuItem(value: 'update', child: const Text('覆盖')),
                        ],
                        onChanged: (v) { if (v!=null) setLocal((){ conflict = v; }); },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const SizedBox(
                    height: 320,
                    child: Column(
                      children: [
                        if (fetching) const LinearProgressIndicator(minHeight: 2),
                        Expanded(
                          child: ListView.builder(
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final t = list[i];
                              final checked = selected.contains(t);
                              return CheckboxListTile(
                                value: checked,
                                onChanged: (_) => setLocal((){
                                  if (checked) { selected.remove(t); } else { selected.add(t); }
                                }),
                                dense: true,
                                title: const Text(t.name),
                                subtitle: const Text(t.classification.name),
                              );
                            },
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('共 $total 项，当前 ${list.length}', style: Theme.of(context).textTheme.bodySmall),
                              OutlinedButton.icon(
                                onPressed: (!fetching && list.length < total) ? () => fetch(next: true) : null,
                                icon: const Icon(Icons.more_horiz),
                                label: const Text('加载更多'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (preview != null) ...[
                    const Divider(),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const Text('预览（服务端 dry-run ）', style: Theme.of(context).textTheme.titleSmall),
                    ),
                    const SizedBox(
                      height: 160,
                      child: ListView.builder(
                        itemCount: preview!.details.length,
                        itemBuilder: (_, i) {
                          final d = preview!.details[i];
                          final color = (d.action == 'failed' || d.action == 'skipped') ? Colors.orange : Colors.green;
                          return ListTile(
                            dense: true,
                            title: const Text(d.predictedName ?? d.finalName ?? d.originalName),
                            subtitle: const Text(_renderDryRunSubtitle(d)),
                            trailing: const Icon(
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
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('预览失败: $e')));
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('导入失败: $e')));
                  }
                },
                child: const Text('确认导入'),
              ),
            ],
          );
        });
      },
    );
  }
}
