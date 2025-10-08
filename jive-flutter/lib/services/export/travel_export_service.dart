import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:jive_money/models/travel_event.dart';
import 'package:jive_money/models/transaction.dart';
import 'package:jive_money/utils/currency_formatter.dart';

/// Service for exporting travel data to various formats
class TravelExportService {
  final CurrencyFormatter _currencyFormatter = CurrencyFormatter();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final DateFormat _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  /// Export travel data to CSV format
  Future<void> exportToCSV({
    required TravelEvent event,
    required List<Transaction> transactions,
    Map<String, double>? categoryBudgets,
  }) async {
    try {
      // Build CSV content
      final StringBuffer csv = StringBuffer();

      // Add header
      csv.writeln('Travel Report - ${event.name}');
      csv.writeln('Generated on: ${_dateFormat.format(DateTime.now())}');
      csv.writeln('');

      // Travel information
      csv.writeln('Travel Information');
      csv.writeln('Field,Value');
      csv.writeln('Name,"${event.name}"');
      csv.writeln('Destination,"${event.destination ?? 'N/A'}"');
      csv.writeln('Start Date,${_dateFormat.format(event.startDate)}');
      csv.writeln('End Date,${_dateFormat.format(event.endDate)}');
      csv.writeln('Duration,${event.duration} days');
      csv.writeln('Budget,${_currencyFormatter.format(event.budget ?? 0, event.currency)}');
      csv.writeln('Total Spent,${_currencyFormatter.format(event.totalSpent, event.currency)}');
      csv.writeln('Currency,${event.currency}');

      if (event.notes != null && event.notes!.isNotEmpty) {
        csv.writeln('Notes,"${event.notes}"');
      }
      csv.writeln('');

      // Category budgets if provided
      if (categoryBudgets != null && categoryBudgets.isNotEmpty) {
        csv.writeln('Category Budgets');
        csv.writeln('Category,Budget,Spent,Remaining');

        final categories = {
          'accommodation': '住宿',
          'transportation': '交通',
          'dining': '餐饮',
          'attractions': '景点',
          'shopping': '购物',
          'entertainment': '娱乐',
          'other': '其他',
        };

        for (var entry in categoryBudgets.entries) {
          final categoryName = categories[entry.key] ?? entry.key;
          final budget = entry.value;

          // Calculate spent for this category
          final spent = transactions
              .where((t) => (t.category ?? 'other') == entry.key)
              .fold<double>(0, (sum, t) => sum + t.amount.abs());

          csv.writeln('$categoryName,${budget.toStringAsFixed(2)},${spent.toStringAsFixed(2)},${(budget - spent).toStringAsFixed(2)}');
        }
        csv.writeln('');
      }

      // Transactions
      csv.writeln('Transactions');
      csv.writeln('Date,Time,Payee,Category,Amount,Description');

      for (var transaction in transactions) {
        final date = _dateFormat.format(transaction.date);
        final time = DateFormat('HH:mm').format(transaction.date);
        final payee = transaction.payee ?? 'Unknown';
        final category = _getCategoryName(transaction.category ?? 'other');
        final amount = transaction.amount.toStringAsFixed(2);
        final description = transaction.description.replaceAll(',', ';').replaceAll('"', '\'');

        csv.writeln('$date,$time,"$payee",$category,$amount,"$description"');
      }

      csv.writeln('');

      // Statistics
      csv.writeln('Statistics');
      csv.writeln('Metric,Value');
      csv.writeln('Total Transactions,${transactions.length}');
      csv.writeln('Average Transaction,${transactions.isEmpty ? 0 : (event.totalSpent / transactions.length).toStringAsFixed(2)}');
      csv.writeln('Daily Average,${(event.totalSpent / event.duration).toStringAsFixed(2)}');

      if (event.budget != null && event.budget! > 0) {
        csv.writeln('Budget Usage,${((event.totalSpent / event.budget!) * 100).toStringAsFixed(1)}%');
      }

      // Save and share
      await _saveAndShareFile(
        content: csv.toString(),
        fileName: 'travel_${event.name.replaceAll(' ', '_')}_${_dateFormat.format(DateTime.now())}.csv',
        mimeType: 'text/csv',
      );

    } catch (e) {
      throw Exception('Failed to export to CSV: $e');
    }
  }

