import 'package:reelpin/data_models/chat/answer_block.dart';
import 'package:reelpin/data_models/chat/chat_attachment.dart';

enum MessageRole { user, assistant }

enum MessageStatus { sending, complete, failed }

class ChatMessage {
  final String id;
  final MessageRole role;

  /// The user's typed question. Empty on assistant messages, which carry
  /// [blocks] instead.
  final String text;
  final List<ChatAttachment> attachments;
  final List<AnswerBlock> blocks;
  final MessageStatus status;
  final DateTime createdAt;

  /// Who asked, in a thread with more than one author. Empty in the private
  /// chat, which has exactly one.
  final String authorName;

  /// True when this pair was published into a collection's shared thread from
  /// someone's private chat, rather than asked in the open — so the answer can
  /// be labelled as such. Always false in a private thread.
  final bool isShared;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.createdAt,
    this.text = '',
    this.attachments = const [],
    this.blocks = const [],
    this.status = MessageStatus.complete,
    this.authorName = '',
    this.isShared = false,
  });

  ChatMessage copyWith({List<AnswerBlock>? blocks, MessageStatus? status}) =>
      ChatMessage(
        id: id,
        role: role,
        createdAt: createdAt,
        text: text,
        attachments: attachments,
        blocks: blocks ?? this.blocks,
        status: status ?? this.status,
        authorName: authorName,
        isShared: isShared,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id']?.toString() ?? '',
    role: json['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now().toUtc(),
    text: json['text']?.toString() ?? '',
    attachments: _mapList(
      json['attachments'],
    ).map(ChatAttachment.fromJson).toList(),
    blocks: _mapList(
      json['blocks'],
    ).map(AnswerBlock.fromJson).whereType<AnswerBlock>().toList(),
    status: MessageStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => MessageStatus.complete,
    ),
    authorName: json['author_name']?.toString() ?? '',
    isShared: json['source'] == 'shared',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'created_at': createdAt.toIso8601String(),
    'text': text,
    'status': status.name,
    'attachments': attachments.map((a) => a.toJson()).toList(),
    'blocks': blocks.map((b) => b.toJson()).toList(),
  };
}

class ChatThread {
  final String id;

  /// Taken from the first question, so the history list is readable without
  /// asking the backend to name anything.
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatThread({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  ChatThread copyWith({
    String? title,
    List<ChatMessage>? messages,
    DateTime? updatedAt,
  }) => ChatThread(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messages: messages ?? this.messages,
  );

  factory ChatThread.fromJson(Map<String, dynamic> json) => ChatThread(
    id: json['id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    createdAt:
        DateTime.tryParse(json['created_at']?.toString() ?? '') ??
        DateTime.now().toUtc(),
    updatedAt:
        DateTime.tryParse(json['updated_at']?.toString() ?? '') ??
        DateTime.now().toUtc(),
    messages: _mapList(json['messages']).map(ChatMessage.fromJson).toList(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };
}

/// A field holding the wrong JSON type (a String where a List was expected,
/// say) degrades to an empty list here rather than throwing, so one bad field
/// never takes the rest of the message — or the thread — down with it.
List<Map<String, dynamic>> _mapList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
}
