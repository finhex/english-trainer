import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../locale_store.dart';
import '../strings.dart';
import '../vocab_models.dart';
import '../vocab_repository.dart';
import '../words_store.dart';
import '../tts_service.dart';

/// Part-of-speech label: English in EN mode, "прилагательное (adjective)" in RU
/// mode so both languages are visible (Russian first, English in parens).
String _posLabel(String lang, String pos) => lang == 'ru'
    ? '${posName('ru', pos)} (${posName('en', pos)})'
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

  // Which dictionary the meanings come from. Default WordNet; remembered across
  // words for the rest of the session.
  static String _srcChoice = 'wordnet'; // 'wordnet' | 'freedict'

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
          // IPA transcription — British (UK) and American (US), when available
          Builder(builder: (context) {
            final repo = context.read<VocabRepository>();
            final uk = repo.ipaUk(w.word);
            final us = repo.ipaUs(w.word);
            if (uk.isEmpty && us.isEmpty) return const SizedBox.shrink();
            final hint = Theme.of(context).hintColor;
            final scheme = Theme.of(context).colorScheme;
            TextSpan part(String label, String ipa) => TextSpan(children: [
                  TextSpan(
                      text: '$label ',
                      style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                  TextSpan(
                      text: '/$ipa/  ',
                      style: TextStyle(color: hint, fontSize: 15)),
                ]);
            // if both sides are identical, show it once without labels
            if (uk == us || uk.isEmpty || us.isEmpty) {
              final one = uk.isNotEmpty ? uk : us;
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('/$one/',
                    style: TextStyle(color: hint, fontSize: 15)),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(TextSpan(children: [part('UK', uk), part('US', us)])),
            );
          }),
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
          const SizedBox(height: 16),

          // irregular verb forms (V1 · V2 · V3), when the word is one
          Builder(builder: (context) {
            final forms = context.read<VocabRepository>().irregularForms(w.word);
            if (forms == null || forms.length < 3) {
              return const SizedBox.shrink();
            }
            final scheme = Theme.of(context).colorScheme;
            Widget cell(String label, String form) => Expanded(
                  child: Column(
                    children: [
                      Text(label,
                          style: TextStyle(
                              color: scheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(form,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(tr(lang, 'irregular_verb'),
                        style: TextStyle(
                            color: scheme.onSecondaryContainer,
                            fontSize: 12,
                            fontStyle: FontStyle.italic)),
                    const SizedBox(height: 8),
                    Row(children: [
                      cell('V1', forms[0]),
                      cell('V2', forms[1]),
                      cell('V3', forms[2]),
                    ]),
                  ],
                ),
              ),
            );
          }),

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

          Builder(builder: (context) {
            final full = context.read<VocabRepository>().fullFor(w.word);
            final richSenses = (full?['senses'] as List?) ?? const [];
            final hasRich = richSenses.isNotEmpty;
            final hasWordNet = w.senses.isNotEmpty;
            // dictionary chooser — only when both sources exist for this word
            final chooser = (hasRich && (hasWordNet || w.simple.isNotEmpty))
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        Text('${tr(lang, 'dictionary')}:  ',
                            style: TextStyle(
                                color: Theme.of(context).hintColor,
                                fontSize: 13)),
                        Expanded(
                          child: SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(
                                visualDensity: VisualDensity.compact),
                            segments: [
                              ButtonSegment(
                                  value: 'wordnet',
                                  label: Text(tr(lang, 'src_wordnet'))),
                              ButtonSegment(
                                  value: 'freedict',
                                  label: Text(tr(lang, 'src_freedict'))),
                            ],
                            selected: {_srcChoice},
                            onSelectionChanged: (s) =>
                                setState(() => _srcChoice = s.first),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink();

            // Which source to actually render (fall back if the chosen one is
            // missing for this word).
            final showRich = hasRich &&
                (_srcChoice == 'freedict' || !hasWordNet);

            if (!hasRich && !hasWordNet && w.simple.isEmpty) {
              return Text(tr(lang, 'no_definition'));
            }

            final Widget meanings = showRich
                ? _RichEntry(word: w.word, full: full!, lang: lang, tts: _tts)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasWordNet)
                        Text(tr(lang, 'dictionary_meanings'),
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                    color: Theme.of(context).hintColor)),
                      const SizedBox(height: 6),
                      for (final entry in byPos.entries) ...[
                        Text(_posLabel(lang, entry.key),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
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
                  );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [chooser, meanings],
            );
          }),
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

/// Rich dictionary entry (FreeDict/Wiktionary): word forms, senses grouped by
/// part of speech with English definition, Russian translation, examples and
/// synonyms, plus etymology.
class _RichEntry extends StatelessWidget {
  final String word;
  final Map<String, dynamic> full;
  final String lang;
  final TtsService tts;
  const _RichEntry(
      {required this.word,
      required this.full,
      required this.lang,
      required this.tts});

  /// The headword plus its inflected forms, lower-cased, for highlighting the
  /// target word inside example sentences (as the reference site does).
  Set<String> _targets() {
    final t = <String>{word.toLowerCase()};
    final forms = (full['forms'] as Map?) ?? const {};
    for (final v in forms.values) {
      if (v is String && v.trim().isNotEmpty) t.add(v.toLowerCase());
    }
    // common regular inflections so "spot" also lights up "spots"/"spotting"
    final w = word.toLowerCase();
    t.addAll([
      '${w}s',
      '${w}es',
      '${w}ed',
      '${w}ing',
      if (w.endsWith('e')) '${w.substring(0, w.length - 1)}ing',
    ]);
    return t;
  }

  /// Renders [text] as italic, bolding any whole-word occurrence of a target.
  Widget _highlight(String text, Set<String> targets, ColorScheme scheme) {
    final spans = <TextSpan>[];
    final re = RegExp(r"[A-Za-z']+|[^A-Za-z']+");
    for (final m in re.allMatches(text)) {
      final tok = m.group(0)!;
      final hit = targets.contains(tok.toLowerCase());
      spans.add(TextSpan(
          text: tok,
          style: hit
              ? TextStyle(
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary)
              : null));
    }
    return Text.rich(TextSpan(children: spans),
        style: TextStyle(
            fontStyle: FontStyle.italic,
            color: scheme.onSurface.withValues(alpha: .8),
            fontSize: 14));
  }

  static const _formLabels = {
    'plural': 'plural',
    'past': 'past',
    'past participle': 'past part.',
    'present_3s': '3rd person',
    'gerund': '-ing',
    'comparative': 'comparative',
    'superlative': 'superlative',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hint = Theme.of(context).hintColor;
    final senses = (full['senses'] as List).cast<dynamic>();
    final forms = (full['forms'] as Map?) ?? const {};
    final ety = ((full['etymology'] as String?) ?? '').trim();

    final byPos = <String, List<Map<String, dynamic>>>{};
    for (final s in senses) {
      final m = (s as Map).cast<String, dynamic>();
      byPos.putIfAbsent((m['pos'] as String?) ?? '', () => []).add(m);
    }

    final formItems = [
      for (final e in _formLabels.entries)
        if (forms[e.key] != null && (forms[e.key] as String).isNotEmpty)
          MapEntry(e.value, forms[e.key] as String)
    ];
    // synonyms aggregated across senses into one list (as on the site)
    final allSyn = <String>[];
    for (final s in senses) {
      for (final sy in (((s as Map)['synonyms'] as List?) ?? const [])) {
        final t = (sy as String).trim();
        if (t.isNotEmpty && !allSyn.contains(t)) allSyn.add(t);
      }
    }

    Widget label(String key) => Text(tr(lang, key),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: hint));

    final targets = _targets();
    // The first sense used to be repeated here as a highlighted callout. It
    // said nothing new: "dictionary meanings" below lists every sense in
    // byPos, starting with that same one and the same example, so the page
    // opened by explaining the word twice.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 0.5) ALL FreeDict Russian meanings (complete set, as on freedict.com)
        Builder(builder: (context) {
          final all = context.read<VocabRepository>().freedictRuFor(word);
          if (all.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label('all_meanings'),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final t in all)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(t,
                        style: TextStyle(
                            color: scheme.onSecondaryContainer, fontSize: 13)),
                  ),
              ]),
              const SizedBox(height: 18),
            ],
          );
        }),
        // 1) word forms (moved above the meanings, per request)
        if (formItems.isNotEmpty) ...[
          label('word_forms'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final it in formItems)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8)),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${it.key}: ',
                      style: TextStyle(color: hint, fontSize: 12)),
                  TextSpan(
                      text: it.value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                ])),
              ),
          ]),
          const SizedBox(height: 16),
        ],
        // 2) synonyms — one list, also above the meanings
        if (allSyn.isNotEmpty) ...[
          label('synonyms'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final sy in allSyn.take(18))
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(20)),
                child: Text(sy,
                    style: TextStyle(
                        color: scheme.onSecondaryContainer, fontSize: 13)),
              ),
          ]),
          const SizedBox(height: 18),
        ],
        // 3) definitions grouped by part of speech (with examples + Russian)
        label('dictionary_meanings'),
        const SizedBox(height: 6),
        for (final entry in byPos.entries) ...[
          Text(_posLabel(lang, entry.key),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _posColor(entry.key),
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic)),
          const SizedBox(height: 6),
          for (var i = 0; i < entry.value.length; i++)
            _sense(context, i + 1, entry.value[i], scheme, hint, targets),
          const SizedBox(height: 14),
        ],
        // 4) etymology
        if (ety.isNotEmpty) ...[
          label('etymology'),
          const SizedBox(height: 4),
          Text(ety,
              style: TextStyle(
                  color: scheme.onSurface.withValues(alpha: .72),
                  fontSize: 13.5,
                  height: 1.4)),
          const SizedBox(height: 16),
        ],
        // 5) common pairings (frequency-ranked collocations) at the end
        Builder(builder: (context) {
          final pairs = context.read<VocabRepository>().pairingsFor(word);
          if (pairs.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label('common_pairings'),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final p in pairs)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 4),
                    decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8)),
                    child: _highlight(p, targets, scheme),
                  ),
              ]),
            ],
          );
        }),
      ],
    );
  }

  Widget _sense(BuildContext context, int idx, Map<String, dynamic> s,
      ColorScheme scheme, Color hint, Set<String> targets) {
    final def = (s['def'] as String?) ?? '';
    final ru = ((s['ru'] as List?) ?? const []).cast<String>();
    final ex = ((s['examples'] as List?) ?? const []).cast<String>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (def.isNotEmpty)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$idx. ',
                  style: TextStyle(color: hint, fontWeight: FontWeight.w600)),
              Expanded(
                  child: Text(def,
                      style: const TextStyle(fontSize: 15.5, height: 1.35))),
            ]),
          if (ru.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 2),
              child: Text(ru.join(', '),
                  style: TextStyle(
                      color: scheme.primary, fontWeight: FontWeight.w600)),
            ),
          for (final e in ex)
            Padding(
              padding: const EdgeInsets.only(left: 18, top: 4),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: _highlight('“$e”', targets, scheme)),
                InkWell(
                    onTap: () => tts.speak(e),
                    child: Icon(Icons.volume_up, size: 16, color: hint)),
              ]),
            ),
        ],
      ),
    );
  }
}
