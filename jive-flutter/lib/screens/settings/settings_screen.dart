import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/ledger_provider.dart';
import '../../providers/settings_provider.dart' hide currentUserProvider;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        children: [
          // 用户信息卡片
          if (user != null) _buildUserCard(context, user),
          
          // 账本管理
          _buildSection(
            title: '账本管理',
            children: [
              ListTile(
                leading: const Icon(Icons.book),
                title: const Text('账本管理'),
                subtitle: const Text('创建和管理多个账本'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToLedgerManagement(context),
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('账本切换'),
                subtitle: Text(ref.watch(currentLedgerProvider)?.name ?? '默认账本'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showLedgerSwitcher(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('账本共享'),
                subtitle: const Text('与家人或团队共享账本'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToLedgerSharing(context),
              ),
            ],
          ),
          
          // 账户设置
          _buildSection(
            title: '账户设置',
            children: [
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('账户分组'),
                subtitle: const Text('管理账户分组和排序'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToAccountGroups(context),
              ),
              ListTile(
                leading: const Icon(Icons.archive),
                title: const Text('归档账户'),
                subtitle: const Text('查看已归档的账户'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToArchivedAccounts(context),
              ),
            ],
          ),
          
          // 货币设置
          _buildSection(
            title: '货币设置',
            children: [
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('默认货币'),
                subtitle: Text(settings.defaultCurrency ?? 'CNY - 人民币'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showCurrencySelector(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.currency_exchange),
                title: const Text('汇率管理'),
                subtitle: const Text('管理多币种汇率'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToExchangeRates(context),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.autorenew),
                title: const Text('自动更新汇率'),
                subtitle: const Text('每日自动更新汇率'),
                value: settings.autoUpdateRates ?? true,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).updateSetting('autoUpdateRates', value);
                },
              ),
            ],
          ),
          
          // 预算设置
          _buildSection(
            title: '预算设置',
            children: [
              ListTile(
                leading: const Icon(Icons.pie_chart),
                title: const Text('预算模板'),
                subtitle: const Text('管理预算模板'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToBudgetTemplates(context),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications),
                title: const Text('预算提醒'),
                subtitle: const Text('接近预算限额时提醒'),
                value: settings.budgetNotifications ?? true,
                onChanged: (value) {
                  ref.read(settingsProvider.notifier).updateSetting('budgetNotifications', value);
                },
              ),
            ],
          ),
          
          // 数据管理
          _buildSection(
            title: '数据管理',
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_upload),
                title: const Text('备份数据'),
                subtitle: const Text('备份数据到云端'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToBackup(context),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_download),
                title: const Text('恢复数据'),
                subtitle: const Text('从云端恢复数据'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToRestore(context),
              ),
              ListTile(
                leading: const Icon(Icons.import_export),
                title: const Text('导入/导出'),
                subtitle: const Text('导入导出CSV/Excel文件'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToImportExport(context),
              ),
            ],
          ),
          
          // 通用设置
          _buildSection(
            title: '通用设置',
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('语言'),
                subtitle: const Text('简体中文'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showLanguageSelector(context),
              ),
              ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('主题'),
                subtitle: const Text('外观和颜色'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.go('/settings/theme'),
              ),
              ListTile(
                leading: const Icon(Icons.security),
                title: const Text('安全设置'),
                subtitle: const Text('密码和生物识别'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.go('/settings/security'),
              ),
            ],
          ),
          
          // 关于
          _buildSection(
            title: '关于',
            children: [
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('关于 Jive Money'),
                subtitle: const Text('版本 1.0.0'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showAboutDialog(context),
              ),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('帮助中心'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _navigateToHelp(context),
              ),
            ],
          ),
          
          // 退出登录
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () => _confirmLogout(context, ref),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('退出登录', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, dynamic user) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: ListTile(
        leading: CircleAvatar(
          radius: 30,
          backgroundImage: user.avatar != null
              ? NetworkImage(user.avatar)
              : null,
          child: user.avatar == null
              ? Text(
                  (user.name ?? 'U')[0].toUpperCase(),
                  style: const TextStyle(fontSize: 24),
                )
              : null,
        ),
        title: Text(
          user.name ?? '用户',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(user.email ?? ''),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => context.go('/settings/profile'),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  void _navigateToLedgerManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LedgerManagementScreen()),
    );
  }

  void _showLedgerSwitcher(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const LedgerSwitcherSheet(),
    );
  }

  void _navigateToLedgerSharing(BuildContext context) {
    // TODO: 实现账本共享页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('账本共享功能开发中')),
    );
  }

  void _navigateToAccountGroups(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountGroupsScreen()),
    );
  }

  void _navigateToArchivedAccounts(BuildContext context) {
    // TODO: 实现归档账户页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('归档账户功能开发中')),
    );
  }

  void _showCurrencySelector(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CurrencySelectionScreen()),
    );
  }

  void _navigateToExchangeRates(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExchangeRatesScreen()),
    );
  }

  void _navigateToBudgetTemplates(BuildContext context) {
    // TODO: 实现预算模板页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('预算模板功能开发中')),
    );
  }

  void _navigateToBackup(BuildContext context) {
    // TODO: 实现备份页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('备份功能开发中')),
    );
  }

  void _navigateToRestore(BuildContext context) {
    // TODO: 实现恢复页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('恢复功能开发中')),
    );
  }

  void _navigateToImportExport(BuildContext context) {
    // TODO: 实现导入导出页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导入导出功能开发中')),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    // TODO: 实现语言选择
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('多语言支持开发中')),
    );
  }

  void _navigateToHelp(BuildContext context) {
    // TODO: 实现帮助页面
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('帮助中心开发中')),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Jive Money',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.account_balance_wallet, size: 64),
      children: const [
        Text('智能财务管理应用'),
        SizedBox(height: 8),
        Text('让财务管理变得简单高效'),
      ],
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认退出'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).logout();
              Navigator.pop(context);
              context.go('/login');
            },
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// 账本管理页面
class LedgerManagementScreen extends ConsumerWidget {
  const LedgerManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = ref.watch(ledgersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('账本管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _createLedger(context),
          ),
        ],
      ),
      body: ledgers.when(
        data: (ledgerList) => ListView.builder(
          itemCount: ledgerList.length,
          itemBuilder: (context, index) {
            final ledger = ledgerList[index];
            return _buildLedgerTile(context, ref, ledger);
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('加载失败: $error')),
      ),
    );
  }

  Widget _buildLedgerTile(BuildContext context, WidgetRef ref, dynamic ledger) {
    final isDefault = ref.watch(currentLedgerProvider)?.id == ledger.id;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isDefault 
            ? Theme.of(context).primaryColor 
            : Colors.grey[300],
        child: Icon(
          _getLedgerIcon(ledger.type),
          color: isDefault ? Colors.white : Colors.grey[600],
        ),
      ),
      title: Text(ledger.name),
      subtitle: Text(ledger.description ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDefault)
            const Chip(
              label: Text('当前', style: TextStyle(fontSize: 12)),
              padding: EdgeInsets.zero,
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _editLedger(context, ledger);
                  break;
                case 'delete':
                  _deleteLedger(context, ref, ledger);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('编辑')),
              const PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
      onTap: () {
        if (!isDefault) {
          ref.read(currentLedgerProvider.notifier).switchLedger(ledger);
        }
      },
    );
  }

  IconData _getLedgerIcon(String type) {
    switch (type) {
      case 'personal':
        return Icons.person;
      case 'family':
        return Icons.family_restroom;
      case 'business':
        return Icons.business;
      case 'project':
        return Icons.work;
      default:
        return Icons.book;
    }
  }

  void _createLedger(BuildContext context) {
    // TODO: 实现创建账本
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('创建账本功能开发中')),
    );
  }

  void _editLedger(BuildContext context, dynamic ledger) {
    // TODO: 实现编辑账本
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('编辑账本功能开发中')),
    );
  }

  void _deleteLedger(BuildContext context, WidgetRef ref, dynamic ledger) {
    // TODO: 实现删除账本
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('删除账本功能开发中')),
    );
  }
}

