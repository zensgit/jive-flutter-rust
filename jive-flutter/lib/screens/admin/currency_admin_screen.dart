import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/models/admin_currency.dart';
import 'package:jive_money/services/admin/currency_admin_service.dart';

final currencyAdminProvider =
    FutureProvider.autoDispose<List<AdminCurrency>>((ref) async {
  final service = CurrencyAdminService();
  return service.listCurrencies();
});

class CurrencyAdminScreen extends ConsumerStatefulWidget {
  const CurrencyAdminScreen({super.key});

  @override
  ConsumerState<CurrencyAdminScreen> createState() =>
      _CurrencyAdminScreenState();
}

class _CurrencyAdminScreenState extends ConsumerState<CurrencyAdminScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final asyncList = ref.watch(currencyAdminProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('币种管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _openEditDialog(context),
            tooltip: '新增币种',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜索（代码/名称/符号）',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: asyncList.when(
              data: (list) {
                final filtered = list.where((c) {
                  if (_query.isEmpty) return true;
                  return c.code.toLowerCase().contains(_query) ||
                      c.name.toLowerCase().contains(_query) ||
                      c.nameZh.toLowerCase().contains(_query) ||
                      c.symbol.toLowerCase().contains(_query);
                }).toList()
                  ..sort((a, b) => a.code.compareTo(b.code));
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await CurrencyAdminService().refreshCatalog();
                              if (mounted && context.mounted) {
                                ref.invalidate(currencyAdminProvider);
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已触发目录刷新')));
                              }
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('刷新目录'),
                          ),
                          const SizedBox(width: 12),
                          const Text('来源/更新时间显示如下：'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, i) => _buildRow(filtered[i]),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('加载失败：$e')),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRow(AdminCurrency c) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Center(
            child:
                Text(c.flag ?? c.symbol, style: const TextStyle(fontSize: 18)),
          ),
        ),
        title: Row(
          children: [
            Text(c.code, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(c.symbol,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            if (c.isCrypto)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('加密',
                    style: TextStyle(
                        color: cs.onSecondaryContainer, fontSize: 11)),
              )
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${c.name} · ${c.nameZh} · 小数位: ${c.decimalPlaces}'),
            const SizedBox(height: 4),
            Row(
              children: [
                if (c.coingeckoId != null && c.coingeckoId!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Chip(
                        label: Text('CoinGecko: ${c.coingeckoId}'),
                        visualDensity: VisualDensity.compact),
                  ),
                if (c.coincapSymbol != null && c.coincapSymbol!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Chip(
                        label: Text('CoinCap: ${c.coincapSymbol}'),
                        visualDensity: VisualDensity.compact),
                  ),
                if (c.binanceSymbol != null && c.binanceSymbol!.isNotEmpty)
                  Chip(
                      label: Text('Binance: ${c.binanceSymbol}'),
                      visualDensity: VisualDensity.compact),
              ],
            ),
            if (c.updatedAt != null || c.lastRefreshedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '更新: ${c.updatedAt?.toLocal().toString().split(".").first ?? '-'} · 抓取: ${c.lastRefreshedAt?.toLocal().toString().split(".").first ?? '-'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: c.isActive,
              onChanged: (v) => _toggleActive(c, v),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _openEditDialog(context, target: c);
                if (v == 'alias') _openAliasDialog(context, c);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                    value: 'edit',
                    child:
                        ListTile(leading: Icon(Icons.edit), title: Text('编辑'))),
                PopupMenuItem(
                    value: 'alias',
                    child: ListTile(
                        leading: Icon(Icons.merge_type), title: Text('改码/合并'))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(AdminCurrency c, bool active) async {
    final service = CurrencyAdminService();
    await service.updateCurrency(c.code, {'is_active': active});
    ref.invalidate(currencyAdminProvider);
  }

  Future<void> _openAliasDialog(BuildContext context, AdminCurrency c) async {
    final newCodeCtrl = TextEditingController();
    DateTime? validUntil;
    final deactivateOld = ValueNotifier<bool>(true);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('改码 / 合并'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: c.code,
                readOnly: true,
                decoration: const InputDecoration(
                    labelText: '旧代码', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: newCodeCtrl,
                decoration: const InputDecoration(
                    labelText: '新代码*',
                    border: OutlineInputBorder(),
                    hintText: '例如：RUB'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: Text(validUntil == null
                          ? '有效期（可选）'
                          : '有效期：${validUntil!.toString().split(' ').first}')),
                  TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: now,
                        lastDate: now.add(const Duration(days: 365)),
                        initialDate: now.add(const Duration(days: 90)),
                      );
                      if (picked != null) {
                        validUntil =
                            DateTime(picked.year, picked.month, picked.day);
                        (context as Element).markNeedsBuild();
                      }
                    },
                    child: const Text('选择日期'),
                  )
                ],
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: deactivateOld,
                builder: (context, v, _) => CheckboxListTile(
                  value: v,
                  onChanged: (nv) => deactivateOld.value = nv ?? true,
                  title: const Text('创建别名后将旧代码设为停用'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存')),
        ],
      ),
    );
    if (ok == true) {
      final newCode = newCodeCtrl.text.trim().toUpperCase();
      if (newCode.isEmpty) return;
      final svc = CurrencyAdminService();
      await svc.createAlias(c.code, newCode, validUntil: validUntil);
      if (deactivateOld.value) {
        await svc.updateCurrency(c.code, {'is_active': false});
      }
      if (mounted && context.mounted) {
        ref.invalidate(currencyAdminProvider);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('已创建别名并保存')));
      }
    }
  }

  Future<void> _openEditDialog(BuildContext context,
      {AdminCurrency? target}) async {
    final result = await showDialog<AdminCurrency>(
      context: context,
      builder: (context) => _EditCurrencyDialog(target: target),
    );
    if (result != null) {
      ref.invalidate(currencyAdminProvider);
    }
  }
}

