import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../data/models/chat_message.dart';
import '../../../services/camera/camera_service.dart';
import '../../../services/connection/realtime_ws_service.dart';
import '../../../services/debug/debug_log_service.dart';
import '../../../services/session/session_service.dart';
import '../../../services/settings/runtime_settings_service.dart';
import '../../../services/speech/speech_service.dart';
import '../../../services/wakelock/wakelock_service.dart';
import '../../../shared/themes/app_theme.dart';
import '../controllers/home_page_controller.dart';

class HomePage extends GetView<HomePageController> {
  const HomePage({super.key, this.role = 'signer', this.roomId = ''});

  final String role;
  final String roomId;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<RuntimeSettingsService>();
    return Obx(() {
        // 主题版本号——主题切换时强制刷新整个页面
        AppTheme.themeVersion;
        final c = AppTheme.current;
        return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(settings.textScale.value),
            ),
            child: CupertinoPageScaffold(
              backgroundColor: c.background,
              child: SafeArea(
                child: Obx(() {
              // 主题版本号——主题切换时强制刷新子树
              AppTheme.themeVersion;
              if (controller.showLoading) {
                return const _LoadingState();
              }
              if (controller.showPermissionGuide) {
                return _PermissionState(controller: controller);
              }
              if (controller.showCameraError) {
                return _ErrorState(
                  title: '摄像头不可用',
                  description: controller.cameraService.errorText.value ??
                      '请检查摄像头权限或重新初始化设备摄像头。',
                  actionLabel: '重试',
                  onAction: controller.retryAll,
                );
              }
              return Column(
                children: [
                  _TopBar(),
                  Expanded(child: _WorkbenchLayout()),
                ],
              );
            }),
          ),
        ),
        );
    });
  }
}

// ======================== Top Bar ========================

class _TopBar extends GetView<HomePageController> {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      AppTheme.themeVersion;
      final c = AppTheme.current;
      final ws = Get.find<RealtimeWsService>();
      final settings = Get.find<RuntimeSettingsService>();
      final connected = ws.state.value == WsState.connected;
      final wsColor = connected ? c.success : c.warning;
      final wsLabel = switch (ws.state.value) {
        WsState.connected => '在线',
        WsState.connecting => '连接中',
        WsState.reconnecting => '重连中',
        WsState.error => '错误',
        WsState.disconnected => '离线',
        WsState.idle => '空闲',
      };

      return ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.8),
              border: Border(bottom: BorderSide(color: c.divider)),
            ),
            child: SafeArea(
              top: true,
              bottom: false,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    // Room info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.number, size: 13, color: c.accentLight),
                          const SizedBox(width: 6),
                          Text(
                            settings.roomCode.value ?? '---',
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: controller.isSigner.value
                            ? c.accent.withValues(alpha: 0.12)
                            : const Color(0xFF7C3AED).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            controller.isSigner.value
                                ? CupertinoIcons.hand_raised
                                : CupertinoIcons.chat_bubble_2,
                            size: 12,
                            color: c.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            controller.isSigner.value ? '手语者' : '对话者',
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Connection status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: wsColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: wsColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: wsColor.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            wsLabel,
                            style: TextStyle(
                              color: wsColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Session timer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.glassBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.clock, size: 12, color: c.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            controller.sessionDuration.value,
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick settings toggle
                    GestureDetector(
                      onTap: () => controller.showQuickSettings.toggle(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: controller.showQuickSettings.value
                              ? c.accent.withValues(alpha: 0.2)
                              : c.glassBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: controller.showQuickSettings.value
                                ? c.accent.withValues(alpha: 0.3)
                                : c.glassBorder,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          CupertinoIcons.slider_horizontal_3,
                          size: 14,
                          color: controller.showQuickSettings.value
                              ? c.accentLight
                              : c.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Settings
                    GestureDetector(
                      onTap: () => Get.toNamed('/settings'),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.glassBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.glassBorder),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          CupertinoIcons.gear,
                          size: 14,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Destroy room (creator only)
                    if (controller.isCreator)
                      GestureDetector(
                        onTap: () => _confirmDestroy(context),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c.danger.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: c.danger.withValues(alpha: 0.3)),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            CupertinoIcons.trash,
                            size: 14,
                            color: c.danger,
                          ),
                        ),
                      ),
                    if (controller.isCreator) const SizedBox(width: 8),
                    // Leave
                    GestureDetector(
                      onTap: () => _confirmLeave(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: c.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: c.danger.withValues(alpha: 0.2)),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          CupertinoIcons.clear,
                          size: 14,
                          color: c.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  void _confirmLeave(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('离开房间'),
        content: const Text('确定要离开当前房间吗？'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Get.back<void>(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Get.back<void>();
              controller.leaveRoom();
            },
            child: const Text('离开'),
          ),
        ],
      ),
    );
  }

  void _confirmDestroy(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('销毁房间'),
        content: const Text('确定要销毁当前房间吗？\n双方都将断开连接。'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Get.back<void>(),
            child: const Text('取消'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Get.back<void>();
              controller.destroyRoom();
            },
            child: const Text('销毁'),
          ),
        ],
      ),
    );
  }
}

