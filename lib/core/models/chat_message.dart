class ChatMessageModel {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isLoading;
  final String? imageUrl;
  final int usedMemories; // Number of memories used to generate this response

  ChatMessageModel({
    required this.id,
    required this.content,
    required this.isUser,
    DateTime? timestamp,
    this.isLoading = false,
    this.imageUrl,
    this.usedMemories = 0,
  }) : timestamp = timestamp ?? DateTime.now();

  ChatMessageModel copyWith({
    String? content,
    bool? isLoading,
    int? usedMemories,
  }) => ChatMessageModel(
    id: id,
    content: content ?? this.content,
    isUser: isUser,
    timestamp: timestamp,
    isLoading: isLoading ?? this.isLoading,
    imageUrl: imageUrl,
    usedMemories: usedMemories ?? this.usedMemories,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'imageUrl': imageUrl,
    'usedMemories': usedMemories,
  };

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) => ChatMessageModel(
    id: json['id'] as String,
    content: json['content'] as String,
    isUser: json['isUser'] as bool,
    timestamp: DateTime.parse(json['timestamp'] as String),
    imageUrl: json['imageUrl'] as String?,
    usedMemories: json['usedMemories'] as int? ?? 0,
  );
}

/// Represents a conversation with multiple messages
class Conversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessageModel> messages;

  Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  Conversation copyWith({
    String? title,
    DateTime? updatedAt,
    List<ChatMessageModel>? messages,
  }) => Conversation(
    id: id,
    title: title ?? this.title,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    messages: messages ?? this.messages,
  );

  /// Get a preview of the conversation (first user message or title)
  String get preview {
    final firstUserMsg = messages.where((m) => m.isUser).firstOrNull;
    if (firstUserMsg != null && firstUserMsg.content.isNotEmpty) {
      return firstUserMsg.content.length > 50
          ? '${firstUserMsg.content.substring(0, 50)}...'
          : firstUserMsg.content;
    }
    return title;
  }

  /// Get relative time description
  String get timeDescription {
    final now = DateTime.now();
    final diff = now.difference(updatedAt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${updatedAt.month}/${updatedAt.day}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as String,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    messages: (json['messages'] as List)
        .map((m) => ChatMessageModel.fromJson(m as Map<String, dynamic>))
        .toList(),
  );
}
