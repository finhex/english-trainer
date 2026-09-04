import 'package:flutter/material.dart';

import '../models.dart';
import '../strings.dart';

String _normTile(String s) =>
    s.toLowerCase().replaceAll(RegExp(r"[^a-zа-яё0-9'\s]"), '').trim();

/// Marks each placed tile right or wrong, the way the original highlights a
/// checked answer rather than only passing or failing it: the longest run of
/// tiles that can be lined up against the slots, in order, counts as right.
List<bool> markTiles(List<List<String>> slots, List<String> chosen) {
  final want = [
    for (final slot in slots) [for (final o in slot) _normTile(o)]
  ];
  final got = [for (final t in chosen) _normTile(t)];
  // dp[i][j] = most tiles still matchable using slots i.. and tiles j..
  final dp = List.generate(
      want.length + 1, (_) => List<int>.filled(got.length + 1, 0));
  for (var i = want.length - 1; i >= 0; i--) {
    for (var j = got.length - 1; j >= 0; j--) {
      var best = dp[i + 1][j]; // skip this slot
      if (want[i].contains(got[j])) {
        final take = 1 + dp[i + 1][j + 1];
        if (take > best) best = take;
      }
      dp[i][j] = best;
    }
  }
  final marks = List<bool>.filled(got.length, false);
  var i = 0, j = 0;
  while (i < want.length && j < got.length) {
    if (want[i].contains(got[j]) && dp[i][j] == 1 + dp[i + 1][j + 1]) {
      marks[j] = true;
      i++;
      j++;
    } else if (dp[i][j] == dp[i + 1][j]) {
      i++;
    } else {
      j++;
    }
  }
  return marks;
}

/// The course's build-the-phrase exercise, laid out like the original: the
/// Russian sentence on top, the answer building up under it as tiles, and the
/// choices for the CURRENT position pinned to the bottom above the check
/// button — one row at a time (`did · do · does · will`), not one pile.
///
/// Tapping a placed tile takes it back, so you can correct a step.
class SentenceExercise extends StatefulWidget {
  final PracticeItem item;
  final String lang;
  final void Function(bool correct, String given, List<String> tiles)
      onResult;
  const SentenceExercise(
      {super.key,
      required this.item,
      required this.lang,
      required this.onResult});

  @override
  State<SentenceExercise> createState() => _SentenceExerciseState();
}

class _SentenceExerciseState extends State<SentenceExercise> {
  // one pick per position (null = still to fill), so the answer keeps the
  // sentence order however the rows were filled
  late final List<String?> _picked =
      List<String?>.filled(widget.item.rows.length, null);

  List<String> get _chosen => [
        for (final p in _picked)
          if (p != null && p.isNotEmpty) p
      ];

  /// The positions still to fill, earliest first — only the first two are shown.
  List<int> get _openRows => [
        for (var r = 0; r < _picked.length; r++)
          if (_picked[r] == null) r
      ];

  bool get _finished => _openRows.isEmpty;

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r"[^a-zа-яё0-9'\s]"), '').trim();

  /// Walks the slots in order, consuming a chosen word when it matches one of
  /// the options and skipping a slot that may be left out.
  bool _matches() {
    final want = [
      for (final slot in widget.item.slots) [for (final o in slot) _norm(o)]
    ];
    final got = [for (final t in _chosen) _norm(t)];
    final seen = <int>{};

    bool walk(int slot, int tile) {
      if (slot == want.length) return tile == got.length;
      final key = slot * (got.length + 1) + tile;
      if (!seen.add(key)) return false;
      final options = want[slot];
      if (tile < got.length && options.contains(got[tile])) {
        if (walk(slot + 1, tile + 1)) return true;
      }
      if (options.contains('')) {
        if (walk(slot + 1, tile)) return true;
      }
      return false;
    }

    return walk(0, 0);
  }

  void _check() {
    final given = _chosen.join(' ');
    widget.onResult(
        _matches(), given.isEmpty ? '—' : given, List<String>.from(_chosen));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final item = widget.item;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr(widget.lang, 'p_sentence'),
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        // the Russian sentence to build
        Text(item.prompt,
            style: TextStyle(
                fontSize: 17,
                height: 1.3,
                color: scheme.onSurface,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted)),
        const SizedBox(height: 12),
        // the answer so far — tap a tile to take it back
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var r = 0; r < _picked.length; r++)
              if (_picked[r] != null)
                _Tile(
                  label: _picked[r]!,
                  onTap: () => setState(() => _picked[r] = null),
                ),
          ],
        ),
        const Spacer(),
        // every position still to fill, in sentence order — one row each, the
        // way the original stacks them (picking from a row removes it)
        if (!_finished)
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1),
                  // only two positions are on screen at a time, earliest
                  // first; filling either one reveals the next
                  for (final r in _openRows.take(2)) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final word in item.rows[r])
                            _Tile(
                              label: word,
                              onTap: () => setState(() => _picked[r] = word),
                            ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _chosen.isEmpty ? null : _check,
          child: Text(tr(widget.lang, 'check')),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _Tile({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: 1,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Text(label,
                style: TextStyle(fontSize: 15, color: scheme.onSurface)),
          ),
        ),
      ),
    );
  }
}
