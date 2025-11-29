import 'package:cactus/cactus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/memory.dart';
import '../models/semantic_fact.dart';
import '../models/procedural_memory.dart';
import '../models/working_memory.dart';
import '../../shared/constants.dart';
import 'cactus_service.dart';
import 'persistence_service.dart';

/// Unified memory system with human-inspired cognitive architecture
class MemoryManager {
  final CactusService _cactus;
  final PersistenceService _persistence;
  final _uuid = const Uuid();

  // Memory stores
  final List<SemanticFact> _facts = [];
  final List<ProceduralMemory> _procedures = [];
  final List<EpisodicMemory> _recentEpisodes = []; // In-memory cache
  final List<ChatMessage> _history = [];
  final WorkingMemory _workingMemory = WorkingMemory();

  MemoryManager(this._cactus, this._persistence);

  // Getters
  WorkingMemory get workingMemory => _workingMemory;
  List<SemanticFact> get facts => List.unmodifiable(_facts);
  List<ProceduralMemory> get procedures => List.unmodifiable(_procedures);
  List<EpisodicMemory> get recentEpisodes => List.unmodifiable(_recentEpisodes);

  Future<void> initialize() async {
    final savedFacts = await _persistence.loadFacts();
    _facts.addAll(savedFacts);

    final savedProcedures = await _persistence.loadProcedures();
    _procedures.addAll(savedProcedures);

    debugPrint('MemoryManager initialized: ${_facts.length} facts, ${_procedures.length} procedures');
  }

  //============================================
  // EPISODIC MEMORY (RAG Storage with decay)
  //============================================

  Future<EpisodicMemory> storeEpisodic({
    required String content,
    required MemorySource source,
    double importance = 0.5,
    EmotionalValence valence = EmotionalValence.neutral,
    List<String> emotionalTags = const [],
  }) async {
    final id = 'mem_${_uuid.v4()}';
    final memory = EpisodicMemory(
      id: id,
      content: content,
      timestamp: DateTime.now(),
      source: source,
      importance: importance,
      valence: valence,
      emotionalTags: emotionalTags,
    );

    // Store in RAG for retrieval
    try {
      await _cactus.rag.storeDocument(
        fileName: id,
        filePath: '',
        content: memory.toStorageFormat(),
        fileSize: content.length,
      );
      debugPrint('Stored episodic memory: $id (importance: $importance)');

      // Keep in recent cache
      _recentEpisodes.add(memory);
      if (_recentEpisodes.length > 50) {
        _recentEpisodes.removeAt(0);
      }

      // Extract facts (non-blocking)
      _extractFacts(content, id);

      // Learn procedures (non-blocking)
      _learnProcedures(content, id);
    } catch (e) {
      debugPrint('Error storing episodic memory: $e');
    }

    return memory;
  }

  Future<void> storeConversation(String userMsg, String assistantMsg) async {
    // Determine importance based on content
    final importance = _assessImportance(userMsg);
    final valence = _detectValence(userMsg);

    await storeEpisodic(
      content: 'User: $userMsg\nAssistant: $assistantMsg',
      source: MemorySource.conversation,
      importance: importance,
      valence: valence,
    );

    // Update conversation history
    _history.add(ChatMessage(content: userMsg, role: 'user'));
    _history.add(ChatMessage(content: assistantMsg, role: 'assistant'));

    // Update working memory
    _workingMemory.addConversationTurn('user', userMsg);
    _workingMemory.addConversationTurn('assistant', assistantMsg);

    while (_history.length > AppConstants.maxConversationHistory * 2) {
      _history.removeAt(0);
    }
  }

  double _assessImportance(String text) {
    final lower = text.toLowerCase();
    // High importance triggers
    if (lower.contains('remember') ||
        lower.contains('important') ||
        lower.contains("don't forget") ||
        lower.contains('always') ||
        lower.contains('never')) {
      return 0.8;
    }
    // Personal information
    if (lower.contains('my name') ||
        lower.contains('i am') ||
        lower.contains('i work') ||
        lower.contains('i live')) {
      return 0.7;
    }
    return 0.5;
  }

  EmotionalValence _detectValence(String text) {
    final lower = text.toLowerCase();
    final positive = ['love', 'like', 'happy', 'great', 'awesome', 'thanks', 'good', 'excited'];
    final negative = ['hate', 'dislike', 'sad', 'bad', 'terrible', 'angry', 'frustrated'];

    for (final word in positive) {
      if (lower.contains(word)) return EmotionalValence.positive;
    }
    for (final word in negative) {
      if (lower.contains(word)) return EmotionalValence.negative;
    }
    return EmotionalValence.neutral;
  }

