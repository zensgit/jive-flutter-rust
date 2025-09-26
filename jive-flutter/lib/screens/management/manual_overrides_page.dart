import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/core/network/api_readiness.dart';
import 'package:jive_money/core/network/http_client.dart';
import 'package:jive_money/providers/currency_provider.dart';

class ManualOverridesPage extends ConsumerStatefulWidget {
  const ManualOverridesPage({super.key});

  @override
  ConsumerState<ManualOverridesPage> createState() => _ManualOverridesPageState();
}

class _ManualOverridesPageState extends ConsumerState<ManualOverridesPage> {
  bool _onlyActive = true;
  bool _onlySoonExpiring = false;
  bool _loading = false;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final base = ref.read(baseCurrencyProvider).code;
      final resp = await dio.get('/currencies/manual-overrides', queryParameters: {
        'base_currency': base,
        'only_active': _onlyActive,
      });
      final data = resp.data['data'] ?? resp.data;
      final List items = (data['overrides'] as List?) ?? [];
      setState(() {
        _items = items.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取手动覆盖失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clear({bool onlyExpired = false, DateTime? beforeDate}) async {
    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);
      final base = ref.read(baseCurrencyProvider).code;
      final payload = <String, dynamic>{'from_currency': base};
      if (onlyExpired) payload['only_expired'] = true;
      if (beforeDate != null) {
        payload['before_date'] = '${beforeDate.year}-${beforeDate.month.toString().padLeft(2, '0')}-${beforeDate.day.toString().padLeft(2, '0')}';
      }
      await dio.post('/currencies/rates/clear-manual-batch', data: payload);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('清理已执行'), backgroundColor: Colors.green),
      );
      await _load();
      // 刷新 provider 中的汇率以同步徽标
      await ref.read(currencyProvider.notifier).refreshExchangeRates();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清理失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = ref.watch(baseCurrencyProvider).code;
    return Scaffold(
      appBar: AppBar(
        title: const Text('手动覆盖清单'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Switch(
                  value: _onlyActive,
                  onChanged: (v) {
                    setState(() => _onlyActive = v);
                    _load();
                  },
                ),
                const Text('仅显示未过期'),
                const SizedBox(width: 16),
                Switch(
                  value: _onlySoonExpiring,
                  onChanged: (v) {
                    setState(() => _onlySoonExpiring = v);
                  },
                ),
                const Text('仅显示即将到期(<48h)'),
                const Spacer(),
                TextButton.icon(
                  onPressed: _loading ? null : () => _clear(onlyExpired: true),
                  icon: const Icon(Icons.cleaning_services, size: 16),
                  label: const Text('清除已过期'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _loading
                      ? null
                      : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            await _clear(beforeDate: picked);
                          }
                        },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('按日期清除'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _loading ? null : () => _clear(),
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('清除全部'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('暂无手动覆盖'))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final m = _items[i];
                          final to = (m['to_currency'] ?? '').toString();
                          final rate = m['rate']?.toString() ?? '-';
                          final expiryRaw = m['manual_rate_expiry']?.toString();
                          final updated = m['updated_at']?.toString();
                          // 近48小时到期高亮
                          bool nearlyExpired = false;
                          if (expiryRaw != null && expiryRaw.isNotEmpty) {
                            final dt = DateTime.tryParse(expiryRaw);
                            if (dt != null) {
                              nearlyExpired = dt.isBefore(DateTime.now().add(const Duration(hours: 48))) && dt.isAfter(DateTime.now());
                            }
                          }
                          if (_onlySoonExpiring && !nearlyExpired) {
                            return const SizedBox.shrink();
                          }
                          return ListTile(
                            leading: Icon(nearlyExpired ? Icons.warning_amber_rounded : Icons.rule, size: 18, color: nearlyExpired ? Colors.orange : null),
                            title: Text(
                              '1 $base = $rate $to',
                              style: TextStyle(color: nearlyExpired ? Colors.orange[800] : null),
                            ),
                            subtitle: Text([
                              if (expiryRaw != null) '有效至: $expiryRaw${nearlyExpired ? '（即将到期）' : ''}',
                              if (updated != null) '更新: $updated',
                            ].join('  ·  ')),
                            trailing: IconButton(
                              tooltip: '清除此覆盖',
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () async {
                                try {
                                  final dio = HttpClient.instance.dio;
                                  await ApiReadiness.ensureReady(dio);
                                  await dio.post('/currencies/rates/clear-manual', data: {
                                    'from_currency': base,
                                    'to_currency': to,
                                  });
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('已清除 $base/$to 覆盖'), backgroundColor: Colors.green),
                                  );
                                  await _load();
                                  await ref.read(currencyProvider.notifier).refreshExchangeRates();
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('清除失败: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
