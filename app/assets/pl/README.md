# The Polish layer

Everything Polish in this app lives in this one folder. It is a separate,
optional layer: no other asset and no content in `content.json` is touched by
it, so the whole language can be added or removed on its own.

| file | holds |
|---|---|
| `ui_pl.json` | every interface string, by the same key `strings.dart` uses |
| `lessons_pl.json` | the course lessons: `{courseNo: {title, subtitle, light[], dark[]}}` |
| `practice_pl.json` | practice prompts, keyed by the Russian sentence they replace |
| `words_pl.json` | vocabulary translations, keyed by the lower-case headword |

## The book is not translated

A Polish learner reads the book in **English**. That is deliberate, and it needs
no code: `Lesson.grammarFor` returns the English text for any language that has
no text of its own, so the 321 book chapters are untouched.

## Removing Polish

1. delete this folder
2. delete the `- assets/pl/` line from `app/pubspec.yaml`

Nothing else has to change. `PolishPack.available` becomes false, Polish stops
being offered in Settings, and the app is English/Russian exactly as before.
The loader already tolerates every file here being missing or empty, so a
partly built layer is safe to ship at any time.

## Rebuilding

    python3 content_pipeline/course_pl/build.py

It reads the Russian course from `content.json` plus the translation tables in
`content_pipeline/course_pl/` and writes the three data files here. A lesson is
only written once it is **completely** Polish, so a learner never opens a
half-Russian page; until then the app shows that lesson in English.
