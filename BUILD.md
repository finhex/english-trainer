# Build & Launch Guide — English Trainer

Everything you need to build the app, launch it, and regenerate its content.

- **Project root:** `~/Documents/Claude/_git-backups/apps/words/`
- **Flutter app:** `app/`
- **Grammar content pipeline:** `content_pipeline/`
- **Vocabulary pipeline:** `vocab_pipeline/`
- **Built APK output:** `dist/english_trainer.apk`

---

## 0. One-time setup (already done on this machine)

| Tool | Location | Notes |
|------|----------|-------|
| Flutter SDK 3.44 | `~/flutter` | `~/flutter/bin` is on your PATH (added to `~/.bashrc`) |
| Java (Temurin 21) | `/usr/lib/jvm/java-21-temurin` | system install |
| Android SDK | `~/Android/sdk` | platform 35+36, build-tools, NDK, CMake |
| Python 3 | system | grammar pipeline |
| Python venv (nltk) | `vocab_pipeline/.venv` | WordNet for vocabulary |

If you ever open a fresh terminal, these env vars make Android builds work:

```bash
export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="/usr/lib/jvm/java-21-temurin"
export ANDROID_SDK_ROOT="$HOME/Android/sdk"
```

---

## 1. Launch on Linux (desktop) — fastest for testing

```bash
cd ~/Documents/Claude/_git-backups/apps/words/app
flutter run -d linux
```

That builds **and** opens the window, with hot reload (press `r` to reload, `q` to quit).

**Run the already-built binary directly** (no rebuild):

```bash
~/Documents/Claude/_git-backups/apps/words/app/build/linux/x64/debug/bundle/english_trainer
```

> Tip: if a window doesn't appear, it may be behind a fullscreen app — Alt+Tab to "English Trainer".

---

## 2. Build the Android APK

```bash
export PATH="$HOME/flutter/bin:$PATH"
export JAVA_HOME="/usr/lib/jvm/java-21-temurin"
export ANDROID_SDK_ROOT="$HOME/Android/sdk"

cd ~/Documents/Claude/_git-backups/apps/words/app
flutter build apk --release

# copy to the dist folder
cp build/app/outputs/flutter-apk/app-release.apk ../dist/english_trainer.apk
```

Output: `dist/english_trainer.apk` (~54 MB). First build takes ~9 min; later builds ~1–2 min.

### Install it on a phone

- **Via USB:** enable USB debugging, plug in, then
  ```bash
  adb install -r dist/english_trainer.apk
  ```
- **Manually:** copy the `.apk` to the phone, tap it, allow "Install unknown apps".

> The app is signed with a debug key (fine for personal use, not for the Play Store).
> App id: `com.firzar.englishtrainer` · min Android 7.0.

---

## 3. Build for other platforms

```bash
cd ~/Documents/Claude/_git-backups/apps/words/app

flutter build linux     # Linux bundle  -> build/linux/x64/release/bundle/
flutter build appbundle # Android AAB (Play Store) -> build/app/outputs/bundle/
# flutter build windows  # only works when run ON Windows
```

---

## 4. Regenerate the content (only if you change the data)

The app ships pre-built JSON; you only rerun these if you edit the source book,
the pipelines, or the word explanations.

### Grammar lessons + guides
```bash
cd ~/Documents/Claude/_git-backups/apps/words
python3 content_pipeline/extract.py \
  --src "/home/konako/Documents/Project Write/Project Write/English Sentences Structure/english_grammar_phonetics_book_v5.md" \
  --out content_pipeline/content.db
cp content_pipeline/content.json app/assets/content.json
```

### Translate example sentences to Russian (local Ollama — run when ready)
The vocabulary example sentences are English. To add Russian translations with
a **local Ollama model** (offline, free), start `ollama serve`, then:
```bash
cd apps/words/vocab_pipeline/ru
python3 translate_examples.py --model gemma3            # translate all (resumable)
python3 translate_examples.py --model gemma3 --limit 50 # quick test first
python3 translate_examples.py --model gemma3 --also-definitions
```
- ~14k unique sentences → a long run; it's **cached** (`example_ru_cache.json`)
  and resumable, so stop/restart anytime.
- Writes `sense.exampleRu` (+ `definitionRu`) into `app/assets/words.json`.
  The app shows the Russian example under the English one in Russian mode
  (falls back to English where not yet translated). Rebuild the app afterwards.
- Check your model tag with `ollama list` and pass it via `--model`.

### Vocabulary (10k words, WordNet definitions)
```bash
cd ~/Documents/Claude/_git-backups/apps/words/vocab_pipeline
./.venv/bin/python build_vocab.py --top 10000
cp words.json ../app/assets/words.json
```
- Add your own plain-English word explanations in `vocab_pipeline/overrides.json`,
  then rerun the command above.

