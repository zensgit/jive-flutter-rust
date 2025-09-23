import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jive_money/core/router/app_router.dart';
import 'package:jive_money/screens/settings/settings_screen.dart';
import 'package:jive_money/screens/management/manual_overrides_page.dart';

void main() {
  testWidgets('Settings has manual overrides entry and navigates', (tester) async {
    final container = ProviderContainer(overrides: [
      // Add minimal overrides if needed for auth; here we assume SettingsScreen builds without auth
    ]);

    final router = GoRouter(
      routes: [
        GoRoute(path: AppRoutes.settings, builder: (_, __) => const SettingsScreen()),
        GoRoute(path: AppRoutes.manualOverrides, builder: (_, __) => const ManualOverridesPage()),
      ],
      initialLocation: AppRoutes.settings,
    );

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ));

    // Find the tile by text
    final manualOverridesTile = find.text('手动覆盖清单');
    expect(manualOverridesTile, findsOneWidget);

    // Scroll to make the item visible if needed
    await tester.ensureVisible(manualOverridesTile);
    await tester.pumpAndSettle();

    // Tap and navigate
    await tester.tap(manualOverridesTile);
    await tester.pumpAndSettle();

    // New page should appear
    expect(find.byType(ManualOverridesPage), findsOneWidget);
  });
}

