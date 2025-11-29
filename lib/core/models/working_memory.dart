import 'memory.dart';
import 'semantic_fact.dart';
import 'procedural_memory.dart';

/// Slot types in working memory
enum WorkingMemorySlotType {
  userStatement,      // Current user input
  relevantEpisode,    // Retrieved episodic memory
  activeFact,         // Active semantic fact
  activeRule,         // Active procedural rule
  conversationTurn,   // Recent conversation context
  goal,               // Current conversation goal
}

/// A single item in working memory with activation level
class WorkingMemorySlot {
  final String id;
  final WorkingMemorySlotType type;
  final String content;
  final double activation;        // How "hot" this item is (0-1)
  final DateTime addedAt;
  final String? sourceId;         // ID of source memory if applicable

  WorkingMemorySlot({
    required this.id,
    required this.type,
    required this.content,
    this.activation = 1.0,
    DateTime? addedAt,
    this.sourceId,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Decay activation over time (items fade from working memory)
  double get currentActivation {
    final secondsElapsed = DateTime.now().difference(addedAt).inSeconds;
    // Rapid decay - items fade in minutes, not hours
    final decayFactor = 1.0 / (1.0 + secondsElapsed / 60.0);
    return activation * decayFactor;
  }

  /// Check if still active enough to include
  bool get isActive => currentActivation > 0.1;

  WorkingMemorySlot withActivation(double newActivation) {
    return WorkingMemorySlot(
      id: id,
      type: type,
      content: content,
      activation: newActivation,
      addedAt: addedAt,
      sourceId: sourceId,
    );
  }
}

/// Dynamic working memory that combines all memory types for context
class WorkingMemory {
  static const int maxSlots = 7; // Miller's Law: 7 +/- 2 items
  static const int maxConversationTurns = 4;

  final List<WorkingMemorySlot> _slots = [];
  String? _currentGoal;
  String? _currentTopic;

  List<WorkingMemorySlot> get slots => List.unmodifiable(_slots);
  List<WorkingMemorySlot> get activeSlots =>
      _slots.where((s) => s.isActive).toList();

  String? get currentGoal => _currentGoal;
  String? get currentTopic => _currentTopic;

  /// Add a new item to working memory
  void add(WorkingMemorySlot slot) {
    // Remove old item of same type if exists
    _slots.removeWhere((s) =>
      s.type == slot.type &&
      s.type != WorkingMemorySlotType.conversationTurn &&
      s.type != WorkingMemorySlotType.relevantEpisode &&
      s.type != WorkingMemorySlotType.activeFact
    );

    _slots.add(slot);
    _enforceCapacity();
  }

  /// Add user's current statement
  void setUserStatement(String statement) {
    _slots.removeWhere((s) => s.type == WorkingMemorySlotType.userStatement);
    add(WorkingMemorySlot(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      type: WorkingMemorySlotType.userStatement,
      content: statement,
      activation: 1.0,
    ));
  }

  /// Set current conversation goal
  void setGoal(String goal) {
    _currentGoal = goal;
    add(WorkingMemorySlot(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      type: WorkingMemorySlotType.goal,
      content: goal,
      activation: 0.9,
    ));
  }

  /// Update detected topic
  void setTopic(String topic) {
    _currentTopic = topic;
  }

  /// Add relevant episodic memory
  void addEpisode(EpisodicMemory episode, {double relevance = 0.5}) {
    add(WorkingMemorySlot(
      id: 'ep_${episode.id}',
      type: WorkingMemorySlotType.relevantEpisode,
      content: episode.content,
      activation: relevance * episode.strength,
      sourceId: episode.id,
    ));
  }

  /// Add active semantic fact
  void addFact(SemanticFact fact, {double relevance = 0.5}) {
    add(WorkingMemorySlot(
      id: 'fact_${fact.id}',
      type: WorkingMemorySlotType.activeFact,
      content: fact.asNaturalLanguage,
      activation: relevance * fact.confidence,
      sourceId: fact.id,
    ));
  }

  /// Add active procedural rule
  void addRule(ProceduralMemory rule, {double relevance = 0.5}) {
    add(WorkingMemorySlot(
      id: 'rule_${rule.id}',
      type: WorkingMemorySlotType.activeRule,
      content: rule.asInstruction,
      activation: relevance * rule.currentConfidence,
      sourceId: rule.id,
    ));
  }

  /// Add conversation turn
  void addConversationTurn(String role, String content) {
    // Keep only recent turns
    final turns = _slots.where((s) =>
      s.type == WorkingMemorySlotType.conversationTurn).toList();
    if (turns.length >= maxConversationTurns * 2) {
      _slots.removeWhere((s) =>
        s.type == WorkingMemorySlotType.conversationTurn &&
        s.id == turns.first.id);
    }

    add(WorkingMemorySlot(
      id: 'turn_${DateTime.now().millisecondsSinceEpoch}',
      type: WorkingMemorySlotType.conversationTurn,
      content: '[$role]: $content',
      activation: 0.8,
    ));
  }

  /// Enforce capacity limits (remove least active items)
  void _enforceCapacity() {
    // Don't remove conversation turns or current user statement
    final removable = _slots.where((s) =>
      s.type != WorkingMemorySlotType.conversationTurn &&
      s.type != WorkingMemorySlotType.userStatement &&
      s.type != WorkingMemorySlotType.goal
    ).toList();

    if (removable.length > maxSlots) {
      removable.sort((a, b) => a.currentActivation.compareTo(b.currentActivation));
      final toRemove = removable.take(removable.length - maxSlots).toSet();
      _slots.removeWhere((s) => toRemove.contains(s));
    }
  }

  /// Prune inactive items
  void prune() {
    _slots.removeWhere((s) => !s.isActive);
  }

  /// Clear working memory
  void clear() {
    _slots.clear();
    _currentGoal = null;
    _currentTopic = null;
  }

  /// Build context string for LLM prompt
  String buildContextPrompt() {
    final buffer = StringBuffer();
    final active = activeSlots;

    // Group by type
    final facts = active.where((s) => s.type == WorkingMemorySlotType.activeFact);
    final episodes = active.where((s) => s.type == WorkingMemorySlotType.relevantEpisode);
    final rules = active.where((s) => s.type == WorkingMemorySlotType.activeRule);
    // Conversation turns are included in recent context, not in the prompt

    if (_currentGoal != null) {
      buffer.writeln('## Current Goal');
      buffer.writeln(_currentGoal);
      buffer.writeln();
    }

    if (facts.isNotEmpty) {
      buffer.writeln('## Known Facts');
      for (final f in facts) {
        buffer.writeln('- ${f.content}');
      }
      buffer.writeln();
    }

    if (rules.isNotEmpty) {
      buffer.writeln('## Behavioral Guidelines');
      for (final r in rules) {
        buffer.writeln('- ${r.content}');
      }
      buffer.writeln();
    }

    if (episodes.isNotEmpty) {
      buffer.writeln('## Relevant Memories');
      for (final e in episodes) {
        buffer.writeln('- ${e.content}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Get memory usage stats
  Map<String, int> get stats {
    final active = activeSlots;
    return {
      'total': active.length,
      'facts': active.where((s) => s.type == WorkingMemorySlotType.activeFact).length,
      'episodes': active.where((s) => s.type == WorkingMemorySlotType.relevantEpisode).length,
      'rules': active.where((s) => s.type == WorkingMemorySlotType.activeRule).length,
      'turns': active.where((s) => s.type == WorkingMemorySlotType.conversationTurn).length,
    };
  }

  /// Visual representation of working memory load
  String get loadIndicator {
    final load = activeSlots.length / maxSlots;
    if (load < 0.3) return '▁▁▁';
    if (load < 0.5) return '▂▂▁';
    if (load < 0.7) return '▄▄▂';
    if (load < 0.9) return '▆▆▄';
    return '█▆▆';
  }
}

/// Summary of what's currently in working memory (for UI display)
class WorkingMemorySummary {
  final int totalSlots;
  final int activeFactCount;
  final int activeEpisodeCount;
  final int activeRuleCount;
  final String? currentTopic;
  final String? currentGoal;
  final double memoryLoad;

  WorkingMemorySummary({
    required this.totalSlots,
    required this.activeFactCount,
    required this.activeEpisodeCount,
    required this.activeRuleCount,
    this.currentTopic,
    this.currentGoal,
    required this.memoryLoad,
  });

  factory WorkingMemorySummary.from(WorkingMemory wm) {
    final stats = wm.stats;
    return WorkingMemorySummary(
      totalSlots: stats['total']!,
      activeFactCount: stats['facts']!,
      activeEpisodeCount: stats['episodes']!,
      activeRuleCount: stats['rules']!,
      currentTopic: wm.currentTopic,
      currentGoal: wm.currentGoal,
      memoryLoad: wm.activeSlots.length / WorkingMemory.maxSlots,
    );
  }
}
