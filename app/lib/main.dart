import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_theme.dart';
import 'content_repository.dart';
import 'locale_store.dart';
import 'polish_pack.dart';
import 'progress_store.dart';
import 'text_scale_store.dart';
import 'theme_store.dart';
import 'vocab_repository.dart';
import 'words_store.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // the removable Polish layer; absent, the app is English/Russian as before
  await PolishPack.load();
  final content = await ContentRepository.load();
  final progress = await ProgressStore.load();
  final vocab = await VocabRepository.load();
  final wordsStore = await WordsStore.load();
  final locale = await LocaleStore.load();
  final textScale = await TextScaleStore.load();
  final theme = await ThemeStore.load();
  runApp(EnglishTrainerApp(
    content: content,
    progress: progress,
    vocab: vocab,
    wordsStore: wordsStore,
    locale: locale,
    textScale: textScale,
    theme: theme,
  ));
}

class EnglishTrainerApp extends StatelessWidget {
  final ContentRepository content;
  final ProgressStore progress;
  final VocabRepository vocab;
  final WordsStore wordsStore;
  final LocaleStore locale;
  final TextScaleStore textScale;
  final ThemeStore theme;
  const EnglishTrainerApp({
    super.key,
    required this.content,
    required this.progress,
    required this.vocab,
    required this.wordsStore,
    required this.locale,
    required this.textScale,
    required this.theme,
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
        ChangeNotifierProvider<ThemeStore>.value(value: theme),
      ],
      // Consumer so the whole app (incl. built-in Material tooltips like the
      // "Back" button) re-localizes when the language toggle changes.
      child: Consumer<LocaleStore>(
        builder: (context, localeStore, _) => MaterialApp(
          title: 'English Trainer',
          debugShowCheckedModeBanner: false,
          // localize Flutter's built-in strings (Back button, etc.) to the
          // chosen UI language
          locale: Locale(localeStore.lang),
          supportedLocales: const [Locale('en'), Locale('ru')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: context.watch<ThemeStore>().mode,
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
      ),
    );
  }
}
