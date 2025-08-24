// 交易表单组件
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class TransactionForm extends StatefulWidget {
  final TransactionFormData? initialData;
  final Function(TransactionFormData) onSubmit;
  final VoidCallback? onCancel;
  final bool isExpense;

  const TransactionForm({
    super.key,
    this.initialData,
    required this.onSubmit,
    this.onCancel,
    this.isExpense = true,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _noteController;
  late final TextEditingController _payeeController;
  
  late TransactionType _type;
  late DateTime _selectedDate;
  String? _selectedCategory;
  String? _selectedAccount;
  List<String> _selectedTags = [];
  
  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    
    final initial = widget.initialData;
    _amountController = TextEditingController(
      text: initial?.amount.toStringAsFixed(2) ?? '',
    );
    _descriptionController = TextEditingController(
      text: initial?.description ?? '',
    );
    _noteController = TextEditingController(
      text: initial?.note ?? '',
    );
    _payeeController = TextEditingController(
      text: initial?.payee ?? '',
    );
    
    _type = initial?.type ?? (widget.isExpense ? TransactionType.expense : TransactionType.income);
    _selectedDate = initial?.date ?? DateTime.now();
    _selectedCategory = initial?.category;
    _selectedAccount = initial?.account;
    _selectedTags = initial?.tags ?? [];
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    _payeeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 交易类型选择
          _buildTypeSelector(theme),
          
          const SizedBox(height: 20),
          
          // 金额输入
          _buildAmountField(theme),
          
          const SizedBox(height: 16),
          
          // 描述输入
          _buildDescriptionField(theme),
          
          const SizedBox(height: 16),
          
          // 日期选择
          _buildDateSelector(theme),
          
          const SizedBox(height: 16),
          
          // 账户选择
          _buildAccountSelector(theme),
          
          const SizedBox(height: 16),
          
          // 分类选择
          _buildCategorySelector(theme),
          
          const SizedBox(height: 16),
          
          // 收款方/付款方
          _buildPayeeField(theme),
          
          const SizedBox(height: 16),
          
          // 标签选择
          _buildTagSelector(theme),
          
          const SizedBox(height: 16),
          
          // 备注输入
          _buildNoteField(theme),
          
          const SizedBox(height: 24),
          
          // 操作按钮
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeButton(
              theme,
              TransactionType.expense,
              '支出',
              Icons.remove_circle_outline,
              AppConstants.errorColor,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTypeButton(
              theme,
              TransactionType.income,
              '收入',
              Icons.add_circle_outline,
              AppConstants.successColor,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTypeButton(
              theme,
              TransactionType.transfer,
              '转账',
              Icons.swap_horiz,
              AppConstants.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeButton(
    ThemeData theme,
    TransactionType type,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _type == type;
    
    return Material(
      color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
      child: InkWell(
        onTap: () => setState(() => _type = type),
        borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? color : theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected ? color : theme.colorScheme.onSurface.withOpacity(0.6),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAmountField(ThemeData theme) {
    return TextFormField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
      ],
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: _getAmountColor(),
      ),
      decoration: InputDecoration(
        labelText: '金额',
        prefixText: '¥ ',
        prefixStyle: theme.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: _getAmountColor(),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入金额';
        }
        final amount = double.tryParse(value);
        if (amount == null || amount <= 0) {
          return '请输入有效金额';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return TextFormField(
      controller: _descriptionController,
      decoration: InputDecoration(
        labelText: '描述',
        hintText: '输入交易描述',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入描述';
        }
        return null;
      },
    );
  }

  Widget _buildDateSelector(ThemeData theme) {
    return InkWell(
      onTap: _selectDate,
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '日期',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          _formatDate(_selectedDate),
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildAccountSelector(ThemeData theme) {
    // 这里应该从状态管理中获取账户列表
    final accounts = ['现金', '支付宝', '微信', '银行卡'];
    
    return DropdownButtonFormField<String>(
      value: _selectedAccount,
      decoration: InputDecoration(
        labelText: '账户',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      items: accounts.map((account) => 
        DropdownMenuItem(
          value: account,
          child: Text(account),
        ),
      ).toList(),
      onChanged: (value) => setState(() => _selectedAccount = value),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请选择账户';
        }
        return null;
      },
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    // 这里应该从状态管理中获取分类列表
    final categories = _type == TransactionType.expense 
        ? ['餐饮', '交通', '购物', '娱乐', '住房']
        : ['工资', '奖金', '投资', '生意', '其他'];
    
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: '分类',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      items: categories.map((category) => 
        DropdownMenuItem(
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
      ).toList(),
      onChanged: (value) => setState(() => _selectedCategory = value),
    );
  }

  Widget _buildPayeeField(ThemeData theme) {
    return TextFormField(
      controller: _payeeController,
      decoration: InputDecoration(
        labelText: _type == TransactionType.expense ? '收款方' : '付款方',
        hintText: _type == TransactionType.expense ? '输入收款方' : '输入付款方',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        suffixIcon: const Icon(Icons.person_outline),
      ),
    );
  }

  Widget _buildTagSelector(ThemeData theme) {
    return InkWell(
      onTap: _selectTags,
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '标签',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          suffixIcon: const Icon(Icons.label_outline),
        ),
        child: _selectedTags.isEmpty
            ? Text(
                '选择标签',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              )
            : Wrap(
                spacing: 8,
                children: _selectedTags.map((tag) => 
                  Chip(
                    label: Text(tag),
                    onDeleted: () => setState(() => _selectedTags.remove(tag)),
                    deleteIconColor: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ).toList(),
              ),
      ),
    );
  }

  Widget _buildNoteField(ThemeData theme) {
    return TextFormField(
      controller: _noteController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: '备注',
        hintText: '添加备注信息',
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
        if (widget.onCancel != null)
          const SizedBox(width: 16),
        Expanded(
          child: PrimaryButton(
            onPressed: _handleSubmit,
            text: widget.initialData != null ? '更新' : '保存',
          ),
        ),
      ],
    );
  }

  Color _getAmountColor() {
    switch (_type) {
      case TransactionType.expense:
        return AppConstants.errorColor;
      case TransactionType.income:
        return AppConstants.successColor;
      case TransactionType.transfer:
        return AppConstants.primaryColor;
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
      '工资': Colors.teal,
      '奖金': Colors.amber,
      '投资': Colors.indigo,
      '生意': Colors.brown,
      '其他': Colors.grey,
    };
    return colors[category] ?? Colors.grey;
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTags() async {
    // 这里应该显示标签选择对话框
    // 暂时使用硬编码的标签列表
    final availableTags = ['日常', '旅行', '医疗', '教育', '娱乐', '投资'];
    
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => _TagSelectionDialog(
        availableTags: availableTags,
        selectedTags: _selectedTags,
      ),
    );
    
    if (selected != null) {
      setState(() => _selectedTags = selected);
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text);
      
      widget.onSubmit(TransactionFormData(
        amount: amount,
        description: _descriptionController.text,
        type: _type,
        date: _selectedDate,
        category: _selectedCategory,
        account: _selectedAccount!,
        payee: _payeeController.text.isEmpty ? null : _payeeController.text,
        tags: _selectedTags,
        note: _noteController.text.isEmpty ? null : _noteController.text,
      ));
    }
  }
}

/// 标签选择对话框
class _TagSelectionDialog extends StatefulWidget {
  final List<String> availableTags;
  final List<String> selectedTags;

  const _TagSelectionDialog({
    required this.availableTags,
    required this.selectedTags,
  });

  @override
  State<_TagSelectionDialog> createState() => _TagSelectionDialogState();
}

class _TagSelectionDialogState extends State<_TagSelectionDialog> {
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selectedTags);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择标签'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: widget.availableTags.map((tag) => 
            CheckboxListTile(
              title: Text(tag),
              value: _selected.contains(tag),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(tag);
                  } else {
                    _selected.remove(tag);
                  }
                });
              },
            ),
          ).toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

/// 交易类型枚举
enum TransactionType {
  expense,
  income,
  transfer,
}

/// 交易表单数据模型
class TransactionFormData {
  final double amount;
  final String description;
  final TransactionType type;
  final DateTime date;
  final String? category;
  final String account;
  final String? payee;
  final List<String> tags;
  final String? note;

  const TransactionFormData({
    required this.amount,
    required this.description,
    required this.type,
    required this.date,
    this.category,
    required this.account,
    this.payee,
    required this.tags,
    this.note,
  });
}