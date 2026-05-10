import 'package:get/get.dart';

class RuntimeSettingsService extends GetxService {
  // 连接
  final RxnString wsOverride = RxnString();

  // 显示
  final RxDouble textScale = 1.0.obs;
  final RxBool accessibleMode = true.obs;

  // 房间信息
  final RxnString roomCode = RxnString();
  final RxnString role = RxnString();

  // 视频识别开关（手语者模式可关闭）
  final RxBool videoRecognitionEnabled = true.obs;

  // 语音引擎：'system' | 'none'
  final RxString speechEngine = 'system'.obs;

  // ========== 开发者模式 ==========
  final RxBool devModeEnabled = false.obs;

  // ========== 模型切换 ==========
  final RxString selectedModel = ''.obs;
  final RxList<String> availableModels = <String>[].obs;
  static const String modelDir = r'D:\a\TFNet';
  static const List<String> knownModels = [
    'TFNet-CE-CSL-CSLDaily-32.46.pth',
    'CECSL-best.pt',
    'CECSL-Light-best.pt',
    'CECSL-Light-Char-best.pt',
    '1.pth',
    '1.int8.pth',
  ];

  void initialize() {
    availableModels.value = List.from(knownModels);
    if (knownModels.isNotEmpty) selectedModel.value = knownModels[0];
  }

  String resolveWsUrl(String fallback) => wsOverride.value?.trim().isNotEmpty == true
      ? wsOverride.value!.trim()
      : fallback;

  void updateWsOverride(String? value) {
    final trimmed = value?.trim() ?? '';
    wsOverride.value = trimmed.isEmpty ? null : trimmed;
  }

  void updateTextScale(double value) {
    textScale.value = value;
  }

  void setRoomInfo(String code, String roleName) {
    roomCode.value = code;
    role.value = roleName;
  }

  void toggleVideoRecognition() {
    videoRecognitionEnabled.value = !videoRecognitionEnabled.value;
  }

  void setSpeechEngine(String engine) {
    speechEngine.value = engine;
  }

  String speechEngineDisplayName(String engine) {
    switch (engine) {
      case 'system':
        return '系统语音识别';
      case 'none':
        return '关闭（仅文字输入）';
      default:
        return engine;
    }
  }

  List<String> get availableSpeechEngines => ['system', 'none'];
}
