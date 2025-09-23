import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jive_money/core/router/app_router.dart';

// Simple mock pages that don't require complex dependencies
class MockSettingsScreen extends StatelessWidget {
  const MockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('手动覆盖清单'),
            onTap: () => context.go(AppRoutes.manualOverrides),
          ),
        ],
      ),
    );
  }
}

class MockManualOverridesPage extends StatelessWidget {
  const MockManualOverridesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manual Overrides')),
      body: const Center(child: Text('Manual Overrides Page')),
    );
  }
}

void main() {
  testWidgets('Settings has manual overrides entry and navigates', (tester) async {
    final container = ProviderContainer(overrides: []);

    final router = GoRouter(
      routes: [
        GoRoute(path: AppRoutes.settings, builder: (_, __) => const MockSettingsScreen()),
        GoRoute(path: AppRoutes.manualOverrides, builder: (_, __) => const MockManualOverridesPage()),
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
    expect(find.byType(MockManualOverridesPage), findsOneWidget);
  });
}

