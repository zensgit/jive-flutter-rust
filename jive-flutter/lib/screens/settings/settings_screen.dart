import 'package:flutter/material.dart';
import 'package:jive_money/utils/string_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jive_money/providers/auth_provider.dart';
import 'package:jive_money/providers/ledger_provider.dart';
import 'package:jive_money/providers/settings_provider.dart';
import 'package:jive_money/providers/currency_provider.dart';
import 'package:jive_money/widgets/dialogs/create_family_dialog.dart';

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

          // 家庭管理
          _buildSection(
            title: '家庭管理',
            children: [
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('家庭设置'),
                subtitle: const Text('管理当前家庭设置'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.go('/family/settings'),
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('家庭切换'),
                subtitle:
                    Text(ref.watch(currentLedgerProvider)?.name ?? '默认家庭'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showLedgerSwitcher(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('家庭成员'),
                subtitle: const Text('管理家庭成员和权限'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.go('/family/members'),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('家庭统计'),
                subtitle: const Text('查看家庭财务统计'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.go('/family/dashboard'),
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

          // 货币设置（精简为统一入口，直接进入 V2 管理页）
          _buildSection(
            title: '多币种设置',
            children: [
              ListTile(
                leading: const Icon(Icons.language),
                title: const Text('多币种管理'),
                subtitle: const Text('基础货币、多币种/加密开关、选择货币、汇率管理'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.go('/settings/currency'),
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
                value: settings.budgetNotifications,
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .updateSetting('budgetNotifications', value);
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
                // 已恢复 CSV 导出
                subtitle: const Text('支持CSV导入，导出为 CSV/Excel/PDF/JSON'),
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
                title: const Text('主题设置'),
                subtitle: const Text('主题模式 / 列表密度 / 圆角'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.go('/settings/theme'),
              ),
              ListTile(
                leading: const Icon(Icons.label),
                title: const Text('标签管理'),
                subtitle: const Text('创建、编辑、归档与合并标签'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.go('/settings/tags'),
              ),
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('分类管理'),
                subtitle: const Text('管理收支分类和子分类'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => context.go('/settings/categories'),
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
    // Safely extract user data with fallbacks
    final userName =
        user?.name?.toString().isNotEmpty == true ? user.name.toString() : '用户';
    final userEmail = user?.email?.toString() ?? '';
    final userAvatar = user?.avatar?.toString();

    // Get safe initial for avatar
    final initial = StringUtils.safeInitial(userName);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: CircleAvatar(
            radius: 30,
            backgroundImage: userAvatar != null && userAvatar.isNotEmpty
                ? NetworkImage(userAvatar)
                : null,
            child: userAvatar == null || userAvatar.isEmpty
                ? Text(
                    initial,
                    style: const TextStyle(fontSize: 24),
                  )
                : null,
          ),
          title: Text(
            userName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: userEmail.isNotEmpty ? Text(userEmail) : null,
          trailing: IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.go('/settings/profile'),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
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
    // Navigate to currency settings in settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请在设置中管理货币')),
    );
  }

  void _navigateToExchangeRates(BuildContext context) {
    // Navigate to exchange rate screen
    context.go('/settings/exchange-rate');
  }

  void _showBaseCurrencyPicker(BuildContext context, WidgetRef ref) {
    final currencies = ref.read(availableCurrenciesProvider);
    final currentBase = ref.read(baseCurrencyProvider);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '选择基础货币',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: currencies.length,
                itemBuilder: (context, index) {
                  final currency = currencies[index];
                  final isSelected = currency.code == currentBase.code;
                  return ListTile(
                    leading: Text(
                      currency.flag ?? currency.symbol,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(currency.nameZh),
                    subtitle: Text(currency.code),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () async {
                      if (currency.code == currentBase.code) {
                        Navigator.pop(context);
                        return;
                      }
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('更换基础货币'),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('1. 旧账单若有币种转换，将保留原转换单位'),
                              SizedBox(height: 8),
                              Text('2. 旧账单若无币种转换，将以新币种显示'),
                              SizedBox(height: 8),
                              Text('3. 所有统计将以新基础货币汇总，请谨慎更换'),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange),
                              child: const Text('确定更换'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(currencyProvider.notifier)
                            .setBaseCurrency(currency.code);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
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
      children: [
        const Text('智能财务管理应用'),
        const SizedBox(height: 8),
        const Text('让财务管理变得简单高效'),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          '开发者文档',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('查看安全总览: docs/TRANSACTION_SECURITY_OVERVIEW.md')),
            );
          },
          child: const Text(
            '• 安全总览 (Security Overview)\n  docs/TRANSACTION_SECURITY_OVERVIEW.md',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('查看安全修复报告: TRANSACTION_SECURITY_FIX_REPORT.md')),
            );
          },
          child: const Text(
            '• 安全修复报告 (Security Fix Report)\n  TRANSACTION_SECURITY_FIX_REPORT.md',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('查看完整修复报告: TRANSACTION_SYSTEM_COMPLETE_FIX_REPORT.md')),
            );
          },
          child: const Text(
            '• 完整修复报告 (Complete Fix Report)\n  TRANSACTION_SYSTEM_COMPLETE_FIX_REPORT.md',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('查看变更记录: CHANGELOG.md')),
            );
          },
          child: const Text(
            '• 变更记录 (Changelog)\n  CHANGELOG.md',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        const Text(
          '第三方服务',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          '头像服务：',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () {
            // 可选：打开链接
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('DiceBear: https://dicebear.com')),
            );
          },
          child: const Text(
            '• DiceBear - MIT License\n  https://dicebear.com',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('RoboHash: https://robohash.org')),
            );
          },
          child: const Text(
            '• RoboHash - CC-BY License\n  https://robohash.org\n  由 Zikri Kader, Hrvoje Novakovic,\n  Julian Peter Arias, David Revoy 等创作',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
        ),
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

// 家庭管理页面
class LedgerManagementScreen extends ConsumerWidget {
  const LedgerManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgers = ref.watch(ledgersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('家庭管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await showDialog<bool>(
                context: context,
                builder: (context) => const CreateFamilyDialog(),
              );
              if (result == true) {
                ref.invalidate(ledgersProvider);
              }
            },
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
        backgroundColor:
            isDefault ? Theme.of(context).primaryColor : Colors.grey[300],
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

  void _createLedger(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateFamilyDialog(),
    );
    // Note: Need to pass ref from the widget context
  }

  void _editLedger(BuildContext context, dynamic ledger) {
    // TODO: 实现编辑家庭
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('编辑家庭功能开发中')),
    );
  }

  void _deleteLedger(BuildContext context, WidgetRef ref, dynamic ledger) {
    // TODO: 实现删除家庭
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('删除家庭功能开发中')),
    );
  }
}

// 家庭切换底部弹窗
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
