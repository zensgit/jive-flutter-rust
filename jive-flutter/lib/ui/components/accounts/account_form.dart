// 账户表单组件
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_constants.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';
import 'account_list.dart';

class AccountForm extends StatefulWidget {
  final AccountFormData? initialData;
  final Function(AccountFormData) onSubmit;
  final VoidCallback? onCancel;
  final bool isEditMode;

  const AccountForm({
    super.key,
    this.initialData,
    required this.onSubmit,
    this.onCancel,
    this.isEditMode = false,
  });

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  late final GlobalKey<FormState> _formKey;
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _bankNameController;
  
  late AccountType _type;
  late AccountSubType _subType;
  late String _currency;
  Color _color = AppConstants.primaryColor;
  IconData _icon = Icons.account_balance_wallet;
  bool _isActive = true;
  bool _includeInTotal = true;
  
  @override
  void initState() {
    super.initState();
    _formKey = GlobalKey<FormState>();
    
    final initial = widget.initialData;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _balanceController = TextEditingController(
      text: initial?.balance.toStringAsFixed(2) ?? '0.00',
    );
    _descriptionController = TextEditingController(text: initial?.description ?? '');
    _accountNumberController = TextEditingController(text: initial?.accountNumber ?? '');
    _bankNameController = TextEditingController(text: initial?.bankName ?? '');
    
    _type = initial?.type ?? AccountType.asset;
    _subType = initial?.subType ?? AccountSubType.cash;
    _currency = initial?.currency ?? 'CNY';
    _color = initial?.color ?? AppConstants.primaryColor;
    _icon = initial?.icon ?? Icons.account_balance_wallet;
    _isActive = initial?.isActive ?? true;
    _includeInTotal = initial?.includeInTotal ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _descriptionController.dispose();
    _accountNumberController.dispose();
    _bankNameController.dispose();
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
            // 账户类型选择
            _buildTypeSelector(theme),
            
            const SizedBox(height: 20),
            
            // 账户子类型选择
            _buildSubTypeSelector(theme),
            
            const SizedBox(height: 20),
            
            // 账户名称
            _buildNameField(theme),
            
            const SizedBox(height: 16),
            
            // 初始余额
            if (!widget.isEditMode)
              _buildBalanceField(theme),
            
            const SizedBox(height: 16),
            
            // 银行名称（信用卡和银行账户）
            if (_shouldShowBankFields())
              _buildBankNameField(theme),
            
            if (_shouldShowBankFields())
              const SizedBox(height: 16),
            
            // 账号（可选）
            _buildAccountNumberField(theme),
            
            const SizedBox(height: 16),
            
            // 货币选择
            _buildCurrencySelector(theme),
            
            const SizedBox(height: 16),
            
            // 颜色和图标选择
            _buildColorIconSelector(theme),
            
            const SizedBox(height: 16),
            
            // 描述
            _buildDescriptionField(theme),
            
            const SizedBox(height: 20),
            
            // 高级选项
            _buildAdvancedOptions(theme),
            
            const SizedBox(height: 24),
            
            // 操作按钮
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '账户类型',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Container(
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
                  AccountType.asset,
                  '资产',
                  Icons.account_balance_wallet,
                  AppConstants.successColor,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildTypeButton(
                  theme,
                  AccountType.liability,
                  '负债',
                  Icons.credit_card,
                  AppConstants.errorColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeButton(
    ThemeData theme,
    AccountType type,
    String label,
    IconData icon,
    Color color,
  ) {
    final isSelected = _type == type;
    
    return Material(
      color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(AppConstants.smallBorderRadius),
      child: InkWell(
        onTap: () {
          setState(() {
            _type = type;
            // 重置子类型
            _subType = type == AccountType.asset 
                ? AccountSubType.cash 
                : AccountSubType.creditCard;
          });
        },
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

  Widget _buildSubTypeSelector(ThemeData theme) {
    final subTypes = _type == AccountType.asset 
        ? [
            AccountSubType.cash,
            AccountSubType.debitCard,
            AccountSubType.savingsAccount,
            AccountSubType.investment,
            AccountSubType.prepaidCard,
            AccountSubType.digitalWallet,
          ]
        : [
            AccountSubType.creditCard,
            AccountSubType.loan,
            AccountSubType.mortgage,
          ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '账户子类型',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: subTypes.map((subType) => 
            ChoiceChip(
              label: Text(_getSubTypeName(subType)),
              selected: _subType == subType,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _subType = subType;
                    _icon = _getSubTypeIcon(subType);
                  });
                }
              },
            ),
          ).toList(),
        ),
      ],
    );
  }

