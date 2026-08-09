import 'package:flutter/material.dart';

/// App configuration loaded from content.json's "config" block, so practice
/// labels, order, icons, per-practice target numbers and level names are all
/// editable in JSON without changing code.

const Map<String, IconData> _iconMap = {
  'reorder': Icons.reorder,
  'space_bar': Icons.space_bar,
  'category': Icons.category_outlined,
  'quiz': Icons.quiz_outlined,
};

IconData iconFor(String name) => _iconMap[name] ?? Icons.quiz_outlined;

class PracticeConfig {
  final String type;
  final String label;
  final String subtitle;
  final String icon;
  final int goal; // target correct answers to complete (default 70)
  final int order;

  PracticeConfig({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.goal,
    required this.order,
  });

  factory PracticeConfig.fromJson(String type, Map<String, dynamic> j) =>
      PracticeConfig(
        type: type,
        label: (j['label'] as String?) ?? type,
        subtitle: (j['subtitle'] as String?) ?? '',
        icon: (j['icon'] as String?) ?? 'quiz',
        goal: (j['goal'] as int?) ?? 70,
        order: (j['order'] as int?) ?? 99,
      );
}

class AppConfig {
  final Map<String, PracticeConfig> practices;
  final Map<int, String> levels;

  AppConfig({required this.practices, required this.levels});

  List<PracticeConfig> get orderedPractices =>
      practices.values.toList()..sort((a, b) => a.order.compareTo(b.order));

  PracticeConfig? practice(String type) => practices[type];
  String labelFor(String type) => practices[type]?.label ?? type;
  int goalFor(String type) => practices[type]?.goal ?? 70;

  factory AppConfig.fromJson(Map<String, dynamic>? j) {
    if (j == null) return AppConfig.fallback();
    final practices = <String, PracticeConfig>{};
    (j['practices'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
      practices[k] = PracticeConfig.fromJson(k, v as Map<String, dynamic>);
    });
    final levels = <int, String>{};
    (j['levels'] as Map<String, dynamic>? ?? const {}).forEach((k, v) {
      levels[int.parse(k)] = v as String;
    });
    if (practices.isEmpty) return AppConfig.fallback();
    return AppConfig(practices: practices, levels: levels);
  }

  factory AppConfig.fallback() => AppConfig(
        practices: {
          'word_order': PracticeConfig(
              type: 'word_order',
              label: 'Build the sentence',
              subtitle: '',
              icon: 'reorder',
              goal: 70,
              order: 1),
          'gap_fill': PracticeConfig(
              type: 'gap_fill',
              label: 'Fill the gap',
              subtitle: '',
              icon: 'space_bar',
              goal: 70,
              order: 2),
          'word_type': PracticeConfig(
              type: 'word_type',
              label: 'Word types',
              subtitle: '',
              icon: 'category',
              goal: 70,
              order: 3),
        },
        levels: const {},
      );
}
