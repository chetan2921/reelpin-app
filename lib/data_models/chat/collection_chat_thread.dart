/// One conversation inside a collection's chat, as the ASK screen's sidebar
/// lists it.
class CollectionChatThread {
  final String id;

  /// The first question asked in it, or the opening line of the shared answer
  /// that started it.
  final String title;
  final int questionCount;
  final DateTime? updatedAt;

  const CollectionChatThread({
    required this.id,
    required this.title,
    this.questionCount = 0,
    this.updatedAt,
  });

  factory CollectionChatThread.fromJson(Map<String, dynamic> json) =>
      CollectionChatThread(
        id: json['thread_id']?.toString() ?? 'main',
        title: json['title']?.toString() ?? '',
        questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );

  /// A list field of the wrong shape reads as no threads rather than throwing,
  /// the same as the rest of the chat's parsing.
  static List<CollectionChatThread> listFromJson(Object? raw) => raw is List
      ? raw
            .whereType<Map>()
            .map(
              (thread) => CollectionChatThread.fromJson(
                Map<String, dynamic>.from(thread),
              ),
            )
            .toList()
      : const [];

  Map<String, dynamic> toJson() => {
    'thread_id': id,
    'title': title,
    'question_count': questionCount,
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };
}
