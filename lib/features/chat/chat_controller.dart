import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/cactus_service.dart';
import '../../core/services/memory_manager.dart';
import '../../core/services/persistence_service.dart';
import '../../core/tools/tool_handler.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/semantic_fact.dart';
import '../../shared/constants.dart';

/// Manages chat interactions with memory-augmented generation
class ChatController extends ChangeNotifier {
  final CactusService _cactus;
  late MemoryManager _memory;
  late ToolHandler _tools;
  late PersistenceService _persistence;
  final _uuid = const Uuid();

  // Multi-conversation support
  final List<Conversation> _conversations = [];
  List<Conversation> get conversations => List.unmodifiable(_conversations);

  String? _currentConversationId;
  String? get currentConversationId => _currentConversationId;

  Conversation? get currentConversation =>
      _currentConversationId == null
          ? null
          : _conversations.where((c) => c.id == _currentConversationId).firstOrNull;

  // Message history for current session
  List<ChatMessageModel> get messages => currentConversation?.messages ?? [];

  // Conversation history for LLM context
  final List<ChatMessage> _conversationHistory = [];

  bool _generating = false;
  bool get isGenerating => _generating;

  bool _ready = false;
  bool get isReady => _ready;

  ChatController(this._cactus);

  /// Initialize the chat controller
  Future<void> initialize() async {
    if (_ready) return;
    _persistence = PersistenceService();
    _memory = MemoryManager(_cactus, _persistence);
    await _memory.initialize();
    _tools = ToolHandler(_memory);

    // Load saved conversations
    final savedConversations = await _persistence.loadConversations();
    _conversations.addAll(savedConversations);

    // Load last active conversation
    final lastId = await _persistence.loadCurrentConversationId();
    if (lastId != null && _conversations.any((c) => c.id == lastId)) {
      _currentConversationId = lastId;
      _rebuildConversationHistory();
    }

    _ready = true;
    debugPrint('ChatController initialized with ${_conversations.length} conversations');
  }

  /// Create a new conversation
  Future<void> createNewConversation() async {
    final now = DateTime.now();
    final conversation = Conversation(
      id: _uuid.v4(),
      title: 'New Chat',
      createdAt: now,
      updatedAt: now,
      messages: [],
    );

    _conversations.insert(0, conversation);
    _currentConversationId = conversation.id;
    _conversationHistory.clear();

    await _persistence.saveConversations(_conversations);
    await _persistence.saveCurrentConversationId(conversation.id);

    notifyListeners();
  }

  /// Switch to a different conversation
  Future<void> switchToConversation(String id) async {
    if (id == _currentConversationId) return;

    final conv = _conversations.where((c) => c.id == id).firstOrNull;
    if (conv == null) return;

    _currentConversationId = id;
    _rebuildConversationHistory();

    await _persistence.saveCurrentConversationId(id);
    notifyListeners();
  }

  /// Delete a conversation
  Future<void> deleteConversation(String id) async {
    _conversations.removeWhere((c) => c.id == id);

    if (_currentConversationId == id) {
      _currentConversationId = _conversations.isNotEmpty ? _conversations.first.id : null;
      _rebuildConversationHistory();
    }

    await _persistence.saveConversations(_conversations);
    await _persistence.saveCurrentConversationId(_currentConversationId);
    notifyListeners();
  }

  /// Rebuild the LLM conversation history from the current conversation
  void _rebuildConversationHistory() {
    _conversationHistory.clear();
    final conv = currentConversation;
    if (conv == null) return;

    for (final msg in conv.messages.take(AppConstants.maxHistoryTurns * 2)) {
      _conversationHistory.add(ChatMessage(
        content: msg.content,
        role: msg.isUser ? 'user' : 'assistant',
      ));
    }
  }

  /// Update conversation title based on first message
  void _updateConversationTitle(String firstMessage) {
    if (currentConversation == null) return;

    final title = firstMessage.length > 30
        ? '${firstMessage.substring(0, 30)}...'
        : firstMessage;

    final idx = _conversations.indexWhere((c) => c.id == _currentConversationId);
    if (idx != -1 && _conversations[idx].title == 'New Chat') {
      _conversations[idx] = _conversations[idx].copyWith(title: title);
    }
  }

  /// Get mutable messages list for current conversation
  List<ChatMessageModel> get _currentMessages {
    final conv = currentConversation;
    if (conv == null) return [];
    return conv.messages;
  }

