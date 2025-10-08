import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jive_money/providers/account_provider.dart';
import 'package:jive_money/providers/ledger_provider.dart';

class AccountAddScreen extends ConsumerStatefulWidget {
  const AccountAddScreen({super.key});

  @override
  ConsumerState<AccountAddScreen> createState() => _AccountAddScreenState();
}

class _AccountAddScreenState extends ConsumerState<AccountAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedType = 'checking';
  String _selectedCurrency = 'CNY';
  bool _isDefault = false;
  bool _excludeFromStats = false;
  Color _selectedColor = Colors.blue;

  final List<Color> _colorOptions = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.red,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _accountNumberController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Using read below for ledger id on save; no need to watch here.

    return Scaffold(
      appBar: AppBar(
        title: const Text('添加账户'),
        actions: [
          TextButton(
            onPressed: _isValid() ? _saveAccount : null,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 基本信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '基本信息',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 账户名称
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: '账户名称',
                        hintText: '例如：工商银行储蓄卡',
                        prefixIcon: Icon(Icons.account_balance),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入账户名称';
                        }
                        return null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // 账户类型
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: '账户类型',
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'checking',
                          child: Row(
                            children: [
                              Icon(Icons.account_balance, size: 20),
                              SizedBox(width: 8),
                              Text('支票账户'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'savings',
                          child: Row(
                            children: [
                              Icon(Icons.savings, size: 20),
                              SizedBox(width: 8),
                              Text('储蓄账户'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'credit_card',
                          child: Row(
                            children: [
                              Icon(Icons.credit_card, size: 20),
                              SizedBox(width: 8),
                              Text('信用卡'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'cash',
                          child: Row(
                            children: [
                              Icon(Icons.account_balance_wallet, size: 20),
                              SizedBox(width: 8),
                              Text('现金'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'investment',
                          child: Row(
                            children: [
                              Icon(Icons.trending_up, size: 20),
                              SizedBox(width: 8),
                              Text('投资账户'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'loan',
                          child: Row(
                            children: [
                              Icon(Icons.money_off, size: 20),
                              SizedBox(width: 8),
                              Text('贷款'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Row(
                            children: [
                              Icon(Icons.account_circle, size: 20),
                              SizedBox(width: 8),
                              Text('其他'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // 初始余额
                    TextFormField(
                      controller: _balanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^-?\d*\.?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: _selectedType == 'credit_card' ||
                                _selectedType == 'loan'
                            ? '欠款金额'
                            : '初始余额',
                        hintText: '0.00',
                        prefixIcon: const Icon(Icons.attach_money),
                        prefixText: '¥ ',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入金额';
                        }
                        if (double.tryParse(value) == null) {
                          return '请输入有效金额';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 附加信息
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '附加信息',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 账户号码
                    TextFormField(
                      controller: _accountNumberController,
                      decoration: const InputDecoration(
                        labelText: '账户号码（可选）',
                        hintText: '卡号后4位或完整账号',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 货币
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCurrency,
                      decoration: const InputDecoration(
                        labelText: '货币',
                        prefixIcon: Icon(Icons.currency_exchange),
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: 'CNY', child: Text('CNY - 人民币')),
                        DropdownMenuItem(value: 'USD', child: Text('USD - 美元')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR - 欧元')),
                        DropdownMenuItem(value: 'GBP', child: Text('GBP - 英镑')),
                        DropdownMenuItem(value: 'JPY', child: Text('JPY - 日元')),
                        DropdownMenuItem(value: 'HKD', child: Text('HKD - 港币')),
                        DropdownMenuItem(value: 'TWD', child: Text('TWD - 台币')),
                        DropdownMenuItem(value: 'KRW', child: Text('KRW - 韩元')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCurrency = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // 颜色选择
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '颜色标识',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _colorOptions.map((color) {
                            final isSelected = _selectedColor == color;
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedColor = color;
                                });
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: Theme.of(context).primaryColor,
                                          width: 3,
                                        )
                                      : null,
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 20,
                                      )
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 描述
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: '描述（可选）',
                        hintText: '添加备注信息',
                        prefixIcon: Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 设置选项
            Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Text(
                        '设置选项',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('设为默认账户'),
                      subtitle: const Text('新交易默认使用此账户'),
                      value: _isDefault,
                      onChanged: (value) {
                        setState(() {
                          _isDefault = value;
                        });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('排除统计'),
                      subtitle: const Text('不计入净资产和统计报表'),
                      value: _excludeFromStats,
                      onChanged: (value) {
                        setState(() {
                          _excludeFromStats = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isValid() ? _saveAccount : null,
        icon: const Icon(Icons.save),
        label: const Text('保存账户'),
      ),
    );
  }

  bool _isValid() {
    return _nameController.text.isNotEmpty &&
        _balanceController.text.isNotEmpty &&
        double.tryParse(_balanceController.text) != null;
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // TODO: 调用API保存账户
      final _account = {
        'name': _nameController.text,
        'type': _selectedType,
        'balance': double.parse(_balanceController.text),
        'account_number': _accountNumberController.text.isEmpty
            ? null
            : _accountNumberController.text,
        'currency': _selectedCurrency,
        'color': _selectedColor.toARGB32(),
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'is_default': _isDefault,
        'exclude_from_stats': _excludeFromStats,
        'ledger_id': ref.read(currentLedgerProvider)?.id,
        'bank_id': _selectedBank?.id,
      };

      // 显示成功消息（TODO: 实际保存后再提示）
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('账户已创建')),
      );

      // 刷新账户列表
      ref.invalidate(accountsProvider);

      // 返回上一页
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败: $e')),
      );
    }
  }
}
