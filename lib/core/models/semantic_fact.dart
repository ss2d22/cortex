import 'dart:math' as math;

/// Categories for semantic facts
enum FactCategory {
  identity,      // Name, age, etc.
  work,          // Job, company, career
  relationships, // Family, friends
  preferences,   // Likes, dislikes
  events,        // Birthdays, anniversaries
  location,      // Where they live, from
  health,        // Medical, fitness
  hobbies,       // Interests, activities
  other,         // Uncategorized
}

/// A semantic triple representing a fact about the user
class SemanticFact {
  final String id;
  final String subject;
  final String predicate;
  final String object;
  final DateTime extractedAt;
  final List<String> sourceMemoryIds;
  int reinforceCount;
  DateTime lastReinforcedAt;

  // Contradiction tracking
  bool isContradicted;
  String? contradictedBy;

  SemanticFact({
    required this.id,
    required this.subject,
    required this.predicate,
    required this.object,
    required this.extractedAt,
    List<String>? sourceMemoryIds,
    this.reinforceCount = 1,
    DateTime? lastReinforcedAt,
    this.isContradicted = false,
    this.contradictedBy,
  }) : sourceMemoryIds = sourceMemoryIds ?? [],
       lastReinforcedAt = lastReinforcedAt ?? extractedAt;

  /// Confidence in this fact (0-1) based on reinforcement
  double get confidence {
    if (isContradicted) return 0.1;
    // Logarithmic growth: more reinforcements = higher confidence
    final base = math.min(1.0, 0.5 + (math.log(reinforceCount + 1) / math.log(10)) * 0.25);
    // Decay slightly if not recently reinforced
    final daysSinceReinforced = DateTime.now().difference(lastReinforcedAt).inDays;
    final recencyFactor = 1.0 / (1.0 + daysSinceReinforced * 0.01);
    return base * recencyFactor;
  }

  /// Natural language representation
  String get asNaturalLanguage {
    final verb = predicate.replaceAll('_', ' ');
    return '$subject $verb $object';
  }

  /// Short form for compact display
  String get shortForm {
    return '${predicate.replaceAll('_', ' ')}: $object';
  }

  /// Reinforce this fact (seen again)
  void reinforce() {
    reinforceCount++;
    lastReinforcedAt = DateTime.now();
  }

  /// Mark as contradicted by another fact
  void markContradicted(String newFactId) {
    isContradicted = true;
    contradictedBy = newFactId;
  }

  /// Get category based on predicate
  FactCategory get category {
    final p = predicate.toLowerCase();
    if (['name_is', 'age_is', 'gender_is', 'nickname_is'].contains(p)) {
      return FactCategory.identity;
    }
    if (['works_at', 'job_is', 'role_is', 'company_is', 'profession_is'].contains(p)) {
      return FactCategory.work;
    }
    if (['likes', 'dislikes', 'prefers', 'favorite_is', 'hates'].contains(p)) {
      return FactCategory.preferences;
    }
    if (['lives_in', 'is_from', 'located_in', 'hometown_is'].contains(p)) {
      return FactCategory.location;
    }
    if (['birthday_is', 'anniversary_is', 'graduated_on'].contains(p)) {
      return FactCategory.events;
    }
    if (['married_to', 'has_child', 'sibling_is', 'parent_is', 'friend_is', 'pet_is'].contains(p)) {
      return FactCategory.relationships;
    }
    if (['hobby_is', 'interested_in', 'plays', 'practices'].contains(p)) {
      return FactCategory.hobbies;
    }
    if (['allergic_to', 'condition_is', 'diet_is', 'feels'].contains(p)) {
      return FactCategory.health;
    }
    return FactCategory.other;
  }

  /// Category icon for UI
  String get categoryIcon {
    switch (category) {
      case FactCategory.identity: return '👤';
      case FactCategory.work: return '💼';
      case FactCategory.relationships: return '👥';
      case FactCategory.preferences: return '❤️';
      case FactCategory.events: return '📅';
      case FactCategory.location: return '📍';
      case FactCategory.health: return '🏥';
      case FactCategory.hobbies: return '🎯';
      case FactCategory.other: return '📝';
    }
  }

  /// Confidence indicator for UI
  String get confidenceIndicator {
    final c = confidence;
    if (c >= 0.8) return '●●●●';
    if (c >= 0.6) return '●●●○';
    if (c >= 0.4) return '●●○○';
    if (c >= 0.2) return '●○○○';
    return '○○○○';
  }

  /// Age of fact for display
  String get ageDescription {
    final diff = DateTime.now().difference(extractedAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'subject': subject,
    'predicate': predicate,
    'object': object,
    'extractedAt': extractedAt.toIso8601String(),
    'sourceMemoryIds': sourceMemoryIds,
    'reinforceCount': reinforceCount,
    'lastReinforcedAt': lastReinforcedAt.toIso8601String(),
    'isContradicted': isContradicted,
    'contradictedBy': contradictedBy,
  };

  factory SemanticFact.fromJson(Map<String, dynamic> json) => SemanticFact(
    id: json['id'],
    subject: json['subject'],
    predicate: json['predicate'],
    object: json['object'],
    extractedAt: DateTime.parse(json['extractedAt']),
    sourceMemoryIds: List<String>.from(json['sourceMemoryIds'] ?? []),
    reinforceCount: json['reinforceCount'] ?? 1,
    lastReinforcedAt: json['lastReinforcedAt'] != null
        ? DateTime.parse(json['lastReinforcedAt'])
        : null,
    isContradicted: json['isContradicted'] ?? false,
    contradictedBy: json['contradictedBy'],
  );

  SemanticFact copyWith({
    String? id,
    String? subject,
    String? predicate,
    String? object,
    DateTime? extractedAt,
    List<String>? sourceMemoryIds,
    int? reinforceCount,
    DateTime? lastReinforcedAt,
    bool? isContradicted,
    String? contradictedBy,
  }) {
    return SemanticFact(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      predicate: predicate ?? this.predicate,
      object: object ?? this.object,
      extractedAt: extractedAt ?? this.extractedAt,
      sourceMemoryIds: sourceMemoryIds ?? this.sourceMemoryIds,
      reinforceCount: reinforceCount ?? this.reinforceCount,
      lastReinforcedAt: lastReinforcedAt ?? this.lastReinforcedAt,
      isContradicted: isContradicted ?? this.isContradicted,
      contradictedBy: contradictedBy ?? this.contradictedBy,
    );
  }
}

/// Statistics about semantic memory
class SemanticMemoryStats {
  final int totalFacts;
  final Map<FactCategory, int> factsByCategory;
  final double averageConfidence;
  final int contradictedCount;

  SemanticMemoryStats({
    required this.totalFacts,
    required this.factsByCategory,
    required this.averageConfidence,
    required this.contradictedCount,
  });

  factory SemanticMemoryStats.fromFacts(List<SemanticFact> facts) {
    final byCategory = <FactCategory, int>{};
    double totalConfidence = 0;
    int contradicted = 0;

    for (final fact in facts) {
      byCategory[fact.category] = (byCategory[fact.category] ?? 0) + 1;
      totalConfidence += fact.confidence;
      if (fact.isContradicted) contradicted++;
    }

    return SemanticMemoryStats(
      totalFacts: facts.length,
      factsByCategory: byCategory,
      averageConfidence: facts.isEmpty ? 0 : totalConfidence / facts.length,
      contradictedCount: contradicted,
    );
  }
}
