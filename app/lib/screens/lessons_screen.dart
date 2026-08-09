import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content_repository.dart';
import '../locale_store.dart';
import '../models.dart';
import '../progress_store.dart';
import '../strings.dart';
import 'lesson_detail_screen.dart';

/// The lesson list, ordered beginner → advanced and grouped by CEFR level,
/// with lock badges (matches the reference app).
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final content = context.read<ContentRepository>();
    final progress = context.watch<ProgressStore>();
    final lang = context.watch<LocaleStore>().lang;
    final lessons = content.grammarLessons;

    // Flatten into a list of rows: a header precedes the first lesson of a level.
    final rows = <Widget>[];
    int? lastLevel;
    for (var i = 0; i < lessons.length; i++) {
      final lesson = lessons[i];
      if (lesson.level != lastLevel) {
        rows.add(_LevelHeader(name: lesson.levelName));
        lastLevel = lesson.level;
      }
      final prevId = i > 0 ? lessons[i - 1].id : null;
      final unlocked =
          progress.practiceUnlocked(ord: lesson.ord, prevLessonId: prevId);
      final done = progress.lessonHasAnyCompleted(lesson.id);
      rows.add(_LessonTile(
        lesson: lesson,
        unlocked: unlocked,
        done: done,
        lang: lang,
      ));
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'lessons'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: rows,
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  final String name;
  const _LevelHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(
        name,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  final bool unlocked;
  final bool done;
  final String lang;
  const _LessonTile(
      {required this.lesson,
      required this.unlocked,
      required this.done,
      required this.lang});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: _OrderBadge(order: lesson.ord, locked: !unlocked),
      title: Text(lesson.topicFor(lang),
          maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(done
          ? tr(lang, 'practice_completed')
          : (unlocked
              ? tr(lang, 'practice_unlocked')
              : tr(lang, 'grammar_readable_locked'))),
      trailing: done
          ? const Icon(Icons.check_circle, color: Color(0xFF3CA84B))
          : const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LessonDetailScreen(
              lessonId: lesson.id, practiceUnlocked: unlocked),
        ),
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  final int order;
  final bool locked;
  const _OrderBadge({required this.order, required this.locked});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('$order',
                style: TextStyle(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          ),
          if (locked)
            Positioned(
              right: 2,
              bottom: 2,
              child: Icon(Icons.lock, size: 14, color: scheme.onPrimary),
            ),
        ],
      ),
    );
  }
}
