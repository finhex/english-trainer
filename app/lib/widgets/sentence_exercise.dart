import 'package:flutter/material.dart';

import '../models.dart';
import '../strings.dart';

/// The course's build-the-phrase exercise, laid out the way the original does:
/// the Russian sentence on top, the answer building up under it, and then a
/// ROW OF CHOICES PER POSITION (interchangeable words such as
/// `did · do · does · will`) instead of one shuffled pile of tiles.
///
/// Tapping a word in a row selects it for that position; tapping it again
/// clears it. The answer is checked against the slots, so a position that
/// accepts several words (`a / the`) or may be left out still passes.
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
  // one chosen word per row (null = nothing picked yet)
  late List<String?> _picked;

  @override
  void initState() {
    super.initState();
    _picked = List<String?>.filled(widget.item.rows.length, null);
  }

  List<String> get _chosen =>
      [for (final p in _picked) if (p != null && p.isNotEmpty) p];

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-zа-яё0-9'\s]"), '')
      .trim();

  /// Walks the slots in order, consuming a chosen word when it matches one of
  /// the options and skipping a slot that may be left out.
  bool _matches() {
    final want = [
      for (final slot in widget.item.slots)
        [for (final o in slot) _norm(o)]
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
    final anyPicked = _chosen.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // the Russian sentence to build
        Text(item.prompt,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        // the answer as it is assembled
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _chosen.join(' '),
            style: TextStyle(
                fontSize: 17,
                height: 1.35,
                color: scheme.onSurface,
                fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(height: 16),
        // a row of choices per position
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                for (var r = 0; r < item.rows.length; r++) ...[
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final word in item.rows[r])
                        _Choice(
                          label: word,
                          selected: _picked[r] == word,
                          onTap: () => setState(() {
                            _picked[r] = _picked[r] == word ? null : word;
                          }),
                        ),
                    ],
                  ),
                  if (r != item.rows.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1),
                    ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: anyPicked ? _check : null,
          child: Text(tr(widget.lang, 'check')),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Choice(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(10),
      elevation: selected ? 0 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: selected ? scheme.onPrimary : scheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
