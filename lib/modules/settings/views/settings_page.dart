import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../services/theme/theme_service.dart';
import '../../../services/wakelock/wakelock_service.dart';
import '../../../shared/themes/app_theme.dart';
import '../controllers/settings_controller.dart';

class SettingsPage extends GetView<SettingsController> {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
        final c = AppTheme.current;
        // 主题版本号——切换时强制刷新
        AppTheme.themeVersion;
        return CupertinoPageScaffold(
          backgroundColor: c.background,
          navigationBar: CupertinoNavigationBar(
            backgroundColor: c.surface,
            border: Border(bottom: BorderSide(color: c.divider)),
            middle: Text('设置', style: TextStyle(color: c.textPrimary)),
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
              const SizedBox(height: 16),
              _SwitchTile(
                icon: CupertinoIcons.person_2,
                label: '人像引导框',
                subtitle: '开启后人在框消失人不在框出现',
                value: settings.personGuideEnabled.value,
                onChanged: (_) => controller.togglePersonGuide(),
              ),
              // 作弊者模式（版本点击 5 次解锁）
              if (controller.versionTapCount.value >= 5) ...[
                const SizedBox(height: 16),
                _SwitchTile(
                  icon: CupertinoIcons.eyedropper_halffull,
                  label: '作弊者模式',
                  subtitle: '开启后无论比什么手语都按固定剧本对话',
                  value: settings.cheaterMode.value,
                  onChanged: (_) => controller.toggleCheaterMode(),
                ),
                if (settings.cheaterMode.value) ...[
                  const SizedBox(height: 12),
                  _CheaterScriptEditor(),
                ],
              ],
              const SizedBox(height: 24),
              _SectionHeader(title: '显示'),
              _SwitchTile(
                icon: CupertinoIcons.sun_max,
                label: '屏幕常亮',
                subtitle: '保持屏幕不息屏',
                value: Get.find<WakeLockService>().enabled.value,
                onChanged: (_) => Get.find<WakeLockService>().toggle(),
              ),
              const SizedBox(height: 24),
              _SectionHeader(title: '主题'),
              _SettingsTile(
                icon: CupertinoIcons.paintbrush,
                label: '主题配色',
                subtitle: Get.find<ThemeService>().currentName,
                onTap: () => _showThemePicker(context),
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
              _SectionHeader(title: '模型'),
              _SettingsTile(
                icon: CupertinoIcons.tray_full,
                label: '识别模型',
                subtitle: controller.currentModelLabel,
                onTap: () => _showModelPicker(context),
              ),
              if (settings.devModeEnabled.value) ...[
                const SizedBox(height: 24),
                _SectionHeader(title: '开发者模式'),
                _SwitchTile(
                  icon: CupertinoIcons.hammer,
                  label: '启用开发者模式',
                  subtitle: '显示高级选项和调试功能',
                  value: settings.devModeEnabled.value,
                  onChanged: (_) => controller.toggleDevMode(),
                ),
                if (settings.devModeEnabled.value) ...[
                  const SizedBox(height: 16),
                  _SettingsTile(
                    icon: CupertinoIcons.eye,
                    label: '直接进入识别页',
                    subtitle: '跳过房间创建，直接进入手语识别',
                    onTap: controller.enterDevRecognitionPage,
                  ),
                ],
              ] else ...[
                const SizedBox(height: 24),
                _SectionHeader(title: '开发者'),
                _SwitchTile(
                  icon: CupertinoIcons.hammer,
                  label: '开发者模式',
                  subtitle: '显示高级选项和调试功能',
                  value: settings.devModeEnabled.value,
                  onChanged: (_) => controller.toggleDevMode(),
                ),
              ],
              const SizedBox(height: 24),
              _SectionHeader(title: '关于'),
              GestureDetector(
                onTap: controller.onVersionTap,
                child: _InfoTile(
                  icon: CupertinoIcons.info,
                  label: '版本',
                  value: '1.0.0',
                ),
              ),
              const SizedBox(height: 40),
            ],
          );
        }),
      ),
    );
    });
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

  void _showThemePicker(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择主题配色'),
        actions: [
          for (int i = 0; i < themeService.presetCount; i++)
            CupertinoActionSheetAction(
              isDefaultAction: i == themeService.currentIndex,
              onPressed: () {
                themeService.apply(i);
                Get.back<void>();
              },
              child: Text(themeService.presetNames[i]),
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

  void _showModelPicker(BuildContext context) {
    final settings = controller.settings;
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('选择识别模型'),
        message: const Text('切换模型后将在下一次识别时生效'),
        actions: [
          for (final model in settings.availableModels)
            CupertinoActionSheetAction(
              isDefaultAction: model == settings.selectedModel.value,
              onPressed: () {
                controller.selectModel(model);
                Get.back<void>();
              },
              child: Text(model),
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
        style: TextStyle(
          color: AppTheme.current.accentLight,
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
    final c = AppTheme.current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: c.textPrimary,
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
    final c = AppTheme.current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: c.textMuted),
            const SizedBox(width: 12),
            SizedBox(width: 80, child: Text(label, style: TextStyle(color: c.textSecondary, fontSize: 14))),
            Expanded(
              child: Text(
                subtitle ?? '',
                textAlign: TextAlign.end,
                style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Icon(CupertinoIcons.chevron_right, size: 14, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

// ======================== Cheat Script Editor ========================

class _CheaterScriptEditor extends GetView<SettingsController> {
  @override
  Widget build(BuildContext context) {
    final settings = controller.settings;
    final c = AppTheme.current;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('自定义剧本', style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...List.generate(settings.cheaterScript.length, (i) {
            final textCtl = TextEditingController(text: settings.cheaterScript[i]);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child: Text('${i + 1}', style: TextStyle(color: c.textMuted, fontSize: 12)),
                  ),
                  Expanded(
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: c.glassBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: c.glassBorder),
                      ),
                      child: CupertinoTextField(
                        controller: textCtl,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        style: TextStyle(color: c.textPrimary, fontSize: 13),
                        decoration: const BoxDecoration(),
                        onChanged: (val) => settings.updateCheaterScript(i, val),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      if (settings.cheaterScript.length > 1) {
                        settings.removeCheaterScriptItem(i);
                      }
                    },
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: c.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      alignment: Alignment.center,
                      child: Icon(CupertinoIcons.minus, size: 12, color: c.danger),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => settings.addCheaterScriptItem(''),
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: c.glassBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.glassBorder, style: BorderStyle.solid),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.plus, size: 14, color: c.accentLight),
                  const SizedBox(width: 6),
                  Text('添加句子', style: TextStyle(color: c.accentLight, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
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
    final c = AppTheme.current;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: c.textSecondary, fontSize: 14)),
                if (subtitle != null)
                  Text(subtitle!, style: TextStyle(color: c.textMuted, fontSize: 11)),
              ],
            ),
          ),
          CupertinoSwitch(
            value: value,
            activeTrackColor: c.accent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
