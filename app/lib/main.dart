import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'content_repository.dart';
import 'locale_store.dart';
import 'progress_store.dart';
import 'text_scale_store.dart';
import 'vocab_repository.dart';
import 'words_store.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final content = await ContentRepository.load();
  final progress = await ProgressStore.load();
  final vocab = await VocabRepository.load();
  final wordsStore = await WordsStore.load();
  final locale = await LocaleStore.load();
  final textScale = await TextScaleStore.load();
  runApp(EnglishTrainerApp(
    content: content,
    progress: progress,
    vocab: vocab,
    wordsStore: wordsStore,
    locale: locale,
    textScale: textScale,
  ));
}

class EnglishTrainerApp extends StatelessWidget {
  final ContentRepository content;
  final ProgressStore progress;
  final VocabRepository vocab;
  final WordsStore wordsStore;
  final LocaleStore locale;
  final TextScaleStore textScale;
  const EnglishTrainerApp({
    super.key,
    required this.content,
    required this.progress,
    required this.vocab,
    required this.wordsStore,
    required this.locale,
    required this.textScale,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ContentRepository>.value(value: content),
        ChangeNotifierProvider<ProgressStore>.value(value: progress),
        Provider<VocabRepository>.value(value: vocab),
        ChangeNotifierProvider<WordsStore>.value(value: wordsStore),
        ChangeNotifierProvider<LocaleStore>.value(value: locale),
        ChangeNotifierProvider<TextScaleStore>.value(value: textScale),
      ],
      child: MaterialApp(
        title: 'English Trainer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2F80ED),
          brightness: Brightness.light,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF2F80ED),
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        // apply the chosen text-size mode to the whole app
        builder: (context, child) {
          final scale = context.watch<TextScaleStore>().scale;
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
        home: const HomeScreen(),
      ),
    );
  }
}
