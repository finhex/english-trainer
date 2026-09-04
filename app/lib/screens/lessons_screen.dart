import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content_repository.dart';
import '../locale_store.dart';
import '../models.dart';
import '../progress_store.dart';
import '../strings.dart';
import 'lesson_home_screen.dart';

/// The lesson list: the course lessons, numbered 1..N, each showing how far
/// its practice has got. Tapping one opens the read-or-practice screen.
///
/// The grammar-book chapters are not listed here — they are the Book tab.
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.read<ContentRepository>();
    final progress = context.watch<ProgressStore>();
    final lang = context.watch<LocaleStore>().lang;
    final lessons = content.courseLessons.isNotEmpty
        ? content.courseLessons
        : content.grammarLessons;

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'lessons'))),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: lessons.length,
        itemBuilder: (context, i) {
          final lesson = lessons[i];
          // total progress across the lesson's practices
          var goal = 0, current = 0;
          var allDone = true;
          for (final p in content.config.orderedPractices) {
            if (lesson.itemsOfType(p.type).isEmpty) continue;
            goal += lesson.goalFor(p.type);
            final done = progress.isPracticeCompleted(lesson.id, p.type);
            current += done
                ? lesson.goalFor(p.type)
                : progress.practiceProgress(lesson.id, p.type);
            if (!done) allDone = false;
          }
          return _LessonTile(
            lesson: lesson,
            number: i + 1,
            goal: goal,
            current: current,
            done: goal > 0 && allDone,
            lang: lang,
          );
        },
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final int number;
  final int goal;
  final int current;
  final bool done;
  final String lang;
  const _LessonTile({
    required this.lesson,
    required this.number,
    required this.goal,
    required this.current,
    required this.done,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hint = Theme.of(context).hintColor;
    final value = goal == 0 ? 0.0 : (current / goal).clamp(0.0, 1.0);
    return ListTile(
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      // the same numbered square the grammar lessons used
      leading: SizedBox(
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: done ? const Color(0xFF3CA84B) : scheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: done
              ? Icon(Icons.check, color: scheme.onPrimary, size: 22)
              : Text('$number',
                  style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
        ),
      ),
      title: Text(lesson.topicFor(lang),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      // progress is visible in the list, before opening the lesson
      subtitle: goal == 0
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: value, minHeight: 6),
                  ),
                  const SizedBox(height: 4),
                  Text('$current / $goal',
                      style: TextStyle(fontSize: 12, color: hint)),
                ],
              ),
            ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonHomeScreen(lessonId: lesson.id),
        ),
      ),
    );
  }
}
