#!/usr/bin/env python3
"""
Give the dark lesson tables the light theme's cell padding, in place.

import_course.py does this while importing, but re-importing needs the
original eng1stApp database. This applies the same fix to the content.json we
already have, so the two themes agree without a full reimport.

    python3 content_pipeline/fix_dark_tables.py

Only spacing moves across - every colour the dark copy chose is left alone.
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from import_course import match_cell_padding  # noqa: E402

CONTENT = Path(__file__).parent.parent / "app" / "assets" / "content.json"


def main():
    data = json.loads(CONTENT.read_text())
    changed = 0
    for lesson in data["lessons"]:
        light, dark = lesson.get("htmlLight"), lesson.get("htmlDark")
        if not light or not dark:
            continue
        fixed = match_cell_padding(light, dark)
        if fixed != dark:
            lesson["htmlDark"] = fixed
            changed += 1
    CONTENT.write_text(json.dumps(data, ensure_ascii=False))
    print(f"lessons whose dark tables were re-spaced: {changed}")


if __name__ == "__main__":
    main()
