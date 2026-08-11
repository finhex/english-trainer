import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'app_config.dart';
import 'models.dart';

/// Loads the bundled, pre-built content once at startup. Identical on
/// Android / Windows / Linux — plain JSON asset, no native dependencies.
class ContentRepository {
  final List<Lesson> lessons;
  final AppConfig config;
  final Map<String, String> partsRu; // english Part name -> russian
  ContentRepository(this.lessons, this.config, this.partsRu);

  static Future<ContentRepository> load() async {
    final raw = await rootBundle.loadString('assets/content.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final lessons = (data['lessons'] as List)
        .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.ord.compareTo(b.ord));
    final config = AppConfig.fromJson(data['config'] as Map<String, dynamic>?);
    var partsRu = <String, String>{};
    try {
      final r = await rootBundle.loadString('assets/parts_ru.json');
      partsRu = (json.decode(r) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as String));
    } catch (_) {}
    return ContentRepository(lessons, config, partsRu);
  }

  /// Part name in the given UI language (Russian when available).
  String partName(String part, String lang) =>
      lang == 'ru' ? (partsRu[part] ?? part) : part;

  Lesson byId(int id) => lessons.firstWhere((l) => l.id == id);

  /// Practice grammar lessons, ordered beginner → advanced.
  List<Lesson> get grammarLessons =>
      lessons.where((l) => l.section == 'grammar').toList()
        ..sort((a, b) => a.ord.compareTo(b.ord));

  /// Read-only reference chapters (phonetics, morphology, skills, …) in book order.
  List<Lesson> get guideLessons =>
      lessons.where((l) => l.section == 'other').toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  /// EVERY chapter in original book order (chapter id; appendices last).
  List<Lesson> get bookOrder =>
      lessons.toList()..sort((a, b) => a.id.compareTo(b.id));

  /// The whole book grouped by Part, Parts and chapters in book order.
  Map<String, List<Lesson>> get bookByPart {
    final m = <String, List<Lesson>>{};
    for (final l in bookOrder) {
      m.putIfAbsent(l.part.isEmpty ? 'Reference' : l.part, () => []).add(l);
    }
    return m;
  }
}
