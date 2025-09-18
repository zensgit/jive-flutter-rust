import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/currency_provider.dart';
import '../../providers/currency_provider.dart' show currencyCatalogMetaProvider; // explicit meta provider

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
  final TextEditingController _amountController =
      TextEditingController(text: '100');

  String _fmt(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  String _buildSyncLine(catalogMeta) {
    final sync = catalogMeta.lastSyncAt != null ? _fmt(catalogMeta.lastSyncAt) : '—';
    final chk = catalogMeta.lastCheckedAt != null ? _fmt(catalogMeta.lastCheckedAt) : '—';
    return '目录: 上次成功 $sync / 最近检查 $chk';
  }

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
    final catalogMeta = ref.watch(currencyCatalogMetaProvider);

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
            // Catalog fallback indicator (uses new meta provider)
            if (catalogMeta.usingFallback)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  border: Border.all(color: Colors.orange.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        catalogMeta.lastError != null
                            ? '使用本地内置货币列表：${catalogMeta.lastError}'
                            : '使用本地内置货币列表（服务器未加载）',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.orange[900]),
                      ),
                    ),
                    TextButton(
                      onPressed: _isRefreshing
                          ? null
                          : () => currencyNotifier.refreshCatalog(),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            // Last sync info
            if (catalogMeta.lastSyncAt != null || catalogMeta.lastCheckedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _buildSyncLine(catalogMeta),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: _isRefreshing
                          ? null
                          : () => currencyNotifier.refreshCatalog(),
                      child: const Text('刷新目录'),
                    )
                  ],
                ),
              ),
            // Update status
            if (_isRefreshing) const LinearProgressIndicator(),

            const SizedBox(height: 16),

            // Amount input
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '金额',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
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
