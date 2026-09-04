import 'package:flutter/material.dart';

import '../models.dart';
import '../strings.dart';

/// The course's build-the-phrase exercise, laid out like the original: the
/// Russian sentence on top, the answer building up under it as tiles, and the
/// choices for the CURRENT position pinned to the bottom above the check
/// button — one row at a time (`did · do · does · will`), not one pile.
///
/// Tapping a placed tile takes it back, so you can correct a step.
class SentenceExercise extends StatefulWidget {
  final PracticeItem item;
  final String lang;
  final void Function(bool correct, String given) onResult;
  const SentenceExercise(
      {super.key,
      required this.item,
      required this.lang,
      required this.onResult});

  @override
  State<SentenceExercise> createState() => _SentenceExerciseState();
}

class _SentenceExerciseState extends State<SentenceExercise> {
  final List<String> _chosen = [];

  int get _step => _chosen.length;
  bool get _finished => _step >= widget.item.rows.length;

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
    widget.onResult(_matches(), given.isEmpty ? '—' : given);
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
            for (var i = 0; i < _chosen.length; i++)
              _Tile(
                label: _chosen[i],
                onTap: () => setState(
                    () => _chosen.removeRange(i, _chosen.length)),
              ),
          ],
        ),
        const Spacer(),
        // choices for the current position, pinned above the button
        if (!_finished) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final word in item.rows[_step])
                  _Tile(
                    label: word,
                    onTap: () => setState(() => _chosen.add(word)),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
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
  final VoidCallback onTap;
  const _Tile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
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
    );
  }
}
