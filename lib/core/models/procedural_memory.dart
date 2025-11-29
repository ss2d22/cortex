import 'dart:math' as math;

/// Types of procedural knowledge
enum ProceduralType {
  preference,    // "User prefers X over Y"
  habit,         // "User usually does X at time Y"
  pattern,       // "When X happens, user tends to Y"
  rule,          // "Always/never do X"
  skill,         // "User knows how to X"
}

/// Confidence level in the learned procedure
enum ConfidenceLevel {
  tentative(0.3),   // Observed once or twice
  emerging(0.5),    // Pattern becoming clear
  established(0.75), // Consistent pattern
  certain(0.95);    // Very reliable

  final double value;
  const ConfidenceLevel(this.value);
}

/// A learned behavioral pattern or preference
class ProceduralMemory {
  final String id;
  final ProceduralType type;
  final String description;      // Natural language description
  final String condition;        // When this applies (e.g., "morning", "work topics")
  final String action;           // What to do (e.g., "be concise", "suggest coffee")
  final DateTime learnedAt;
  final List<String> evidenceIds; // Memory IDs that support this

  // Learning metrics
  int observationCount;
  int successCount;        // Times this pattern was confirmed
  int failureCount;        // Times this pattern was violated
  DateTime lastObservedAt;
  ConfidenceLevel confidence;

  // Decay tracking
  static const double _decayRatePerDay = 0.02; // 2% decay per day without reinforcement

  ProceduralMemory({
    required this.id,
    required this.type,
    required this.description,
    required this.condition,
    required this.action,
    required this.learnedAt,
    this.evidenceIds = const [],
    this.observationCount = 1,
    this.successCount = 0,
    this.failureCount = 0,
    DateTime? lastObservedAt,
    this.confidence = ConfidenceLevel.tentative,
  }) : lastObservedAt = lastObservedAt ?? learnedAt;

  /// Calculate current confidence with decay
  double get currentConfidence {
    final daysSinceObserved = DateTime.now().difference(lastObservedAt).inHours / 24.0;
    final decayFactor = math.exp(-_decayRatePerDay * daysSinceObserved);

    // Base confidence from observations
    final successRate = observationCount > 0
        ? successCount / observationCount
        : 0.5;

    return math.min(1.0, confidence.value * decayFactor * (0.5 + successRate * 0.5));
  }

  /// Reliability score (how often this pattern holds true)
  double get reliability {
    final total = successCount + failureCount;
    if (total == 0) return 0.5; // Unknown
    return successCount / total;
  }

  /// Reinforce the pattern (observed again)
  void reinforce({bool success = true}) {
    observationCount++;
    lastObservedAt = DateTime.now();

    if (success) {
      successCount++;
      // Upgrade confidence level based on observation count
      if (confidence == ConfidenceLevel.tentative && observationCount >= 3) {
        confidence = ConfidenceLevel.emerging;
      } else if (confidence == ConfidenceLevel.emerging && observationCount >= 7) {
        confidence = ConfidenceLevel.established;
      } else if (confidence == ConfidenceLevel.established && observationCount >= 15) {
        confidence = ConfidenceLevel.certain;
      }
    } else {
      failureCount++;
      // Downgrade confidence on failures
      if (failureCount > successCount && confidence != ConfidenceLevel.tentative) {
        confidence = ConfidenceLevel.values[confidence.index - 1];
      }
    }
  }

  /// Check if this procedure should be applied given a context
  bool matchesContext(String context) {
    final lowerContext = context.toLowerCase();
    final lowerCondition = condition.toLowerCase();

    // Simple keyword matching for now
    final keywords = lowerCondition.split(RegExp(r'[\s,]+'));
    return keywords.any((kw) => kw.isNotEmpty && lowerContext.contains(kw));
  }

