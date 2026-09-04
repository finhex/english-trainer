import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_config.dart';
import '../content_repository.dart';
import '../models.dart';
import '../progress_store.dart';
import '../strings.dart';
import '../screens/lesson_detail_screen.dart';
import '../screens/practice_screen.dart';

/// Tapping a lesson asks what to do with it — read the explanation, or run one
/// of its practices — instead of dropping straight into the text. Each practice
/// row carries its own progress (12 / 70) and a check when it is finished.
Future<void> showLessonMenu(
  BuildContext context, {
  required Lesson lesson,
  required bool unlocked,
  required String lang,
}) {
  final repo = context.read<ContentRepository>();
  final practices = repo.config.orderedPractices
      .where((p) => lesson.itemsOfType(p.type).isNotEmpty)
      .toList();

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final progress = sheetContext.watch<ProgressStore>();
      final scheme = Theme.of(sheetContext).colorScheme;
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                lesson.topicFor(lang),
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: Icon(Icons.menu_book_outlined, color: scheme.primary),
              title: Text(tr(lang, 'read_lesson')),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LessonDetailScreen(
                      lessonId: lesson.id, practiceUnlocked: unlocked),
                ));
              },
            ),
            if (practices.isNotEmpty) const Divider(height: 1),
            for (final p in practices)
              _PracticeRow(
                config: p,
                lang: lang,
                goal: lesson.goalFor(p.type),
                current: progress.practiceProgress(lesson.id, p.type),
                done: progress.isPracticeCompleted(lesson.id, p.type),
                locked: !unlocked,
                onTap: () {
                  if (!unlocked) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr(lang, 'finish_previous'))),
                    );
                    return;
                  }
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        PracticeScreen(lessonId: lesson.id, type: p.type),
                  ));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

class _PracticeRow extends StatelessWidget {
  final PracticeConfig config;
  final String lang;
  final int goal;
  final int current;
  final bool done;
  final bool locked;
  final VoidCallback onTap;
  const _PracticeRow({
    required this.config,
    required this.lang,
    required this.goal,
    required this.current,
    required this.done,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = goal == 0 ? 0.0 : (current / goal).clamp(0.0, 1.0);
    return ListTile(
      leading: Icon(iconFor(config.icon),
          color: locked ? Theme.of(context).disabledColor : scheme.primary),
      title: Text(practiceLabel(lang, config.type)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: done ? 1 : value, minHeight: 6),
          ),
          const SizedBox(height: 4),
          Text('${done ? goal : current} / $goal',
              style: TextStyle(
                  fontSize: 12, color: Theme.of(context).hintColor)),
        ],
      ),
      trailing: done
          ? const Icon(Icons.check_circle, color: Color(0xFF3CA84B))
          : Icon(locked ? Icons.lock_outline : Icons.chevron_right),
      onTap: onTap,
    );
  }
}
