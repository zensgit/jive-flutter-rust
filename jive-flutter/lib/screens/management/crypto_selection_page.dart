import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/currency.dart' as model;
import '../../providers/currency_provider.dart';
import '../../widgets/source_badge.dart';
import '../../providers/settings_provider.dart';

/// 加密货币选择管理页面
class CryptoSelectionPage extends ConsumerStatefulWidget {
  const CryptoSelectionPage({super.key});

  @override
  ConsumerState<CryptoSelectionPage> createState() => _CryptoSelectionPageState();
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final density = ref.read(settingsProvider).listDensity;
      setState(() { _compact = density == 'compact'; });
    });
    // 打开页面时自动获取加密货币价格
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchLatestPrices();
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

  // 获取加密货币图标
  Widget _getCryptoIcon(String code) {
    // 这里可以根据不同的加密货币返回不同的图标
    final Map<String, IconData> cryptoIcons = {
      'BTC': Icons.currency_bitcoin,
      'ETH': Icons.account_balance_wallet,
      'USDT': Icons.attach_money,
      'USDC': Icons.monetization_on,
      'BNB': Icons.local_fire_department,
      'XRP': Icons.water_drop,
      'ADA': Icons.eco,
      'SOL': Icons.wb_sunny,
      'DOT': Icons.blur_circular,
      'DOGE': Icons.pets,
    };
    
    return Icon(
      cryptoIcons[code] ?? Icons.currency_bitcoin,
      size: 24,
      color: _getCryptoColor(code),
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
    };
    
    return cryptoColors[code] ?? Colors.grey;
  }

  List<model.Currency> _getFilteredCryptos() {
    final allCurrencies = ref.watch(availableCurrenciesProvider);
    final selectedCurrencies = ref.watch(selectedCurrenciesProvider);
    
    // 过滤加密货币
    List<model.Currency> cryptoCurrencies = allCurrencies
        .where((c) => c.isCrypto)
        .toList();
    
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
    final price = _localPriceOverrides[crypto.code] ?? cryptoPrices[crypto.code] ?? 0.0;
    
    // 获取或创建价格输入控制器
    if (!_priceControllers.containsKey(crypto.code)) {
      _priceControllers[crypto.code] = TextEditingController(
        text: price > 0 ? price.toStringAsFixed(2) : '',
      );
    }
    
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.symmetric(horizontal: _compact ? 12 : 16, vertical: _compact ? 2 : 4),
      elevation: 1,
      color: isSelected ? cs.secondaryContainer : cs.surface,
      child: ExpansionTile(
        leading: Container(
          width: _compact ? 40 : 48,
          height: _compact ? 40 : 48,
          decoration: BoxDecoration(
            color: _getCryptoColor(crypto.code).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? _getCryptoColor(crypto.code) 
                  : cs.outlineVariant,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.currency_bitcoin,
              // use onSurface in dark to avoid low contrast
              color: Theme.of(context).brightness == Brightness.dark
                  ? cs.onSurface
                  : _getCryptoColor(crypto.code),
              size: _compact ? 20 : 22,
            ),
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
                      Text(
                        crypto.code,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: _compact ? 6 : 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: _compact ? 4 : 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getCryptoColor(crypto.code).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          crypto.symbol,
                          style: TextStyle(
                            fontSize: _compact ? 10 : 11,
                            color: _getCryptoColor(crypto.code),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    crypto.nameZh,
                    style: TextStyle(fontSize: _compact ? 12 : 13, color: cs.onSurfaceVariant),
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
                    ref.read(currencyProvider.notifier).formatCurrency(price, baseCurrency.code),
                    style: TextStyle(fontSize: _compact ? 13 : 14, fontWeight: FontWeight.w600, color: cs.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SourceBadge(source: _manualPrices[crypto.code] == true ? 'manual' : 'coingecko'),
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
              await ref.read(currencyProvider.notifier)
                  .addSelectedCurrency(crypto.code);
            } else {
              await ref.read(currencyProvider.notifier)
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
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: '价格 (${baseCurrency.code})',
                                prefixText: baseCurrency.symbol,
                                border: const OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: _compact ? 10 : 12, vertical: _compact ? 6 : 8),
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
                                  await ref.read(currencyProvider.notifier)
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
                                  final priceText = _priceControllers[crypto.code]!.text.trim();
                                  final price = double.tryParse(priceText);
                                  if (price == null || price <= 0) {
                                    _showSnackBar('请输入有效价格', Colors.red);
                                    return;
                                  }
                                  // 选择有效期（默认次日 UTC 00:00）
                                  final tomorrow = DateTime.now().add(const Duration(days: 1));
                                  DateTime defaultExpiry = DateTime.utc(
                                    tomorrow.year, tomorrow.month, tomorrow.day, 0, 0, 0);
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: defaultExpiry.toLocal(),
                                    firstDate: DateTime.now().toLocal(),
                                    lastDate: DateTime.now().add(const Duration(days: 365)).toLocal(),
                                  );
                                  if (date == null) return; // 用户取消
                                  final expiryUtc = DateTime.utc(date.year, date.month, date.day, 0, 0, 0);
                                  // 汇率 = 1 / 价格
                                  final rate = 1.0 / price;
                                  await ref.read(currencyProvider.notifier)
                                      .upsertManualRate(crypto.code, rate, expiryUtc);
                                  if (mounted) {
                                    setState(() {
                                      _manualPrices[crypto.code] = true;
                                      _manualExpiry[crypto.code] = expiryUtc;
                                      _localPriceOverrides[crypto.code] = price;
                                      _priceControllers[crypto.code]?.text = price.toStringAsFixed(2);
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
                      if (_manualPrices[crypto.code] == true && _manualExpiry[crypto.code] != null)
                        Text(
                          '手动价格有效期: ${_manualExpiry[crypto.code]!.toLocal().toString().split(" ").first} 00:00',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      const SizedBox(height: 8),
                      // 24小时变化（模拟数据）
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildPriceChange('24h', '+5.32%', Colors.green),
                            _buildPriceChange('7d', '-2.18%', Colors.red),
                            _buildPriceChange('30d', '+12.45%', Colors.green),
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
  
  Widget _buildPriceChange(String period, String change, Color color) {
    return Column(
      children: [
        Text(
          period,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          change,
          style: TextStyle(
            fontSize: 12,
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
    final selectedCount = ref.watch(selectedCurrenciesProvider)
        .where((c) => ref.watch(availableCurrenciesProvider)
            .firstWhere((currency) => currency.code == c.code)
            .isCrypto)
        .length;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('管理加密货币'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
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
            color: Colors.white,
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
            color: Colors.purple[50],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '勾选要使用的加密货币，展开可设置价格',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.purple[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 市场概览（可选）
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMarketStat('总市值', '\$2.3T', Colors.blue),
                _buildMarketStat('24h成交量', '\$98.5B', Colors.green),
                _buildMarketStat('BTC占比', '48.2%', Colors.orange),
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
            color: Colors.white,
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
                  icon: const Icon(Icons.check),
                  label: const Text('完成'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMarketStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
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
