import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../data/models/chat_message.dart';
import '../../../services/camera/camera_service.dart';
import '../../../services/connection/realtime_ws_service.dart';
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
                children: const [
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
    final c = AppTheme.current;
    final ws = Get.find<RealtimeWsService>();
    final settings = Get.find<RuntimeSettingsService>();
    return Obx(() {
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
              Obx(() => _QuickSwitch(
                icon: CupertinoIcons.videocam,
                label: '视频识别',
                value: settings.videoRecognitionEnabled.value,
                onChanged: (_) => settings.toggleVideoRecognition(),
              )),
              const SizedBox(height: 10),
              Obx(() => _QuickSwitch(
                icon: CupertinoIcons.sun_max,
                label: '屏幕常亮',
                value: wakeLock.enabled.value,
                onChanged: (_) => wakeLock.toggle(),
              )),
              const SizedBox(height: 10),
              Obx(() => _QuickSwitch(
                icon: CupertinoIcons.textformat_size,
                label: '大字体',
                value: settings.textScale.value > 1.0,
                onChanged: (v) => settings.textScale.value = v ? 1.3 : 1.0,
              )),
            ],
          ),
        ),
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
        ],
      );
    });
  }

  Widget _signerLayout() {
    return const Row(
      children: [
        Expanded(flex: 58, child: _CameraPanel()),
        SizedBox(width: 16),
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
    return const Row(
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
    final c = AppTheme.current;
    final settings = Get.find<RuntimeSettingsService>();
    return Obx(() {
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
            // Bottom guidance
            Positioned(
              bottom: 18,
              left: 18,
              right: 18,
              child: _buildGuidance(),
            ),
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

  Widget _buildGuidance() {
    final c = AppTheme.current;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0x80000000),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.glassBorder.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(7),
                ),
                alignment: Alignment.center,
                child: Icon(CupertinoIcons.hand_raised, size: 12, color: c.accentLight),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Obx(() {
                  final caption = controller.sessionService.liveCaption.value;
                  return Text(
                    caption == '等待识别开始'
                        ? '请将双手放在预览框中央，保持上半身在画面内'
                        : caption,
                    style: TextStyle(
                      color: controller.sessionService.isRecognizing.value
                          ? c.accentLight
                          : c.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================== Status Badge ========================

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    final ws = Get.find<RealtimeWsService>();
    return Obx(() {
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
          child: const Column(
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
  }
}

// ======================== Chat Header ========================

class _ChatHeader extends GetView<HomePageController> {
  const _ChatHeader();

  @override
  Widget build(BuildContext context) {
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
    final c = AppTheme.current;
    final session = controller.sessionService;
    return Obx(
      () => Padding(
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
      ),
    );
  }
}

// ======================== Conversation Body ========================

class _ConversationBody extends GetView<HomePageController> {
  const _ConversationBody();

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.current;
    final session = controller.sessionService;
    return Obx(() {
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
      bubbleColor = const Color(0xFF1E3A5F);
      prefixIcon = CupertinoIcons.hand_raised;
    } else if (message.origin == MessageOrigin.speech) {
      bubbleColor = const Color(0xFF2D1B69);
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
    final c = AppTheme.current;
    final speech = Get.find<SpeechService>();
    final session = Get.find<SessionService>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Row(
        children: [
          // Quick phrases (only show when no messages)
          Obx(() {
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
            final settings = Get.find<RuntimeSettingsService>();
            if (settings.speechEngine.value == 'none') return const SizedBox.shrink();
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
    final c = AppTheme.current;
    final controller = Get.find<HomePageController>();
    final settings = Get.find<RuntimeSettingsService>();
    return Obx(() {
      // 视频识别关闭或摄像头未就绪时隐藏
      if (!settings.videoRecognitionEnabled.value) {
        return const SizedBox.shrink();
      }
      final cameraState = controller.cameraService.state.value;
      if (cameraState != CameraState.ready &&
          cameraState != CameraState.streaming) {
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

    // 外发光
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(silhouette, glowPaint);

    // 主线
    final linePaint = Paint()
      ..color = accentLight.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(silhouette, linePaint);

    // 内部微弱填充
    final fillPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;
    canvas.drawPath(silhouette, fillPaint);
  }

  @override
  bool shouldRepaint(_SilhouetteGuidePainter old) => false;
}

/// 构建半身人像轮廓 Path
Path _buildSilhouettePath(double w, double h) {
  // 比例参数（相对宽高）
  final headSize = w * 0.185;          // 头部直径
  final headCY = h * 0.20;             // 头部中心 Y
  final neckW = w * 0.09;              // 脖子宽度
  final shoulderW = w * 0.42;          // 肩膀宽度（半宽）
  final waistY = h * 0.82;             // 底部 Y
  final waistW = w * 0.32;             // 底部半宽
  final cx = w / 2;                    // 水平居中

  final path = Path();

  // 从头顶开始，顺时针绘制半身轮廓
  // 1. 头顶 → 右侧头部
  path.addOval(Rect.fromCenter(
    center: Offset(cx, headCY),
    width: headSize,
    height: headSize * 1.15,
  ));

  // 重新构建：从右耳下方开始向下画身体，
  // 然后绕回来从左侧身体向上回到左耳下方，
  // 最后与头部椭圆闭合

  // 使用复合路径：身体路径 + 头部椭圆
  // 身体路径
  final body = Path();
  final rightEarX = cx + headSize * 0.45;
  final leftEarX = cx - headSize * 0.45;
  final earY = headCY + headSize * 0.3;

  body.moveTo(rightEarX, earY);
  // 右肩曲线
  body.quadraticBezierTo(
    rightEarX + neckW * 0.5, earY + headSize * 0.15,
    cx + neckW, earY + headSize * 0.35,
  );
  // 右肩到右上臂
  body.quadraticBezierTo(
    cx + shoulderW * 0.7, earY + headSize * 0.4,
    cx + shoulderW, earY + headSize * 0.55,
  );
  // 右臂外侧到腰部
  body.quadraticBezierTo(
    cx + shoulderW * 1.05, earY + headSize * 0.7,
    cx + waistW, waistY,
  );
  // 底部弧线
  body.quadraticBezierTo(
    cx, waistY + h * 0.04,
    cx - waistW, waistY,
  );
  // 左臂外侧到肩
  body.quadraticBezierTo(
    cx - shoulderW * 1.05, earY + headSize * 0.7,
    cx - shoulderW, earY + headSize * 0.55,
  );
  // 左肩到脖子
  body.quadraticBezierTo(
    cx - shoulderW * 0.7, earY + headSize * 0.4,
    cx - neckW, earY + headSize * 0.35,
  );
  body.quadraticBezierTo(
    leftEarX - neckW * 0.5, earY + headSize * 0.15,
    leftEarX, earY,
  );
  body.close();

  // 合并头部和身体
  final combined = Path.combine(
    PathOperation.union,
    body,
    Path()..addOval(Rect.fromCenter(
      center: Offset(cx, headCY),
      width: headSize,
      height: headSize * 1.15,
    )),
  );

  return combined;
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
