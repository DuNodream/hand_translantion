import 'package:get/get.dart';

import '../../data/models/chat_message.dart';
import '../connection/realtime_ws_service.dart';

class SessionService extends GetxService {
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;
  final RxString liveCaption = '等待识别开始'.obs;
  final RxBool isRecognizing = false.obs;
  final RxString sessionId = 'default-session'.obs;

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
        final naturalText = payload['natural_text']?.toString().trim() ?? '';
        final glosses = payload['glosses']?.toString().trim() ?? '';
        liveCaption.value = naturalText.isNotEmpty ? naturalText : glosses;
        if (naturalText.isNotEmpty) {
          messages.add(
            ChatMessage(
              content: naturalText,
              origin: MessageOrigin.sign,
            ),
          );
        }
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
          // 手语者发来的消息（识别结果已通过 result 事件处理，但双设备模式下由广播转发）
          messages.add(ChatMessage(content: content, origin: MessageOrigin.sign));
        } else if (sender == 'chat') {
          // 对话者发来的文字回复
          messages.add(ChatMessage(content: content, origin: MessageOrigin.speech));
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
