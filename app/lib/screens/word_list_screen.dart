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
  bool _hideKnown = true; // learned words hidden by default

  @override
  Widget build(BuildContext context) {
    final vocab = context.read<VocabRepository>();
    final store = context.watch<WordsStore>();
    final lang = context.watch<LocaleStore>().lang;
    final all = (widget.level == null
        ? List<Word>.from(vocab.words)
        : vocab.wordsForLevel(widget.level!))
      ..sort((a, b) => a.word.compareTo(b.word));

    // hide learned words (unless the "show learned" chip is on) in BOTH the
    // plain list and search — so learned words don't clutter, but flipping the
    // chip lets you find one you've already marked known.
    List<Word> words =
        _hideKnown ? all.where((w) => !store.isKnown(w.word)).toList() : all;
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      words = words
          .where((w) =>
              w.word.contains(q) ||
              w.ru.any((t) => t.toLowerCase().contains(q)))
          .toList();
      // rank matches: exact word > word starts with q > word contains q >
      // matched only via Russian — so typing "ally" shows "ally" first, not
      // "abnormally" (which merely contains it)
      int rank(Word w) {
        if (w.word == q) return 0;
        if (w.word.startsWith(q)) return 1;
        if (w.word.contains(q)) return 2;
        return 3;
      }

      words.sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.word.compareTo(b.word);
      });
    }

    // random pool: follows the "show learned" toggle — excludes learned words
    // by default, includes them when the chip is on (fall back to all if empty)
    List<Word> pool = _hideKnown
        ? all.where((w) => !store.isKnown(w.word)).toList()
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
                      randomIncludeKnown: !_hideKnown,
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                selected: !_hideKnown,
                showCheckmark: false,
                avatar: Icon(
                    _hideKnown ? Icons.school_outlined : Icons.done_all,
                    size: 18),
                label: Text(tr(lang, 'show_known')),
                onSelected: (show) => setState(() => _hideKnown = !show),
              ),
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
                      final known = store.isKnown(w.word);
                      return ListTile(
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
                        trailing: known
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
