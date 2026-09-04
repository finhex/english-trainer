import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../locale_store.dart';
import '../polish_pack.dart';
import '../progress_store.dart';
import '../strings.dart';
import '../text_scale_store.dart';
import '../theme_store.dart';
import '../words_store.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.read<ProgressStore>();
    final words = context.read<WordsStore>();
    final locale = context.watch<LocaleStore>();
    final textScale = context.watch<TextScaleStore>();
    final themeStore = context.watch<ThemeStore>();
    final lang = locale.lang;

    return Scaffold(
      appBar: AppBar(title: Text(tr(lang, 'nav_settings'))),
      body: ListView(
        children: [
          // Language toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.language),
                const SizedBox(width: 16),
                Text(tr(lang, 'language'),
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                SegmentedButton<String>(
                  segments: [
                    const ButtonSegment(value: 'en', label: Text('English')),
                    const ButtonSegment(value: 'ru', label: Text('Русский')),
                    // only offered while the assets/pl pack is installed
                    if (PolishPack.available)
                      const ButtonSegment(value: 'pl', label: Text('Polski')),
                  ],
                  selected: {lang},
                  onSelectionChanged: (s) => locale.setLang(s.first),
                ),
              ],
            ),
          ),
          // Theme: follow the system, or force light / dark.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.brightness_6_outlined),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(tr(lang, 'theme'),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                        value: 'system',
                        icon: const Icon(Icons.brightness_auto, size: 18),
                        tooltip: tr(lang, 'theme_system')),
                    ButtonSegment(
                        value: 'light',
                        icon: const Icon(Icons.light_mode_outlined, size: 18),
                        tooltip: tr(lang, 'theme_light')),
                    ButtonSegment(
                        value: 'dark',
                        icon: const Icon(Icons.dark_mode_outlined, size: 18),
                        tooltip: tr(lang, 'theme_dark')),
                  ],
                  selected: {themeStore.name},
                  onSelectionChanged: (s) => themeStore.setMode(s.first),
                ),
              ],
            ),
          ),
          // Text size (accessibility): Normal / Large / Extra-large.
          // Labels are "A" at three sizes, and are NOT themselves scaled so the
          // control always shows the relative sizes clearly.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.format_size),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(tr(lang, 'text_size'),
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                MediaQuery.withNoTextScaling(
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: 'normal',
                          label: Text('A', style: TextStyle(fontSize: 13))),
                      ButtonSegment(
                          value: 'large',
                          label: Text('A', style: TextStyle(fontSize: 18))),
                      ButtonSegment(
                          value: 'xlarge',
                          label: Text('A', style: TextStyle(fontSize: 23))),
                    ],
                    selected: {textScale.mode},
                    onSelectionChanged: (s) => textScale.setMode(s.first),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(tr(lang, 'reset_grammar')),
            subtitle: Text(tr(lang, 'reset_grammar_sub')),
            onTap: () async {
              await progress.reset();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr(lang, 'grammar_reset_done'))));
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.restart_alt),
            title: Text(tr(lang, 'reset_words')),
            subtitle: Text(tr(lang, 'reset_words_sub')),
            onTap: () async {
              await words.reset();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(tr(lang, 'words_reset_done'))));
              }
            },
          ),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'English Trainer',
            applicationVersion: '0.1.0',
          ),
        ],
      ),
    );
  }
}
