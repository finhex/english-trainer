import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide text size for readability/accessibility. Three modes:
/// normal (1.0), large (1.25), extra-large (1.5). Applied via a MediaQuery
/// textScaler wrapped around the whole app in main.dart.
class TextScaleStore extends ChangeNotifier {
  static const _key = 'text_scale';
  final SharedPreferences _prefs;
  TextScaleStore(this._prefs);

  static Future<TextScaleStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return TextScaleStore(prefs);
  }

  /// 'normal' | 'large' | 'xlarge'
  String get mode => _prefs.getString(_key) ?? 'normal';

  double get scale {
    switch (mode) {
      case 'large':
        return 1.25;
      case 'xlarge':
        return 1.5;
      default:
        return 1.0;
    }
  }

  Future<void> setMode(String mode) async {
    await _prefs.setString(_key, mode);
    notifyListeners();
  }
}
