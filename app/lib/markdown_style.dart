import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;

/// Builders for `Markdown`/`MarkdownBody`. Fenced/indented CODE BLOCKS get our
/// own horizontal scroll + always-visible bottom scrollbar (keeps ASCII-tree
/// alignment); inline `code` falls through to the default styling.
Map<String, MarkdownElementBuilder> markdownBuilders(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return {
    'code': _CodeBlockBuilder(scheme),
    for (final e in kMarks.entries)
      e.value.tag: _MarkBuilder(markColor(context, e.value.tag)),
  };
}

/// The imported course colors its text — blue glosses, gray notes, red
/// warnings, green. Markdown has no color, so the importer keeps each as its
/// own marker and they are painted here.
class MarkSpec {
  final String open; // the markdown marker, e.g. '=='
  final String tag; // the element tag, e.g. 'mark_blue'
  const MarkSpec(this.open, this.tag);
}

const Map<String, MarkSpec> kMarks = {
  'blue': MarkSpec('==', 'mark_blue'),
  'gray': MarkSpec('%%', 'mark_gray'),
  'red': MarkSpec('!!', 'mark_red'),
  'green': MarkSpec('++', 'mark_green'),
};

/// Theme-aware color for a mark tag (readable in light and dark).
Color markColor(BuildContext context, String tag) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  switch (tag) {
    case 'mark_gray':
      return Theme.of(context).hintColor;
    case 'mark_red':
      return dark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F);
    case 'mark_green':
      return dark ? const Color(0xFF62D07A) : const Color(0xFF2E7D32);
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

class _MarkSyntax extends md.InlineSyntax {
  final String tag;
  _MarkSyntax(String marker, this.tag)
      : super('${RegExp.escape(marker)}(.+?)${RegExp.escape(marker)}');
  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.text(tag, match[1]!));
    return true;
  }
}

class _MarkBuilder extends MarkdownElementBuilder {
  final Color color;
  _MarkBuilder(this.color);
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) =>
      Text(element.textContent,
          style: (preferredStyle ?? const TextStyle())
              .copyWith(color: color, fontWeight: FontWeight.w500));
}

/// GitHub-flavored markdown plus our colored-mark inline syntaxes.
md.ExtensionSet get appExtensionSet => md.ExtensionSet(
      md.ExtensionSet.gitHubFlavored.blockSyntaxes,
      [
        ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
        for (final m in kMarks.values) _MarkSyntax(m.open, m.tag),
      ],
    );

