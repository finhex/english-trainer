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
class _CourseHtml extends StatefulWidget {
  final Lesson lesson;
  final List<PracticeConfig> practices;
  final String lang;
  const _CourseHtml(
      {required this.lesson, required this.practices, required this.lang});

  @override
  State<_CourseHtml> createState() => _CourseHtmlState();
}

class _CourseHtmlState extends State<_CourseHtml> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Lesson get lesson => widget.lesson;
  List<PracticeConfig> get practices => widget.practices;
  String get lang => widget.lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts =
        lesson.htmlFor(theme.brightness == Brightness.dark, lang: lang);
    final progress = context.watch<ProgressStore>();

    // A ListView.builder only ESTIMATES its extent from the items it has
    // measured, so dragging the bar jumps when the pieces differ wildly in
    // height. A SingleChildScrollView lays them all out and knows its real
    // height, so the thumb tracks the pointer - the way the book scrolls.
    // keep the last lines clear of the Android system nav bar (3 buttons)
    final bottomInset = MediaQuery.of(context).padding.bottom;
    // on a phone the desktop gutters would eat most of the width, so shrink
    // them: the lesson should use the screen it has
    final narrow = MediaQuery.of(context).size.width < 640;
    final gutter = narrow ? 4.0 : 24.0;
    final inner = narrow ? 8.0 : 22.0;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, 8, gutter, gutter + bottomInset),
          child: Card(
            margin: EdgeInsets.zero,
            child: Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(
                    inner, inner, inner, inner + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final part in parts)
                      for (final seg in _splitTables(part))
                        seg.isTable
                            ? _TableScroll(
                                html: seg.html,
                                centered: seg.centered,
                                textStyle: theme.textTheme.bodyMedium)
                            : HtmlWidget(seg.html,
                                textStyle: theme.textTheme.bodyMedium),
                    if (practices.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 8),
                        child: Text(tr(lang, 'practice'),
                            style: theme.textTheme.titleMedium),
                      ),
                      for (final p in practices)
                        Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Icon(iconFor(p.icon),
                                color: theme.colorScheme.primary),
                            title: Text(practiceLabel(lang, p.type)),
                            subtitle: Text(
                                '${progress.isPracticeCompleted(lesson.id, p.type) ? lesson.goalFor(p.type) : progress.practiceProgress(lesson.id, p.type)}'
                                ' / ${lesson.goalFor(p.type)}'),
                            trailing:
                                progress.isPracticeCompleted(lesson.id, p.type)
                                    ? const Icon(Icons.check_circle,
                                        color: Color(0xFF3CA84B))
                                    : const Icon(Icons.chevron_right),
                            onTap: () =>
                                Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => PracticeScreen(
                                  lessonId: lesson.id, type: p.type),
                            )),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One piece of a lesson: a table, or ordinary flowing content.
class _Seg {
  final String html;
  final bool isTable;

  /// Whether the source wrapped this table in <center>. It does that for the
  /// conjugation boxes only; the plain word tables are meant to sit at the
  /// left margin, where the lesson text is.
  final bool centered;
  const _Seg(this.html, this.isTable, {this.centered = false});
}

/// Splits lesson HTML into table and non-table pieces, matching each <table> to
/// its own closing tag so a nested conjugation box stays in one piece.
List<_Seg> _splitTables(String html) {
  final segs = <_Seg>[];
  final tag = RegExp(r'<(/?)table\b[^>]*>', caseSensitive: false);
  var pos = 0;
  while (true) {
    final open = tag.firstMatch(html.substring(pos));
    if (open == null || open.group(1) == '/') break;
    final start = pos + open.start;
    if (start > pos) segs.add(_Seg(html.substring(pos, start), false));
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
    segs.add(_Seg(html.substring(start, end), true,
        centered: html.substring(0, start).trimRight().endsWith('<center>')));
    pos = end;
  }
  if (pos < html.length) segs.add(_Seg(html.substring(pos), false));
  return segs.where((s) => s.html.trim().isNotEmpty).toList();
}

/// A lesson table.
///
/// On a screen with room it is left completely alone - no box around it, so it
/// keeps the width it chooses. Only when the view is too narrow to lay it out
/// at all (a phone, where the columns collapse until words break into single
/// letters) is it given the room it needs and scrolled, with a grey bar under
/// it.
class _TableScroll extends StatelessWidget {
  final String html;
  final TextStyle? textStyle;
  final bool centered;
  const _TableScroll(
      {required this.html, this.textStyle, this.centered = false});

  (int, bool) _shape(String html) {
    var cols = 0;
    for (final row
        in RegExp(r'<tr\b[^>]*>(.*?)</tr>', caseSensitive: false, dotAll: true)
            .allMatches(html)) {
      final n = RegExp(r'<t[dh]\b', caseSensitive: false)
          .allMatches(row.group(1) ?? '')
          .length;
      if (n > cols) cols = n;
    }
    final nested =
        RegExp(r'<table\b', caseSensitive: false).allMatches(html).length > 1;
    return (cols, nested);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final avail = c.maxWidth;
        final (cols, nested) = _shape(html);
        if (!avail.isFinite || cols == 0) {
          return HtmlWidget(html, textStyle: textStyle);
        }
        // the width below which the columns stop being readable
        final floor = cols * (nested ? 150.0 : 110.0);
        if (avail >= floor) {
          // the renderer ignores <center>, so a box the source centres is
          // centred here; a plain table keeps the left margin it was written at
          final table = HtmlWidget(html, textStyle: textStyle);
          return centered ? Center(child: table) : table;
        }
        // The renderer splits a table's width evenly between its columns and
        // ignores width hints, so the narrow tense-label column still takes a
        // full share. Keep the total tight so scrolling stays short.
        final width = cols * (nested ? 200.0 : 150.0);
        return HScroll(
          forceVisible: true,
          thumbColor: Theme.of(context).colorScheme.outline,
          child: SizedBox(
            width: width,
            child: HtmlWidget(html, textStyle: textStyle),
          ),
        );
      },
    );
  }
}
