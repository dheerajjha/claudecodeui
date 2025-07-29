import 'package:json_annotation/json_annotation.dart';

part 'message.g.dart';

@JsonSerializable()
class ChatMessage {
  final String id;
  final String type; // 'user', 'assistant', 'error', 'tool-call', etc.
  final String content;
  final List<String>? images;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    this.images,
    required this.timestamp,
    this.metadata,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => _$ChatMessageFromJson(json);
  Map<String, dynamic> toJson() => _$ChatMessageToJson(this);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage && 
      runtimeType == other.runtimeType &&
      id == other.id;

  @override
  int get hashCode => id.hashCode;

  ChatMessage copyWith({
    String? id,
    String? type,
    String? content,
    List<String>? images,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      type: type ?? this.type,
      content: content ?? this.content,
      images: images ?? this.images,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isUser => type == 'user';
  bool get isAssistant => type == 'assistant';
  bool get isError => type == 'error';
  bool get isToolCall => type == 'tool-call';
} 