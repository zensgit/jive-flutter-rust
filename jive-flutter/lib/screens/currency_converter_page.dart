import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/widgets/currency_converter.dart';
import 'package:jive_money/providers/currency_provider.dart';
import 'package:jive_money/models/currency.dart';
import 'package:jive_money/widgets/source_badge.dart';

/// Standalone currency converter page
class CurrencyConverterPage extends ConsumerStatefulWidget {
  const CurrencyConverterPage({super.key});

  @override
  ConsumerState<CurrencyConverterPage> createState() =>
      _CurrencyConverterPageState();
}

class _CurrencyConverterPageState extends ConsumerState<CurrencyConverterPage> {
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    // Auto-fetch rates on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeRates();
    });
  }

  Future<void> _initializeRates() async {
    if (_isInitializing) return;

    setState(() {
      _isInitializing = true;
    });

    try {
      final currencyNotifier = ref.read(currencyProvider.notifier);

      // Only fetch if rates are stale
      if (currencyNotifier.ratesNeedUpdate) {
        await currencyNotifier.refreshExchangeRates();
      }
    } catch (e) {
      debugPrint('Failed to initialize exchange rates: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyPrefs = ref.watch(currencyProvider);
    final selectedCurrencies = ref.watch(selectedCurrenciesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.black,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '货币转换',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  if (_isInitializing)
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue[600]!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '初始化...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Main converter
                    CurrencyConverter(
                      initialFromCurrency: baseCurrency.code,
                      initialToCurrency: selectedCurrencies.length > 1
                          ? selectedCurrencies
                              .firstWhere(
                                (c) => c.code != baseCurrency.code,
                                orElse: () => selectedCurrencies.first,
                              )
                              .code
                          : 'USD',
                      initialAmount: 100,
                    ),

                    const SizedBox(height: 24),

                    // Quick stats
                    if (selectedCurrencies.isNotEmpty)
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.trending_up,
                                      color: Colors.green[700], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    '今日汇率',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...selectedCurrencies
                                  .where((c) => c.code != baseCurrency.code)
                                  .take(5)
                                  .map((currency) =>
                                      _buildRateItem(currency, baseCurrency)),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // Currency settings shortcut
                    Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.settings, color: Colors.blue[700]),
                        ),
                        title: const Text('货币设置'),
                        subtitle: Text(
                          '已选择 ${selectedCurrencies.length} 种货币 · ${currencyPrefs.multiCurrencyEnabled ? '多币种模式' : '单币种模式'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pushNamed(context, '/settings/currency');
                        },
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

  Widget _buildRateItem(Currency currency, Currency baseCurrency) {
    final rates = ref.watch(exchangeRateObjectsProvider);
    final rateObj = rates[currency.code];
    return FutureBuilder<double?>(
      future: ref
          .read(currencyProvider.notifier)
          .convertAmount(1.0, baseCurrency.code, currency.code),
      builder: (context, snapshot) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color:
                      currency.isCrypto ? Colors.purple[50] : Colors.blue[50],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    currency.flag ?? currency.symbol,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currency.code,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      currency.nameZh,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              if (snapshot.hasData)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currency.formatAmount(snapshot.data!),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '1 ${baseCurrency.code}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (rateObj != null)
                          SourceBadge(source: rateObj.source),
                      ],
                    ),
                  ],
                )
              else if (snapshot.connectionState == ConnectionState.waiting)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                  ),
                )
              else
                Text(
                  '--',
                  style: TextStyle(color: Colors.grey[500]),
                ),
            ],
          ),
        );
      },
    );
  }
}
