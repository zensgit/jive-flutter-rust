import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/travel_provider.dart';
import '../../models/travel_event.dart';

class TravelCreateDialog extends StatefulWidget {
  const TravelCreateDialog({Key? key}) : super(key: key);

  @override
  State<TravelCreateDialog> createState() => _TravelCreateDialogState();
}

class _TravelCreateDialogState extends State<TravelCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _autoTag = true;
  bool _isSubmitting = false;
  
  String? _selectedTemplate;
  final List<String> _selectedCategoryIds = [];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startDate : _endDate;
    final firstDate = isStart 
        ? DateTime.now().subtract(const Duration(days: 365))
        : _startDate;
    final lastDate = DateTime.now().add(const Duration(days: 365 * 2));

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate.add(const Duration(days: 1));
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final provider = context.read<TravelProvider>();
      
      final input = CreateTravelEventInput(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        autoTag: _autoTag,
        travelCategoryIds: _selectedCategoryIds,
      );

      final success = await provider.createTravelEvent(input);

      if (success && mounted) {
        Navigator.of(context).pop(true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? '创建旅行失败'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _applyTemplate(String templateId) {
    setState(() {
      _selectedTemplate = templateId;
      
      // Apply template settings
      switch (templateId) {
        case 'common_travel':
          _selectedCategoryIds.clear();
          _selectedCategoryIds.addAll([
            'transportation',
            'accommodation',
            'dining',
            'entertainment',
            'shopping',
            'attractions',
          ]);
          break;
        case 'domestic_short_trip':
          _selectedCategoryIds.clear();
          _selectedCategoryIds.addAll([
            'transportation',
            'accommodation',
            'dining',
            'attractions',
          ]);
          break;
        case 'business_trip':
          _selectedCategoryIds.clear();
          _selectedCategoryIds.addAll([
            'transportation',
            'accommodation',
            'dining',
            'communication',
            'office_supplies',
          ]);
          break;
        default:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('创建新旅行'),
            actions: [
              TextButton(
                onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSubmitting ? null : _submitForm,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('创建'),
              ),
              const SizedBox(width: 16),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 基本信息
                Text(
                  '基本信息',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '旅行名称',
                    hintText: '例如：日本东京5日游',
                    prefixIcon: Icon(Icons.flight_takeoff),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入旅行名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '描述（可选）',
                    hintText: '添加更多旅行细节',
                    prefixIcon: Icon(Icons.description),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: '目的地（可选）',
                    hintText: '例如：东京、大阪',
                    prefixIcon: Icon(Icons.location_on),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                
                // 日期选择
                Text(
                  '旅行日期',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: _DateSelector(
                        label: '开始日期',
                        date: _startDate,
                        onTap: () => _selectDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _DateSelector(
                        label: '结束日期',
                        date: _endDate,
                        onTap: () => _selectDate(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                Text(
                  '共 ${_endDate.difference(_startDate).inDays + 1} 天',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                
                // 模板选择
                Text(
                  '快速模板',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TemplateChip(
                      label: '常见旅行',
                      icon: '✈️',
                      isSelected: _selectedTemplate == 'common_travel',
                      onTap: () => _applyTemplate('common_travel'),
                    ),
                    _TemplateChip(
                      label: '国内短途',
                      icon: '🚗',
                      isSelected: _selectedTemplate == 'domestic_short_trip',
                      onTap: () => _applyTemplate('domestic_short_trip'),
                    ),
                    _TemplateChip(
                      label: '商务出差',
                      icon: '💼',
                      isSelected: _selectedTemplate == 'business_trip',
                      onTap: () => _applyTemplate('business_trip'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 高级选项
                Text(
                  '高级选项',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                
                SwitchListTile(
                  title: const Text('自动标记交易'),
                  subtitle: const Text('自动将旅行期间的交易标记到此旅行'),
                  value: _autoTag,
                  onChanged: (value) {
                    setState(() {
                      _autoTag = value;
                    });
                  },
                ),
                
                if (_selectedCategoryIds.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '已选择 ${_selectedCategoryIds.length} 个分类',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateSelector({
    Key? key,
    required this.label,
    required this.date,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '${date.year}年${date.month}月${date.day}日',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TemplateChip({
    Key? key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 创建旅行事件输入模型
class CreateTravelEventInput {
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final String? location;
  final bool autoTag;
  final List<String> travelCategoryIds;

  CreateTravelEventInput({
    required this.name,
    this.description,
    required this.startDate,
    required this.endDate,
    this.location,
    required this.autoTag,
    required this.travelCategoryIds,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    if (location != null) 'location': location,
    'auto_tag': autoTag,
    'travel_category_ids': travelCategoryIds,
  };
}