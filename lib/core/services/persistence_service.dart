import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/semantic_fact.dart';
import '../models/procedural_memory.dart';

class PersistenceService {
  static const String _factsKey = 'cortex_facts';
  static const String _proceduresKey = 'cortex_procedures';
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
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_factsKey);
    await prefs.remove(_proceduresKey);
    await prefs.remove(_settingsKey);
  }
}
