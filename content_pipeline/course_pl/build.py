#!/usr/bin/env python3
"""
Build the Polish layer in app/assets/pl/ from the Russian course.

Unlike the English translation, which is written back into content.json as
htmlEn*, Polish is kept entirely outside the main bundle: everything lands in
app/assets/pl/, so deleting that folder (and its pubspec line) removes Polish
without touching a single byte of the shared content.

    lessons_pl.json   {courseNo: {title, subtitle, light[], dark[]}}
    practice_pl.json  {russian prompt: polish prompt}
    words_pl.json     {headword: [polish translations]}

The book is deliberately not translated: a Polish learner reads it in English,
which is what Lesson.grammarFor already does for any language without its own
text.

Re-runnable: anything still missing a translation is simply left out, and the
app falls back to English for it.
"""
import json, re
from pathlib import Path

HERE = Path(__file__).parent
ROOT = HERE.parent.parent
CONTENT = ROOT / "app" / "assets" / "content.json"
OUT = ROOT / "app" / "assets" / "pl"

# The tense labels are set vertically, one letter per line, so they cannot be
# translated letter by letter; each run is rebuilt with the Polish word.
VERTICAL = {
    "Будущее": "Przyszły",
    "Настоящее": "Teraźniejszy",
    "Прошедшее": "Przeszły",
}
_RUN = re.compile(r"(?:[А-Яа-яЁё]\s*<br\s*/?>\s*){2,}[А-Яа-яЁё]", re.I)


def fix_vertical(html):
    def repl(m):
        word = "".join(re.findall(r"[А-Яа-яЁё]", m.group(0)))
        pl = VERTICAL.get(word)
        return "<br/>".join(pl) if pl else m.group(0)
    return _RUN.sub(repl, html)


# Single Cyrillic letters standing alone in a text node. fix_vertical has
# already rebuilt the vertical tense labels by the time these are looked at, so
# whatever one letter is left is a word in its own right. A few differ by
# lesson: "в" is "do" in lesson 10 ("go into the room") but "o" in lesson 8
# ("at 9 o'clock"), and lesson 11's "У" has no Polish counterpart - dropping it
# lets the fragments after it read as a normal sentence.
SINGLES = {"и": "i", "Я": "Ja", "В": "W", "а": "a", "с": "z", "в": "do"}
SINGLES_BY_LESSON = {8: {"в": "o"}, 11: {"У": ""}}


def translate_html(html, table, singles):
    """Replaces text nodes only - tags, styles, colours and structure stay."""
    out = []
    for chunk in re.split(r"(<[^>]+>)", html):
        if chunk.startswith("<") or not chunk.strip():
            out.append(chunk)
            continue
        s = chunk.strip()
        if not re.search(r"[А-Яа-яЁё]", s):
            out.append(chunk)
            continue
        pl = singles.get(s) if len(s) == 1 else table.get(s)
        if pl is None or (pl == "" and len(s) != 1):
            out.append(chunk)
            continue
        lead = chunk[: len(chunk) - len(chunk.lstrip())]
        tail = chunk[len(chunk.rstrip()):]
        out.append(f"{lead}{pl}{tail}")
    return "".join(out)


def load(name):
    p = HERE / name
    return json.loads(p.read_text()) if p.exists() else {}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    lessons_tr = load("translations.json")
    prompts_tr = load("prompts.json")
    words_tr = load("words.json")

    data = json.loads(CONTENT.read_text())
    course = [l for l in data["lessons"] if l.get("section") == "course"]

    lessons, done, partial = {}, 0, 0
    for l in course:
        no = l.get("courseNo")
        if no is None:
            continue
        entry = {}
        singles = {**SINGLES, **SINGLES_BY_LESSON.get(no, {})}
        for src, dst in (("htmlLight", "light"), ("htmlDark", "dark")):
            parts = l.get(src) or []
            if not parts:
                continue
            entry[dst] = [translate_html(fix_vertical(p), lessons_tr, singles)
                          for p in parts]
        ru_title = l.get("titleRu") or ""
        if lessons_tr.get(ru_title):
            entry["title"] = lessons_tr[ru_title]
        ru_sub = l.get("subtitleRu") or ""
        if lessons_tr.get(ru_sub):
            entry["subtitle"] = lessons_tr[ru_sub]
        # only ship a lesson once its text is actually Polish, so a learner
        # never meets a half-Russian page; the app shows English until then
        text = "".join(entry.get("light") or [])
        left = len(re.findall(r"[А-Яа-яЁё]", re.sub(r"<[^>]+>", " ", text)))
        if entry.get("light") and left == 0:
            lessons[str(no)] = entry
            done += 1
        elif entry.get("light"):
            partial += 1

    prompts = {ru: pl for ru, pl in prompts_tr.items() if pl}
    words = {w.lower(): v for w, v in words_tr.items() if v}

    (OUT / "lessons_pl.json").write_text(
        json.dumps(lessons, ensure_ascii=False), encoding="utf-8")
    (OUT / "practice_pl.json").write_text(
        json.dumps(prompts, ensure_ascii=False), encoding="utf-8")
    (OUT / "words_pl.json").write_text(
        json.dumps(words, ensure_ascii=False), encoding="utf-8")

    total_prompts = len({it["prompt"]
                         for l in course
                         for it in l.get("practices", {})
                                     .get("sentence", {}).get("items", [])})
    print(f"lessons fully Polish : {done}/{len(course)}"
          f"  (still part Russian, not shipped: {partial})")
    print(f"practice prompts     : {len(prompts)}/{total_prompts}")
    print(f"words                : {len(words)}")
    for f in ("lessons_pl.json", "practice_pl.json", "words_pl.json"):
        print(f"  {f:18} {(OUT / f).stat().st_size / 1024:8.1f} KB")


if __name__ == "__main__":
    main()
