import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../shared/themes/app_theme.dart';
import 'lobby_controller.dart';

class LobbyPage extends GetView<LobbyController> {
  const LobbyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Logo(),
                const SizedBox(height: 48),
                _RoomCodeInput(),
                const SizedBox(height: 24),
                _RoleButtons(),
                const SizedBox(height: 12),
                _ErrorHint(),
                const SizedBox(height: 32),
                _OrDivider(),
                const SizedBox(height: 32),
                _CreateButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: const Icon(
            CupertinoIcons.hand_thumbsup_fill,
            size: 40,
            color: AppTheme.accent,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'SignBridge',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '手语实时沟通助手',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _RoomCodeInput extends GetView<LobbyController> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Column(
            children: [
              const Text(
                '加入已有房间',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: controller.roomCodeController,
                placeholder: '输入4位房间号',
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 12,
                ),
                placeholderStyle: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 20,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.glassBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.glassBorder),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleButtons extends GetView<LobbyController> {
  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: _RoleChip(
              icon: CupertinoIcons.hand_raised,
              label: '手语者',
              subtitle: '使用摄像头输入',
              onTap: controller.isJoining.value ? null : () => controller.joinRoom('signer'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _RoleChip(
              icon: CupertinoIcons.chat_bubble_2,
              label: '对话者',
              subtitle: '使用文字回复',
              onTap: controller.isJoining.value ? null : () => controller.joinRoom('chat'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({
    required this.icon,
    required this.label,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.glassBorder),
            ),
            child: Column(
              children: [
                Icon(icon, size: 28, color: AppTheme.accent),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorHint extends GetView<LobbyController> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.errorMessage.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          controller.errorMessage.value,
          style: const TextStyle(color: AppTheme.danger, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    });
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 0.5, color: AppTheme.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '或',
            style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.6), fontSize: 13),
          ),
        ),
        Expanded(child: Container(height: 0.5, color: AppTheme.divider)),
      ],
    );
  }
}

class _CreateButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = Get.find<LobbyController>();
    return Obx(
      () => Row(
        children: [
          Expanded(
            child: _CreateButton(
              icon: CupertinoIcons.hand_raised,
              label: '创建房间',
              subtitle: '手语输入',
              loading: controller.isCreating.value,
              onTap: controller.isCreating.value ? null : () => controller.createRoom('signer'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CreateButton(
              icon: CupertinoIcons.chat_bubble_2,
              label: '创建房间',
              subtitle: '文字回复',
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
    required this.loading,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accent, AppTheme.accentLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: loading
            ? const CupertinoActivityIndicator(radius: 12)
            : Column(
                children: [
                  Icon(icon, size: 24, color: AppTheme.textPrimary),
                  const SizedBox(height: 6),
                  const Text(
                    '创建房间',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
