import 'package:flutter/material.dart';
import '../../services/api/category_service.dart';

class ImportDetailsSheet extends StatelessWidget {
  final ImportResult result;

  const ImportDetailsSheet({
    super.key,
    required this.result,
  });

  static Future<void> show(BuildContext context, ImportResult result) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ImportDetailsSheet(result: result),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: result.success ? Colors.green : Colors.red,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Import Results',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),

          const Divider(),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary
                  _buildSummarySection(context),

                  const SizedBox(height: 20),

                  // Details by action
                  if (result.details.isNotEmpty) ...[
                    Text(
                      'Import Details',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...result.details.entries.map(
                      (entry) => _buildActionSection(context, entry.key, entry.value),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context) {
    final total = result.details.values.fold<int>(
      0,
      (sum, items) => sum + items.length,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: result.success ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: result.success ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                result.success ? Icons.check_circle : Icons.error,
                color: result.success ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                result.success ? 'Import Successful' : 'Import Failed',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: result.success ? Colors.green.shade700 : Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Total items processed: $total',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (result.message.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              result.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionSection(BuildContext context, String action, List<ImportDetail> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    IconData actionIcon;
    Color actionColor;
    String actionLabel;

    switch (action.toLowerCase()) {
      case 'created':
        actionIcon = Icons.add_circle;
        actionColor = Colors.green;
        actionLabel = 'Created';
        break;
      case 'updated':
        actionIcon = Icons.edit;
        actionColor = Colors.blue;
        actionLabel = 'Updated';
        break;
      case 'skipped':
        actionIcon = Icons.skip_next;
        actionColor = Colors.orange;
        actionLabel = 'Skipped';
        break;
      case 'renamed':
        actionIcon = Icons.drive_file_rename_outline;
        actionColor = Colors.purple;
        actionLabel = 'Renamed';
        break;
      default:
        actionIcon = Icons.info;
        actionColor = Colors.grey;
        actionLabel = action;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(actionIcon, color: actionColor, size: 20),
              const SizedBox(width: 8),
              Text(
                '$actionLabel (${items.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _buildImportDetailItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildImportDetailItem(BuildContext context, ImportDetail item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (item.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              item.reason,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}