import 'dart:convert';
import 'dart:math' as math;

enum MemorySource { conversation, voice, photo, note, explicit }

enum ImportanceLevel {
  low(0.3),
  medium(0.5),
  high(0.8),
  critical(1.0);

  final double value;
  const ImportanceLevel(this.value);
}

/// Emotional valence for memory coloring
enum EmotionalValence {
  positive(1.0),
  neutral(0.0),
  negative(-1.0);

  final double value;
  const EmotionalValence(this.value);
}

/// Consolidation state - memories strengthen over time through rehearsal
enum ConsolidationState {
  shortTerm,   // Fresh, vulnerable to decay
  consolidating, // Being strengthened
  longTerm,    // Stable, resistant to decay
}

/// Enhanced Episodic Memory with human-like decay and strengthening
class EpisodicMemory {
  final String id;
  final String content;
  final DateTime timestamp;
  final MemorySource source;
  final double importance;
  final List<String> emotionalTags;
  final EmotionalValence valence;

  // Access tracking
  int accessCount;
  DateTime lastAccessedAt;

  // Consolidation
  ConsolidationState consolidationState;
  int rehearsalCount;

  // Decay constants (in hours)
  static const double _halfLifeBase = 24.0; // Base half-life in hours
  static const double _accessBonus = 0.15; // Each access extends half-life by 15%
  static const double _importanceMultiplier = 2.0; // Important memories decay slower

  EpisodicMemory({
    required this.id,
    required this.content,
    required this.timestamp,
    required this.source,
    this.importance = 0.5,
    this.accessCount = 0,
    DateTime? lastAccessedAt,
    this.emotionalTags = const [],
    this.valence = EmotionalValence.neutral,
    this.consolidationState = ConsolidationState.shortTerm,
    this.rehearsalCount = 0,
  }) : lastAccessedAt = lastAccessedAt ?? timestamp;

  /// Calculate memory decay based on Ebbinghaus forgetting curve
  /// Returns value between 0 (forgotten) and 1 (fresh)
  double get decayScore {
    final now = DateTime.now();
    final hoursSinceCreation = now.difference(timestamp).inMinutes / 60.0;
    final hoursSinceAccess = now.difference(lastAccessedAt).inMinutes / 60.0;

    // Calculate effective half-life based on access patterns and importance
    final accessMultiplier = 1.0 + (accessCount * _accessBonus);
    final importanceBonus = importance * _importanceMultiplier;
    final consolidationBonus = consolidationState == ConsolidationState.longTerm
        ? 3.0
        : (consolidationState == ConsolidationState.consolidating ? 1.5 : 1.0);

    final effectiveHalfLife = _halfLifeBase * accessMultiplier * importanceBonus * consolidationBonus;

    // Use time since last access for recency bonus
    final recencyWeight = math.exp(-hoursSinceAccess / (effectiveHalfLife * 0.5));

    // Ebbinghaus forgetting curve: R = e^(-t/S) where S is stability
    final retention = math.exp(-hoursSinceCreation / effectiveHalfLife);

    // Combine retention with recency (recently accessed memories feel stronger)
    return math.min(1.0, retention * 0.7 + recencyWeight * 0.3);
  }

  /// Overall memory strength combining importance, decay, and access frequency
  /// This is the primary metric for retrieval ranking
  double get strength {
    final accessBonus = math.log(accessCount + 1) / math.log(10); // log10(accessCount + 1)
    final emotionalBonus = valence != EmotionalValence.neutral ? 0.1 : 0.0;

    return math.min(1.0,
      importance * 0.4 +           // Base importance
      decayScore * 0.35 +          // Time-based decay
      accessBonus * 0.15 +         // Access frequency bonus
      emotionalBonus * 0.1         // Emotional salience
    );
  }

  /// Mark memory as accessed, updating tracking
  void recordAccess() {
    accessCount++;
    lastAccessedAt = DateTime.now();

    // Progress consolidation based on access patterns
    if (consolidationState == ConsolidationState.shortTerm && accessCount >= 3) {
      consolidationState = ConsolidationState.consolidating;
    } else if (consolidationState == ConsolidationState.consolidating && accessCount >= 7) {
      consolidationState = ConsolidationState.longTerm;
    }
  }

