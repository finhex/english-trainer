import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../strings.dart';

/// Tap word-tiles to assemble the sentence (the "Соберите фразу" exercise).
/// Correct tiles + distractors are shuffled; the answer must match the
/// pre-built token order exactly.
class WordOrderExercise extends StatefulWidget {
  final PracticeItem item;
  final String lang;
  final void Function(bool correct, String given) onResult;
  const WordOrderExercise(
      {super.key,
      required this.item,
      this.lang = 'en',
      required this.onResult});

  @override
  State<WordOrderExercise> createState() => _WordOrderExerciseState();
}

class _Tile {
  final String text;
  final bool isDistractor;
  _Tile(this.text, this.isDistractor);
}

class _WordOrderExerciseState extends State<WordOrderExercise> {
  late final List<_Tile> _tray; // available tiles
  final List<_Tile> _answer = []; // assembled answer

  @override
  void initState() {
    super.initState();
    _tray = [
      ...widget.item.tokens.map((t) => _Tile(t, false)),
      ...widget.item.distractors.map((t) => _Tile(t, true)),
    ]..shuffle(Random());
  }

  void _pick(_Tile t) => setState(() {
        _tray.remove(t);
        _answer.add(t);
      });

  void _unpick(_Tile t) => setState(() {
        _answer.remove(t);
        _tray.add(t);
      });

  void _check() {
    final assembled = _answer.map((t) => t.text).toList();
    widget.onResult(
        _listEquals(assembled, widget.item.tokens), assembled.join(' '));
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tr(widget.lang, 'put_words_order'),
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        // assembled answer area
        Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _answer)
                _TileChip(text: t.text, onTap: () => _unpick(t)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // available tiles
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _tray)
              _TileChip(text: t.text, onTap: () => _pick(t)),
          ],
        ),
        const Spacer(),
        FilledButton(
          onPressed: _answer.isEmpty ? null : _check,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(tr(widget.lang, 'check')),
          ),
        ),
      ],
    );
  }
}

class _TileChip extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _TileChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(text, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}
