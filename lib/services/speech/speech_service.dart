import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../debug/debug_log_service.dart';
import '../session/session_service.dart';

enum SpeechState { idle, unavailable, listening, error }

class SpeechService extends GetxService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final Rx<SpeechState> state = SpeechState.idle.obs;
  final RxnString errorMessage = RxnString();

  DebugLogService? get _debugLog =>
      Get.isRegistered<DebugLogService>() ? Get.find<DebugLogService>() : null;

  Future<void> initialize() async {
    try {
      // 先尝试中文 locale，再尝试默认 locale
      bool available = false;
      final locales = await _speech.locales();
      final hasCn = locales.any((l) => l.localeId.startsWith('zh'));
      if (hasCn) {
        _debugLog?.log('speech', 'found Chinese locale, trying...');
      }
      available = await _speech.initialize(
        onStatus: (_) {},
        onError: (error) {
          errorMessage.value = error.errorMsg;
          state.value = SpeechState.error;
          _debugLog?.log('speech', 'plugin error: ${error.errorMsg}');
        },
      );

      if (!available) {
        // 国内手机通常没有 Google 语音服务，尝试备选
        state.value = SpeechState.unavailable;
        errorMessage.value = '语音识别在当前设备不可用（国内手机需安装 Google 语音服务或使用系统自带语音引擎）';
        _debugLog?.log('speech', 'initialize unavailable');
      } else {
        state.value = SpeechState.idle;
      }
    } on PlatformException catch (error) {
      errorMessage.value = _mapPlatformError(error);
      state.value = SpeechState.unavailable;
      debugPrint('Speech initialize unavailable: $error');
      _debugLog?.log('speech', 'initialize unavailable: ${errorMessage.value}');
    } catch (error) {
      errorMessage.value = error.toString();
      state.value = SpeechState.error;
      debugPrint('Speech initialize error: $error');
      _debugLog?.log('speech', 'initialize error: $error');
    }
  }

  Future<void> toggleListening() async {
    if (state.value == SpeechState.listening) {
      await _speech.stop();
      state.value = SpeechState.idle;
      _debugLog?.log('speech', 'listening stopped');
      return;
    }

    try {
      final available = await _speech.initialize();
      if (!available) {
        state.value = SpeechState.unavailable;
        errorMessage.value = '语音识别在当前设备不可用';
        _debugLog?.log('speech', 'recognizer unavailable');
        return;
      }

      state.value = SpeechState.listening;
      _debugLog?.log('speech', 'listening started');
      await _speech.listen(
        localeId: 'zh_CN',
        onResult: (result) {
          if (result.finalResult) {
            Get.find<SessionService>().addSpeechDraft(result.recognizedWords);
            state.value = SpeechState.idle;
            _debugLog?.log('speech', 'final result: ${result.recognizedWords}');
          }
        },
      );
    } on PlatformException catch (error) {
      errorMessage.value = _mapPlatformError(error);
      state.value = SpeechState.unavailable;
      debugPrint('Speech toggle unavailable: $error');
      _debugLog?.log('speech', 'toggle unavailable: ${errorMessage.value}');
    } catch (error) {
      errorMessage.value = error.toString();
      state.value = SpeechState.error;
      debugPrint('Speech toggle error: $error');
      _debugLog?.log('speech', 'toggle error: $error');
    }
  }

  String _mapPlatformError(PlatformException error) {
    if (error.code == 'recognizerNotAvailable') {
      return '当前设备没有可用的语音识别引擎（国内手机需安装 Google 语音搜索或启用系统语音引擎）';
    }
    return error.message ?? error.code;
  }

  @override
  void onClose() {
    if (!kIsWeb) {
      _speech.stop();
    }
    super.onClose();
  }
}
