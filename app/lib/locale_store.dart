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

  /// The languages the app actually offers. A setting saved by an older
  /// build can name one that no longer exists — Polish was offered for a
  /// while — and handing that to the Settings picker would leave it with a
  /// selection none of its buttons has, so anything unrecognised reads as
  /// English until the user chooses again.
  static const supported = {'en', 'ru'};

  String get lang {
    final saved = _prefs.getString(_key);
    return supported.contains(saved) ? saved! : 'en';
  }

  bool get isRu => lang == 'ru';

  Future<void> setLang(String lang) async {
    await _prefs.setString(_key, lang);
    notifyListeners();
  }
}
