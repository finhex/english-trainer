import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'app_config.dart';
import 'models.dart';

/// Loads the bundled, pre-built content once at startup. Identical on
/// Android / Windows / Linux — plain JSON asset, no native dependencies.
class ContentRepository {
  final List<Lesson> lessons;
  final AppConfig config;
  ContentRepository(this.lessons, this.config);

  static Future<ContentRepository> load() async {
    final raw = await rootBundle.loadString('assets/content.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final lessons = (data['lessons'] as List)
        .map((e) => Lesson.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.ord.compareTo(b.ord));
    final config = AppConfig.fromJson(data['config'] as Map<String, dynamic>?);
    return ContentRepository(lessons, config);
  }

  Lesson byId(int id) => lessons.firstWhere((l) => l.id == id);

  /// Practice grammar lessons, ordered beginner → advanced.
  List<Lesson> get grammarLessons =>
      lessons.where((l) => l.section == 'grammar').toList()
        ..sort((a, b) => a.ord.compareTo(b.ord));

  /// Read-only reference chapters (phonetics, morphology, skills, …) in book order.
  List<Lesson> get guideLessons =>
      lessons.where((l) => l.section == 'other').toList()
        ..sort((a, b) => a.id.compareTo(b.id));
}
