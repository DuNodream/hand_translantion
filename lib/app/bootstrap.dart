import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../config/app_config.dart';
import '../services/camera/camera_service.dart';
import '../services/connection/realtime_ws_service.dart';
import '../services/debug/debug_log_service.dart';
import '../services/permissions/permission_service.dart';
import '../services/session/session_service.dart';
import '../services/settings/runtime_settings_service.dart';
import '../services/speech/speech_service.dart';
import '../services/theme/theme_service.dart';
import '../services/wakelock/wakelock_service.dart';
Future<void> bootstrap() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final settings = Get.put(RuntimeSettingsService(), permanent: true);
  settings.initialize();
  final debugLog = Get.put(DebugLogService(), permanent: true);
  debugLog.log('app', 'bootstrap start');

  final session = Get.put(SessionService(), permanent: true);
  final permissionService = Get.put(PermissionService(), permanent: true);
  final speechService = Get.put(SpeechService(), permanent: true);
  Get.put(WakeLockService(), permanent: true);

  // 主题服务（默认主题已在 AppTheme 中预置）
  Get.put(ThemeService(), permanent: true);

  final ws = Get.put(
    RealtimeWsService(
      sessionService: session,
      debugLogService: debugLog,
    ),
    permanent: true,
  );
  await ws.initialize(
    baseUrl: AppConfig.current.wsUrl,
    token: AppConfig.current.token,
    settingsService: settings,
    requireHandshake: AppConfig.current.requireWsHandshake,
    enableHeartbeat: AppConfig.current.enableWsHeartbeat,
    supportTextMessaging: AppConfig.current.supportTextMessaging,
  );

  Get.put(
    CameraService(
      permissionService: permissionService,
      wsService: ws,
      debugLogService: debugLog,
    ),
    permanent: true,
  );

  // 不阻塞启动：语音初始化在后台进行
  speechService.initialize();
  debugLog.log('app', 'bootstrap done');
}