  /// Add a message to the current conversation
  void _addMessage(ChatMessageModel message) {
    final idx = _conversations.indexWhere((c) => c.id == _currentConversationId);
    if (idx == -1) return;

    final conv = _conversations[idx];
    final updatedMessages = [...conv.messages, message];
    _conversations[idx] = conv.copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
  }

  /// Update a message in the current conversation
  void _updateMessageInConversation(String id, ChatMessageModel Function(ChatMessageModel) update) {
    final convIdx = _conversations.indexWhere((c) => c.id == _currentConversationId);
    if (convIdx == -1) return;

    final conv = _conversations[convIdx];
    final msgIdx = conv.messages.indexWhere((m) => m.id == id);
    if (msgIdx == -1) return;

    final updatedMessages = [...conv.messages];
    updatedMessages[msgIdx] = update(updatedMessages[msgIdx]);
    _conversations[convIdx] = conv.copyWith(
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
  }

  /// Save current conversation state
  Future<void> _saveConversation() async {
    await _persistence.saveConversations(_conversations);
  }

  /// Send a message and generate a response
  Future<void> sendMessage(String text) async {
    if (_generating || text.trim().isEmpty || !_ready) return;

    // Auto-create conversation if none exists
    if (_currentConversationId == null) {
      await createNewConversation();
    }

    // Add user message to UI
    _addMessage(ChatMessageModel(
      id: _uuid.v4(),
      content: text,
      isUser: true,
    ));

    // Update title if this is the first message
    if (_currentMessages.length == 1) {
      _updateConversationTitle(text);
    }

    // Add assistant placeholder
    final assistantId = _uuid.v4();
    _addMessage(ChatMessageModel(
      id: assistantId,
      content: '',
      isUser: false,
      isLoading: true,
    ));

    _generating = true;
    notifyListeners();

    String response = '';
    int usedMemories = 0;

    try {
      // Build memory-augmented context
      final context = await _memory.buildContext(text);
      usedMemories = _memory.workingMemory.activeSlots.length;

      final systemPrompt = _buildSystemPrompt(context);

      // Build messages for LLM
      final msgs = <ChatMessage>[
        ChatMessage(content: systemPrompt, role: 'system'),
        ..._conversationHistory.take(AppConstants.maxHistoryTurns * 2),
        ChatMessage(content: text, role: 'user'),
      ];

      debugPrint('Sending message with ${msgs.length} messages, context length: ${context.length}');

      // Generate streaming response
      final stream = await _cactus.generateCompletionStream(
        messages: msgs,
        params: CactusCompletionParams(
          maxTokens: AppConstants.maxResponseTokens,
          // Tools defined but handled post-generation
          tools: _getMemoryTools(),
        ),
      );

      await for (final chunk in stream.stream) {
        response += chunk;
        _updateMessage(assistantId, response, loading: true);
      }

      // Get final result
      CactusCompletionResult? result;
      try {
        result = await stream.result;
        debugPrint('Response complete. Success: ${result.success}, Tool calls: ${result.toolCalls.length}');
      } catch (e) {
        debugPrint('Result parsing error (using streamed response): $e');
      }

      // Handle tool calls silently
      if (result != null && result.toolCalls.isNotEmpty) {
        for (final tc in result.toolCalls) {
          debugPrint('Executing tool: ${tc.name} with args: ${tc.arguments}');
          final toolResult = await _tools.handle(tc);
          debugPrint('Tool result: $toolResult');
        }

        // Use result.response if streaming missed content
        if (response.isEmpty && result.response.isNotEmpty) {
          response = result.response;
        }
      }

      // Clean response
      response = _cleanResponse(response);

      // Fallback if empty
      if (response.isEmpty || response.length < 3) {
        response = "I'm here to help! What would you like to talk about?";
      }

      _updateMessage(assistantId, response, loading: false, usedMemories: usedMemories);

      // Update conversation history
      _conversationHistory.add(ChatMessage(content: text, role: 'user'));
      _conversationHistory.add(ChatMessage(content: response, role: 'assistant'));

      // Trim history if too long
      while (_conversationHistory.length > AppConstants.maxHistoryTurns * 2) {
        _conversationHistory.removeAt(0);
      }

      // Store in episodic memory
      await _memory.storeConversation(text, response);
      debugPrint('Conversation stored in memory');

      // Save conversation to persistence
      await _saveConversation();

    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      await _handleError(assistantId, e);
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  String _buildSystemPrompt(String context) {
    final hasContext = context.trim().isNotEmpty;

    return '''You are Cortex, a thoughtful AI companion who truly knows the user. Everything runs privately on their device - you're their personal AI that remembers and grows with them.

${hasContext ? context : '(No memories yet - this is a new conversation!)'}

CORE PERSONALITY:
- Warm, genuine, and attentive - like a trusted friend who actually listens
- Reference what you know naturally: "Since you work at [company]..." or "I remember you mentioned..."
- If you know their name, use it occasionally (but not every message)
- Be concise but meaningful - quality over quantity (2-3 sentences usually)

MEMORY BEHAVIOR:
- You automatically remember important things - never say "I'll remember that" or mention memory
- When they share something new about themselves, acknowledge it naturally
- Connect new information to what you already know when relevant
- If asked "what do you know about me?" - share facts warmly, not as a list

EMOTIONAL INTELLIGENCE:
- Match their energy - playful when they're light, supportive when they're struggling
- Acknowledge feelings before problem-solving
- Celebrate their wins, even small ones
- Ask follow-up questions that show you care

WHAT TO AVOID:
- Generic responses that could apply to anyone
- Mentioning tools, functions, JSON, or technical details
- Being overly formal or robotic
- Making assumptions about things you don't know''';
  }

  List<CactusTool> _getMemoryTools() {
    return [
      CactusTool(
        name: 'remember',
        description: 'Store important information the user wants remembered',
        parameters: ToolParametersSchema(
          properties: {
            'content': ToolParameter(
              type: 'string',
              description: 'What to remember',
              required: true,
            ),
            'importance': ToolParameter(
              type: 'string',
              description: 'low, medium, high, or critical',
              required: false,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'recall',
        description: 'Search memories for specific information',
        parameters: ToolParametersSchema(
          properties: {
            'query': ToolParameter(
              type: 'string',
              description: 'What to search for',
              required: true,
            ),
          },
        ),
      ),
      CactusTool(
        name: 'list_facts',
        description: 'List all known facts about the user',
        parameters: ToolParametersSchema(properties: {}),
      ),
    ];
  }

  String _cleanResponse(String response) {
    String cleaned = response
        // Remove code blocks
        .replaceAll(RegExp(r"```[a-z]*\n?", caseSensitive: false), '')
        .replaceAll(RegExp(r"'''[a-z]*\n?", caseSensitive: false), '')
        .replaceAll(RegExp(r'```'), '')
        .replaceAll(RegExp(r"'''"), '')
        // Remove thinking tags
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .replaceAll(RegExp(r'<think>.*$', dotAll: true), '')
        // Remove function call artifacts
        .replaceAll(RegExp(r'function_call\s*[:\(\{].*', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'function_call', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bname\s*:\s*\w+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\barguments\s*:\s*.*', caseSensitive: false), '')
        // Remove JSON structures
        .replaceAll(RegExp(r'\{[^{}]*"[^{}]*\}', dotAll: true), '')
        .replaceAll(RegExp(r'\{"[a-zA-Z_]+":', dotAll: true), '')
        .replaceAll(RegExp(r'\{[^\}]{0,100}\}', dotAll: true), '')
        .replaceAll(RegExp(r'\{[^\}]*$', dotAll: true), '')
        .replaceAll(RegExp(r'"name"\s*:\s*"[a-zA-Z_]+"', dotAll: true), '')
        .replaceAll(RegExp(r'"arguments"\s*:\s*[^\n]*', dotAll: true), '')
        .replaceAll(RegExp(r'\("[a-zA-Z_]+"\s*:\s*[^\)]*\)', dotAll: true), '')
        // Remove tool output artifacts
        .replaceAll(RegExp(r'^No facts stored yet\.\s*\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^Remembered:.*\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^Found:.*\n?', multiLine: true), '')
        // Remove special tokens
        .replaceAll(RegExp(r'<\|[^|>]*\|>'), '')
        .replaceAll(RegExp(r'<\|im_end\|>'), '')
        .replaceAll(RegExp(r'</s>'), '')
        .replaceAll(RegExp(r'<\|endoftext\|>'), '')
        // Clean up whitespace
        .replaceAll(RegExp(r'^\s*[:\}\{\]\[]+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*[:\}\{\]\[]+\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*[\{\}\[\]:,]+\s*$', multiLine: true), '')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'^\s*\n', multiLine: true), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    return cleaned.isEmpty || cleaned.length < 3
        ? "I'm listening! How can I help you?"
        : cleaned;
  }

  void _updateMessage(
    String id,
    String content, {
    required bool loading,
    int usedMemories = 0,
  }) {
    _updateMessageInConversation(id, (msg) => msg.copyWith(
      content: content.isEmpty ? '...' : content,
      isLoading: loading,
      usedMemories: usedMemories,
    ));
    notifyListeners();
  }

  Future<void> _handleError(String messageId, Object error) async {
    final errorStr = error.toString();

    if (errorStr.contains('context') || errorStr.contains('initialize')) {
      debugPrint('Context error detected, attempting reinitialize...');
      try {
        await _cactus.reinitializePrimaryLM();
        _updateMessage(
          messageId,
          "I had a brief hiccup. Please try your message again!",
          loading: false,
        );
      } catch (reinitError) {
        debugPrint('Reinitialize failed: $reinitError');
        _updateMessage(
          messageId,
          "Something went wrong. Please restart the app.",
          loading: false,
        );
      }
    } else {
      _updateMessage(
        messageId,
        'Sorry, something went wrong. Please try again.',
        loading: false,
      );
    }
  }

  /// Process a photo for memory storage
  Future<void> processPhoto(String path) async {
    if (!_ready || _generating) return;

    // Auto-create conversation if none exists
    if (_currentConversationId == null) {
      await createNewConversation();
    }

    _generating = true;

    final userMsgId = _uuid.v4();
    final assistantMsgId = _uuid.v4();

    _addMessage(ChatMessageModel(
      id: userMsgId,
      content: 'Loading vision model...',
      isUser: true,
      imageUrl: path,
    ));

    _addMessage(ChatMessageModel(
      id: assistantMsgId,
      content: '',
      isUser: false,
      isLoading: true,
    ));

    notifyListeners();

    try {
      _updateUserMessage(userMsgId, 'Analyzing image...');

      final desc = await _memory.ingestPhoto(path);

      _updateUserMessage(userMsgId, 'Photo');
      _updateMessage(
        assistantMsgId,
        'I see: $desc\n\nI\'ve saved this to memory.',
        loading: false,
      );

      debugPrint('Photo processed and stored');
    } catch (e) {
      debugPrint('Error processing photo: $e');
      _updateUserMessage(userMsgId, 'Photo (failed)');
      _updateMessage(
        assistantMsgId,
        'Sorry, I couldn\'t analyze the image. Please try again.',
        loading: false,
      );
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  void _updateUserMessage(String id, String content) {
    _updateMessageInConversation(id, (msg) => msg.copyWith(content: content));
    notifyListeners();
  }

  /// Process voice recording for transcription and memory
  Future<void> processVoice(String path) async {
    if (!_ready || _generating) return;

    // Auto-create conversation if none exists
    if (_currentConversationId == null) {
      await createNewConversation();
    }

    _generating = true;

    final id = _uuid.v4();
    _addMessage(ChatMessageModel(
      id: id,
      content: 'Loading speech model...',
      isUser: true,
    ));
    notifyListeners();

    try {
      _updateUserMessage(id, 'Transcribing...');

      final text = await _memory.ingestVoice(path);
      _updateUserMessage(id, '"$text"');

      _generating = false;
      notifyListeners();

      // Send transcribed text as a message
      await sendMessage('Voice memo: "$text"');
    } catch (e) {
      debugPrint('Error processing voice: $e');
      _updateUserMessage(id, 'Voice (failed)');
      _generating = false;
      notifyListeners();
    }
  }

  /// Clear current chat session (starts a new conversation)
  Future<void> clearChat() async {
    _conversationHistory.clear();
    _memory.clearHistory();
    await createNewConversation();
    notifyListeners();
  }

  /// Clear all memory and chat
  Future<void> clearAll() async {
    await _memory.clearAll();
    _conversations.clear();
    _currentConversationId = null;
    _conversationHistory.clear();
    await _persistence.saveConversations([]);
    await _persistence.saveCurrentConversationId(null);
    notifyListeners();
  }

  // Getters for memory data
  List<SemanticFact> getFacts() => _memory.getAllFacts();
  MemoryStatistics getMemoryStats() => _memory.getStatistics();
  MemoryManager get memoryManager => _memory;
}
