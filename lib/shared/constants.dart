class AppConstants {
  // Main chat model - lfm2-700m has tool calling and is memory efficient (467MB)
  // qwen3-1.7 (1161MB) causes out-of-memory on iPhone
  static const String mainModel = 'lfm2-700m';

  // Vision model for photo analysis
  static const String visionModel = 'lfm2-vl-450m';

  // Speech-to-text model
  static const String sttModel = 'whisper-small';

  // Context and memory settings (reduced for mobile memory constraints)
  static const int defaultContextSize = 1024;
  static const int chunkSize = 256;
  static const int chunkOverlap = 32;
  static const int maxConversationHistory = 6;
  static const int maxRetrievedMemories = 3;
}
