import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/currency_provider.dart';

/// Exchange Rate Screen - Auto-refreshes when opened
class ExchangeRateScreen extends ConsumerStatefulWidget {
  const ExchangeRateScreen({super.key});

  @override
  ConsumerState<ExchangeRateScreen> createState() => _ExchangeRateScreenState();
}

class _ExchangeRateScreenState extends ConsumerState<ExchangeRateScreen> {
  bool _isRefreshing = false;
  String _fromCurrency = 'USD';
  String _toCurrency = 'CNY';
  double _amount = 100.0;
  double? _convertedAmount;
  final TextEditingController _amountController = TextEditingController(text: '100');
  
  @override
  void initState() {
    super.initState();
    _amountController.text = _amount.toString();
    // Auto-refresh exchange rates when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshRates();
    });
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
  
  Future<void> _refreshRates() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // Refresh exchange rates from API
      await ref.read(currencyProvider.notifier).refreshExchangeRates();
      
      // Update conversion
      await _performConversion();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('汇率已更新'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更新汇率失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }
  
  Future<void> _performConversion() async {
    final result = await ref.read(currencyProvider.notifier).convertAmount(
      _amount,
      _fromCurrency,
      _toCurrency,
    );
    
    if (mounted) {
      setState(() {
        _convertedAmount = result;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final currencyNotifier = ref.watch(currencyProvider.notifier);
    final availableCurrencies = currencyNotifier.getAvailableCurrencies();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('汇率转换'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshRates,
            tooltip: '刷新汇率',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Update status
            if (_isRefreshing)
              const LinearProgressIndicator(),
            
            const SizedBox(height: 16),
            
            // Amount input
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '金额',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) {
                setState(() {
                  _amount = double.tryParse(value) ?? 0.0;
                });
                _performConversion();
              },
            ),
            
            const SizedBox(height: 16),
            
            // From currency
            DropdownButtonFormField<String>(
              value: _fromCurrency,
              decoration: const InputDecoration(
                labelText: '从',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_exchange),
              ),
              items: availableCurrencies.map((currency) {
                return DropdownMenuItem(
                  value: currency.code,
                  child: Row(
                    children: [
                      Text(currency.symbol),
                      const SizedBox(width: 8),
                      Text(currency.code),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currency.name,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _fromCurrency = value;
                  });
                  _performConversion();
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Swap button
            Center(
              child: IconButton(
                icon: const Icon(Icons.swap_vert, size: 32),
                onPressed: () {
                  setState(() {
                    final temp = _fromCurrency;
                    _fromCurrency = _toCurrency;
                    _toCurrency = temp;
                  });
                  _performConversion();
                },
                tooltip: '交换货币',
              ),
            ),
            
            const SizedBox(height: 16),
            
            // To currency
            DropdownButtonFormField<String>(
              value: _toCurrency,
              decoration: const InputDecoration(
                labelText: '到',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_exchange),
              ),
              items: availableCurrencies.map((currency) {
                return DropdownMenuItem(
                  value: currency.code,
                  child: Row(
                    children: [
                      Text(currency.symbol),
                      const SizedBox(width: 8),
                      Text(currency.code),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currency.name,
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _toCurrency = value;
                  });
                  _performConversion();
                }
              },
            ),
            
            const SizedBox(height: 32),
            
            // Result
            if (_convertedAmount != null)
              Card(
                color: Theme.of(context).primaryColor.withAlpha(25),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        '转换结果',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_amount.toStringAsFixed(2)} $_fromCurrency',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Icon(Icons.arrow_downward),
                      Text(
                        '${_convertedAmount!.toStringAsFixed(2)} $_toCurrency',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '汇率: 1 $_fromCurrency = ${(_convertedAmount! / _amount).toStringAsFixed(4)} $_toCurrency',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            
            const Spacer(),
            
            // Info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '汇率会在您打开此页面时自动更新',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}