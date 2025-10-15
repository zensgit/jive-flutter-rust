import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/models/currency.dart' as model;
import 'package:jive_money/providers/currency_provider.dart';
import 'package:jive_money/widgets/source_badge.dart';
import 'package:jive_money/providers/settings_provider.dart';

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
    // 打开页面时只在汇率过期的情况下才刷新（避免每次都调用API）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 检查汇率是否需要更新（超过1小时未更新）
      if (ref.read(currencyProvider.notifier).ratesNeedUpdate) {
        _fetchLatestRates();
      }
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

    // 🔍 DEBUG: 验证法币过滤是否正确
    print('[CurrencySelectionPage] Total currencies: ${allCurrencies.length}');
    print('[CurrencySelectionPage] Fiat currencies: ${fiatCurrencies.length}');

    // 检查问题加密货币是否出现在法币列表
    final problemCryptos = ['1INCH', 'AAVE', 'ADA', 'AGIX', 'PEPE', 'MKR', 'COMP', 'BTC', 'ETH'];
    final foundProblems = fiatCurrencies.where((c) => problemCryptos.contains(c.code)).toList();
    if (foundProblems.isNotEmpty) {
      print('[CurrencySelectionPage] ❌ ERROR: Found crypto in fiat list: ${foundProblems.map((c) => c.code).join(", ")}');
    } else {
      print('[CurrencySelectionPage] ✅ OK: No crypto in fiat list');
    }

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

    // 排序：基础货币第一，手动汇率第二，已选择的排前面
    final rates = ref.watch(exchangeRateObjectsProvider);
    fiatCurrencies.sort((a, b) {
      // 基础货币永远第一
      if (a.code == baseCurrency.code) return -1;
      if (b.code == baseCurrency.code) return 1;

      // ✅ 手动汇率的货币排在基础货币下面（第二优先级）
      final aIsManual = rates[a.code]?.source == 'manual';
      final bIsManual = rates[b.code]?.source == 'manual';
      if (aIsManual != bIsManual) return aIsManual ? -1 : 1;

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
    // Check if this is a saved manual rate (provider loads manual rates with source='manual')
    final isManual = rateObj?.source == 'manual';
    final displayRate = isManual ? rate : (_localRateOverrides[currency.code] ?? rate);

    // DEBUG: Log rate information for troubleshooting
    if (rateObj != null && rateObj.source == 'manual') {
      print('[CurrencySelectionPage] ${currency.code}: Manual rate detected! rate=$rate, source=${rateObj.source}');
    }

    // 获取或创建汇率输入控制器
    if (!_rateControllers.containsKey(currency.code)) {
      _rateControllers[currency.code] = TextEditingController(
        text: displayRate.toStringAsFixed(4),
      );
    } else {
      // 如果controller已存在，检查是否需要更新其值
      // 只在不是手动编辑状态时更新（避免覆盖用户正在输入的内容）
      if (_manualRates[currency.code] != true) {
        final currentValue = double.tryParse(_rateControllers[currency.code]!.text) ?? 0;
        if ((currentValue - displayRate).abs() > 0.0001) {
          // displayRate发生了变化，更新controller
          _rateControllers[currency.code]!.text = displayRate.toStringAsFixed(4);
          print('[CurrencySelectionPage] ${currency.code}: Updated controller from $currentValue to $displayRate');
        }
      }
    }

    if (widget.isSelectingBaseCurrency) {
      return Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: dense ? 2 : 4),
        elevation: isBaseCurrency ? 2 : 1,
        color: isBaseCurrency ? cs.tertiaryContainer : cs.surface,
        child: ListTile(
          leading: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: Text(
                currency.flag ?? currency.symbol,
                style: const TextStyle(fontSize: 32),
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
                  child: Text('基础',
                      style: TextStyle(
                          fontSize: dense ? 10 : 11,
                          color: cs.onTertiaryContainer,
                          fontWeight: FontWeight.w700)),
                ),
              // 🔥 优先显示中文名
              Text(currency.nameZh,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(currency.code,
                    style: TextStyle(fontSize: dense ? 11 : 12)),
              ),
            ],
          ),
          subtitle: Text('${currency.symbol} · ${currency.code}',
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
        leading: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Text(
              currency.flag ?? currency.symbol,
              style: const TextStyle(fontSize: 32),
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
                      // 🔥 优先显示中文名
                      Text(
                        currency.nameZh,
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
                          color: cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(currency.code,
                            style: TextStyle(fontSize: dense ? 11 : 12)),
                      ),
                    ],
                  ),
                  Text('${currency.symbol} · ${currency.code}',
                      style: TextStyle(
                          fontSize: dense ? 12 : 13,
                          color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            // 🔥 将汇率和来源标识移到右侧，与加密货币页面保持一致
            if (!isBaseCurrency &&
                (rateObj != null ||
                    _localRateOverrides.containsKey(currency.code)))
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '1 ${ref.watch(baseCurrencyProvider).code} = ${displayRate.toStringAsFixed(4)} ${currency.code}',
                    style: TextStyle(
                      fontSize: dense ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SourceBadge(
                        source: _localRateOverrides.containsKey(currency.code)
                            ? 'manual'
                            : (rateObj?.source),
                      ),
                    ],
                  ),
                  if (rateObj?.source == 'manual')
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Builder(builder: (_) {
                        final expiry = ref
                            .read(currencyProvider.notifier)
                            .manualExpiryFor(currency.code);
                        final text = expiry != null
                            ? '手动有效至 ${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}'
                            : '手动汇率有效中';
                        return Text(
                          text,
                          style: TextStyle(
                            fontSize: dense ? 10 : 11,
                            color: Colors.orange[700],
                          ),
                        );
                      }),
                    ),
                ],
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

                                  // 1. 选择日期
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
                                    // 2. 选择时间
                                    if (!mounted) return;
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                          _manualExpiry[currency.code]?.toLocal() ??
                                              defaultExpiry.toLocal()),
                                    );

                                    if (time != null) {
                                      _manualExpiry[currency.code] = DateTime.utc(
                                          date.year,
                                          date.month,
                                          date.day,
                                          time.hour,   // 用户选择的小时
                                          time.minute, // 用户选择的分钟
                                          0);          // 秒固定为0
                                    } else {
                                      // 用户取消时间选择，使用默认 00:00
                                      _manualExpiry[currency.code] = DateTime.utc(
                                          date.year,
                                          date.month,
                                          date.day,
                                          0,
                                          0,
                                          0);
                                    }
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
                                      // 显示完整的日期时间
                                      final expiryLocal = expiry.toLocal();
                                      _showSnackBar(
                                          '汇率已保存，至 ${expiryLocal.year}-${expiryLocal.month.toString().padLeft(2, '0')}-${expiryLocal.day.toString().padLeft(2, '0')} ${expiryLocal.hour.toString().padLeft(2, '0')}:${expiryLocal.minute.toString().padLeft(2, '0')} 生效',
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
                              Builder(builder: (_) {
                                final expiry = _manualExpiry[currency.code]!.toLocal();
                                return Text(
                                  '手动汇率有效期: ${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')} ${expiry.hour.toString().padLeft(2, '0')}:${expiry.minute.toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                      fontSize: dense ? 11 : 12,
                                      color: cs.tertiary),
                                );
                              }),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      // 汇率变化趋势（实时数据）
                      if (rateObj != null)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildRateChange(
                                cs,
                                '24h',
                                rateObj.change24h,
                                _compact,
                              ),
                              _buildRateChange(
                                cs,
                                '7d',
                                rateObj.change7d,
                                _compact,
                              ),
                              _buildRateChange(
                                cs,
                                '30d',
                                rateObj.change30d,
                                _compact,
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

  Widget _buildRateChange(
    ColorScheme cs,
    String period,
    double? changePercent,
    bool compact,
  ) {
    // 如果没有数据，显示 --
    if (changePercent == null) {
      return Column(
        children: [
          Text(
            period,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '--',
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    // 确定颜色：正数绿色，负数红色
    final color = changePercent >= 0 ? Colors.green : Colors.red;
    // 格式化百分比：带符号
    final changeText =
        '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%';

    return Column(
      children: [
        Text(
          period,
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          changeText,
          style: TextStyle(
            fontSize: compact ? 11 : 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
                    Builder(builder: (context) {
                      final selectedCurrencies = ref.watch(selectedCurrenciesProvider);
                      final fiatCount = selectedCurrencies.where((c) => !c.isCrypto).length;

                      // 🔍 DEBUG: 打印selectedCurrenciesProvider的详细信息
                      print('[Bottom Stats] Total selected currencies: ${selectedCurrencies.length}');
                      print('[Bottom Stats] Fiat count: $fiatCount');
                      print('[Bottom Stats] Selected currencies list:');
                      for (final c in selectedCurrencies) {
                        print('  - ${c.code}: isCrypto=${c.isCrypto}');
                      }

                      return Text(
                        '已选择 $fiatCount 种法定货币',
                        style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface),
                      );
                    }),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('返回'),
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
