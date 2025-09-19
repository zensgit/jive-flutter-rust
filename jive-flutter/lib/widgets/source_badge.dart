import 'package:flutter/material.dart';

class SourceBadge extends StatelessWidget {
  final String? source;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const SourceBadge({
    super.key,
    required this.source,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    final label = _labelFor(source);
    final cs = Theme.of(context).colorScheme;
    final color = _colorFor(context, source);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static String _labelFor(String? src) {
    switch ((src ?? '').toLowerCase()) {
      case 'manual':
        return '手动';
      case 'exchangerate-api':
        return 'ExchangeRate-API';
      case 'coingecko':
        return 'CoinGecko';
      case 'frankfurter':
        return 'ECB';
      case 'fxrates':
        return 'FXRates';
      case 'backend-api':
        return 'API';
      default:
        return src == null || src.isEmpty ? '未知' : src;
    }
  }

  static Color _colorFor(BuildContext context, String? src) {
    final cs = Theme.of(context).colorScheme;
    switch ((src ?? '').toLowerCase()) {
      case 'manual':
        return cs.tertiary;
      case 'coingecko':
        return cs.secondary;
      case 'exchangerate-api':
        return cs.primary;
      case 'frankfurter':
        return cs.primary;
      case 'fxrates':
        return cs.primary;
      case 'backend-api':
        return cs.primary;
      default:
        return cs.outline;
    }
  }
}
