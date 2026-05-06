import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../services/camera/camera_service.dart';
import '../../../services/connection/realtime_ws_service.dart';
import '../../../services/debug/debug_log_service.dart';
import '../../../services/permissions/permission_service.dart';
import '../../../services/session/session_service.dart';
import '../../../services/settings/runtime_settings_service.dart';
import '../../../services/speech/speech_service.dart';

class HomePageController extends GetxController {
  HomePageController({this.autoBootstrap = true, this.role = 'signer', this.roomId = ''});

  final bool autoBootstrap;
  final String role;
  final String roomId;

  final textController = TextEditingController();
  final quickPhrases = const <String>[
    '请稍等',
    '我需要帮助',
    '请再说一遍',
    '谢谢你的帮助',
  ];

  late final RealtimeWsService wsService;
  late final CameraService cameraService;
  late final SessionService sessionService;
  late final SpeechService speechService;
  late final RuntimeSettingsService settingsService;
  late final PermissionService permissionService;
  late final DebugLogService debugLogService;

  final RxBool isBootstrapping = true.obs;
  final RxBool isSigner = false.obs;

  @override
  void onInit() {
    super.onInit();
    wsService = Get.find<RealtimeWsService>();
    cameraService = Get.find<CameraService>();
    sessionService = Get.find<SessionService>();
    speechService = Get.find<SpeechService>();
    settingsService = Get.find<RuntimeSettingsService>();
    permissionService = Get.find<PermissionService>();
    debugLogService = Get.find<DebugLogService>();

    isSigner.value = role == 'signer';

    if (autoBootstrap) {
      unawaited(bootstrapPage());
    } else {
      // 从 Lobby 进入，已连上 WebSocket
      isBootstrapping.value = false;
      if (isSigner.value) {
        // 手语者：启动摄像头
        unawaited(_initCamera());
      }
    }

    // 监听视频识别开关（跳过初始值，仅响应切换操作）
    bool firstCall = true;
    ever(settingsService.videoRecognitionEnabled, (bool enabled) {
      if (firstCall) { firstCall = false; return; }
      if (!isSigner.value) return;
      if (enabled) {
        cameraService.state.value == CameraState.ready
            ? unawaited(cameraService.startCapture())
            : unawaited(_initCamera());
      } else {
        cameraService.stopCapture();
      }
    });
  }

  Future<void> _initCamera() async {
    debugLogService.log('home', 'init camera');
    await cameraService.initialize();
    if (cameraService.state.value == CameraState.ready) {
      await cameraService.startCapture();
    }
    debugLogService.log('home', 'camera done: ${cameraService.state.value.name}');
  }

  Future<void> bootstrapPage() async {
    isBootstrapping.value = true;
    debugLogService.log('home', 'bootstrap start');
    await wsService.connect();
    await cameraService.initialize();
    if (cameraService.state.value == CameraState.ready) {
      await cameraService.startCapture();
    }
    isBootstrapping.value = false;
    debugLogService.log('home', 'bootstrap done');
  }

  Future<void> retryAll() async {
    debugLogService.log('home', 'retry all');
    await cameraService.restart();
    await wsService.connect();
  }

  Future<void> sendCurrentInput() async {
    await sessionService.sendText(textController.text);
    textController.clear();
  }

  Future<void> sendQuickPhrase(String text) async {
    textController.text = text;
    await sendCurrentInput();
  }

  Future<void> toggleSpeech() => speechService.toggleListening();

  Future<void> applyServerUrl(String value) async {
    debugLogService.log('home', 'apply url: $value');
    settingsService.updateWsOverride(value);
    await wsService.disconnect(manual: false);
    await wsService.connect();
  }

  Future<void> clearConversation() async {
    sessionService.clearConversation();
    wsService.requestSessionReset();
  }

  bool get showPermissionGuide =>
      cameraService.state.value == CameraState.permissionDenied ||
      permissionService.cameraState.value == PermissionState.denied ||
      permissionService.microphoneState.value == PermissionState.denied ||
      permissionService.cameraState.value == PermissionState.permanentlyDenied ||
      permissionService.microphoneState.value == PermissionState.permanentlyDenied;

  bool get showCameraError =>
      cameraService.state.value == CameraState.error ||
      cameraService.state.value == CameraState.unavailable;

  bool get showLoading =>
      isBootstrapping.value ||
      cameraService.state.value == CameraState.initializing ||
      cameraService.state.value == CameraState.requestingPermission;

  @override
  void onClose() {
    textController.dispose();
    if (!kIsWeb) {
      cameraService.stopCapture();
    }
    super.onClose();
  }
}