/// Render a lesson body as a list of widgets, pulling every GitHub-style pipe
/// TABLE out into our own adaptive table widget (which flutter_markdown can't
/// do — its table either squishes wide tables or leaves narrow ones short) and
/// rendering the prose in between with normal (justified) Markdown.
List<Widget> buildMarkdownBlocks(BuildContext context, String src,
    {String? anchor, Key? anchorKey}) {
  final scheme = Theme.of(context).colorScheme;
  final style = appMarkdownStyle(context);
  final builders = markdownBuilders(context);
  final out = <Widget>[];
  final buf = <String>[];
  // matches the target subsection heading, e.g. "### 15.1 ..." for anchor "15.1"
  final anchorRe = anchor == null
      ? null
      : RegExp('^#{2,6}\\s+${RegExp.escape(anchor)}(\\D|\$)');
  var anchored = false;

  void flush() {
    if (buf.isNotEmpty) {
      out.add(MarkdownBody(
          data: buf.join('\n'),
          styleSheet: style,
          builders: builders,
          extensionSet: appExtensionSet,
          selectable: false));
      buf.clear();
    }
  }

  final lines = src.split('\n');
  var i = 0;
  while (i < lines.length) {
    final trimmed = lines[i].trimLeft();
    // target subsection heading → flush and drop a keyed marker to scroll to
    if (!anchored && anchorRe != null && anchorRe.hasMatch(trimmed)) {
      flush();
      out.add(SizedBox(key: anchorKey, height: 0));
      anchored = true;
    }
    // fenced code block (``` or ~~~) → our own full-width grey block
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      flush();
      final marker = trimmed.substring(0, 3);
      final info = trimmed.substring(3).trim();
      final code = <String>[];
      i++;
      while (i < lines.length && !lines[i].trimLeft().startsWith(marker)) {
        code.add(lines[i]);
        i++;
      }
      if (i < lines.length) i++; // skip the closing fence
      // the course's conjugation box travels as structured data, not a table
      if (info == 'conj') {
        try {
          final data = json.decode(code.join('\n')) as Map<String, dynamic>;
          out.add(ConjBox(data: data));
          continue;
        } catch (_) {
          // fall through and show it as a code block
        }
      }
      out.add(_CodeBlock(text: code.join('\n'), scheme: scheme));
      continue;
    }
    final next = i + 1 < lines.length ? lines[i + 1] : '';
    // a table = a header row with '|' immediately followed by a |---|---| rule
    if (lines[i].contains('|') && _isTableSeparator(next)) {
      flush();
      final block = <String>[lines[i], next];
      i += 2;
      while (i < lines.length &&
          lines[i].contains('|') &&
          lines[i].trim().isNotEmpty) {
        block.add(lines[i]);
        i++;
      }
      out.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: _MdTable(rows: _parseTable(block), scheme: scheme),
      ));
    } else {
      buf.add(lines[i]);
      i++;
    }
  }
  flush();
  return out;
}

bool _isTableSeparator(String s) {
  final t = s.trim();
  return t.contains('|') &&
      t.contains('-') &&
      RegExp(r'^[\s:|-]+$').hasMatch(t);
}

List<List<String>> _parseTable(List<String> block) {
  final rows = <List<String>>[];
  for (final raw in block) {
    final line = raw.trim();
    if (line.isEmpty || !line.contains('|')) continue;
    if (_isTableSeparator(line)) continue; // the |---|---| rule
    var s = line;
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    rows.add(s.split('|').map((c) => c.trim()).toList());
  }
  return rows;
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  final ColorScheme scheme;
  _CodeBlockBuilder(this.scheme);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    var text = element.textContent;
    if (!text.contains('\n')) return null; // inline code → default
    if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
    return _CodeBlock(text: text, scheme: scheme);
  }
}

/// A code block that FILLS the width with a grey background, keeps its
/// monospace/ASCII alignment (no wrapping), and scrolls sideways with an
/// always-visible bottom scrollbar when the content is wider than the screen.
class _CodeBlock extends StatelessWidget {
  final String text;
  final ColorScheme scheme;
  const _CodeBlock({required this.text, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: HScroll(
        // grey wraps only the code (the scroll bar sits below, outside it)
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Text(
          text,
          softWrap: false,
          style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.35,
              color: scheme.onSurface),
        ),
      ),
    );
  }
}

/// An adaptive markdown table. Up to 3 columns stretch to fill the full width
/// (no empty gap, no overflow); 4+ columns keep a readable fixed width and
/// scroll sideways with an always-visible bottom scrollbar.
class _MdTable extends StatelessWidget {
  final List<List<String>> rows;
  final ColorScheme scheme;
  const _MdTable({required this.rows, required this.scheme});

