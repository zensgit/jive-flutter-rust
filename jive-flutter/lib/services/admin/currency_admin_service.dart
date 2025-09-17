import 'package:dio/dio.dart';
import '../../core/network/http_client.dart';
import '../../core/network/api_readiness.dart';
import '../../models/admin_currency.dart';

class CurrencyAdminService {
  final Dio _dio = HttpClient.instance.dio;
  bool _warned = false;

  bool _isAdmin(Ref? ref) {
    // Optional guard hook if we had a Ref here; since service is simple, we keep a lightweight safeguard
    return true; // server will enforce; client can add UI-level gating
  }

  Future<List<AdminCurrency>> listCurrencies() async {
    await ApiReadiness.ensureReady(_dio);
    final resp = await _dio.get('/admin/currencies');
    final data = resp.data;
    final list = (data['data'] ?? data) as List<dynamic>;
    return list
        .map((e) => AdminCurrency.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AdminCurrency> createCurrency(AdminCurrency payload) async {
    // client-side soft guard could be added via role check in UI; server enforces ACL
    await ApiReadiness.ensureReady(_dio);
    final resp = await _dio.post('/admin/currencies', data: payload.toJson());
    return AdminCurrency.fromJson(
        (resp.data['data'] ?? resp.data) as Map<String, dynamic>);
  }

  Future<AdminCurrency> updateCurrency(
      String code, Map<String, dynamic> updates) async {
    await ApiReadiness.ensureReady(_dio);
    final resp = await _dio.put('/admin/currencies/$code', data: updates);
    return AdminCurrency.fromJson(
        (resp.data['data'] ?? resp.data) as Map<String, dynamic>);
  }

  Future<void> createAlias(String oldCode, String newCode,
      {DateTime? validUntil}) async {
    await ApiReadiness.ensureReady(_dio);
    await _dio.post('/admin/currency-aliases', data: {
      'old_code': oldCode,
      'new_code': newCode,
      if (validUntil != null) 'valid_until': validUntil.toIso8601String(),
    });
  }

  Future<void> refreshCatalog() async {
    await ApiReadiness.ensureReady(_dio);
    await _dio.post('/currencies/refresh');
  }
}
