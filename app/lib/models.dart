/// Data models for the pre-built content bundle (assets/content.json).
/// Nothing here is generated at runtime — items are authored by the
/// content pipeline and simply served.
library;

class PracticeItem {
  final String type; // 'word_order' | 'gap_fill' | 'word_type'
  final String prompt;
  final String answer;
  final List<String> tokens; // correct tiles, in order (word_order)
  final List<String> distractors; // extra wrong tiles / MCQ options

  PracticeItem({
    required this.type,
    required this.prompt,
    required this.answer,
    required this.tokens,
    required this.distractors,
  });

  factory PracticeItem.fromJson(String type, Map<String, dynamic> j) =>
      PracticeItem(
        type: type,
        prompt: (j['prompt'] as String?) ?? '',
        answer: j['answer'] as String,
        tokens: ((j['tokens'] as List?) ?? const []).cast<String>(),
        distractors: (j['distractors'] as List).cast<String>(),
      );
}

/// One practice within a lesson: its own goal, optional part-of-speech
/// (word_type), and its items.
class LessonPractice {
  final int goal;
  final String pos; // word_type target POS ('noun'…); '' otherwise
  final List<PracticeItem> items;

  LessonPractice({required this.goal, required this.pos, required this.items});

  factory LessonPractice.fromJson(String type, Map<String, dynamic> j) =>
      LessonPractice(
        goal: (j['goal'] as int?) ?? 70,
        pos: (j['pos'] as String?) ?? '',
        items: ((j['items'] as List?) ?? const [])
            .map((e) => PracticeItem.fromJson(type, e as Map<String, dynamic>))
            .toList(),
      );
}

/// Human labels for the practice modes (order = display order).
const List<String> kPracticeOrder = ['word_order', 'gap_fill', 'word_type'];
const Map<String, String> kPracticeLabel = {
  'word_order': 'Build the sentence',
  'gap_fill': 'Fill the gap',
  'word_type': 'Word types',
};
const Map<String, String> kPracticeSubtitle = {
  'word_order': 'Arrange the word tiles into the correct sentence',
  'gap_fill': 'Choose the correct grammar word for the gap',
  'word_type': 'Pick the word of the right type (noun, verb, …)',
};

class Lesson {
  final int id;
  final int ord;
  final String part;
  final String title;
  final String grammarMd;
  final int uniqueSentences;
  final int level; // 1..6 (A1..C2); 0 for guides
  final String levelName;
  final String section; // 'grammar' | 'other'
  final String titleRu; // Russian chapter title ('' if none)
  final String grammarMdRu; // Russian grammar explanation ('' if none)
  final Map<String, LessonPractice> practices; // per-practice goal/pos/items

  Lesson({
    required this.id,
    required this.ord,
    required this.part,
    required this.title,
    required this.grammarMd,
    required this.uniqueSentences,
    required this.level,
    required this.levelName,
    required this.section,
    required this.titleRu,
    required this.grammarMdRu,
    required this.practices,
  });

  /// Goal for a given practice in this lesson (default 70).
  int goalFor(String type) => practices[type]?.goal ?? 70;

  /// word_type target part of speech for this lesson ('' if none).
  String posFor(String type) => practices[type]?.pos ?? '';

  static String _strip(String t) =>
      t.replaceFirst(RegExp(r'^Chapter\s+\d+\.\s*'), '');

  /// The topic without the "Chapter 53." prefix, e.g. "Present Perfect Simple".
  String get topic => _strip(title);

  /// Topic in the given UI language (Russian when available).
  String topicFor(String lang) =>
      lang == 'ru' && titleRu.isNotEmpty ? _strip(titleRu) : topic;

  /// Grammar explanation in the given UI language (Russian when available).
  String grammarFor(String lang) =>
      lang == 'ru' && grammarMdRu.isNotEmpty ? grammarMdRu : grammarMd;

  List<PracticeItem> itemsOfType(String type) =>
      practices[type]?.items ?? const [];

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as int,
        ord: j['ord'] as int,
        part: j['part'] as String,
        title: j['title'] as String,
        grammarMd: j['grammarMd'] as String,
        uniqueSentences: j['uniqueSentences'] as int,
        level: (j['level'] as int?) ?? 6,
        levelName: (j['levelName'] as String?) ?? '',
        section: (j['section'] as String?) ?? 'grammar',
        titleRu: (j['titleRu'] as String?) ?? '',
        grammarMdRu: (j['grammarMdRu'] as String?) ?? '',
        practices: ((j['practices'] as Map<String, dynamic>?) ?? const {}).map(
          (type, v) => MapEntry(
              type, LessonPractice.fromJson(type, v as Map<String, dynamic>)),
        ),
      );
}