  // minimal inline markdown → styled spans (bold / italic / code)
  InlineSpan _inline(String text, TextStyle base) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'==(.+?)==|%%(.+?)%%|!!(.+?)!!|\+\+(.+?)\+\+'
        r'|\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`|_(.+?)_');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start), style: base));
      }
      // the course's colored text, in cells too
      if (m.group(1) != null) {
        spans.add(TextSpan(
            text: m.group(1),
            style: base.copyWith(
                color: scheme.primary, fontWeight: FontWeight.w500)));
      } else if (m.group(2) != null) {
        spans.add(TextSpan(
            text: m.group(2),
            style: base.copyWith(color: scheme.onSurfaceVariant)));
      } else if (m.group(3) != null) {
        spans.add(TextSpan(
            text: m.group(3),
            style: base.copyWith(
                color: const Color(0xFFD32F2F), fontWeight: FontWeight.w500)));
      } else if (m.group(4) != null) {
        spans.add(TextSpan(
            text: m.group(4),
            style: base.copyWith(
                color: const Color(0xFF2E7D32), fontWeight: FontWeight.w500)));
      } else if (m.group(5) != null) {
        spans.add(TextSpan(
            text: m.group(5),
            style: base.copyWith(fontWeight: FontWeight.bold)));
      } else if (m.group(6) != null) {
        spans.add(TextSpan(
            text: m.group(6),
            style: base.copyWith(fontStyle: FontStyle.italic)));
      } else if (m.group(7) != null) {
        spans.add(TextSpan(
            text: m.group(7), style: base.copyWith(fontFamily: 'monospace')));
      } else if (m.group(8) != null) {
        spans.add(TextSpan(
            text: m.group(8),
            style: base.copyWith(fontStyle: FontStyle.italic)));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last), style: base));
    }
    return TextSpan(children: spans);
  }

  TableRow _row(List<String> cells, bool head, int cols,
      {bool stackItems = false}) {
    final base = TextStyle(
        fontSize: 13,
        height: 1.3,
        color: scheme.onSurface,
        fontWeight: head ? FontWeight.bold : FontWeight.normal);
    final padded = [...cells];
    while (padded.length < cols) {
      padded.add('');
    }
    return TableRow(
      children: [
        for (final c in padded)
          Padding(
            // the conjugation box hugs its content, so its columns need a
            // little more air between them
            padding: stackItems
                ? const EdgeInsets.fromLTRB(14, 6, 22, 6)
                : const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
            // the course stacks interchangeable words (I / you / we / they)
            // down a cell; markdown can't hold a newline in one, so the
            // importer joins them with " · " and they are split back here
            child: stackItems && c.contains(' · ')
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final part in c.split(' · '))
                        Text.rich(_inline(
                            part.trim(),
                            base.copyWith(
                                fontSize: 12.5, fontStyle: FontStyle.italic))),
                    ],
                  )
                : Text.rich(_inline(c, base),
                    textAlign: head ? TextAlign.center : TextAlign.left),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    // A table whose first row is blank has no real header — drop it and style
    // every row as a data row. The importer additionally marks the course's
    // conjugation boxes (all cells border:none in the source) with a sentinel,
    // so those render as a borderless card while ruled tables keep their lines.
    final firstCell = rows.first.isEmpty ? '' : rows.first.first.trim();
    final isCard = firstCell == '~card~';
    final headless = isCard || rows.first.every((c) => c.trim().isEmpty);
    final body = headless ? rows.sublist(1) : rows;
    if (body.isEmpty) return const SizedBox.shrink();
    final cols = body.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    // A headless table is a course conjugation box: the original draws it as
    // ONE tinted, bordered card with no lines between the cells.
    final border = isCard
        ? const TableBorder()
        : TableBorder.all(color: scheme.outlineVariant, width: 0.7);
    final children = [
      for (var i = 0; i < body.length; i++)
        _row(body[i], !headless && i == 0, cols, stackItems: isCard)
    ];

    // Decide by AVAILABLE width, not column count: if every column can get at
    // least a readable minimum, stretch them to FILL the width (no empty gap);
    // otherwise keep a comfortable fixed width and scroll sideways (better than
    // squishing a many-column table to one word per line).
    const minCol = 150.0;
    // the course's conjugation box: one tinted, softly bordered card
    Widget card(Widget child) => isCard
        ? Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              border: Border.all(color: const Color(0xFF87C9FF)),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: child,
          )
        : child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        // The course's conjugation box is an HTML table with no width, so it
        // shrinks to fit its content — columns sized to their text, the whole
        // box only as wide as it needs, left-aligned in the flow.
        if (isCard) {
          return Align(
            alignment: Alignment.centerLeft,
            child: IntrinsicWidth(
              child: card(Table(
                defaultColumnWidth: const IntrinsicColumnWidth(),
                border: border,
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: children,
              )),
            ),
          );
        }
        if (cols * minCol <= avail) {
          // A table stretched across a 1900px desktop window gives absurdly
          // wide cells, so cap the TABLE (the prose around it stays full width).
          const maxTable = 900.0;
          final table = Table(
            defaultColumnWidth: const FlexColumnWidth(),
            border: border,
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: children,
          );
          if (avail <= maxTable) return card(table);
          return Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxTable),
              child: card(table),
            ),
          );
        }
        return HScroll(
          forceVisible: true, // this branch is only used when it overflows
          padding: const EdgeInsets.only(bottom: 14),
          child: card(Table(
            defaultColumnWidth: const FixedColumnWidth(150),
            border: border,
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: children,
          )),
        );
      },
    );
  }
}

