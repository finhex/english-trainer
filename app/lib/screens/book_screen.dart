import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content_repository.dart';
import '../locale_store.dart';
import '../markdown_style.dart';
import '../models.dart';
import '../strings.dart';

// numbered subsection ("### 15.1 Title", "#### 15.1.1 Title")
final _subRe = RegExp(r'^#{2,4}\s+(\d+\.\d+(?:\.\d+)*)\s+(.*)$', multiLine: true);
final _subsCache = <String, List<({String num, String title})>>{};

List<({String num, String title})> _subsOf(Lesson ch, String lang) =>
    _subsCache.putIfAbsent('${ch.id}_$lang', () {
      return _subRe
          .allMatches(ch.grammarFor(lang))
          .map((m) => (num: m.group(1)!, title: m.group(2)!.trim()))
          .toList();
    });

/// One flat TOC row: a Part header, a chapter, or a subsection.
class _Row {
  final int kind; // 0 = part, 1 = chapter, 2 = subsection
  final String text;
  final Lesson? ch;
  const _Row(this.kind, this.text, [this.ch]);
}

/// The whole grammar/phonetics book, read-only, in original order:
/// Parts → chapters → subsections, all always visible, with a book search.
class BookScreen extends StatefulWidget {
  const BookScreen({super.key});
  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  String _query = '';
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ContentRepository>();
    final lang = context.watch<LocaleStore>().lang;
    final order = repo.bookOrder;
    final scheme = Theme.of(context).colorScheme;
    final q = _query.toLowerCase();

    bool chMatches(Lesson ch) =>
        ch.title.toLowerCase().contains(q) ||
        ch.titleRu.toLowerCase().contains(q) ||
        repo.partName(ch.part, lang).toLowerCase().contains(q) ||
        ch.grammarFor(lang).toLowerCase().contains(q);

    // build the flat row list (Part header, chapters, subsections), filtered
    final rows = <_Row>[];
    String? currentPart;
    for (final ch in order) {
      final subs = _subsOf(ch, lang);
      final subShow = q.isEmpty
          ? subs
          : subs
              .where((s) => '${s.num} ${s.title}'.toLowerCase().contains(q))
              .toList();
      if (q.isNotEmpty && !chMatches(ch) && subShow.isEmpty) continue;
      if (ch.part != currentPart) {
        currentPart = ch.part;
        rows.add(_Row(0, repo.partName(ch.part, lang)));
      }
      rows.add(_Row(1, ch.topicFor(lang), ch));
      for (final s in subShow) {
        rows.add(_Row(2, '${s.num}  ${s.title}', ch));
      }
    }

    void open(Lesson ch) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              ChapterReaderScreen(chapters: order, index: order.indexOf(ch)),
        ));

    Widget buildRow(_Row r) {
      switch (r.kind) {
        case 0: // Part header
          return Container(
            width: double.infinity,
            color: scheme.surfaceContainerHighest,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(r.text,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: scheme.primary, fontWeight: FontWeight.bold)),
          );
        case 1: // chapter
          return ListTile(
            dense: true,
            leading: SizedBox(
              width: 40,
              child: Text('${r.ch!.id}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: Theme.of(context).hintColor, fontSize: 13)),
            ),
            title: Text(r.text,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => open(r.ch!),
          );
        default: // subsection
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.only(left: 62, right: 16),
            title: Text(r.text,
                style: TextStyle(
                    fontSize: 13, color: Theme.of(context).hintColor)),
            onTap: () => open(r.ch!),
          );
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'nav_book'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr(lang, 'search_book'),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        }),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(child: Text(tr(lang, 'no_words')))
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: rows.length,
                    itemBuilder: (_, i) => buildRow(rows[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Reads one chapter, with prev/next to move through the whole book in order.
class ChapterReaderScreen extends StatefulWidget {
  final List<Lesson> chapters;
  final int index;
  const ChapterReaderScreen(
      {super.key, required this.chapters, required this.index});
  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  late int _i = widget.index;

  void _go(int delta) {
    final n = _i + delta;
    if (n >= 0 && n < widget.chapters.length) setState(() => _i = n);
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LocaleStore>().lang;
    final repo = context.read<ContentRepository>();
    final ch = widget.chapters[_i];
    final hasPrev = _i > 0;
    final hasNext = _i < widget.chapters.length - 1;
    return Scaffold(
      appBar: AppBar(
        title: Text('${ch.id}. ${ch.topicFor(lang)}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ReadingView(
        key: ValueKey(ch.id),
        title: '${ch.id}. ${ch.topicFor(lang)}',
        levelName: ch.levelName,
        meta: '${repo.partName(ch.part, lang)}  ·  '
            '${tr(lang, 'chapter')} ${ch.id}',
        markdown: ch.grammarFor(lang),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.chevron_left),
                  label: Text(tr(lang, 'prev_chapter')),
                  onPressed: hasPrev ? () => _go(-1) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.chevron_right),
                  label: Text(tr(lang, 'next_chapter')),
                  onPressed: hasNext ? () => _go(1) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
