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
}
