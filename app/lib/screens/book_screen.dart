import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content_repository.dart';
import '../locale_store.dart';
import '../markdown_style.dart';
import '../models.dart';
import '../strings.dart';

// numbered subsection ("### 15.1 Title", "#### 15.1.1 Title")
final _subRe = RegExp(r'^#{2,4}\s+(\d+\.\d+(?:\.\d+)*)\s+(.*)$', multiLine: true);
// num, display title, and `hay` = lowercased heading + body text (for search)
final _subsCache = <String, List<({String num, String title, String hay})>>{};

int _roman(String s) {
  const m = {'I': 1, 'V': 5, 'X': 10, 'L': 50, 'C': 100, 'D': 500, 'M': 1000};
  var total = 0, prev = 0;
  for (final ch in s.toUpperCase().split('').reversed) {
    final v = m[ch] ?? 0;
    if (v < prev) {
      total -= v;
    } else {
      total += v;
      prev = v;
    }
  }
  return total;
}

// a Part's Arabic number + suffix, e.g. "PART XI-B" -> (11, "b"), "PART II" -> (2, "")
final _partNumCache = <String, (int, String)>{};
(int, String) _partNum(String rawPart) => _partNumCache.putIfAbsent(rawPart, () {
      final m = RegExp(r'PART\s+([IVXLCDM]+)(-?[A-Za-z]*)', caseSensitive: false)
          .firstMatch(rawPart);
      if (m == null) return (0, '');
      return (_roman(m.group(1)!),
          (m.group(2) ?? '').replaceAll('-', '').toLowerCase());
    });

List<({String num, String title, String hay})> _subsOf(Lesson ch, String lang) =>
    _subsCache.putIfAbsent('${ch.id}_$lang', () {
      final md = ch.grammarFor(lang);
      final ms = _subRe.allMatches(md).toList();
      return [
        for (var k = 0; k < ms.length; k++)
          (
            num: ms[k].group(1)!,
            title: ms[k].group(2)!.trim(),
            // this subsection's text (heading → next subsection heading)
            hay: md
                .substring(ms[k].start,
                    k + 1 < ms.length ? ms[k + 1].start : md.length)
                .toLowerCase(),
          )
      ];
    });

/// One flat TOC row: a Part header, a chapter, or a subsection.
class _Row {
  final int kind; // 0 = part, 1 = chapter, 2 = subsection
  final String text;
  final Lesson? ch;
  final String? subNum; // subsection anchor (e.g. "15.1")
  const _Row(this.kind, this.text, [this.ch, this.subNum]);
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
  final ScrollController _list = ScrollController();

  // update the query and jump the results back to the top (a fresh search
  // shouldn't leave you scrolled halfway down the previous results)
  void _resetQuery(String v) {
    setState(() => _query = v.trim());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_list.hasClients) _list.jumpTo(0);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _list.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ContentRepository>();
    final lang = context.watch<LocaleStore>().lang;
    final order = repo.bookOrder;
    final scheme = Theme.of(context).colorScheme;
    final q = _query.toLowerCase();

    // "part 2", "part 11-b", "part 11 b", "part2", "часть 2" → exact Part-number query
    final pq =
        RegExp(r'^(?:part|часть)\s*(\d+)\s*-?\s*([a-z]?)$').firstMatch(q);
    final pqNum = pq != null ? int.parse(pq.group(1)!) : -1;
    final pqSuf = pq?.group(2) ?? '';

    bool chMatches(Lesson ch) {
      if (pq != null) {
        final (n, s) = _partNum(ch.part);
        return n == pqNum && (pqSuf.isEmpty || s == pqSuf);
      }
      return ch.title.toLowerCase().contains(q) ||
          ch.titleRu.toLowerCase().contains(q) ||
          repo.partName(ch.part, lang).toLowerCase().contains(q) ||
          ch.grammarFor(lang).toLowerCase().contains(q);
    }

    // build the flat row list (Part header, chapters, subsections), filtered
    final rows = <_Row>[];
    String? currentPart;
    for (final ch in order) {
      final subs = _subsOf(ch, lang);
      bool include;
      List<({String num, String title, String hay})> subShow;
      if (q.isEmpty) {
        include = true;
        subShow = subs;
      } else if (pq != null) {
        // exact Part-number query: keep only chapters of that Part
        include = chMatches(ch);
        subShow = subs;
      } else {
        // free text: match against each subsection's own text, so we can point
        // to the exact subsection (not just "somewhere in this chapter")
        final subM = subs.where((s) => s.hay.contains(q)).toList();
        final struct = ch.title.toLowerCase().contains(q) ||
            ch.titleRu.toLowerCase().contains(q) ||
            repo.partName(ch.part, lang).toLowerCase().contains(q);
        final body = ch.grammarFor(lang).toLowerCase().contains(q);
        include = struct || subM.isNotEmpty || body;
        // show the matching subsections when there are any; otherwise all
        subShow = subM.isNotEmpty ? subM : subs;
      }
      if (!include) continue;
      if (ch.part != currentPart) {
        currentPart = ch.part;
        rows.add(_Row(0, repo.partName(ch.part, lang)));
      }
      rows.add(_Row(1, ch.topicFor(lang), ch));
      for (final s in subShow) {
        rows.add(_Row(2, '${s.num}  ${s.title}', ch, s.num));
      }
    }

    void open(Lesson ch, {String? anchor}) =>
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => ChapterReaderScreen(
              chapters: order, index: order.indexOf(ch), anchor: anchor),
        ));

    // highlight the free-text query inside a row's text
    Widget hl(String text, TextStyle base) {
      if (q.isEmpty || pq != null || !text.toLowerCase().contains(q)) {
        return Text(text, style: base);
      }
      final lc = text.toLowerCase();
      final spans = <TextSpan>[];
      var start = 0;
      for (var idx = lc.indexOf(q); idx >= 0; idx = lc.indexOf(q, start)) {
        if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
        spans.add(TextSpan(
            text: text.substring(idx, idx + q.length),
            style: TextStyle(
                backgroundColor: scheme.primary.withValues(alpha: 0.25),
                fontWeight: FontWeight.bold)));
        start = idx + q.length;
      }
      if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
      return Text.rich(TextSpan(style: base, children: spans));
    }

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
            title: hl(r.text, const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => open(r.ch!),
          );
        default: // subsection
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.only(left: 62, right: 16),
            title: hl(r.text,
                TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
            onTap: () => open(r.ch!, anchor: r.subNum),
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
                          _resetQuery('');
                        }),
              ),
              onChanged: _resetQuery,
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? Center(child: Text(tr(lang, 'no_words')))
                : ListView.builder(
                    controller: _list,
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
  final String? anchor; // subsection to scroll to on open (e.g. "15.1")
  const ChapterReaderScreen(
      {super.key, required this.chapters, required this.index, this.anchor});
  @override
  State<ChapterReaderScreen> createState() => _ChapterReaderScreenState();
}

class _ChapterReaderScreenState extends State<ChapterReaderScreen> {
  late int _i = widget.index;
  String? _anchor; // only for the initial chapter, cleared after use / nav
  final GlobalKey _anchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _anchor = widget.anchor;
    if (_anchor != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _anchorKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 350), alignment: 0.02);
        }
      });
    }
  }

  void _go(int delta) {
    final n = _i + delta;
    if (n >= 0 && n < widget.chapters.length) {
      setState(() {
        _i = n;
        _anchor = null; // navigating to a new chapter: start at the top
      });
    }
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
        anchor: _anchor,
        anchorKey: _anchor != null ? _anchorKey : null,
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
