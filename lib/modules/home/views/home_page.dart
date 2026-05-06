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
import '../../../shared/themes/app_theme.dart';
import '../controllers/home_page_controller.dart';

class HomePage extends GetView<HomePageController> {
  const HomePage({super.key, this.role = 'signer', this.roomId = ''});

  final String role;
  final String roomId;

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<RuntimeSettingsService>();
    return Obx(
      () => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(settings.textScale.value),
        ),
        child: CupertinoPageScaffold(
          backgroundColor: AppTheme.background,
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
              return const _WorkbenchLayout();
            }),
          ),
        ),
      ),
    );
  }
}

// ======================== 工作台布局 ========================

class _WorkbenchLayout extends GetView<HomePageController> {
  const _WorkbenchLayout();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isSigner.value) {
        // 手语者模式：摄像头 + 对话面板
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: const [
              Expanded(flex: 58, child: _CameraPanel()),
              SizedBox(width: 18),
              Expanded(flex: 42, child: _RightPanel()),
            ],
          ),
        );
      } else {
        // 对话者模式：仅对话面板（全宽）
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: const [
              Expanded(flex: 58, child: _ChatOnlyPanel()),
              SizedBox(width: 18),
              Expanded(flex: 42, child: _RightPanel()),
            ],
          ),
        );
      }
    });
  }
}

/// 对话者模式：用聊天背景替代摄像头预览
class _ChatOnlyPanel extends StatelessWidget {
  const _ChatOnlyPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Container(
                color: AppTheme.background,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.chat_bubble_2_fill,
                      size: 48,
                      color: AppTheme.textMuted.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '文字对话模式',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '接收手语识别结果并通过文字回复',
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 14,
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
}

// ======================== 摄像头面板 ========================

class _CameraPanel extends GetView<HomePageController> {
  const _CameraPanel();

