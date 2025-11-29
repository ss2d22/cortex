import 'dart:math' as math;

enum ProceduralType {
  preference,
  habit,
  pattern,
  rule,
  skill,
}

enum ConfidenceLevel {
  tentative(0.3),
  emerging(0.5),
  established(0.75),
  certain(0.95);

  final double value;
  const ConfidenceLevel(this.value);
}

class ProceduralMemory {
  final String id;
  final ProceduralType type;
  final String description;
  final String condition;
  final String action;
  final DateTime learnedAt;
  final List<String> evidenceIds;

  int observationCount;
  int successCount;
  int failureCount;
  DateTime lastObservedAt;
  ConfidenceLevel confidence;

  static const double _decayRatePerDay = 0.02;

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

  double get currentConfidence {
    final daysSinceObserved = DateTime.now().difference(lastObservedAt).inHours / 24.0;
    final decayFactor = math.exp(-_decayRatePerDay * daysSinceObserved);

    final successRate = observationCount > 0
        ? successCount / observationCount
        : 0.5;

    return math.min(1.0, confidence.value * decayFactor * (0.5 + successRate * 0.5));
  }

  double get reliability {
    final total = successCount + failureCount;
    if (total == 0) return 0.5;
    return successCount / total;
  }

  void reinforce({bool success = true}) {
    observationCount++;
    lastObservedAt = DateTime.now();

    if (success) {
      successCount++;
      if (confidence == ConfidenceLevel.tentative && observationCount >= 3) {
        confidence = ConfidenceLevel.emerging;
      } else if (confidence == ConfidenceLevel.emerging && observationCount >= 7) {
        confidence = ConfidenceLevel.established;
      } else if (confidence == ConfidenceLevel.established && observationCount >= 15) {
        confidence = ConfidenceLevel.certain;
      }
    } else {
      failureCount++;
      if (failureCount > successCount && confidence != ConfidenceLevel.tentative) {
        confidence = ConfidenceLevel.values[confidence.index - 1];
      }
    }
  }

  bool matchesContext(String context) {
    final lowerContext = context.toLowerCase();
    final lowerCondition = condition.toLowerCase();

    final keywords = lowerCondition.split(RegExp(r'[\s,]+'));
    return keywords.any((kw) => kw.isNotEmpty && lowerContext.contains(kw));
  }

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

  String get typeIcon {
    switch (type) {
      case ProceduralType.preference: return '❤️';
      case ProceduralType.habit: return '🔄';
      case ProceduralType.pattern: return '🎯';
      case ProceduralType.rule: return '📋';
      case ProceduralType.skill: return '💡';
    }
  }

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

class ProceduralContext {
  final String name;
  final List<ProceduralMemory> procedures;

  ProceduralContext({
    required this.name,
    required this.procedures,
  });

  List<ProceduralMemory> get sortedByConfidence {
    final sorted = List<ProceduralMemory>.from(procedures);
    sorted.sort((a, b) => b.currentConfidence.compareTo(a.currentConfidence));
    return sorted;
  }

  List<ProceduralMemory> get reliable {
    return procedures.where((p) => p.currentConfidence >= 0.6).toList();
  }
}
