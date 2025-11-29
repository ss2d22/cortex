import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/semantic_fact.dart';
import '../models/procedural_memory.dart';
import '../models/memory.dart';
import '../models/chat_message.dart';

class PersistenceService {
  static const String _factsKey = 'cortex_facts';
  static const String _proceduresKey = 'cortex_procedures';
  static const String _episodesKey = 'cortex_episodes';
  static const String _conversationsKey = 'cortex_conversations';
  static const String _currentConversationKey = 'cortex_current_conversation';
  static const String _settingsKey = 'cortex_settings';

  //============================================
  // SEMANTIC FACTS
  //============================================

  Future<void> saveFacts(List<SemanticFact> facts) async {
    final prefs = await SharedPreferences.getInstance();
    final json = facts.map((f) => f.toJson()).toList();
    await prefs.setString(_factsKey, jsonEncode(json));
  }

  Future<List<SemanticFact>> loadFacts() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_factsKey);
    if (str == null) return [];

    try {
      final list = jsonDecode(str) as List;
      return list.map((j) => SemanticFact.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  //============================================
  // PROCEDURAL MEMORY
  //============================================

  Future<void> saveProcedures(List<ProceduralMemory> procedures) async {
    final prefs = await SharedPreferences.getInstance();
    final json = procedures.map((p) => p.toJson()).toList();
    await prefs.setString(_proceduresKey, jsonEncode(json));
  }

  Future<List<ProceduralMemory>> loadProcedures() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_proceduresKey);
    if (str == null) return [];

    try {
      final list = jsonDecode(str) as List;
      return list.map((j) => ProceduralMemory.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  //============================================
  // EPISODIC MEMORY
  //============================================

  Future<void> saveEpisodes(List<EpisodicMemory> episodes) async {
    final prefs = await SharedPreferences.getInstance();
    // Store the full storage format which includes metadata
    final json = episodes.map((e) => e.toStorageFormat()).toList();
    await prefs.setString(_episodesKey, jsonEncode(json));
  }

  Future<List<EpisodicMemory>> loadEpisodes() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_episodesKey);
    if (str == null) return [];

    try {
      final list = jsonDecode(str) as List;
      return list
          .map((s) => EpisodicMemory.fromStorageFormat(s as String))
          .toList();
    } catch (_) {
      return [];
    }
  }

  //============================================
  // CONVERSATIONS
  //============================================

  Future<void> saveConversations(List<Conversation> conversations) async {
    final prefs = await SharedPreferences.getInstance();
    final json = conversations.map((c) => c.toJson()).toList();
    await prefs.setString(_conversationsKey, jsonEncode(json));
  }

  Future<List<Conversation>> loadConversations() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_conversationsKey);
    if (str == null) return [];

    try {
      final list = jsonDecode(str) as List;
      return list
          .map((j) => Conversation.fromJson(j as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCurrentConversationId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_currentConversationKey);
    } else {
      await prefs.setString(_currentConversationKey, id);
    }
  }

  Future<String?> loadCurrentConversationId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentConversationKey);
  }

  //============================================
  // SETTINGS
  //============================================

  Future<void> saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = await _loadSettings();
    settings[key] = value;
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }

  Future<T?> loadSetting<T>(String key) async {
    final settings = await _loadSettings();
    return settings[key] as T?;
  }

  Future<Map<String, dynamic>> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_settingsKey);
    if (str == null) return {};
    try {
      return jsonDecode(str) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  //============================================
  // CLEAR
  //============================================

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_factsKey);
    await prefs.remove(_proceduresKey);
    await prefs.remove(_episodesKey);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_factsKey);
    await prefs.remove(_proceduresKey);
    await prefs.remove(_episodesKey);
    await prefs.remove(_settingsKey);
  }
}
