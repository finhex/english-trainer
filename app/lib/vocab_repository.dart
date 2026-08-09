import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'vocab_models.dart';

/// Loads the bundled 10k CEFR-leveled word list once at startup, plus the
/// separate Russian example-translations overlay (examples_ru.json).
class VocabRepository {
  final List<Word> words;
  final Map<int, String> levelNames; // level -> display name
  final Map<String, String> exampleRu; // english example -> russian
  final Map<String, String> definitionRu; // english definition -> russian
  VocabRepository(
      this.words, this.levelNames, this.exampleRu, this.definitionRu);

  static Future<VocabRepository> load() async {
    final raw = await rootBundle.loadString('assets/words.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final words = (data['words'] as List)
        .map((e) => Word.fromJson(e as Map<String, dynamic>))
        .toList();
    final names = <int, String>{};
    for (final w in words) {
      names[w.level] = w.levelName;
    }
    // Russian overlays (separate files; absent/partial is fine).
    final exampleRu = await _loadMap('assets/examples_ru.json');
    final definitionRu = await _loadMap('assets/definitions_ru.json');
    return VocabRepository(words, names, exampleRu, definitionRu);
  }

  static Future<Map<String, String>> _loadMap(String asset) async {
    try {
      final raw = await rootBundle.loadString(asset);
      return (json.decode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  /// Russian translation of an English example sentence ('' if none).
  String ruExample(String english) => exampleRu[english] ?? '';

  /// Russian translation of an English definition ('' if none yet).
  String ruDefinition(String english) => definitionRu[english] ?? '';

  List<int> get levels => levelNames.keys.toList()..sort();

  List<Word> wordsForLevel(int level) =>
      words.where((w) => w.level == level).toList();

  int countForLevel(int level) => wordsForLevel(level).length;
}
