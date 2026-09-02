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
  final Map<String, Map<String, String>> ipa; // word -> {uk, us} IPA
  final Map<String, List<String>> irregular; // base verb -> [v1, v2, v3]
  final Map<String, dynamic> full; // word -> rich entry (ipa/forms/etymology/senses)
  final List<String> top3000; // the ~3000 most frequent words (freq order)
  final Map<String, List<String>> pairings; // word -> common collocations
  VocabRepository(this.words, this.levelNames, this.exampleRu,
      this.definitionRu, this.ipa, this.irregular, this.full, this.top3000,
      this.pairings);

  /// Frequency-ranked common collocations for a word (e.g. spot -> "parking
  /// spot", "sweet spot"), empty if none.
  List<String> pairingsFor(String word) => pairings[word] ?? const [];

  /// The subset of [words] that are in the 3000-most-common list.
  List<Word> get top3000Words {
    final rank = {for (var i = 0; i < top3000.length; i++) top3000[i]: i};
    final list = words.where((w) => rank.containsKey(w.word)).toList();
    list.sort((a, b) => rank[a.word]!.compareTo(rank[b.word]!));
    return list;
  }

  /// Rich FreeDict/Wiktionary entry for a word (senses with examples, synonyms,
  /// forms, etymology), or null if not covered.
  Map<String, dynamic>? fullFor(String word) =>
      full[word] as Map<String, dynamic>?;

  static Future<VocabRepository> load() async {
    final raw = await rootBundle.loadString('assets/words.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    // word-level Russian overlay (separate file; overrides the inline `ru` so
    // translations can be corrected/rebuilt without touching words.json).
    final wordRu = await _loadListMap('assets/word_ru.json');
    final wlist = data['words'] as List;
    if (wordRu.isNotEmpty) {
      for (final e in wlist) {
        final m = e as Map<String, dynamic>;
        final o = wordRu[m['word']];
        if (o != null) m['ru'] = o;
      }
    }
    final words = wlist
        .map((e) => Word.fromJson(e as Map<String, dynamic>))
        .toList();
    final names = <int, String>{};
    for (final w in words) {
      names[w.level] = w.levelName;
    }
    // Russian overlays (separate files; absent/partial is fine).
    final exampleRu = await _loadMap('assets/examples_ru.json');
    final definitionRu = await _loadMap('assets/definitions_ru.json');
    var ipa = <String, Map<String, String>>{};
    try {
      final raw = await rootBundle.loadString('assets/ipa.json');
      ipa = (json.decode(raw) as Map<String, dynamic>).map((k, v) => MapEntry(
          k,
          (v as Map<String, dynamic>)
              .map((a, b) => MapEntry(a, b as String))));
    } catch (_) {}
    var irregular = <String, List<String>>{};
    try {
      final raw = await rootBundle.loadString('assets/irregular_verbs.json');
      irregular = (json.decode(raw) as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, (v as List).cast<String>()));
    } catch (_) {}
    var full = <String, dynamic>{};
    try {
      final raw = await rootBundle.loadString('assets/word_full.json');
      full = json.decode(raw) as Map<String, dynamic>;
    } catch (_) {}
    var top3000 = <String>[];
    try {
      final raw = await rootBundle.loadString('assets/top3000.json');
      top3000 = (json.decode(raw) as List).cast<String>();
    } catch (_) {}
    final pairings = await _loadListMap('assets/pairings.json');
    return VocabRepository(words, names, exampleRu, definitionRu, ipa,
        irregular, full, top3000, pairings);
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

  static Future<Map<String, List<String>>> _loadListMap(String asset) async {
    try {
      final raw = await rootBundle.loadString(asset);
      return (json.decode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as List).cast<String>()));
    } catch (_) {
      return {};
    }
  }

  /// Russian translation of an English example sentence ('' if none).
  String ruExample(String english) => exampleRu[english] ?? '';

  /// Russian translation of an English definition ('' if none yet).
  String ruDefinition(String english) => definitionRu[english] ?? '';

  /// British (RP) IPA of a word ('' if unavailable).
  String ipaUk(String word) => ipa[word]?['uk'] ?? '';

  /// American IPA of a word ('' if unavailable).
  String ipaUs(String word) => ipa[word]?['us'] ?? '';

  /// [base, past, past-participle] if the word is an irregular verb, else null.
  List<String>? irregularForms(String word) => irregular[word];

  List<int> get levels => levelNames.keys.toList()..sort();

  List<Word> wordsForLevel(int level) =>
      words.where((w) => w.level == level).toList();

  int countForLevel(int level) => wordsForLevel(level).length;
}
