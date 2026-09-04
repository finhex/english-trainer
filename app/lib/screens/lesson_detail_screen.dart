import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_config.dart';
import '../content_repository.dart';
import '../locale_store.dart';
import '../markdown_style.dart';
import '../progress_store.dart';
import '../strings.dart';
import 'practice_screen.dart';

/// Grammar explanation (always readable) + the lesson's practices. Which
/// practices exist, their labels/icons/order and target numbers all come from
/// the JSON config (assets/content.json → "config").
class LessonDetailScreen extends StatelessWidget {
  final int lessonId;
  final bool practiceUnlocked;
  const LessonDetailScreen(
      {super.key, required this.lessonId, required this.practiceUnlocked});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ContentRepository>();
    final lesson = repo.byId(lessonId);
    final progress = context.watch<ProgressStore>();
    final lang = context.watch<LocaleStore>().lang;

    // ordered practices (from config) that actually have items in this lesson
    final practices = repo.config.orderedPractices
        .where((p) => lesson.itemsOfType(p.type).isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson.topicFor(lang),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${tr(lang, 'lesson')} ${lesson.displayNo}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      ),
      // reading + practices in one smooth scroll (shared with guides)
      body: ReadingView(
        title: lesson.topicFor(lang),
        // a course lesson already says "Урок N" in the app bar and again as the
        // first heading of its own text — no chip and no meta line as well
        levelName: lesson.courseNo != null ? '' : lesson.levelName,
        meta: lesson.courseNo != null
            ? ''
            : '${tr(lang, 'lesson')} ${lesson.ord}  ·  ${tr(lang, 'chapter')} ${lesson.id}',
        markdown: lesson.grammarFor(lang),
        trailing: [
          if (practices.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(tr(lang, 'practice'),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final p in practices)
              _PracticeTile(
                config: p,
                lang: lang,
                goal: lesson.goalFor(p.type),
                done: progress.isPracticeCompleted(lesson.id, p.type),
                inProgress: progress.practiceProgress(lesson.id, p.type),
                locked: !practiceUnlocked,
                onTap: practiceUnlocked
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PracticeScreen(
                                lessonId: lesson.id, type: p.type),
                          ),
                        )
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(tr(lang, 'finish_previous'))),
                        ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PracticeTile extends StatelessWidget {
  final PracticeConfig config;
  final String lang;
  final int goal;
  final bool done;
  final int inProgress;
  final bool locked;
  final VoidCallback onTap;
  const _PracticeTile({
    required this.config,
    required this.lang,
    required this.goal,
    required this.done,
    required this.inProgress,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resuming = !done && inProgress > 0;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(
          iconFor(config.icon),
          color: locked ? Theme.of(context).disabledColor : scheme.primary,
        ),
        title: Text(practiceLabel(lang, config.type)),
        subtitle: Text(resuming
            ? '${tr(lang, 'in_progress')} · $inProgress / $goal'
            : practiceSub(lang, config.type)),
        trailing: locked
            ? const Icon(Icons.lock)
            : done
                ? const Icon(Icons.check_circle, color: Color(0xFF3CA84B))
                : Icon(resuming ? Icons.play_circle_fill : Icons.play_arrow,
                    color: scheme.primary),
        onTap: onTap,
      ),
    );
  }
}