// 账本切换底部弹窗
class LedgerSwitcherSheet extends ConsumerWidget {
  const LedgerSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 实现与 dashboard_screen.dart 中相同的逻辑
    return Container();
  }
}

// 账户分组页面
class AccountGroupsScreen extends StatelessWidget {
  const AccountGroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('账户分组')),
      body: const Center(child: Text('账户分组管理')),
    );
  }
}

// 货币选择页面
class CurrencySelectionScreen extends ConsumerWidget {
  const CurrencySelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencies = [
      {'code': 'CNY', 'name': '人民币', 'symbol': '¥'},
      {'code': 'USD', 'name': '美元', 'symbol': '\$'},
      {'code': 'EUR', 'name': '欧元', 'symbol': '€'},
      {'code': 'GBP', 'name': '英镑', 'symbol': '£'},
      {'code': 'JPY', 'name': '日元', 'symbol': '¥'},
      {'code': 'HKD', 'name': '港币', 'symbol': 'HK\$'},
      // 更多货币...
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('选择货币')),
      body: ListView.builder(
        itemCount: currencies.length,
        itemBuilder: (context, index) {
          final currency = currencies[index];
          return ListTile(
            leading: Text(
              currency['symbol']!,
              style: const TextStyle(fontSize: 24),
            ),
            title: Text(currency['name']!),
            subtitle: Text(currency['code']!),
            onTap: () {
              ref.read(settingsProvider.notifier).updateSetting(
                'defaultCurrency',
                '${currency['code']} - ${currency['name']}',
              );
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }
}

// 汇率管理页面
class ExchangeRatesScreen extends StatelessWidget {
  const ExchangeRatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('汇率管理')),
      body: const Center(child: Text('汇率管理')),
    );
  }
}