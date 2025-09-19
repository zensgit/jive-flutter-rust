import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/ledger.dart';
import '../../providers/ledger_provider.dart';

/// 创建家庭对话框
class CreateFamilyDialog extends ConsumerStatefulWidget {
  const CreateFamilyDialog({super.key});

  @override
  ConsumerState<CreateFamilyDialog> createState() => _CreateFamilyDialogState();
}

class _CreateFamilyDialogState extends ConsumerState<CreateFamilyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  LedgerType _selectedType = LedgerType.family;
  String _selectedCurrency = 'CNY';
  bool _isDefault = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final ledger = Ledger(
        name: _nameController.text.trim(),
        type: _selectedType,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        currency: _selectedCurrency,
        isDefault: _isDefault,
      );

      await ref.read(currentLedgerProvider.notifier).createLedger(
            name: ledger.name,
            type: ledger.type,
            description: ledger.description,
            currency: ledger.currency,
          );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getTypeLabel(_selectedType)}创建成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建失败: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getTypeLabel(LedgerType type) {
    switch (type) {
      case LedgerType.personal:
        return '个人账本';
      case LedgerType.family:
        return '家庭';
      case LedgerType.business:
        return '商业账本';
      case LedgerType.project:
        return '项目账本';
      case LedgerType.travel:
        return '旅行账本';
      case LedgerType.investment:
        return '投资账本';
    }
  }

  IconData _getTypeconst Icon(LedgerType type) {
    switch (type) {
      case LedgerType.personal:
        return Icons.person;
      case LedgerType.family:
        return Icons.family_restroom;
      case LedgerType.business:
        return Icons.business;
      case LedgerType.project:
        return Icons.work;
      case LedgerType.travel:
        return Icons.flight;
      case LedgerType.investment:
        return Icons.trending_up;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.add_home,
                    color: theme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '创建新家庭',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // 表单内容
            Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 名称输入
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: '名称',
                        hintText: '例如：我的家庭',
                        prefixIcon: Icon(Icons.home),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '请输入名称';
                        }
                        if (value.trim().length > 50) {
                          return '名称不能超过50个字符';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // 类型选择
                    DropdownButtonFormField<LedgerType>(
                      value: _selectedType,
                      decoration: InputDecoration(
                        labelText: '类型',
                        prefixIcon: Icon(_getTypeconst Icon(_selectedType)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: LedgerType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Row(
                            children: [
                              Icon(_getTypeconst Icon(type), size: 20),
                              const SizedBox(width: 8),
                              Text(_getTypeLabel(type)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedType = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // 货币选择
                    DropdownButtonFormField<String>(
                      value: _selectedCurrency,
                      decoration: InputDecoration(
                        labelText: '货币',
                        prefixIcon: Icon(Icons.attach_money),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CNY',
                          child: Text('CNY - 人民币 ¥'),
                        ),
                        DropdownMenuItem(
                          value: 'USD',
                          child: Text('USD - 美元 \$'),
                        ),
                        DropdownMenuItem(
                          value: 'EUR',
                          child: Text('EUR - 欧元 €'),
                        ),
                        DropdownMenuItem(
                          value: 'GBP',
                          child: Text('GBP - 英镑 £'),
                        ),
                        DropdownMenuItem(
                          value: 'JPY',
                          child: Text('JPY - 日元 ¥'),
                        ),
                        DropdownMenuItem(
                          value: 'HKD',
                          child: Text('HKD - 港币 HK\$'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCurrency = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // 描述输入
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: '描述（可选）',
                        hintText: '简单描述这个账本的用途',
                        prefixIcon: Icon(Icons.description),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      maxLines: 2,
                      maxLength: 200,
                    ),

                    // 设为默认
                    CheckboxListTile(
                      title: Text('设为默认'),
                      subtitle: Text('登录后自动选择此账本'),
                      value: _isDefault,
                      onChanged: (value) {
                        setState(() => _isDefault = value ?? false);
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),

                    const SizedBox(height: 8),

                    // 提示信息
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.primaryColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: theme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '您将成为此账本的所有者（Owner），拥有全部管理权限',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 按钮栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.of(context).pop(),
                    child: Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _createFamily,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text('创建'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
