import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart';
import '../../shared/constants.dart';

/// Progress callback for model downloads
typedef ProgressCallback = void Function(
  String model,
  double progress,
  String status,
);

/// Manages all Cactus SDK instances (LLM, STT, RAG, Vision)
/// Implements lazy loading to minimize memory footprint
class CactusService extends ChangeNotifier {
  // Primary instances
  CactusLM? _primaryLM;
  CactusLM? _embeddingLM;
  CactusRAG? _rag;

  // Lazy-loaded instances
  CactusLM? _visionLM;
  CactusSTT? _stt;

  // State tracking
  bool _primaryInitialized = false;
  bool _embeddingInitialized = false;
  bool _ragInitialized = false;
  bool _visionInitialized = false;
  bool _sttInitialized = false;

  // Currently active model (for model switching)
  String? _activeModel;

  // Progress callback
  ProgressCallback? onProgress;

  /// Get the currently active model name
  String? get activeModel => _activeModel;

  // Getters for state
  bool get isReady => _primaryInitialized && _ragInitialized;
  bool get isPrimaryReady => _primaryInitialized;
  bool get isEmbeddingReady => _embeddingInitialized;
  bool get isRagReady => _ragInitialized;
  bool get isVisionReady => _visionInitialized;
  bool get isSttReady => _sttInitialized;

  CactusLM get primaryLM {
    if (_primaryLM == null || !_primaryInitialized) {
      throw StateError('Primary LM not initialized. Call initialize() first.');
    }
    return _primaryLM!;
  }

  CactusRAG get rag {
    if (_rag == null || !_ragInitialized) {
      throw StateError('RAG not initialized. Call initialize() first.');
    }
    return _rag!;
  }

  /// Initialize the core services (Primary LLM + Embedding + RAG)
  Future<void> initialize() async {
    if (isReady) return;

    try {
      // Step 1: Download and initialize primary model
      await _initializePrimaryLM();

      // Step 2: Download and initialize embedding model
      await _initializeEmbeddingLM();

      // Step 3: Initialize RAG with embedding generator
      await _initializeRAG();

      debugPrint('CactusService fully initialized');
    } catch (e) {
      debugPrint('CactusService initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _initializePrimaryLM() async {
    _primaryLM = CactusLM(enableToolFiltering: true);

    onProgress?.call(AppConstants.primaryModel, 0, 'Downloading primary model...');

    await _primaryLM!.downloadModel(
      model: AppConstants.primaryModel,
      downloadProcessCallback: (progress, status, isError) {
        if (!isError) {
          onProgress?.call(AppConstants.primaryModel, progress ?? 0, status);
        } else {
          debugPrint('Primary model download error: $status');
        }
      },
    );

    onProgress?.call(AppConstants.primaryModel, 1.0, 'Initializing primary model...');

    await _primaryLM!.initializeModel(
      params: CactusInitParams(
        model: AppConstants.primaryModel,
        contextSize: AppConstants.contextSize,
      ),
    );

    _primaryInitialized = true;
    _activeModel = AppConstants.primaryModel;
    debugPrint('Primary LM initialized: ${AppConstants.primaryModel}');
  }

  Future<void> _initializeEmbeddingLM() async {
    _embeddingLM = CactusLM();

    onProgress?.call(AppConstants.embeddingModel, 0, 'Downloading embedding model...');

    await _embeddingLM!.downloadModel(
      model: AppConstants.embeddingModel,
      downloadProcessCallback: (progress, status, isError) {
        if (!isError) {
          onProgress?.call(AppConstants.embeddingModel, progress ?? 0, status);
        } else {
          debugPrint('Embedding model download error: $status');
        }
      },
    );

    onProgress?.call(AppConstants.embeddingModel, 1.0, 'Initializing embedding model...');

    await _embeddingLM!.initializeModel(
      params: CactusInitParams(model: AppConstants.embeddingModel),
    );

    _embeddingInitialized = true;
    debugPrint('Embedding LM initialized: ${AppConstants.embeddingModel}');
  }

  Future<void> _initializeRAG() async {
    _rag = CactusRAG();

    onProgress?.call('RAG', 0.5, 'Initializing memory database...');

    await _rag!.initialize();

    // Use dedicated embedding model for higher quality vectors
    _rag!.setEmbeddingGenerator((text) async {
      if (!_embeddingInitialized || _embeddingLM == null) {
        throw StateError('Embedding model not initialized');
      }
      final result = await _embeddingLM!.generateEmbedding(text: text);
      return result.embeddings;
    });

    _rag!.setChunking(
      chunkSize: AppConstants.chunkSize,
      chunkOverlap: AppConstants.chunkOverlap,
    );

    _ragInitialized = true;
    onProgress?.call('RAG', 1.0, 'Memory database ready');
    debugPrint('RAG initialized with dedicated embedding model');
  }

  /// Generate embedding using dedicated embedding model
  Future<List<double>> generateEmbedding(String text) async {
    if (!_embeddingInitialized || _embeddingLM == null) {
      throw StateError('Embedding model not initialized');
    }
    final result = await _embeddingLM!.generateEmbedding(text: text);
    return result.embeddings;
  }

  /// Generate completion using primary model
  Future<CactusCompletionResult> generateCompletion({
    required List<ChatMessage> messages,
    CactusCompletionParams? params,
  }) async {
    if (!_primaryInitialized || _primaryLM == null) {
      throw StateError('Primary LM not initialized');
    }
    return await _primaryLM!.generateCompletion(
      messages: messages,
      params: params,
    );
  }

  /// Generate streaming completion using primary model
  Future<CactusStreamedCompletionResult> generateCompletionStream({
    required List<ChatMessage> messages,
    CactusCompletionParams? params,
  }) async {
    if (!_primaryInitialized || _primaryLM == null) {
      throw StateError('Primary LM not initialized');
    }
    return await _primaryLM!.generateCompletionStream(
      messages: messages,
      params: params,
    );
  }

  /// Lazy load vision model for photo analysis
  /// This unloads the primary model temporarily to save memory
  Future<CactusLM> getVisionLM() async {
    if (_visionInitialized && _visionLM != null) {
      return _visionLM!;
    }

    // Unload primary LM to free memory
    if (_primaryLM != null && _primaryInitialized) {
      try {
        _primaryLM!.unload();
        debugPrint('Primary LM unloaded for vision');
      } catch (e) {
        debugPrint('Error unloading primary LM: $e');
      }
      _primaryInitialized = false;
    }

    await Future.delayed(const Duration(milliseconds: 500));

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
      params: CactusInitParams(model: AppConstants.visionModel),
    );

    _visionInitialized = true;
    _activeModel = AppConstants.visionModel;
    debugPrint('Vision LM initialized: ${AppConstants.visionModel}');

    return _visionLM!;
  }

  /// Restore primary model after vision use
  Future<void> restorePrimaryLM() async {
    if (_visionLM != null && _visionInitialized) {
      try {
        _visionLM!.unload();
        debugPrint('Vision LM unloaded');
      } catch (e) {
        debugPrint('Error unloading vision LM: $e');
      }
      _visionInitialized = false;
      _visionLM = null;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    // Reinitialize primary LM
    _primaryLM = CactusLM(enableToolFiltering: true);

    int retries = 0;
    while (retries < 3) {
      try {
        await _primaryLM!.initializeModel(
          params: CactusInitParams(
            model: AppConstants.primaryModel,
            contextSize: AppConstants.contextSize,
          ),
        );
        _primaryInitialized = true;
        _activeModel = AppConstants.primaryModel;
        debugPrint('Primary LM restored');
        break;
      } catch (e) {
        retries++;
        if (retries >= 3) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * retries));
        _primaryLM = CactusLM(enableToolFiltering: true);
      }
    }
  }