/// Horizontal scroll with a real scroll indicator laid out BELOW the content
/// (only shown when the content overflows). A plain overlay Scrollbar paints
/// over the last row and mis-positions when the block is taller than the screen
/// — an under-bar sits cleanly below the table/code and tracks the position.
class HScroll extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool forceVisible; // caller knows the content overflows (wide table)
  final BoxDecoration? decoration; // wraps ONLY the scroll area (bar stays out)
  final Color? thumbColor; // defaults to the accent colour
  const HScroll(
      {super.key,
      required this.child,
      this.thumbColor,
      this.padding = EdgeInsets.zero,
      this.forceVisible = false,
      this.decoration});
  @override
  State<HScroll> createState() => HScrollState();
}

class HScrollState extends State<HScroll> {
  final ScrollController _c = ScrollController();
  bool _scrollable = false;
  double _frac = 0; // 0..1 scroll position
  double _viewFrac = 1; // viewport / total (thumb width fraction)

  @override
  void initState() {
    super.initState();
    _c.addListener(_update);
    _scheduleUpdate();
  }

  // retry until the scroll view has attached its controller, then measure
  void _scheduleUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_c.hasClients) {
        _scheduleUpdate();
        return;
      }
      _update();
    });
  }

  @override
  void dispose() {
    _c.removeListener(_update);
    _c.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || !_c.hasClients) return;
    final p = _c.position;
    final max = p.maxScrollExtent;
    final vp = p.viewportDimension;
    final total = max + vp;
    final scrollable = max > 1.0;
    final viewFrac = total > 0 ? (vp / total).clamp(0.10, 1.0) : 1.0;
    final frac = max > 0 ? (p.pixels / max).clamp(0.0, 1.0) : 0.0;
    if (scrollable != _scrollable ||
        (viewFrac - _viewFrac).abs() > 0.002 ||
        (frac - _frac).abs() > 0.002) {
      setState(() {
        _scrollable = scrollable;
        _viewFrac = viewFrac;
        _frac = frac;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // re-measure after each layout (content size / text-scale changes)
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
    final showBar = _scrollable || widget.forceVisible;
    // let a MOUSE drag the content sideways too (desktop has no touch and the
    // wheel scrolls the page vertically)
    final behavior = ScrollConfiguration.of(context).copyWith(dragDevices: {
      PointerDeviceKind.touch,
      PointerDeviceKind.mouse,
      PointerDeviceKind.trackpad,
      PointerDeviceKind.stylus,
    });
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: widget.decoration,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _update());
              return false;
            },
            child: ScrollConfiguration(
              behavior: behavior,
              child: SingleChildScrollView(
                controller: _c,
                scrollDirection: Axis.horizontal,
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
        if (showBar)
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 5, 2, 2),
            child: LayoutBuilder(
              builder: (context, cns) {
                final trackW = cns.maxWidth;
                final thumbW = (trackW * _viewFrac).clamp(28.0, trackW);
                final left = (trackW - thumbW) * _frac;
                final denom = trackW - thumbW;

                void jumpToThumbLeft(double thumbLeft) {
                  if (!_c.hasClients) return;
                  final max = _c.position.maxScrollExtent;
                  final f =
                      denom > 0 ? (thumbLeft / denom).clamp(0.0, 1.0) : 0.0;
                  _c.jumpTo(f * max);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) =>
                      jumpToThumbLeft(d.localPosition.dx - thumbW / 2),
                  onHorizontalDragUpdate: (d) {
                    if (!_c.hasClients) return;
                    final max = _c.position.maxScrollExtent;
                    final delta = denom > 0 ? d.delta.dx / denom * max : 0.0;
                    _c.jumpTo((_c.position.pixels + delta).clamp(0.0, max));
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    // explicit-width track (an unsized DecoratedBox in a Stack
                    // collapses to 0 → the bar was invisible everywhere)
                    child: SizedBox(
                      width: trackW,
                      height: 14,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 5,
                            child: Container(
                              height: 5,
                              decoration: BoxDecoration(
                                color: scheme.outlineVariant
                                    .withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          Positioned(
                            left: left,
                            top: 3,
                            child: Container(
                              width: thumbW,
                              height: 8,
                              decoration: BoxDecoration(
                                color: widget.thumbColor ?? scheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// The shared reading view for a lesson OR a guide: a "where am I" header
/// (full title + level + chapter), the markdown body (adaptive tables +
/// full-width code blocks + justified prose) and optional trailing widgets
/// (e.g. the practice cards), all in one smooth vertical scroll.
class ReadingView extends StatelessWidget {
  final String title;
  final String levelName; // '' → no level chip (guides)
  final String meta; // already-localized "Lesson 5 · Chapter 33"
  final String markdown;
  final List<Widget> trailing;
  final String? anchor; // subsection number to scroll to (e.g. "15.1")
  final Key? anchorKey;
  const ReadingView({
    super.key,
    required this.title,
    required this.levelName,
    required this.meta,
    required this.markdown,
    this.trailing = const [],
    this.anchor,
    this.anchorKey,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // keep the last lines clear of the Android system nav bar (3 buttons)
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Scrollbar(
      // ignore notifications bubbling up from inner horizontal scrolls so the
      // vertical scroll never jumps when a table/code block is swiped
      notificationPredicate: (n) => n.depth == 0,
      child: SingleChildScrollView(
        primary: true,
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (levelName.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(levelName,
                        style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
                if (meta.isNotEmpty)
                  Text(meta,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: scheme.primary)),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            ...buildMarkdownBlocks(context, markdown,
                anchor: anchor, anchorKey: anchorKey),
            ...trailing,
          ],
        ),
      ),
    );
  }
}

/// A theme-aware markdown style with readable blockquotes and code blocks in
/// both light and dark mode (the default blockquote is light-on-light).
MarkdownStyleSheet appMarkdownStyle(BuildContext context) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    // justify paragraph text (both edges aligned, book-style). spaceBetween is
    // flutter_markdown's WrapAlignment that maps to TextAlign.justify.
    textAlign: WrapAlignment.spaceBetween,
    blockquotePadding: const EdgeInsets.all(12),
    blockquoteDecoration: BoxDecoration(
      color: scheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: scheme.primary, width: 4)),
    ),
    blockquote:
        TextStyle(color: scheme.onPrimaryContainer, fontSize: 15, height: 1.35),
    code: TextStyle(
      backgroundColor: scheme.surfaceContainerHighest,
      color: scheme.onSurface,
      fontFamily: 'monospace',
      fontSize: 14,
    ),
    codeblockPadding: const EdgeInsets.all(10),
    codeblockDecoration: BoxDecoration(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(6),
    ),
  );
}

/// The course's conjugation box: one bordered card holding side-by-side
/// PANELS, each a small grid of `aux | pronouns | verb`, with the panel being
/// taught highlighted. Markdown tables cannot express that nesting, so the
/// importer ships the box as structured data and it is drawn here.
class ConjBox extends StatelessWidget {
  final Map<String, dynamic> data;
  const ConjBox({super.key, required this.data});

  static const _blue = Color(0xFF87C9FF); // the original's border

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panels = (data['panels'] as List?) ?? const [];
    if (panels.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _blue),
            borderRadius: BorderRadius.circular(6),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var p = 0; p < panels.length; p++)
                  _panel(context, (panels[p] as Map).cast<String, dynamic>(),
                      scheme, dark,
                      last: p == panels.length - 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context, Map<String, dynamic> panel,
      ColorScheme scheme, bool dark,
      {required bool last}) {
    final hl = panel['hl'] == true;
    final rows = (panel['rows'] as List?) ?? const [];
    return Container(
      decoration: BoxDecoration(
        color: hl
            ? (dark
                ? scheme.primary.withValues(alpha: 0.22)
                : const Color(0xFFBCE1FF))
            : (dark
                ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
                : const Color(0xFFEEEEEE)),
        border: last ? null : const Border(right: BorderSide(color: _blue)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final c in (r as List))
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _cell(
                          context, (c as Map).cast<String, dynamic>(), scheme),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(
      BuildContext context, Map<String, dynamic> cell, ColorScheme scheme) {
    final base = TextStyle(fontSize: 14, height: 1.35, color: scheme.onSurface);
    final items = (cell['items'] as List?)?.cast<String>();
    if (items != null) {
      // the interchangeable pronouns, stacked small and italic
      final style = base.copyWith(
          fontSize: 12.5,
          fontStyle: FontStyle.italic,
          color: Theme.of(context).hintColor);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [for (final it in items) Text(it, style: style)],
      );
    }
    return Text.rich(
        markedSpans((cell['text'] as String?) ?? '', base, context));
  }
}

/// Inline markdown with our colored marks, as a span (shared by the tables and
/// the conjugation box).
InlineSpan markedSpans(String text, TextStyle base, BuildContext context) {
  final spans = <InlineSpan>[];
  final re = RegExp(r'==(.+?)==|%%(.+?)%%|!!(.+?)!!|\+\+(.+?)\+\+'
      r'|\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`|_(.+?)_');
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) {
      spans.add(TextSpan(text: text.substring(last, m.start), style: base));
    }
    if (m.group(1) != null) {
      spans.add(TextSpan(
          text: m.group(1),
          style: base.copyWith(color: markColor(context, 'mark_blue'))));
    } else if (m.group(2) != null) {
      spans.add(TextSpan(
          text: m.group(2),
          style: base.copyWith(color: markColor(context, 'mark_gray'))));
    } else if (m.group(3) != null) {
      spans.add(TextSpan(
          text: m.group(3),
          style: base.copyWith(color: markColor(context, 'mark_red'))));
    } else if (m.group(4) != null) {
      spans.add(TextSpan(
          text: m.group(4),
          style: base.copyWith(color: markColor(context, 'mark_green'))));
    } else if (m.group(5) != null) {
      spans.add(TextSpan(
          text: m.group(5), style: base.copyWith(fontWeight: FontWeight.bold)));
    } else if (m.group(6) != null) {
      spans.add(TextSpan(
          text: m.group(6), style: base.copyWith(fontStyle: FontStyle.italic)));
    } else if (m.group(7) != null) {
      spans.add(TextSpan(
          text: m.group(7), style: base.copyWith(fontFamily: 'monospace')));
    } else if (m.group(8) != null) {
      spans.add(TextSpan(
          text: m.group(8), style: base.copyWith(fontStyle: FontStyle.italic)));
    }
    last = m.end;
  }
  if (last < text.length) {
    spans.add(TextSpan(text: text.substring(last), style: base));
  }
  return TextSpan(children: spans);
}
