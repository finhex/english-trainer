#!/usr/bin/env python3
"""Print a readable sample of the Russian translations for eyeballing quality.

  ./.venv/bin/python ru/sample_ru.py            # a spread of words per level
  ./.venv/bin/python ru/sample_ru.py time run   # specific words
"""
import json
import random
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
words = json.loads((ROOT / "app/assets/words.json").read_text(encoding="utf-8"))["words"]
index = {w["word"].lower(): w for w in words}


def show(w):
    print(f"\n{w['word']}  [{w['levelName']}]  ->  {', '.join(w['ru']) or '(none)'}")
    for s in w["senses"]:
        ru = ", ".join(s["ru"]) or "—"
        print(f"    ({s['pos']}) {s['definition'][:70]}\n        {ru}")


if len(sys.argv) > 1:
    for a in sys.argv[1:]:
        w = index.get(a.lower())
        print(f"\n?? {a} not in the word list") if not w else show(w)
else:
    random.seed(7)
    for level in sorted({w["level"] for w in words}):
        pool = [w for w in words if w["level"] == level]
        for w in random.sample(pool, min(4, len(pool))):
            show(w)