  /// Rehearse memory (strengthens consolidation without full access)
  void rehearse() {
    rehearsalCount++;
    if (rehearsalCount >= 5 && consolidationState == ConsolidationState.shortTerm) {
      consolidationState = ConsolidationState.consolidating;
    }
  }

  /// Get human-readable age string
  String get ageDescription {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  /// Get strength description for UI
  String get strengthDescription {
    final s = strength;
    if (s >= 0.8) return 'Very Strong';
    if (s >= 0.6) return 'Strong';
    if (s >= 0.4) return 'Moderate';
    if (s >= 0.2) return 'Weak';
    return 'Fading';
  }

  /// Icon for memory source
  String get sourceIcon {
    switch (source) {
      case MemorySource.conversation: return '💬';
      case MemorySource.voice: return '🎙️';
      case MemorySource.photo: return '📷';
      case MemorySource.note: return '📝';
      case MemorySource.explicit: return '📌';
    }
  }

  Map<String, dynamic> toMetadata() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'source': source.name,
    'importance': importance,
    'accessCount': accessCount,
    'lastAccessedAt': lastAccessedAt.toIso8601String(),
    'emotionalTags': emotionalTags,
    'valence': valence.name,
    'consolidationState': consolidationState.name,
    'rehearsalCount': rehearsalCount,
  };

  String toStorageFormat() =>
    '$content\n\n---CORTEX_META---\n${jsonEncode(toMetadata())}';

  static String extractContent(String stored) {
    final parts = stored.split('---CORTEX_META---');
    return parts[0].trim();
  }

  static Map<String, dynamic>? extractMetadata(String stored) {
    final parts = stored.split('---CORTEX_META---');
    if (parts.length < 2) return null;
    try {
      return jsonDecode(parts[1].trim()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  factory EpisodicMemory.fromStorageFormat(String stored) {
    final content = extractContent(stored);
    final meta = extractMetadata(stored);

    if (meta == null) {
      return EpisodicMemory(
        id: 'recovered_${DateTime.now().millisecondsSinceEpoch}',
        content: content,
        timestamp: DateTime.now(),
        source: MemorySource.conversation,
      );
    }

    return EpisodicMemory(
      id: meta['id'] as String,
      content: content,
      timestamp: DateTime.parse(meta['timestamp'] as String),
      source: MemorySource.values.firstWhere(
        (s) => s.name == meta['source'],
        orElse: () => MemorySource.conversation,
      ),
      importance: (meta['importance'] as num?)?.toDouble() ?? 0.5,
      accessCount: meta['accessCount'] as int? ?? 0,
      lastAccessedAt: meta['lastAccessedAt'] != null
          ? DateTime.parse(meta['lastAccessedAt'] as String)
          : null,
      emotionalTags: (meta['emotionalTags'] as List<dynamic>?)?.cast<String>() ?? [],
      valence: EmotionalValence.values.firstWhere(
        (v) => v.name == meta['valence'],
        orElse: () => EmotionalValence.neutral,
      ),
      consolidationState: ConsolidationState.values.firstWhere(
        (c) => c.name == meta['consolidationState'],
        orElse: () => ConsolidationState.shortTerm,
      ),
      rehearsalCount: meta['rehearsalCount'] as int? ?? 0,
    );
  }

  EpisodicMemory copyWith({
    String? id,
    String? content,
    DateTime? timestamp,
    MemorySource? source,
    double? importance,
    int? accessCount,
    DateTime? lastAccessedAt,
    List<String>? emotionalTags,
    EmotionalValence? valence,
    ConsolidationState? consolidationState,
    int? rehearsalCount,
  }) {
    return EpisodicMemory(
      id: id ?? this.id,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      source: source ?? this.source,
      importance: importance ?? this.importance,
      accessCount: accessCount ?? this.accessCount,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      emotionalTags: emotionalTags ?? this.emotionalTags,
      valence: valence ?? this.valence,
      consolidationState: consolidationState ?? this.consolidationState,
      rehearsalCount: rehearsalCount ?? this.rehearsalCount,
    );
  }
}
