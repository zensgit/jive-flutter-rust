import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/travel_event.dart';
import '../../providers/travel_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class TravelEditScreen extends ConsumerStatefulWidget {
  final TravelEvent? event;

  const TravelEditScreen({Key? key, this.event}) : super(key: key);

  @override
  ConsumerState<TravelEditScreen> createState() => _TravelEditScreenState();
}

class _TravelEditScreenState extends ConsumerState<TravelEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _destinationController;
  late TextEditingController _budgetController;
  late TextEditingController _notesController;

  DateTime? _startDate;
  DateTime? _endDate;
  String _currency = 'CNY';
  TravelEventStatus _status = TravelEventStatus.upcoming;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.event?.name ?? '');
    _descriptionController = TextEditingController(text: widget.event?.description ?? '');
    _destinationController = TextEditingController(text: widget.event?.destination ?? '');
    _budgetController = TextEditingController(text: widget.event?.budget?.toString() ?? '');
    _notesController = TextEditingController(text: widget.event?.notes ?? '');

    if (widget.event != null) {
      _startDate = widget.event!.startDate;
      _endDate = widget.event!.endDate;
      _currency = widget.event!.currency;
      _status = widget.event!.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _destinationController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // If end date is before start date, update it
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择旅行日期')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final service = ref.read(travelServiceProvider);
      final double? budget = _budgetController.text.isNotEmpty
          ? double.tryParse(_budgetController.text)
          : null;

      final event = TravelEvent(
        id: widget.event?.id,
        name: _nameController.text,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        destination: _destinationController.text,
        startDate: _startDate!,
        endDate: _endDate!,
        budget: budget,
        currency: _currency,
        status: _status,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        transactionCount: widget.event?.transactionCount ?? 0,
        totalSpent: widget.event?.totalSpent ?? 0,
        createdAt: widget.event?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (widget.event == null) {
        await service.createEvent(event);
      } else {
        await service.updateEvent(event);
      }

      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑旅行' : '新建旅行'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('删除旅行'),
                    content: const Text('确定要删除这个旅行记录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('删除'),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    final service = ref.read(travelServiceProvider);
                    await service.deleteEvent(widget.event!.id!);
                    if (mounted) {
                      Navigator.of(context).pop(true);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('删除失败: $e')),
                      );
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            CustomTextField(
              controller: _nameController,
              labelText: '旅行名称',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入旅行名称';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            CustomTextField(
              controller: _destinationController,
              labelText: '目的地',
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入目的地';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            CustomTextField(
              controller: _descriptionController,
              labelText: '描述（可选）',
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '开始日期',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _startDate != null ? dateFormat.format(_startDate!) : '选择日期',
                        style: TextStyle(
                          color: _startDate != null ? null : Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '结束日期',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _endDate != null ? dateFormat.format(_endDate!) : '选择日期',
                        style: TextStyle(
                          color: _endDate != null ? null : Theme.of(context).hintColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    controller: _budgetController,
                    labelText: '预算（可选）',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final budget = double.tryParse(value);
                        if (budget == null || budget < 0) {
                          return '请输入有效的金额';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(
                      labelText: '货币',
                      border: OutlineInputBorder(),
                    ),
                    items: ['CNY', 'USD', 'EUR', 'JPY', 'HKD', 'GBP']
                        .map((currency) => DropdownMenuItem(
                              value: currency,
                              child: Text(currency),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _currency = value;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<TravelEventStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: '状态',
                border: OutlineInputBorder(),
              ),
              items: TravelEventStatus.values
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(_getStatusLabel(status)),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _status = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            CustomTextField(
              controller: _notesController,
              labelText: '备注（可选）',
              maxLines: 4,
            ),
            const SizedBox(height: 32),

            CustomButton(
              onPressed: _isLoading ? null : _saveEvent,
              text: _isLoading ? '保存中...' : '保存',
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusLabel(TravelEventStatus status) {
    switch (status) {
      case TravelEventStatus.upcoming:
        return '即将开始';
      case TravelEventStatus.ongoing:
        return '进行中';
      case TravelEventStatus.completed:
        return '已完成';
      case TravelEventStatus.cancelled:
        return '已取消';
    }
  }
}