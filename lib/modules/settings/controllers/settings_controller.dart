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

  // ==================== 开发者模式 ====================

  void toggleDevMode() {
    _settings.devModeEnabled.value = !_settings.devModeEnabled.value;
  }

  /// 开发者模式：不经过房间，直接进入识别页面
  void enterDevRecognitionPage() {
    Get.offNamed('/home', arguments: {
      'room_id': 'dev-mode',
      'role': 'signer',
      'is_creator': true,
    });
  }

  // ==================== 模型切换 ====================

  String get currentModelLabel {
    final m = _settings.selectedModel.value;
    return m.isEmpty ? '默认模型' : m;
  }

  void selectModel(String modelName) {
    _settings.selectedModel.value = modelName;
    // 通过 WebSocket 通知后端切换模型
    _sendModelSwitch(modelName);
  }

  void _sendModelSwitch(String modelName) {
    if (_ws.state.value != WsState.connected) {
      Get.snackbar(
        '提示',
        '模型将在下次连接时切换',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xCC1A1A2E),
        colorText: const Color(0xFFFFFFFF),
        duration: const Duration(seconds: 3),
      );
      return;
    }
    _ws.sendJson({
      'type': 'switch_model',
      'model': modelName,
    });
  }

  @override
  void onClose() {
    serverUrlController.dispose();
    super.onClose();
  }
}
