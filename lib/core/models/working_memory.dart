import 'memory.dart';
import 'semantic_fact.dart';
import 'procedural_memory.dart';

enum WorkingMemorySlotType {
  userStatement,
  relevantEpisode,
  activeFact,
  activeRule,
  conversationTurn,
  goal,
}

class WorkingMemorySlot {
  final String id;
  final WorkingMemorySlotType type;
  final String content;
  final double activation;
  final DateTime addedAt;
  final String? sourceId;

  WorkingMemorySlot({
    required this.id,
    required this.type,
    required this.content,
    this.activation = 1.0,
    DateTime? addedAt,
    this.sourceId,
  }) : addedAt = addedAt ?? DateTime.now();

  double get currentActivation {
    final secondsElapsed = DateTime.now().difference(addedAt).inSeconds;
    final decayFactor = 1.0 / (1.0 + secondsElapsed / 60.0);
    return activation * decayFactor;
  }

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

class WorkingMemory {
  static const int maxSlots = 7;
  static const int maxConversationTurns = 4;

  final List<WorkingMemorySlot> _slots = [];
  String? _currentGoal;
  String? _currentTopic;

  List<WorkingMemorySlot> get slots => List.unmodifiable(_slots);
  List<WorkingMemorySlot> get activeSlots =>
      _slots.where((s) => s.isActive).toList();

  String? get currentGoal => _currentGoal;
  String? get currentTopic => _currentTopic;

  void add(WorkingMemorySlot slot) {
    _slots.removeWhere((s) =>
      s.type == slot.type &&
      s.type != WorkingMemorySlotType.conversationTurn &&
      s.type != WorkingMemorySlotType.relevantEpisode &&
      s.type != WorkingMemorySlotType.activeFact
    );

    _slots.add(slot);
    _enforceCapacity();
  }

  void setUserStatement(String statement) {
    _slots.removeWhere((s) => s.type == WorkingMemorySlotType.userStatement);
    add(WorkingMemorySlot(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      type: WorkingMemorySlotType.userStatement,
      content: statement,
      activation: 1.0,
    ));
  }

  void setGoal(String goal) {
    _currentGoal = goal;
    add(WorkingMemorySlot(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      type: WorkingMemorySlotType.goal,
      content: goal,
      activation: 0.9,
    ));
  }

  void setTopic(String topic) {
    _currentTopic = topic;
  }

  void addEpisode(EpisodicMemory episode, {double relevance = 0.5}) {
    add(WorkingMemorySlot(
      id: 'ep_${episode.id}',
      type: WorkingMemorySlotType.relevantEpisode,
      content: episode.content,
      activation: relevance * episode.strength,
      sourceId: episode.id,
    ));
  }

  void addFact(SemanticFact fact, {double relevance = 0.5}) {
    add(WorkingMemorySlot(
      id: 'fact_${fact.id}',
      type: WorkingMemorySlotType.activeFact,
      content: fact.asNaturalLanguage,
      activation: relevance * fact.confidence,
      sourceId: fact.id,
    ));
  }

  void addRule(ProceduralMemory rule, {double relevance = 0.5}) {
    add(WorkingMemorySlot(
      id: 'rule_${rule.id}',
      type: WorkingMemorySlotType.activeRule,
      content: rule.asInstruction,
      activation: relevance * rule.currentConfidence,
      sourceId: rule.id,
    ));
  }

  void addConversationTurn(String role, String content) {
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

  void _enforceCapacity() {
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

  void prune() {
    _slots.removeWhere((s) => !s.isActive);
  }

  void clear() {
    _slots.clear();
    _currentGoal = null;
    _currentTopic = null;
  }

  String buildContextPrompt() {
    final buffer = StringBuffer();
    final active = activeSlots;

    final facts = active.where((s) => s.type == WorkingMemorySlotType.activeFact);
    final episodes = active.where((s) => s.type == WorkingMemorySlotType.relevantEpisode);
    final rules = active.where((s) => s.type == WorkingMemorySlotType.activeRule);

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

  String get loadIndicator {
    final load = activeSlots.length / maxSlots;
    if (load < 0.3) return '▁▁▁';
    if (load < 0.5) return '▂▂▁';
    if (load < 0.7) return '▄▄▂';
    if (load < 0.9) return '▆▆▄';
    return '█▆▆';
  }
}

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
