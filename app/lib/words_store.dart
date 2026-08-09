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

  // stored in the ORDER words were marked known (append on mark), so the last
  // entry is the most recently learned.
  List<String> get _knownList => _prefs.getStringList(_kKnown) ?? const [];
  Set<String> get _known => _knownList.toSet();

  bool isKnown(String word) => _known.contains(word);

  int knownCount(Iterable<String> words) {
    final k = _known;
    return words.where(k.contains).length;
  }

  /// Position a word was marked known (higher = more recent); -1 if not known.
  /// Used to sort learned words "last-added first".
  int knownOrder(String word) => _knownList.indexOf(word);

  Future<void> setKnown(String word, bool known) async {
    final list = List<String>.from(_knownList);
    list.remove(word); // avoid duplicates / refresh recency
    if (known) list.add(word); // newest goes to the end
    await _prefs.setStringList(_kKnown, list);
    notifyListeners();
  }

  Future<void> reset() async {
    await _prefs.remove(_kKnown);
    notifyListeners();
  }
}
