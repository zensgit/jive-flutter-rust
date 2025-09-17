import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/currency.dart';
import '../providers/currency_provider.dart';
import 'source_badge.dart';

/// Currency converter widget with auto-fetch rates
class CurrencyConverter extends ConsumerStatefulWidget {
  final String? initialFromCurrency;
  final String? initialToCurrency;
  final double? initialAmount;

  const CurrencyConverter({
    super.key,
    this.initialFromCurrency,
    this.initialToCurrency,
    this.initialAmount,
  });

  @override
  ConsumerState<CurrencyConverter> createState() => _CurrencyConverterState();
}

class _CurrencyConverterState extends ConsumerState<CurrencyConverter> {
  final TextEditingController _amountController = TextEditingController();
  String? _fromCurrency;
  String? _toCurrency;
  double? _convertedAmount;
  bool _isConverting = false;
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    _fromCurrency = widget.initialFromCurrency ?? 'USD';
    _toCurrency = widget.initialToCurrency ?? 'CNY';
    _amountController.text = widget.initialAmount?.toString() ?? '100';

    // Auto-fetch rates and convert on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFetchAndConvert();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _autoFetchAndConvert() async {
    final currencyNotifier = ref.read(currencyProvider.notifier);

    // Check if we need to refresh rates (older than 15 minutes)
    if (currencyNotifier.ratesNeedUpdate) {
      try {
        await currencyNotifier.refreshExchangeRates();
        _lastFetchTime = DateTime.now();
      } catch (e) {
        debugPrint('Failed to fetch exchange rates: $e');
      }
    }

    // Perform initial conversion
    await _performConversion();
  }

  Future<void> _performConversion() async {
    if (_fromCurrency == null || _toCurrency == null) return;

    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) return;

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) return;

    setState(() {
      _isConverting = true;
    });

    try {
      final currencyNotifier = ref.read(currencyProvider.notifier);

      // Auto-fetch rates if stale (older than 15 minutes)
      final now = DateTime.now();
      if (_lastFetchTime == null ||
          now.difference(_lastFetchTime!).inMinutes > 15) {
        await currencyNotifier.refreshExchangeRates();
        _lastFetchTime = now;
      }

      // Perform conversion
      final converted = await currencyNotifier.convertAmount(
        amount,
        _fromCurrency!,
        _toCurrency!,
      );

      if (mounted) {
        setState(() {
          _convertedAmount = converted;
          _isConverting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConverting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('转换失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _swapCurrencies() {
    setState(() {
      final temp = _fromCurrency;
      _fromCurrency = _toCurrency;
      _toCurrency = temp;

      if (_convertedAmount != null) {
        _amountController.text = _convertedAmount!.toStringAsFixed(2);
        _convertedAmount = null;
      }
    });
    _performConversion();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCurrencies = ref.watch(selectedCurrenciesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);

    // Ensure selected currencies are available
    if (!selectedCurrencies.any((c) => c.code == _fromCurrency)) {
      _fromCurrency = baseCurrency.code;
    }
    if (!selectedCurrencies.any((c) => c.code == _toCurrency)) {
      _toCurrency = selectedCurrencies
          .firstWhere(
            (c) => c.code != _fromCurrency,
            orElse: () => baseCurrency,
          )
          .code;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(Icons.currency_exchange, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  '货币转换',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const Spacer(),
                if (_isConverting)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // From currency section
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '从',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildCurrencySelector(_fromCurrency, selectedCurrencies,
                          (currency) {
                        setState(() {
                          _fromCurrency = currency;
                        });
                        _performConversion();
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: IconButton(
                    onPressed: _swapCurrencies,
                    icon: Icon(Icons.swap_horiz, color: Colors.blue[600]),
                    tooltip: '交换货币',
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '到',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildCurrencySelector(_toCurrency, selectedCurrencies,
                          (currency) {
                        setState(() {
                          _toCurrency = currency;
                        });
                        _performConversion();
                      }),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Amount input
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: '金额',
                prefixText: _fromCurrency != null
                    ? _getCurrencySymbol(_fromCurrency)
                    : '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (value) {
                _performConversion();
              },
            ),

            const SizedBox(height: 16),

            // Result display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '转换结果',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _getCurrencySymbol(_toCurrency),
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _convertedAmount?.toStringAsFixed(2) ?? '0.00',
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (_convertedAmount != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Text(
                            '汇率: 1 $_fromCurrency = ${(_convertedAmount! / (double.tryParse(_amountController.text) ?? 1)).toStringAsFixed(4)} $_toCurrency',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[600],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Try to show source if available in provider's cache
                          Builder(
                            builder: (context) {
                              final rates =
                                  ref.watch(exchangeRateObjectsProvider);
                              final source = rates[_toCurrency ?? '']?.source;
                              return source != null
                                  ? SourceBadge(source: source)
                                  : const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Last update time
            if (_lastFetchTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.update, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      '汇率更新于 ${_formatUpdateTime(_lastFetchTime!)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySelector(
    String? selectedCode,
    List<Currency> currencies,
    ValueChanged<String> onChanged,
  ) {
    final selected = currencies.firstWhere(
      (c) => c.code == selectedCode,
      orElse: () => currencies.first,
    );

    return InkWell(
      onTap: () => _showCurrencyPicker(currencies, selectedCode, onChanged),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              selected.flag ?? selected.symbol,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selected.code,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    selected.nameZh,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker(
    List<Currency> currencies,
    String? selectedCode,
    ValueChanged<String> onChanged,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            Text(
              '选择货币',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: currencies.length,
                itemBuilder: (context, index) {
                  final currency = currencies[index];
                  final isSelected = currency.code == selectedCode;

                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.blue[50],
                    leading: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: currency.isCrypto
                            ? Colors.purple[100]
                            : Colors.blue[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Text(
                          currency.flag ?? currency.symbol,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    title: Text(
                      currency.code,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('${currency.name} · ${currency.nameZh}'),
                    trailing: isSelected
                        ? Icon(Icons.check, color: Colors.blue[600])
                        : null,
                    onTap: () {
                      onChanged(currency.code);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrencySymbol(String? code) {
    if (code == null) return '';
    final currencies = ref.read(availableCurrenciesProvider);
    final currency = currencies.firstWhere(
      (c) => c.code == code,
      orElse: () => Currency(
        code: code,
        name: code,
        nameZh: code,
        symbol: code,
        decimalPlaces: 2,
      ),
    );
    return currency.symbol;
  }

  String _formatUpdateTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${diff.inDays}天前';
    }
  }
}
