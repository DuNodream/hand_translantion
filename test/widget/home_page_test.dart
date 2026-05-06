import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_sign_language_interpretation/modules/home/controllers/home_page_controller.dart';
import 'package:flutter_sign_language_interpretation/modules/home/views/home_page.dart';
import 'package:flutter_sign_language_interpretation/services/camera/camera_service.dart';
import 'package:flutter_sign_language_interpretation/services/connection/realtime_ws_service.dart';
import 'package:flutter_sign_language_interpretation/services/debug/debug_log_service.dart';
import 'package:flutter_sign_language_interpretation/services/permissions/permission_service.dart';
import 'package:flutter_sign_language_interpretation/services/session/session_service.dart';
import 'package:flutter_sign_language_interpretation/services/settings/runtime_settings_service.dart';
import 'package:flutter_sign_language_interpretation/services/speech/speech_service.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(RuntimeSettingsService());
    Get.put(DebugLogService());
    Get.put(SessionService());
    Get.put(PermissionService());
    Get.put(SpeechService());
    Get.put(RealtimeWsService());
    Get.put(
      CameraService(
        permissionService: Get.find<PermissionService>(),
        wsService: Get.find<RealtimeWsService>(),
      ),
    );
  });

  tearDown(() {
    Get.reset();
  });

  testWidgets('shows permission state when camera permission is denied', (
    tester,
  ) async {
    final permissions = Get.find<PermissionService>();
    final camera = Get.find<CameraService>();
    permissions.cameraState.value = PermissionState.denied;
    permissions.microphoneState.value = PermissionState.denied;
    camera.state.value = CameraState.permissionDenied;

    Get.put(HomePageController(autoBootstrap: false));

    await tester.pumpWidget(
      const GetCupertinoApp(home: HomePage()),
    );
    await tester.pump();

    expect(find.text('Camera and microphone permissions are required'), findsOneWidget);
  });
}