// ======================== Quick Settings Overlay ========================

class _QuickSettingsPanel extends GetView<HomePageController> {
  const _QuickSettingsPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      AppTheme.themeVersion;
      final c = AppTheme.current;
      final settings = Get.find<RuntimeSettingsService>();
      final wakeLock = Get.find<WakeLockService>();
      return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '快捷设置',
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                AppTheme.themeVersion;
                return _QuickSwitch(
                icon: CupertinoIcons.videocam,
                label: '视频识别',
                value: settings.videoRecognitionEnabled.value,
                onChanged: (_) => settings.toggleVideoRecognition(),
              );
              }),
              const SizedBox(height: 10),
              Obx(() {
                AppTheme.themeVersion;
                return _QuickSwitch(
                icon: CupertinoIcons.sun_max,
                label: '屏幕常亮',
                value: wakeLock.enabled.value,
                onChanged: (_) => wakeLock.toggle(),
              );
              }),
              const SizedBox(height: 10),
              Obx(() {
                AppTheme.themeVersion;
                return _QuickSwitch(
                icon: CupertinoIcons.textformat_size,
                label: '大字体',
                value: settings.textScale.value > 1.0,
                onChanged: (v) => settings.textScale.value = v ? 1.3 : 1.0,
              );
              }),
            ],
          ),
        ),
      ),
      );
    });
}
}

// ======================== Debug Overlay (开发者模式) ========================