  /// Lazy load STT model for voice transcription
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
    debugPrint('STT initialized: ${AppConstants.sttModel}');

    return _stt!;
  }

  /// Unload STT to free memory
  void unloadSTT() {
    if (_stt != null && _sttInitialized) {
      try {
        _stt!.unload();
        debugPrint('STT unloaded');
      } catch (e) {
        debugPrint('Error unloading STT: $e');
      }
      _sttInitialized = false;
      _stt = null;
    }
  }

  /// Reinitialize primary LM if context fails
  Future<void> reinitializePrimaryLM() async {
    if (_primaryLM != null) {
      try {
        _primaryLM!.unload();
      } catch (e) {
        debugPrint('Error unloading primary LM: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));

    _primaryLM = CactusLM(enableToolFiltering: true);
    await _primaryLM!.initializeModel(
      params: CactusInitParams(
        model: AppConstants.primaryModel,
        contextSize: AppConstants.contextSize,
      ),
    );
    _primaryInitialized = true;
    _activeModel = AppConstants.primaryModel;
    debugPrint('Primary LM reinitialized');
  }

  @override
  void dispose() {
    if (_primaryLM != null) {
      try {
        _primaryLM!.unload();
      } catch (e) {
        debugPrint('Error unloading primary LM: $e');
      }
    }
    if (_embeddingLM != null) {
      try {
        _embeddingLM!.unload();
      } catch (e) {
        debugPrint('Error unloading embedding LM: $e');
      }
    }
    if (_visionLM != null) {
      try {
        _visionLM!.unload();
      } catch (e) {
        debugPrint('Error unloading vision LM: $e');
      }
    }
    if (_stt != null) {
      try {
        _stt!.unload();
      } catch (e) {
        debugPrint('Error unloading STT: $e');
      }
    }
    if (_rag != null) {
      _rag!.close();
    }
    super.dispose();
  }
}