  /// Natural language representation for the LLM
  String get asInstruction {
    switch (type) {
      case ProceduralType.preference:
        return 'The user prefers: $description';
      case ProceduralType.habit:
        return 'User habit: $description';
      case ProceduralType.pattern:
        return 'Pattern observed: When $condition, $action';
      case ProceduralType.rule:
        return 'Important rule: $description';
      case ProceduralType.skill:
        return 'User skill: $description';
    }
  }

  /// Icon for UI display
  String get typeIcon {
    switch (type) {
      case ProceduralType.preference: return '❤️';
      case ProceduralType.habit: return '🔄';
      case ProceduralType.pattern: return '🎯';
      case ProceduralType.rule: return '📋';
      case ProceduralType.skill: return '💡';
    }
  }

  /// Confidence indicator for UI
  String get confidenceIndicator {
    switch (confidence) {
      case ConfidenceLevel.tentative: return '○○○○';
      case ConfidenceLevel.emerging: return '●○○○';
      case ConfidenceLevel.established: return '●●●○';
      case ConfidenceLevel.certain: return '●●●●';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'description': description,
    'condition': condition,
    'action': action,
    'learnedAt': learnedAt.toIso8601String(),
    'evidenceIds': evidenceIds,
    'observationCount': observationCount,
    'successCount': successCount,
    'failureCount': failureCount,
    'lastObservedAt': lastObservedAt.toIso8601String(),
    'confidence': confidence.name,
  };

  factory ProceduralMemory.fromJson(Map<String, dynamic> json) {
    return ProceduralMemory(
      id: json['id'] as String,
      type: ProceduralType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => ProceduralType.pattern,
      ),
      description: json['description'] as String,
      condition: json['condition'] as String? ?? '',
      action: json['action'] as String? ?? '',
      learnedAt: DateTime.parse(json['learnedAt'] as String),
      evidenceIds: (json['evidenceIds'] as List<dynamic>?)?.cast<String>() ?? [],
      observationCount: json['observationCount'] as int? ?? 1,
      successCount: json['successCount'] as int? ?? 0,
      failureCount: json['failureCount'] as int? ?? 0,
      lastObservedAt: json['lastObservedAt'] != null
          ? DateTime.parse(json['lastObservedAt'] as String)
          : null,
      confidence: ConfidenceLevel.values.firstWhere(
        (c) => c.name == json['confidence'],
        orElse: () => ConfidenceLevel.tentative,
      ),
    );
  }

  ProceduralMemory copyWith({
    String? id,
    ProceduralType? type,
    String? description,
    String? condition,
    String? action,
    DateTime? learnedAt,
    List<String>? evidenceIds,
    int? observationCount,
    int? successCount,
    int? failureCount,
    DateTime? lastObservedAt,
    ConfidenceLevel? confidence,
  }) {
    return ProceduralMemory(
      id: id ?? this.id,
      type: type ?? this.type,
      description: description ?? this.description,
      condition: condition ?? this.condition,
      action: action ?? this.action,
      learnedAt: learnedAt ?? this.learnedAt,
      evidenceIds: evidenceIds ?? this.evidenceIds,
      observationCount: observationCount ?? this.observationCount,
      successCount: successCount ?? this.successCount,
      failureCount: failureCount ?? this.failureCount,
      lastObservedAt: lastObservedAt ?? this.lastObservedAt,
      confidence: confidence ?? this.confidence,
    );
  }
}

/// Collection of procedures for a specific context
class ProceduralContext {
  final String name;
  final List<ProceduralMemory> procedures;

  ProceduralContext({
    required this.name,
    required this.procedures,
  });

  /// Get procedures sorted by confidence
  List<ProceduralMemory> get sortedByConfidence {
    final sorted = List<ProceduralMemory>.from(procedures);
    sorted.sort((a, b) => b.currentConfidence.compareTo(a.currentConfidence));
    return sorted;
  }

  /// Get only high-confidence procedures
  List<ProceduralMemory> get reliable {
    return procedures.where((p) => p.currentConfidence >= 0.6).toList();
  }
}