  //============================================
  // VOICE & PHOTO (Lazy-loaded models)
  //============================================

  Future<String> ingestVoice(String audioPath) async {
    final stt = await _cactus.getSTT();

    final result = await stt.transcribe(
      audioFilePath: audioPath,
      prompt: '<|startoftranscript|><|en|><|transcribe|><|notimestamps|>',
    );

    _cactus.unloadSTT();

    if (result.success) {
      await storeEpisodic(
        content: 'Voice memo: ${result.text}',
        source: MemorySource.voice,
        importance: 0.7,
      );
      return result.text;
    }
    throw Exception('Transcription failed');
  }

  Future<String> ingestPhoto(String imagePath) async {
    CactusLM? visionLM;
    try {
      debugPrint('Starting photo analysis for: $imagePath');
      visionLM = await _cactus.getVisionLM();
      debugPrint('Vision LM loaded, generating completion...');

      final result = await visionLM.generateCompletion(
        messages: [
          ChatMessage(
            content: 'You are a helpful AI assistant that can analyze images.',
            role: 'system',
          ),
          ChatMessage(
            content: 'Describe this image briefly.',
            role: 'user',
            images: [imagePath],
          ),
        ],
        params: CactusCompletionParams(maxTokens: 150),
      );

      debugPrint('Vision result: success=${result.success}, response=${result.response}');

      if (result.success && result.response.isNotEmpty) {
        await storeEpisodic(
          content: 'Photo: ${result.response}',
          source: MemorySource.photo,
          importance: 0.6,
        );
        return result.response;
      }
      throw Exception('Vision returned empty response');
    } catch (e) {
      debugPrint('Vision error: $e');
      rethrow;
    } finally {
      // Always restore main LM
      try {
        await _cactus.restoreMainLM();
        debugPrint('Main LM restored after vision');
      } catch (e) {
        debugPrint('Error restoring main LM: $e');
      }
    }
  }

  //============================================
  // SEMANTIC MEMORY (Facts with confidence)
  //============================================

  /// Queue for background extraction
  final List<_ExtractionTask> _extractionQueue = [];
  bool _isExtracting = false;

  Future<void> _extractFacts(String content, String memoryId) async {
    // Extract user message portion
    String userContent = content;
    if (content.startsWith('User:')) {
      final assistantIndex = content.indexOf('Assistant:');
      if (assistantIndex > 0) {
        userContent = content.substring(5, assistantIndex).trim();
      } else {
        userContent = content.substring(5).trim();
      }
    }

    // Skip very short messages
    if (userContent.length < 5) {
      debugPrint('Skipping extraction for short message');
      return;
    }

    // Queue extraction task (will run after current LLM operation completes)
    _extractionQueue.add(_ExtractionTask(userContent, memoryId));
    _processExtractionQueue();
  }

  Future<void> _processExtractionQueue() async {
    if (_isExtracting || _extractionQueue.isEmpty) return;

    _isExtracting = true;

    while (_extractionQueue.isNotEmpty) {
      final task = _extractionQueue.removeAt(0);
      try {
        await _extractWithLLM(task.content, task.memoryId);
      } catch (e) {
        debugPrint('Extraction error: $e');
      }
    }

    _isExtracting = false;
  }

