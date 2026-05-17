import 'package:uuid/uuid.dart';

enum MessageOrigin { user, speech, sign, system }

enum MessageStatus { sending, success, failed }

class ChatMessage {
  final String id;
  final String content;
  final MessageOrigin origin;
  final MessageStatus status;
  final DateTime createdAt;
  /// PR-2/4: 关联到后端识别请求；NLP 异步结果到达时用它定位并更新文本。
  final int? requestId;
  /// PR-4: 是否仍在等待 NLP 结果（用于 UI 显示「转换中…」）。
  final bool nlpPending;

  ChatMessage({
    String? id,
    required this.content,
    required this.origin,
    this.status = MessageStatus.success,
    DateTime? createdAt,
    this.requestId,
    this.nlpPending = false,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  factory ChatMessage.system(String content) {
    return ChatMessage(
      content: content,
      origin: MessageOrigin.system,
    );
  }

  ChatMessage copyWith({
    String? id,
    String? content,
    MessageOrigin? origin,
    MessageStatus? status,
    DateTime? createdAt,
    int? requestId,
    bool? nlpPending,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      origin: origin ?? this.origin,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      requestId: requestId ?? this.requestId,
      nlpPending: nlpPending ?? this.nlpPending,
    );
  }
}
