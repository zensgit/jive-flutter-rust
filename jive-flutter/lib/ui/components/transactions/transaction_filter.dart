// 交易筛选组件
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import 'transaction_form.dart';

class TransactionFilter extends StatefulWidget {
  final TransactionFilterData? initialFilter;
  final Function(TransactionFilterData) onApply;
  final VoidCallback? onReset;

  const TransactionFilter({
    super.key,
    this.initialFilter,
    required this.onApply,
    this.onReset,
  });

  @override
  State<TransactionFilter> createState() => _TransactionFilterState();
}

class _TransactionFilterState extends State<TransactionFilter> {
  late TransactionFilterData _filter;
  late TextEditingController _searchController;
  late TextEditingController _minAmountController;
  late TextEditingController _maxAmountController;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? TransactionFilterData();
    _searchController = TextEditingController(text: _filter.searchText);
    _minAmountController = TextEditingController(
      text: _filter.minAmount?.toString() ?? '',
    );
    _maxAmountController = TextEditingController(
      text: _filter.maxAmount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Row(
            children: [
              Text(
                '筛选交易',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (widget.onReset != null)
                TextButton(
                  onPressed: _handleReset,
                  child: const Text('重置'),
                ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 搜索框
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: '搜索',
              hintText: '搜索描述、备注或收款方',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
            ),
            onChanged: (value) => _filter = _filter.copyWith(searchText: value),
          ),
          
          const SizedBox(height: 16),
          
          // 交易类型
          _buildTypeFilter(theme),
          
          const SizedBox(height: 16),
          
          // 日期范围
          _buildDateRangeFilter(theme),
          
          const SizedBox(height: 16),
          
          // 金额范围
          _buildAmountRangeFilter(theme),
          
          const SizedBox(height: 16),
          
          // 账户选择
          _buildAccountFilter(theme),
          
          const SizedBox(height: 16),
          
          // 分类选择
          _buildCategoryFilter(theme),
          
          const SizedBox(height: 16),
          
          // 标签选择
          _buildTagFilter(theme),
          
          const SizedBox(height: 24),
          
          // 操作按钮
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTypeFilter(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '交易类型',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('全部'),
              selected: _filter.types.isEmpty,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _filter = _filter.copyWith(types: []);
                  }
                });
              },
            ),
            FilterChip(
              label: const Text('支出'),
              selected: _filter.types.contains(TransactionType.expense),
              onSelected: (selected) {
                setState(() {
                  final types = List<TransactionType>.from(_filter.types);
                  if (selected) {
                    types.add(TransactionType.expense);
                  } else {
                    types.remove(TransactionType.expense);
                  }
                  _filter = _filter.copyWith(types: types);
                });
              },
            ),
            FilterChip(
              label: const Text('收入'),
              selected: _filter.types.contains(TransactionType.income),
              onSelected: (selected) {
                setState(() {
                  final types = List<TransactionType>.from(_filter.types);
                  if (selected) {
                    types.add(TransactionType.income);
                  } else {
                    types.remove(TransactionType.income);
                  }
                  _filter = _filter.copyWith(types: types);
                });
              },
            ),
            FilterChip(
              label: const Text('转账'),
              selected: _filter.types.contains(TransactionType.transfer),
              onSelected: (selected) {
                setState(() {
                  final types = List<TransactionType>.from(_filter.types);
                  if (selected) {
                    types.add(TransactionType.transfer);
                  } else {
                    types.remove(TransactionType.transfer);
                  }
                  _filter = _filter.copyWith(types: types);
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateRangeFilter(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '日期范围',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(true),
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '开始日期',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                  ),
                  child: Text(
                    _filter.startDate != null 
                        ? _formatDate(_filter.startDate!)
                        : '选择日期',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: InkWell(
                onTap: () => _selectDate(false),
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: '结束日期',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                    ),
                  ),
                  child: Text(
                    _filter.endDate != null 
                        ? _formatDate(_filter.endDate!)
                        : '选择日期',
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ActionChip(
              label: const Text('今天'),
              onPressed: () => _setDateRange(DateRange.today),
            ),
            ActionChip(
              label: const Text('本周'),
              onPressed: () => _setDateRange(DateRange.thisWeek),
            ),
            ActionChip(
              label: const Text('本月'),
              onPressed: () => _setDateRange(DateRange.thisMonth),
            ),
            ActionChip(
              label: const Text('上月'),
              onPressed: () => _setDateRange(DateRange.lastMonth),
            ),
            ActionChip(
              label: const Text('今年'),
              onPressed: () => _setDateRange(DateRange.thisYear),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountRangeFilter(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '金额范围',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _minAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '最小金额',
                  prefixText: '¥',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                ),
                onChanged: (value) {
                  final amount = double.tryParse(value);
                  _filter = _filter.copyWith(minAmount: amount);
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _maxAmountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '最大金额',
                  prefixText: '¥',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                  ),
                ),
                onChanged: (value) {
                  final amount = double.tryParse(value);
                  _filter = _filter.copyWith(maxAmount: amount);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountFilter(ThemeData theme) {
    // 这里应该从状态管理中获取账户列表
    final accounts = ['现金', '支付宝', '微信', '银行卡'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '账户',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: accounts.map((account) => 
            FilterChip(
              label: Text(account),
              selected: _filter.accounts.contains(account),
              onSelected: (selected) {
                setState(() {
                  final accounts = List<String>.from(_filter.accounts);
                  if (selected) {
                    accounts.add(account);
                  } else {
                    accounts.remove(account);
                  }
                  _filter = _filter.copyWith(accounts: accounts);
                });
              },
            ),
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter(ThemeData theme) {
    // 这里应该从状态管理中获取分类列表
    final categories = ['餐饮', '交通', '购物', '娱乐', '住房', '工资', '奖金', '投资'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '分类',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: categories.map((category) => 
            FilterChip(
              label: Text(category),
              selected: _filter.categories.contains(category),
              onSelected: (selected) {
                setState(() {
                  final categories = List<String>.from(_filter.categories);
                  if (selected) {
                    categories.add(category);
                  } else {
                    categories.remove(category);
                  }
                  _filter = _filter.copyWith(categories: categories);
                });
              },
            ),
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildTagFilter(ThemeData theme) {
    // 这里应该从状态管理中获取标签列表
    final tags = ['日常', '旅行', '医疗', '教育', '娱乐', '投资'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '标签',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: tags.map((tag) => 
            FilterChip(
              label: Text(tag),
              selected: _filter.tags.contains(tag),
              onSelected: (selected) {
                setState(() {
                  final tags = List<String>.from(_filter.tags);
                  if (selected) {
                    tags.add(tag);
                  } else {
                    tags.remove(tag);
                  }
                  _filter = _filter.copyWith(tags: tags);
                });
              },
            ),
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _handleApply,
            child: const Text('应用筛选'),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _filter.startDate : _filter.endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        if (isStart) {
          _filter = _filter.copyWith(startDate: picked);
        } else {
          _filter = _filter.copyWith(endDate: picked);
        }
      });
    }
  }

  void _setDateRange(DateRange range) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;
    
    switch (range) {
      case DateRange.today:
        start = DateTime(now.year, now.month, now.day);
        end = start;
        break;
      case DateRange.thisWeek:
        final weekday = now.weekday;
        start = now.subtract(Duration(days: weekday - 1));
        end = now;
        break;
      case DateRange.thisMonth:
        start = DateTime(now.year, now.month, 1);
        end = now;
        break;
      case DateRange.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1, 1);
        start = lastMonth;
        end = DateTime(now.year, now.month, 0);
        break;
      case DateRange.thisYear:
        start = DateTime(now.year, 1, 1);
        end = now;
        break;
    }
    
    setState(() {
      _filter = _filter.copyWith(
        startDate: start,
        endDate: end,
      );
    });
  }

  void _handleReset() {
    setState(() {
      _filter = TransactionFilterData();
      _searchController.clear();
      _minAmountController.clear();
      _maxAmountController.clear();
    });
    
    widget.onReset?.call();
  }

  void _handleApply() {
    widget.onApply(_filter);
    Navigator.of(context).pop();
  }
}

/// 日期范围枚举
enum DateRange {
  today,
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
}

/// 交易筛选数据模型
class TransactionFilterData {
  final String? searchText;
  final List<TransactionType> types;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final double? maxAmount;
  final List<String> accounts;
  final List<String> categories;
  final List<String> tags;

  TransactionFilterData({
    this.searchText,
    this.types = const [],
    this.startDate,
    this.endDate,
    this.minAmount,
    this.maxAmount,
    this.accounts = const [],
    this.categories = const [],
    this.tags = const [],
  });

  TransactionFilterData copyWith({
    String? searchText,
    List<TransactionType>? types,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    double? maxAmount,
    List<String>? accounts,
    List<String>? categories,
    List<String>? tags,
  }) {
    return TransactionFilterData(
      searchText: searchText ?? this.searchText,
      types: types ?? this.types,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      accounts: accounts ?? this.accounts,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
    );
  }

  bool get hasFilters =>
      searchText?.isNotEmpty == true ||
      types.isNotEmpty ||
      startDate != null ||
      endDate != null ||
      minAmount != null ||
      maxAmount != null ||
      accounts.isNotEmpty ||
      categories.isNotEmpty ||
      tags.isNotEmpty;
}