  /// Export travel summary to HTML format (can be converted to PDF)
  Future<void> exportToHTML({
    required TravelEvent event,
    required List<Transaction> transactions,
    Map<String, double>? categoryBudgets,
  }) async {
    try {
      // Build HTML content
      final StringBuffer html = StringBuffer();

      html.writeln('''
<!DOCTYPE html>
<html lang="zh">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Travel Report - ${event.name}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            margin: 0;
            padding: 20px;
            color: #333;
            line-height: 1.6;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 30px;
        }
        .header h1 {
            margin: 0 0 10px 0;
            font-size: 28px;
        }
        .header .subtitle {
            opacity: 0.9;
            font-size: 16px;
        }
        .section {
            background: white;
            border: 1px solid #e0e0e0;
            border-radius: 8px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        .section h2 {
            color: #667eea;
            margin-top: 0;
            border-bottom: 2px solid #f0f0f0;
            padding-bottom: 10px;
        }
        .info-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 15px;
            margin-top: 15px;
        }
        .info-item {
            display: flex;
            justify-content: space-between;
            padding: 8px;
            background: #f8f9fa;
            border-radius: 5px;
        }
        .info-label {
            font-weight: 500;
            color: #666;
        }
        .info-value {
            font-weight: 600;
            color: #333;
        }
        .budget-bar {
            width: 100%;
            height: 30px;
            background: #e0e0e0;
            border-radius: 15px;
            overflow: hidden;
            margin: 15px 0;
        }
        .budget-fill {
            height: 100%;
            background: linear-gradient(90deg, #4caf50, #8bc34a);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: 600;
            font-size: 14px;
        }
        .budget-fill.over {
            background: linear-gradient(90deg, #ff5252, #ff9800);
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 15px;
        }
        th {
            background: #f5f5f5;
            padding: 12px;
            text-align: left;
            font-weight: 600;
            color: #666;
            border-bottom: 2px solid #e0e0e0;
        }
        td {
            padding: 10px 12px;
            border-bottom: 1px solid #f0f0f0;
        }
        tr:hover {
            background: #fafafa;
        }
        .amount {
            font-weight: 600;
            text-align: right;
        }
        .amount.expense {
            color: #ff5252;
        }
        .amount.income {
            color: #4caf50;
        }
        .statistics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 10px;
            text-align: center;
        }
        .stat-value {
            font-size: 28px;
            font-weight: bold;
            margin: 10px 0;
        }
        .stat-label {
            opacity: 0.9;
            font-size: 14px;
        }
        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 2px solid #f0f0f0;
            text-align: center;
            color: #999;
            font-size: 14px;
        }
        @media print {
            body {
                padding: 10px;
            }
            .section {
                box-shadow: none;
                break-inside: avoid;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🏝️ ${event.name}</h1>
        <div class="subtitle">
            📍 ${event.destination ?? 'Unknown Destination'} |
            📅 ${_dateFormat.format(event.startDate)} - ${_dateFormat.format(event.endDate)}
        </div>
    </div>
''');

      // Travel Information Section
      html.writeln('''
    <div class="section">
        <h2>📋 Travel Information</h2>
        <div class="info-grid">
            <div class="info-item">
                <span class="info-label">Duration</span>
                <span class="info-value">${event.duration} days</span>
            </div>
            <div class="info-item">
                <span class="info-label">Status</span>
                <span class="info-value">${_getStatusLabel(event.computedStatus)}</span>
            </div>
            <div class="info-item">
                <span class="info-label">Currency</span>
                <span class="info-value">${event.currency}</span>
            </div>
            <div class="info-item">
                <span class="info-label">Transactions</span>
                <span class="info-value">${event.transactionCount}</span>
            </div>
        </div>
''');

      if (event.notes != null && event.notes!.isNotEmpty) {
        html.writeln('''
        <div style="margin-top: 15px; padding: 15px; background: #fff9e6; border-left: 4px solid #ffc107; border-radius: 5px;">
            <strong>Notes:</strong> ${event.notes}
        </div>
''');
      }

      html.writeln('    </div>');

      // Budget Section
      if (event.budget != null && event.budget! > 0) {
        final percentage = (event.totalSpent / event.budget!) * 100;
        final isOver = percentage > 100;

        html.writeln('''
    <div class="section">
        <h2>💰 Budget Overview</h2>
        <div class="info-grid">
            <div class="info-item">
                <span class="info-label">Budget</span>
                <span class="info-value">${_currencyFormatter.format(event.budget!, event.currency)}</span>
            </div>
            <div class="info-item">
                <span class="info-label">Spent</span>
                <span class="info-value">${_currencyFormatter.format(event.totalSpent, event.currency)}</span>
            </div>
            <div class="info-item">
                <span class="info-label">Remaining</span>
                <span class="info-value ${isOver ? 'style="color: #ff5252;"' : 'style="color: #4caf50;"'}">${_currencyFormatter.format(event.budget! - event.totalSpent, event.currency)}</span>
            </div>
        </div>
        <div class="budget-bar">
            <div class="budget-fill ${isOver ? 'over' : ''}" style="width: ${percentage.clamp(0, 100)}%;">
                ${percentage.toStringAsFixed(1)}%
            </div>
        </div>
    </div>
''');
      }

      // Statistics Section
      html.writeln('''
    <div class="section">
        <h2>📊 Statistics</h2>
        <div class="statistics-grid">
            <div class="stat-card">
                <div class="stat-label">Total Spent</div>
                <div class="stat-value">${_currencyFormatter.format(event.totalSpent, event.currency)}</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Daily Average</div>
                <div class="stat-value">${_currencyFormatter.format(event.totalSpent / event.duration, event.currency)}</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Transaction Count</div>
                <div class="stat-value">${transactions.length}</div>
            </div>
            <div class="stat-card">
                <div class="stat-label">Avg Transaction</div>
                <div class="stat-value">${transactions.isEmpty ? '0' : _currencyFormatter.format(event.totalSpent / transactions.length, event.currency)}</div>
            </div>
        </div>
    </div>
''');

      // Transactions Table
      if (transactions.isNotEmpty) {
        html.writeln('''
    <div class="section">
        <h2>📝 Transaction Details</h2>
        <table>
            <thead>
                <tr>
                    <th>Date</th>
                    <th>Payee</th>
                    <th>Category</th>
                    <th>Description</th>
                    <th style="text-align: right;">Amount</th>
                </tr>
            </thead>
            <tbody>
''');

        for (var transaction in transactions) {
          final isExpense = transaction.amount < 0;
          html.writeln('''
                <tr>
                    <td>${_dateTimeFormat.format(transaction.date)}</td>
                    <td>${transaction.payee ?? 'Unknown'}</td>
                    <td>${_getCategoryName(transaction.category ?? 'other')}</td>
                    <td>${transaction.description}</td>
                    <td class="amount ${isExpense ? 'expense' : 'income'}">
                        ${_currencyFormatter.format(transaction.amount.abs(), event.currency)}
                    </td>
                </tr>
''');
        }

        html.writeln('''
            </tbody>
        </table>
    </div>
''');
      }

      // Footer
      html.writeln('''
    <div class="footer">
        <p>Generated by Jive Money on ${_dateFormat.format(DateTime.now())}</p>
        <p>© 2025 Jive Money - Personal Finance Management</p>
    </div>
</body>
</html>
''');

      // Save and share
      await _saveAndShareFile(
        content: html.toString(),
        fileName: 'travel_${event.name.replaceAll(' ', '_')}_${_dateFormat.format(DateTime.now())}.html',
        mimeType: 'text/html',
      );

    } catch (e) {
      throw Exception('Failed to export to HTML: $e');
    }
  }