  /// Extract facts using reliable regex patterns (small models can't do structured extraction)
  Future<void> _extractWithLLM(String userMessage, String memoryId) async {
    try {
      debugPrint('Regex extraction for: $userMessage');
      final text = userMessage.toLowerCase();
      int extracted = 0;

      // Normalize smart quotes to regular quotes
      final normalizedText = text.replaceAll(''', "'").replaceAll(''', "'");

      // Name patterns: "I'm [name]", "my name is [name]", "I am [name]"
      final namePatterns = [
        RegExp(r"(?:i'm|i am|my name is|call me)\s+([a-z]{2,15})(?:\s|,|\.|\!|$)", caseSensitive: false),
      ];
      for (final pattern in namePatterns) {
        final match = pattern.firstMatch(normalizedText);
        if (match != null) {
          final name = match.group(1)!.trim();
          // Filter out non-names
          final badWords = ['stressed', 'happy', 'sad', 'tired', 'being', 'going', 'working', 'feeling'];
          if (!badWords.contains(name.toLowerCase())) {
            _addFact('name_is', _capitalize(name), memoryId);
            extracted++;
            break;
          }
        }
      }

      // Company patterns: "work at [company]", "working at [company]"
      final companyMatch = RegExp(r"(?:work(?:ing)?|employed)\s+(?:at|for)\s+([a-z0-9]+)", caseSensitive: false).firstMatch(text);
      if (companyMatch != null) {
        final company = companyMatch.group(1)!.trim();
        if (company.length >= 2) {
          _addFact('works_at', _capitalize(company), memoryId);
          extracted++;
        }
      }

      // Job patterns: "I'm a [job]", "I work as a [job]"
      final jobMatch = RegExp(r"(?:i'm a|i am a|work as a?)\s+([a-z]+(?:\s+[a-z]+)?)", caseSensitive: false).firstMatch(text);
      if (jobMatch != null) {
        final job = jobMatch.group(1)!.trim();
        final badJobs = ['employee', 'worker', 'person'];
        if (!badJobs.contains(job.toLowerCase()) && job.length >= 3) {
          _addFact('job_is', job, memoryId);
          extracted++;
        }
      }

      // Location patterns: "I live in [city]", "I'm from [place]"
      final locationMatch = RegExp(r"(?:live in|from|based in|located in)\s+([a-z]+(?:\s+[a-z]+)?)", caseSensitive: false).firstMatch(text);
      if (locationMatch != null) {
        final location = locationMatch.group(1)!.trim();
        if (location.length >= 2) {
          _addFact('lives_in', _capitalize(location), memoryId);
          extracted++;
        }
      }

      // Emotion patterns: "I'm stressed", "feeling sad", "I feel anxious"
      final emotionPatterns = ['stressed', 'anxious', 'happy', 'sad', 'angry', 'frustrated', 'tired', 'exhausted', 'scared', 'worried', 'overwhelmed', 'depressed'];
      for (final emotion in emotionPatterns) {
        if (text.contains(emotion)) {
          _addFact('feels', emotion, memoryId);
          extracted++;
          break;
        }
      }

      // Boss/abuse patterns
      if (text.contains('boss') && (text.contains('abuse') || text.contains('yell') || text.contains('scream') || text.contains('throw'))) {
        final behaviors = <String>[];
        if (text.contains('abuse')) behaviors.add('abusive');
        if (text.contains('yell') || text.contains('scream')) behaviors.add('yells');
        if (text.contains('throw')) behaviors.add('throws things');
        if (behaviors.isNotEmpty) {
          _addFact('boss_behavior', behaviors.join(', '), memoryId);
          extracted++;
        }
      }

      // Domestic/relationship abuse patterns
      final abuseWords = ['beat', 'hit', 'hurt', 'abuse', 'attack', 'slap', 'punch', 'kick'];
      final relationshipWords = ['wife', 'husband', 'spouse', 'partner', 'boyfriend', 'girlfriend', 'parent', 'father', 'mother', 'dad', 'mom'];
      for (final person in relationshipWords) {
        if (text.contains(person)) {
          for (final abuse in abuseWords) {
            if (text.contains(abuse)) {
              _addFact('abuse_situation', '$person is abusive', memoryId);
              extracted++;
              break;
            }
          }
          break;
        }
      }

      // Age pattern: "I'm [number] years old"
      final ageMatch = RegExp(r"(?:i'm|i am)\s+(\d{1,3})\s*(?:years?\s*old)?", caseSensitive: false).firstMatch(text);
      if (ageMatch != null) {
        final age = int.tryParse(ageMatch.group(1)!);
        if (age != null && age > 0 && age < 120) {
          _addFact('age_is', age.toString(), memoryId);
          extracted++;
        }
      }

      // Save facts
      if (extracted > 0) {
        await _persistence.saveFacts(_facts);
        debugPrint('Extracted $extracted facts, total: ${_facts.length}');
      } else {
        debugPrint('No facts extracted from message');
      }
    } catch (e) {
      debugPrint('Extraction error: $e');
    }
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  void _addFact(String predicate, String value, String memoryId) {
    _addOrUpdateFact(SemanticFact(
      id: 'fact_${_uuid.v4()}',
      subject: 'User',
      predicate: predicate,
      object: value,
      extractedAt: DateTime.now(),
      sourceMemoryIds: [memoryId],
    ));
    debugPrint('Extracted: $predicate = $value');
  }

  void _addOrUpdateFact(SemanticFact newFact) {
    // Check for existing fact with same subject+predicate
    final existingIndex = _facts.indexWhere(
      (f) => f.subject.toLowerCase() == newFact.subject.toLowerCase() &&
             f.predicate == newFact.predicate,
    );

    if (existingIndex != -1) {
      final existing = _facts[existingIndex];
      if (existing.object.toLowerCase() == newFact.object.toLowerCase()) {
        // Same fact - reinforce
        existing.reinforce();
        debugPrint('Reinforced fact: ${newFact.asNaturalLanguage}');
      } else {
        // Contradiction - mark old as contradicted, add new
        existing.markContradicted(newFact.id);
        _facts.add(newFact);
        debugPrint('Updated fact (contradiction): ${existing.asNaturalLanguage} -> ${newFact.asNaturalLanguage}');
      }
    } else {
      _facts.add(newFact);
      debugPrint('Added new fact: ${newFact.asNaturalLanguage}');
    }
  }

  List<SemanticFact> getAllFacts() => List.unmodifiable(
    _facts.where((f) => !f.isContradicted).toList()
  );

  List<SemanticFact> getFactsByCategory(FactCategory category) =>
    _facts.where((f) => f.category == category && !f.isContradicted).toList();

  String getFactsAsContext() {
    final activeFacts = getAllFacts().toList(); // Create modifiable copy
    if (activeFacts.isEmpty) return 'No facts known yet.';

    // Sort by confidence and group by category
    activeFacts.sort((a, b) => b.confidence.compareTo(a.confidence));
    return activeFacts.take(10).map((f) => '- ${f.asNaturalLanguage}').join('\n');
  }

  SemanticMemoryStats getSemanticStats() => SemanticMemoryStats.fromFacts(_facts);

  //============================================
  // PROCEDURAL MEMORY (Learned patterns)
  //============================================

  Future<void> _learnProcedures(String content, String memoryId) async {
    try {
      // Extract user message portion
      String userContent = content;
      if (content.startsWith('User:')) {
        final assistantIndex = content.indexOf('Assistant:');
        if (assistantIndex > 0) {
          userContent = content.substring(5, assistantIndex).trim();
        } else {
          userContent = content.substring(5).trim();
        }
      }

      // Use regex-based extraction (more reliable than small LLM)
      _extractProceduresWithRegex(userContent, memoryId);

      if (_procedures.isNotEmpty) {
        await _persistence.saveProcedures(_procedures);
      }
      debugPrint('Procedures learned: ${_procedures.length} total');
    } catch (e) {
      debugPrint('Error learning procedures: $e');
    }
  }

  /// Extract procedures using regex patterns
  void _extractProceduresWithRegex(String content, String memoryId) {
    final normalized = content
        .replaceAll(''', "'")
        .replaceAll(''', "'")
        .toLowerCase();

    // Preference patterns: "I prefer X", "I like X better"
    final preferPatterns = [
      RegExp(r"i\s+prefer\s+([a-zA-Z\s]+?)(?:\.|,|$)", caseSensitive: false),
      RegExp(r"i\s+(?:like|want)\s+([a-zA-Z\s]+?)\s+better", caseSensitive: false),
    ];
    for (final pattern in preferPatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final pref = match.group(1)?.trim();
        if (pref != null && pref.length > 2) {
          _addOrUpdateProcedure(ProceduralMemory(
            id: 'proc_${_uuid.v4()}',
            type: ProceduralType.preference,
            description: 'Prefers $pref',
            condition: 'always',
            action: 'Use $pref when possible',
            learnedAt: DateTime.now(),
            evidenceIds: [memoryId],
          ));
          debugPrint('Extracted preference: $pref');
          break;
        }
      }
    }

    // Rule patterns: "Don't X", "Never X", "Always X"
    final rulePatterns = [
      (RegExp(r"don'?t\s+([a-zA-Z\s]+?)(?:\.|,|$)", caseSensitive: false), 'avoid'),
      (RegExp(r"never\s+([a-zA-Z\s]+?)(?:\.|,|$)", caseSensitive: false), 'never'),
      (RegExp(r"always\s+([a-zA-Z\s]+?)(?:\.|,|$)", caseSensitive: false), 'always'),
    ];
    for (final (pattern, ruleType) in rulePatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final rule = match.group(1)?.trim();
        if (rule != null && rule.length > 2) {
          _addOrUpdateProcedure(ProceduralMemory(
            id: 'proc_${_uuid.v4()}',
            type: ProceduralType.rule,
            description: '${ruleType.toUpperCase()}: $rule',
            condition: 'always',
            action: '$ruleType $rule',
            learnedAt: DateTime.now(),
            evidenceIds: [memoryId],
          ));
          debugPrint('Extracted rule: $ruleType $rule');
          break;
        }
      }
    }