  Widget _buildNameField(ThemeData theme) {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        labelText: '账户名称',
        hintText: '例如：工商银行储蓄卡',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入账户名称';
        }
        return null;
      },
    );
  }

  Widget _buildBalanceField(ThemeData theme) {
    return TextFormField(
      controller: _balanceController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d{0,2}')),
      ],
      decoration: InputDecoration(
        labelText: '初始余额',
        prefixText: '¥ ',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        helperText: _type == AccountType.liability ? '负债账户请输入负数' : null,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入初始余额';
        }
        if (double.tryParse(value) == null) {
          return '请输入有效金额';
        }
        return null;
      },
    );
  }

  Widget _buildBankNameField(ThemeData theme) {
    return TextFormField(
      controller: _bankNameController,
      decoration: InputDecoration(
        labelText: '银行/机构名称',
        hintText: '例如：中国工商银行',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
    );
  }

  Widget _buildAccountNumberField(ThemeData theme) {
    return TextFormField(
      controller: _accountNumberController,
      decoration: InputDecoration(
        labelText: '账号/卡号（可选）',
        hintText: '输入账号后4位即可',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        helperText: '为了安全，建议只输入后4位',
      ),
    );
  }

  Widget _buildCurrencySelector(ThemeData theme) {
    final currencies = ['CNY', 'USD', 'EUR', 'JPY', 'HKD'];
    
    return DropdownButtonFormField<String>(
      initialValue: _currency,
      decoration: InputDecoration(
        labelText: '货币',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
      items: currencies.map((currency) => 
        DropdownMenuItem(
          value: currency,
          child: Text(_getCurrencyDisplay(currency)),
        ),
      ).toList(),
      onChanged: (value) => setState(() => _currency = value!),
    );
  }

  Widget _buildColorIconSelector(ThemeData theme) {
    return Row(
      children: [
        // 颜色选择
        Expanded(
          child: InkWell(
            onTap: _selectColor,
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '颜色',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('选择颜色'),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // 图标选择
        Expanded(
          child: InkWell(
            onTap: _selectIcon,
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '图标',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                ),
              ),
              child: Row(
                children: [
                  Icon(_icon, size: 24),
                  const SizedBox(width: 8),
                  Text('选择图标'),
                ],
              ),
            ),
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
        hintText: '添加账户描述信息',
        alignLabelWithHint: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
      ),
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
        SwitchListTile(
          title: const Text('激活账户'),
          subtitle: const Text('停用的账户不会显示在列表中'),
          value: _isActive,
          onChanged: (value) => setState(() => _isActive = value),
        ),
        SwitchListTile(
          title: const Text('计入总额'),
          subtitle: const Text('是否将此账户余额计入净资产'),
          value: _includeInTotal,
          onChanged: (value) => setState(() => _includeInTotal = value),
        ),
      ],
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
            text: widget.isEditMode ? '更新' : '创建',
          ),
        ),
      ],
    );
  }

  bool _shouldShowBankFields() {
    return [
      AccountSubType.debitCard,
      AccountSubType.savingsAccount,
      AccountSubType.creditCard,
      AccountSubType.loan,
      AccountSubType.mortgage,
    ].contains(_subType);
  }

  String _getSubTypeName(AccountSubType subType) {
    switch (subType) {
      case AccountSubType.cash:
        return '现金';
      case AccountSubType.debitCard:
        return '借记卡';
      case AccountSubType.savingsAccount:
        return '储蓄账户';
      case AccountSubType.investment:
        return '投资账户';
      case AccountSubType.prepaidCard:
        return '预付卡';
      case AccountSubType.digitalWallet:
        return '数字钱包';
      case AccountSubType.creditCard:
        return '信用卡';
      case AccountSubType.loan:
        return '贷款';
      case AccountSubType.mortgage:
        return '房贷';
    }
  }

  IconData _getSubTypeIcon(AccountSubType subType) {
    switch (subType) {
      case AccountSubType.cash:
        return Icons.payments;
      case AccountSubType.debitCard:
        return Icons.credit_card;
      case AccountSubType.savingsAccount:
        return Icons.savings;
      case AccountSubType.investment:
        return Icons.trending_up;
      case AccountSubType.prepaidCard:
        return Icons.card_giftcard;
      case AccountSubType.digitalWallet:
        return Icons.account_balance_wallet;
      case AccountSubType.creditCard:
        return Icons.credit_card;
      case AccountSubType.loan:
        return Icons.receipt_long;
      case AccountSubType.mortgage:
        return Icons.home;
    }
  }

  String _getCurrencyDisplay(String currency) {
    switch (currency) {
      case 'CNY':
        return '人民币 (CNY)';
      case 'USD':
        return '美元 (USD)';
      case 'EUR':
        return '欧元 (EUR)';
      case 'JPY':
        return '日元 (JPY)';
      case 'HKD':
        return '港币 (HKD)';
      default:
        return currency;
    }
  }

  Future<void> _selectColor() async {
    // 这里应该显示颜色选择器
    // 暂时使用预定义的颜色列表
    final colors = [
      AppConstants.primaryColor,
      AppConstants.successColor,
      AppConstants.errorColor,
      AppConstants.warningColor,
      AppConstants.infoColor,
      Colors.purple,
      Colors.orange,
      Colors.teal,
    ];
    
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: Wrap(
          spacing: 8,
          children: colors.map((color) => 
            InkWell(
              onTap: () => Navigator.of(context).pop(color),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ).toList(),
        ),
      ),
    );
    
    if (selected != null) {
      setState(() => _color = selected);
    }
  }

  Future<void> _selectIcon() async {
    // 这里应该显示图标选择器
    // 暂时使用预定义的图标列表
    final icons = [
      Icons.account_balance_wallet,
      Icons.credit_card,
      Icons.savings,
      Icons.payments,
      Icons.trending_up,
      Icons.card_giftcard,
      Icons.home,
      Icons.receipt_long,
    ];
    
    final selected = await showDialog<IconData>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择图标'),
        content: Wrap(
          spacing: 8,
          children: icons.map((icon) => 
            InkWell(
              onTap: () => Navigator.of(context).pop(icon),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon),
              ),
            ),
          ).toList(),
        ),
      ),
    );
    
    if (selected != null) {
      setState(() => _icon = selected);
    }
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final balance = double.parse(_balanceController.text);
      
      widget.onSubmit(AccountFormData(
        name: _nameController.text,
        type: _type,
        subType: _subType,
        balance: balance,
        currency: _currency,
        color: _color,
        icon: _icon,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        accountNumber: _accountNumberController.text.isEmpty ? null : _accountNumberController.text,
        bankName: _bankNameController.text.isEmpty ? null : _bankNameController.text,
        isActive: _isActive,
        includeInTotal: _includeInTotal,
      ));
    }
  }
}

/// 账户表单数据模型
class AccountFormData {
  final String name;
  final AccountType type;
  final AccountSubType subType;
  final double balance;
  final String currency;
  final Color color;
  final IconData icon;
  final String? description;
  final String? accountNumber;
  final String? bankName;
  final bool isActive;
  final bool includeInTotal;

  const AccountFormData({
    required this.name,
    required this.type,
    required this.subType,
    required this.balance,
    required this.currency,
    required this.color,
    required this.icon,
    this.description,
    this.accountNumber,
    this.bankName,
    required this.isActive,
    required this.includeInTotal,
  });
}