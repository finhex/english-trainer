import 'dart:convert';
import 'package:flutter/services.dart';

/// The Polish layer, loaded from `assets/pl/` at startup.
///
/// It is deliberately kept apart from the rest of the app: every Polish string
/// lives in that one folder, nothing else reads from it, and if the folder is
/// removed the app carries on in English and Russian - [available] simply stays
/// false and Polish is not offered as a language.
///
/// The book is not part of this layer. A Polish learner reads the book in
/// English, which is what `Lesson.grammarFor` already does for any language
/// that has no translation of its own.
class PolishPack {
  /// Whether the Polish data loaded. Nothing offers Polish when this is false.
  static bool available = false;

  static Map<String, String> _ui = const {};
  static Map<String, dynamic> _lessons = const {};
  static Map<String, String> _practice = const {};
  static Map<String, dynamic> _words = const {};

  /// How much of each layer is present, for the settings screen and for tests.
  static int get uiCount => _ui.length;
  static int get lessonCount => _lessons.length;
  static int get practiceCount => _practice.length;
  static int get wordCount => _words.length;

  static Future<void> load() async {
    _ui = await _map('assets/pl/ui_pl.json');
    _lessons = await _raw('assets/pl/lessons_pl.json');
    _practice = await _map('assets/pl/practice_pl.json');
    _words = await _raw('assets/pl/words_pl.json');
    // the interface is what makes Polish usable at all; the content layers
    // fill in as they are translated
    available = _ui.isNotEmpty;
  }

  static Future<Map<String, dynamic>> _raw(String path) async {
    try {
      final text = await rootBundle.loadString(path);
      final json = jsonDecode(text);
      return json is Map<String, dynamic> ? json : const {};
    } catch (_) {
      return const {};
    }
  }

  static Future<Map<String, String>> _map(String path) async {
    final raw = await _raw(path);
    return {
      for (final e in raw.entries)
        if (e.value is String) e.key: e.value as String,
    };
  }

  /// A translated interface string, or null to fall back to English.
  static String? ui(String key) => _ui[key];

  /// The Polish pages of a course lesson, or null if it is not translated yet.
  static List<String>? lessonHtml(int courseNo, bool dark) {
    final l = _lessons['$courseNo'];
    if (l is! Map) return null;
    final parts = l[dark ? 'dark' : 'light'] ?? l['light'];
    if (parts is! List || parts.isEmpty) return null;
    return [for (final p in parts) '$p'];
  }

  /// The Polish title of a course lesson, or null.
  static String? lessonTitle(int courseNo) {
    final l = _lessons['$courseNo'];
    return l is Map && l['title'] is String ? l['title'] as String : null;
  }

  /// The Polish subtitle of a course lesson, or null.
  static String? lessonSubtitle(int courseNo) {
    final l = _lessons['$courseNo'];
    return l is Map && l['subtitle'] is String ? l['subtitle'] as String : null;
  }

  /// The Polish wording of a practice prompt, keyed by the Russian original.
  static String? prompt(String ru) => _practice[ru];

  /// Polish translations of a headword.
  static List<String> word(String w) {
    final v = _words[w.toLowerCase()];
    if (v is List) return [for (final t in v) '$t'];
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }
}
