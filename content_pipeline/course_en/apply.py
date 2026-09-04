#!/usr/bin/env python3
"""
Apply the English translations to the imported course lessons.

`strings.json` holds every unique Russian text node found in the course HTML;
`translations.json` maps each to its English. This walks the lesson HTML,
replaces only TEXT nodes (tags, styles, colors and structure are untouched) and
writes the result back as htmlEnLight / htmlEnDark, leaving the Russian intact.

Re-runnable: strings still missing a translation keep their Russian.
"""
import json, re
from pathlib import Path

HERE = Path(__file__).parent
CONTENT = HERE.parent.parent / "app" / "assets" / "content.json"


def translate_html(html, table):
    out = []
    for chunk in re.split(r"(<[^>]+>)", html):
        if chunk.startswith("<"):
            out.append(chunk)
            continue
        s = chunk.strip()
        if not s or not re.search(r"[А-Яа-яЁё]", s):
            out.append(chunk)
            continue
        en = table.get(s)
        if not en:
            out.append(chunk)
            continue
        # keep the original leading/trailing whitespace around the node
        lead = chunk[: len(chunk) - len(chunk.lstrip())]
        tail = chunk[len(chunk.rstrip()):]
        out.append(f"{lead}{en}{tail}")
    return "".join(out)


# The tense labels are set VERTICALLY - one letter per <div> - so they cannot
# be translated letter by letter. Rebuild each run with the English word.
VERTICAL = {
    "Будущее": "Future",
    "Настоящее": "Present",
    "Прошедшее": "Past",
}
# the letters are separated by <br/> inside a span, not wrapped in divs
_RUN = re.compile(r"(?:[А-Яа-яЁё]\s*<br\s*/?>\s*){2,}[А-Яа-яЁё]", re.I)


def fix_vertical(html):
    def repl(m):
        run = m.group(0)
        word = "".join(re.findall(r"[А-Яа-яЁё]", run))
        en = VERTICAL.get(word)
        if not en:
            return run
        return "<br/>".join(en)
    return _RUN.sub(repl, html)


def main():
    table = {}
    tf = HERE / "translations.json"
    if tf.exists():
        table = json.loads(tf.read_text())
    data = json.loads(CONTENT.read_text())
    done = missing = 0
    for lesson in data["lessons"]:
        if lesson.get("section") != "course":
            continue
        for src, dst in (("htmlLight", "htmlEnLight"),
                         ("htmlDark", "htmlEnDark")):
            parts = lesson.get(src) or []
            lesson[dst] = [fix_vertical(translate_html(p, table))
                           for p in parts]
    # report coverage over the extracted strings
    strings = json.loads((HERE / "strings.json").read_text())
    for s in strings:
        if table.get(s):
            done += 1
        else:
            missing += 1
    CONTENT.write_text(json.dumps(data, ensure_ascii=False))
    pct = 100 * done // max(1, done + missing)
    print(f"translated strings: {done}/{done + missing} ({pct}%)")
    print(f"content.json: {CONTENT.stat().st_size / 1048576:.1f} MB")


if __name__ == "__main__":
    main()
