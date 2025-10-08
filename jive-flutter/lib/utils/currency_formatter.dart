import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jive_money/providers/currency_provider.dart';

/// Currency formatter utility for Travel screens
class CurrencyFormatter {
  final Ref? _ref;

  CurrencyFormatter([this._ref]);

  /// Format amount with currency code
  String format(double amount, String currencyCode) {
    // If we have a ref, use the provider's formatter
    if (_ref != null) {
      return _ref!.read(currencyProvider.notifier).formatCurrency(amount, currencyCode);
    }

    // Fallback simple formatting
    final absAmount = amount.abs();
    final sign = amount < 0 ? '-' : '';

    // Basic formatting with 2 decimal places
    final formatted = absAmount.toStringAsFixed(2);

    // Add currency code
    return '$sign$currencyCode $formatted';
  }

  /// Format amount with default base currency
  String formatDefault(double amount, Ref ref) {
    final baseCurrency = ref.read(baseCurrencyProvider);
    return ref.read(currencyProvider.notifier).formatCurrency(amount, baseCurrency.code);
  }
}