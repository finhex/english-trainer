#!/usr/bin/env python3
"""
Backfill per-POS word-level Russian translations for the ~12% of words where a
whole part-of-speech has NO Wiktionary translation (so its line was missing from
the top of the word screen — e.g. the adjective sense of "ageing").

For each sense whose POS group lacks any `ru`, translate the HEADWORD with DeepL
using that sense's English DEFINITION as `context`, so DeepL picks the right
part of speech / meaning (world[adj] -> мировой, ageing[adj] -> стареющий).

Writes `sense.ru` back into app/assets/words.json IN PLACE. Cached & resumable
in ru/pos_backfill_cache.json (key = "word\tdefinition"). Re-run safely after any
ru-layer rebuild. Key from $DEEPL_API_KEY or ru/deepl_key.txt (never hard-coded).

    .venv/bin/python ru/backfill_pos_ru.py --dry      # count only, no API calls
    .venv/bin/python ru/backfill_pos_ru.py            # run
"""
import argparse
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
WORDS = HERE.parent.parent / "app" / "assets" / "words.json"
CACHE = HERE / "pos_backfill_cache.json"


def get_key():
    k = os.environ.get("DEEPL_API_KEY", "").strip()
    if not k:
        f = HERE / "deepl_key.txt"
        if f.exists():
            k = f.read_text().strip()
    return k


def endpoint(key):
    return ("https://api-free.deepl.com/v2/translate" if key.endswith(":fx")
            else "https://api.deepl.com/v2/translate")


def translate(url, key, word, ctx):
    data = [("text", word), ("target_lang", "RU"), ("source_lang", "EN"),
            ("context", ctx)]
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, headers={
        "Authorization": f"DeepL-Auth-Key {key}",
        "Content-Type": "application/x-www-form-urlencoded",
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["translations"][0]["text"]


def gap_senses(data):
    """Yield (word_obj, sense) for senses whose POS group has no ru at all."""
    for w in data["words"]:
        has = {}
        for s in w["senses"]:
            has.setdefault(s["pos"], False)
            if s.get("ru"):
                has[s["pos"]] = True
        for s in w["senses"]:
            if not has[s["pos"]] and (s.get("definition") or "").strip():
                yield w, s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true", help="count only, no API")
    ap.add_argument("--limit", type=int, default=10**9)
    args = ap.parse_args()

    data = json.loads(WORDS.read_text(encoding="utf-8"))
    todo = list(gap_senses(data))
    chars = sum(len(w["word"]) for w, _ in todo)
    print(f"{len(todo)} gap senses across "
          f"{len({w['word'] for w, _ in todo})} words · ~{chars:,} headword chars")
    if args.dry:
        return

    key = get_key()
    if not key:
        print("No API key (set DEEPL_API_KEY or ru/deepl_key.txt).")
        return
    url = endpoint(key)
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}

    done, t0 = 0, time.time()
    try:
        for w, s in todo:
            if done >= args.limit:
                break
            ck = f"{w['word']}\t{s['definition']}"
            ru = cache.get(ck)
            if ru is None:
                ctx = f"({s['pos']}) {s['definition']}"
                for attempt in range(3):
                    try:
                        ru = translate(url, key, w["word"], ctx)
                        break
                    except urllib.error.HTTPError as e:
                        if e.code == 456:
                            print("QUOTA EXCEEDED — stopping.")
                            raise SystemExit
                        time.sleep(3 + attempt * 3)
                    except Exception:
                        time.sleep(3)
                else:
                    continue
                cache[ck] = ru
                done += 1
                if done % 100 == 0:
                    CACHE.write_text(json.dumps(cache, ensure_ascii=False),
                                     encoding="utf-8")
                    print(f"  {done} ({done/(time.time()-t0):.0f}/s)", flush=True)
            # apply into the sense (dedupe, keep any existing)
            cur = s.get("ru") or []
            if ru and ru not in cur:
                s["ru"] = cur + [ru]
    finally:
        CACHE.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
        WORDS.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    print(f"done: +{done} new translations · words.json updated")


if __name__ == "__main__":
    main()
