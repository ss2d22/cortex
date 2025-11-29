import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../core/services/cactus_service.dart';
import '../../core/services/memory_manager.dart';
import '../../core/services/persistence_service.dart';
import '../../core/tools/memory_tools.dart';
import '../../core/tools/tool_handler.dart';
import '../../core/models/chat_message.dart';
import '../../core/models/semantic_fact.dart';

class ChatController extends ChangeNotifier {
  final CactusService _cactus;
  late MemoryManager _memory;
  late ToolHandler _tools;
  final _uuid = const Uuid();

  final List<ChatMessageModel> _messages = [];
  List<ChatMessageModel> get messages => List.unmodifiable(_messages);

  bool _generating = false;
  bool get isGenerating => _generating;

  bool _ready = false;

  ChatController(this._cactus);

  Future<void> initialize() async {
    if (_ready) return;
    _memory = MemoryManager(_cactus, PersistenceService());
    await _memory.initialize();
    _tools = ToolHandler(_memory);
    _ready = true;
    debugPrint('ChatController initialized');
  }

  Future<void> sendMessage(String text) async {
    if (_generating || text.trim().isEmpty || !_ready) return;

    // Add user message
    _messages.add(ChatMessageModel(id: _uuid.v4(), content: text, isUser: true));

    // Add assistant placeholder
    final aId = _uuid.v4();
    _messages.add(ChatMessageModel(id: aId, content: '', isUser: false, isLoading: true));

    _generating = true;
    notifyListeners();

    String response = '';

    try {
      final context = await _memory.buildContext(text);
      final systemPrompt = '''You are Cortex, a friendly AI assistant with persistent memory.

$context

Be conversational, friendly, and keep responses concise.''';

      final msgs = <ChatMessage>[
        ChatMessage(content: systemPrompt, role: 'system'),
        ..._memory.getHistory().take(6),
        ChatMessage(content: text, role: 'user'),
      ];

      debugPrint('Sending message with ${msgs.length} messages');

      final stream = await _cactus.lm.generateCompletionStream(
        messages: msgs,
        params: CactusCompletionParams(
          tools: memoryTools,
          maxTokens: 400,
        ),
      );

      await for (final chunk in stream.stream) {
        response += chunk;
        _updateMsg(aId, response, loading: true);
      }

      // Try to get the result, but handle JSON parsing errors gracefully
      CactusCompletionResult? result;
      try {
        result = await stream.result;
        debugPrint('Response complete. Success: ${result.success}, Tool calls: ${result.toolCalls.length}');
      } catch (parseError) {
        // JSON parsing error from malformed tool calls - use streamed response
        debugPrint('Result parsing error (using streamed response): $parseError');
        result = null;
      }

      // Check if generation was successful (if we got a result)
      if (result != null && !result.success) {
        debugPrint('Generation failed');
        // If we have streamed content, use it anyway
        if (response.isNotEmpty) {
          response = _cleanResponse(response);
          if (response.isNotEmpty && response.length >= 3) {
            _updateMsg(aId, response, loading: false);
            await _memory.storeConversation(text, response);
            return;
          }
        }
        _updateMsg(aId, "Sorry, I couldn't generate a response. Please try again.", loading: false);
        return;
      }

      // Handle tool calls silently (don't append to response)
      if (result != null) {
        for (final tc in result.toolCalls) {
          debugPrint('Executing tool: ${tc.name} with args: ${tc.arguments}');
          final toolResult = await _tools.handle(tc);
          debugPrint('Tool result: $toolResult');
          // Tools work silently - facts are stored, memories recalled for context
        }

        // Use result.response if streaming didn't capture content
        if (response.isEmpty && result.response.isNotEmpty) {
          response = result.response;
        }
      }

      // Clean up response (remove thinking tags, malformed tool calls, etc.)
      response = _cleanResponse(response);

      // Make sure we have a valid response
      if (response.isEmpty || response.length < 3) {
        response = "I'm here to help! What would you like to talk about?";
      }

      _updateMsg(aId, response, loading: false);

      // Store conversation in memory
      await _memory.storeConversation(text, response);
      debugPrint('Conversation stored in memory');

    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      final errorStr = e.toString();

      // Handle context initialization failures - try to reinitialize
      if (errorStr.contains('context') || errorStr.contains('initialize')) {
        debugPrint('Context error detected, attempting reinitialize...');
        try {
          await _cactus.reinitializeMainLM();
          _updateMsg(aId, "I had a brief hiccup. Please try your message again!", loading: false);
        } catch (reinitError) {
          debugPrint('Reinitialize failed: $reinitError');
          _updateMsg(aId, "Something went wrong. Please restart the app.", loading: false);
        }
      } else {
        // Don't show raw exception objects to user
        final errorMsg = errorStr.contains('Instance of')
            ? 'Something went wrong. Please try again.'
            : 'Sorry, something went wrong. Please try again.';
        _updateMsg(aId, errorMsg, loading: false);
      }
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  String _cleanResponse(String response) {
    // Remove thinking tags, function calls, and clean up
    String cleaned = response
        // Remove markdown code blocks first (```json, '''json, etc.)
        .replaceAll(RegExp(r"```[a-z]*\n?", caseSensitive: false), '')
        .replaceAll(RegExp(r"'''[a-z]*\n?", caseSensitive: false), '')
        .replaceAll(RegExp(r'```'), '')
        .replaceAll(RegExp(r"'''"), '')
        // Remove thinking tags (complete and incomplete)
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .replaceAll(RegExp(r'<think>.*$', dotAll: true), '')
        // Remove function_call patterns early (various formats the LLM outputs)
        .replaceAll(RegExp(r'function_call\s*[:\(\{].*', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'function_call', caseSensitive: false), '')
        // Remove name: and arguments: patterns (common in malformed tool calls)
        .replaceAll(RegExp(r'\bname\s*:\s*\w+', caseSensitive: false), '')
        .replaceAll(RegExp(r'\barguments\s*:\s*.*', caseSensitive: false), '')
        // Remove any JSON-like structures (tool calls, function calls)
        // Pattern: {"anything": ...} or {anything}
        .replaceAll(RegExp(r'\{[^{}]*"[^{}]*\}', dotAll: true), '')
        // Pattern: {"key": "value", ...} spread across text
        .replaceAll(RegExp(r'\{"[a-zA-Z_]+":', dotAll: true), '')
        // Standalone curly braces with content
        .replaceAll(RegExp(r'\{[^\}]{0,100}\}', dotAll: true), '')
        // Orphaned opening braces at end of text
        .replaceAll(RegExp(r'\{[^\}]*$', dotAll: true), '')
        // Remove quoted key-value patterns
        .replaceAll(RegExp(r'"name"\s*:\s*"[a-zA-Z_]+"', dotAll: true), '')
        .replaceAll(RegExp(r'"arguments"\s*:\s*[^\n]*', dotAll: true), '')
        // Remove parenthesized JSON-like content
        .replaceAll(RegExp(r'\("[a-zA-Z_]+"\s*:\s*[^\)]*\)', dotAll: true), '')
        // Remove tool output artifacts
        .replaceAll(RegExp(r'^No facts stored yet\.\s*\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^Remembered:.*\n?', multiLine: true), '')
        .replaceAll(RegExp(r'^Found:.*\n?', multiLine: true), '')
        // Remove special tokens (various formats)
        .replaceAll(RegExp(r'<\|[^|>]*\|>'), '')
        .replaceAll(RegExp(r'<\|im_end\|>'), '')
        .replaceAll(RegExp(r'</s>'), '')
        .replaceAll(RegExp(r'<\|endoftext\|>'), '')
        // Remove orphaned punctuation from cleaned content
        .replaceAll(RegExp(r'^\s*[:\}\{\]\[]+\s*', multiLine: true), '')
        .replaceAll(RegExp(r'\s*[:\}\{\]\[]+\s*$', multiLine: true), '')
        // Remove standalone single characters that are JSON artifacts
        .replaceAll(RegExp(r'^\s*[\{\}\[\]:,]+\s*$', multiLine: true), '')
        // Clean up excessive whitespace
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'^\s*\n', multiLine: true), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // If response is empty after cleaning, provide fallback
    if (cleaned.isEmpty || cleaned.length < 3) {
      return "I'm listening! How can I help you?";
    }
    return cleaned;
  }

  void _updateMsg(String id, String content, {required bool loading}) {
    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      _messages[i] = _messages[i].copyWith(
        content: content.isEmpty ? '...' : content,
        isLoading: loading,
      );
      notifyListeners();
    }
  }

