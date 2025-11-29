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
      final systemPrompt = '''You are Cortex, a friendly AI assistant with persistent memory. You remember everything the user tells you.

$context

Available tools:
- remember: Store important information (use when user says "remember", "don't forget", or shares personal info)
- recall: Search memories for specific information
- list_facts: List all known facts about the user

Instructions:
- Be conversational and friendly
- Reference known facts naturally in conversation
- When user shares personal info, acknowledge it and use the remember tool
- Keep responses concise''';

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

      final result = await stream.result;
      debugPrint('Response complete. Tool calls: ${result.toolCalls.length}');

      // Handle tool calls
      for (final tc in result.toolCalls) {
        debugPrint('Executing tool: ${tc.name}');
        final toolResult = await _tools.handle(tc);
        if (tc.name == 'recall' || tc.name == 'list_facts') {
          response += '\n\n$toolResult';
        }
      }

      // Clean up response (remove thinking tags if present)
      response = _cleanResponse(response);

      _updateMsg(aId, response, loading: false);

      // Store conversation in memory
      await _memory.storeConversation(text, response);
      debugPrint('Conversation stored in memory');

    } catch (e) {
      debugPrint('Error in sendMessage: $e');
      _updateMsg(aId, 'Error: $e', loading: false);
    } finally {
      _generating = false;
      notifyListeners();
    }
  }

  String _cleanResponse(String response) {
    // Remove thinking tags and clean up
    String cleaned = response
        .replaceAll(RegExp(r'<think>.*?</think>', dotAll: true), '')
        .replaceAll(RegExp(r'<\|im_end\|>'), '')
        .replaceAll(RegExp(r'</s>'), '')
        .trim();
    return cleaned.isEmpty ? response : cleaned;
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
