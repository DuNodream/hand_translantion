import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../services/connection/realtime_ws_service.dart';
import '../../shared/themes/app_theme.dart';
import 'lobby_controller.dart';

class LobbyPage extends GetView<LobbyController> {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final c = AppTheme.current;
      // 主题版本号——切换时强制刷新
      AppTheme.themeVersion;
      return CupertinoPageScaffold(
        backgroundColor: c.background,
        child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Row(
                      children: [
                        const Expanded(flex: 5, child: _BrandPanel()),
                        const SizedBox(width: 28),
                        const Expanded(flex: 6, child: _ControlsPanel()),
                      ],
                    ),
                  ),
                ),
                // Settings button
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => Get.toNamed('/settings'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.glassBorder),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        CupertinoIcons.gear,
                        size: 20,
                        color: c.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    });
  }
}

// ======================== Brand Panel (Left) ========================

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                c.surface.withValues(alpha: 0.6),
                c.surface.withValues(alpha: 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: c.glassBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // App icon
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [c.accent, c.accentLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: c.accent.withValues(alpha: 0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        CupertinoIcons.hand_thumbsup_fill,
                        size: 44,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'SignBridge',
                      style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '手语实时沟通助手',
                      style: TextStyle(
                        color: c.textSecondary,
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Feature highlights
                    _FeatureRow(icon: CupertinoIcons.videocam_fill, text: '实时手语识别'),
                    const SizedBox(height: 14),
                    _FeatureRow(icon: CupertinoIcons.chat_bubble_2_fill, text: '双人实时对话'),
                    const SizedBox(height: 14),
                    _FeatureRow(icon: CupertinoIcons.mic_fill, text: '语音转文字输入'),
                    const SizedBox(height: 28),
                    // Connection status
                    const _ConnectionStatus(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                c.accent.withValues(alpha: 0.25),
                c.accentLight.withValues(alpha: 0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: c.accentLight),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    final ws = Get.find<RealtimeWsService>();
    return Obx(() {
      final connected = ws.state.value == WsState.connected;
      final color = connected ? c.success : c.textMuted;
      final label = connected ? '服务已连接' : '等待连接';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ======================== Controls Panel (Right) ========================

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: c.glassBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _JoinSection(),
                    const SizedBox(height: 28),
                    // Divider
                    Row(
                      children: [
                        Expanded(child: Container(height: 0.5, color: c.divider)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            '或',
                            style: TextStyle(
                              color: c.textMuted.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(child: Container(height: 0.5, color: c.divider)),
                      ],
                    ),
                    const SizedBox(height: 28),
                    // Create section
                    const _CreateButtons(),
                    const SizedBox(height: 20),
                    // Error message
                    const _ErrorHint(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================== Join Room Section ========================

class _JoinSection extends GetView<LobbyController> {
  const _JoinSection();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return Column(
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.qrcode_viewfinder, size: 20, color: c.accentLight),
            const SizedBox(width: 10),
            Text(
              '加入已有房间',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: CupertinoTextField(
                controller: controller.roomCodeController,
                placeholder: '输入4位房间号',
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                ),
                placeholderStyle: TextStyle(
                  color: c.textMuted,
                  fontSize: 18,
                  letterSpacing: 0,
                ),
                decoration: BoxDecoration(
                  color: c.glassBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.glassBorder),
                ),
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _RoleJoinButton(
                icon: CupertinoIcons.hand_raised,
                label: '手语者',
                loading: controller.isJoining.value,
                onTap: controller.isJoining.value ? null : () => controller.joinRoom('signer'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _RoleJoinButton(
                icon: CupertinoIcons.chat_bubble_2,
                label: '对话者',
                loading: controller.isJoining.value,
                onTap: controller.isJoining.value ? null : () => controller.joinRoom('chat'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoleJoinButton extends StatelessWidget {
  const _RoleJoinButton({
    required this.icon,
    required this.label,
    required this.loading,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.surfaceLight, c.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.glassBorder),
        ),
        alignment: Alignment.center,
        child: loading
            ? const CupertinoActivityIndicator(radius: 14)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: c.accentLight),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ======================== Create Room Section ========================

class _CreateButtons extends StatelessWidget {
  const _CreateButtons();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    final controller = Get.find<LobbyController>();
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: _CreateButton(
              icon: CupertinoIcons.hand_raised_fill,
              label: '创建房间',
              subtitle: '手语者模式 · 摄像头输入',
              gradientColors: [c.accent, c.accentLight],
              loading: controller.isCreating.value,
              onTap: controller.isCreating.value ? null : () => controller.createRoom('signer'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _CreateButton(
              icon: CupertinoIcons.chat_bubble_2_fill,
              label: '创建房间',
              subtitle: '对话者模式 · 文字回复',
              gradientColors: [const Color(0xFF7C3AED), c.accentLight],
              loading: controller.isCreating.value,
              onTap: controller.isCreating.value ? null : () => controller.createRoom('chat'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradientColors,
    required this.loading,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final List<Color> gradientColors;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: loading
            ? const CupertinoActivityIndicator(radius: 16)
            : Column(
                children: [
                  Icon(icon, size: 32, color: c.textPrimary),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ======================== Error Hint ========================

class _ErrorHint extends GetView<LobbyController> {
  const _ErrorHint();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return Obx(() {
      if (controller.errorMessage.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: c.danger.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.danger.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(CupertinoIcons.exclamationmark_triangle_fill,
                  size: 14, color: CupertinoColors.systemRed),
              const SizedBox(width: 8),
              Text(
                controller.errorMessage.value,
                style: TextStyle(color: c.danger, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    });
  }
}
