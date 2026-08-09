import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app UI language. English is the default; Russian is the alternative.
class LocaleStore extends ChangeNotifier {
  static const _key = 'ui_lang';
  final SharedPreferences _prefs;
  LocaleStore(this._prefs);

  static Future<LocaleStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return LocaleStore(prefs);
  }

  String get lang => _prefs.getString(_key) ?? 'en';
  bool get isRu => lang == 'ru';

  Future<void> setLang(String lang) async {
    await _prefs.setString(_key, lang);
    notifyListeners();
  }
}
