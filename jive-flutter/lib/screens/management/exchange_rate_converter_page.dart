import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/currency.dart' as model;
import '../../providers/currency_provider.dart';

/// 汇率转换器页面
class ExchangeRateConverterPage extends ConsumerStatefulWidget {
  const ExchangeRateConverterPage({super.key});

  @override
  ConsumerState<ExchangeRateConverterPage> createState() =>
      _ExchangeRateConverterPageState();
}

class _ExchangeRateConverterPageState
    extends ConsumerState<ExchangeRateConverterPage> {
  final TextEditingController _amountController = TextEditingController();
  model.Currency? _fromCurrency;
  model.Currency? _toCurrency;
  double _convertedAmount = 0.0;
  bool _isCalculating = false;

  // 历史记录
  final List<ConversionHistory> _history = [];

  @override
  void initState() {
    super.initState();
    // 默认设置基础货币为源货币
    _fromCurrency = ref.read(baseCurrencyProvider);
    _amountController.text = '100';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _swapCurrencies() {
    if (_fromCurrency != null && _toCurrency != null) {
      setState(() {
        final temp = _fromCurrency;
        _fromCurrency = _toCurrency;
        _toCurrency = temp;
        _calculateConversion();
      });
    }
  }

  void _calculateConversion() {
    if (_fromCurrency == null || _toCurrency == null) return;

    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      setState(() {
        _convertedAmount = 0;
      });
      return;
    }

    setState(() {
      _isCalculating = true;
    });

    // 获取汇率
    final exchangeRates = ref.read(exchangeRatesProvider);
    final cryptoPrices = ref.read(cryptoPricesProvider);
    final baseCurrency = ref.read(baseCurrencyProvider);

    double fromRate = 1.0;
    double toRate = 1.0;

    // 获取源货币汇率
    if (_fromCurrency!.code != baseCurrency.code) {
      if (_fromCurrency!.isCrypto) {
        fromRate = cryptoPrices[_fromCurrency!.code] ?? 1.0;
      } else {
        fromRate = exchangeRates[_fromCurrency!.code] ?? 1.0;
      }
    }

    // 获取目标货币汇率
    if (_toCurrency!.code != baseCurrency.code) {
      if (_toCurrency!.isCrypto) {
        toRate = cryptoPrices[_toCurrency!.code] ?? 1.0;
      } else {
        toRate = exchangeRates[_toCurrency!.code] ?? 1.0;
      }
    }

    // 计算转换金额
    // 先转换到基础货币，再转换到目标货币
    final baseAmount = _fromCurrency!.isCrypto
        ? amount * fromRate // 加密货币：金额 * 价格
        : amount / fromRate; // 法定货币：金额 / 汇率

    final converted = _toCurrency!.isCrypto
        ? baseAmount / toRate // 转换到加密货币：基础金额 / 价格
        : baseAmount * toRate; // 转换到法定货币：基础金额 * 汇率

    setState(() {
      _convertedAmount = converted;
      _isCalculating = false;

      // 添加到历史记录
      if (_history.length >= 10) {
        _history.removeLast();
      }
      _history.insert(
          0,
          ConversionHistory(
            from: _fromCurrency!,
            to: _toCurrency!,
            amount: amount,
            result: converted,
            rate: converted / amount,
            timestamp: DateTime.now(),
          ));
    });
  }

  Widget _buildCurrencySelector({
    required String label,
    required model.Currency? selected,
    required Function(model.Currency) onSelect,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final result = await _showCurrencyPicker(selected);
            if (result != null) {
              onSelect(result);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: selected != null
                ? Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: selected.isCrypto
                              ? Colors.purple[50]
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            selected.flag ?? selected.symbol,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selected.code,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              selected.nameZh,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                    ],
                  )
                : Row(
                    children: [
                      Icon(Icons.add_circle_outline, color: Colors.grey[400]),
                      const SizedBox(width: 12),
                      Text(
                        '选择货币',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<model.Currency?> _showCurrencyPicker(model.Currency? current) async {
    return showModalBottomSheet<model.Currency>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _CurrencyPickerSheet(
        currentCurrency: current,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('汇率转换器'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 转换卡片
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 金额输入
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: '金额',
                      labelStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixText: _fromCurrency?.symbol,
                    ),
                    onChanged: (value) {
                      _calculateConversion();
                    },
                  ),
                  const SizedBox(height: 20),

                  // 源货币选择
                  _buildCurrencySelector(
                    label: '从',
                    selected: _fromCurrency,
                    onSelect: (currency) {
                      setState(() {
                        _fromCurrency = currency;
                        _calculateConversion();
                      });
                    },
                  ),

                  // 交换按钮
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: IconButton(
                      onPressed: _swapCurrencies,
                      icon: const Icon(Icons.swap_vert, size: 28),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue,
                      ),
                    ),
                  ),

                  // 目标货币选择
                  _buildCurrencySelector(
                    label: '到',
                    selected: _toCurrency,
                    onSelect: (currency) {
                      setState(() {
                        _toCurrency = currency;
                        _calculateConversion();
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // 转换结果
                  if (_toCurrency != null && _convertedAmount > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${_toCurrency!.symbol}${_convertedAmount.toStringAsFixed(_toCurrency!.decimalPlaces)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '1 ${_fromCurrency!.code} = ${(_convertedAmount / (double.tryParse(_amountController.text) ?? 1)).toStringAsFixed(4)} ${_toCurrency!.code}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // 历史记录
            if (_history.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.history, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      '转换历史',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...List.generate(
                _history.length,
                (index) => _buildHistoryItem(_history[index]),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem(ConversionHistory history) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      ref
                          .read(currencyProvider.notifier)
                          .formatCurrency(history.amount, history.from.code),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const Icon(Icons.arrow_forward, size: 16),
                    Text(
                      ref
                          .read(currencyProvider.notifier)
                          .formatCurrency(history.result, history.to.code),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${history.from.code} → ${history.to.code} | 汇率: ${history.rate.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTime(history.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}小时前';
    } else {
      return '${diff.inDays}天前';
    }
  }
}

// 转换历史记录模型
class ConversionHistory {
  final model.Currency from;
  final model.Currency to;
  final double amount;
  final double result;
  final double rate;
  final DateTime timestamp;

  ConversionHistory({
    required this.from,
    required this.to,
    required this.amount,
    required this.result,
    required this.rate,
    required this.timestamp,
  });
}

// 货币选择底部弹窗
class _CurrencyPickerSheet extends ConsumerStatefulWidget {
  final model.Currency? currentCurrency;

  const _CurrencyPickerSheet({this.currentCurrency});

  @override
  ConsumerState<_CurrencyPickerSheet> createState() =>
      _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends ConsumerState<_CurrencyPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<model.Currency> _getFilteredCurrencies() {
    final selectedCurrencies = ref.watch(selectedCurrenciesProvider);
    final availableCurrencies = ref.watch(availableCurrenciesProvider);

    // 只显示已选择的货币
    List<model.Currency> currencies = availableCurrencies
        .where((c) => selectedCurrencies.contains(c))
        .toList();

    // 搜索过滤
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      currencies = currencies.where((currency) {
        return currency.code.toLowerCase().contains(query) ||
            currency.name.toLowerCase().contains(query) ||
            currency.nameZh.toLowerCase().contains(query) ||
            currency.symbol.toLowerCase().contains(query);
      }).toList();
    }

    // 排序
    currencies.sort((a, b) {
      // 当前选中的排第一
      if (widget.currentCurrency != null) {
        if (a.code == widget.currentCurrency!.code) return -1;
        if (b.code == widget.currentCurrency!.code) return 1;
      }

      // 加密货币和法定货币分开
      if (a.isCrypto != b.isCrypto) {
        return a.isCrypto ? 1 : -1;
      }

      return a.code.compareTo(b.code);
    });

    return currencies;
  }

  @override
  Widget build(BuildContext context) {
    final currencies = _getFilteredCurrencies();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  '选择货币',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          // 搜索框
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: '搜索货币',
                prefixIcon: const Icon(Icons.search),
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

          // 货币列表
          Expanded(
            child: ListView.builder(
              itemCount: currencies.length,
              itemBuilder: (context, index) {
                final currency = currencies[index];
                final isSelected =
                    widget.currentCurrency?.code == currency.code;

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: currency.isCrypto
                          ? Colors.purple[50]
                          : Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        currency.flag ?? currency.symbol,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  title: Text(
                    '${currency.code} (${currency.symbol})',
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(currency.nameZh),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    Navigator.pop(context, currency);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
