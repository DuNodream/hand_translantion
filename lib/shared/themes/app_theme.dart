import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

class ThemePreset {
  final String name;
  final Color background;
  final Color surface;
  final Color surfaceLight;
  final Color glassBg;
  final Color glassBorder;
  final Color divider;
  final Color accent;
  final Color accentLight;
  final Color success;
  final Color warning;
  final Color danger;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color chatBubbleMe;
  final Color chatBubbleOther;

  const ThemePreset({
    required this.name,
    required this.background,
    required this.surface,
    required this.surfaceLight,
    required this.glassBg,
    required this.glassBorder,
    required this.divider,
    required this.accent,
    required this.accentLight,
    required this.success,
    required this.warning,
    required this.danger,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.chatBubbleMe,
    required this.chatBubbleOther,
  });
}

class AppTheme {
  // 背景 & 表面
  static const Color background = Color(0xFF0F0F1A);
  static const Color surface = Color(0xFF1A1A2E);
  static const Color surfaceLight = Color(0xFF252542);

  // 边框 & 玻璃态
  static const Color glassBg = Color(0x0DFFFFFF);
  static const Color glassBorder = Color(0x1AFFFFFF);
  static const Color divider = Color(0x33FFFFFF);

  // 强调色（靛蓝）
  static const Color accent = Color(0xFF4F46E5);
  static const Color accentLight = Color(0xFF6366F1);

  // 状态色
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // 文字
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF9CA3AF);

  // 聊天气泡
  static const Color chatBubbleMe = Color(0xFF4F46E5);
  static const Color chatBubbleOther = Color(0x1AFFFFFF);

  static const CupertinoThemeData cupertinoTheme = CupertinoThemeData(
    brightness: Brightness.dark,
    primaryColor: accent,
    scaffoldBackgroundColor: background,
    barBackgroundColor: surface,
    textTheme: CupertinoTextThemeData(
      primaryColor: textPrimary,
      textStyle: TextStyle(color: textPrimary, fontSize: 16),
    ),
  );

  /// 运行时主题色（由 ThemeService 更新），响应式 — 在 Obx 中读取即可自动追踪
  static ThemePreset get current => _currentRx.value;
  static set current(ThemePreset v) {
    _currentRx.value = v;
    _themeVersion.value++;
  }

  static final Rx<ThemePreset> _currentRx = Rx<ThemePreset>(_defaultPreset);

  /// 每次主题切换时递增，供页面强制刷新用
  static final RxInt _themeVersion = 0.obs;
  static int get themeVersion => _themeVersion.value;

  static const ThemePreset _defaultPreset = ThemePreset(
    name: '深空靛蓝',
    background: Color(0xFF0F0F1A),
    surface: Color(0xFF1A1A2E),
    surfaceLight: Color(0xFF252542),
    glassBg: Color(0x0DFFFFFF),
    glassBorder: Color(0x1AFFFFFF),
    divider: Color(0x33FFFFFF),
    accent: Color(0xFF4F46E5),
    accentLight: Color(0xFF6366F1),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFCBD5E1),
    textMuted: Color(0xFF9CA3AF),
    chatBubbleMe: Color(0xFF4F46E5),
    chatBubbleOther: Color(0x1AFFFFFF),
  );
}
