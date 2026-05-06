import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';

import '../../../services/connection/realtime_ws_service.dart';
import '../../../services/settings/runtime_settings_service.dart';
import '../../../services/speech/speech_service.dart';

class SettingsController extends GetxController {
  late final RuntimeSettingsService _settings;
  late final RealtimeWsService _ws;
  late final SpeechService _speech;

  final serverUrlController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    _settings = Get.find<RuntimeSettingsService>();
    _ws = Get.find<RealtimeWsService>();
    _speech = Get.find<SpeechService>();

    serverUrlController.text = _settings.wsOverride.value ?? _ws.activeUrl;
  }

  RuntimeSettingsService get settings => _settings;
  RealtimeWsService get ws => _ws;

  String get roleLabel {
    switch (_settings.role.value) {
      case 'signer':
        return '手语者（摄像头输入）';
      case 'chat':
        return '对话者（文字回复）';
      default:
        return '未设置';
    }
  }

  Future<void> applyServerUrl(String value) async {
    _settings.updateWsOverride(value);
    await _ws.disconnect(manual: false);
    await _ws.connect();
  }

  void toggleVideoRecognition() {
    _settings.toggleVideoRecognition();
  }

  void setSpeechEngine(String engine) {
    _settings.setSpeechEngine(engine);
    if (engine == 'none' && _speech.state.value == SpeechState.listening) {
      _speech.toggleListening();
    }
  }

  @override
  void onClose() {
    serverUrlController.dispose();
    super.onClose();
  }
}
