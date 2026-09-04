import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_config.dart';
import '../content_repository.dart';
import '../locale_store.dart';
import '../progress_store.dart';
import '../strings.dart';
import 'lesson_detail_screen.dart';
import 'practice_screen.dart';

/// What to do with a lesson — read the explanation, or run one of its
/// practices. A full screen rather than a sheet, so each choice gets room for
/// its own progress.
class LessonHomeScreen extends StatelessWidget {
  final int lessonId;
  final bool unlocked;
  const LessonHomeScreen(
      {super.key, required this.lessonId, this.unlocked = true});

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ContentRepository>();
    final lesson = repo.byId(lessonId);
    final progress = context.watch<ProgressStore>();
    final lang = context.watch<LocaleStore>().lang;
    final practices = repo.config.orderedPractices
        .where((p) => lesson.itemsOfType(p.type).isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(lesson.topicFor(lang),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text('${tr(lang, 'lesson')} ${lesson.displayNo}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BigCard(
            icon: Icons.menu_book_outlined,
            title: tr(lang, 'read_lesson'),
            subtitle: tr(lang, 'read_lesson_sub'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => LessonDetailScreen(
                  lessonId: lesson.id, practiceUnlocked: unlocked),
            )),
          ),
          for (final p in practices)
            _PracticeCard(
              config: p,
              lang: lang,
              goal: lesson.goalFor(p.type),
              current: progress.practiceProgress(lesson.id, p.type),
              done: progress.isPracticeCompleted(lesson.id, p.type),
              count: lesson.itemsOfType(p.type).length,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    PracticeScreen(lessonId: lesson.id, type: p.type),
              )),
            ),
        ],
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _BigCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 30, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).hintColor)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  final PracticeConfig config;
  final String lang;
  final int goal;
  final int current;
  final bool done;
  final int count;
  final VoidCallback onTap;
  const _PracticeCard({
    required this.config,
    required this.lang,
    required this.goal,
    required this.current,
    required this.done,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final value = goal == 0 ? 0.0 : (current / goal).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(iconFor(config.icon), size: 30, color: scheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(practiceLabel(lang, config.type),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text('$count ${tr(lang, 'course_exercises')}',
                            style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).hintColor)),
                      ],
                    ),
                  ),
                  done
                      ? const Icon(Icons.check_circle, color: Color(0xFF3CA84B))
                      : const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: done ? 1 : value, minHeight: 8),
              ),
              const SizedBox(height: 6),
              Text('${done ? goal : current} / $goal',
                  style:
                      TextStyle(fontSize: 12.5, color: Theme.of(context).hintColor)),
            ],
          ),
        ),
      ),
    );
  }
}
