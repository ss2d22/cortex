import 'package:cactus/cactus.dart';
import '../../shared/constants.dart';

typedef ProgressCallback = void Function(String model, double progress, String status);

class CactusService {
  late CactusLM lm;
  CactusLM? _visionLM;
  CactusSTT? _stt;
  late CactusRAG rag;

  bool _initialized = false;
  bool _visionInitialized = false;
  bool _sttInitialized = false;

  bool get isInitialized => _initialized;
  bool get isVisionReady => _visionInitialized;
  bool get isSttReady => _sttInitialized;

  ProgressCallback? onProgress;

  /// Initialize only the main LM and RAG at startup (lighter memory footprint)
  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize main LM only
    lm = CactusLM(enableToolFiltering: true);
    rag = CactusRAG();

    // Download and initialize main model
    await _downloadModel(lm, AppConstants.mainModel);

    onProgress?.call(AppConstants.mainModel, 1.0, 'Initializing main model...');
    await lm.initializeModel(
      params: CactusInitParams(
        model: AppConstants.mainModel,
        contextSize: AppConstants.defaultContextSize,
      ),
    );

    // Initialize RAG
    onProgress?.call('RAG', 1.0, 'Initializing memory database...');
    await rag.initialize();

    // Set embedding generator - uses LOCAL embeddings from main LM
    rag.setEmbeddingGenerator((text) async {
      final result = await lm.generateEmbedding(text: text);
      return result.embeddings;
    });

    rag.setChunking(
      chunkSize: AppConstants.chunkSize,
      chunkOverlap: AppConstants.chunkOverlap,
    );

    _initialized = true;
  }

  /// Lazy load vision model only when needed (for photo analysis)
  Future<CactusLM> getVisionLM() async {
    if (_visionInitialized && _visionLM != null) {
      return _visionLM!;
    }

    // Unload main LM to free memory before loading vision
    lm.unload();

    _visionLM = CactusLM();

    await _visionLM!.downloadModel(
      model: AppConstants.visionModel,
      downloadProcessCallback: (progress, status, isError) {
        if (!isError) {
          onProgress?.call(AppConstants.visionModel, progress ?? 0, status);
        }
      },
    );

    await _visionLM!.initializeModel(
      params: CactusInitParams(
        model: AppConstants.visionModel,
        contextSize: AppConstants.defaultContextSize,
      ),
    );

    _visionInitialized = true;
    return _visionLM!;
  }

  /// Switch back to main LM after using vision
  Future<void> restoreMainLM() async {
    if (_visionLM != null && _visionInitialized) {
      _visionLM!.unload();
      _visionInitialized = false;
      _visionLM = null;
    }

    // Re-initialize main LM
    await lm.initializeModel(
      params: CactusInitParams(
        model: AppConstants.mainModel,
        contextSize: AppConstants.defaultContextSize,
      ),
    );
  }

  /// Lazy load STT model only when needed (for voice transcription)
  Future<CactusSTT> getSTT() async {
    if (_sttInitialized && _stt != null) {
      return _stt!;
    }

    _stt = CactusSTT();

    await _stt!.downloadModel(
      model: AppConstants.sttModel,
      downloadProcessCallback: (progress, status, isError) {
        if (!isError) {
          onProgress?.call(AppConstants.sttModel, progress ?? 0, status);
        }
      },
    );

    await _stt!.initializeModel(
      params: CactusInitParams(model: AppConstants.sttModel),
    );

    _sttInitialized = true;
    return _stt!;
  }

  /// Unload STT to free memory
  void unloadSTT() {
    if (_stt != null && _sttInitialized) {
      _stt!.unload();
      _sttInitialized = false;
      _stt = null;
    }
  }

  Future<void> _downloadModel(CactusLM model, String modelName) async {
    await model.downloadModel(
      model: modelName,
      downloadProcessCallback: (progress, status, isError) {
        if (!isError) {
          onProgress?.call(modelName, progress ?? 0, status);
        }
      },
    );
  }

  void dispose() {
    if (_initialized) {
      lm.unload();
      rag.close();
    }
    if (_visionLM != null) {
      _visionLM!.unload();
    }
    if (_stt != null) {
      _stt!.unload();
    }
  }
}
