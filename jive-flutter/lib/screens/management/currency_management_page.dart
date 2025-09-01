import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/currency.dart' as model;
import '../../providers/currency_provider.dart';

/// 货币管理页面 - 基于maybe-main设计
class CurrencyManagementPage extends ConsumerStatefulWidget {
  const CurrencyManagementPage({super.key});

  @override
  ConsumerState<CurrencyManagementPage> createState() => _CurrencyManagementPageState();
}

class _CurrencyManagementPageState extends ConsumerState<CurrencyManagementPage> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingRates = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Auto-fetch exchange rates when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFetchExchangeRates();
    });
  }

  Future<void> _autoFetchExchangeRates() async {
    final currencyNotifier = ref.read(currencyProvider.notifier);
    
    // Only fetch if rates need update (older than 15 minutes)
    if (currencyNotifier.ratesNeedUpdate && !_isLoadingRates) {
      setState(() {
        _isLoadingRates = true;
      });
      
      try {
        await currencyNotifier.refreshExchangeRates();
        if (mounted) {
          // Show subtle success indicator
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('汇率已更新'),
                ],
              ),
              backgroundColor: Colors.green[600],
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } catch (e) {
        // Silently fail for auto-fetch, user can manually retry
        print('Auto-fetch exchange rates failed: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingRates = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencyPrefs = ref.watch(currencyProvider);
    final currencyNotifier = ref.watch(currencyProvider.notifier);
    final isCryptoSupported = ref.watch(isCryptoSupportedProvider);
    final availableCurrencies = ref.watch(availableCurrenciesProvider);
    final selectedCurrencies = ref.watch(selectedCurrenciesProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);

    // Filter currencies based on search
    List<model.Currency> filteredFiatCurrencies = [];
    List<model.Currency> filteredCryptoCurrencies = [];

    for (final currency in availableCurrencies) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!currency.code.toLowerCase().contains(query) &&
            !currency.name.toLowerCase().contains(query) &&
            !currency.nameZh.toLowerCase().contains(query)) {
          continue;
        }
      }
      
      if (currency.isCrypto) {
        filteredCryptoCurrencies.add(currency);
      } else {
        filteredFiatCurrencies.add(currency);
      }
    }

    // Sort: selected first, then alphabetical
    filteredFiatCurrencies.sort((a, b) {
      final aSelected = currencyPrefs.selectedCurrencies.contains(a.code);
      final bSelected = currencyPrefs.selectedCurrencies.contains(b.code);
      if (aSelected != bSelected) return aSelected ? -1 : 1;
      return a.code.compareTo(b.code);
    });

    filteredCryptoCurrencies.sort((a, b) {
      final aSelected = currencyPrefs.selectedCurrencies.contains(a.code);
      final bSelected = currencyPrefs.selectedCurrencies.contains(b.code);
      if (aSelected != bSelected) return aSelected ? -1 : 1;
      return a.code.compareTo(b.code);
    });

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Custom header with loading indicator
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
                    '货币管理',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  if (_isLoadingRates)
                    Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '更新中...',
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

            // Settings section
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Multi-currency toggle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.language, color: Colors.blue[700], size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '多币种支持',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue[900],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currencyPrefs.multiCurrencyEnabled
                                    ? '已开启 - 可选择多种货币'
                                    : '已关闭 - 只能选择一种货币',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: currencyPrefs.multiCurrencyEnabled,
                          onChanged: (value) async {
                            await currencyNotifier.setMultiCurrencyMode(value);
                          },
                          activeThumbColor: Colors.blue,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Crypto toggle
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCryptoSupported ? Colors.purple[50] : Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCryptoSupported ? Colors.purple[200]! : Colors.red[200]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.currency_bitcoin,
                          color: isCryptoSupported ? Colors.purple[700] : Colors.red[700],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '加密货币支持',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isCryptoSupported ? Colors.purple[900] : Colors.red[900],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isCryptoSupported
                                    ? (currencyPrefs.cryptoEnabled
                                        ? '已开启 - 可管理加密货币'
                                        : '已关闭 - 不显示加密货币')
                                    : '当前地区不支持',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isCryptoSupported 
                                      ? Colors.purple[700] 
                                      : Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCryptoSupported)
                          Switch(
                            value: currencyPrefs.cryptoEnabled,
                            onChanged: (value) async {
                              await currencyNotifier.setCryptoMode(value);
                            },
                            activeThumbColor: Colors.purple,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Base currency selector
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '本位币设置',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.amber[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Base currency dropdown
                        InkWell(
                          onTap: () => _showBaseCurrencySelector(),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber[300]!),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  baseCurrency.flag ?? baseCurrency.symbol,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${baseCurrency.code} (${baseCurrency.symbol})',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        baseCurrency.nameZh,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down, color: Colors.amber[700]),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Display format options
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.format_list_bulleted, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '货币显示格式',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.green[900],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: currencyPrefs.showCurrencyCode,
                                    onChanged: (value) async {
                                      final showCode = value ?? true;
                                      final showSymbol = currencyPrefs.showCurrencySymbol;
                                      if (!showCode && !showSymbol) {
                                        // At least one must be selected
                                        return;
                                      }
                                      await currencyNotifier.setDisplayFormat(showCode, showSymbol);
                                    },
                                    activeColor: Colors.green,
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final showCode = !currencyPrefs.showCurrencyCode;
                                      final showSymbol = currencyPrefs.showCurrencySymbol;
                                      if (!showCode && !showSymbol) {
                                        return;
                                      }
                                      await currencyNotifier.setDisplayFormat(showCode, showSymbol);
                                    },
                                    child: Text(
                                      '显示货币代码',
                                      style: TextStyle(fontSize: 13, color: Colors.green[800]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: currencyPrefs.showCurrencySymbol,
                                    onChanged: (value) async {
                                      final showSymbol = value ?? false;
                                      final showCode = currencyPrefs.showCurrencyCode;
                                      if (!showCode && !showSymbol) {
                                        // At least one must be selected
                                        return;
                                      }
                                      await currencyNotifier.setDisplayFormat(showCode, showSymbol);
                                    },
                                    activeColor: Colors.green,
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      final showSymbol = !currencyPrefs.showCurrencySymbol;
                                      final showCode = currencyPrefs.showCurrencyCode;
                                      if (!showCode && !showSymbol) {
                                        return;
                                      }
                                      await currencyNotifier.setDisplayFormat(showCode, showSymbol);
                                    },
                                    child: Text(
                                      '显示货币符号',
                                      style: TextStyle(fontSize: 13, color: Colors.green[800]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _getDisplayFormatExample(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Search bar with tips
            Container(
              color: Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: '搜索货币代码或名称...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
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
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  // 操作提示
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border(
                        top: BorderSide(color: Colors.blue[100]!),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currencyPrefs.multiCurrencyEnabled
                                ? '提示：单击选择货币，长按或点击星标设为本位币'
                                : '提示：选择货币将自动设为本位币',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Tab bar (only show if crypto is enabled)
            if (currencyPrefs.cryptoEnabled)
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: Theme.of(context).primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Theme.of(context).primaryColor,
                  tabs: const [
                    Tab(text: '法定货币'),
                    Tab(text: '加密货币'),
                  ],
                ),
              ),

            // Currency list
            Expanded(
              child: currencyPrefs.cryptoEnabled
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCurrencyList(filteredFiatCurrencies, false),
                        _buildCurrencyList(filteredCryptoCurrencies, true),
                      ],
                    )
                  : _buildCurrencyList(filteredFiatCurrencies, false),
            ),

            // Bottom status bar with exchange rate update button
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green[600], size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '已选择 ${currencyPrefs.selectedCurrencies.length} 种货币',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('正在更新汇率...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                      
                      try {
                        await currencyNotifier.refreshExchangeRates();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('汇率已更新'),
                              backgroundColor: Colors.green[600],
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('汇率更新失败，使用缓存数据'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('更新汇率'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[700],
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

  Widget _buildCurrencyList(List<model.Currency> currencies, bool isCrypto) {
    final currencyPrefs = ref.watch(currencyProvider);
    final currencyNotifier = ref.watch(currencyProvider.notifier);
    final baseCurrency = ref.watch(baseCurrencyProvider);

    if (currencies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCrypto ? Icons.currency_bitcoin : Icons.attach_money,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? '未找到匹配的货币'
                  : '暂无${isCrypto ? '加密' : '法定'}货币',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: currencies.length,
      itemBuilder: (context, index) {
        final currency = currencies[index];
        final isSelected = currencyPrefs.selectedCurrencies.contains(currency.code);
        final isBase = currency.code == currencyPrefs.baseCurrency;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isBase 
                  ? Colors.amber[400]! 
                  : (isSelected ? Colors.blue[300]! : Colors.grey[200]!),
              width: isBase ? 2 : 1,
            ),
          ),
          child: ListTile(
            onTap: () async {
              // 单击选择/取消选择货币
              if (currencyPrefs.multiCurrencyEnabled || !isSelected) {
                await currencyNotifier.toggleCurrency(currency.code);
              }
            },
            onLongPress: () {
              // 长按设为本位币
              if (!isBase) {
                _showBaseCurrencyDialog(currency);
              }
            },
            leading: Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isBase 
                        ? Colors.amber[100] 
                        : (currency.isCrypto ? Colors.purple[100] : Colors.blue[100]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      currency.flag ?? currency.symbol,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                // 本位币标识
                if (isBase)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.star,
                        size: 8,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Text(
                  _formatCurrencyDisplay(currency),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isBase) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '本位币',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.amber[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              '${currency.name} · ${currency.nameZh}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 汇率显示
                if (!isBase) ...[
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FutureBuilder<double?>(
                        future: currencyNotifier.convertAmount(1.0, baseCurrency.code, currency.code),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                              ),
                            );
                          }
                          
                          if (snapshot.hasData && snapshot.data != null) {
                            final rate = snapshot.data!;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currency.formatAmount(rate),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  '1 ${baseCurrency.code}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            );
                          }
                          
                          return Text(
                            '--',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                ],
                
                // 选择控件
                if (currencyPrefs.multiCurrencyEnabled) ...[
                  // 多币种模式：复选框 + 设为本位币按钮
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) async {
                      await currencyNotifier.toggleCurrency(currency.code);
                    },
                    activeColor: Colors.blue,
                  ),
                  if (isSelected && !isBase)
                    IconButton(
                      icon: Icon(
                        Icons.star_outline,
                        color: Colors.amber[600],
                        size: 20,
                      ),
                      tooltip: '设为本位币',
                      onPressed: () {
                        _showBaseCurrencyDialog(currency);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ] else ...[
                  // 单币种模式：单选按钮（自动设为本位币）
                  Radio<String>(
                    value: currency.code,
                    groupValue: currencyPrefs.selectedCurrencies.firstOrNull,
                    onChanged: (value) async {
                      if (value != null) {
                        // 单币种模式下，选择即设为本位币
                        await currencyNotifier.toggleCurrency(value);
                        await currencyNotifier.setBaseCurrency(value);
                      }
                    },
                    activeColor: Colors.blue,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBaseCurrencySelector() {
    final selectedCurrencies = ref.read(selectedCurrenciesProvider);
    final currentBase = ref.read(baseCurrencyProvider);
    
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
              '选择本位币',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: selectedCurrencies.length,
                itemBuilder: (context, index) {
                  final currency = selectedCurrencies[index];
                  final isSelected = currency.code == currentBase.code;
                  
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: Colors.amber[50],
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: currency.isCrypto ? Colors.purple[100] : Colors.blue[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: Text(
                          currency.flag ?? currency.symbol,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    title: Text(
                      '${currency.code} (${currency.symbol})',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(currency.nameZh),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Colors.amber[600])
                        : null,
                    onTap: () async {
                      if (!isSelected) {
                        final currencyNotifier = ref.read(currencyProvider.notifier);
                        await currencyNotifier.setBaseCurrency(currency.code);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('本位币已更改为 ${currency.code}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        Navigator.pop(context);
                      }
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
  
  String _getDisplayFormatExample() {
    final currencyPrefs = ref.read(currencyProvider);
    if (currencyPrefs.showCurrencyCode && currencyPrefs.showCurrencySymbol) {
      return '示例: USD (\$)';
    } else if (currencyPrefs.showCurrencyCode) {
      return '示例: USD';
    } else {
      return '示例: \$';
    }
  }
  
  String _formatCurrencyDisplay(model.Currency currency) {
    final currencyPrefs = ref.read(currencyProvider);
    if (currencyPrefs.showCurrencyCode && currencyPrefs.showCurrencySymbol) {
      return '${currency.code} (${currency.symbol})';
    } else if (currencyPrefs.showCurrencyCode) {
      return currency.code;
    } else {
      return currency.symbol;
    }
  }

  void _showBaseCurrencyDialog(model.Currency currency) {
    final currencyNotifier = ref.read(currencyProvider.notifier);
    final currentBase = ref.read(baseCurrencyProvider);

    if (currency.code == currentBase.code) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('更改本位币'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '确定要将本位币从 ${currentBase.code} 更改为 ${currency.code} 吗？',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 8),
                      Text(
                        '更改本位币将影响:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.amber[900],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 所有账户余额显示\n• 历史交易记录汇率计算\n• 报表和图表单位',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.amber[800],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              await currencyNotifier.setBaseCurrency(currency.code);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('本位币已更改为 ${currency.code}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}