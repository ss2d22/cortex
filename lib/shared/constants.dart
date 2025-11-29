class AppConstants {
  static const String primaryModel = 'qwen3-0.6';
  static const String embeddingModel = 'nomic2-embed-300m';
  static const String visionModel = 'lfm2-vl-450m';
  static const String sttModel = 'whisper-small';

  static const int contextSize = 2048;
  static const int maxResponseTokens = 300;

  static const int chunkSize = 512;
  static const int chunkOverlap = 64;
  static const int maxHistoryTurns = 10;
  static const int maxRetrievedMemories = 5;
  static const int maxContextFacts = 15;
  static const int maxContextRules = 5;

  static const int workingMemorySlots = 7;
  static const int workingMemoryTurns = 4;

  static const double memoryHalfLifeHours = 24.0;
  static const double accessBonus = 0.15;
  static const double importanceMultiplier = 2.0;

  static const int imageMaxDimension = 512;
  static const int imageQuality = 85;
  static const int maxAudioDuration = 30000;
  static const int audioSampleRate = 16000;
}