class _EditCurrencyDialog extends StatefulWidget {
  final AdminCurrency? target;
  const _EditCurrencyDialog({this.target});

  @override
  State<_EditCurrencyDialog> createState() => _EditCurrencyDialogState();
}

class _EditCurrencyDialogState extends State<_EditCurrencyDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _code;
  late TextEditingController _name;
  late TextEditingController _nameZh;
  late TextEditingController _symbol;
  late TextEditingController _flag;
  late TextEditingController _decimals;
  bool _isCrypto = false;
  bool _isActive = true;
  // providers
  late TextEditingController _coingeckoId;
  late TextEditingController _coincapSymbol;
  late TextEditingController _binanceSymbol;

  @override
  void initState() {
    super.initState();
    final t = widget.target;
    _code = TextEditingController(text: t?.code ?? '');
    _name = TextEditingController(text: t?.name ?? '');
    _nameZh = TextEditingController(text: t?.nameZh ?? '');
    _symbol = TextEditingController(text: t?.symbol ?? '');
    _flag = TextEditingController(text: t?.flag ?? '');
    _decimals = TextEditingController(text: (t?.decimalPlaces ?? 2).toString());
    _isCrypto = t?.isCrypto ?? false;
    _isActive = t?.isActive ?? true;
    _coingeckoId = TextEditingController(text: t?.coingeckoId ?? '');
    _coincapSymbol = TextEditingController(text: t?.coincapSymbol ?? '');
    _binanceSymbol = TextEditingController(text: t?.binanceSymbol ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.target != null;
    return AlertDialog(
      title: Text(isEdit ? '编辑币种' : '新增币种'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                      child: _text(_code, '代码*',
                          readOnly: isEdit, validator: _notEmpty)),
                  const SizedBox(width: 12),
                  Expanded(child: _text(_symbol, '符号*', validator: _notEmpty)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _text(_name, '英文名*', validator: _notEmpty)),
                  const SizedBox(width: 12),
                  Expanded(child: _text(_nameZh, '中文名*', validator: _notEmpty)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _text(_flag, '国旗/符号（可选）')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _text(_decimals, '小数位*',
                          keyboardType: TextInputType.number,
                          validator: _isInt)),
                ]),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _isCrypto,
                  onChanged: (v) => setState(() => _isCrypto = v),
                  title: const Text('加密货币'),
                ),
                if (_isCrypto) ...[
                  _text(_coingeckoId, 'CoinGecko ID (推荐)'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: _text(_coincapSymbol, 'CoinCap Symbol')),
                    const SizedBox(width: 12),
                    Expanded(child: _text(_binanceSymbol, 'Binance Symbol')),
                  ]),
                ],
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('启用'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        ElevatedButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }

  Widget _text(TextEditingController c, String label,
      {TextInputType? keyboardType,
      String? Function(String?)? validator,
      bool readOnly = false}) {
    return TextFormField(
      controller: c,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
    );
  }

  String? _notEmpty(String? v) => (v == null || v.trim().isEmpty) ? '必填' : null;
  String? _isInt(String? v) {
    if (v == null || v.isEmpty) return '必填';
    return int.tryParse(v) == null ? '请输入整数' : null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = AdminCurrency(
      code: _code.text.trim().toUpperCase(),
      name: _name.text.trim(),
      nameZh: _nameZh.text.trim(),
      symbol: _symbol.text.trim(),
      decimalPlaces: int.parse(_decimals.text.trim()),
      isCrypto: _isCrypto,
      isActive: _isActive,
      flag: _flag.text.trim().isEmpty ? null : _flag.text.trim(),
      coingeckoId:
          _coingeckoId.text.trim().isEmpty ? null : _coingeckoId.text.trim(),
      coincapSymbol: _coincapSymbol.text.trim().isEmpty
          ? null
          : _coincapSymbol.text.trim(),
      binanceSymbol: _binanceSymbol.text.trim().isEmpty
          ? null
          : _binanceSymbol.text.trim(),
    );
    final svc = CurrencyAdminService();
    if (widget.target == null) {
      await svc.createCurrency(payload);
    } else {
      await svc.updateCurrency(widget.target!.code, payload.toJson());
    }
    if (mounted) Navigator.pop(context, payload);
  }
}
