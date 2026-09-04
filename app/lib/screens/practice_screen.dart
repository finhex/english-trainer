import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../content_repository.dart';
import '../locale_store.dart';
import '../models.dart';
import '../progress_store.dart';
import '../strings.dart';
import '../widgets/page_width.dart';
import '../tts_service.dart';
import '../widgets/word_order_exercise.dart';
import '../widgets/gap_fill_exercise.dart';
import '../widgets/sentence_exercise.dart';

/// The practice engine for ONE practice mode (word_order OR gap_fill).
///
/// Rules:
///  * reach 70 net-correct to complete this practice;
///  * correct +1, wrong -1 (never below 0);
///  * a wrong answer reveals the correct sentence with audio;
///  * the feedback panel always shows YOUR answer and whether it was right;
///  * items cycle (reshuffled each pass) until the goal is reached.
const Color kGood = Color(0xFF3CA84B); // correct — green
const Color kBad = Color(0xFFD32F2F); // incorrect — red

class PracticeScreen extends StatefulWidget {
  final int lessonId;
  final String type; // 'word_order' | 'gap_fill'
  const PracticeScreen({super.key, required this.lessonId, required this.type});
  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final Lesson _lesson;
  late final List<PracticeItem> _pool;
  late final TtsService _tts;
  final _rng = Random();

  late List<int> _order; // indices into _pool for the current pass
  int _pos = 0;
  int _correct = 0;

  bool _showingFeedback = false;
  bool _lastWasCorrect = false;
  String _userAnswer = '';
  List<String> _userTiles = const [];

  late final int _goal;
  late final String _rawPos; // English POS key ('noun'…) for word_type

  @override
  void initState() {
    super.initState();
    final repo = context.read<ContentRepository>();
    _lesson = repo.byId(widget.lessonId);
    _goal = _lesson.goalFor(widget.type); // per-practice goal for this lesson
    _rawPos = _lesson.posFor(widget.type); // word_type part of speech
    _pool = _lesson.itemsOfType(widget.type);
    _tts = TtsService();
    // resume from saved progress if the user left mid-practice
    _correct = context
        .read<ProgressStore>()
        .practiceProgress(widget.lessonId, widget.type);
    _newPass();
  }

  @override
  void dispose() {
    _tts.dispose();
    super.dispose();
  }

  void _newPass() {
    _order = List<int>.generate(_pool.length, (i) => i)..shuffle(_rng);
    _pos = 0;
  }

  PracticeItem get _item => _pool[_order[_pos]];

  void _onResult(bool correct, String given) {
    setState(() {
      _userAnswer = given;
      _lastWasCorrect = correct;
      _showingFeedback = true;
      if (correct) {
        _correct = min(_goal, _correct + 1);
      } else {
        _correct = max(0, _correct - 1);
        _tts.speak(_item.answer);
      }
    });
    // persist after every answer so closing the app keeps your place
    context
        .read<ProgressStore>()
        .setPracticeProgress(widget.lessonId, widget.type, _correct);
  }

  void _next() {
    if (_correct >= _goal) {
      context
          .read<ProgressStore>()
          .markPracticeCompleted(_lesson.id, widget.type);
      _showComplete();
      return;
    }
    setState(() {
      _showingFeedback = false;
      _pos++;
      if (_pos >= _order.length) _newPass();
    });
  }

  String get _lang => context.read<LocaleStore>().lang;
  String get _label => practiceLabel(_lang, widget.type);
  String get _posLoc => posName(_lang, _rawPos);

  void _showComplete() {
    final lang = _lang;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text('${tr(lang, 'practice_complete')} 🎉'),
        content: Text(
            '"${practiceLabel(lang, widget.type)}" · $_goal ${tr(lang, 'correct_answers')}'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // dialog
              Navigator.of(context).pop(); // practice screen
            },
            child: Text(tr(lang, 'done')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleStore>(); // rebuild on language change
    final lang = _lang;
    return Scaffold(
      appBar: AppBar(
        // two-line title needs the extra height, or the subtitle is clipped
        toolbarHeight: 68,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_lesson.topicFor(lang),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
                '${tr(lang, 'lesson')} ${_lesson.displayNo} · $_label',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: PageWidth(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: _correct / _goal,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('$_correct / $_goal'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: PageWidth(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _showingFeedback ? _feedback() : _exercise(),
          ),
        ),
      ),
    );
  }

  Widget _exercise() {
    final item = _item;
    final key = ValueKey('${_pos}_${_correct}_${item.answer}');
    switch (item.type) {
      case 'sentence':
        return SentenceExercise(
            key: key,
            item: item,
            lang: _lang,
            onResult: (correct, given, tiles) {
              _userTiles = tiles;
              _onResult(correct, given);
            });
      case 'gap_fill':
      case 'word_type':
        return GapFillExercise(
            key: key,
            item: item,
            pos: _posLoc,
            lang: _lang,
            onResult: _onResult);
      case 'word_order':
      default:
        return WordOrderExercise(
            key: key, item: item, lang: _lang, onResult: _onResult);
    }
  }

  Widget _feedback() {
    final ok = _lastWasCorrect;
    final lang = _lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ok ? kGood : kBad,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(ok ? Icons.check_circle : Icons.cancel, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  ok ? tr(lang, 'correct') : tr(lang, 'incorrect'),
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.volume_up, color: Colors.white),
                onPressed: () => _tts.speak(_item.answer),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Show the question that was asked.
        Text(tr(lang, 'question'),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme.of(context).hintColor)),
        const SizedBox(height: 2),
        Text(
          _item.type == 'word_order'
              ? tr(lang, 'put_words_order')
              : _item.type == 'word_type'
                  ? '${tr(lang, 'select_the')} $_posLoc'
                  : _item.prompt,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        // What the learner answered. For the course exercise each placed tile
        // is marked right or wrong, the way the original highlights a checked
        // answer rather than only passing or failing it.
        if (_item.type == 'sentence' && _userTiles.isNotEmpty)
          _MarkedTiles(
              label: tr(lang, 'your_answer'),
              tiles: _userTiles,
              marks: markTiles(_item.slots, _userTiles))
        else
          _AnswerRow(
            label: tr(lang, 'your_answer'),
            text: _userAnswer.isEmpty ? '—' : _userAnswer,
            good: ok,
          ),
        if (!ok) ...[
          const SizedBox(height: 12),
          _AnswerRow(
              label: tr(lang, 'correct_answer'),
              text: _item.answer,
              good: true),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _next,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(tr(lang, 'next')),
          ),
        ),
      ],
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final String label;
  final String text;
  final bool good;
  const _AnswerRow(
      {required this.label, required this.text, required this.good});

  @override
  Widget build(BuildContext context) {
    final color = good ? kGood : kBad;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: Theme.of(context).hintColor)),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(good ? Icons.check : Icons.close, size: 18, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ],
    );
  }
}


/// The learner's placed tiles, each colored by whether it fits the sentence.
class _MarkedTiles extends StatelessWidget {
  final String label;
  final List<String> tiles;
  final List<bool> marks;
  const _MarkedTiles(
      {required this.label, required this.tiles, required this.marks});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12.5, color: Theme.of(context).hintColor)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < tiles.length; i++)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (i < marks.length && marks[i] ? kGood : kBad)
                      .withValues(alpha: 0.15),
                  border: Border.all(
                      color: i < marks.length && marks[i] ? kGood : kBad),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(tiles[i],
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: i < marks.length && marks[i] ? kGood : kBad)),
              ),
          ],
        ),
      ],
    );
  }
}
