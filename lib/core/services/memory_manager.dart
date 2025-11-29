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

class MemoryManager extends ChangeNotifier {
  final CactusService _cactus;
  final PersistenceService _persistence;
  final _uuid = const Uuid();

  final List<SemanticFact> _facts = [];
  final List<ProceduralMemory> _procedures = [];
  final List<EpisodicMemory> _recentEpisodes = [];
  final WorkingMemory _workingMemory = WorkingMemory();

  final List<_ExtractionTask> _extractionQueue = [];
  bool _isExtracting = false;

  MemoryManager(this._cactus, this._persistence);

  WorkingMemory get workingMemory => _workingMemory;
  List<SemanticFact> get facts => List.unmodifiable(_facts);
  List<ProceduralMemory> get procedures => List.unmodifiable(_procedures);
  List<EpisodicMemory> get recentEpisodes => List.unmodifiable(_recentEpisodes);

  Future<void> initialize() async {
    final savedFacts = await _persistence.loadFacts();
    _facts.addAll(savedFacts);

    final savedProcedures = await _persistence.loadProcedures();
    _procedures.addAll(savedProcedures);

    final savedEpisodes = await _persistence.loadEpisodes();
    _recentEpisodes.addAll(savedEpisodes);

    notifyListeners();
  }

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

    try {
      await _cactus.rag.storeDocument(
        fileName: id,
        filePath: '',
        content: memory.toStorageFormat(),
        fileSize: content.length,
      );

      _recentEpisodes.add(memory);
      if (_recentEpisodes.length > 50) {
        _recentEpisodes.removeAt(0);
      }

      await _persistence.saveEpisodes(_recentEpisodes);

      _queueExtraction(content, id);

      notifyListeners();
    } catch (_) {}

