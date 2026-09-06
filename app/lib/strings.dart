/// Minimal offline UI localization (English / Russian). Look up a key with
/// `tr(lang, 'key')`. Falls back to English, then the key itself.
library;


const Map<String, Map<String, String>> _s = {
  // navigation
  'nav_lessons': {'en': 'Lessons', 'ru': 'Уроки'},
  'nav_vocab': {'en': 'Vocabulary', 'ru': 'Слова'},
  'nav_guides': {'en': 'Guides', 'ru': 'Справочник'},
  'read_lesson': {'en': 'Read the lesson', 'ru': 'Читать урок'},
  'read_lesson_sub': {
    'en': 'The grammar explanation with examples',
    'ru': 'Объяснение грамматики с примерами'
  },
  'course_lessons': {'en': 'lessons', 'ru': 'уроков'},
  'course_exercises': {'en': 'exercises', 'ru': 'упражнений'},
  'nav_settings': {'en': 'Settings', 'ru': 'Настройки'},

  // lessons list
  'lessons': {'en': 'Lessons', 'ru': 'Уроки'},
  'practice_completed': {'en': 'Practice completed', 'ru': 'Практика пройдена'},
  'practice_unlocked': {'en': 'Practice unlocked', 'ru': 'Практика открыта'},
  'grammar_readable_locked': {
    'en': 'Grammar readable · practice locked',
    'ru': 'Грамматику можно читать · практика закрыта'
  },
  'lesson': {'en': 'Lesson', 'ru': 'Урок'},
  'guide': {'en': 'Guide', 'ru': 'Раздел'},
  'chapter': {'en': 'Chapter', 'ru': 'Глава'},

  // practices
  'practice': {'en': 'Practice', 'ru': 'Практика'},
  'p_word_order': {'en': 'Build the sentence', 'ru': 'Соберите предложение'},
  'p_sentence': {'en': 'Build the phrase', 'ru': 'Соберите фразу'},
  'p_sentence_sub': {
    'en': 'Pick the right word for each position',
    'ru': 'Выберите нужное слово для каждой позиции'
  },
  'p_gap_fill': {'en': 'Fill the gap', 'ru': 'Заполните пропуск'},
  'p_word_type': {'en': 'Word types', 'ru': 'Части речи'},
  'p_word_order_sub': {
    'en': 'Arrange the word tiles into the correct sentence',
    'ru': 'Составьте предложение из слов'
  },
  'p_gap_fill_sub': {
    'en': 'Choose the correct grammar word for the gap',
    'ru': 'Выберите правильное слово для пропуска'
  },
  'p_word_type_sub': {
    'en': 'Pick the word of the right type (noun, verb, …)',
    'ru': 'Выберите слово нужной части речи'
  },
  'in_progress': {'en': 'In progress', 'ru': 'В процессе'},
  'start_practice': {'en': 'Start practice', 'ru': 'Начать практику'},
  'locked': {'en': 'Locked', 'ru': 'Закрыто'},
  'finish_previous': {
    'en': 'Finish a practice in the previous lesson to unlock.',
    'ru': 'Пройдите практику в предыдущем уроке, чтобы открыть.'
  },

  // practice engine
  'put_words_order': {
    'en': 'Put the words in the correct order',
    'ru': 'Расставьте слова в правильном порядке'
  },
  'fill_in_gap': {'en': 'Fill in the gap', 'ru': 'Заполните пропуск'},
  'select_the': {'en': 'Select the', 'ru': 'Выберите'},
  'which_is_a': {'en': 'Which of these is a', 'ru': 'Какое из этих слов —'},
  'check': {'en': 'Check', 'ru': 'Проверить'},
  'next': {'en': 'Next', 'ru': 'Далее'},
  'done': {'en': 'Done', 'ru': 'Готово'},
  'correct': {'en': 'Correct', 'ru': 'Верно'},
  'incorrect': {'en': 'Incorrect', 'ru': 'Неверно'},
  'question': {'en': 'Question', 'ru': 'Вопрос'},
  'your_answer': {'en': 'Your answer', 'ru': 'Ваш ответ'},
  'correct_answer': {'en': 'Correct answer', 'ru': 'Правильный ответ'},
  'practice_complete': {'en': 'Practice complete', 'ru': 'Практика пройдена'},
  'correct_answers': {'en': 'correct answers', 'ru': 'правильных ответов'},

  // settings
  'reset_grammar': {'en': 'Reset grammar progress', 'ru': 'Сбросить прогресс'},
  'reset_grammar_sub': {
    'en': 'Clear completed lessons and locks',
    'ru': 'Очистить пройденные уроки и замки'
  },
  'reset_words': {'en': 'Reset learned words', 'ru': 'Сбросить выученные слова'},
  'reset_words_sub': {
    'en': 'Clear all words marked as known',
    'ru': 'Очистить все выученные слова'
  },
  'grammar_reset_done': {'en': 'Grammar progress reset.', 'ru': 'Прогресс сброшен.'},
  'words_reset_done': {'en': 'Learned words reset.', 'ru': 'Слова сброшены.'},
  'language': {'en': 'Language', 'ru': 'Язык'},
  'theme': {'en': 'Theme', 'ru': 'Тема'},
  'theme_system': {'en': 'System', 'ru': 'Системная'},
  'theme_light': {'en': 'Light', 'ru': 'Светлая'},
  'theme_dark': {'en': 'Dark', 'ru': 'Тёмная'},

  // vocabulary
  'search_words': {'en': 'Search words', 'ru': 'Поиск слов'},
  'hide_known': {'en': 'Hide known words', 'ru': 'Скрыть выученные'},
  'show_known': {'en': 'Show known words', 'ru': 'Показать выученные'},
  'filter_learn': {'en': 'To learn', 'ru': 'Учить'},
  'filter_known': {'en': 'Known', 'ru': 'Выучено'},
  'filter_all': {'en': 'All', 'ru': 'Все'},
  'words_lc': {'en': 'words', 'ru': 'слов'},
  'irregular_verb': {'en': 'Irregular verb', 'ru': 'Неправильный глагол'},
  'nav_book': {'en': 'Book', 'ru': 'Книга'},
  'chapters_lc': {'en': 'chapters', 'ru': 'глав'},
  'prev_chapter': {'en': 'Previous', 'ru': 'Назад'},
  'next_chapter': {'en': 'Next', 'ru': 'Далее'},
  'search_book': {'en': 'Search the book', 'ru': 'Поиск по книге'},
  'random_word': {'en': 'Random word', 'ru': 'Случайное слово'},
  'all_words': {'en': 'All words', 'ru': 'Все слова'},
  'top3000': {'en': 'Essential words', 'ru': 'Основные слова'},
  'top3000_sub': {
    'en': 'Most common + the 3000 essential lists',
    'ru': 'Самые частые + списки 3000 essential'
  },
  'text_size': {'en': 'Text size', 'ru': 'Размер текста'},
  'next_word': {'en': 'Next word', 'ru': 'Следующее'},
  'mark_known': {'en': 'Mark as known', 'ru': 'Отметить выученным'},
  'known': {'en': 'Known', 'ru': 'Выучено'},
  'learned': {'en': 'learned', 'ru': 'выучено'},
  'in_simple_words': {'en': 'In simple words', 'ru': 'Простыми словами'},
  'dictionary_meanings': {'en': 'Dictionary meanings', 'ru': 'Значения из словаря'},
  'dictionary': {'en': 'Dictionary', 'ru': 'Словарь'},
  'src_wordnet': {'en': 'WordNet', 'ru': 'WordNet'},
  'src_freedict': {'en': 'FreeDict', 'ru': 'FreeDict'},
  'etymology': {'en': 'Etymology', 'ru': 'Этимология'},
  'synonyms': {'en': 'Synonyms', 'ru': 'Синонимы'},
  'word_forms': {'en': 'Word forms', 'ru': 'Формы слова'},
  'common_pairings': {'en': 'Common pairings', 'ru': 'Частые сочетания'},
  'all_meanings': {'en': 'All meanings', 'ru': 'Все значения'},
  'no_definition': {
    'en': 'No offline definition available for this word yet.',
    'ru': 'Для этого слова пока нет офлайн-определения.'
  },
  'no_words': {'en': 'No words to show.', 'ru': 'Нет слов для показа.'},
};

const Map<String, Map<String, String>> _pos = {
  'noun': {'en': 'noun', 'ru': 'существительное'},
  'verb': {'en': 'verb', 'ru': 'глагол'},
  'adjective': {'en': 'adjective', 'ru': 'прилагательное'},
  'adverb': {'en': 'adverb', 'ru': 'наречие'},
};

String tr(String lang, String key) =>
    _s[key]?[lang] ?? _s[key]?['en'] ?? key;

/// Localized part-of-speech name.
String posName(String lang, String pos) => _pos[pos]?[lang] ?? pos;

/// Practice label/subtitle by type, localized.
String practiceLabel(String lang, String type) =>
    tr(lang, 'p_$type');
String practiceSub(String lang, String type) => tr(lang, 'p_${type}_sub');
