import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/currency_provider.dart';

/// Simple Currency Converter Screen
class CurrencyConverterScreen extends ConsumerStatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  ConsumerState<CurrencyConverterScreen> createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState
    extends ConsumerState<CurrencyConverterScreen> {
  final TextEditingController _amountController =
      TextEditingController(text: '100');
  String _fromCurrency = 'USD';
  String _toCurrency = 'CNY';
  double? _result;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-refresh rates when opening page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAndConvert();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _refreshAndConvert() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Refresh exchange rates
      await ref.read(currencyProvider.notifier).refreshExchangeRates();

      // Perform conversion
      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount > 0) {
        final result = await ref.read(currencyProvider.notifier).convertAmount(
              amount,
              _fromCurrency,
              _toCurrency,
            );
        setState(() {
          _result = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('转换失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final formatter = ref.read(currencyProvider.notifier);
    final selectedCurrencies = ref.watch(selectedCurrenciesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('汇率转换'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Amount input
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                border: OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              onChanged: (_) => _refreshAndConvert(),
            ),

            const SizedBox(height: 20),

            // From Currency
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('从货币:'),
                  DropdownButton<String>(
                    value: _fromCurrency,
                    underline: const SizedBox(),
                    items: selectedCurrencies.map((currency) {
                      return DropdownMenuItem(
                        value: currency.code,
                        child: const Text('${currency.code} - ${currency.nameZh}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _fromCurrency = value;
                        });
                        _refreshAndConvert();
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Swap button
            IconButton(
              icon: const Icon(Icons.swap_vert, size: 32),
              onPressed: () {
                setState(() {
                  final temp = _fromCurrency;
                  _fromCurrency = _toCurrency;
                  _toCurrency = temp;
                });
                _refreshAndConvert();
              },
            ),

            const SizedBox(height: 10),

            // To Currency
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('到货币:'),
                  DropdownButton<String>(
                    value: _toCurrency,
                    underline: const SizedBox(),
                    items: selectedCurrencies.map((currency) {
                      return DropdownMenuItem(
                        value: currency.code,
                        child: const Text('${currency.code} - ${currency.nameZh}'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _toCurrency = value;
                        });
                        _refreshAndConvert();
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Result
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_result != null)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        formatter.formatCurrency(
                            double.tryParse(_amountController.text) ?? 0,
                            _fromCurrency),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 10),
                      const Icon(Icons.arrow_downward, size: 24),
                      const SizedBox(height: 10),
                      const Text(
                        formatter.formatCurrency(_result ?? 0, _toCurrency),
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '汇率: 1 $_fromCurrency = ${(_result! / (double.tryParse(_amountController.text) ?? 1)).toStringAsFixed(4)} $_toCurrency',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Refresh button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _refreshAndConvert,
              icon: const Icon(Icons.refresh),
              label: const Text('刷新汇率'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            ),

            const SizedBox(height: 10),

            // Info
            const Text(
              '汇率数据实时更新',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
