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
  final _uuid = const Uuid();

  // Message history for current session
  final List<ChatMessageModel> _messages = [];
  List<ChatMessageModel> get messages => List.unmodifiable(_messages);

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
    _memory = MemoryManager(_cactus, PersistenceService());
    await _memory.initialize();
    _tools = ToolHandler(_memory);
    _ready = true;
    debugPrint('ChatController initialized');
  }

  /// Send a message and generate a response
  Future<void> sendMessage(String text) async {
    if (_generating || text.trim().isEmpty || !_ready) return;

    // Add user message to UI
    _messages.add(ChatMessageModel(
      id: _uuid.v4(),
      content: text,
      isUser: true,
    ));

    // Add assistant placeholder
    final assistantId = _uuid.v4();
    _messages.add(ChatMessageModel(
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

    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      await _handleError(assistantId, e);
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  String _buildSystemPrompt(String context) {
    return '''You are Cortex, a caring and empathetic AI companion with persistent memory. You automatically remember everything the user shares.

$context

PERSONALITY & BEHAVIOR:
- Be warm, empathetic, and genuinely supportive
- Reference specific details you know about the user naturally
- If the user shares something difficult, acknowledge their feelings FIRST before offering advice
- Keep responses concise (2-3 sentences unless asked for more)
- Never give generic advice - always personalize based on their context
- NEVER mention tools, functions, or memory commands - memory is automatic
- If you don't know something about the user, don't make assumptions''';
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
    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      _messages[i] = _messages[i].copyWith(
        content: content.isEmpty ? '...' : content,
        isLoading: loading,
        usedMemories: usedMemories,
      );
      notifyListeners();
    }
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

    _generating = true;

    final userMsgId = _uuid.v4();
    final assistantMsgId = _uuid.v4();

    _messages.add(ChatMessageModel(
      id: userMsgId,
      content: 'Loading vision model...',
      isUser: true,
      imageUrl: path,
    ));

    _messages.add(ChatMessageModel(
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
    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      _messages[i] = _messages[i].copyWith(content: content);
      notifyListeners();
    }
  }

  /// Process voice recording for transcription and memory
  Future<void> processVoice(String path) async {
    if (!_ready || _generating) return;

    _generating = true;

    final id = _uuid.v4();
    _messages.add(ChatMessageModel(
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

  /// Clear current chat session
  void clearChat() {
    _messages.clear();
    _conversationHistory.clear();
    _memory.clearHistory();
    notifyListeners();
  }

  /// Clear all memory and chat
  Future<void> clearAll() async {
    await _memory.clearAll();
    _messages.clear();
    _conversationHistory.clear();
    notifyListeners();
  }

  // Getters for memory data
  List<SemanticFact> getFacts() => _memory.getAllFacts();
  MemoryStatistics getMemoryStats() => _memory.getStatistics();
  MemoryManager get memoryManager => _memory;
}
