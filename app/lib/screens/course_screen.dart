import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content_repository.dart';
import '../locale_store.dart';
import '../models.dart';
import '../progress_store.dart';
import '../strings.dart';
import 'lesson_detail_screen.dart';

/// The imported sentence course: Russian-taught lessons whose practice is
/// building the English sentence from word tiles. Lessons unlock in order,
/// the same way the grammar lessons do.
class CourseScreen extends StatelessWidget {
  const CourseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.read<ContentRepository>();
    final progress = context.watch<ProgressStore>();
    final lang = context.watch<LocaleStore>().lang;
    final lessons = content.courseLessons;

    if (lessons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(tr(lang, 'nav_course'))),
        body: Center(child: Text(tr(lang, 'no_words'))),
      );
    }

    final totalItems =
        lessons.fold<int>(0, (int s, l) => s + l.itemsOfType('sentence').length);

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'nav_course'))),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: lessons.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                '${lessons.length} ${tr(lang, 'course_lessons')} · '
                '$totalItems ${tr(lang, 'course_exercises')}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).hintColor),
              ),
            );
          }
          final idx = i - 1;
          final lesson = lessons[idx];
          // The imported course lessons stand alone (each drills its own
          // grammar point), so they're all open — no sequential gating.
          const unlocked = true;
          final done = progress.lessonHasAnyCompleted(lesson.id);
          return _CourseTile(
            lesson: lesson,
            number: idx + 1,
            unlocked: unlocked,
            done: done,
            lang: lang,
          );
        },
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  final Lesson lesson;
  final int number;
  final bool unlocked;
  final bool done;
  final String lang;
  const _CourseTile({
    required this.lesson,
    required this.number,
    required this.unlocked,
    required this.done,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hint = Theme.of(context).hintColor;
    final count = lesson.itemsOfType('sentence').length;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            done ? const Color(0xFF3CA84B) : scheme.surfaceContainerHighest,
        foregroundColor: done ? Colors.white : scheme.onSurface,
        child: done
            ? const Icon(Icons.check, size: 20)
            : Text('$number', style: const TextStyle(fontSize: 13)),
      ),
      title: Text(lesson.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(
        count > 0
            ? '$count ${tr(lang, 'course_exercises')}'
            : tr(lang, 'guide'),
        style: TextStyle(color: hint, fontSize: 12.5),
      ),
      trailing: unlocked
          ? const Icon(Icons.chevron_right)
          : Icon(Icons.lock_outline, size: 18, color: hint),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonDetailScreen(
            lessonId: lesson.id,
            practiceUnlocked: unlocked,
          ),
        ),
      ),
    );
  }
}
