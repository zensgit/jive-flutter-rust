import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';

/// 可复用的“主题外观”组件：密度 + 圆角
class ThemeAppearance extends ConsumerWidget {
  final EdgeInsetsGeometry padding;
  final bool showTitle;

  const ThemeAppearance({super.key, this.padding = const EdgeInsets.all(16), this.showTitle = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final cs = Theme.of(context).colorScheme;
    return Container(
      color: cs.surface,
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle)
            Row(
              children: [
                Icon(Icons.tune, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '主题外观',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          if (showTitle) const SizedBox(height: 12),

          // 密度
          SwitchListTile(
            value: settings.listDensity == 'compact',
            onChanged: (v) async {
              await ref.read(settingsProvider.notifier).updateSetting('listDensity', v ? 'compact' : 'comfortable');
            },
            title: const Text('紧凑密度'),
            subtitle: const Text('减少垂直留白，显示更多列表项'),
            contentPadding: EdgeInsets.zero,
            activeColor: cs.primary,
          ),

          // 圆角
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.crop_square_rounded, color: cs.secondary),
            title: const Text('圆角大小'),
            subtitle: const Text('小 / 中 / 大'),
            trailing: DropdownButton<String>(
              value: settings.cornerRadius,
              items: const [
                DropdownMenuItem(value: 'small', child: Text('小')),
                DropdownMenuItem(value: 'medium', child: Text('中')),
                DropdownMenuItem(value: 'large', child: Text('大')),
              ],
              onChanged: (v) async {
                if (v != null) {
                  await ref.read(settingsProvider.notifier).updateSetting('cornerRadius', v);
                }
              },
            ),
          ),

          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.35),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: cs.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  '密度与圆角设置将影响列表、卡片、输入框等组件。',
                  style: TextStyle(fontSize: 12, color: cs.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

