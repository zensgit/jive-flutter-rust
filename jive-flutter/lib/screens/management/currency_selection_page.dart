import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/currency.dart' as model;
import '../../providers/currency_provider.dart';
import '../../models/exchange_rate.dart';
import '../../widgets/source_badge.dart';
import '../../providers/settings_provider.dart';

/// 货币选择管理页面
class CurrencySelectionPage extends ConsumerStatefulWidget {
  final bool isSelectingBaseCurrency;
  final bool compact;

  const CurrencySelectionPage({
    super.key,
    this.isSelectingBaseCurrency = false,
    this.compact = false,
  });

  @override
  ConsumerState<CurrencySelectionPage> createState() =>
      _CurrencySelectionPageState();
}

class _CurrencySelectionPageState extends ConsumerState<CurrencySelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isUpdatingRates = false;
  final Map<String, TextEditingController> _rateControllers = {};
  final Map<String, bool> _manualRates = {};
  final Map<String, DateTime> _manualExpiry = {};
  final Map<String, double> _localRateOverrides = {};
  bool _compact = false;

  @override
  void initState() {
    super.initState();
    _compact = widget.compact;
    // 打开页面时自动获取汇率
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchLatestRates();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _rateControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchLatestRates() async {
    if (!mounted) return;
    setState(() {
      _isUpdatingRates = true;
    });

    try {
      await ref.read(currencyProvider.notifier).refreshExchangeRates();
      if (mounted) {
        _showSnackBar('汇率已更新', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('汇率更新失败', Colors.red);
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isUpdatingRates = false;
      });
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  List<model.Currency> _getFilteredCurrencies() {
    final allCurrencies = ref.watch(availableCurrenciesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final selectedCurrencies = ref.watch(selectedCurrenciesProvider);

    // 过滤法定货币
    List<model.Currency> fiatCurrencies =
        allCurrencies.where((c) => !c.isCrypto).toList();

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      fiatCurrencies = fiatCurrencies.where((currency) {
        return currency.code.toLowerCase().contains(query) ||
            currency.name.toLowerCase().contains(query) ||
            currency.nameZh.toLowerCase().contains(query) ||
            currency.symbol.toLowerCase().contains(query);
      }).toList();
    }

    // 排序：基础货币第一，已选择的排前面
    fiatCurrencies.sort((a, b) {
      // 基础货币永远第一
      if (a.code == baseCurrency.code) return -1;
      if (b.code == baseCurrency.code) return 1;

      // 已选择的排前面
      final aSelected = selectedCurrencies.contains(a);
      final bSelected = selectedCurrencies.contains(b);
      if (aSelected != bSelected) return aSelected ? -1 : 1;

      // 按代码字母排序
      return a.code.compareTo(b.code);
    });

    return fiatCurrencies;
  }

  Widget _buildCurrencyTile(model.Currency currency) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dense = _compact;
    final isBaseCurrency =
        currency.code == ref.watch(baseCurrencyProvider).code;
    final isSelected = ref.watch(selectedCurrenciesProvider).contains(currency);
    final rates = ref.watch(exchangeRateObjectsProvider);
    final rateObj = rates[currency.code];
    final rate = rateObj?.rate ?? 1.0;
    final displayRate = _localRateOverrides[currency.code] ?? rate;

    // 获取或创建汇率输入控制器
    if (!_rateControllers.containsKey(currency.code)) {
      _rateControllers[currency.code] = TextEditingController(
        text: displayRate.toStringAsFixed(4),
      );
    }

    if (widget.isSelectingBaseCurrency) {
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 2 : 4),
        elevation: isBaseCurrency ? 2 : 1,
        color: isBaseCurrency ? cs.tertiaryContainer : cs.surface,
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: isBaseCurrency ? cs.tertiary : cs.outlineVariant),
            ),
            child: Center(
              child: Text(currency.flag ?? currency.symbol,
                  style: TextStyle(fontSize: 20, color: cs.onSurface)),
            ),
          ),
          title: Row(
            children: [
              if (isBaseCurrency)
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: dense ? 6 : 8, vertical: 3),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cs.tertiary),
                  ),
                  child: Text('基础',
                      style: TextStyle(
                          fontSize: dense ? 10 : 11,
                          color: cs.onTertiaryContainer,
                          fontWeight: FontWeight.w700)),
                ),
              Text(currency.code,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: cs.surfaceVariant,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(currency.symbol,
                    style: TextStyle(fontSize: dense ? 11 : 12)),
              ),
            ],
          ),
          subtitle: Text(currency.nameZh,
              style: TextStyle(
                  fontSize: dense ? 12 : 13, color: cs.onSurfaceVariant)),
          trailing: isBaseCurrency
              ? const Icon(Icons.check_circle, color: Colors.amber)
              : const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context, currency),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 2 : 4),
      elevation: isBaseCurrency ? 2 : 1,
      color: isBaseCurrency
          ? cs.tertiaryContainer
          : (isSelected ? cs.secondaryContainer : cs.surface),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isBaseCurrency
                  ? cs.tertiary
                  : (isSelected ? cs.secondary : cs.outlineVariant),
            ),
          ),
          child: Center(
            child: Text(
              currency.flag ?? currency.symbol,
              style: TextStyle(fontSize: 20, color: cs.onSurface),
            ),
          ),
        ),
        title: Row(
          children: [
            if (isBaseCurrency)
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: dense ? 6 : 8, vertical: 3),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: cs.tertiaryContainer,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: cs.tertiary),
                ),
                child: Text(
                  '基础',
                  style: TextStyle(
                    fontSize: dense ? 10 : 11,
                    color: cs.onTertiaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        currency.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(currency.symbol,
                            style: TextStyle(fontSize: dense ? 11 : 12)),
                      ),
                    ],
                  ),
                  Text(currency.nameZh,
                      style: TextStyle(
                          fontSize: dense ? 12 : 13,
                          color: cs.onSurfaceVariant)),
                  // Inline rate + source to avoid tall trailing overflow
                  if (!isBaseCurrency &&
                      (rateObj != null ||
                          _localRateOverrides.containsKey(currency.code))) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                              '1 ${ref.watch(baseCurrencyProvider).code} = ${displayRate.toStringAsFixed(4)} ${currency.code}',
                              style: TextStyle(
                                  fontSize: dense ? 11 : 12,
                                  color: cs.onSurface),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        SourceBadge(
                            source:
                                _localRateOverrides.containsKey(currency.code)
                                    ? 'manual'
                                    : (rateObj?.source)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        trailing: Checkbox(
          value: isSelected,
          onChanged: isBaseCurrency
              ? null
              : (value) async {
                  if (value == true) {
                    await ref
                        .read(currencyProvider.notifier)
                        .addSelectedCurrency(currency.code);
                  } else {
                    await ref
                        .read(currencyProvider.notifier)
                        .removeSelectedCurrency(currency.code);
                  }
                },
          activeColor: cs.primary,
        ),
        // ExpansionTile has no onTap; capture base currency selection via GestureDetector
        children: isSelected && !widget.isSelectingBaseCurrency
            ? [
                Container(
                  padding: EdgeInsets.all(dense ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, size: 16, color: cs.primary),
                          const SizedBox(width: 8),
                          const Text(
                            '汇率设置',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (_manualRates[currency.code] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.tertiaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '手动',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: cs.onTertiaryContainer),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _rateControllers[currency.code],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    '1 ${ref.watch(baseCurrencyProvider).code} = ',
                                suffixText: currency.code,
                                border: const OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: dense ? 10 : 12,
                                    vertical: dense ? 6 : 8),
                              ),
                              onChanged: (value) {
                                if (!mounted) return;
                                setState(() {
                                  _manualRates[currency.code] = true;
                                });
                              },
                            ),
                          ),
                          SizedBox(width: dense ? 8 : 12),
                          Column(
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  // 自动获取最新汇率
                                  if (mounted) {
                                    setState(() {
                                      _manualRates[currency.code] = false;
                                      _localRateOverrides.remove(currency.code);
                                    });
                                  }
                                  // 清除该币种的手动汇率，恢复自动
                                  await ref
                                      .read(currencyProvider.notifier)
                                      .clearManualRate(currency.code);
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('自动'),
                                style: TextButton.styleFrom(
                                    foregroundColor: cs.primary),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  // 选择有效期（默认次日 UTC）
                                  final tomorrow = DateTime.now()
                                      .add(const Duration(days: 1));
                                  DateTime defaultExpiry = DateTime.utc(
                                      tomorrow.year,
                                      tomorrow.month,
                                      tomorrow.day,
                                      0,
                                      0,
                                      0);
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _manualExpiry[currency.code]
                                            ?.toLocal() ??
                                        defaultExpiry.toLocal(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 60)),
                                  );
                                  if (date != null) {
                                    _manualExpiry[currency.code] = DateTime.utc(
                                        date.year,
                                        date.month,
                                        date.day,
                                        0,
                                        0,
                                        0);
                                  } else {
                                    _manualExpiry[currency.code] =
                                        defaultExpiry;
                                  }
                                  // 保存手动汇率 + 有效期
                                  final rate = double.tryParse(
                                      _rateControllers[currency.code]!.text);
                                  final expiry = _manualExpiry[currency.code] ??
                                      defaultExpiry;
                                  if (rate != null && rate > 0) {
                                    await ref
                                        .read(currencyProvider.notifier)
                                        .upsertManualRate(
                                            currency.code, rate, expiry);
                                    if (mounted) {
                                      setState(() {
                                        _manualRates[currency.code] = true;
                                        _localRateOverrides[currency.code] =
                                            rate;
                                        _rateControllers[currency.code]?.text =
                                            rate.toStringAsFixed(4);
                                      });
                                      _showSnackBar(
                                          '汇率已保存，至 ${expiry.toLocal().toString().split(" ").first} 生效',
                                          Colors.green);
                                    }
                                  } else {
                                    if (mounted) {
                                      _showSnackBar('请输入有效汇率', Colors.red);
                                    }
                                  }
                                },
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text('保存(含有效期)'),
                                style: TextButton.styleFrom(
                                    foregroundColor: cs.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (_manualExpiry[currency.code] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              Icon(Icons.schedule,
                                  size: dense ? 14 : 16, color: cs.tertiary),
                              const SizedBox(width: 6),
                              Text(
                                '手动汇率有效期: ${_manualExpiry[currency.code]!.toLocal().toString().split(" ").first} 00:00',
                                style: TextStyle(
                                    fontSize: dense ? 11 : 12,
                                    color: cs.tertiary),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ]
            : [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCurrencies = _getFilteredCurrencies();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.isSelectingBaseCurrency ? '选择基础货币' : '管理法定货币',
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        elevation: 0.5,
        actions: [
          if (!widget.isSelectingBaseCurrency)
            IconButton(
              onPressed: () async {
                setState(() {
                  _compact = !_compact;
                });
                // Persist to settings
                try {
                  final density = _compact ? 'compact' : 'comfortable';
                  // ignore: use_build_context_synchronously
                  await ref
                      .read(settingsProvider.notifier)
                      .updateSetting('listDensity', density);
                  if (mounted) {
                    _showSnackBar(
                        _compact ? '已切换为紧凑模式' : '已切换为舒适模式', Colors.blue);
                  }
                } catch (_) {}
              },
              icon: Icon(_compact
                  ? Icons.format_list_bulleted
                  : Icons.format_line_spacing),
              tooltip: _compact ? '切换舒适模式' : '切换紧凑模式',
            ),
          if (!widget.isSelectingBaseCurrency)
            IconButton(
              onPressed: _isUpdatingRates ? null : _fetchLatestRates,
              icon: _isUpdatingRates
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              tooltip: '更新汇率',
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: '搜索货币（代码、名称、符号）',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ),

          // 提示信息
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isSelectingBaseCurrency
                        ? '点击选择要设为基础货币的货币'
                        : '勾选要使用的货币，展开可设置汇率',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer),
                  ),
                ),
              ],
            ),
          ),

          // 货币列表
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => ListView.builder(
                padding: EdgeInsets.only(
                  top: 8,
                  bottom:
                      widget.isSelectingBaseCurrency ? 8 : 88, // 留出底部空间，避免被底栏遮挡
                ),
                itemCount: filteredCurrencies.length,
                itemBuilder: (context, index) {
                  return SafeArea(
                    bottom: true,
                    top: false,
                    maintainBottomViewPadding: true,
                    child: _buildCurrencyTile(filteredCurrencies[index]),
                  );
                },
              ),
            ),
          ),

          // 底部统计
          if (!widget.isSelectingBaseCurrency)
            SafeArea(
              top: false,
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '已选择 ${ref.watch(selectedCurrenciesProvider).length} 种货币',
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('完成'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
