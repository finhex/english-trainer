import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../app_config.dart';
import '../content_repository.dart';
import '../locale_store.dart';
import '../markdown_style.dart';
import '../models.dart';
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
      // The imported course renders from its ORIGINAL HTML with the same
      // widget its own app uses, so the lessons look exactly as they do there.
      body: lesson
              .htmlFor(Theme.of(context).brightness == Brightness.dark)
              .isNotEmpty
          ? _CourseHtml(lesson: lesson, practices: practices, lang: lang)
          : ReadingView(
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

/// A course lesson, drawn from its own HTML.
///
/// The pieces arrive pre-split: the course's app stores them that way because
/// the HTML renderer silently gives up and shows nothing once a single
/// document passes roughly 10 KB. Stacking the pieces keeps each one under it.
class _CourseHtml extends StatelessWidget {
  final Lesson lesson;
  final List<PracticeConfig> practices;
  final String lang;
  const _CourseHtml(
      {required this.lesson, required this.practices, required this.lang});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = lesson.htmlFor(theme.brightness == Brightness.dark);
    final progress = context.watch<ProgressStore>();
    // the course's own app puts the whole explanation in a Card with 22px of
    // padding — same wrapper here so the tables sit where they do there
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final part in parts)
                  for (final seg in _splitTables(part))
                    // a wide conjugation table must scroll rather than be cut off;
                    // the prose around it keeps wrapping normally
                    seg.isTable
                        ? LayoutBuilder(
                            builder: (context, c) {
                              // The source tables carry no width: they shrink
                              // to fit and sit centred. Laying one out at the
                              // window width stretches it; at a narrow width
                              // the renderer breaks words inside the cells.
                              final want = _tableWidth(seg.html);
                              final table = SizedBox(
                                width: want,
                                child: HtmlWidget(seg.html,
                                    textStyle: theme.textTheme.bodyMedium),
                              );
                              if (c.maxWidth.isFinite && want <= c.maxWidth) {
                                return Center(child: table);
                              }
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.only(bottom: 8),
                                child: table,
                              );
                            },
                          )
                        : HtmlWidget(seg.html,
                            textStyle: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        if (practices.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child:
                Text(tr(lang, 'practice'), style: theme.textTheme.titleMedium),
          ),
          for (final p in practices)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading:
                    Icon(iconFor(p.icon), color: theme.colorScheme.primary),
                title: Text(practiceLabel(lang, p.type)),
                subtitle: Text(
                    '${progress.isPracticeCompleted(lesson.id, p.type) ? lesson.goalFor(p.type) : progress.practiceProgress(lesson.id, p.type)}'
                    ' / ${lesson.goalFor(p.type)}'),
                trailing: progress.isPracticeCompleted(lesson.id, p.type)
                    ? const Icon(Icons.check_circle, color: Color(0xFF3CA84B))
                    : const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      PracticeScreen(lessonId: lesson.id, type: p.type),
                )),
              ),
            ),
        ],
      ],
    );
  }
}

/// One piece of a lesson: either a table (scrolled sideways) or ordinary flow.
class _Seg {
  final String html;
  final bool isTable;
  const _Seg(this.html, this.isTable);
}

/// Splits lesson HTML into table and non-table segments, matching <table>
/// openings to their own closing tag so nested tables stay in one piece.
List<_Seg> _splitTables(String html) {
  final segs = <_Seg>[];
  final tag = RegExp(r'<(/?)table\b[^>]*>', caseSensitive: false);
  var pos = 0;
  while (true) {
    final open = tag.firstMatch(html.substring(pos));
    if (open == null || open.group(1) == '/') break;
    final start = pos + open.start;
    if (start > pos) segs.add(_Seg(html.substring(pos, start), false));
    // walk to the matching close
    var depth = 0;
    var end = html.length;
    for (final m in tag.allMatches(html, start)) {
      if (m.group(1) == '/') {
        depth--;
        if (depth == 0) {
          end = m.end;
          break;
        }
      } else {
        depth++;
      }
    }
    segs.add(_Seg(html.substring(start, end), true));
    pos = end;
  }
  if (pos < html.length) segs.add(_Seg(html.substring(pos), false));
  return segs.where((s) => s.html.trim().isNotEmpty).toList();
}

/// A sensible width for a lesson table: its widest row's column count times a
/// readable column share. The source tables carry no width, so laying them out
/// at the window width stretches them and at a narrow width collapses the
/// words inside the cells.
double _tableWidth(String html) {
  var cols = 0;
  for (final row
      in RegExp(r'<tr\b[^>]*>(.*?)</tr>', caseSensitive: false, dotAll: true)
          .allMatches(html)) {
    final n = RegExp(r'<t[dh]\b', caseSensitive: false)
        .allMatches(row.group(1) ?? '')
        .length;
    if (n > cols) cols = n;
  }
  if (cols == 0) return 560;
  // A conjugation box holds a nested table per panel (aux | pronouns | verb),
  // so its outer column count badly understates the room the text needs —
  // counting only those breaks words inside the cells ("lov e?").
  final nested = RegExp(r'<table\b', caseSensitive: false).allMatches(html).length > 1;
  final w = cols * (nested ? 265.0 : 190.0);
  return w.clamp(360.0, 1500.0);
}
