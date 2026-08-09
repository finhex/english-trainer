import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../locale_store.dart';
import '../strings.dart';
import '../vocab_models.dart';
import '../vocab_repository.dart';
import '../words_store.dart';
import 'word_detail_screen.dart';

/// All words in one CEFR level, with search, a "hide known" toggle, and a
/// random-word button (which skips words you already know).
class WordListScreen extends StatefulWidget {
  final int? level; // null => all words across every level
  const WordListScreen({super.key, this.level});
  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  String _query = '';
  int _filter = 1; // 0 = all (known last), 1 = to-learn only, 2 = known only

  @override
  Widget build(BuildContext context) {
    final vocab = context.read<VocabRepository>();
    final store = context.watch<WordsStore>();
    final lang = context.watch<LocaleStore>().lang;
    final all = (widget.level == null
        ? List<Word>.from(vocab.words)
        : vocab.wordsForLevel(widget.level!))
      ..sort((a, b) => a.word.compareTo(b.word));

    bool known(Word w) => store.isKnown(w.word);
    // filter set: to-learn (unknown) / known / all
    List<Word> words = switch (_filter) {
      2 => all.where(known).toList(), // Known only
      1 => all.where((w) => !known(w)).toList(), // To learn only
      _ => List<Word>.from(all), // All
    };
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      words = words
          .where((w) =>
              w.word.contains(q) ||
              w.ru.any((t) => t.toLowerCase().contains(q)))
          .toList();
      // rank matches: exact > starts-with > contains > matched-via-Russian, and
      // (within a rank) unknown before known — so "ally" shows "ally" first.
      int rank(Word w) {
        if (w.word == q) return 0;
        if (w.word.startsWith(q)) return 1;
        if (w.word.contains(q)) return 2;
        return 3;
      }

      words.sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        if (r != 0) return r;
        if (known(a) != known(b)) return known(a) ? 1 : -1;
        return a.word.compareTo(b.word);
      });
    } else if (_filter == 2) {
      // "Known": most recently marked first, so an accidental one is right on
      // top to un-mark.
      words.sort((a, b) =>
          store.knownOrder(b.word).compareTo(store.knownOrder(a.word)));
    }
    // "All" (_filter == 0) stays plain alphabetical — every word shown, known
    // ones in place with their green check (not buried at the bottom).

    // random pool matches the active filter (fall back to all if empty)
    List<Word> pool = _filter == 2
        ? all.where(known).toList()
        : _filter == 1
            ? all.where((w) => !known(w)).toList()
            : all;
    if (pool.isEmpty) pool = all;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.level == null
            ? tr(lang, 'all_words')
            : (vocab.levelNames[widget.level] ?? 'Words')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.casino_outlined),
        label: Text(tr(lang, 'random_word')),
        onPressed: pool.isEmpty
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => WordDetailScreen(
                      word: pool[Random().nextInt(pool.length)],
                      randomPool: all, // full scope; screen filters via toggle
                      randomIncludeKnown: _filter != 1,
                    ),
                  ),
                ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr(lang, 'search_words'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                      Theme.of(context).textTheme.labelMedium),
                ),
                segments: [
                  ButtonSegment(value: 1, label: Text(tr(lang, 'filter_learn'))),
                  ButtonSegment(value: 2, label: Text(tr(lang, 'filter_known'))),
                  ButtonSegment(value: 0, label: Text(tr(lang, 'filter_all'))),
                ],
                selected: {_filter},
                onSelectionChanged: (s) => setState(() => _filter = s.first),
              ),
            ),
          ),
          // count of the current view + total learned
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Row(
              children: [
                Text('${words.length} ${tr(lang, 'words_lc')}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).hintColor)),
                const Spacer(),
                Text('${tr(lang, 'learned')}: ${all.where(known).length}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).hintColor)),
              ],
            ),
          ),
          Expanded(
            child: words.isEmpty
                ? Center(child: Text(tr(lang, 'no_words')))
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: words.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final w = words[i];
                      final isKnown = store.isKnown(w.word);
                      return ListTile(
                        leading: SizedBox(
                          width: 46,
                          child: Text('${i + 1}',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.visible,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  color: Theme.of(context).hintColor,
                                  fontSize: 12)),
                        ),
                        title: Text(w.word,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: (lang == 'ru' && w.ru.isNotEmpty)
                            ? Text(
                                w.ruLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary),
                              )
                            : Text(w.pos.join(' · ')),
                        trailing: isKnown
                            ? const Icon(Icons.check_circle,
                                color: Color(0xFF3CA84B))
                            : const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WordDetailScreen(word: w),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
