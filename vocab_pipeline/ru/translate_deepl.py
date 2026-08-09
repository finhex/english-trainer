#!/usr/bin/env python3
"""
Translate the vocabulary example sentences to Russian with the DeepL API
(top quality for RU). Batched (up to ~45 sentences/request), cached & resumable.
Writes the SEPARATE overlay file app/assets/examples_ru.json (english -> russian);
words.json is left untouched.

The API key is read from the DEEPL_API_KEY env var, or from ru/deepl_key.txt —
NEVER hard-coded. Free keys (ending ':fx') auto-use the free endpoint.

Run:
    export DEEPL_API_KEY="your-key"        # OR: echo "your-key" > ru/deepl_key.txt
    .venv/bin/python ru/translate_deepl.py --limit 20   # quick test first
    .venv/bin/python ru/translate_deepl.py              # full run (all examples)
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
ASSETS = HERE.parent.parent / "app" / "assets"

# per-field cache + bundled overlay (examples_ru.json / definitions_ru.json)
FILES = {
    "example": (HERE / "example_ru_cache.json", ASSETS / "examples_ru.json"),
    "definition": (HERE / "definition_ru_cache.json",
                   ASSETS / "definitions_ru.json"),
}


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


def translate_batch(url, key, texts):
    data = [("text", t) for t in texts]
    data += [("target_lang", "RU"), ("source_lang", "EN")]
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body, headers={
        "Authorization": f"DeepL-Auth-Key {key}",
        "Content-Type": "application/x-www-form-urlencoded",
    })
    with urllib.request.urlopen(req, timeout=60) as r:
        res = json.loads(r.read())
    return [t["text"] for t in res["translations"]]


def collect(data, field):
    seen, texts = set(), []
    for w in data["words"]:
        for s in w["senses"]:
            e = (s.get(field) or "").strip()
            if e and e not in seen:
                seen.add(e)
                texts.append(e)
    return texts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--field", default="example",
                    choices=["example", "definition"],
                    help="which text to translate")
    ap.add_argument("--limit", type=int, default=10**9,
                    help="max NEW sentences this run")
    ap.add_argument("--batch", type=int, default=45)
    args = ap.parse_args()

    key = get_key()
    if not key:
        print("No API key. Set DEEPL_API_KEY, or put the key in ru/deepl_key.txt")
        return
    url = endpoint(key)

    cache_path, out_ru = FILES[args.field]
    data = json.loads(WORDS.read_text(encoding="utf-8"))
    cache = json.loads(cache_path.read_text(encoding="utf-8")) \
        if cache_path.exists() else {}
    texts = collect(data, args.field)
    todo = [t for t in texts if t not in cache]
    chars = sum(len(t) for t in todo)
    print(f"{len(texts)} unique · {len(cache)} cached · {len(todo)} to do "
          f"(~{chars:,} chars) · key …{key[-6:]} · {url.split('//')[1].split('/')[0]}")

    done, t0 = 0, time.time()
    try:
        i = 0
        while i < len(todo) and done < args.limit:
            batch = todo[i:i + args.batch]
            i += len(batch)
            for attempt in range(3):
                try:
                    res = translate_batch(url, key, batch)
                    break
                except urllib.error.HTTPError as e:
                    if e.code == 456:
                        print("QUOTA EXCEEDED — stopping (used your char limit).")
                        raise SystemExit
                    print(f"  HTTP {e.code}, retry…")
                    time.sleep(3 + attempt * 3)
                except Exception as e:
                    print(f"  error {e}, retry…")
                    time.sleep(3)
            else:
                continue
            for src, ru in zip(batch, res):
                cache[src] = ru
            done += len(batch)
            if done % (args.batch * 5) < args.batch:
                cache_path.write_text(json.dumps(cache, ensure_ascii=False),
                                     encoding="utf-8")
                print(f"  {done}/{min(args.limit, len(todo))} "
                      f"({done/(time.time()-t0):.0f}/s)", flush=True)
    finally:
        cache_path.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
        out_ru.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    print(f"done: +{done} new · {len(cache)} total translations -> {out_ru}")


if __name__ == "__main__":
    main()
