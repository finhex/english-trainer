import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content_repository.dart';
import '../locale_store.dart';
import '../markdown_style.dart';
import '../models.dart';
import '../strings.dart';

/// Read-only reference material — every book chapter that isn't a practice
/// grammar lesson (phonetics, morphology, spelling, punctuation, study skills,
/// common mistakes …), grouped by the book's Parts.
class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final guides = context.read<ContentRepository>().guideLessons;
    final lang = context.watch<LocaleStore>().lang;

    // group by Part, preserving order
    final groups = <String, List<Lesson>>{};
    for (final g in guides) {
      groups.putIfAbsent(g.part, () => []).add(g);
    }

    final rows = <Widget>[];
    groups.forEach((part, items) {
      rows.add(_PartHeader(name: part.isEmpty ? 'Reference' : part));
      for (final g in items) {
        rows.add(ListTile(
          leading: const Icon(Icons.article_outlined),
          title: Text(g.topicFor(lang),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => GuideDetailScreen(guide: g)),
          ),
        ));
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'nav_guides'))),
      body: ListView(padding: const EdgeInsets.only(bottom: 16), children: rows),
    );
  }
}

class _PartHeader extends StatelessWidget {
  final String name;
  const _PartHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Text(name,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold)),
    );
  }
}

class GuideDetailScreen extends StatelessWidget {
  final Lesson guide;
  const GuideDetailScreen({super.key, required this.guide});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleStore>().lang;
    return Scaffold(
      appBar: AppBar(
        title: Text(guide.topicFor(lang),
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      // same reading view as lessons (adaptive tables, full-width code, header)
      body: ReadingView(
        title: guide.topicFor(lang),
        levelName: guide.levelName,
        meta:
            '${tr(lang, 'guide')} ${guide.ord}  ·  ${tr(lang, 'chapter')} ${guide.id}',
        markdown: guide.grammarFor(lang),
      ),
    );
  }
}
