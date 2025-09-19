import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/account_provider.dart';
import '../../providers/ledger_provider.dart';

class TransactionAddScreen extends ConsumerStatefulWidget {
  final String? type; // income, expense, transfer

  const TransactionAddScreen({super.key, this.type});

  @override
  ConsumerState<TransactionAddScreen> createState() =>
      _TransactionAddScreenState();
}

class _TransactionAddScreenState extends ConsumerState<TransactionAddScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCategory;
  String? _selectedAccountId;
  String? _selectedToAccountId; // 用于转账
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isRecurring = false;
  String? _recurringPeriod; // daily, weekly, monthly, yearly

  // 分类列表
  final Map<String, List<String>> _categories = {
    'expense': [
      '餐饮',
      '交通',
      '购物',
      '娱乐',
      '居住',
      '医疗',
      '教育',
      '通讯',
      '日用品',
      '服饰',
      '运动',
      '其他'
    ],
    'income': ['工资', '奖金', '投资收益', '兼职', '生意', '退款', '报销', '红包', '其他'],
  };

  @override
  void initState() {
    super.initState();
    _type = widget.type ?? 'expense';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final currentLedger = ref.watch(currentLedgerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        actions: [
          TextButton(
            onPressed: _isValid() ? _saveTransaction : null,
            child: Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 交易类型选择
            if (widget.type == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '交易类型',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'expense',
                            label: Text('支出'),
                            icon: Icon(Icons.remove_circle_outline),
                          ),
                          ButtonSegment(
                            value: 'income',
                            label: Text('收入'),
                            icon: Icon(Icons.add_circle_outline),
                          ),
                          ButtonSegment(
                            value: 'transfer',
                            label: Text('转账'),
                            icon: Icon(Icons.swap_horiz),
                          ),
                        ],
                        selected: {_type},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _type = newSelection.first;
                            _selectedCategory = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 金额输入
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '金额',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        prefixText: '¥ ',
                        prefixStyle: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        hintText: '0.00',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 账户选择
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _type == 'transfer' ? '转出账户' : '账户',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAccountId,
                      decoration: InputDecoration(
                        hintText: '选择账户',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: accounts.map((account) {
                        return DropdownMenuItem(
                          value: account.id,
                          child: Row(
                            children: [
                              Icon(
                                _getAccountIcon(account.type.value),
                                size: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text(account.name ?? '未命名'),
                              const Spacer(),
                              Text(
                                '¥${(account.balance ?? 0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAccountId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return '请选择账户';
                        }
                        return null;
                      },
                    ),

                    // 转账目标账户
                    if (_type == 'transfer') ...[
                      const SizedBox(height: 16),
                      Text(
                        '转入账户',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedToAccountId,
                        decoration: InputDecoration(
                          hintText: '选择账户',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: accounts
                            .where(
                                (account) => account.id != _selectedAccountId)
                            .map((account) {
                          return DropdownMenuItem(
                            value: account.id,
                            child: Row(
                              children: [
                                Icon(
                                  _getAccountIcon(account.type.value),
                                  size: 20,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 8),
                                Text(account.name ?? '未命名'),
                                const Spacer(),
                                Text(
                                  '¥${(account.balance ?? 0).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedToAccountId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return '请选择转入账户';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 分类选择（非转账）
            if (_type != 'transfer')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '分类',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories[_type]?.map((category) {
                              final isSelected = _selectedCategory == category;
                              return FilterChip(
                                label: Text(category),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedCategory =
                                        selected ? category : null;
                                  });
                                },
                              );
                            }).toList() ??
                            [],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // 日期时间选择
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '日期时间',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectDate,
                            icon: Icon(Icons.calendar_today),
                            label: Text(
                              DateFormat('yyyy年MM月dd日').format(_selectedDate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _selectTime,
                            icon: Icon(Icons.access_time),
                            label: Text(
                              _selectedTime.format(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 描述和备注
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '描述',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText: '输入交易描述',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入描述';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '备注',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: '添加备注（可选）',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 定期交易设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '定期交易',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Switch(
                          value: _isRecurring,
                          onChanged: (value) {
                            setState(() {
                              _isRecurring = value;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_isRecurring) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _recurringPeriod,
                        decoration: InputDecoration(
                          hintText: '选择重复周期',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'daily', child: Text('每天')),
                          DropdownMenuItem(value: 'weekly', child: Text('每周')),
                          DropdownMenuItem(value: 'monthly', child: Text('每月')),
                          DropdownMenuItem(value: 'yearly', child: Text('每年')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _recurringPeriod = value;
                          });
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isValid() ? _saveTransaction : null,
        icon: Icon(Icons.save),
        label: Text('保存交易'),
      ),
    );
  }

  String _getTitle() {
    switch (_type) {
      case 'income':
        return '添加收入';
      case 'expense':
        return '添加支出';
      case 'transfer':
        return '添加转账';
      default:
        return '添加交易';
    }
  }

  bool _isValid() {
    return _amountController.text.isNotEmpty &&
        double.tryParse(_amountController.text) != null &&
        double.tryParse(_amountController.text)! > 0;
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // TODO: 调用API保存交易
      final transaction = {
        'type': _type,
        'amount': double.parse(_amountController.text),
        'description': _descriptionController.text,
        'note': _noteController.text,
        'category': _selectedCategory,
        'account_id': _selectedAccountId,
        'to_account_id': _selectedToAccountId,
        'date': DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        ).toIso8601String(),
        'is_recurring': _isRecurring,
        'recurring_period': _recurringPeriod,
        'ledger_id': ref.read(currentLedgerProvider)?.id,
      };

      // 显示成功消息
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('交易已保存')),
      );

      // 刷新交易列表
      ref.invalidate(transactionsProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(accountsProvider);

      // 返回上一页
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    }
  }

  IconData _getAccountIcon(String? type) {
    switch (type) {
      case 'checking':
        return Icons.account_balance;
      case 'savings':
        return Icons.savings;
      case 'credit_card':
        return Icons.credit_card;
      case 'investment':
        return Icons.trending_up;
      case 'loan':
        return Icons.money_off;
      case 'cash':
        return Icons.account_balance_wallet;
      default:
        return Icons.account_circle;
    }
  }
}
