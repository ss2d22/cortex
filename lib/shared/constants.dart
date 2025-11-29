/// App constants following the Cortex technical architecture plan
class AppConstants {
  // ===== MODEL SELECTION =====
  // Based on technical plan recommendations for optimal performance

  /// Primary LLM for conversation and memory operations
  /// Qwen 3 0.6B: Fast inference, tool calling support, 394 MB
  static const String primaryModel = 'qwen3-0.6';

  /// Dedicated embedding model for higher quality vectors
  /// Nomic Embed V2: 1024-dimensional vectors, 533 MB
  static const String embeddingModel = 'nomic2-embed-300m';

  /// Vision model for photo analysis
  /// LFM 2 VL 450M: Lightweight, good balance of speed/quality, 420 MB
  static const String visionModel = 'lfm2-vl-450m';

  /// Speech-to-text model
  /// Whisper Tiny: Most stable, lightweight, ~75 MB
  /// Note: whisper-small has FFI issues on some devices
  static const String sttModel = 'whisper-tiny';

  // ===== CONTEXT SETTINGS =====

  /// Context size for primary model (tokens)
  static const int contextSize = 2048;

  /// Max tokens for response generation
  static const int maxResponseTokens = 300;

  // ===== MEMORY SETTINGS =====

  /// RAG chunk size for episodic memory storage
  static const int chunkSize = 512;

  /// RAG chunk overlap for context preservation
  static const int chunkOverlap = 64;

  /// Max conversation history turns to include in context
  static const int maxHistoryTurns = 10;

  /// Max episodic memories to retrieve for context
  static const int maxRetrievedMemories = 5;

  /// Max semantic facts to include in context
  static const int maxContextFacts = 15;

  /// Max procedural rules to include in context
  static const int maxContextRules = 5;

  // ===== WORKING MEMORY =====

  /// Miller's Law: 7 +/- 2 items
  static const int workingMemorySlots = 7;

  /// Max conversation turns in working memory
  static const int workingMemoryTurns = 4;

  // ===== DECAY SETTINGS =====

  /// Base half-life for memory decay (hours)
  static const double memoryHalfLifeHours = 24.0;

  /// Access bonus: each access extends half-life by this percentage
  static const double accessBonus = 0.15;

  /// Important memories decay slower by this multiplier
  static const double importanceMultiplier = 2.0;

  // ===== UI SETTINGS =====

  /// Image max dimension for vision processing
  static const int imageMaxDimension = 512;

  /// Image quality for compression (0-100)
  static const int imageQuality = 85;

  /// Max audio recording duration (milliseconds)
  static const int maxAudioDuration = 30000;

  /// Audio sample rate for STT
  static const int audioSampleRate = 16000;
}
