# English Trainer

An **offline**, bilingual (English / Русский) app for learning English **grammar**
and **vocabulary**. No account, no internet, no ads — everything is bundled.

Built with Flutter. Runs on **Android**, **Windows**, and **Linux** (iOS is
possible but needs an Apple account — see below).

---

## What's inside

### 📚 Grammar book — 320 chapters
A reference to read, not to drill:
- **263 lessons**, ordered A1 → C2
- **57 reference guides** (phonetics, spelling, punctuation, study skills)
- **10 appendices**
- Every chapter available in **English and Russian** (100% translated)

### 🎓 Course — 32 lessons
A guided course with **11,504 practice sentences**, by the makers of the
«1st English» app (see [Content sources](#content-sources) — this part is not
original to this project). Each lesson is
*build the sentence* — tap the words into the right order — and carries the
original lesson pages, styled for light and dark themes.

### 🔤 Vocabulary — 14,283 words
CEFR-leveled A1–C2, fully offline. Each word shows:
- **Russian translation** (99% coverage)
- **IPA transcription** (e.g. water → /ˈwɔtɚ/) for ~13.4k words
- **Dictionary meanings** grouped by part of speech, with example sentences
- **Russian for every definition and example**
- **Pronunciation** (text-to-speech) and a "mark as known" tracker

Word list built by auditing several learner-graded sources (CEFR-J, EFLLex,
NGSL) so everyday words (banana, apron, astronaut…) are included, not just
high-frequency ones.

---

## Get it / run it

| Platform | How |
|---|---|
| **Android** | Install `dist/english_trainer.apk` |
| **Windows** | Unzip `dist/EnglishTrainer-Windows.zip` → double-click `english_trainer.exe` (portable, no install) |
| **Linux** | `app/build/linux/x64/release/bundle/english_trainer` |

### Build from source
```bash
cd app
flutter pub get
flutter build apk     --release   # Android  → build/app/outputs/flutter-apk/
flutter build linux   --release   # Linux    → build/linux/x64/release/bundle/
flutter build windows --release   # Windows  → build/windows/x64/runner/Release/  (needs Windows + Visual Studio)
```
Windows can also be built in the cloud via GitHub Actions (see
`.github/workflows/windows-build.yml`) — no Windows PC required; download the zip
from the run's **Artifacts**.

**iOS:** the code is iOS-ready, but Apple requires a Mac/Xcode to build and a paid
Apple Developer account for easy install (TestFlight). Not included in `dist/`.

---

## Project layout

```
app/                    Flutter app (lib/, assets/, android/ linux/ windows/ runners)
  assets/
    content.json        320 book chapters + the 32-lesson course (EN + RU)
    words.json          14,283 vocabulary words (senses, level, POS, Russian)
    ipa.json            IPA transcriptions (CMU dictionary)
    examples_ru.json    Russian for example sentences
    definitions_ru.json Russian for definitions
content_pipeline/       extract.py — mines the grammar book → content.json
vocab_pipeline/         build_vocab.py + ru/ + helper scripts → words.json
  wordlists/            reference CEFR word lists (EFLLex, CEFR-J) + README
dist/                   built APK / Windows zip
```

## Content sources

> **Third-party content — the 32-lesson course.** The course lesson pages and
> all 11,504 practice sentences are **not** original to this project. They were
> written by the team behind the Android app **«1st English — учим
> английский»** (v1.0.11, package `com.kirson.firstenglish`) — developers from
> **Kyrgyzstan** — and taken from that app's own database. The app is no longer
> published.
>
> Full credit for that course belongs to them, and none of it is licensed to
> this project. It is reproduced here for personal study only. If you are one
> of its authors and would like it removed, open an issue and it will be taken
> down.

- **Course (32 lessons, 11,504 drills):** «1st English — учим английский», by
  its Kyrgyz developers (`content.db`, tables `grammar` / `drills` /
  `lesson_dict`). See the note above.
- **Grammar:** a 310-chapter + 10-appendix English grammar/phonetics book and its
  full Russian edition (authored for this project).
- **Vocabulary levels/list:** Maximax67 CEFR-J dataset, audited against
  [EFLLex](https://cental.uclouvain.be/cefrlex/efllex/) (CC BY-NC-SA) and the
  [CEFR-J Vocabulary Profile](https://github.com/openlanguageprofiles/olp-en-cefrj).
- **Definitions & examples:** WordNet (NLTK).
- **IPA:** CMU Pronouncing Dictionary (via NLTK), ARPAbet → IPA.
- **Russian translations:** English/Russian Wiktionary + DeepL API.

Definitions are offline dictionary data; translations were produced with the
DeepL API. No API key is in this repo — credential-shaped filenames are
git-ignored.
