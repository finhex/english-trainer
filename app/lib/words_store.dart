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
  // entry is the most recently learned. Cached so a fast scroll (which calls
  // isKnown once per visible row, every frame) does not rebuild a Set from
  // SharedPreferences on every single call.
  List<String>? _listCache;
  Set<String>? _setCache;
  Map<String, int>? _orderCache;

  List<String> get _knownList =>
      _listCache ??= _prefs.getStringList(_kKnown) ?? const [];
  Set<String> get _known => _setCache ??= _knownList.toSet();
  Map<String, int> get _order => _orderCache ??= {
        for (var i = 0; i < _knownList.length; i++) _knownList[i]: i,
      };

  void _invalidate() {
    _listCache = null;
    _setCache = null;
    _orderCache = null;
  }

  bool isKnown(String word) => _known.contains(word);

  int knownCount(Iterable<String> words) {
    final k = _known;
    return words.where(k.contains).length;
  }

  /// Position a word was marked known (higher = more recent); -1 if not known.
  /// Used to sort learned words "last-added first".
  int knownOrder(String word) => _order[word] ?? -1;

  Future<void> setKnown(String word, bool known) async {
    final list = List<String>.from(_knownList);
    list.remove(word); // avoid duplicates / refresh recency
    if (known) list.add(word); // newest goes to the end
    await _prefs.setStringList(_kKnown, list);
    _invalidate();
    notifyListeners();
  }

  Future<void> reset() async {
    await _prefs.remove(_kKnown);
    _invalidate();
    notifyListeners();
  }
}