  /// Export travel data to JSON format
  Future<void> exportToJSON({
    required TravelEvent event,
    required List<Transaction> transactions,
    Map<String, double>? categoryBudgets,
  }) async {
    try {
      final Map<String, dynamic> exportData = {
        'metadata': {
          'exportDate': DateTime.now().toIso8601String(),
          'version': '1.0.0',
          'app': 'Jive Money',
        },
        'travelEvent': {
          'id': event.id,
          'name': event.name,
          'destination': event.destination,
          'startDate': event.startDate.toIso8601String(),
          'endDate': event.endDate.toIso8601String(),
          'duration': event.duration,
          'budget': event.budget,
          'totalSpent': event.totalSpent,
          'currency': event.currency,
          'status': event.computedStatus.toString(),
          'notes': event.notes,
          'transactionCount': event.transactionCount,
        },
        'categoryBudgets': categoryBudgets ?? {},
        'transactions': transactions.map((t) => {
          'id': t.id,
          'date': t.date.toIso8601String(),
          'amount': t.amount,
          'payee': t.payee,
          'category': t.category,
          'description': t.description,
          'accountId': t.accountId,
        }).toList(),
        'statistics': {
          'totalTransactions': transactions.length,
          'dailyAverage': event.duration > 0 ? event.totalSpent / event.duration : 0,
          'averageTransaction': transactions.isNotEmpty ? event.totalSpent / transactions.length : 0,
          'budgetUsagePercentage': event.budget != null && event.budget! > 0
              ? (event.totalSpent / event.budget!) * 100
              : null,
          'categoryBreakdown': _calculateCategoryBreakdown(transactions),
        },
      };

      // Pretty print JSON
      final encoder = const JsonEncoder.withIndent('  ');
      final jsonString = encoder.convert(exportData);

      // Save and share
      await _saveAndShareFile(
        content: jsonString,
        fileName: 'travel_${event.name.replaceAll(' ', '_')}_${_dateFormat.format(DateTime.now())}.json',
        mimeType: 'application/json',
      );

    } catch (e) {
      throw Exception('Failed to export to JSON: $e');
    }
  }