class _DebugOverlay extends GetView<HomePageController> {
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    final debug = Get.find<DebugLogService>();
    final settings = Get.find<RuntimeSettingsService>();
    final ws = Get.find<RealtimeWsService>();
    return GestureDetector(
      onTap: () => controller.showDebugOverlay.value = false,
      child: Container(
        color: const Color(0xCC000000),
        child: SafeArea(
          child: GestureDetector(
            onTap: () {}, // 阻止点击穿透
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.hammer_fill, size: 18, color: c.warning),
                      const SizedBox(width: 8),
                      Text('开发者调试面板',
                        style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => controller.showDebugOverlay.value = false,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: c.glassBg, borderRadius: BorderRadius.circular(8)),
                          child: Icon(CupertinoIcons.xmark, size: 14, color: c.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Session info
                  _debugRow(c, '房间', settings.roomCode.value ?? '无'),
                  _debugRow(c, '角色', settings.role.value ?? '无'),
                  _debugRow(c, 'Session', controller.sessionService.sessionId.value),
                  _debugRow(c, 'WS 状态', ws.state.value.name),
                  _debugRow(c, 'WS URL', ws.activeUrl),
                  _debugRow(c, '模型', settings.selectedModel.value.isEmpty ? '默认' : settings.selectedModel.value),
                  _debugRow(c, '手语者', '${controller.isSigner.value}'),
                  _debugRow(c, '摄像头', controller.cameraService.state.value.name),
                  _debugRow(c, '人像检测', '${controller.cameraService.personInFrame.value}'),
                  _debugRow(c, '作弊模式', '${settings.cheaterMode.value}'),
                  _debugRow(c, '语音引擎', settings.speechEngine.value),
                  const SizedBox(height: 12),
                  // Debug log
                  Text('调试日志', style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Obx(() {
                      final logs = debug.entries;
                      if (logs.isEmpty) {
                        return Center(
                          child: Text('暂无日志', style: TextStyle(color: c.textMuted, fontSize: 12)),
                        );
                      }
                      return ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (_, i) {
                          final e = logs[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '[${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}:${e.time.second.toString().padLeft(2, '0')}] [${e.scope}] ${e.message}',
                              style: TextStyle(color: c.textMuted, fontSize: 10, fontFamily: 'monospace'),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _debugRow(ThemePreset c, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: TextStyle(color: c.textMuted, fontSize: 11))),
          Expanded(child: Text(value, style: TextStyle(color: c.textPrimary, fontSize: 11, fontFamily: 'monospace'))),
        ],
      ),
    );
  }
}

class _QuickSwitch extends StatelessWidget {
  const _QuickSwitch({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return Row(
      children: [
        Icon(icon, size: 16, color: c.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: c.textSecondary, fontSize: 13),
          ),
        ),
        CupertinoSwitch(
          value: value,
          activeTrackColor: c.accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ======================== Workbench Layout ========================

class _WorkbenchLayout extends GetView<HomePageController> {
  const _WorkbenchLayout();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      AppTheme.themeVersion;
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: controller.isSigner.value
                ? _signerLayout()
                : _chatLayout(),
          ),
          // Quick settings overlay
          if (controller.showQuickSettings.value)
            Positioned(
              top: 0,
              right: 20,
              width: 260,
              child: _QuickSettingsPanel(),
            ),
          // Debug overlay (开发者模式)
          if (controller.showDebugOverlay.value)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: _DebugOverlay(),
            ),
          // Debug floating button (仅开发者模式显示)
          Obx(() {
            AppTheme.themeVersion;
            final c = AppTheme.current;
            final devMode = Get.find<RuntimeSettingsService>().devModeEnabled.value;
            if (!devMode) return const SizedBox.shrink();
            return Positioned(
              right: 20,
              bottom: 20,
              child: GestureDetector(
                onTap: () => controller.showDebugOverlay.toggle(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: c.warning.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: c.warning.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Icon(CupertinoIcons.hammer, size: 20, color: CupertinoColors.white),
                ),
              ),
            );
          }),
        ],
      );
    });
  }

  Widget _signerLayout() {
    return Row(
      children: [
        Expanded(flex: 58, child: _CameraPanel()),
        const SizedBox(width: 16),
        Expanded(flex: 42, child: _RightPanel()),
      ],
    );
  }

  Widget _chatLayout() {
    final settings = Get.find<RuntimeSettingsService>();
    if (settings.videoRecognitionEnabled.value) {
      return Row(
        children: [
          Expanded(flex: 58, child: _CameraPanel()),
          const SizedBox(width: 16),
          Expanded(flex: 42, child: _RightPanel()),
        ],
      );
    }
    return Row(
      children: [
        Expanded(child: _RightPanel()),
      ],
    );
  }
}

// ======================== Camera Panel ========================

class _CameraPanel extends GetView<HomePageController> {
  const _CameraPanel();

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<RuntimeSettingsService>();
    return Obx(() {
      AppTheme.themeVersion;
      final c = AppTheme.current;
      if (!settings.videoRecognitionEnabled.value) {
        return _buildContainer(
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: c.background,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.eye_slash,
                          size: 48,
                          color: c.textMuted.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '视频识别已关闭',
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '可在快捷设置中重新开启',
                          style: TextStyle(
                            color: c.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(top: 16, left: 16, child: _StatusBadge()),
            ],
          ),
        );
      }

      return _buildContainer(
        child: Stack(
          children: [
            // Camera preview
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Obx(() {
                  final cameraState = controller.cameraService.state.value;
                  final CameraController? camera = controller.cameraService.controller;
                  if (cameraState != CameraState.ready &&
                      cameraState != CameraState.streaming) {
                    return const _CameraPlaceholder();
                  }
                  if (camera == null || !camera.value.isInitialized) {
                    return const _CameraPlaceholder();
                  }
                  return CameraPreview(camera);
                }),
              ),
            ),
            // Face/silhouette guide overlay
            const Positioned.fill(child: _FaceGuideOverlay()),
            // Status badge
            const Positioned(top: 16, left: 16, child: _StatusBadge()),
            // Recognition indicator
            Positioned(
              top: 16,
              right: 16,
              child: Obx(() {
                AppTheme.themeVersion;
                final recognizing = controller.sessionService.isRecognizing.value;
                if (!recognizing) return const SizedBox.shrink();
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: c.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: c.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '识别中',
                            style: TextStyle(
                              color: c.accentLight,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            // 底部提示由 _FaceGuideOverlay 提供，此处不再重复
          ],
        ),
      );
    });
  }

