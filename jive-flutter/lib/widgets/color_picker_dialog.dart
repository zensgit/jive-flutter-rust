import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 颜色选择器对话框
class ColorPickerDialog extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const ColorPickerDialog({
    super.key,
    required this.initialColor,
    required this.onColorChanged,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late Color _selectedColor;
  late TextEditingController _hexController;

  // 预设颜色
  static const List<Color> _presetColors = [
    // 红色系
    Color(0xFFFF5722), Color(0xFFF44336), Color(0xFFE91E63), Color(0xFF9C27B0),
    // 蓝色系
    Color(0xFF3F51B5), Color(0xFF2196F3), Color(0xFF03DAC6), Color(0xFF00BCD4),
    // 绿色系
    Color(0xFF4CAF50), Color(0xFF8BC34A), Color(0xFFCDDC39), Color(0xFFFFEB3B),
    // 橙色系
    Color(0xFFFF9800), Color(0xFFFF5722), Color(0xFF795548), Color(0xFF607D8B),
    // 灰色系
    Color(0xFF9E9E9E), Color(0xFF666666), Color(0xFF333333), Color(0xFF000000),
    // 白色系
    Color(0xFFFFFFFF), Color(0xFFF5F5F5), Color(0xFFE0E0E0), Color(0xFFBDBDBD),
  ];

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _hexController = TextEditingController(
      text: _selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase(),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('选择颜色'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 当前颜色预览
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: _selectedColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
            ),

            const SizedBox(height: 16),

            // 十六进制输入
            TextField(
              controller: _hexController,
              decoration: InputDecoration(
                labelText: '十六进制颜色值',
                hintText: 'FFFFFF',
                border: const OutlineInputBorder(),
                prefixText: '#',
              ),
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                UpperCaseTextFormatter(),
              ],
              onChanged: _onHexChanged,
            ),

            const SizedBox(height: 16),

            // RGB滑块
            _buildRGBSliders(),

            const SizedBox(height: 16),

            // 预设颜色
            const Text(
              '预设颜色',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _buildPresetColors(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onColorChanged(_selectedColor);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _buildRGBSliders() {
    return Column(
      children: [
        _buildSlider(
          'R',
          (((_selectedColor.r) * 255.0).round() & 0xff).toDouble(),
          Colors.red,
          (value) => _updateColor(red: value.toInt()),
        ),
        _buildSlider(
          'G',
          (((_selectedColor.g) * 255.0).round() & 0xff).toDouble(),
          Colors.green,
          (value) => _updateColor(green: value.toInt()),
        ),
        _buildSlider(
          'B',
          (((_selectedColor.b) * 255.0).round() & 0xff).toDouble(),
          Colors.blue,
          (value) => _updateColor(blue: value.toInt()),
        ),
      ],
    );
  }

  Widget _buildSlider(
    String label,
    double value,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.3),
              ),
              child: Slider(
                value: value,
                min: 0,
                max: 255,
                divisions: 255,
                onChanged: onChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              value.toInt().toString(),
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetColors() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _presetColors.map((color) {
        final isSelected = _selectedColor.toARGB32() == color.toARGB32();
        return InkWell(
          onTap: () => _selectColor(color),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: isSelected
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }

  void _selectColor(Color color) {
    setState(() {
      _selectedColor = color;
      _hexController.text =
          color.toARGB32().toRadixString(16).substring(2).toUpperCase();
    });
  }

  void _updateColor({int? red, int? green, int? blue}) {
    setState(() {
      _selectedColor = Color.fromARGB(
        255,
        red ?? (((_selectedColor.r) * 255.0).round() & 0xff),
        green ?? (((_selectedColor.g) * 255.0).round() & 0xff),
        blue ?? (((_selectedColor.b) * 255.0).round() & 0xff),
      );
      _hexController.text =
          _selectedColor.toARGB32().toRadixString(16).substring(2).toUpperCase();
    });
  }

  void _onHexChanged(String value) {
    if (value.length == 6) {
      try {
        final color = Color(int.parse('FF$value', radix: 16));
        setState(() {
          _selectedColor = color;
        });
      } catch (e) {
        // 忽略无效的十六进制值
      }
    }
  }
}

/// 将输入转换为大写的文本格式化器
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