  /// Helper method to save and share a file
  Future<void> _saveAndShareFile({
    required String content,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      // Get temporary directory
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$fileName');

      // Write content to file
      await file.writeAsString(content);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path, mimeType: mimeType)],
        subject: 'Travel Report Export',
        text: 'Travel report exported from Jive Money',
      );

    } catch (e) {
      throw Exception('Failed to save/share file: $e');
    }
  }

  /// Get human-readable category name
  String _getCategoryName(String categoryId) {
    final categories = {
      'accommodation': '住宿',
      'transportation': '交通',
      'dining': '餐饮',
      'attractions': '景点',
      'shopping': '购物',
      'entertainment': '娱乐',
      'other': '其他',
    };
    return categories[categoryId] ?? categoryId;
  }

  /// Get status label
  String _getStatusLabel(TravelEventStatus status) {
    switch (status) {
      case TravelEventStatus.upcoming:
        return '即将开始';
      case TravelEventStatus.ongoing:
        return '进行中';
      case TravelEventStatus.completed:
        return '已完成';
      case TravelEventStatus.cancelled:
        return '已取消';
    }
  }

  /// Calculate category breakdown
  Map<String, double> _calculateCategoryBreakdown(List<Transaction> transactions) {
    final Map<String, double> breakdown = {};

    for (var transaction in transactions) {
      final category = transaction.category ?? 'other';
      breakdown[category] = (breakdown[category] ?? 0) + transaction.amount.abs();
    }

    return breakdown;
  }
}