  Widget _buildContainer({required Widget child}) {
    final c = AppTheme.current;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.glassBorder),
      ),
      child: child,
    );
  }
}

// ======================== Status Badge ========================

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    final ws = Get.find<RealtimeWsService>();
    return Obx(() {
      AppTheme.themeVersion;
      final c = AppTheme.current;
      final connected = ws.state.value == WsState.connected;
      final color = connected ? c.success : c.warning;
      final text = switch (ws.state.value) {
        WsState.connected => '在线',
        WsState.connecting => '连接中',
        WsState.reconnecting => '重连中',
        WsState.error => '错误',
        WsState.disconnected => '离线',
        WsState.idle => '空闲',
      };

      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0x73000000),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ======================== Right Panel ========================

class _RightPanel extends GetView<HomePageController> {
  const _RightPanel();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      AppTheme.themeVersion;
      final c = AppTheme.current;
      return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: c.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChatHeader(),
              _Divider(),
              _LiveCaptionBar(),
              _Divider(),
              Expanded(child: _ConversationBody()),
              _Divider(),
              _ComposerBar(),
            ],
          ),
        ),
      ),
      );
    });
  }
}

// ======================== Chat Header ========================

class _ChatHeader extends GetView<HomePageController> {
  const _ChatHeader();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      AppTheme.themeVersion;
      final c = AppTheme.current;
      final session = controller.sessionService;
      final settings = Get.find<RuntimeSettingsService>();
      return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              CupertinoIcons.chat_bubble_2_fill,
              size: 16,
              color: c.accentLight,
            ),
          ),
          const SizedBox(width: 10),
          Obx(() {
            AppTheme.themeVersion;
            final c = AppTheme.current;
            final code = settings.roomCode.value;
            return Text(
              code != null ? '房间 $code' : '对话',
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            );
          }),
          // Message count
          Obx(() {
            AppTheme.themeVersion;
            final c = AppTheme.current;
            if (session.messages.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Obx(() => Text(
                  '${session.messages.length}',
                  style: TextStyle(
                    color: c.accentLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                )),
              ),
            );
          }),
          const Spacer(),
          // Quick phrases toggle
          CupertinoButton(
            padding: EdgeInsets.zero,
            pressedOpacity: 0.6,
            onPressed: () => _showAllPhrases(context),
            child: Icon(
              CupertinoIcons.rectangle_3_offgrid,
              size: 16,
              color: c.textMuted,
            ),
          ),
          const SizedBox(width: 8),
          // Clear
          CupertinoButton(
            padding: EdgeInsets.zero,
            pressedOpacity: 0.6,
            onPressed: controller.clearConversation,
            child: Icon(
              CupertinoIcons.trash,
              size: 16,
              color: c.textMuted,
            ),
          ),
        ],
      ),
      );
    });
  }

  void _showAllPhrases(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('快捷短语'),
        actions: [
          for (final phrase in controller.quickPhrases)
            CupertinoActionSheetAction(
              onPressed: () {
                Get.back<void>();
                controller.sendQuickPhrase(phrase);
              },
              child: Text(phrase),
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

// ======================== Divider ========================

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return Container(height: 0.5, color: c.divider);
  }
}

// ======================== Live Caption Bar ========================

class _LiveCaptionBar extends GetView<HomePageController> {
  const _LiveCaptionBar();

  @override
  Widget build(BuildContext context) {
    final session = controller.sessionService;
    return Obx(
      () {
        AppTheme.themeVersion;
        final c = AppTheme.current;
        return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (session.isRecognizing.value)
              Container(
                margin: const EdgeInsets.only(right: 10),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Text(
                session.liveCaption.value,
                style: TextStyle(
                  color: session.isRecognizing.value
                      ? c.accentLight
                      : c.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
      },
    );
  }
}

// ======================== Conversation Body ========================

class _ConversationBody extends GetView<HomePageController> {
  const _ConversationBody();

  @override
  Widget build(BuildContext context) {
    final session = controller.sessionService;
    return Obx(() {
      AppTheme.themeVersion;
      final c = AppTheme.current;
      if (session.messages.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.chat_bubble_2_fill,
                  size: 36,
                  color: c.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  '识别结果和文字消息将显示在这里',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 4),
        reverse: true,
        itemCount: session.messages.length,
        itemBuilder: (context, index) {
          final message = session.messages[session.messages.length - 1 - index];
          if (message.origin == MessageOrigin.system) {
            return _SystemMessage(content: message.content);
          }
          return _ChatBubble(message: message);
        },
      );
    });
  }
}

// ======================== System Message ========================

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.content});
  final String content;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: c.glassBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.glassBorder),
          ),
          child: Text(
            content,
            style: TextStyle(
              color: c.textMuted,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

// ======================== Chat Bubble ========================

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    final isSigner = Get.find<HomePageController>().isSigner.value;
    final isMe = message.origin == MessageOrigin.user ||
        (isSigner && message.origin == MessageOrigin.sign) ||
        (!isSigner && message.origin == MessageOrigin.speech);

    Color bubbleColor;
    IconData? prefixIcon;

    if (isMe) {
      bubbleColor = c.chatBubbleMe;
    } else if (message.origin == MessageOrigin.sign) {
      bubbleColor = c.chatBubbleSign;
      prefixIcon = CupertinoIcons.hand_raised;
    } else if (message.origin == MessageOrigin.speech) {
      bubbleColor = c.chatBubbleSpeech;
      prefixIcon = CupertinoIcons.mic;
    } else {
      bubbleColor = c.chatBubbleOther;
    }

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(19),
      topRight: const Radius.circular(19),
      bottomLeft: Radius.circular(isMe ? 19 : 5),
      bottomRight: Radius.circular(isMe ? 5 : 19),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 16),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.35,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
              boxShadow: [
                BoxShadow(
                  color: bubbleColor.withValues(alpha: isMe ? 0.25 : 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (prefixIcon != null) ...[
                  Icon(prefixIcon, size: 12, color: c.textSecondary),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.status == MessageStatus.sending)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                '发送中',
                style: TextStyle(
                  color: c.textMuted,
                  fontSize: 10,
                ),
              ),
            ),
          if (message.status == MessageStatus.failed)
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '失败',
                    style: TextStyle(
                      color: c.danger,
                      fontSize: 10,
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 4),
                    minimumSize: Size.zero,
                    onPressed: () => Get.find<SessionService>().retryMessage(message.id),
                    child: Text(
                      '重试',
                      style: TextStyle(
                        color: c.accentLight,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ======================== Composer Bar ========================

class _ComposerBar extends GetView<HomePageController> {
  const _ComposerBar();

  @override
  Widget build(BuildContext context) {
    final speech = Get.find<SpeechService>();
    final session = Get.find<SessionService>();
    return Obx(() {
      AppTheme.themeVersion;
      final c = AppTheme.current;
      return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          // Quick phrases (only show when no messages)
          Obx(() {
            AppTheme.themeVersion;
            if (session.messages.isNotEmpty) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...controller.quickPhrases.take(3).map(
                  (phrase) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _QuickChip(
                      label: phrase,
                      onTap: () => controller.sendQuickPhrase(phrase),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            );
          }),
          // Mic button
          Obx(() {
            AppTheme.themeVersion;
            final s = Get.find<RuntimeSettingsService>();
            if (s.speechEngine.value == 'none') return const SizedBox.shrink();
            final listening = speech.state.value == SpeechState.listening;
            final unavailable = speech.state.value == SpeechState.unavailable;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _IconButton(
                icon: CupertinoIcons.mic,
                size: 36,
                active: listening,
                danger: listening,
                onTap: unavailable
                    ? () => _showSpeechUnavailable(context)
                    : controller.toggleSpeech,
              ),
            );
          }),
          // Text input
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: c.glassBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: c.glassBorder),
              ),
              child: CupertinoTextField(
                controller: controller.textController,
                placeholder: '输入消息...',
                padding: const EdgeInsets.symmetric(horizontal: 14),
                style: TextStyle(
                  color: c.textPrimary,
                  fontSize: 14,
                ),
                placeholderStyle: TextStyle(
                  color: c.textMuted,
                  fontSize: 14,
                ),
                decoration: const BoxDecoration(),
                clearButtonMode: OverlayVisibilityMode.editing,
                onSubmitted: (_) => controller.sendCurrentInput(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send
          _SendButton(onTap: controller.sendCurrentInput),
        ],
      ),
      );
    });
  }

  void _showSpeechUnavailable(BuildContext context) {
    final c = AppTheme.current;
    final msg = controller.speechService.errorMessage.value ??
        '语音识别在当前设备不可用。';
    Get.snackbar(
      '语音不可用',
      '$msg\n请点击右上角齿轮图标进入设置更改语音引擎',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xCC1A1A2E),
      colorText: c.textPrimary,
      duration: const Duration(seconds: 4),
    );
  }
}

