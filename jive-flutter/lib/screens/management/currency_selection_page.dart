import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/currency.dart' as model;
import '../../providers/currency_provider.dart';
import '../../models/exchange_rate.dart';

/// 货币选择管理页面
class CurrencySelectionPage extends ConsumerStatefulWidget {
  final bool isSelectingBaseCurrency;
  
  const CurrencySelectionPage({
    super.key,
    this.isSelectingBaseCurrency = false,
  });

  @override
  ConsumerState<CurrencySelectionPage> createState() => _CurrencySelectionPageState();
}

class _CurrencySelectionPageState extends ConsumerState<CurrencySelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isUpdatingRates = false;
  final Map<String, TextEditingController> _rateControllers = {};
  final Map<String, bool> _manualRates = {};
  final Map<String, DateTime> _manualExpiry = {};

  @override
  void initState() {
    super.initState();
    // 打开页面时自动获取汇率
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    setState(() {
      _isUpdatingRates = true;
    });
    
    try {
      await ref.read(currencyProvider.notifier).refreshExchangeRates();
      _showSnackBar('汇率已更新', Colors.green);
    } catch (e) {
      _showSnackBar('汇率更新失败', Colors.red);
    } finally {
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
    List<model.Currency> fiatCurrencies = allCurrencies
        .where((c) => !c.isCrypto)
        .toList();
    
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
    final isBaseCurrency = currency.code == ref.watch(baseCurrencyProvider).code;
    final isSelected = ref.watch(selectedCurrenciesProvider).contains(currency);
    final rates = ref.watch(exchangeRateObjectsProvider);
    final rateObj = rates[currency.code];
    final rate = rateObj?.rate ?? 1.0;
    
    // 获取或创建汇率输入控制器
    if (!_rateControllers.containsKey(currency.code)) {
      _rateControllers[currency.code] = TextEditingController(
        text: rate.toStringAsFixed(4),
      );
    }
    
    return GestureDetector(
      onTap: widget.isSelectingBaseCurrency
          ? () => Navigator.pop(context, currency)
          : null,
      child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isBaseCurrency ? 2 : 1,
      color: isBaseCurrency 
          ? Colors.amber[50] 
          : (isSelected ? Colors.green[50] : Colors.white),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isBaseCurrency 
                  ? Colors.amber[300]! 
                  : (isSelected ? Colors.green[300]! : Colors.grey[300]!),
            ),
          ),
          child: Center(
            child: Text(
              currency.flag ?? currency.symbol,
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Row(
          children: [
            if (isBaseCurrency)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '基础',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          currency.symbol,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    currency.nameZh,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        trailing: widget.isSelectingBaseCurrency
            ? (isBaseCurrency 
                ? const Icon(Icons.check_circle, color: Colors.amber)
                : null)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isBaseCurrency && rateObj != null)
                    Text(
                      '1 ${ref.watch(baseCurrencyProvider).code} = ${rate.toStringAsFixed(4)} ${currency.code}',
                      style: const TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  if (!isBaseCurrency && rateObj != null)
                    Text(
                      '来源: ${rateObj.source ?? '未知'}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  const SizedBox(height: 4),
                  Checkbox(
                    value: isSelected,
                    onChanged: isBaseCurrency ? null : (value) async {
                      if (value == true) {
                        await ref.read(currencyProvider.notifier)
                            .addSelectedCurrency(currency.code);
                      } else {
                        await ref.read(currencyProvider.notifier)
                            .removeSelectedCurrency(currency.code);
                      }
                    },
                    activeColor: Colors.green,
                  ),
                ],
              ),
        // ExpansionTile has no onTap; capture base currency selection via GestureDetector
        children: isSelected && !widget.isSelectingBaseCurrency
            ? [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_up, 
                            size: 16, color: Colors.blue),
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
                                color: Colors.orange[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '手动',
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
                              controller: _rateControllers[currency.code],
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText: '1 ${ref.watch(baseCurrencyProvider).code} = ',
                                suffixText: currency.code,
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _manualRates[currency.code] = true;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            children: [
                              TextButton.icon(
                                onPressed: () async {
                                  // 自动获取最新汇率
                                  setState(() {
                                    _manualRates[currency.code] = false;
                                  });
                                  await _fetchLatestRates();
                                },
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('自动'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () async {
                                  // 选择有效期（默认次日 UTC）
                                  final tomorrow = DateTime.now().add(const Duration(days: 1));
                                  DateTime defaultExpiry = DateTime.utc(
                                    tomorrow.year, tomorrow.month, tomorrow.day, 0, 0, 0);
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: _manualExpiry[currency.code]?.toLocal() ?? defaultExpiry.toLocal(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 60)),
                                  );
                                  if (date != null) {
                                    _manualExpiry[currency.code] = DateTime.utc(date.year, date.month, date.day, 0, 0, 0);
                                  } else {
                                    _manualExpiry[currency.code] = defaultExpiry;
                                  }
                                  // 保存手动汇率 + 有效期
                                  final rate = double.tryParse(_rateControllers[currency.code]!.text);
                                  final expiry = _manualExpiry[currency.code] ?? defaultExpiry;
                                  if (rate != null && rate > 0) {
                                    await ref.read(currencyProvider.notifier)
                                        .upsertManualRate(currency.code, rate, expiry);
                                    _showSnackBar('汇率已保存，至 ${expiry.toLocal().toString().split(" ").first} 生效', Colors.green);
                                  } else {
                                    _showSnackBar('请输入有效汇率', Colors.red);
                                  }
                                },
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text('保存(含有效期)'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.green,
                                ),
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
                              const Icon(Icons.schedule, size: 16, color: Colors.orange),
                              const SizedBox(width: 6),
                              Text(
                                '手动汇率有效期: ${_manualExpiry[currency.code]!.toLocal().toString().split(" ").first} 00:00',
                                style: const TextStyle(fontSize: 12, color: Colors.orange),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCurrencies = _getFilteredCurrencies();
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.isSelectingBaseCurrency ? '选择基础货币' : '管理法定货币',
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
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
            color: Colors.blue[50],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.isSelectingBaseCurrency
                        ? '点击选择要设为基础货币的货币'
                        : '勾选要使用的货币，展开可设置汇率',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 货币列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: filteredCurrencies.length,
              itemBuilder: (context, index) {
                return _buildCurrencyTile(filteredCurrencies[index]);
              },
            ),
          ),
          
          // 底部统计
          if (!widget.isSelectingBaseCurrency)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已选择 ${ref.watch(selectedCurrenciesProvider).length} 种货币',
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
}
