import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../shared/themes/app_theme.dart';
import '../controllers/settings_controller.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppTheme.background,
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.divider)),
        middle: Text('设置', style: TextStyle(color: AppTheme.textPrimary)),
      ),
      child: SafeArea(
        child: Obx(() {
          final settings = controller.settings;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            children: [
              _SectionHeader(title: '房间信息'),
              _InfoTile(
                icon: CupertinoIcons.number,
                label: '房间号',
                value: settings.roomCode.value ?? '未加入房间',
              ),
              _InfoTile(
                icon: CupertinoIcons.person,
                label: '角色',
                value: controller.roleLabel,
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: '连接'),
              _InfoTile(
                icon: CupertinoIcons.antenna_radiowaves_left_right,
                label: '服务器',
                value: controller.ws.activeUrl,
              ),
              _SettingsTile(
                icon: CupertinoIcons.pencil,
                label: '修改服务器地址',
                onTap: () => _showServerUrlDialog(context),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: '识别'),
              _SwitchTile(
                icon: CupertinoIcons.videocam,
                label: '视频识别',
                subtitle: '关闭后摄像头将停止采集',
                value: settings.videoRecognitionEnabled.value,
                onChanged: (_) => controller.toggleVideoRecognition(),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: '语音'),
              _SettingsTile(
                icon: CupertinoIcons.mic,
                label: '语音引擎',
                subtitle: settings.speechEngineDisplayName(settings.speechEngine.value),
                onTap: () => _showSpeechEnginePicker(context),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: '关于'),
              _InfoTile(
                icon: CupertinoIcons.info,
                label: '版本',
                value: '1.0.0',
              ),
              const SizedBox(height: 40),
            ],
          );
        }),
      ),
    );
  }

  void _showServerUrlDialog(BuildContext context) {
    final input = TextEditingController(text: controller.serverUrlController.text);
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('服务器地址'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: input,
            placeholder: 'ws://host:8000/ws/recognize',
            style: const TextStyle(fontSize: 13),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Get.back<void>(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            onPressed: () async {
              controller.serverUrlController.text = input.text;
              await controller.applyServerUrl(input.text);
              if (context.mounted) Get.back<void>();
            },
            child: const Text('应用'),
          ),
        ],
      ),
    );
  }

  void _showSpeechEnginePicker(BuildContext context) {
    final settings = controller.settings;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择语音引擎'),
        message: const Text('部分引擎可能需要安装额外服务'),
        actions: [
          for (final engine in settings.availableSpeechEngines)
            CupertinoActionSheetAction(
              isDefaultAction: engine == settings.speechEngine.value,
              onPressed: () {
                controller.setSpeechEngine(engine);
                Get.back<void>();
              },
              child: Text(settings.speechEngineDisplayName(engine)),
            ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Get.back<void>(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}

// ======================== Section Header ========================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppTheme.accentLight,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ======================== Info Tile (read-only) ========================

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ======================== Settings Tile (tappable) ========================

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14))),
            Expanded(
              child: Text(
                subtitle ?? '',
                textAlign: TextAlign.end,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(CupertinoIcons.chevron_right, size: 14, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}

// ======================== Switch Tile ========================

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                if (subtitle != null)
                  Text(subtitle!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: AppTheme.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
