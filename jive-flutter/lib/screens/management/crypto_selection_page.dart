import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/models/currency.dart' as model;
import 'package:jive_money/models/global_market_stats.dart';
import 'package:jive_money/providers/currency_provider.dart';
import 'package:jive_money/services/currency_service.dart';
import 'package:jive_money/widgets/source_badge.dart';
import 'package:jive_money/providers/settings_provider.dart';

/// 加密货币选择管理页面
class CryptoSelectionPage extends ConsumerStatefulWidget {
  const CryptoSelectionPage({super.key});

  @override
  ConsumerState<CryptoSelectionPage> createState() =>
      _CryptoSelectionPageState();
}

class _CryptoSelectionPageState extends ConsumerState<CryptoSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isUpdatingPrices = false;
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, bool> _manualPrices = {};
  final Map<String, DateTime> _manualExpiry = {};
  final Map<String, double> _localPriceOverrides = {};
  bool _compact = false;
  GlobalMarketStats? _globalMarketStats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final density = ref.read(settingsProvider).listDensity;
      setState(() {
        _compact = density == 'compact';
      });
    });
    // 打开页面时自动获取加密货币价格和全球市场统计
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchLatestPrices();
      _fetchGlobalMarketStats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchLatestPrices() async {
    if (!mounted) return;
    setState(() {
      _isUpdatingPrices = true;
    });

    try {
      await ref.read(currencyProvider.notifier).refreshCryptoPrices();
      if (mounted) {
        _showSnackBar('加密货币价格已更新', Colors.green);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('价格更新失败', Colors.red);
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isUpdatingPrices = false;
      });
    }
  }

  Future<void> _fetchGlobalMarketStats() async {
    if (!mounted) return;
    try {
      final service = CurrencyService(null);
      final stats = await service.getGlobalMarketStats();
      if (mounted && stats != null) {
        setState(() {
          _globalMarketStats = stats;
        });
      }
    } catch (e) {
      // 静默失败，使用硬编码的后备值
      debugPrint('Failed to fetch global market stats: $e');
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

  // 获取加密货币图标（从服务器获取的 emoji）
  Widget _getCryptoIcon(model.Currency crypto) {
    // 🔥 优先使用服务器提供的 icon emoji
    if (crypto.icon != null && crypto.icon!.isNotEmpty) {
      return Text(
        crypto.icon!,
        style: const TextStyle(fontSize: 24),
      );
    }

    // 🔥 后备：使用 symbol 或 code
    if (crypto.symbol.length <= 3) {
      return Text(
        crypto.symbol,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: _getCryptoColor(crypto.code),
        ),
      );
    }

    // 最后的后备：使用通用加密货币图标
    return Icon(
      Icons.currency_bitcoin,
      size: 24,
      color: _getCryptoColor(crypto.code),
    );
  }

  // 获取加密货币颜色
  Color _getCryptoColor(String code) {
    final Map<String, Color> cryptoColors = {
      'BTC': Colors.orange,
      'ETH': Colors.indigo,
      'USDT': Colors.green,
      'USDC': Colors.blue,
      'BNB': Colors.amber,
      'XRP': Colors.blueGrey,
      'ADA': Colors.teal,
      'SOL': Colors.purple,
      'DOT': Colors.pink,
      'DOGE': Colors.brown,
      // Extended crypto brand colors (added 2025-10-10)
      '1INCH': const Color(0xFF1D4EA3),        // 1Inch 蓝色
      'AAVE': const Color(0xFFB6509E),         // Aave 紫红色
      'AGIX': const Color(0xFF4D4D4D),         // AGIX 深灰色
      'ALGO': const Color(0xFF000000),         // Algorand 黑色
      'PEPE': const Color(0xFF4CAF50),         // Pepe 绿色
      'MKR': const Color(0xFF1AAB9B),          // Maker 青绿色
      'COMP': const Color(0xFF00D395),         // Compound 绿色
      'CRV': const Color(0xFF0052FF),          // Curve 蓝色
      'SUSHI': const Color(0xFFFA52A0),        // Sushi 粉色
      'YFI': const Color(0xFF006AE3),          // YFI 蓝色
      'SNX': const Color(0xFF5FCDF9),          // Synthetix 浅蓝
      'GRT': const Color(0xFF6F4CD2),          // Graph 紫色
      'ENJ': const Color(0xFF7866D5),          // Enjin 紫色
      'MANA': const Color(0xFFFF2D55),         // Decentraland 红色
      'SAND': const Color(0xFF04BBFB),         // Sandbox 蓝色
      'AXS': const Color(0xFF0055D5),          // Axie 蓝色
      'GALA': const Color(0xFF000000),         // Gala 黑色
      'CHZ': const Color(0xFFCD0124),          // Chiliz 红色
      'FIL': const Color(0xFF0090FF),          // Filecoin 蓝色
      'ICP': const Color(0xFF29ABE2),          // ICP 蓝色
      'APE': const Color(0xFF0B57D0),          // ApeCoin 蓝色
      'LRC': const Color(0xFF1C60FF),          // Loopring 蓝色
      'IMX': const Color(0xFF0CAEFF),          // Immutable 蓝色
      'NEAR': const Color(0xFF000000),         // NEAR 黑色
      'FLR': const Color(0xFFE84142),          // Flare 红色
      'HBAR': const Color(0xFF000000),         // Hedera 黑色
      'VET': const Color(0xFF15BDFF),          // VeChain 蓝色
      'QNT': const Color(0xFF000000),          // Quant 黑色
      'ETC': const Color(0xFF328332),          // ETC 绿色
    };

    return cryptoColors[code] ?? Colors.grey;
  }

  List<model.Currency> _getFilteredCryptos() {
    // 🔥 FIX: 使用新的公共方法获取所有加密货币，不受 cryptoEnabled 限制
    // "管理加密货币"页面应该始终显示所有加密货币供选择
    final notifier = ref.watch(currencyProvider.notifier);
    final selectedCurrencies = ref.watch(selectedCurrenciesProvider);

    // 🔥 获取服务器提供的所有加密货币（包括未启用的）
    // 使用新添加的 getAllCryptoCurrencies() 公共方法
    List<model.Currency> cryptoCurrencies = notifier.getAllCryptoCurrencies();

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      cryptoCurrencies = cryptoCurrencies.where((currency) {
        return currency.code.toLowerCase().contains(query) ||
            currency.name.toLowerCase().contains(query) ||
            currency.nameZh.toLowerCase().contains(query) ||
            currency.symbol.toLowerCase().contains(query);
      }).toList();
    }

    // 排序：已选择的排前面，然后按市值排序（这里简单按代码排序）
    cryptoCurrencies.sort((a, b) {
      final aSelected = selectedCurrencies.contains(a);
      final bSelected = selectedCurrencies.contains(b);
      if (aSelected != bSelected) return aSelected ? -1 : 1;

      // 按重要性排序（简化版）
      final priority = ['BTC', 'ETH', 'USDT', 'USDC', 'BNB'];
      final aIndex = priority.indexOf(a.code);
      final bIndex = priority.indexOf(b.code);

      if (aIndex != -1 && bIndex != -1) {
        return aIndex.compareTo(bIndex);
      } else if (aIndex != -1) {
        return -1;
      } else if (bIndex != -1) {
        return 1;
      }

      return a.code.compareTo(b.code);
    });

    return cryptoCurrencies;
  }

  Widget _buildCryptoTile(model.Currency crypto) {
    final isSelected = ref.watch(selectedCurrenciesProvider).contains(crypto);
    final cryptoPrices = ref.watch(cryptoPricesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final price =
        _localPriceOverrides[crypto.code] ?? cryptoPrices[crypto.code] ?? 0.0;
    // 获取汇率对象以访问历史变化数据
    final rates = ref.watch(exchangeRateObjectsProvider);
    final rateObj = rates[crypto.code];

    // 获取或创建价格输入控制器
    if (!_priceControllers.containsKey(crypto.code)) {
      _priceControllers[crypto.code] = TextEditingController(
        text: price > 0 ? price.toStringAsFixed(2) : '',
      );
    }

    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.symmetric(
          horizontal: _compact ? 12 : 16, vertical: _compact ? 2 : 4),
      elevation: 1,
      color: isSelected ? cs.secondaryContainer : cs.surface,
      child: ExpansionTile(
        leading: SizedBox(
          width: _compact ? 40 : 48,
          height: _compact ? 40 : 48,
          child: Center(
            child: _getCryptoIcon(crypto),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // 🔥 显示中文名作为主标题
                      Text(
                        crypto.nameZh,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: _compact ? 6 : 8),
                      // 🔥 显示代码作为badge
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: _compact ? 4 : 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCryptoColor(crypto.code).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          crypto.code,
                          style: TextStyle(
                            fontSize: _compact ? 10 : 11,
                            color: _getCryptoColor(crypto.code),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // 🔥 显示符号和代码作为副标题
                  Text(
                    '${crypto.symbol} · ${crypto.code}',
                    style: TextStyle(
                        fontSize: _compact ? 12 : 13,
                        color: cs.onSurfaceVariant),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (price > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ref
                        .read(currencyProvider.notifier)
                        .formatCurrency(price, baseCurrency.code),
                    style: TextStyle(
                        fontSize: _compact ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SourceBadge(
                          source: _manualPrices[crypto.code] == true
                              ? 'manual'
                              : 'coingecko'),
                    ],
                  ),
                ],
              ),
          ],
        ),
        trailing: Checkbox(
          value: isSelected,
          onChanged: (value) async {
            if (value == true) {
              await ref
                  .read(currencyProvider.notifier)
                  .addSelectedCurrency(crypto.code);
            } else {
              await ref
                  .read(currencyProvider.notifier)
                  .removeSelectedCurrency(crypto.code);
            }
          },
          activeColor: cs.secondary,
        ),
        children: isSelected
            ? [
                Container(
                  padding: EdgeInsets.all(_compact ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up,
                              size: 16, color: _getCryptoColor(crypto.code)),
                          const SizedBox(width: 8),
                          const Text(
                            '价格设置',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (_manualPrices[crypto.code] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '手动设置',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange[800],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _priceControllers[crypto.code],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: '价格 (${baseCurrency.code})',
                                prefixText: baseCurrency.symbol,
                                border: const OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: _compact ? 10 : 12,
                                    vertical: _compact ? 6 : 8),
                              ),
                              onChanged: (value) {
                                if (!mounted) return;
                                setState(() {
                                  _manualPrices[crypto.code] = true;
                                });
                              },
                            ),
                          ),
                          SizedBox(width: _compact ? 8 : 12),
                          Column(
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  // 自动获取最新价格，且清除该币种手动覆盖
                                  if (mounted) {
                                    setState(() {
                                      _manualPrices[crypto.code] = false;
                                      _manualExpiry.remove(crypto.code);
                                      _localPriceOverrides.remove(crypto.code);
                                    });
                                  }
                                  await ref
                                      .read(currencyProvider.notifier)
                                      .clearManualRate(crypto.code);
                                  await _fetchLatestPrices();
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('自动'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.purple,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  // 保存手动价格（带有效期），内部以汇率形式保存（基->币种的汇率 = 1/价格）
                                  final priceText =
                                      _priceControllers[crypto.code]!
                                          .text
                                          .trim();
                                  final price = double.tryParse(priceText);
                                  if (price == null || price <= 0) {
                                    _showSnackBar('请输入有效价格', Colors.red);
                                    return;
                                  }
                                  // 选择有效期（默认次日 UTC 00:00）
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
                                    initialDate: defaultExpiry.toLocal(),
                                    firstDate: DateTime.now().toLocal(),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365))
                                        .toLocal(),
                                  );
                                  if (date == null) return; // 用户取消
                                  final expiryUtc = DateTime.utc(
                                      date.year, date.month, date.day, 0, 0, 0);
                                  // 汇率 = 1 / 价格
                                  final rate = 1.0 / price;
                                  await ref
                                      .read(currencyProvider.notifier)
                                      .upsertManualRate(
                                          crypto.code, rate, expiryUtc);
                                  if (mounted) {
                                    setState(() {
                                      _manualPrices[crypto.code] = true;
                                      _manualExpiry[crypto.code] = expiryUtc;
                                      _localPriceOverrides[crypto.code] = price;
                                      _priceControllers[crypto.code]?.text =
                                          price.toStringAsFixed(2);
                                    });
                                    _showSnackBar('手动价格已保存', Colors.green);
                                  }
                                },
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text('保存'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_manualPrices[crypto.code] == true &&
                          _manualExpiry[crypto.code] != null)
                        Text(
                          '手动价格有效期: ${_manualExpiry[crypto.code]!.toLocal().toString().split(" ").first} 00:00',
                          style:
                              TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      const SizedBox(height: 8),
                      // 24小时变化（实时数据）
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
                              _buildPriceChange(
                                cs,
                                '24h',
                                rateObj.change24h,
                                _compact,
                              ),
                              _buildPriceChange(
                                cs,
                                '7d',
                                rateObj.change7d,
                                _compact,
                              ),
                              _buildPriceChange(
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

  Widget _buildPriceChange(
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
    final filteredCryptos = _getFilteredCryptos();
    final selectedCount = ref
        .watch(selectedCurrenciesProvider)
        .where((c) => ref
            .watch(availableCurrenciesProvider)
            .firstWhere((currency) => currency.code == c.code)
            .isCrypto)
        .length;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('管理加密货币'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0.5,
        actions: [
          IconButton(
            onPressed: _isUpdatingPrices ? null : _fetchLatestPrices,
            icon: _isUpdatingPrices
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '更新价格',
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            color: cs.surface,
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: '搜索加密货币（代码、名称、符号）',
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
            color: cs.tertiaryContainer.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: cs.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '勾选要使用的加密货币，展开可设置价格',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 市场概览（使用真实数据）
          Container(
            color: cs.surface,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMarketStat(
                  cs,
                  '总市值',
                  _globalMarketStats?.formattedMarketCap ?? '\$2.3T',
                  Colors.blue,
                ),
                _buildMarketStat(
                  cs,
                  '24h成交量',
                  _globalMarketStats?.formatted24hVolume ?? '\$98.5B',
                  Colors.green,
                ),
                _buildMarketStat(
                  cs,
                  'BTC占比',
                  _globalMarketStats?.formattedBtcDominance ?? '48.2%',
                  Colors.orange,
                ),
              ],
            ),
          ),

          // 加密货币列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: filteredCryptos.length,
              itemBuilder: (context, index) {
                return _buildCryptoTile(filteredCryptos[index]);
              },
            ),
          ),

          // 底部统计
          Container(
            color: cs.surface,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '已选择 $selectedCount 种加密货币',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
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
        ],
      ),
    );
  }

  Widget _buildMarketStat(ColorScheme cs, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
