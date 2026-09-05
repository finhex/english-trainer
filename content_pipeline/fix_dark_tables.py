#!/usr/bin/env python3
"""
Rebuild the dark lesson pages from the light ones, recoloured.

The course ships two hand-styled copies of every lesson, and they were not
styled to the same standard. The light copy splits a nested table evenly with
"width: 50%" and pads its cells; the dark copy leaves both out, so the same
table reads as ragged, cramped columns in dark mode - and it marks its
translations with coloured spans where the light copy uses italics. The text is
identical in the two, so the light markup is used for both themes and only its
colours are swapped, out of the course's own dark palette.

    python3 content_pipeline/fix_dark_tables.py

import_course.py does the same while importing; this applies it to the
content.json we already have, without needing the original database.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from colorize import to_dark  # noqa: E402

CONTENT = Path(__file__).parent.parent / "app" / "assets" / "content.json"


def main():
    data = json.loads(CONTENT.read_text())
    changed = 0
    for lesson in data["lessons"]:
        light = lesson.get("htmlLight")
        if not light:
            continue
        dark = [to_dark(part) for part in light]
        if dark != lesson.get("htmlDark"):
            lesson["htmlDark"] = dark
            changed += 1
    CONTENT.write_text(json.dumps(data, ensure_ascii=False))
    print(f"lessons whose dark pages were rebuilt from light: {changed}")


if __name__ == "__main__":
    main()
