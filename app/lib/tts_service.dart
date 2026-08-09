import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// English pronunciation ("озвучка"). Guarded so platforms without a TTS
/// implementation (e.g. some Linux setups) degrade to a silent no-op
/// instead of crashing.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _ensure() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.45);
      _ready = true;
    } catch (e) {
      debugPrint('TTS unavailable: $e');
    }
  }

  Future<void> speak(String text) async {
    try {
      await _ensure();
      await _tts.stop();
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
