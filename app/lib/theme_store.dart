import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light / dark / follow-the-system, remembered across launches.
class ThemeStore extends ChangeNotifier {
  static const _key = 'theme_mode'; // 'system' | 'light' | 'dark'
  final SharedPreferences _prefs;
  ThemeStore(this._prefs);

  static Future<ThemeStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemeStore(prefs);
  }

  String get name => _prefs.getString(_key) ?? 'system';

  ThemeMode get mode => switch (name) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  Future<void> setMode(String value) async {
    await _prefs.setString(_key, value);
    notifyListeners();
  }
}