  @override
  Widget build(BuildContext context) {
    final settings = Get.find<RuntimeSettingsService>();
    return Obx(() {
      if (!settings.videoRecognitionEnabled.value) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: AppTheme.background,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.eye_slash,
                          size: 48,
                          color: AppTheme.textMuted.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '视频识别已关闭',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '可在设置中重新开启',
                          style: TextStyle(
                            color: AppTheme.textMuted,
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

      return Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Stack(
          children: [
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
            const Positioned(top: 16, left: 16, child: _StatusBadge()),
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

  Widget _buildGuidance() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x73000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: const Row(
            children: [
              Icon(CupertinoIcons.hand_raised, size: 14, color: AppTheme.textMuted),
              SizedBox(width: 8),
              Text(
                '请将双手放在预览框中央，保持上半身在画面内',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================== 玻璃状态胶囊 ========================

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

  @override
  Widget build(BuildContext context) {
    final ws = Get.find<RealtimeWsService>();
    return Obx(() {
      final connected = ws.state.value == WsState.connected;
      final color = connected ? AppTheme.success : AppTheme.warning;
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x73000000),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.glassBorder),
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
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 11,
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

// ======================== 右侧玻璃面板 ========================

class _RightPanel extends GetView<HomePageController> {
  const _RightPanel();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.glassBorder),
          ),
          child: const Column(
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

// ======================== 聊天气泡头部 ========================

class _ChatHeader extends GetView<HomePageController> {
  const _ChatHeader();

  @override
  Widget build(BuildContext context) {
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
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Icon(
              CupertinoIcons.chat_bubble_2_fill,
              size: 16,
              color: AppTheme.accentLight,
            ),
          ),
          const SizedBox(width: 10),
          Obx(() {
            final code = settings.roomCode.value;
            return Text(
              code != null ? '房间 $code' : '对话',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            );
          }),
          const Spacer(),
          Obx(() {
            if (session.messages.isEmpty) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${session.messages.length}',
                style: const TextStyle(
                  color: AppTheme.accentLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: EdgeInsets.zero,
            pressedOpacity: 0.6,
            onPressed: controller.clearConversation,
            child: const Icon(
              CupertinoIcons.trash,
              size: 16,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ======================== 分割线 ========================

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 0.5, color: AppTheme.divider);
  }
}

// ======================== 实时字幕条 ========================

class _LiveCaptionBar extends GetView<HomePageController> {
  const _LiveCaptionBar();

  @override
  Widget build(BuildContext context) {
    final session = controller.sessionService;
    return Obx(
      () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (session.isRecognizing.value)
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                ),
              ),
            Expanded(
              child: Text(
                session.liveCaption.value,
                style: TextStyle(
                  color: session.isRecognizing.value
                      ? AppTheme.accentLight
                      : AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================== 对话消息列表 ========================

class _ConversationBody extends GetView<HomePageController> {
  const _ConversationBody();

  @override
  Widget build(BuildContext context) {
    final session = controller.sessionService;
    return Obx(() {
      if (session.messages.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '识别结果和文字消息将显示在这里',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textMuted,
                fontSize: 13,
              ),
            ),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
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

// ======================== 系统消息 ========================

class _SystemMessage extends StatelessWidget {
  const _SystemMessage({required this.content});
  final String content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            content,
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

// ======================== 聊天气泡（非对称圆角） ========================

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isMe = message.origin == MessageOrigin.user;
    final bubbleColor = isMe ? AppTheme.chatBubbleMe : AppTheme.chatBubbleOther;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.35,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
              border: isMe ? null : Border.all(color: AppTheme.glassBorder, width: 0.5),
            ),
            child: Text(
              message.content,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ),
          if (message.status == MessageStatus.sending)
            const Padding(
              padding: EdgeInsets.only(top: 2, right: 4),
              child: Text(
                '发送中',
                style: TextStyle(
                  color: AppTheme.textMuted,
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
                  const Text(
                    '失败',
                    style: TextStyle(
                      color: AppTheme.danger,
                      fontSize: 10,
                    ),
                  ),
                  CupertinoButton(
                    padding: const EdgeInsets.only(left: 4),
                    minimumSize: Size.zero,
                    onPressed: () => Get.find<SessionService>().retryMessage(message.id),
                    child: const Text(
                      '重试',
                      style: TextStyle(
                        color: AppTheme.accentLight,
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

// ======================== 底部操作栏 ========================

class _ComposerBar extends GetView<HomePageController> {
  const _ComposerBar();

  @override
  Widget build(BuildContext context) {
    final speech = Get.find<SpeechService>();
    final session = Get.find<SessionService>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // 快捷短语
          Obx(() {
            if (session.messages.isNotEmpty) return const SizedBox.shrink();
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...controller.quickPhrases.take(2).map(
                  (phrase) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _QuickChip(label: phrase, onTap: () => controller.sendQuickPhrase(phrase)),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            );
          }),
          // 麦克风
          Obx(() {
            final settings = Get.find<RuntimeSettingsService>();
            if (settings.speechEngine.value == 'none') return const SizedBox.shrink();
            final listening = speech.state.value == SpeechState.listening;
            final unavailable = speech.state.value == SpeechState.unavailable;
            return _IconButton(
              icon: CupertinoIcons.mic,
              size: 36,
              active: listening,
              danger: listening,
              onTap: unavailable
                  ? () => _showSpeechUnavailable(context)
                  : controller.toggleSpeech,
            );
          }),
          const SizedBox(width: 8),
          // 文本框
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.glassBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.glassBorder),
              ),
              child: CupertinoTextField(
                controller: controller.textController,
                placeholder: '输入消息',
                padding: const EdgeInsets.symmetric(horizontal: 14),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                placeholderStyle: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 14,
                ),
                decoration: const BoxDecoration(),
                clearButtonMode: OverlayVisibilityMode.editing,
                onSubmitted: (_) => controller.sendCurrentInput(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 发送按钮（渐变）
          _SendButton(onTap: controller.sendCurrentInput),
          const SizedBox(width: 8),
          // 设置
          _IconButton(
            icon: CupertinoIcons.gear,
            size: 36,
            onTap: () => Get.toNamed('/settings'),
          ),
        ],
      ),
    );
  }

  void _showSpeechUnavailable(BuildContext context) {
    final msg = controller.speechService.errorMessage.value ??
        '语音识别在当前设备不可用。';
    Get.snackbar(
      '语音不可用',
      '$msg\n请点击右上角齿轮图标进入设置更改语音引擎',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xCC1A1A2E),
      colorText: AppTheme.textPrimary,
      duration: const Duration(seconds: 4),
    );
  }
}

// ======================== 快捷短语芯片 ========================

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.glassBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

// ======================== 图标按钮 ========================

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
    final bgColor = danger
        ? CupertinoColors.destructiveRed.withValues(alpha: 0.15)
        : active
            ? AppTheme.glassBg
            : AppTheme.glassBg;
    final borderColor = danger
        ? CupertinoColors.destructiveRed.withValues(alpha: 0.3)
        : AppTheme.glassBorder;
    final iconColor = active
        ? (danger ? CupertinoColors.destructiveRed : AppTheme.accentLight)
        : AppTheme.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: iconColor),
      ),
    );
  }
}

// ======================== 渐变色发送按钮 ========================

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.accent, AppTheme.accentLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(
          CupertinoIcons.arrow_up,
          size: 18,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

// ======================== 摄像头加载占位 ========================

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoActivityIndicator(radius: 16),
          SizedBox(height: 12),
          Text(
            '摄像头准备中',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ======================== 加载 / 错误 / 权限 ========================

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CupertinoActivityIndicator(radius: 18),
          SizedBox(height: 16),
          Text(
            '正在初始化...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 18),
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
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: AppTheme.warning,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
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
