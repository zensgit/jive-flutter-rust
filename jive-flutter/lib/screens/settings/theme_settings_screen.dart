import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';
import '../../core/app.dart' as core;
import '../../widgets/theme_appearance.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final themeMode = ref.watch(core.themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('主题设置')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // 主题模式
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('主题模式', style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.phone_iphone, size: 18),
                    label: const Text('跟随系统'),
                    onPressed: () => ref.read(core.themeModeProvider.notifier).setThemeMode(ThemeMode.system),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeMode == ThemeMode.system ? cs.onPrimary : null,
                      backgroundColor: themeMode == ThemeMode.system ? cs.primary : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                    label: const Text('浅色'),
                    onPressed: () => ref.read(core.themeModeProvider.notifier).setThemeMode(ThemeMode.light),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeMode == ThemeMode.light ? cs.onPrimary : null,
                      backgroundColor: themeMode == ThemeMode.light ? cs.primary : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.nightlight_round, size: 18),
                    label: const Text('深色'),
                    onPressed: () => ref.read(core.themeModeProvider.notifier).setThemeMode(ThemeMode.dark),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeMode == ThemeMode.dark ? cs.onPrimary : null,
                      backgroundColor: themeMode == ThemeMode.dark ? cs.primary : null,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 外观（密度 + 圆角）
          const ThemeAppearance(padding: EdgeInsets.all(16), showTitle: true),
        ],
      ),
    );
  }
}
