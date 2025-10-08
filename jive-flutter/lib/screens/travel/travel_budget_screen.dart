import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/travel_event.dart';
import '../../providers/travel_provider.dart';
import '../../utils/currency_formatter.dart';

class TravelBudgetScreen extends ConsumerStatefulWidget {
  final TravelEvent travelEvent;

  const TravelBudgetScreen({
    Key? key,
    required this.travelEvent,
  }) : super(key: key);

  @override
  ConsumerState<TravelBudgetScreen> createState() => _TravelBudgetScreenState();
}

class _TravelBudgetScreenState extends ConsumerState<TravelBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalBudgetController = TextEditingController();

  // Category budget controllers
  final Map<String, TextEditingController> _categoryBudgetControllers = {};

  // Common travel categories
  final List<Map<String, dynamic>> _categories = [
    {'id': 'accommodation', 'name': '住宿', 'icon': Icons.hotel, 'color': Colors.blue},
    {'id': 'transportation', 'name': '交通', 'icon': Icons.directions_car, 'color': Colors.green},
    {'id': 'dining', 'name': '餐饮', 'icon': Icons.restaurant, 'color': Colors.orange},
    {'id': 'attractions', 'name': '景点', 'icon': Icons.attractions, 'color': Colors.purple},
    {'id': 'shopping', 'name': '购物', 'icon': Icons.shopping_bag, 'color': Colors.pink},
    {'id': 'entertainment', 'name': '娱乐', 'icon': Icons.sports_esports, 'color': Colors.red},
    {'id': 'other', 'name': '其他', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  bool _isLoading = false;
  Map<String, double> _currentSpending = {};

  @override
  void initState() {
    super.initState();
    _totalBudgetController.text = widget.travelEvent.budget?.toStringAsFixed(2) ?? '';

    // Initialize category controllers
    for (var category in _categories) {
      _categoryBudgetControllers[category['id']] = TextEditingController();
    }

    _loadCurrentSpending();
  }

  @override
  void dispose() {
    _totalBudgetController.dispose();
    _categoryBudgetControllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _loadCurrentSpending() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Load actual spending by category from API
      // For now, using mock data
      _currentSpending = {
        'accommodation': 5000.0,
        'transportation': 3000.0,
        'dining': 2500.0,
        'attractions': 1500.0,
        'shopping': 2000.0,
        'entertainment': 1000.0,
        'other': 500.0,
      };
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final totalBudget = double.tryParse(_totalBudgetController.text) ?? 0;

      // Save total budget
      final travelService = ref.read(travelServiceProvider);
      await travelService.updateEvent(
        widget.travelEvent.id!,
        widget.travelEvent.copyWith(
          budget: totalBudget,
        ),
      );

      // Save category budgets
      for (var category in _categories) {
        final budgetText = _categoryBudgetControllers[category['id']]!.text;
        if (budgetText.isNotEmpty) {
          final budget = double.tryParse(budgetText);
          if (budget != null && budget > 0) {
            await travelService.updateBudget(
              widget.travelEvent.id!,
              category['id'],
              budget,
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('预算保存成功')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildCategoryBudgetItem(Map<String, dynamic> category) {
    final currencyFormatter = CurrencyFormatter();
    final spending = _currentSpending[category['id']] ?? 0.0;
    final controller = _categoryBudgetControllers[category['id']]!;
    final budgetText = controller.text;
    final budget = budgetText.isNotEmpty ? (double.tryParse(budgetText) ?? 0.0) : 0.0;
    final percentage = budget > 0 ? (spending / budget * 100).clamp(0, 100) : 0.0;
    final isOverBudget = spending > budget && budget > 0;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  category['icon'] as IconData,
                  color: category['color'] as Color,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category['name'],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  currencyFormatter.format(spending, widget.travelEvent.currency),
                  style: TextStyle(
                    color: isOverBudget ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Budget input
            TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '预算金额',
                prefixText: '${widget.travelEvent.currency} ',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final budget = double.tryParse(value);
                  if (budget == null || budget < 0) {
                    return '请输入有效的金额';
                  }
                }
                return null;
              },
              onChanged: (_) {
                setState(() {}); // Trigger rebuild for percentage update
              },
            ),

            if (budget > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverBudget ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已使用 ${percentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '剩余: ${currencyFormatter.format(
                      (budget - spending).clamp(0, double.infinity),
                      widget.travelEvent.currency,
                    )}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isOverBudget ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormatter = CurrencyFormatter();
    final totalSpent = _currentSpending.values.fold(0.0, (sum, value) => sum + value);
    final totalBudget = double.tryParse(_totalBudgetController.text) ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('预算管理 - ${widget.travelEvent.name}'),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveBudget,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Total budget card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '总预算',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _totalBudgetController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '总预算金额',
                              prefixText: '${widget.travelEvent.currency} ',
                              border: const OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final budget = double.tryParse(value);
                                if (budget == null || budget < 0) {
                                  return '请输入有效的金额';
                                }
                              }
                              return null;
                            },
                            onChanged: (_) {
                              setState(() {}); // Trigger rebuild
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('总花费'),
                              Text(
                                currencyFormatter.format(totalSpent, widget.travelEvent.currency),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: totalSpent > totalBudget && totalBudget > 0
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                          if (totalBudget > 0) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: (totalSpent / totalBudget).clamp(0.0, 1.0),
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                totalSpent > totalBudget ? Colors.red : Colors.green,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '已使用 ${((totalSpent / totalBudget) * 100).toStringAsFixed(1)}%',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category budgets
                  Text(
                    '分类预算',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '为每个分类设置独立的预算（可选）',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ..._categories.map(_buildCategoryBudgetItem),
                ],
              ),
            ),
      floatingActionButton: !_isLoading
          ? FloatingActionButton.extended(
              onPressed: _saveBudget,
              label: const Text('保存预算'),
              icon: const Icon(Icons.save),
            )
          : null,
    );
  }
}