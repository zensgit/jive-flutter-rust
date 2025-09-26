// 预算表单组件
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jive_money/core/constants/app_constants.dart';
import 'package:jive_money/ui/components/buttons/primary_button.dart';
import 'package:jive_money/ui/components/buttons/secondary_button.dart';

class BudgetForm extends StatefulWidget {
  final BudgetFormData? initialData;
  final Function(BudgetFormData) onSubmit;
  final VoidCallback? onCancel;
  final List<String> availableCategories;

  const BudgetForm({
    super.key,
    this.initialData,
    required this.onSubmit,
    this.onCancel,
    this.availableCategories = const [],
  });

  @override
  State<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _amountController;
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  late String? _selectedCategory;
  late BudgetPeriod _period;
  late DateTime _startDate;
  late DateTime? _endDate;
  late bool _rollover;
  late bool _notifyOnThreshold;
  late double _notificationThreshold;

  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();

    final initial = widget.initialData;
    _amountController = TextEditingController(
      text: initial?.amount.toStringAsFixed(2) ?? '',
    );
    _nameController = TextEditingController(text: initial?.name ?? '');
    _descriptionController =
        TextEditingController(text: initial?.description ?? '');

    _selectedCategory = initial?.category;
    _period = initial?.period ?? BudgetPeriod.monthly;
    _startDate = initial?.startDate ?? DateTime.now();
    _endDate = initial?.endDate;
    _rollover = initial?.rollover ?? false;
    _notifyOnThreshold = initial?.notifyOnThreshold ?? true;
    _notificationThreshold = initial?.notificationThreshold ?? 0.8;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 预算名称
            _buildNameField(theme),

            const SizedBox(height: 16),

            // 分类选择
            _buildCategorySelector(theme),

            const SizedBox(height: 16),

            // 预算金额
            _buildAmountField(theme),

            const SizedBox(height: 16),

            // 周期选择
            _buildPeriodSelector(theme),

            const SizedBox(height: 16),

            // 日期选择
            _buildDateSelectors(theme),

            const SizedBox(height: 20),

            // 高级选项
            _buildAdvancedOptions(theme),

            const SizedBox(height: 16),

            // 描述
            _buildDescriptionField(theme),

            const SizedBox(height: 24),

