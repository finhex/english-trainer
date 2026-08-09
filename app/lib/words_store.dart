import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which words the learner has marked as "known".
class WordsStore extends ChangeNotifier {
  static const _kKnown = 'known_words';
  final SharedPreferences _prefs;

  WordsStore(this._prefs);

  static Future<WordsStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return WordsStore(prefs);
  }

  Set<String> get _known =>
      (_prefs.getStringList(_kKnown) ?? const []).toSet();

  bool isKnown(String word) => _known.contains(word);

  int knownCount(Iterable<String> words) {
    final k = _known;
    return words.where(k.contains).length;
  }

  Future<void> setKnown(String word, bool known) async {
    final set = _known;
    if (known) {
      set.add(word);
    } else {
      set.remove(word);
    }
    await _prefs.setStringList(_kKnown, set.toList());
    notifyListeners();
  }

  Future<void> reset() async {
    await _prefs.remove(_kKnown);
    notifyListeners();
  }
}
