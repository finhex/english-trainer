import 'dart:math';
import 'package:flutter/material.dart';
import '../models.dart';
import '../strings.dart';

/// Choose the missing word. Options = the tied target + closed-set
/// distractors (all pre-built, grammatically valid alternatives).
class GapFillExercise extends StatefulWidget {
  final PracticeItem item;
  final String pos; // word_type: the part of speech to select (localized)
  final String lang;
  final void Function(bool correct, String given) onResult;
  const GapFillExercise(
      {super.key,
      required this.item,
      this.pos = '',
      this.lang = 'en',
      required this.onResult});

  @override
  State<GapFillExercise> createState() => _GapFillExerciseState();
}

class _GapFillExerciseState extends State<GapFillExercise> {
  late final List<String> _options;
  String? _selected;

  @override
  void initState() {
    super.initState();
    _options = [widget.item.answer, ...widget.item.distractors]
      ..shuffle(Random());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.item.type == 'word_type') ...[
          Text('${tr(widget.lang, 'select_the')} ${widget.pos}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${tr(widget.lang, 'which_is_a')} ${widget.pos}?',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: 32),
        ] else ...[
          Text(tr(widget.lang, 'fill_in_gap'),
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 24),
          Text(widget.item.prompt,
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 32),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final o in _options)
              ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 6),
                  child: Text(o, style: const TextStyle(fontSize: 16)),
                ),
                selected: _selected == o,
                showCheckmark: false,
                // constant border width so selection never changes the size
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: _selected == o
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).dividerColor,
                    width: 2,
                  ),
                ),
                onSelected: (_) => setState(() => _selected = o),
              ),
          ],
        ),
        const Spacer(),
        FilledButton(
          onPressed: _selected == null
              ? null
              : () => widget.onResult(
                  _selected == widget.item.answer, _selected ?? ''),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(tr(widget.lang, 'check')),
          ),
        ),
      ],
    );
  }
}
