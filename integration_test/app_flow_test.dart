import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_sign_language_interpretation/modules/home/controllers/home_page_controller.dart';
import 'package:flutter_sign_language_interpretation/modules/home/views/home_page.dart';
import 'package:flutter_sign_language_interpretation/services/camera/camera_service.dart';
import 'package:flutter_sign_language_interpretation/services/connection/realtime_ws_service.dart';
import 'package:flutter_sign_language_interpretation/services/permissions/permission_service.dart';
import 'package:flutter_sign_language_interpretation/services/session/session_service.dart';
import 'package:flutter_sign_language_interpretation/services/settings/runtime_settings_service.dart';
import 'package:flutter_sign_language_interpretation/services/speech/speech_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    Get.put(RuntimeSettingsService());
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

  testWidgets('home workbench shell renders', (tester) async {
    final ws = Get.find<RealtimeWsService>();
    final camera = Get.find<CameraService>();
    ws.state.value = WsState.connected;
    ws.statusText.value = '识别服务在线';
    camera.state.value = CameraState.ready;

    Get.put(HomePageController(autoBootstrap: false));

    await tester.pumpWidget(
      const GetCupertinoApp(home: HomePage()),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('实时字幕'), findsOneWidget);
    expect(find.text('会话记录'), findsOneWidget);
  });
}
