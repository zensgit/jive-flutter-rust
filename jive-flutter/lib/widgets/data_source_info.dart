import 'package:flutter/material.dart';

Future<void> showDataSourceInfoSheet(BuildContext context) async {
  final cs = Theme.of(context).colorScheme;
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline, color: cs.primary),
                  const SizedBox(width: 8),
                  const Text(
                    '数据来源与缓存说明',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  )
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                '法定货币：默认优先顺序 ExchangeRate-API → Frankfurter(ECB) → FXRates；后端按优先顺序合并缺失币种，并标注每个币种的来源。',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              const Text(
                '加密货币：默认优先顺序 CoinGecko → CoinCap(USD) → Binance(USDT)。',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              const Text(
                '缓存策略：法币 15 分钟、加密 5 分钟；后端自动回退。UI 中的来源徽标显示每个币种的实际数据来源。',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              const Text(
                '说明：部分来源可能不覆盖全部币种，系统会自动从后备来源补齐（如 AED/ARS/CLP/COP 等）。',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    },
  );
}
