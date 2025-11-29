import 'package:cactus/cactus.dart';
import '../services/memory_manager.dart';
import '../models/memory.dart';

class ToolHandler {
  final MemoryManager memoryManager;

  ToolHandler(this.memoryManager);

  Future<String> handle(ToolCall call) async {
    switch (call.name) {
      case 'remember':
        final content = call.arguments['content'] ?? '';
        if (content.isEmpty) return 'Nothing to remember.';

        final imp = switch (call.arguments['importance']?.toLowerCase()) {
          'low' => ImportanceLevel.low,
          'medium' => ImportanceLevel.medium,
          'critical' => ImportanceLevel.critical,
          _ => ImportanceLevel.high,
        };

        await memoryManager.rememberExplicitly(content, importance: imp);
        return 'Remembered: "$content"';

      case 'recall':
        final query = call.arguments['query'] ?? '';
        if (query.isEmpty) return 'No search query provided.';
        return await memoryManager.recallMemories(query);

      case 'list_facts':
        final facts = memoryManager.getAllFacts();
        if (facts.isEmpty) return 'No facts stored yet.';
        return memoryManager.getFactsAsContext();

      default:
        return 'Unknown tool: ${call.name}';
    }
  }
}
