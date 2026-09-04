/// Models for the bundled, offline vocabulary (assets/words.json).
/// Each word carries its part(s) of speech and multiple meanings (senses).
library;

import 'polish_pack.dart';

class Sense {
  final String pos;
  final String definition;
  final String example;
  final String exampleRu; // Russian translation of the example ('' if none yet)
  final String definitionRu; // Russian definition ('' if none)
  final List<String> ru; // Russian translations of this meaning ([] if none)

  Sense({
    required this.pos,
    required this.definition,
    required this.example,
    required this.exampleRu,
    required this.definitionRu,
    required this.ru,
  });

  factory Sense.fromJson(Map<String, dynamic> j) => Sense(
        pos: j['pos'] as String,
        definition: j['definition'] as String,
        example: (j['example'] as String?) ?? '',
        exampleRu: (j['exampleRu'] as String?) ?? '',
        definitionRu: (j['definitionRu'] as String?) ?? '',
        ru: ((j['ru'] as List?) ?? const []).cast<String>(),
      );
}

class Word {
  final String word;
  final int level;
  final String levelName;
  final List<String> pos; // e.g. ['noun', 'verb']
  final List<Sense> senses;
  final String simple; // hand-written plain-English explanation ('' if none)
  final List<String> myExamples;
  final List<String> ru; // Russian translations of the word ([] if none)

  Word({
    required this.word,
    required this.level,
    required this.levelName,
    required this.pos,
    required this.senses,
    required this.simple,
    required this.myExamples,
    required this.ru,
  });

  /// e.g. "время · срок · раз" — a short line (primary translations) for lists.
  String get ruLine => ru.take(4).join(' · ');

  /// Translations to show in the given UI language: Russian for 'ru', Polish
  /// from the removable pack for 'pl', and nothing for English. A word the
  /// Polish pack has not reached yet shows no translation rather than falling
  /// back to Russian, which a Polish learner could not read.
  List<String> translationsFor(String lang) {
    if (lang == 'pl') return PolishPack.word(word);
    return lang == 'ru' ? ru : const [];
  }

  /// The same, as one short line for a list row.
  String lineFor(String lang) => translationsFor(lang).take(4).join(' · ');

  /// Russian translations grouped by part of speech (deduped, top few each),
  /// so a word like "address" shows noun vs verb separately instead of a
  /// jumble, and the rare/archaic tail is trimmed.
  Map<String, List<String>> get ruByPos {
    final m = <String, List<String>>{};
    for (final s in senses) {
      if (s.ru.isEmpty) continue;
      final list = m.putIfAbsent(s.pos, () => []);
      for (final t in s.ru) {
        if (!list.contains(t) && list.length < 3) list.add(t);
      }
    }
    if (m.isEmpty && ru.isNotEmpty) {
      m[pos.isNotEmpty ? pos.first : 'noun'] = ru.take(3).toList();
    }
    return m;
  }

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        word: j['word'] as String,
        level: j['level'] as int,
        levelName: j['levelName'] as String,
        pos: (j['pos'] as List).cast<String>(),
        senses: (j['senses'] as List)
            .map((e) => Sense.fromJson(e as Map<String, dynamic>))
            .toList(),
        simple: (j['simple'] as String?) ?? '',
        myExamples: ((j['myExamples'] as List?) ?? const []).cast<String>(),
        ru: ((j['ru'] as List?) ?? const []).cast<String>(),
      );
}
