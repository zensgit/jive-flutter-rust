import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/currency_provider.dart';
import '../../models/currency.dart' as model;

/// 用户端：统一浏览与管理（启用/禁用）法币+加密币
class UserCurrencyBrowser extends ConsumerStatefulWidget {
  const UserCurrencyBrowser({super.key});

  @override
  ConsumerState<UserCurrencyBrowser> createState() =>
      _UserCurrencyBrowserState();
}

class _UserCurrencyBrowserState extends ConsumerState<UserCurrencyBrowser> {
  String _q = '';
  bool _showCrypto = true;
  String _filter = 'all'; // all | enabled | down

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(availableCurrenciesProvider);
    final selected =
        ref.watch(selectedCurrenciesProvider).map((e) => e.code).toSet();
    final base = ref.watch(baseCurrencyProvider).code;
    final list = all.where((c) {
      if (!_showCrypto && c.isCrypto) return false;
      if (_q.isEmpty) return true;
      final q = _q.toLowerCase();
      return c.code.toLowerCase().contains(q) ||
          c.name.toLowerCase().contains(q) ||
          c.nameZh.toLowerCase().contains(q) ||
          c.symbol.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        if (a.code == base) return -1;
        if (b.code == base) return 1;
        final aSel = selected.contains(a.code);
        final bSel = selected.contains(b.code);
        if (aSel != bSel) return aSel ? -1 : 1;
        return a.code.compareTo(b.code);
      });

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('币种管理（用户）'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _showCrypto = !_showCrypto),
            icon:
                Icon(_showCrypto ? Icons.currency_bitcoin : Icons.attach_money),
            tooltip: _showCrypto ? '仅看法币' : '包含加密币',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: const InputDecoration(
                hintText: '搜索（代码/名称/符号）',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          // 过滤：全部 / 仅启用 / 仅下线
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('全部'),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('仅启用'),
                  selected: _filter == 'enabled',
                  onSelected: (_) => setState(() => _filter = 'enabled'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('仅下线'),
                  selected: _filter == 'down',
                  onSelected: (_) => setState(() => _filter = 'down'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) =>
                  _row(list[i], selected.contains(list[i].code), base, cs),
            ),
          )
        ],
      ),
    );
  }

  Widget _row(model.Currency c, bool isSelected, String base, ColorScheme cs) {
    // 过滤逻辑应用在构造行前
    if (_filter == 'enabled' && c.isEnabled == false)
      return const SizedBox.shrink();
    if (_filter == 'down' && c.isEnabled != false)
      return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: cs.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Center(
              child: Text(c.flag ?? c.symbol,
                  style: const TextStyle(fontSize: 18))),
        ),
        title: Row(
          children: [
            if (c.code == base)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: cs.tertiary)),
                child: Text('基础',
                    style: TextStyle(
                        color: cs.onTertiaryContainer,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            Text(c.code, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: cs.surfaceVariant,
                  borderRadius: BorderRadius.circular(4)),
              child: Text(c.symbol,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            ),
            const SizedBox(width: 8),
            if (c.isCrypto)
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('加密',
                      style: TextStyle(
                          color: cs.onSecondaryContainer, fontSize: 11)))
          ],
        ),
        subtitle: Text(
            '${c.name} · ${c.nameZh} · 小数位: ${c.decimalPlaces}${c.isEnabled ? '' : ' · 已下线'}'),
        trailing: _trailingButtons(c, isSelected, base, cs),
      ),
    );
  }

  Widget _trailingButtons(
      model.Currency c, bool isSelected, String base, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (c.code != base)
          IconButton(
            icon: Icon(
                isSelected
                    ? Icons.remove_circle_outline
                    : Icons.add_circle_outline,
                color: isSelected ? cs.error : cs.primary),
            tooltip: isSelected ? '移除' : '加入',
            onPressed: () async {
              final notifier = ref.read(currencyProvider.notifier);
              if (isSelected) {
                await notifier.removeSelectedCurrency(c.code);
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('已移除 ${c.code}')));
                }
              } else {
                await notifier.addSelectedCurrency(c.code);
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('已启用 ${c.code}')));
                }
              }
            },
          ),
        const SizedBox(width: 4),
        if (!c.isCrypto)
          TextButton(
            onPressed: c.code == base
                ? null
                : () async {
                    final notifier = ref.read(currencyProvider.notifier);
                    await notifier.setBaseCurrency(c.code);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('基础货币已设为 ${c.code}')));
                    }
                  },
            child: Text('设为基础'),
          ),
      ],
    );
  }
}