// ======================== Icon Button ========================

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.size,
    this.active = false,
    this.danger = false,
    this.onTap,
  });

  final IconData icon;
  final double size;
  final bool active;
  final bool danger;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    final activeBg = danger
        ? CupertinoColors.destructiveRed.withValues(alpha: 0.2)
        : c.accent.withValues(alpha: 0.2);
    final idleBg = c.glassBg;
    final bgColor = active ? activeBg : idleBg;
    final borderColor = active
        ? (danger
            ? CupertinoColors.destructiveRed.withValues(alpha: 0.3)
            : c.accent.withValues(alpha: 0.3))
        : c.glassBorder;
    final iconColor = active
        ? (danger ? CupertinoColors.destructiveRed : c.accentLight)
        : c.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 17, color: iconColor),
      ),
    );
  }
}

// ======================== Send Button ========================

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.accent, c.accentLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: c.accent.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          CupertinoIcons.arrow_up,
          size: 17,
          color: c.textPrimary,
        ),
      ),
    );
  }
}

// ======================== Quick Phrase Chip ========================

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: c.glassBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.glassBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: c.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ======================== Face Guide Overlay ========================

class _FaceGuideOverlay extends StatelessWidget {
  const _FaceGuideOverlay();

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<RuntimeSettingsService>();
    return Obx(() {
      AppTheme.themeVersion;
      final c = AppTheme.current;
      final controller = Get.find<HomePageController>();
      // 视频识别关闭或摄像头未就绪时隐藏
      if (!settings.videoRecognitionEnabled.value) {
        return const SizedBox.shrink();
      }
      final cameraState = controller.cameraService.state.value;
      if (cameraState != CameraState.ready &&
          cameraState != CameraState.streaming) {
        return const SizedBox.shrink();
      }
      // 人像引导框开关关闭时始终隐藏
      if (!settings.personGuideEnabled.value) return const SizedBox.shrink();
      // 人像在画面中时隐藏引导框，不在时显示
      if (controller.cameraService.personInFrame.value) {
        return const SizedBox.shrink();
      }
      return _GuideFrame(accentColor: c.accent, accentLight: c.accentLight);
    });
  }
}

