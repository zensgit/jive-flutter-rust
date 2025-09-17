import 'package:flutter/material.dart';

/// 密码强度等级
enum PasswordStrength {
  weak('弱', Colors.red, 0.25),
  fair('一般', Colors.orange, 0.5),
  good('良好', Colors.yellow, 0.75),
  strong('强', Colors.green, 1.0);

  const PasswordStrength(this.description, this.color, this.value);

  final String description;
  final Color color;
  final double value;
}

/// 密码强度检查器
class PasswordStrengthChecker {
  /// 检查密码强度
  static PasswordStrength checkStrength(String password) {
    if (password.isEmpty) {
      return PasswordStrength.weak;
    }

    int score = 0;

    // 长度检查
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;

    // 包含小写字母
    if (password.contains(RegExp(r'[a-z]'))) score++;

    // 包含大写字母
    if (password.contains(RegExp(r'[A-Z]'))) score++;

    // 包含数字
    if (password.contains(RegExp(r'[0-9]'))) score++;

    // 包含特殊字符
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    // 没有连续相同字符
    if (!password.contains(RegExp(r'(.)\1{2,}'))) score++;

    // 根据得分返回强度
    switch (score) {
      case 0:
      case 1:
      case 2:
        return PasswordStrength.weak;
      case 3:
      case 4:
        return PasswordStrength.fair;
      case 5:
        return PasswordStrength.good;
      case 6:
      case 7:
        return PasswordStrength.strong;
      default:
        return PasswordStrength.weak;
    }
  }

  /// 获取密码强度建议
  static List<String> getStrengthSuggestions(String password) {
    List<String> suggestions = [];

    if (password.length < 8) {
      suggestions.add('至少8个字符');
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      suggestions.add('包含小写字母');
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      suggestions.add('包含大写字母');
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      suggestions.add('包含数字');
    }

    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      suggestions.add('包含特殊字符');
    }

    if (password.contains(RegExp(r'(.)\1{2,}'))) {
      suggestions.add('避免连续相同字符');
    }

    return suggestions;
  }
}
