import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter_sign_language_interpretation/services/connection/realtime_ws_service.dart';
import 'package:flutter_sign_language_interpretation/services/session/session_service.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(() {
    Get.reset();
  });

  test('send text marks message failed when websocket is unavailable', () async {
    Get.put(SessionService());
    Get.put(RealtimeWsService());
    final service = Get.find<SessionService>();

    await service.sendText('你好');

    expect(service.messages, hasLength(1));
    expect(service.messages.first.status.name, 'failed');
  });

  test('recognition payload appends sign message', () {
    final service = SessionService();

    service.onRecognitionPayload({
      'type': 'result',
      'natural_text': '请稍等',
      'glosses': 'WAIT',
    });

    expect(service.liveCaption.value, '请稍等');
    expect(service.messages.single.content, '请稍等');
  });
}
