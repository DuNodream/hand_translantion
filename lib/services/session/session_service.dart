import 'dart:async';

import 'package:get/get.dart';

import '../../data/models/chat_message.dart';
import '../connection/realtime_ws_service.dart';
import '../settings/runtime_settings_service.dart';

class SessionService extends GetxService {
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxString liveCaption = '等待识别开始'.obs;
  final RxBool isRecognizing = false.obs;
  final RxString sessionId = 'default-session'.obs;

  // ========== 作弊者模式剧本（从 RuntimeSettingsService 读取）==========
  int _cheaterStep = 0;
  bool _cheaterWaitingForReply = false;
  Timer? _cheaterSignerTimer;

  List<String> get _cheaterScript =>
      Get.find<RuntimeSettingsService>().cheaterScript;

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final message = ChatMessage(
      content: trimmed,
      origin: MessageOrigin.user,
      status: MessageStatus.sending,
    );
    messages.add(message);

    final ws = Get.find<RealtimeWsService>();
    final sent = ws.sendTextMessage(trimmed, messageId: message.id);
    _updateMessageStatus(
      message.id,
      sent ? MessageStatus.success : MessageStatus.failed,
    );

    // 作弊者模式：用户打字 → 视为对话者回复，解锁下一段剧本
    _cheaterUnlockIfWaiting();
  }

  void addSpeechDraft(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    messages.add(
      ChatMessage(
        content: trimmed,
        origin: MessageOrigin.speech,
      ),
    );
    // 作弊者模式：语音输入 → 视为对话者回复，解锁下一段剧本
    _cheaterUnlockIfWaiting();
  }

  void retryMessage(String messageId) {
    final index = messages.indexWhere((item) => item.id == messageId);
    if (index < 0) return;
    final message = messages[index];
    if (message.status != MessageStatus.failed) return;
    messages[index] = message.copyWith(status: MessageStatus.sending);
    final sent = Get.find<RealtimeWsService>().sendTextMessage(
      message.content,
      messageId: message.id,
    );
    _updateMessageStatus(
      message.id,
      sent ? MessageStatus.success : MessageStatus.failed,
    );
  }

  /// 作弊者模式：按剧本输出一句话并广播给对话者，然后等待对话者回复。
  void _handleCheaterResult() {
    if (_cheaterWaitingForReply) return;

    final userMsg = _cheaterScript[_cheaterStep];
    messages.add(ChatMessage(content: userMsg, origin: MessageOrigin.sign));
    liveCaption.value = userMsg;
    _cheaterWaitingForReply = true;
    _cheaterStep = (_cheaterStep + 1) % _cheaterScript.length;

    // 广播给对话者
    Get.find<RealtimeWsService>().sendTextMessage(
      userMsg,
      messageId: 'cheater-${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  /// 作弊者模式：对话者回复后清除等待状态，手语者端重启 15s 计时器
  void _cheaterUnlockIfWaiting() {
    if (!Get.find<RuntimeSettingsService>().cheaterMode.value) return;
    if (!_cheaterWaitingForReply) return;
    _cheaterWaitingForReply = false;

    final role = Get.find<RuntimeSettingsService>().role.value;
    if (role == 'signer') {
      _cheaterSignerTimer?.cancel();
      _cheaterSignerTimer = Timer(const Duration(seconds: 15), _handleCheaterResult);
    }
  }

  // ==================== 自动播放（15s 循环） ====================

  void startCheaterAutoPlay() {
    _cheaterSignerTimer?.cancel();
    _cheaterSignerTimer = Timer(const Duration(seconds: 15), _handleCheaterResult);
  }

  void stopCheaterAutoPlay() {
    _cheaterSignerTimer?.cancel();
    _cheaterSignerTimer = null;
  }

  void onRecognitionPayload(Map<String, dynamic> payload) {
    final type = payload['type']?.toString() ?? '';
    switch (type) {
      case 'recording_start':
        isRecognizing.value = true;
        liveCaption.value = '正在采集手语片段...';
        messages.add(ChatMessage.system('已检测到手语动作'));
        break;
      case 'inference_start':
        isRecognizing.value = true;
        liveCaption.value = '正在识别内容...';
        break;
      case 'no_result':
        isRecognizing.value = false;
        liveCaption.value = '未识别到有效内容';
        break;
      case 'result':
        isRecognizing.value = false;
        if (Get.find<RuntimeSettingsService>().cheaterMode.value) break;
        final naturalText = payload['natural_text']?.toString().trim() ?? '';
        final glosses = payload['glosses']?.toString().trim() ?? '';
        final reqId = (payload['request_id'] is int)
            ? payload['request_id'] as int
            : int.tryParse(payload['request_id']?.toString() ?? '');
        final nlpPending = payload['nlp_pending'] == true;
        liveCaption.value = naturalText.isNotEmpty ? naturalText : glosses;
        if (naturalText.isNotEmpty || glosses.isNotEmpty) {
          messages.add(
            ChatMessage(
              content: naturalText.isNotEmpty ? naturalText : glosses,
              origin: MessageOrigin.sign,
              requestId: reqId,
              nlpPending: nlpPending,
            ),
          );
        }
        break;
      case 'nlp_result':
        // 作弊者模式下忽略 NLP 异步结果
        if (Get.find<RuntimeSettingsService>().cheaterMode.value) break;
        // PR-2: NLP 异步结果到达；按 request_id 找到对应消息并替换文本
        final naturalText = payload['natural_text']?.toString().trim() ?? '';
        final reqId = (payload['request_id'] is int)
            ? payload['request_id'] as int
            : int.tryParse(payload['request_id']?.toString() ?? '');
        if (naturalText.isEmpty || reqId == null) break;
        final idx = messages.lastIndexWhere(
          (m) => m.requestId == reqId && m.origin == MessageOrigin.sign,
        );
        if (idx >= 0) {
          messages[idx] = messages[idx].copyWith(
            content: naturalText,
            nlpPending: false,
          );
          messages.refresh();
        } else {
          // 找不到原消息（可能被清理了）；退化为追加一条
          messages.add(
            ChatMessage(
              content: naturalText,
              origin: MessageOrigin.sign,
              requestId: reqId,
            ),
          );
        }
        liveCaption.value = naturalText;
        break;
      case 'error':
        isRecognizing.value = false;
        liveCaption.value = payload['message']?.toString() ?? '服务异常';
        messages.add(ChatMessage.system(liveCaption.value));
        break;

      // ========== 房间聊天消息 ==========
      case 'chat_message':
        final content = payload['content']?.toString().trim() ?? '';
        final sender = payload['sender']?.toString() ?? '';
        if (content.isEmpty) return;
        if (sender == 'signer') {
          final cheaterOn = Get.find<RuntimeSettingsService>().cheaterMode.value;
          if (cheaterOn) {
            if (_cheaterWaitingForReply) break;
            final scripted = _cheaterScript[_cheaterStep];
            _cheaterStep = (_cheaterStep + 1) % _cheaterScript.length;
            messages.add(ChatMessage(
              content: scripted,
              origin: MessageOrigin.sign,
            ));
            _cheaterWaitingForReply = true;
          } else {
            messages.add(ChatMessage(content: content, origin: MessageOrigin.sign));
          }
        } else if (sender == 'chat') {
          final lastMsg = messages.isNotEmpty ? messages.last : null;
          final isDuplicate = lastMsg != null &&
              lastMsg.content == content &&
              lastMsg.origin == MessageOrigin.speech;
          if (!isDuplicate) {
            messages.add(ChatMessage(content: content, origin: MessageOrigin.speech));
          }
          _cheaterUnlockIfWaiting();
        }
        liveCaption.value = content;
        break;

      case 'chat_message_ack':
        // 自己发送的消息已被服务器确认
        break;

      case 'peer_joined':
        final peerRole = payload['role']?.toString() ?? '';
        messages.add(ChatMessage.system('对方已加入 ($peerRole)'));
        break;

      case 'peer_left':
        messages.add(ChatMessage.system('对方已离开'));
        break;
    }
  }

  void clearConversation() {
    _cheaterStep = 0;
    _cheaterWaitingForReply = false;
    _cheaterSignerTimer?.cancel();
    _cheaterSignerTimer = null;
    messages.clear();
    liveCaption.value = '等待识别开始';
  }

  void _updateMessageStatus(String id, MessageStatus status) {
    final index = messages.indexWhere((item) => item.id == id);
    if (index < 0) return;
    messages[index] = messages[index].copyWith(status: status);
    messages.refresh();
  }
}