    return memory;
  }

  Future<void> storeConversation(String userMsg, String assistantMsg) async {
    final importance = _assessImportance(userMsg);
    final valence = _detectValence(userMsg);

    await storeEpisodic(
      content: 'User: $userMsg\nAssistant: $assistantMsg',
      source: MemorySource.conversation,
      importance: importance,
      valence: valence,
    );

    _workingMemory.addConversationTurn('user', userMsg);
    _workingMemory.addConversationTurn('assistant', assistantMsg);
  }

  Future<List<MemoryRetrievalResult>> retrieveRelevant(
    String query, {
    int limit = AppConstants.maxRetrievedMemories,
  }) async {
    if (query.trim().length < 10) return [];

    try {
      final ragResults = await _cactus.rag.search(text: query, limit: limit * 2);
      final results = <MemoryRetrievalResult>[];

      for (int i = 0; i < ragResults.length; i++) {
        final r = ragResults[i];
        final content = EpisodicMemory.extractContent(r.chunk.content);
        final meta = EpisodicMemory.extractMetadata(r.chunk.content);

        final relevanceScore = 1.0 - (i / ragResults.length) * 0.5;

        double strength = 0.5;
        if (meta != null) {
          final memory = EpisodicMemory.fromStorageFormat(r.chunk.content);
          memory.recordAccess();
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

      results.sort((a, b) => b.combinedScore.compareTo(a.combinedScore));
      return results.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  List<SemanticFact> getAllFacts() =>
    _facts.where((f) => !f.isContradicted).toList();

  List<SemanticFact> getFactsByCategory(FactCategory category) =>
    _facts.where((f) => f.category == category && !f.isContradicted).toList();

  String getFactsAsContext() {
    final activeFacts = getAllFacts();
    if (activeFacts.isEmpty) return 'No facts known yet.';

    final sorted = List<SemanticFact>.from(activeFacts)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    return sorted
      .take(AppConstants.maxContextFacts)
      .map((f) => '- ${f.asNaturalLanguage}')
      .join('\n');
  }

  void addOrUpdateFact(SemanticFact newFact) {
    final existingIndex = _facts.indexWhere(
      (f) => f.subject.toLowerCase() == newFact.subject.toLowerCase() &&
             f.predicate == newFact.predicate,
    );

    if (existingIndex != -1) {
      final existing = _facts[existingIndex];
      if (existing.object.toLowerCase() == newFact.object.toLowerCase()) {
        existing.reinforce();
      } else {
        existing.markContradicted(newFact.id);
        _facts.add(newFact);
      }
    } else {
      _facts.add(newFact);
    }

    _persistence.saveFacts(_facts);
    notifyListeners();
  }

  List<ProceduralMemory> getRelevantProcedures(String context) {
    return _procedures
      .where((p) => p.matchesContext(context) && p.currentConfidence > 0.3)
      .toList()
      ..sort((a, b) => b.currentConfidence.compareTo(a.currentConfidence));
  }

  void addOrUpdateProcedure(ProceduralMemory newProc) {
    final existingIndex = _procedures.indexWhere((p) =>
      p.description.toLowerCase().contains(
        newProc.description.toLowerCase().split(' ').first
      ) && p.type == newProc.type
    );

    if (existingIndex != -1) {
      _procedures[existingIndex].reinforce();
    } else {
      _procedures.add(newProc);
    }

    _persistence.saveProcedures(_procedures);
    notifyListeners();
  }

  Future<String> buildContext(String query) async {
    final buffer = StringBuffer();

    _workingMemory.setUserStatement(query);

    buffer.writeln('## Known facts about the user:');
    buffer.writeln(getFactsAsContext());

    for (final fact in getAllFacts().take(5)) {
      _workingMemory.addFact(fact, relevance: 0.7);
    }

    final relevantProcs = getRelevantProcedures(query);
    if (relevantProcs.isNotEmpty) {
      buffer.writeln('\n## Behavioral guidelines:');
      for (final proc in relevantProcs.take(AppConstants.maxContextRules)) {
        buffer.writeln('- ${proc.asInstruction}');
        _workingMemory.addRule(proc, relevance: 0.6);
      }
    }

    try {
      final memories = await retrieveRelevant(query);
      if (memories.isNotEmpty) {
        buffer.writeln('\n## Relevant past conversations:');
        for (final m in memories) {
          buffer.writeln('- ${m.content}');
        }
      }
    } catch (_) {}

    return buffer.toString();
  }

  Future<String> ingestVoice(String audioPath) async {
    final stt = await _cactus.getSTT();

    String streamedText = "";

    final streamedResult = await stt.transcribeStream(
      audioFilePath: audioPath,
    );

    streamedResult.stream.listen(
      (token) {
        streamedText += token;
      },
      onError: (_) {},
    );

    final result = await streamedResult.result;

    await _cactus.unloadSTT();

    if (result.success) {
      final rawText = streamedText.isNotEmpty ? streamedText : result.text;
      final text = _cleanWhisperOutput(rawText);
      await storeEpisodic(
        content: 'Voice memo: $text',
        source: MemorySource.voice,
        importance: 0.7,
      );
      return text;
    }
    throw Exception('Transcription failed: ${result.errorMessage}');
  }

  String _cleanWhisperOutput(String text) {
    final cleaned = text
        .replaceAll(RegExp(r'<\|[^|>]+\|>'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();
    return cleaned;
  }

  Future<String> ingestPhoto(String imagePath) async {
    try {
      final visionLM = await _cactus.getVisionLM();

      final result = await visionLM.generateCompletion(
        messages: [
          ChatMessage(
            content: 'You are a helpful AI assistant that can analyze images.',
            role: 'system',
          ),
          ChatMessage(
            content: 'Describe this image briefly and note any important details.',
            role: 'user',
            images: [imagePath],
          ),
        ],
        params: CactusCompletionParams(maxTokens: 150),
      );

      if (result.success && result.response.isNotEmpty) {
        await storeEpisodic(
          content: 'Photo: ${result.response}',
          source: MemorySource.photo,
          importance: 0.6,
        );
        return result.response;
      }
      throw Exception('Vision returned empty response');
    } finally {
      await _cactus.restorePrimaryLM();
    }
  }

  Future<void> rememberExplicitly(
    String content, {
    ImportanceLevel importance = ImportanceLevel.high,
  }) async {
    await storeEpisodic(
      content: 'User explicitly asked to remember: $content',
      source: MemorySource.explicit,
      importance: importance.value,
    );
  }

  Future<String> recallMemories(String query) async {
    final memories = await retrieveRelevant(query);
    if (memories.isEmpty) return 'No memories found for: "$query"';

    return 'Found:\n${memories.map((m) =>
      '- ${m.content} (strength: ${(m.memoryStrength * 100).toInt()}%)'
    ).join('\n')}';
  }

  String listAllFacts() {
    final allFacts = getAllFacts();
    if (allFacts.isEmpty) return 'No facts stored yet.';

    final grouped = <FactCategory, List<SemanticFact>>{};
    for (final fact in allFacts) {
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

  void _queueExtraction(String content, String memoryId) {
    String userContent = content;
    if (content.startsWith('User:')) {
      final assistantIndex = content.indexOf('Assistant:');
      if (assistantIndex > 0) {
        userContent = content.substring(5, assistantIndex).trim();
      } else {
        userContent = content.substring(5).trim();
      }
    }

    if (userContent.length < 5) return;

    _extractionQueue.add(_ExtractionTask(userContent, memoryId));
    _processExtractionQueue();
  }

  Future<void> _processExtractionQueue() async {
    if (_isExtracting || _extractionQueue.isEmpty) return;

    _isExtracting = true;

    while (_extractionQueue.isNotEmpty) {
      final task = _extractionQueue.removeAt(0);
      try {
        await _extractWithRegex(task.content, task.memoryId);
      } catch (_) {}
    }

    _isExtracting = false;
  }

  Future<void> _extractWithRegex(String userMessage, String memoryId) async {
    final text = userMessage.toLowerCase().replaceAll(''', "'").replaceAll(''', "'");
    int extracted = 0;

    final nameMatch = RegExp(
      r"(?:i'm|i am|my name is|call me)\s+([a-z]{2,15})(?:\s|,|\.|\!|$)",
      caseSensitive: false,
    ).firstMatch(text);

    if (nameMatch != null) {
      final name = nameMatch.group(1)!.trim();
      final badWords = ['stressed', 'happy', 'sad', 'tired', 'being', 'going', 'working', 'feeling'];
      if (!badWords.contains(name.toLowerCase())) {
        _addFact('name_is', _capitalize(name), memoryId);
        extracted++;
      }
    }

    final companyMatch = RegExp(
      r"(?:work(?:ing)?|employed)\s+(?:at|for)\s+([a-z0-9]+)",
      caseSensitive: false,
    ).firstMatch(text);

    if (companyMatch != null) {
      final company = companyMatch.group(1)!.trim();
      if (company.length >= 2) {
        _addFact('works_at', _capitalize(company), memoryId);
        extracted++;
      }
    }

    final jobMatch = RegExp(
      r"(?:i'm a|i am a|work as a?)\s+([a-z]+(?:\s+[a-z]+)?)",
      caseSensitive: false,
    ).firstMatch(text);

    if (jobMatch != null) {
      final job = jobMatch.group(1)!.trim();
      final badJobs = ['employee', 'worker', 'person'];
      if (!badJobs.contains(job.toLowerCase()) && job.length >= 3) {
        _addFact('job_is', job, memoryId);
        extracted++;
      }
    }

    final locationMatch = RegExp(
      r"(?:live in|from|based in|located in)\s+([a-z]+(?:\s+[a-z]+)?)",
      caseSensitive: false,
    ).firstMatch(text);

    if (locationMatch != null) {
      final location = locationMatch.group(1)!.trim();
      if (location.length >= 2) {
        _addFact('lives_in', _capitalize(location), memoryId);
        extracted++;
      }
    }

    final ageMatch = RegExp(
      r"(?:i'm|i am)\s+(\d{1,3})\s*(?:years?\s*old)?",
      caseSensitive: false,
    ).firstMatch(text);

    if (ageMatch != null) {
      final age = int.tryParse(ageMatch.group(1)!);
      if (age != null && age > 0 && age < 120) {
        _addFact('age_is', age.toString(), memoryId);
        extracted++;
      }
    }

    final emotions = ['stressed', 'anxious', 'happy', 'sad', 'angry', 'frustrated', 'tired', 'exhausted', 'excited', 'nervous', 'overwhelmed'];
    for (final emotion in emotions) {
      if (RegExp(r"\b" + emotion + r"\b").hasMatch(text)) {
        _addFact('feels', emotion, memoryId);
        extracted++;
        break;
      }
    }

    final petMatch = RegExp(
      r"(?:i have|my|got)\s+(?:a\s+)?(?:pet\s+)?([a-z]+)\s+(?:named|called)\s+([a-z]+)",
      caseSensitive: false,
    ).firstMatch(text);
    if (petMatch != null) {
      final petType = petMatch.group(1)?.trim();
      final petName = petMatch.group(2)?.trim();
      if (petType != null && petName != null) {
        _addFact('pet_is', '$petType named ${_capitalize(petName)}', memoryId);
        extracted++;
      }
    }

    final hobbyMatch = RegExp(
      r"(?:i\s+(?:like|love|enjoy)\s+(?:to\s+)?|my hobby is\s+)([a-z]+(?:ing)?(?:\s+[a-z]+)?)",
      caseSensitive: false,
    ).firstMatch(text);
    if (hobbyMatch != null) {
      final hobby = hobbyMatch.group(1)?.trim();
      if (hobby != null && hobby.length > 2 && !['it', 'that', 'this'].contains(hobby)) {
        _addFact('hobby_is', hobby, memoryId);
        extracted++;
      }
    }

    final relationshipMatch = RegExp(
      r"my\s+(wife|husband|partner|boyfriend|girlfriend|spouse)'?s?\s+(?:name is\s+)?([a-z]+)",
      caseSensitive: false,
    ).firstMatch(text);
    if (relationshipMatch != null) {
      final relation = relationshipMatch.group(1)?.trim();
      final name = relationshipMatch.group(2)?.trim();
      if (relation != null && name != null && name.length > 1) {
        _addFact('married_to', _capitalize(name), memoryId);
        extracted++;
      }
    }

    final childMatch = RegExp(
      r"(?:i have|my)\s+(?:a\s+)?(?:(\d+)\s+)?(?:kid|child|son|daughter)s?(?:\s+named\s+([a-z]+))?",
      caseSensitive: false,
    ).firstMatch(text);
    if (childMatch != null) {
      final count = childMatch.group(1);
      final name = childMatch.group(2);
      if (name != null) {
        _addFact('has_child', _capitalize(name), memoryId);
        extracted++;
      } else if (count != null) {
        _addFact('has_child', '$count children', memoryId);
        extracted++;
      }
    }

    final birthdayMatch = RegExp(
      r"my birthday is\s+(?:on\s+)?([a-z]+\s+\d{1,2}|\d{1,2}[\/\-]\d{1,2})",
      caseSensitive: false,
    ).firstMatch(text);
    if (birthdayMatch != null) {
      final birthday = birthdayMatch.group(1)?.trim();
      if (birthday != null) {
        _addFact('birthday_is', birthday, memoryId);
        extracted++;
      }
    }

    final likesMatch = RegExp(
      r"i\s+(?:really\s+)?(?:like|love)\s+([a-z]+(?:\s+[a-z]+)?)",
      caseSensitive: false,
    ).firstMatch(text);
    if (likesMatch != null && hobbyMatch == null) {
      final likes = likesMatch.group(1)?.trim();
      if (likes != null && likes.length > 1 && !['it', 'that', 'this', 'to'].contains(likes)) {
        _addFact('likes', likes, memoryId);
        extracted++;
      }
    }

    final dislikesMatch = RegExp(
      r"i\s+(?:really\s+)?(?:hate|dislike|don'?t like)\s+([a-z]+(?:\s+[a-z]+)?)",
      caseSensitive: false,
    ).firstMatch(text);
    if (dislikesMatch != null) {
      final dislikes = dislikesMatch.group(1)?.trim();
      if (dislikes != null && dislikes.length > 1 && !['it', 'that', 'this'].contains(dislikes)) {
        _addFact('dislikes', dislikes, memoryId);
        extracted++;
      }
    }

    _extractProcedures(text, memoryId);

    if (extracted > 0) {
      await _persistence.saveFacts(_facts);
    }
  }

  void _extractProcedures(String text, String memoryId) {
    final preferMatch = RegExp(
      r"i\s+prefer\s+([a-zA-Z\s]+?)(?:\.|,|$)",
      caseSensitive: false,
    ).firstMatch(text);

    if (preferMatch != null) {
      final pref = preferMatch.group(1)?.trim();
      if (pref != null && pref.length > 2) {
        addOrUpdateProcedure(ProceduralMemory(
          id: 'proc_${_uuid.v4()}',
          type: ProceduralType.preference,
          description: 'Prefers $pref',
          condition: 'always',
          action: 'Use $pref when possible',
          learnedAt: DateTime.now(),
          evidenceIds: [memoryId],
        ));
      }
    }

    final rulePatterns = [
      (RegExp(r"don'?t\s+([a-zA-Z\s]+?)(?:\.|,|$)", caseSensitive: false), 'avoid'),
      (RegExp(r"never\s+([a-zA-Z\s]+?)(?:\.|,|$)", caseSensitive: false), 'never'),
      (RegExp(r"always\s+([a-zA-Z\s]+?)(?:\.|,|$)", caseSensitive: false), 'always'),
    ];

    for (final (pattern, ruleType) in rulePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final rule = match.group(1)?.trim();
        if (rule != null && rule.length > 2) {
          addOrUpdateProcedure(ProceduralMemory(
            id: 'proc_${_uuid.v4()}',
            type: ProceduralType.rule,
            description: '${ruleType.toUpperCase()}: $rule',
            condition: 'always',
            action: '$ruleType $rule',
            learnedAt: DateTime.now(),
            evidenceIds: [memoryId],
          ));
          break;
        }
      }
    }
  }

  void _addFact(String predicate, String value, String memoryId) {
    addOrUpdateFact(SemanticFact(
      id: 'fact_${_uuid.v4()}',
      subject: 'User',
      predicate: predicate,
      object: value,
      extractedAt: DateTime.now(),
      sourceMemoryIds: [memoryId],
    ));
  }

  String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  double _assessImportance(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('remember') || lower.contains('important') ||
        lower.contains("don't forget") || lower.contains('always') ||
        lower.contains('never')) {
      return 0.8;
    }
    if (lower.contains('my name') || lower.contains('i am') ||
        lower.contains('i work') || lower.contains('i live')) {
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

  MemoryStatistics getStatistics() {
    return MemoryStatistics(
      episodicCount: _recentEpisodes.length,
      semanticFactCount: _facts.where((f) => !f.isContradicted).length,
      proceduralCount: _procedures.length,
      workingMemoryLoad: _workingMemory.activeSlots.length / AppConstants.workingMemorySlots,
      averageFactConfidence: _facts.isEmpty
        ? 0
        : _facts.map((f) => f.confidence).reduce((a, b) => a + b) / _facts.length,
      averageProceduralConfidence: _procedures.isEmpty
        ? 0
        : _procedures.map((p) => p.currentConfidence).reduce((a, b) => a + b) / _procedures.length,
    );
  }

  SemanticMemoryStats getSemanticStats() => SemanticMemoryStats.fromFacts(_facts);

  void clearHistory() {
    _workingMemory.clear();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _facts.clear();
    _procedures.clear();
    _recentEpisodes.clear();
    _workingMemory.clear();
    await _persistence.clear();
    notifyListeners();
  }
}

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

class _ExtractionTask {
  final String content;
  final String memoryId;

  _ExtractionTask(this.content, this.memoryId);
}
