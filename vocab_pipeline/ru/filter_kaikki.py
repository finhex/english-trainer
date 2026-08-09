#!/usr/bin/env python3
"""Stream the kaikki.org English Wiktionary extract from stdin and keep only
the entries for words in app/assets/words.json that carry Russian translations.

wiktextract puts a translation either on the entry (unlinked table) or inside
the sense it belongs to (`senses[].translations`) — we take both, and when it
came from a sense we use that sense's own gloss as the matching text.

Output: ru/kaikki_ru.jsonl  {word, pos, tr:[{ru, sense}]}
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
WORDS = json.loads((ROOT / "app/assets/words.json").read_text())["words"]
WANTED = {w["word"].lower() for w in WORDS}


def russian(items, fallback_sense=""):
    for t in items or []:
        if (t.get("code") or t.get("lang_code")) != "ru":
            continue
        w = t.get("word")
        if not w:
            continue
        yield {"ru": w, "sense": t.get("sense") or fallback_sense}


out = (HERE / "kaikki_ru.jsonl").open("w", encoding="utf-8")
kept = seen = 0
for line in sys.stdin:
    seen += 1
    if '"Russian"' not in line:
        continue
    try:
        e = json.loads(line)
    except Exception:
        continue
    w = (e.get("word") or "").lower()
    if w not in WANTED:
        continue

    tr = list(russian(e.get("translations")))
    for s in e.get("senses", []):
        gloss = (s.get("glosses") or [""])[0]
        tr += list(russian(s.get("translations"), gloss))
    if not tr:
        continue

    out.write(json.dumps(
        {"word": e.get("word"), "pos": e.get("pos"), "tr": tr},
        ensure_ascii=False) + "\n")
    kept += 1
    if kept % 2000 == 0:
        print(f"  seen={seen:,} kept={kept:,}", file=sys.stderr, flush=True)
out.close()
print(f"DONE seen={seen:,} kept={kept:,}", file=sys.stderr)
