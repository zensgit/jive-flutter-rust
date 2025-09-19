import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/category_provider.dart';
import 'models/category_template.dart';

void main() {
  runApp(
    const ProviderScope(
      child: NetworkTestApp(),
    ),
  );
}

class NetworkTestApp extends StatelessWidget {
  const NetworkTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jive Network Category Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const NetworkTestScreen(),
    );
  }
}

class NetworkTestScreen extends ConsumerWidget {
  const NetworkTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(systemTemplatesProvider);
    final networkStatus = ref.watch(networkStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Category Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref
                  .read(systemTemplatesProvider.notifier)
                  .refresh(forceRefresh: true);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Network Status Card
          Card(
            color: networkStatus.hasNetworkData
                ? Colors.green[100]
                : Colors.orange[100],
            child: ListTile(
              leading: Icon(
                networkStatus.hasNetworkData
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                color:
                    networkStatus.hasNetworkData ? Colors.green : Colors.orange,
              ),
              title: Text(
                networkStatus.hasNetworkData
                    ? 'Network Data Available'
                    : 'Using Local Data',
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Loading: ${networkStatus.isLoading}'),
                  if (networkStatus.lastSync != null)
                    Text('Last Sync: ${networkStatus.lastSync!.toLocal()}'),
                  if (networkStatus.error != null)
                    Text('Error: ${networkStatus.error}',
                        style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Templates List
          Expanded(
            child: templatesAsync.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading templates...'),
                  ],
                ),
              ),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref
                            .read(systemTemplatesProvider.notifier)
                            .refresh(forceRefresh: true);
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (templates) => ListView.builder(
                itemCount: templates.length,
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return TemplateCard(template: template);
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _testNetworkCall(ref);
        },
        label: const Text('Test Network'),
        icon: const Icon(Icons.network_check),
      ),
    );
  }

  void _testNetworkCall(WidgetRef ref) async {
    try {
      final service = ref.read(categoryServiceProvider);
      final templates = await service.getAllTemplates(forceRefresh: true);
      debugPrint(
          '✅ Network test successful: Loaded ${templates.length} templates');

      // Test featured templates
      final featured = await service.getFeaturedTemplates();
      debugPrint('✅ Featured templates: ${featured.length}');

      // Test search
      final searchResults = await service.searchTemplates('工资');
      debugPrint('✅ Search results for "工资": ${searchResults.length}');
    } catch (e) {
      debugPrint('❌ Network test failed: $e');
    }
  }
}

class TemplateCard extends StatelessWidget {
  final SystemCategoryTemplate template;

  const TemplateCard({super.key, required this.template});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _parseColor(template.color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              template.icon ?? '📁',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        title: Text(template.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(template.nameEn ?? ''),
            Text(template.classification.name.toUpperCase()),
            if (template.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: template.tags
                    .map((tag) => Chip(
                          label:
                              Text(tag, style: const TextStyle(fontSize: 10)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (template.isFeatured)
              const Icon(Icons.star, color: Colors.amber, size: 16),
            Text('${template.globalUsageCount}'),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.grey;
    }
  }
}