class _GuideFrame extends StatelessWidget {
  const _GuideFrame({required this.accentColor, required this.accentLight});

  final Color accentColor;
  final Color accentLight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            // 人像轮廓遮罩（四周暗中间人形区域亮）
            CustomPaint(
              size: Size(w, h),
              painter: _MaskPainter(
                maskColor: const Color(0x8C000000),
              ),
            ),
            // 人像轮廓引导线
            IgnorePointer(
              child: CustomPaint(
                size: Size(w, h),
                painter: _SilhouetteGuidePainter(
                  accentColor: accentColor,
                  accentLight: accentLight,
                ),
              ),
            ),
            // 顶部提示文字
            Positioned(
              left: 0,
              right: 0,
              top: h * 0.04,
              child: IgnorePointer(
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x80000000),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '请将头部、双肩和上半身置于轮廓内',
                          style: TextStyle(
                            color: accentLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // 底部小提示
            Positioned(
              left: 0,
              right: 0,
              bottom: h * 0.06,
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    '保持正脸面向摄像头',
                    style: TextStyle(
                      color: accentLight.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 在四周画半透明遮罩，中间人像轮廓区域挖空
class _MaskPainter extends CustomPainter {
  _MaskPainter({required this.maskColor});

  final Color maskColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = maskColor;
    final silhouette = _buildSilhouettePath(size.width, size.height);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addPath(silhouette, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MaskPainter old) => true;
}

/// 画人像轮廓引导线
class _SilhouetteGuidePainter extends CustomPainter {
  _SilhouetteGuidePainter({
    required this.accentColor,
    required this.accentLight,
  });

  final Color accentColor;
  final Color accentLight;

  @override
  void paint(Canvas canvas, Size size) {
    final silhouette = _buildSilhouettePath(size.width, size.height);

    // 外发光（柔和）
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(silhouette, glowPaint);

    // 主线
    final linePaint = Paint()
      ..color = accentLight.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(silhouette, linePaint);

    // 内部微弱填充
    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    canvas.drawPath(silhouette, fillPaint);
  }

  @override
  bool shouldRepaint(_SilhouetteGuidePainter old) => false;
}

/// 微信默认头像风格人像轮廓（299点精确描边）
/// 源 BoundingBox: (276, 401) ~ (880, 1005), 604×604
Path _buildSilhouettePath(double w, double h) {
  // 299 个轮廓点 (x, y 交替)
  const c = <double>[
    563, 401, 560, 404, 544, 404, 541, 407, 534, 407, 531, 410,
    525, 410, 521, 413, 518, 413, 512, 420, 508, 420, 505, 423,
    502, 423, 489, 436, 486, 436, 463, 459, 463, 462, 457, 468,
    457, 472, 450, 478, 450, 481, 447, 485, 447, 488, 444, 491,
    444, 494, 440, 498, 440, 501, 437, 504, 437, 507, 434, 510,
    434, 517, 431, 520, 431, 527, 428, 530, 428, 543, 424, 546,
    424, 559, 421, 562, 421, 617, 424, 620, 424, 630, 428, 633,
    428, 640, 431, 643, 431, 650, 434, 653, 434, 659, 437, 662,
    437, 666, 440, 669, 440, 672, 444, 675, 444, 679, 447, 682,
    447, 688, 450, 692, 450, 695, 457, 701, 457, 705, 463, 711,
    463, 714, 466, 717, 466, 721, 470, 724, 470, 727, 473, 730,
    473, 734, 482, 743, 482, 747, 486, 750, 486, 753, 489, 756,
    489, 759, 492, 763, 492, 766, 495, 769, 495, 785, 492, 789,
    492, 792, 489, 795, 489, 798, 482, 805, 479, 805, 476, 808,
    473, 808, 470, 811, 466, 811, 463, 814, 457, 814, 453, 818,
    450, 818, 447, 821, 440, 821, 434, 827, 428, 827, 424, 831,
    418, 831, 411, 837, 408, 837, 405, 840, 398, 840, 395, 844,
    392, 844, 389, 847, 385, 847, 382, 850, 376, 850, 373, 853,
    369, 853, 366, 857, 363, 857, 360, 860, 356, 860, 353, 863,
    347, 863, 343, 866, 340, 866, 337, 869, 334, 869, 330, 873,
    324, 873, 321, 876, 318, 876, 311, 882, 305, 882, 305, 886,
    292, 899, 288, 899, 288, 902, 285, 905, 285, 908, 282, 911,
    282, 915, 279, 918, 279, 921, 276, 924, 276, 960, 279, 963,
    279, 973, 282, 976, 282, 979, 288, 986, 288, 989, 292, 992,
    295, 992, 298, 996, 301, 996, 308, 1002, 314, 1002, 318, 1005,
    832, 1005, 835, 1002, 845, 1002, 848, 999, 851, 999, 854, 996,
    858, 996, 874, 979, 874, 976, 877, 973, 877, 970, 880, 966,
    880, 924, 877, 921, 877, 918, 874, 915, 874, 911, 871, 908,
    871, 905, 864, 899, 864, 895, 854, 886, 851, 886, 845, 879,
    841, 879, 838, 876, 832, 876, 829, 873, 825, 873, 822, 869,
    819, 869, 816, 866, 809, 866, 806, 863, 803, 863, 799, 860,
    793, 860, 790, 857, 786, 857, 783, 853, 774, 853, 770, 850,
    767, 850, 764, 847, 761, 847, 757, 844, 754, 844, 751, 840,
    744, 840, 741, 837, 735, 837, 732, 834, 728, 834, 725, 831,
    722, 831, 719, 827, 709, 827, 706, 824, 702, 824, 699, 821,
    696, 821, 693, 818, 686, 818, 683, 814, 680, 814, 673, 808,
    670, 808, 667, 805, 664, 805, 657, 798, 657, 795, 654, 792,
    654, 776, 657, 772, 657, 769, 660, 766, 660, 756, 664, 753,
    664, 750, 670, 743, 670, 740, 677, 734, 677, 730, 683, 724,
    683, 721, 686, 717, 686, 714, 696, 705, 696, 701, 699, 698,
    699, 695, 702, 692, 702, 688, 709, 682, 709, 679, 712, 675,
    712, 672, 715, 669, 715, 662, 719, 659, 719, 653, 722, 650,
    722, 646, 725, 643, 725, 640, 728, 637, 728, 624, 732, 620,
    732, 611, 735, 607, 735, 575, 732, 572, 732, 556, 728, 553,
    728, 536, 725, 533, 725, 523, 722, 520, 722, 514, 719, 510,
    719, 507, 715, 504, 715, 501, 712, 498, 712, 494, 709, 491,
    709, 488, 706, 485, 706, 481, 702, 478, 702, 475, 696, 468,
    696, 465, 693, 465, 689, 462, 689, 459, 651, 420, 647, 420,
    644, 417, 638, 417, 634, 413, 631, 413, 628, 410, 625, 410,
    622, 407, 615, 407, 612, 404, 602, 404, 599, 401,
  ];

  // BoundingBox: left=276, top=401, size=604x604
  // 整体缩小到 65%，头部自然变小，肩部相对更明显
  const srcL = 276.0, srcT = 401.0, srcSize = 604.0;
  const fitScale = 0.65;
  final s = (w < h ? w : h) / srcSize * fitScale;
  final ox = (w - srcSize * s) / 2;
  final oy = (h - srcSize * s) / 2;

  final path = Path();
  for (int i = 0; i < c.length; i += 2) {
    final x = ox + (c[i] - srcL) * s;
    final y = oy + (c[i + 1] - srcT) * s;
    if (i == 0) { path.moveTo(x, y); } else { path.lineTo(x, y); }
  }
  path.close();
  return path;
}

// ======================== Camera Placeholder ========================

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return Container(
      color: c.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(radius: 16),
          const SizedBox(height: 12),
          Text(
            '摄像头准备中',
            style: TextStyle(color: c.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ======================== Loading / Error / Permission States ========================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CupertinoActivityIndicator(radius: 18),
          const SizedBox(height: 16),
          Text(
            '正在初始化...',
            style: TextStyle(color: c.textSecondary, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _PermissionState extends StatelessWidget {
  const _PermissionState({required this.controller});
  final HomePageController controller;

  @override
  Widget build(BuildContext context) {
    return _ErrorState(
      title: '需要摄像头和麦克风权限',
      description: '请在系统设置中允许 SignBridge 使用摄像头和麦克风，然后重试。',
      actionLabel: '重新检查权限',
      onAction: controller.retryAll,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String description;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: c.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: c.warning,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: c.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.textSecondary,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            CupertinoButton.filled(
              onPressed: onAction,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
