import 'package:flutter/material.dart';
import '../models/theme_models.dart' as models;
import '../services/theme_service.dart';
import '../widgets/theme_preview_card.dart';
import '../widgets/custom_theme_editor.dart';
import '../widgets/theme_share_dialog.dart';

/// 主题管理页面
class ThemeManagementScreen extends StatefulWidget {
  const ThemeManagementScreen({super.key});

  @override
  State<ThemeManagementScreen> createState() => _ThemeManagementScreenState();
}

class _ThemeManagementScreenState extends State<ThemeManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ThemeService _themeService = ThemeService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _themeService.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('主题设置'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import_clipboard',
                child: Row(
                  children: [
                    Icon(Icons.content_paste, size: 20),
                    const SizedBox(width: 8),
                    Text('从剪贴板导入'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import_code',
                child: Row(
                  children: [
                    Icon(Icons.qr_code, size: 20),
                    const SizedBox(width: 8),
                    Text('输入分享码'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, size: 20),
                    const SizedBox(width: 8),
                    Text('重置为默认'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'eye_comfort',
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 20),
                    const SizedBox(width: 8),
                    Text('一键护眼主题'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'apply_eye_bluegrey',
                child: Row(
                  children: [
                    Icon(Icons.color_lens, size: 20),
                    const SizedBox(width: 8),
                    Text('应用护眼·蓝灰'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'apply_eye_green',
                child: Row(
                  children: [
                    Icon(Icons.color_lens, size: 20),
                    const SizedBox(width: 8),
                    Text('应用护眼·青绿'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'apply_eye_dark',
                child: Row(
                  children: [
                    Icon(Icons.dark_mode, size: 20),
                    const SizedBox(width: 8),
                    Text('应用护眼·夜间'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '系统主题'),
            Tab(text: '预设主题'),
            Tab(text: '自定义主题'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSystemThemeTab(),
          _buildPresetThemeTab(),
          _buildCustomThemeTab(),
        ],
      ),
    );
  }

  /// 系统主题标签页
  Widget _buildSystemThemeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 主题模式选择
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '主题模式',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ...models.ThemeMode.values
                    .map((mode) => RadioListTile<models.ThemeMode>(
                          title: Text(mode.displayName),
                          subtitle: Text(_getThemeModeDescription(mode)),
                          value: mode,
                          groupValue: _themeService.currentSettings.themeMode,
                          onChanged: (value) {
                            if (value != null) {
                              _themeService.setThemeMode(value);
                            }
                          },
                        )),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 当前主题信息
        if (_themeService.activeTheme != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前主题',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ThemePreviewCard(
                    theme: _themeService.activeTheme!,
                    isActive: true,
                    onTap: null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 预设主题标签页
  Widget _buildPresetThemeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '选择预设主题',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: _themeService.presetThemes.length,
          itemBuilder: (context, index) {
            final theme = _themeService.presetThemes[index];
            final isActive =
                _themeService.currentSettings.presetThemeId == theme.id;

            return ThemePreviewCard(
              theme: theme,
              isActive: isActive,
              onTap: () => _themeService.applyPresetTheme(theme.id),
              actions: [
                IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () => _shareTheme(theme),
                  tooltip: '分享主题',
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// 自定义主题标签页
  Widget _buildCustomThemeTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 创建新主题按钮
        Card(
          child: InkWell(
            onTap: _createNewTheme,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: const Column(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '创建新主题',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '根据个人喜好自定义应用主题',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 自定义主题列表
        if (_themeService.customThemes.isNotEmpty) ...[
          Text(
            '我的自定义主题',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: _themeService.customThemes.length,
            itemBuilder: (context, index) {
              final theme = _themeService.customThemes[index];
              final isActive =
                  _themeService.currentSettings.customThemeId == theme.id;

              return ThemePreviewCard(
                theme: theme,
                isActive: isActive,
                onTap: () => _themeService.applyCustomTheme(theme.id),
                actions: [
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => _editTheme(theme),
                    tooltip: '编辑主题',
                  ),
                  IconButton(
                    icon: Icon(Icons.share),
                    onPressed: () => _shareTheme(theme),
                    tooltip: '分享主题',
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert),
                    onSelected: (action) => _handleThemeAction(action, theme),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 16),
                            const SizedBox(width: 8),
                            Text('复制'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.download, size: 16),
                            const SizedBox(width: 8),
                            Text('导出'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 16, color: Colors.red),
                            const SizedBox(width: 8),
                            Text('删除', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  String _getThemeModeDescription(models.ThemeMode mode) {
    switch (mode) {
      case models.ThemeMode.light:
        return '始终使用浅色主题';
      case models.ThemeMode.dark:
        return '始终使用深色主题';
      case models.ThemeMode.system:
        return '跟随系统设置自动切换';
    }
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'import_clipboard':
        await _importFromClipboard();
        break;
      case 'import_code':
        await _showImportCodeDialog();
        break;
      case 'reset':
        await _resetToDefault();
        break;
      case 'eye_comfort':
        await ThemeService().applyEyeComfortTheme();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已应用护眼主题')),
          );
        }
        break;
      case 'apply_eye_bluegrey':
        await ThemeService().applyPresetTheme('preset_eye_bluegrey');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已应用护眼·蓝灰')),
          );
        }
        break;
      case 'apply_eye_green':
        await ThemeService().applyPresetTheme('preset_eye_green');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已应用护眼·青绿')),
          );
        }
        break;
      case 'apply_eye_dark':
        await ThemeService().applyPresetTheme('preset_eye_dark');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已应用护眼·夜间')),
          );
        }
        break;
    }
  }

  void _handleThemeAction(String action, models.CustomThemeData theme) async {
    switch (action) {
      case 'copy':
        await _copyTheme(theme);
        break;
      case 'export':
        await _exportTheme(theme);
        break;
      case 'delete':
        await _deleteTheme(theme);
        break;
    }
  }

  Future<void> _createNewTheme() async {
    final result = await Navigator.of(context).push<models.CustomThemeData>(
      MaterialPageRoute(
        builder: (context) => const CustomThemeEditor(),
      ),
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('主题"${result.name}"创建成功'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _editTheme(models.CustomThemeData theme) async {
    final result = await Navigator.of(context).push<models.CustomThemeData>(
      MaterialPageRoute(
        builder: (context) => CustomThemeEditor(theme: theme),
      ),
    );

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('主题"${result.name}"已更新'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _shareTheme(models.CustomThemeData theme) async {
    await showDialog(
      context: context,
      builder: (context) => ThemeShareDialog(theme: theme),
    );
  }

  Future<void> _copyTheme(models.CustomThemeData theme) async {
    try {
      final newTheme = await _themeService.createCustomTheme(
        name: '${theme.name} (副本)',
        author: theme.author,
        description: theme.description,
        baseTheme: theme,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('主题"${newTheme.name}"创建成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('复制失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportTheme(models.CustomThemeData theme) async {
    try {
      await _themeService.copyThemeToClipboard(theme.id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('主题已复制到剪贴板'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteTheme(models.CustomThemeData theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除主题"${theme.name}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _themeService.deleteCustomTheme(theme.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('主题"${theme.name}"已删除'),
            backgroundColor: Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importFromClipboard() async {
    try {
      final theme = await _themeService.importThemeFromClipboard();
      if (theme != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('主题"${theme.name}"导入成功'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('剪贴板中没有找到有效的主题数据'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showImportCodeDialog() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('输入分享码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('请输入8位分享码或完整的分享链接：'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '分享码或链接',
                hintText:
                    'ABCD1234 或 https://jivemoney.com/theme/import/ABCD1234',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 100,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: Text('导入'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _importTheme(result);
    }
  }

  Future<void> _importTheme(String input) async {
    try {
      models.CustomThemeData theme;

      if (input.startsWith('http')) {
        // 从URL导入
        theme = await _themeService.importThemeFromUrl(input);
      } else {
        // 从分享码导入
        theme = await _themeService.importSharedTheme(input);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('主题"${theme.name}"导入成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('重置主题'),
        content: Text('确定要重置为系统默认主题吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: Text('重置'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _themeService.resetToSystemTheme();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已重置为系统默认主题'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
