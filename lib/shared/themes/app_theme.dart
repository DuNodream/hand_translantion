import 'package:flutter/cupertino.dart';

class AppTheme {
  // 背景 & 表面
  static const background = Color(0xFF0F0F1A);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceLight = Color(0xFF252542);

  // 边框 & 玻璃态
  static const glassBg = Color(0x0DFFFFFF);
  static const glassBorder = Color(0x1AFFFFFF);
  static const divider = Color(0x33FFFFFF);

  // 强调色（靛蓝）
  static const accent = Color(0xFF4F46E5);
  static const accentLight = Color(0xFF6366F1);

  // 状态色
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  // 文字
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFCBD5E1);
  static const textMuted = Color(0xFF9CA3AF);

  // 聊天气泡
  static const chatBubbleMe = Color(0xFF4F46E5);
  static const chatBubbleOther = Color(0x1AFFFFFF);

  static const cupertinoTheme = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: accent,
    scaffoldBackgroundColor: background,
    barBackgroundColor: surface,
    textTheme: CupertinoTextThemeData(
      primaryColor: textPrimary,
      textStyle: TextStyle(color: textPrimary, fontSize: 16),
    ),
  );
}
