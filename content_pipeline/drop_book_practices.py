#!/usr/bin/env python3
"""
Take the practices out of the book chapters.

The book is a reference to read, not a drill: its 263 grammar chapters each
carried a word_order / word_type / gap_fill set, which is not what the book is
for. The 32 course lessons keep theirs - those ARE the exercises.

    python3 content_pipeline/drop_book_practices.py

Only the "grammar" section is touched, and only its "practices" field. The
chapter text, titles, ordering and ids are left exactly as they are, and the
screens are data-driven - a chapter with no practices simply stops offering
any, with no code change needed.
"""
import json
from pathlib import Path

CONTENT = Path(__file__).parent.parent / "app" / "assets" / "content.json"
SECTION = "grammar"


def main():
    data = json.loads(CONTENT.read_text())
    chapters = items = 0
    for lesson in data["lessons"]:
        if lesson.get("section") != SECTION:
            continue
        practices = lesson.get("practices") or {}
        if not practices:
            continue
        chapters += 1
        items += sum(len(p.get("items", [])) for p in practices.values())
        lesson["practices"] = {}
    CONTENT.write_text(json.dumps(data, ensure_ascii=False))
    print(f"book chapters cleared : {chapters}")
    print(f"practice items removed: {items}")


if __name__ == "__main__":
    main()
