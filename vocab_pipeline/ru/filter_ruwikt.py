#!/usr/bin/env python3
"""Stream the kaikki.org Russian Wiktionary extract from stdin and keep the
English-language entries for words in app/assets/words.json.

ru.wiktionary describes English words with Russian glosses ("abuse" ->
"злоупотребление"), which covers a lot of what the English Wiktionary's
translation tables miss.

Usage:
  curl -sSL https://kaikki.org/dictionary/downloads/ru/ru-extract.jsonl.gz \\
    | gunzip | python3 ru/filter_ruwikt.py

Output: ru/ruwikt_ru.jsonl  {word, pos, glosses:[...]}
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
WORDS = json.loads((ROOT / "app/assets/words.json").read_text())["words"]
WANTED = {w["word"].lower() for w in WORDS}

out = (HERE / "ruwikt_ru.jsonl").open("w", encoding="utf-8")
kept = seen = 0
for line in sys.stdin:
    seen += 1
    if '"lang_code": "en"' not in line:
        continue
    try:
        e = json.loads(line)
    except Exception:
        continue
    if e.get("lang_code") != "en":
        continue
    if (e.get("word") or "").lower() not in WANTED:
        continue
    glosses = [g for s in e.get("senses", [])
               for g in (s.get("glosses") or s.get("raw_glosses") or [])]
    if not glosses:
        continue
    out.write(json.dumps(
        {"word": e["word"], "pos": e.get("pos"), "glosses": glosses},
        ensure_ascii=False) + "\n")
    kept += 1
    if kept % 2000 == 0:
        print(f"  seen={seen:,} kept={kept:,}", file=sys.stderr, flush=True)
out.close()
print(f"DONE seen={seen:,} kept={kept:,}", file=sys.stderr)
