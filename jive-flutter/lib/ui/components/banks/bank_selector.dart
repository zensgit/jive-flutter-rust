import 'package:flutter/material.dart';
import 'package:jive_money/models/bank.dart';
import 'package:jive_money/services/bank_service.dart';
import 'package:jive_money/core/constants/app_constants.dart';

class BankSelector extends StatefulWidget {
  final Bank? selectedBank;
  final ValueChanged<Bank?> onBankSelected;
  final bool isCryptoMode;

  const BankSelector({
    super.key,
    this.selectedBank,
    required this.onBankSelected,
    this.isCryptoMode = false,
  });

  @override
  State<BankSelector> createState() => _BankSelectorState();
}

class _BankSelectorState extends State<BankSelector> {
  final BankService _bankService = BankService(null);
  List<Bank> _banks = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBanks();
  }

  Future<void> _loadBanks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final banks = await _bankService.getBanks(
        isCrypto: widget.isCryptoMode,
      );
      setState(() {
        _banks = banks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载银行列表失败: $e';
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _showBankPicker(context),
      borderRadius: BorderRadius.circular(AppConstants.borderRadius),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: widget.isCryptoMode ? '加密货币' : '银行/机构',
          hintText: widget.isCryptoMode ? '选择加密货币' : '选择银行或机构',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          ),
          suffixIcon: widget.selectedBank != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => widget.onBankSelected(null),
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        child: Row(
          children: [
            if (widget.selectedBank != null) ...[
              if (widget.selectedBank!.iconFilename != null)
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Text(
                    widget.selectedBank!.displayName[0].toUpperCase(),
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else
                Icon(
                  widget.isCryptoMode
                      ? Icons.currency_bitcoin
                      : Icons.account_balance,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.selectedBank!.displayName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              Text(
                widget.isCryptoMode ? '点击选择加密货币' : '点击选择银行',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBankPicker(BuildContext context) async {
    final selectedBank = await showModalBottomSheet<Bank>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _BankPickerSheet(
          scrollController: scrollController,
          banks: _banks,
          isLoading: _isLoading,
          error: _error,
          isCryptoMode: widget.isCryptoMode,
          onRefresh: _loadBanks,
          bankService: _bankService,
        ),
      ),
    );

    if (selectedBank != null) {
      widget.onBankSelected(selectedBank);
    }
  }
}

class _BankPickerSheet extends StatefulWidget {
  final ScrollController scrollController;
  final List<Bank> banks;
  final bool isLoading;
  final String? error;
  final bool isCryptoMode;
  final VoidCallback onRefresh;
  final BankService bankService;

  const _BankPickerSheet({
    required this.scrollController,
    required this.banks,
    required this.isLoading,
    this.error,
    required this.isCryptoMode,
    required this.onRefresh,
    required this.bankService,
  });

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Bank> _filteredBanks = [];

  @override
  void initState() {
    super.initState();
    _filteredBanks = widget.banks;
    _searchController.addListener(_filterBanks);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterBanks() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredBanks = widget.banks;
      } else {
        _filteredBanks = widget.banks.where((bank) {
          return bank.name.toLowerCase().contains(query) ||
              (bank.nameCn?.toLowerCase().contains(query) ?? false) ||
              (bank.nameEn?.toLowerCase().contains(query) ?? false) ||
              bank.code.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isCryptoMode ? '选择加密货币' : '选择银行',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.isCryptoMode
                      ? '搜索加密货币...'
                      : '搜索银行名称、拼音或代码...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppConstants.borderRadius),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildContent(theme),
        ),
      ],
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (widget.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(widget.error!, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: widget.onRefresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_filteredBanks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: theme.hintColor),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的${widget.isCryptoMode ? '加密货币' : '银行'}',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: _filteredBanks.length + 1,
      itemBuilder: (context, index) {
        if (index == _filteredBanks.length) {
          return Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  '没有找到银行？',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    // TODO: 实现反馈功能
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('感谢反馈！我们会尽快添加更多银行'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.feedback_outlined),
                  label: const Text('点击这里反馈'),
                ),
              ],
            ),
          );
        }

        final bank = _filteredBanks[index];
        return ListTile(
          leading: bank.iconFilename != null
              ? CircleAvatar(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Text(
                    bank.displayName[0].toUpperCase(),
                    style: theme.textTheme.titleMedium,
                  ),
                )
              : Icon(
                  widget.isCryptoMode
                      ? Icons.currency_bitcoin
                      : Icons.account_balance,
                ),
          title: Text(bank.displayName),
          subtitle: Text(bank.code),
          onTap: () => Navigator.of(context).pop(bank),
        );
      },
    );
  }
}