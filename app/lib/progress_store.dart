import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-(lesson, practice-type) completion and enforces the unlock
/// rule: the next lesson unlocks once AT LEAST ONE of the current lesson's
/// practices is completed. Grammar explanations are always readable.
class ProgressStore extends ChangeNotifier {
  static const _kCompleted = 'completed_practices'; // "lessonId:type" entries
  final SharedPreferences _prefs;

  ProgressStore(this._prefs);

  static Future<ProgressStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressStore(prefs);
  }

  Set<String> get _completed =>
      (_prefs.getStringList(_kCompleted) ?? const []).toSet();

  String _key(int lessonId, String type) => '$lessonId:$type';

  bool isPracticeCompleted(int lessonId, String type) =>
      _completed.contains(_key(lessonId, type));

  String _progKey(int lessonId, String type) => 'prog:$lessonId:$type';

  /// Saved net-correct count for an in-progress practice (0 if none/completed).
  int practiceProgress(int lessonId, String type) =>
      _prefs.getInt(_progKey(lessonId, type)) ?? 0;

  /// Persist mid-practice progress so it survives closing the app.
  Future<void> setPracticeProgress(
      int lessonId, String type, int count) async {
    await _prefs.setInt(_progKey(lessonId, type), count);
    notifyListeners();
  }

  /// Whether any practice of a lesson has been completed.
  bool lessonHasAnyCompleted(int lessonId) =>
      _completed.any((e) => e.startsWith('$lessonId:'));

  /// Practice is unlocked for the first lesson, or if the immediately
  /// preceding lesson has at least one completed practice.
  bool practiceUnlocked({required int ord, required int? prevLessonId}) {
    if (ord <= 1) return true;
    if (prevLessonId == null) return true;
    return lessonHasAnyCompleted(prevLessonId);
  }

  Future<void> markPracticeCompleted(int lessonId, String type) async {
    final set = _completed..add(_key(lessonId, type));
    await _prefs.setStringList(_kCompleted, set.toList());
    await _prefs.remove(_progKey(lessonId, type)); // clear the in-progress count
    notifyListeners();
  }

  Future<void> reset() async {
    await _prefs.remove(_kCompleted);
    for (final k in _prefs.getKeys().where((k) => k.startsWith('prog:')).toList()) {
      await _prefs.remove(k);
    }
    notifyListeners();
  }
}