  Future<void> processPhoto(String path) async {
    if (!_ready || _generating) return;

    _generating = true;

    final userMsgId = _uuid.v4();
    final assistantMsgId = _uuid.v4();

    // Add user message with image
    _messages.add(ChatMessageModel(
      id: userMsgId,
      content: 'Loading vision model...',
      isUser: true,
      imageUrl: path,
    ));

    // Add assistant placeholder
    _messages.add(ChatMessageModel(
      id: assistantMsgId,
      content: '',
      isUser: false,
      isLoading: true,
    ));

    notifyListeners();

    try {
      // Update status
      _updateUserMsg(userMsgId, 'Analyzing image...');

      final desc = await _memory.ingestPhoto(path);

      // Update user message
      _updateUserMsg(userMsgId, 'Photo');

      // Update assistant response
      _updateMsg(assistantMsgId, 'I see: $desc\n\nI\'ve saved this to memory.', loading: false);

      debugPrint('Photo processed and stored');
    } catch (e) {
      debugPrint('Error processing photo: $e');
      _updateUserMsg(userMsgId, 'Photo (failed)');
      _updateMsg(assistantMsgId, 'Sorry, I couldn\'t analyze the image: $e', loading: false);
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  void _updateUserMsg(String id, String content) {
    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      _messages[i] = _messages[i].copyWith(content: content);
      notifyListeners();
    }
  }

  Future<void> processVoice(String path) async {
    if (!_ready || _generating) return;

    _generating = true;

    final id = _uuid.v4();
    _messages.add(ChatMessageModel(id: id, content: 'Loading speech model...', isUser: true));
    notifyListeners();

    try {
      _updateUserMsg(id, 'Transcribing...');

      final text = await _memory.ingestVoice(path);
      _updateUserMsg(id, '"$text"');

      _generating = false;
      notifyListeners();

      // Send transcribed text as a message
      await sendMessage('Voice memo: "$text"');
    } catch (e) {
      debugPrint('Error processing voice: $e');
      _updateUserMsg(id, 'Voice (failed): $e');
      _generating = false;
      notifyListeners();
    }
  }

  void clearChat() {
    _messages.clear();
    _memory.clearHistory();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _memory.clearAll();
    _messages.clear();
    notifyListeners();
  }

  List<SemanticFact> getFacts() => _memory.getAllFacts();
}
