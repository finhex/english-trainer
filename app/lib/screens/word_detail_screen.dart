import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../locale_store.dart';
import '../strings.dart';
import '../vocab_models.dart';
import '../vocab_repository.dart';
import '../words_store.dart';
import '../tts_service.dart';

/// Part-of-speech label: English in EN mode, "noun (существительное)" in RU
/// mode so both languages are visible.
String _posLabel(String lang, String pos) => lang == 'ru'
    ? '${posName('en', pos)} (${posName('ru', pos)})'
    : posName('en', pos);

/// A distinct color per part of speech (chips / headers).
Color _posColor(String pos) {
  switch (pos) {
    case 'noun':
      return const Color(0xFF2F80ED); // blue
    case 'verb':
      return const Color(0xFF27AE60); // green
    case 'adjective':
      return const Color(0xFFE67E22); // orange
    case 'adverb':
      return const Color(0xFF9B51E0); // purple
    default:
      return const Color(0xFF7F8C8D); // grey
  }
}

/// A word with a plain-English explanation (when available), its part(s) of
/// speech, pronunciation (TTS), and all its dictionary meanings.
/// When opened in "random" mode (a pool is given) it shows a Next button.
class WordDetailScreen extends StatefulWidget {
  final Word word;
  final List<Word>? randomPool; // non-null → discovery mode with "Next word"
  final bool randomIncludeKnown; // start with learned words included?
  const WordDetailScreen(
      {super.key,
      required this.word,
      this.randomPool,
      this.randomIncludeKnown = false});
  @override
  State<WordDetailScreen> createState() => _WordDetailScreenState();
}

class _WordDetailScreenState extends State<WordDetailScreen> {
  final TtsService _tts = TtsService();
  final ScrollController _scroll = ScrollController();
  final _rng = Random();
  late Word _word;
  late bool _includeKnown; // toggle: include learned words in the rotation

  @override
  void initState() {
    super.initState();
    _word = widget.word;
    _includeKnown = widget.randomIncludeKnown;
  }

  @override
  void dispose() {
    _tts.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _next(WordsStore store) {
    final pool = widget.randomPool;
    if (pool == null || pool.isEmpty) return;
    // honor the "show learned" toggle; fall back to any (except current)
    var pick = pool
        .where((w) =>
            w.word != _word.word &&
            (_includeKnown || !store.isKnown(w.word)))
        .toList();
    if (pick.isEmpty) {
      pick = pool.where((w) => w.word != _word.word).toList();
    }
    if (pick.isEmpty) return;
    setState(() => _word = pick[_rng.nextInt(pick.length)]);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final w = _word;
    final store = context.watch<WordsStore>();
    final lang = context.watch<LocaleStore>().lang;
    final known = store.isKnown(w.word);
    final scheme = Theme.of(context).colorScheme;
    final isRandom = widget.randomPool != null;

    // group dictionary senses by part of speech
    final byPos = <String, List<Sense>>{};
    for (final s in w.senses) {
      byPos.putIfAbsent(s.pos, () => []).add(s);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isRandom ? tr(lang, 'random_word') : w.word),
        actions: [
          if (isRandom)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: _includeKnown,
                showCheckmark: false,
                avatar: Icon(
                    _includeKnown ? Icons.done_all : Icons.school_outlined,
                    size: 18),
                label: Text(tr(lang, 'show_known')),
                onSelected: (v) => setState(() => _includeKnown = v),
              ),
            ),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(w.word,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
              ),
              IconButton.filledTonal(
                icon: const Icon(Icons.volume_up),
                onPressed: () => _tts.speak(w.word),
              ),
            ],
          ),
          // IPA transcription (CMU dictionary), when available
          if (context.read<VocabRepository>().ipaFor(w.word).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('/${context.read<VocabRepository>().ipaFor(w.word)}/',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).hintColor,
                      fontFeatures: const [])),
            ),
          // Russian translations grouped by part of speech (once, not repeated)
          if (lang == 'ru' && w.ruByPos.isNotEmpty) ...[
            const SizedBox(height: 6),
            for (final entry in w.ruByPos.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.titleMedium,
                    children: [
                      TextSpan(
                        text: '${_posLabel(lang, entry.key)}: ',
                        style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontStyle: FontStyle.italic),
                      ),
                      TextSpan(
                        text: entry.value.join(', '),
                        style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(w.levelName)),
              for (final p in w.pos)
                Chip(
                  label: Text(p,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  backgroundColor: _posColor(p),
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 20),

          // my own plain-English explanation, when available
          if (w.simple.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 18, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 6),
                      Text(tr(lang, 'in_simple_words'),
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: scheme.onPrimaryContainer)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(w.simple,
                      style: TextStyle(color: scheme.onPrimaryContainer)),
                  for (final ex in w.myExamples)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.chevron_right,
                              size: 18, color: scheme.onPrimaryContainer),
                          Expanded(
                            child: Text('“$ex”',
                                style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: scheme.onPrimaryContainer)),
                          ),
                          InkWell(
                            onTap: () => _tts.speak(ex),
                            child: Icon(Icons.volume_up,
                                size: 18, color: scheme.onPrimaryContainer),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          if (w.senses.isNotEmpty)
            Text(tr(lang, 'dictionary_meanings'),
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Theme.of(context).hintColor)),
          const SizedBox(height: 6),
          if (w.senses.isEmpty && w.simple.isEmpty)
            Text(tr(lang, 'no_definition'))
          else
            for (final entry in byPos.entries) ...[
              Text(_posLabel(lang, entry.key),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _posColor(entry.key),
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic)),
              const SizedBox(height: 6),
              for (var i = 0; i < entry.value.length; i++)
                _SenseTile(
                    index: i + 1,
                    sense: entry.value[i],
                    lang: lang,
                    ruExample: context
                        .read<VocabRepository>()
                        .ruExample(entry.value[i].example),
                    ruDefinition: context
                        .read<VocabRepository>()
                        .ruDefinition(entry.value[i].definition),
                    tts: _tts),
              const SizedBox(height: 14),
            ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  style: known
                      ? FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3CA84B),
                          foregroundColor: Colors.white)
                      : null,
                  icon: Icon(known ? Icons.check_circle : Icons.school_outlined),
                  label: Text(known ? tr(lang, 'known') : tr(lang, 'mark_known')),
                  onPressed: () => store.setKnown(w.word, !known),
                ),
              ),
              if (isRandom) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(tr(lang, 'next_word')),
                    onPressed: () => _next(store),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SenseTile extends StatelessWidget {
  final int index;
  final Sense sense;
  final String lang;
  final String ruExample; // DeepL Russian translation of the example ('' none)
  final String ruDefinition; // DeepL Russian translation of the def ('' none)
  final TtsService tts;
  const _SenseTile(
      {required this.index,
      required this.sense,
      required this.lang,
      required this.ruExample,
      required this.ruDefinition,
      required this.tts});

  @override
  Widget build(BuildContext context) {
    final ru = lang == 'ru';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$index. ${sense.definition}',
              style: Theme.of(context).textTheme.bodyLarge),
          // Russian translation of the definition (DeepL), under the English
          if (ru && ruDefinition.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(ruDefinition,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary)),
            ),
          if (sense.example.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3, left: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('“${sense.example}”',
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).hintColor)),
                        // Russian translation of the example (DeepL), when shown
                        if (ru && ruExample.isNotEmpty)
                          Text('“$ruExample”',
                              style: TextStyle(
                                  fontStyle: FontStyle.italic,
                                  color: Theme.of(context).colorScheme.primary)),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => tts.speak(sense.example),
                    child: Icon(Icons.volume_up,
                        size: 18, color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
