import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:jive_money/core/network/http_client.dart';
import 'package:jive_money/core/network/api_readiness.dart';
import 'package:jive_money/core/storage/token_storage.dart';
import 'package:jive_money/models/bank.dart';

class BankService {
  static const String _cacheKey = 'banks_cache';
  static const String _cacheTimestampKey = 'banks_cache_timestamp';
  static const Duration _cacheExpiration = Duration(hours: 24);

  final String? token;

  BankService(this.token);

  Future<Map<String, String>> _headers() async {
    final t = token ?? await TokenStorage.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  Future<List<Bank>> getBanks({
    String? search,
    bool? isCrypto,
    int? limit,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = await _getCachedBanks();
      if (cached != null && cached.isNotEmpty) {
        return _filterBanksLocally(cached, search: search, isCrypto: isCrypto);
      }
    }

    try {
      final dio = HttpClient.instance.dio;
      await ApiReadiness.ensureReady(dio);

      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (isCrypto != null) {
        queryParams['is_crypto'] = isCrypto;
      }
      if (limit != null) {
        queryParams['limit'] = limit;
      }

      final resp = await dio.get(
        '/banks',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(headers: await _headers()),
      );

      if (resp.statusCode == 200) {
        final List<dynamic> data = resp.data is List
            ? resp.data
            : (resp.data['data'] ?? resp.data);

        final banks = data.map((json) => Bank.fromJson(json)).toList();

        if (search == null && isCrypto == null) {
          await _cacheBanks(banks);
        }

        return banks;
      } else {
        throw Exception('Failed to load banks: ${resp.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching banks from API: $e');
      final cached = await _getCachedBanks();
      if (cached != null && cached.isNotEmpty) {
        return _filterBanksLocally(cached, search: search, isCrypto: isCrypto);
      }
      rethrow;
    }
  }

  Future<Bank?> getBankById(String id) async {
    final banks = await getBanks();
    try {
      return banks.firstWhere((bank) => bank.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<List<Bank>> searchBanks(String query, {bool? isCrypto}) async {
    if (query.isEmpty) {
      return getBanks(isCrypto: isCrypto);
    }

    return getBanks(search: query, isCrypto: isCrypto);
  }

  Future<List<Bank>> getCryptoBanks() async {
    return getBanks(isCrypto: true);
  }

  Future<List<Bank>> getRegularBanks() async {
    return getBanks(isCrypto: false);
  }

  List<Bank> _filterBanksLocally(
    List<Bank> banks, {
    String? search,
    bool? isCrypto,
  }) {
    var filtered = banks;

    if (isCrypto != null) {
      filtered = filtered.where((bank) => bank.isCrypto == isCrypto).toList();
    }

    if (search != null && search.isNotEmpty) {
      final searchLower = search.toLowerCase();
      filtered = filtered.where((bank) {
        return bank.name.toLowerCase().contains(searchLower) ||
            (bank.nameCn?.toLowerCase().contains(searchLower) ?? false) ||
            (bank.nameEn?.toLowerCase().contains(searchLower) ?? false) ||
            bank.code.toLowerCase().contains(searchLower);
      }).toList();
    }

    return filtered;
  }

  Future<void> _cacheBanks(List<Bank> banks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final banksJson = banks.map((bank) => bank.toJson()).toList();
      await prefs.setString(_cacheKey, jsonEncode(banksJson));
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('Error caching banks: $e');
    }
  }

  Future<List<Bank>?> _getCachedBanks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_cacheKey);
      final cachedTimestamp = prefs.getInt(_cacheTimestampKey);

      if (cachedJson == null || cachedTimestamp == null) {
        return null;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
      final now = DateTime.now();

      if (now.difference(cacheTime) > _cacheExpiration) {
        await clearCache();
        return null;
      }

      final List<dynamic> jsonList = jsonDecode(cachedJson);
      return jsonList.map((json) => Bank.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error reading cached banks: $e');
      return null;
    }
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (e) {
      debugPrint('Error clearing bank cache: $e');
    }
  }

  Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedTimestamp = prefs.getInt(_cacheTimestampKey);

      if (cachedTimestamp == null) {
        return false;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
      final now = DateTime.now();

      return now.difference(cacheTime) <= _cacheExpiration;
    } catch (e) {
      return false;
    }
  }

  Future<void> refreshBanks() async {
    await clearCache();
    await getBanks(forceRefresh: true);
  }
}