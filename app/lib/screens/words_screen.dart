import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../locale_store.dart';
import '../strings.dart';
import '../vocab_repository.dart';
import '../words_store.dart';
import 'word_list_screen.dart';

/// Vocabulary home: the 10k words grouped by CEFR level, with a known counter.
class WordsScreen extends StatelessWidget {
  const WordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vocab = context.read<VocabRepository>();
    final store = context.watch<WordsStore>();
    final lang = context.watch<LocaleStore>().lang;

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'nav_vocab'))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final level in vocab.levels)
            _LevelCard(
              name: vocab.levelNames[level] ?? '',
              learnedLabel: tr(lang, 'learned'),
              total: vocab.countForLevel(level),
              known: store.knownCount(
                  vocab.wordsForLevel(level).map((w) => w.word)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WordListScreen(level: level),
                ),
              ),
            ),
          // the 3000 most common words — the core everyday vocabulary
          if (vocab.top3000.isNotEmpty)
            _LevelCard(
              name: tr(lang, 'top3000'),
              learnedLabel: tr(lang, 'learned'),
              total: vocab.top3000Words.length,
              known: store.knownCount(vocab.top3000Words.map((w) => w.word)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WordListScreen(
                    subset: vocab.top3000Words,
                    title: tr(lang, 'top3000'),
                  ),
                ),
              ),
            ),
          // every word across all levels, at the very end
          _LevelCard(
            name: tr(lang, 'all_words'),
            learnedLabel: tr(lang, 'learned'),
            total: vocab.words.length,
            known: store.knownCount(vocab.words.map((w) => w.word)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const WordListScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String name;
  final String learnedLabel;
  final int total;
  final int known;
  final VoidCallback onTap;
  const _LevelCard({
    required this.name,
    required this.learnedLabel,
    required this.total,
    required this.known,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pct = total == 0 ? 0.0 : known / total;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.bold)),
                  ),
                  Text('$known / $total $learnedLabel'),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: pct, minHeight: 6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
