# English Trainer

Offline English grammar & vocabulary trainer for **Android, Windows, and Linux**
(one Flutter codebase). Grammar lessons + tap-to-assemble practice, modeled on
the "1st English" app.

## Layout

```
content_pipeline/   Python build tool: grammar book (markdown) -> content.json
  extract.py
app/                Flutter app (Android / Windows / Linux)
  assets/content.json   <- bundled, pre-built lessons (copied from pipeline)
  lib/
```

## How content works (no runtime generation)

`extract.py` reads the grammar reference markdown, splits it into chapters
(= lessons), mines the **example sentences** that already demonstrate each
grammar point, and emits **pre-built** practice items (word-order + gap-fill),
each tied to its grammar point. The `✗` wrong examples are never used.

Regenerate the bundle (example: chapters 24 and 25):

```bash
cd content_pipeline
python3 extract.py \
  --src "/path/to/english_grammar_phonetics_book_v5.md" \
  --out content.db --chapters 24,25
cp content.json ../app/assets/content.json
```

Omit `--chapters` to process every chapter that has enough examples.

## Run the app

Requires the Flutter SDK (not yet installed on this machine).

```bash
cd app
flutter pub get
flutter run -d linux      # or: -d windows, or an Android device/emulator
```

Build installers later with `flutter build apk`, `flutter build windows`,
`flutter build linux`.

## Status

- [x] Content pipeline (proven on 2 chapters, 70 items each)
- [x] App scaffold: lessons list + locks, grammar viewer, practice engine
      (word-order + gap-fill, ±1 scoring, reach 70, TTS), progress persistence
- [ ] Run/verify in Flutter (needs SDK install)
- [ ] Vocabulary module (offline list + optional live dictionary API)
- [ ] Extract all chapters
- [ ] Packaging (APK/AAB, Windows, Linux)
