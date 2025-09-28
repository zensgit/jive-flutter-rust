import 'package:flutter/material.dart';
import 'package:jive_money/models/theme_models.dart' as models;
import 'package:jive_money/services/theme_service.dart';
import 'package:jive_money/widgets/color_picker_dialog.dart';
import 'package:jive_money/widgets/theme_preview_card.dart';

/// 自定义主题编辑器
class CustomThemeEditor extends StatefulWidget {
  final models.CustomThemeData? theme;

  const CustomThemeEditor({super.key, this.theme});

  @override
  State<CustomThemeEditor> createState() => _CustomThemeEditorState();
}

class _CustomThemeEditorState extends State<CustomThemeEditor>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ThemeService _themeService = ThemeService();

  // 表单控制器
  final _nameController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();

  // 主题颜色
  late models.CustomThemeData _editingTheme;
  bool _isEditing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _isEditing = widget.theme != null;

    if (_isEditing) {
      _editingTheme = widget.theme!;
      _nameController.text = _editingTheme.name;
      _authorController.text = _editingTheme.author;
      _descriptionController.text = _editingTheme.description;
    } else {
      _editingTheme = _createDefaultTheme();
      _authorController.text = '我';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑主题' : '创建新主题'),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.preview),
              onPressed: _previewTheme,
              tooltip: '预览主题',
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveTheme,
            tooltip: '保存主题',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '基本信息'),
            Tab(text: '主要颜色'),
            Tab(text: '界面颜色'),
            Tab(text: '状态颜色'),
            Tab(text: '外观风格'),
          ],
        ),
      ),
      body: Column(
        children: [
          // 实时预览
          Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            child: ThemePreviewCard(
              theme: _editingTheme,
              showDetails: false,
              onTap: null,
            ),
          ),

          const Divider(height: 1),

          // 编辑面板
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBasicInfoTab(),
                _buildMainColorsTab(),
                _buildUIColorsTab(),
                _buildStatusColorsTab(),
                _buildAppearanceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 基本信息标签页
  Widget _buildBasicInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 主题名称
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: '主题名称 *',
            hintText: '输入主题名称',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _editingTheme = _editingTheme.copyWith(name: value);
            });
          },
        ),

        const SizedBox(height: 16),

        // 作者
        TextField(
          controller: _authorController,
          decoration: const InputDecoration(
            labelText: '作者',
            hintText: '输入作者名称',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _editingTheme = _editingTheme.copyWith(author: value);
            });
          },
        ),

        const SizedBox(height: 16),

        // 描述
        TextField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '描述',
            hintText: '输入主题描述（可选）',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          onChanged: (value) {
            setState(() {
              _editingTheme = _editingTheme.copyWith(description: value);
            });
          },
        ),

        const SizedBox(height: 24),

        // 预设主题模板
        const Text(
          '快速开始',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '选择一个预设主题作为起点，然后自定义颜色：',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 16),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _themeService.presetThemes.take(6).map((preset) {
            return InkWell(
              onTap: () => _applyPresetTemplate(preset),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: preset.primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preset.name,
                      style: const TextStyle(fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  /// 主要颜色标签页
  Widget _buildMainColorsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildColorSection('主要颜色', [
          _ColorItem(
            title: '主色调',
            subtitle: '应用的主要品牌色',
            color: _editingTheme.primaryColor,
            onChanged: (color) => _updateColor(primaryColor: color),
          ),
          _ColorItem(
            title: '主色调变体',
            subtitle: '主色调的深色版本',
            color: _editingTheme.primaryVariant,
            onChanged: (color) => _updateColor(primaryVariant: color),
          ),
          _ColorItem(
            title: '辅助色',
            subtitle: '强调和装饰色彩',
            color: _editingTheme.secondary,
            onChanged: (color) => _updateColor(secondary: color),
          ),
          _ColorItem(
            title: '辅助色变体',
            subtitle: '辅助色的深色版本',
            color: _editingTheme.secondaryVariant,
            onChanged: (color) => _updateColor(secondaryVariant: color),
          ),
        ]),
        const SizedBox(height: 24),
        _buildColorSection('按钮颜色', [
          _ColorItem(
            title: '主要按钮背景',
            subtitle: '主要操作按钮的背景色',
            color: _editingTheme.buttonPrimary,
            onChanged: (color) => _updateColor(buttonPrimary: color),
          ),
          _ColorItem(
            title: '次要按钮背景',
            subtitle: '次要操作按钮的背景色',
            color: _editingTheme.buttonSecondary,
            onChanged: (color) => _updateColor(buttonSecondary: color),
          ),
          _ColorItem(
            title: '按钮文字色',
            subtitle: '按钮上的文字颜色',
            color: _editingTheme.buttonText,
            onChanged: (color) => _updateColor(buttonText: color),
          ),
        ]),
      ],
    );
  }

  /// 外观风格（密度与圆角）
  Widget _buildAppearanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          value: _editingTheme.listDensity == 'compact',
          onChanged: (v) {
            setState(() {
              _editingTheme = _editingTheme.copyWith(
                listDensity: v ? 'compact' : 'comfortable',
              );
            });
          },
          title: const Text('紧凑密度'),
          subtitle: const Text('减少垂直留白，显示更多列表项'),
        ),
        const SizedBox(height: 8),
        ListTile(
          leading: const Icon(Icons.crop_square_rounded),
          title: const Text('圆角大小'),
          subtitle: const Text('小 / 中 / 大'),
          trailing: DropdownButton<String>(
            value: _editingTheme.cornerRadius,
            items: const [
              DropdownMenuItem(value: 'small', child: Text('小')),
              DropdownMenuItem(value: 'medium', child: Text('中')),
              DropdownMenuItem(value: 'large', child: Text('大')),
            ],
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _editingTheme = _editingTheme.copyWith(cornerRadius: v);
                });
              }
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '提示：密度与圆角设置会随主题一起保存/分享，应用到卡片、输入框、列表等组件。',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
        )
      ],
    );
  }

  /// 界面颜色标签页
  Widget _buildUIColorsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildColorSection('背景颜色', [
          _ColorItem(
            title: '主背景色',
            subtitle: '应用的主要背景颜色',
            color: _editingTheme.background,
            onChanged: (color) => _updateColor(background: color),
          ),
          _ColorItem(
            title: '表面色',
            subtitle: '卡片和对话框的背景色',
            color: _editingTheme.surface,
            onChanged: (color) => _updateColor(surface: color),
          ),
          _ColorItem(
            title: '表面变体色',
            subtitle: '次要表面元素的背景色',
            color: _editingTheme.surfaceVariant,
            onChanged: (color) => _updateColor(surfaceVariant: color),
          ),
          _ColorItem(
            title: '卡片背景色',
            subtitle: '卡片组件的背景颜色',
            color: _editingTheme.cardColor,
            onChanged: (color) => _updateColor(cardColor: color),
          ),
        ]),
        const SizedBox(height: 24),
        _buildColorSection('文字颜色', [
          _ColorItem(
            title: '主色上的文字',
            subtitle: '在主色调背景上的文字颜色',
            color: _editingTheme.onPrimary,
            onChanged: (color) => _updateColor(onPrimary: color),
          ),
          _ColorItem(
            title: '辅助色上的文字',
            subtitle: '在辅助色背景上的文字颜色',
            color: _editingTheme.onSecondary,
            onChanged: (color) => _updateColor(onSecondary: color),
          ),
          _ColorItem(
            title: '背景上的文字',
            subtitle: '在主背景上的文字颜色',
            color: _editingTheme.onBackground,
            onChanged: (color) => _updateColor(onBackground: color),
          ),
          _ColorItem(
            title: '表面上的文字',
            subtitle: '在表面背景上的文字颜色',
            color: _editingTheme.onSurface,
            onChanged: (color) => _updateColor(onSurface: color),
          ),
        ]),
        const SizedBox(height: 24),
        _buildColorSection('边框和分隔', [
          _ColorItem(
            title: '分隔线颜色',
            subtitle: '分隔线和分割元素的颜色',
            color: _editingTheme.dividerColor,
            onChanged: (color) => _updateColor(dividerColor: color),
          ),
          _ColorItem(
            title: '边框颜色',
            subtitle: '输入框和卡片边框的颜色',
            color: _editingTheme.borderColor,
            onChanged: (color) => _updateColor(borderColor: color),
          ),
        ]),
      ],
    );
  }

  /// 状态颜色标签页
  Widget _buildStatusColorsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildColorSection('导航颜色', [
          _ColorItem(
            title: '导航栏背景',
            subtitle: '顶部和底部导航栏背景色',
            color: _editingTheme.navigationBar,
            onChanged: (color) => _updateColor(navigationBar: color),
          ),
          _ColorItem(
            title: '导航栏文字',
            subtitle: '导航栏上的文字和图标颜色',
            color: _editingTheme.navigationBarText,
            onChanged: (color) => _updateColor(navigationBarText: color),
          ),
          _ColorItem(
            title: '导航栏选中',
            subtitle: '选中的导航项颜色',
            color: _editingTheme.navigationBarSelected,
            onChanged: (color) => _updateColor(navigationBarSelected: color),
          ),
        ]),
        const SizedBox(height: 24),
        _buildColorSection('状态颜色', [
          _ColorItem(
            title: '错误色',
            subtitle: '错误和危险操作的颜色',
            color: _editingTheme.error,
            onChanged: (color) => _updateColor(error: color),
          ),
          _ColorItem(
            title: '错误色上的文字',
            subtitle: '在错误色背景上的文字颜色',
            color: _editingTheme.onError,
            onChanged: (color) => _updateColor(onError: color),
          ),
          _ColorItem(
            title: '成功色',
            subtitle: '成功状态的颜色',
            color: _editingTheme.success,
            onChanged: (color) => _updateColor(success: color),
          ),
          _ColorItem(
            title: '警告色',
            subtitle: '警告状态的颜色',
            color: _editingTheme.warning,
            onChanged: (color) => _updateColor(warning: color),
          ),
          _ColorItem(
            title: '信息色',
            subtitle: '信息提示的颜色',
            color: _editingTheme.info,
            onChanged: (color) => _updateColor(info: color),
          ),
        ]),
      ],
    );
  }

  Widget _buildColorSection(String title, List<_ColorItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildColorTile(item),
            )),
      ],
    );
  }

  Widget _buildColorTile(_ColorItem item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: InkWell(
        onTap: () => _showColorPicker(item.color, item.onChanged),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.grey[300]!),
          ),
        ),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(item.subtitle),
      trailing: Text(
        '#${item.color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
      onTap: () => _showColorPicker(item.color, item.onChanged),
    );
  }

  void _showColorPicker(Color currentColor, ValueChanged<Color> onChanged) {
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        initialColor: currentColor,
        onColorChanged: onChanged,
      ),
    );
  }

  void _updateColor({
    Color? primaryColor,
    Color? primaryVariant,
    Color? secondary,
    Color? secondaryVariant,
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? onPrimary,
    Color? onSecondary,
    Color? onBackground,
    Color? onSurface,
    Color? error,
    Color? onError,
    Color? success,
    Color? warning,
    Color? info,
    Color? cardColor,
    Color? dividerColor,
    Color? borderColor,
    Color? buttonPrimary,
    Color? buttonSecondary,
    Color? buttonText,
    Color? navigationBar,
    Color? navigationBarText,
    Color? navigationBarSelected,
  }) {
    setState(() {
      _editingTheme = _editingTheme.copyWith(
        primaryColor: primaryColor,
        primaryVariant: primaryVariant,
        secondary: secondary,
        secondaryVariant: secondaryVariant,
        background: background,
        surface: surface,
        surfaceVariant: surfaceVariant,
        onPrimary: onPrimary,
        onSecondary: onSecondary,
        onBackground: onBackground,
        onSurface: onSurface,
        error: error,
        onError: onError,
        success: success,
        warning: warning,
        info: info,
        cardColor: cardColor,
        dividerColor: dividerColor,
        borderColor: borderColor,
        buttonPrimary: buttonPrimary,
        buttonSecondary: buttonSecondary,
        buttonText: buttonText,
        navigationBar: navigationBar,
        navigationBarText: navigationBarText,
        navigationBarSelected: navigationBarSelected,
      );
    });
  }

  void _applyPresetTemplate(models.CustomThemeData preset) {
    setState(() {
      _editingTheme = preset.copyWith(
        id: _editingTheme.id,
        name: _nameController.text.isEmpty ? preset.name : _nameController.text,
        author: _authorController.text,
        description: _descriptionController.text,
        createdAt: _editingTheme.createdAt,
        updatedAt: DateTime.now(),
        isShared: false,
        downloads: 0,
        rating: 0.0,
      );
    });

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('已应用"${preset.name}"模板'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _previewTheme() {
    // 临时应用主题进行预览
    showDialog(
      context: context,
      builder: (context) => Theme(
        data: _editingTheme.toFlutterThemeData(),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('主题预览'),
            centerTitle: true,
            backgroundColor: _editingTheme.navigationBar,
            foregroundColor: _editingTheme.navigationBarText,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 示例卡片
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '示例标题',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _editingTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '这是一段示例文本，用于展示主题在实际应用中的效果。',
                        style: TextStyle(color: _editingTheme.onSurface),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {},
                            child: const Text('主要按钮'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {},
                            child: const Text('次要按钮'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 密度与圆角预览
                      SwitchListTile(
                        value: _editingTheme.listDensity == 'compact',
                        onChanged: (v) {
                          setState(() {
                            _editingTheme = _editingTheme.copyWith(
                              listDensity: v ? 'compact' : 'comfortable',
                            );
                          });
                        },
                        title: const Text('紧凑密度'),
                        subtitle: const Text('减少垂直留白以显示更多内容'),
                      ),
                      ListTile(
                        title: const Text('圆角大小'),
                        trailing: DropdownButton<String>(
                          value: _editingTheme.cornerRadius,
                          items: const [
                            DropdownMenuItem(value: 'small', child: Text('小')),
                            DropdownMenuItem(value: 'medium', child: Text('中')),
                            DropdownMenuItem(value: 'large', child: Text('大')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                _editingTheme =
                                    _editingTheme.copyWith(cornerRadius: v);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => Navigator.of(context).pop(),
            backgroundColor: _editingTheme.primaryColor,
            child: const Icon(Icons.close),
          ),
        ),
      ),
    );
  }

  Future<void> _saveTheme() async {
    // Capture before awaits to avoid using context across async gaps
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_nameController.text.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('请输入主题名称'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final finalTheme = _editingTheme.copyWith(
        name: _nameController.text.trim(),
        author: _authorController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (_isEditing) {
        await _themeService.updateCustomTheme(_editingTheme.id, finalTheme);
      } else {
        await _themeService.createCustomTheme(
          name: finalTheme.name,
          author: finalTheme.author,
          description: finalTheme.description,
          baseTheme: finalTheme,
        );
      }

      if (!context.mounted) return;

      navigator.pop(finalTheme);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  models.CustomThemeData _createDefaultTheme() {
    return models.CustomThemeData(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      name: '',
      author: '',
      description: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isShared: false,
      downloads: 0,
      rating: 0.0,
      primaryColor: const Color(0xFF2196F3),
      primaryVariant: const Color(0xFF1976D2),
      secondary: const Color(0xFF03DAC6),
      secondaryVariant: const Color(0xFF018786),
      background: Colors.white,
      surface: Colors.white,
      surfaceVariant: const Color(0xFFF5F5F5),
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onBackground: Colors.black87,
      onSurface: Colors.black87,
      error: const Color(0xFFB00020),
      onError: Colors.white,
      success: const Color(0xFF4CAF50),
      warning: const Color(0xFFFF9800),
      info: const Color(0xFF2196F3),
      cardColor: Colors.white,
      dividerColor: const Color(0xFFE0E0E0),
      borderColor: const Color(0xFFE0E0E0),
      buttonPrimary: Colors.black,
      buttonSecondary: Colors.white,
      buttonText: Colors.white,
      navigationBar: Colors.white,
      navigationBarText: Colors.black87,
      navigationBarSelected: const Color(0xFF2196F3),
    );
  }
}

class _ColorItem {
  final String title;
  final String subtitle;
  final Color color;
  final ValueChanged<Color> onChanged;

  _ColorItem({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onChanged,
  });
}