### Russian translations (`ru/`)
Every word gets Russian translations, and so does each individual meaning.
`build_vocab.py` produces English-only data; the Russian layer is added on top,
so **rerunning `build_vocab.py` wipes it and you must redo this step**.

```bash
cd ~/Documents/Claude/_git-backups/apps/words/vocab_pipeline
# 1. only if ru/*.jsonl are missing or you want fresher data — these stream
#    large dumps and keep ~1% of each (~9 min and ~1 min respectively)
curl -sSL https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl \
  | python3 ru/filter_kaikki.py
curl -sSL https://kaikki.org/dictionary/downloads/ru/ru-extract.jsonl.gz \
  | gunzip | python3 ru/filter_ruwikt.py
# 2. merge the translations into app/assets/words.json (in place, seconds)
./.venv/bin/python ru/build_ru.py
# 3. eyeball the result
./.venv/bin/python ru/sample_ru.py            # random spread
./.venv/bin/python ru/sample_ru.py time run   # specific words
```

Sources, in priority order — a later one only fills in what the earlier ones had
nothing for:
1. `ru/overrides_ru.json` — hand-written, `{"word": ["перевод", ...]}`, wins over
   everything. Add to it when a machine-picked translation is wrong.
2. `ru/kaikki_ru.jsonl` — English Wiktionary translation tables. The only source
   that says *which meaning* a translation belongs to.
3. `ru/ruwikt_ru.jsonl` — Russian Wiktionary's glosses for English words.
4. `ru/muse_en_ru.txt` — MUSE en-ru pairs, last resort.

Words whose own entry has nothing fall back to their WordNet base form
(`accepted` reuses `accept`) and to British→American spellings (`favour` reuses
`favor`). Each word gets `ru: [...]`; each sense gets its own `ru: [...]`, either
matched to that meaning or the word's main translations for that part of speech.
Current coverage: **9,900 / 10,000** — the rest are abbreviations and fragments
(`inc`, `xiii`, `tion`) that are left untranslated on purpose.

`ru/words_en_backup.json` is the English-only snapshot; `build_ru.py` is re-run
from it (`cp ru/words_en_backup.json ../app/assets/words.json` first) so repeated
runs stay clean.

After regenerating content, rebuild the app (section 1 or 2) so the new
`assets/*.json` are bundled.

---

## 4b. Configure the app via JSON (no code changes)

Almost everything except Settings is driven by the `config` block at the top of
`app/assets/content.json`:

```json
{
  "config": {
    "practices": {
      "word_order": {"label": "Build the sentence", "order": 1, "icon": "reorder",   "subtitle": "…"},
      "gap_fill":   {"label": "Fill the gap",       "order": 2, "icon": "space_bar", "subtitle": "…"},
      "word_type":  {"label": "Word types",         "order": 3, "icon": "category",  "subtitle": "…"}
    },
    "levels": {"1": "A1 · Beginner", "2": "A2 · Elementary", "…": "…"}
  },
  "lessons": [
    { "id": 17, "…": "…", "goals": {"word_order": 70, "word_type": 70}, "items": [ … ] }
  ]
}
```

- **`goals`** (per lesson) — how many correct answers finish each practice **in
  that lesson**. Edit a single lesson's `goals` to change only that lesson,
  e.g. `"goals": {"word_type": 40}`.
- **`label` / `subtitle` / `icon` / `order`** (global) — how each practice
  appears. Valid icons: `reorder`, `space_bar`, `category`, `quiz`.
- **`levels`** — the group headings shown in the Lessons list.

Two ways to change it:
1. **Quick/manual:** edit `app/assets/content.json` directly, then rebuild the
   app (section 1/2). (A full content regen overwrites it — see below.)
2. **Permanent:** edit `PRACTICE_CONFIG` / `LEVEL_NAMES` in
   `content_pipeline/extract.py`, then regenerate content (section 4).

## 5. Quick checks

```bash
cd ~/Documents/Claude/_git-backups/apps/words/app
flutter analyze          # static analysis (should say "No issues found!")
flutter doctor           # environment health
```

---

## Common issues

- **`flutter: command not found`** → open a new terminal, or run
  `export PATH="$HOME/flutter/bin:$PATH"`.
- **Android build can't find SDK** → set `ANDROID_SDK_ROOT` (section 0) or run
  `flutter config --android-sdk ~/Android/sdk`.
- **Two copies of the app on the phone** → the package id changed once
  (`com.example…` → `com.firzar.englishtrainer`); uninstall the old one.
