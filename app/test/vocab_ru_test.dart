import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:english_trainer/vocab_models.dart';

/// Parses the real bundled word list and checks the Russian layer is intact.
void main() {
  late List<Word> words;

  setUpAll(() {
    final raw = File('assets/words.json').readAsStringSync();
    final data = json.decode(raw) as Map<String, dynamic>;
    words = (data['words'] as List)
        .map((e) => Word.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  test('every word parses and 99% carry a Russian translation', () {
    expect(words.length, 10000);
    final withRu = words.where((w) => w.ru.isNotEmpty).length;
    expect(withRu / words.length, greaterThan(0.98));
  });

  test('translations are Cyrillic, non-empty and deduplicated', () {
    final cyrillic = RegExp(r'[Ѐ-ӿ]');
    for (final w in words.take(2000)) {
      for (final t in w.ru) {
        expect(t.trim(), isNotEmpty, reason: 'blank translation on ${w.word}');
        expect(cyrillic.hasMatch(t), isTrue,
            reason: 'non-Cyrillic "$t" on ${w.word}');
      }
      expect(w.ru.toSet().length, w.ru.length,
          reason: 'duplicate translation on ${w.word}');
    }
  });

  test('sense translations never outnumber the cap', () {
    for (final w in words) {
      for (final s in w.senses) {
        expect(s.ru.length, lessThanOrEqualTo(4));
      }
    }
  });

  test('known words translate as expected', () {
    Word find(String s) => words.firstWhere((w) => w.word == s);
    expect(find('water').ru, contains('вода'));
    expect(find('book').ru, contains('книга'));
    expect(find('because').ru, contains('потому что'));
    expect(find('light').ru, contains('свет'));
  });
}