    // Habit patterns: "I usually X", "I always X in the morning"
    final habitPatterns = [
      RegExp(r"i\s+(?:usually|normally|typically)\s+([a-zA-Z\s]+?)(?:\.|,|$)", caseSensitive: false),
      RegExp(r"every\s+(?:day|morning|evening|night)\s+i\s+([a-zA-Z\s]+?)(?:\.|,|$)", caseSensitive: false),
    ];
    for (final pattern in habitPatterns) {
      final match = pattern.firstMatch(normalized);
      if (match != null) {
        final habit = match.group(1)?.trim();
        if (habit != null && habit.length > 2) {
          _addOrUpdateProcedure(ProceduralMemory(
            id: 'proc_${_uuid.v4()}',
            type: ProceduralType.habit,
            description: 'Usually $habit',
            condition: 'regularly',
            action: 'Remember user habit: $habit',
            learnedAt: DateTime.now(),
            evidenceIds: [memoryId],
          ));
          debugPrint('Extracted habit: $habit');
          break;
        }
      }
    }
  }

  void _addOrUpdateProcedure(ProceduralMemory newProc) {
    // Check for similar existing procedure
    final existingIndex = _procedures.indexWhere((p) =>
      p.description.toLowerCase().contains(newProc.description.toLowerCase().split(' ').first) &&
      p.type == newProc.type
    );

    if (existingIndex != -1) {
      _procedures[existingIndex].reinforce();
      debugPrint('Reinforced procedure: ${newProc.description}');
    } else {
      _procedures.add(newProc);
      debugPrint('Added new procedure: ${newProc.description}');
    }
  }

  List<ProceduralMemory> getRelevantProcedures(String context) {
    return _procedures
      .where((p) => p.matchesContext(context) && p.currentConfidence > 0.3)
      .toList()
      ..sort((a, b) => b.currentConfidence.compareTo(a.currentConfidence));
  }

  //============================================
  // MEMORY RETRIEVAL (Decay-weighted)
  //============================================

  Future<List<MemoryRetrievalResult>> retrieveRelevant(String query, {int limit = 5}) async {
    // Skip retrieval for very short queries (embedding fails)
    if (query.trim().length < 10) {
      debugPrint('Query too short for retrieval, skipping');
      return [];
    }

    try {
      final ragResults = await _cactus.rag.search(text: query, limit: limit * 2);
      final results = <MemoryRetrievalResult>[];

      // Results are already sorted by relevance, so use position-based scoring
      for (int i = 0; i < ragResults.length; i++) {
        final r = ragResults[i];
        final content = EpisodicMemory.extractContent(r.chunk.content);
        final meta = EpisodicMemory.extractMetadata(r.chunk.content);

        // Estimate relevance score based on position (first = most relevant)
        final relevanceScore = 1.0 - (i / ragResults.length) * 0.5;

        // Calculate memory strength with decay
        double strength = 0.5;
        if (meta != null) {
          final memory = EpisodicMemory.fromStorageFormat(r.chunk.content);
          memory.recordAccess(); // Update access tracking
          strength = memory.strength;
        }

        final combinedScore = relevanceScore * 0.6 + strength * 0.4;
        results.add(MemoryRetrievalResult(
          content: content,
          relevanceScore: relevanceScore,
          memoryStrength: strength,
          combinedScore: combinedScore,
          memoryId: meta?['id'] as String?,
        ));
      }

      // Sort by combined score and take top results
      results.sort((a, b) => b.combinedScore.compareTo(a.combinedScore));
      return results.take(limit).toList();
    } catch (e) {
      debugPrint('Error retrieving memories: $e');
      return [];
    }
  }

  Future<String> buildContext(String query) async {
    final buffer = StringBuffer();

    // Update working memory with query
    _workingMemory.setUserStatement(query);

    // Add semantic facts
    buffer.writeln('## Known facts about the user:');
    final factsContext = getFactsAsContext();
    buffer.writeln(factsContext);

    // Populate working memory with relevant facts
    for (final fact in getAllFacts().take(5)) {
      _workingMemory.addFact(fact, relevance: 0.7);
    }

    // Add relevant procedures
    final relevantProcs = getRelevantProcedures(query);
    if (relevantProcs.isNotEmpty) {
      buffer.writeln('\n## Behavioral guidelines:');
      for (final proc in relevantProcs.take(3)) {
        buffer.writeln('- ${proc.asInstruction}');
        _workingMemory.addRule(proc, relevance: 0.6);
      }
    }

    // Add relevant episodic memories
    try {
      final memories = await retrieveRelevant(query, limit: 3);
      if (memories.isNotEmpty) {
        buffer.writeln('\n## Relevant past conversations:');
        for (final m in memories) {
          buffer.writeln('- ${m.content}');
        }
      }
    } catch (e) {
      debugPrint('Error building context: $e');
    }

    return buffer.toString();
  }

  //============================================
  // EXPLICIT OPERATIONS
  //============================================

  Future<void> rememberExplicitly(String content, {ImportanceLevel importance = ImportanceLevel.high}) async {
    await storeEpisodic(
      content: 'User explicitly asked to remember: $content',
      source: MemorySource.explicit,
      importance: importance.value,
    );
  }

  Future<String> recallMemories(String query) async {
    final memories = await retrieveRelevant(query);
    if (memories.isEmpty) return 'No memories found for: "$query"';
    return 'Found:\n${memories.map((m) => '- ${m.content} (strength: ${(m.memoryStrength * 100).toInt()}%)').join('\n')}';
  }

  String listAllFacts() {
    final facts = getAllFacts();
    if (facts.isEmpty) return 'No facts stored yet.';

    final grouped = <FactCategory, List<SemanticFact>>{};
    for (final fact in facts) {
      grouped.putIfAbsent(fact.category, () => []).add(fact);
    }

    final buffer = StringBuffer();
    for (final entry in grouped.entries) {
      buffer.writeln('\n${entry.key.name.toUpperCase()}:');
      for (final fact in entry.value) {
        buffer.writeln('  - ${fact.asNaturalLanguage} (${fact.confidenceIndicator})');
      }
    }
    return buffer.toString();
  }

  List<ChatMessage> getHistory() => List.unmodifiable(_history);
  void clearHistory() {
    _history.clear();
    _workingMemory.clear();
  }

  Future<void> clearAll() async {
    _facts.clear();
    _procedures.clear();
    _recentEpisodes.clear();
    _history.clear();
    _workingMemory.clear();
    await _persistence.clear();
  }

  //============================================
  // STATISTICS
  //============================================

  MemoryStatistics getStatistics() {
    return MemoryStatistics(
      episodicCount: _recentEpisodes.length,
      semanticFactCount: _facts.where((f) => !f.isContradicted).length,
      proceduralCount: _procedures.length,
      workingMemoryLoad: _workingMemory.activeSlots.length / WorkingMemory.maxSlots,
      averageFactConfidence: _facts.isEmpty
        ? 0
        : _facts.map((f) => f.confidence).reduce((a, b) => a + b) / _facts.length,
      averageProceduralConfidence: _procedures.isEmpty
        ? 0
        : _procedures.map((p) => p.currentConfidence).reduce((a, b) => a + b) / _procedures.length,
    );
  }
}

/// Result of memory retrieval with scoring
class MemoryRetrievalResult {
  final String content;
  final double relevanceScore;
  final double memoryStrength;
  final double combinedScore;
  final String? memoryId;

  MemoryRetrievalResult({
    required this.content,
    required this.relevanceScore,
    required this.memoryStrength,
    required this.combinedScore,
    this.memoryId,
  });
}

/// Overall memory system statistics
class MemoryStatistics {
  final int episodicCount;
  final int semanticFactCount;
  final int proceduralCount;
  final double workingMemoryLoad;
  final double averageFactConfidence;
  final double averageProceduralConfidence;

  MemoryStatistics({
    required this.episodicCount,
    required this.semanticFactCount,
    required this.proceduralCount,
    required this.workingMemoryLoad,
    required this.averageFactConfidence,
    required this.averageProceduralConfidence,
  });

  int get totalMemories => episodicCount + semanticFactCount + proceduralCount;
}

/// Task for background extraction queue
class _ExtractionTask {
  final String content;
  final String memoryId;

  _ExtractionTask(this.content, this.memoryId);
}
