import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/currency.dart' as model;
import '../../providers/currency_provider.dart';
import 'currency_selection_page.dart';
import 'crypto_selection_page.dart';
import 'exchange_rate_converter_page.dart';

/// 优化后的货币管理页面 V2
class CurrencyManagementPageV2 extends ConsumerStatefulWidget {
  const CurrencyManagementPageV2({super.key});

  @override
  ConsumerState<CurrencyManagementPageV2> createState() => _CurrencyManagementPageV2State();
}

class _CurrencyManagementPageV2State extends ConsumerState<CurrencyManagementPageV2> {
  bool _isLoadingRates = false;
  DateTime? _manualRateExpiry;

  @override
  void initState() {
    super.initState();
    // 页面打开时自动获取汇率
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoFetchExchangeRates();
    });
  }

  Widget _buildManualRatesBanner(WidgetRef ref) {
    final manualActive = ref.watch(currencyProvider.notifier).manualRatesActive;
    final manualExpiry = ref.watch(currencyProvider.notifier).manualRatesExpiryUtc;
    if (manualExpiry == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: manualActive ? Colors.orange[50] : Colors.grey[100],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 14, color: manualActive ? Colors.orange[700] : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              '手动汇率有效至: ${_formatDate(manualExpiry.toLocal())}${manualActive ? '' : ' (已过期)'}',
              style: TextStyle(
                fontSize: 12,
                color: manualActive ? Colors.orange[700]! : Colors.grey[600]!,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () async {
                await ref.read(currencyProvider.notifier).clearManualRates();
                if (!mounted) return;
                _showSnackBar('已清除手动汇率', Colors.green);
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('清除'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _autoFetchExchangeRates() async {
    final currencyNotifier = ref.read(currencyProvider.notifier);
    
    setState(() {
      _isLoadingRates = true;
    });
    
    try {
      await currencyNotifier.refreshExchangeRates();
      if (mounted) {
        _showSnackBar('汇率已更新', Colors.green);
      }
    } catch (e) {
      print('Auto-fetch exchange rates failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRates = false;
        });
      }
    }
  }

  Future<void> _manualUpdateRates() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ManualRateDialog(
        currentExpiry: _manualRateExpiry,
      ),
    );
    
    if (result != null) {
      final defaultExpiry = result['expiry'] as DateTime;
      // Build manual rates based on currently selected fiat currencies vs base
      final base = ref.read(baseCurrencyProvider).code;
      final selected = ref.read(selectedCurrenciesProvider)
          .where((c) => !c.isCrypto && c.code != base)
          .toList();
      final notifier = ref.read(currencyProvider.notifier);
      final Map<String, double> manualRates = {};
      final Map<String, DateTime> expiries = {};
      // Prompt per-currency rates
      for (final c in selected) {
        final rwe = await _promptManualRateWithExpiry(c.code, base, defaultExpiry);
        if (rwe != null && rwe.rate > 0) {
          manualRates[c.code] = rwe.rate;
          expiries[c.code] = rwe.expiryUtc;
        }
      }
      if (manualRates.isNotEmpty) {
        await notifier.setManualRatesWithExpiries(manualRates, expiries);
        // For banner, pick earliest expiry
        final sorted = expiries.values.toList()..sort();
        final bannerExpiry = sorted.isNotEmpty ? sorted.first : defaultExpiry;
        setState(() { _manualRateExpiry = bannerExpiry; });
        _showSnackBar('手动汇率已设置，最早有效期至 ${_formatDate(bannerExpiry)}', Colors.blue);
      }
    }
  }

  Future<double?> _promptManualRate(String toCurrency, String baseCurrency) async {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('设置汇率: 1 $baseCurrency = ? $toCurrency'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(hintText: '请输入汇率数值'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('跳过')),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              Navigator.pop(context, v);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBaseCurrencyChangeDialog(model.Currency newCurrency) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Text('更换基础货币'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '您确定要将基础货币从 ${ref.read(baseCurrencyProvider).code} 更换为 ${newCurrency.code} 吗？',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
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
                  const Text(
                    '请注意：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildWarningItem('1. 已有币种转换的账单将保留原转换单位'),
                  _buildWarningItem('2. 无币种转换的账单将以新币种显示'),
                  _buildWarningItem('3. 所有统计数据将以新基础货币汇总'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('确认更换'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await ref.read(currencyProvider.notifier).setBaseCurrency(newCurrency.code);
      _showSnackBar('基础货币已更换为 ${newCurrency.code}', Colors.green);
    }
  }

  Widget _buildWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getDisplayExample() {
    final prefs = ref.watch(currencyProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    String example = '1234.56';
    
    if (prefs.showCurrencySymbol && prefs.showCurrencyCode) {
      return '示例: ${baseCurrency.symbol}$example ${baseCurrency.code}';
    } else if (prefs.showCurrencySymbol) {
      return '示例: ${baseCurrency.symbol}$example';
    } else {
      return '示例: $example ${baseCurrency.code}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyPrefs = ref.watch(currencyProvider);
    final currencyNotifier = ref.watch(currencyProvider.notifier);
    final isCryptoSupported = ref.watch(isCryptoSupportedProvider);
    final baseCurrency = ref.watch(baseCurrencyProvider);
    final selectedCurrencies = ref.watch(selectedCurrenciesProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('多币种设置'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        actions: [
          if (_isLoadingRates)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. 基础货币 - 放在第一行
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '基础货币',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '重要',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.amber[900],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final result = await Navigator.push<model.Currency>(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CurrencySelectionPage(
                            isSelectingBaseCurrency: true,
                          ),
                        ),
                      );
                      
                      if (result != null && result.code != baseCurrency.code) {
                        await _showBaseCurrencyChangeDialog(result);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Row(
                        children: [
                          // 国旗或符号
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber[300]!),
                            ),
                            child: Center(
                              child: Text(
                                baseCurrency.flag ?? baseCurrency.symbol,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      baseCurrency.code,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
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
                                        baseCurrency.symbol,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  baseCurrency.nameZh,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.amber[700]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 2. 启用多币种 - 第二行
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.language, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '启用多币种',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: currencyPrefs.multiCurrencyEnabled,
                        onChanged: (value) async {
                          await currencyNotifier.setMultiCurrencyMode(value);
                        },
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                  if (currencyPrefs.multiCurrencyEnabled) ...[
                    const SizedBox(height: 12),
                    // 启用加密货币 - 只在多币种开启时显示
                    if (isCryptoSupported)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.currency_bitcoin,
                              color: Colors.purple[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '启用加密货币',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            Switch(
                              value: currencyPrefs.cryptoEnabled,
                              onChanged: (value) async {
                                await currencyNotifier.setCryptoMode(value);
                              },
                              activeColor: Colors.purple,
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.block, color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '加密货币在您的地区不可用',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.red[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),

            // 3. 多币种管理
            if (currencyPrefs.multiCurrencyEnabled)
              Container(
                color: Colors.white,
                margin: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, 
                            color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            '已选货币',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${selectedCurrencies.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[800],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 管理按钮
                    ListTile(
                      leading: const Icon(Icons.edit, color: Colors.blue),
                      title: const Text('管理法定货币'),
                      subtitle: Text(
                        '选择并管理汇率',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CurrencySelectionPage(),
                          ),
                        );
                      },
                    ),
                    if (currencyPrefs.cryptoEnabled)
                      ListTile(
                        leading: const Icon(Icons.currency_bitcoin, 
                          color: Colors.purple),
                        title: const Text('管理加密货币'),
                        subtitle: Text(
                          '选择并管理加密货币',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CryptoSelectionPage(),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

            // 4. 显示设置
            Container(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.visibility, color: Colors.teal[700], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '显示设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    title: const Text('显示货币符号'),
                    subtitle: Text(
                      '在金额前显示货币符号',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    value: currencyPrefs.showCurrencySymbol,
                    onChanged: (value) async {
                      if (value == false && !currencyPrefs.showCurrencyCode) {
                        _showSnackBar('至少需要显示一种格式', Colors.orange);
                        return;
                      }
                      await currencyNotifier.setDisplayFormat(
                        currencyPrefs.showCurrencyCode,
                        value ?? false,
                      );
                    },
                    activeColor: Colors.teal,
                    contentPadding: EdgeInsets.zero,
                  ),
                  CheckboxListTile(
                    title: const Text('显示货币代码'),
                    subtitle: Text(
                      '在金额后显示货币代码',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    value: currencyPrefs.showCurrencyCode,
                    onChanged: (value) async {
                      if (value == false && !currencyPrefs.showCurrencySymbol) {
                        _showSnackBar('至少需要显示一种格式', Colors.orange);
                        return;
                      }
                      await currencyNotifier.setDisplayFormat(
                        value ?? true,
                        currencyPrefs.showCurrencySymbol,
                      );
                    },
                    activeColor: Colors.teal,
                    contentPadding: EdgeInsets.zero,
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, 
                          size: 16, color: Colors.teal[700]),
                        const SizedBox(width: 8),
                        Text(
                          _getDisplayExample(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.teal[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 5. 汇率管理（隐藏）
            if (false) Container(
              color: Colors.white,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sync, color: Colors.indigo[700], size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '汇率管理',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // 汇率更新按钮
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoadingRates ? null : _autoFetchExchangeRates,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('自动更新'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.indigo,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _manualUpdateRates,
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('手动设置'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Manual override banner (kept internal but hidden with block)
                  // _buildManualRatesBanner(ref),
                  // const SizedBox(height: 12),
                  // 数据源提示（自动/手动）
                  Builder(builder: (_) {
                    final isFallback = ref.watch(currencyProvider).isFallback ?? false;
                    final manualActive = ref.watch(currencyProvider.notifier).manualRatesActive;
                    final parts = <String>[];
                    if (manualActive) parts.add('手动');
                    parts.add(isFallback ? '备用' : '实时');
                    final sourceText = '数据源：${parts.join(" + ")} (由后端统一汇总，来源含央行/公开API)';
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 14, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sourceText,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // 汇率转换器（隐藏）
                  // ListTile(...)
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // Rate + per-currency expiry prompt
  Future<_RateWithExpiry?> _promptManualRateWithExpiry(
    String toCurrency,
    String baseCurrency,
    DateTime defaultExpiryUtc,
  ) async {
    final controller = TextEditingController();
    DateTime expiryUtc = defaultExpiryUtc;
    return showDialog<_RateWithExpiry>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('设置汇率与有效期: 1 $baseCurrency = ? $toCurrency'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: '请输入汇率数值'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '有效期至: ${_formatDate(expiryUtc.toLocal())}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: expiryUtc.toLocal(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (date != null) {
                        setState(() {
                          expiryUtc = DateTime.utc(date.year, date.month, date.day, 0, 0, 0);
                        });
                      }
                    },
                    icon: const Icon(Icons.calendar_today, color: Colors.blueGrey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('提示：有效期内将优先使用手动汇率', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('跳过')),
            ElevatedButton(
              onPressed: () {
                final v = double.tryParse(controller.text.trim());
                if (v == null || v <= 0) { Navigator.pop(context); return; }
                Navigator.pop(context, _RateWithExpiry(v, expiryUtc));
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

}

class _RateWithExpiry {
  final double rate;
  final DateTime expiryUtc;
  _RateWithExpiry(this.rate, this.expiryUtc);
}

// 手动设置汇率对话框
class _ManualRateDialog extends StatefulWidget {
  final DateTime? currentExpiry;
  
  const _ManualRateDialog({this.currentExpiry});
  
  @override
  State<_ManualRateDialog> createState() => _ManualRateDialogState();
}

class _ManualRateDialogState extends State<_ManualRateDialog> {
  late DateTime _selectedExpiry;
  
  @override
  void initState() {
    super.initState();
    // 默认设置为明天的世界时间
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _selectedExpiry = DateTime.utc(
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
      0, 0, 0,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手动设置汇率'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '设置手动汇率有效期',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '有效期至',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '${_selectedExpiry.year}-${_selectedExpiry.month.toString().padLeft(2, '0')}-${_selectedExpiry.day.toString().padLeft(2, '0')} 00:00 UTC',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedExpiry.toLocal(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    
                    if (date != null) {
                      setState(() {
                        _selectedExpiry = DateTime.utc(
                          date.year,
                          date.month,
                          date.day,
                          0, 0, 0,
                        );
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today, color: Colors.blue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '提示：手动设置的汇率将在有效期内优先使用',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, {
              'expiry': _selectedExpiry,
            });
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
