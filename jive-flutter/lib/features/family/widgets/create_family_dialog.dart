import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_models.dart';
import '../providers/family_provider.dart';

/// 创建 Family 对话框
class CreateFamilyDialog extends ConsumerStatefulWidget {
  const CreateFamilyDialog({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateFamilyDialog> createState() => _CreateFamilyDialogState();
}

class _CreateFamilyDialogState extends ConsumerState<CreateFamilyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  FamilyTemplate _selectedTemplate = FamilyTemplate.personal;
  String _selectedCurrency = 'USD';
  String _selectedTimezone = 'America/New_York';
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // 根据模板设置默认名称
    _updateNameFromTemplate();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateNameFromTemplate() {
    final userName = ref.read(authProvider).currentUser?.name ?? 'User';
    _nameController.text = _selectedTemplate.getDefaultName(userName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Row(
                    children: [
                      Icon(Icons.add_home, 
                        color: theme.colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Create New Family',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You will become the Owner of this new family',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // 模板选择
                  Text(
                    'Template',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildTemplateGrid(),
                  const SizedBox(height: 24),
                  
                  // Family 名称
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Family Name',
                      hintText: 'Enter a name for your family',
                      prefixIcon: Icon(Icons.edit),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a family name';
                      }
                      if (value.length > 50) {
                        return 'Name is too long (max 50 characters)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 货币选择
                  DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    items: _getCurrencyItems(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCurrency = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // 时区选择
                  DropdownButtonFormField<String>(
                    value: _selectedTimezone,
                    decoration: const InputDecoration(
                      labelText: 'Timezone',
                      prefixIcon: Icon(Icons.access_time),
                      border: OutlineInputBorder(),
                    ),
                    items: _getTimezoneItems(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTimezone = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // 设置预览
                  _buildSettingsPreview(),
                  const SizedBox(height: 24),
                  
                  // 操作按钮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isCreating ? null : () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _isCreating ? null : _createFamily,
                        icon: _isCreating 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                        label: Text(_isCreating ? 'Creating...' : 'Create Family'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: FamilyTemplate.values.map((template) {
        return _TemplateCard(
          template: template,
          isSelected: _selectedTemplate == template,
          onTap: () {
            setState(() {
              _selectedTemplate = template;
              _updateNameFromTemplate();
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildSettingsPreview() {
    final settings = _selectedTemplate.getSettings();
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings Preview',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildSettingRow('Shared Categories', settings.sharedCategories),
          _buildSettingRow('Shared Tags', settings.sharedTags),
          _buildSettingRow('Shared Budgets', settings.sharedBudgets),
          _buildSettingRow('Show Member Transactions', settings.showMemberTransactions),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, bool value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: value ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  List<DropdownMenuItem<String>> _getCurrencyItems() {
    final currencies = [
      {'code': 'USD', 'name': 'US Dollar'},
      {'code': 'EUR', 'name': 'Euro'},
      {'code': 'GBP', 'name': 'British Pound'},
      {'code': 'JPY', 'name': 'Japanese Yen'},
      {'code': 'CNY', 'name': 'Chinese Yuan'},
      {'code': 'AUD', 'name': 'Australian Dollar'},
      {'code': 'CAD', 'name': 'Canadian Dollar'},
      {'code': 'CHF', 'name': 'Swiss Franc'},
      {'code': 'HKD', 'name': 'Hong Kong Dollar'},
      {'code': 'SGD', 'name': 'Singapore Dollar'},
    ];
    
    return currencies.map((currency) {
      return DropdownMenuItem<String>(
        value: currency['code'],
        child: Text('${currency['code']} - ${currency['name']}'),
      );
    }).toList();
  }

  List<DropdownMenuItem<String>> _getTimezoneItems() {
    final timezones = [
      'America/New_York',
      'America/Chicago',
      'America/Denver',
      'America/Los_Angeles',
      'Europe/London',
      'Europe/Paris',
      'Europe/Berlin',
      'Asia/Tokyo',
      'Asia/Shanghai',
      'Asia/Hong_Kong',
      'Asia/Singapore',
      'Australia/Sydney',
    ];
    
    return timezones.map((tz) {
      return DropdownMenuItem<String>(
        value: tz,
        child: Text(tz),
      );
    }).toList();
  }

  Future<void> _createFamily() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final request = CreateFamilyRequest(
        name: _nameController.text.trim(),
        currency: _selectedCurrency,
        timezone: _selectedTimezone,
        template: _selectedTemplate,
      );

      await ref.read(familyProvider.notifier).createAdditionalFamily(request);
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Family "${_nameController.text}" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create family: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}

/// 模板卡片
class _TemplateCard extends StatelessWidget {
  final FamilyTemplate template;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateCard({
    Key? key,
    required this.template,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected 
              ? theme.colorScheme.primary 
              : theme.colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected 
            ? theme.colorScheme.primary.withOpacity(0.1)
            : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getTemplateIcon(template),
              size: 24,
              color: isSelected 
                ? theme.colorScheme.primary 
                : theme.colorScheme.onSurface,
            ),
            const SizedBox(height: 4),
            Text(
              _getTemplateLabel(template),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : null,
                color: isSelected 
                  ? theme.colorScheme.primary 
                  : null,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTemplateIcon(FamilyTemplate template) {
    switch (template) {
      case FamilyTemplate.personal:
        return Icons.person;
      case FamilyTemplate.couple:
        return Icons.favorite;
      case FamilyTemplate.family:
        return Icons.family_restroom;
      case FamilyTemplate.roommates:
        return Icons.home;
      case FamilyTemplate.travel:
        return Icons.flight;
      case FamilyTemplate.business:
        return Icons.business;
      case FamilyTemplate.custom:
        return Icons.settings;
    }
  }

  String _getTemplateLabel(FamilyTemplate template) {
    switch (template) {
      case FamilyTemplate.personal:
        return 'Personal';
      case FamilyTemplate.couple:
        return 'Couple';
      case FamilyTemplate.family:
        return 'Family';
      case FamilyTemplate.roommates:
        return 'Roommates';
      case FamilyTemplate.travel:
        return 'Travel';
      case FamilyTemplate.business:
        return 'Business';
      case FamilyTemplate.custom:
        return 'Custom';
    }
  }
}