            // 操作按钮
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField(ThemeData theme) {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: '预算名称',
        hintText: '例如：本月生活费',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入预算名称';
        }
        return null;
      },
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    final categories = widget.availableCategories.isNotEmpty
        ? widget.availableCategories
        : ['餐饮', '交通', '购物', '娱乐', '住房', '医疗', '教育', '其他'];

    return DropdownButtonFormField<String>(
      initialValue: _selectedCategory,
      decoration: InputDecoration(
        labelText: '分类',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('全部分类'),
        ),
        ...categories.map(
          (category) => DropdownMenuItem(
            value: category,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category),
                    shape: BoxShape.circle,
                  ),
                ),
                Text(category),
              ],
            ),
          ),
        ),
      ],
      onChanged: (value) => setState(() => _selectedCategory = value),
    );
  }

  Widget _buildAmountField(ThemeData theme) {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: '预算金额',
        prefixText: '¥ ',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        helperText: _getPeriodHelperText(),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入预算金额';
        }
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          return '请输入有效金额';
        }
        return null;
      },
    );
  }

  Widget _buildPeriodSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '预算周期',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              _buildPeriodButton(theme, BudgetPeriod.weekly, '每周'),
              _buildPeriodButton(theme, BudgetPeriod.monthly, '每月'),
              _buildPeriodButton(theme, BudgetPeriod.quarterly, '每季'),
              _buildPeriodButton(theme, BudgetPeriod.yearly, '每年'),
              _buildPeriodButton(theme, BudgetPeriod.custom, '自定义'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodButton(
      ThemeData theme, BudgetPeriod period, String label) {
    final isSelected = _period == period;

    return Expanded(
      child: Material(
        color: isSelected
            ? theme.primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        child: InkWell(
          onTap: () => setState(() => _period = period),
          borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? theme.primaryColor
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateSelectors(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _selectDate(true),
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '开始日期',
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppConstants.borderRadius),
                ),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              child: Text(
                _formatDate(_startDate),
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ),
        ),
        if (_period == BudgetPeriod.custom) ...[
          const SizedBox(width: 16),
          Expanded(
            child: InkWell(
              onTap: () => _selectDate(false),
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '结束日期',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadius),
                  ),
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(
                  _endDate != null ? _formatDate(_endDate!) : '选择日期',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAdvancedOptions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '高级选项',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),

        // 余额滚动
        SwitchListTile(
          title: const Text('余额滚动'),
          subtitle: const Text('未使用的预算滚动到下一周期'),
          value: _rollover,
          onChanged: (value) => setState(() => _rollover = value),
        ),

        // 通知设置
        SwitchListTile(
          title: const Text('预算提醒'),
          subtitle: const Text('接近预算上限时发送通知'),
          value: _notifyOnThreshold,
          onChanged: (value) => setState(() => _notifyOnThreshold = value),
        ),

        // 通知阈值
        if (_notifyOnThreshold)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('提醒阈值'),
                const SizedBox(width: 16),
                Expanded(
                  child: Slider(
                    value: _notificationThreshold,
                    min: 0.5,
                    max: 1.0,
                    divisions: 10,
                    label: '${(_notificationThreshold * 100).toInt()}%',
                    onChanged: (value) =>
                        setState(() => _notificationThreshold = value),
                  ),
                ),
                Text(
                  '${(_notificationThreshold * 100).toInt()}%',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: '描述（可选）',
        hintText: '添加预算说明',
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (widget.onCancel != null)
          Expanded(
            child: SecondaryButton(
              onPressed: widget.onCancel!,
              text: '取消',
            ),
          ),
        if (widget.onCancel != null) const SizedBox(width: 16),
        Expanded(
          child: PrimaryButton(
            onPressed: _handleSubmit,
            text: widget.initialData != null ? '更新' : '创建',
          ),
        ),
      ],
    );
  }

  String _getPeriodHelperText() {
    switch (_period) {
      case BudgetPeriod.weekly:
        return '每周预算金额';
      case BudgetPeriod.monthly:
        return '每月预算金额';
      case BudgetPeriod.quarterly:
        return '每季度预算金额';
      case BudgetPeriod.yearly:
        return '每年预算金额';
      case BudgetPeriod.custom:
        return '自定义周期预算金额';
    }
  }

  Color _getCategoryColor(String category) {
    // 这里应该从常量或配置中获取颜色
    final colors = {
      '餐饮': Colors.orange,
      '交通': Colors.blue,
      '购物': Colors.purple,
      '娱乐': Colors.pink,
      '住房': Colors.green,
      '医疗': Colors.red,
      '教育': Colors.teal,
      '其他': Colors.grey,
    };
    return colors[category] ?? Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text);

      // 根据周期自动计算结束日期
      if (_period != BudgetPeriod.custom && _endDate == null) {
        switch (_period) {
          case BudgetPeriod.weekly:
            _endDate = _startDate.add(const Duration(days: 7));
            break;
          case BudgetPeriod.monthly:
            _endDate =
                DateTime(_startDate.year, _startDate.month + 1, _startDate.day);
            break;
          case BudgetPeriod.quarterly:
            _endDate =
                DateTime(_startDate.year, _startDate.month + 3, _startDate.day);
            break;
          case BudgetPeriod.yearly:
            _endDate =
                DateTime(_startDate.year + 1, _startDate.month, _startDate.day);
            break;
          default:
            break;
        }
      }

      widget.onSubmit(BudgetFormData(
        name: _nameController.text,
        category: _selectedCategory,
        amount: amount,
        period: _period,
        startDate: _startDate,
        endDate: _endDate,
        rollover: _rollover,
        notifyOnThreshold: _notifyOnThreshold,
        notificationThreshold: _notificationThreshold,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
      ));
    }
  }
}

/// 预算周期枚举
enum BudgetPeriod {
  weekly,
  monthly,
  quarterly,
  yearly,
  custom,
}

/// 预算表单数据模型
class BudgetFormData {
  final String name;
  final String? category;
  final double amount;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime? endDate;
  final bool rollover;
  final bool notifyOnThreshold;
  final double notificationThreshold;
  final String? description;

  const BudgetFormData({
    required this.name,
    this.category,
    required this.amount,
    required this.period,
    required this.startDate,
    this.endDate,
    required this.rollover,
    required this.notifyOnThreshold,
    required this.notificationThreshold,
    this.description,
  });
}
