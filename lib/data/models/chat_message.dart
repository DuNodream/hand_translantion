import 'package:uuid/uuid.dart';

enum MessageOrigin { user, speech, sign, system }

enum MessageStatus { sending, success, failed }

class ChatMessage {
  final String id;
  final String content;
  final MessageOrigin origin;
  final MessageStatus status;
  final DateTime createdAt;

  ChatMessage({
    String? id,
    required this.content,
    required this.origin,
    this.status = MessageStatus.success,
    DateTime? createdAt,
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
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      origin: origin ?? this.origin,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
