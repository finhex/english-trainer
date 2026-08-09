#!/usr/bin/env python3
"""
Translate the vocabulary EXAMPLE SENTENCES (and optionally definitions) into
Russian with a LOCAL Ollama model (e.g. Gemma). Offline, free, no API key.

It writes `sense.exampleRu` (and with --also-definitions, `sense.definitionRu`)
back into app/assets/words.json, so the app can show Russian examples in
Russian mode.

RESUMABLE: every translation is cached in `example_ru_cache.json`; re-running
never re-translates. Safe to stop/restart (there are ~14k unique sentences, so
a full run takes a while).

Usage (run ONLY when you're ready; make sure `ollama serve` is running):
    # translate everything, in batches you can stop anytime:
    python3 translate_examples.py --model gemma3

    # do a quick 50-sentence test first:
    python3 translate_examples.py --model gemma3 --limit 50

    # also translate the English definitions:
    python3 translate_examples.py --model gemma3 --also-definitions

After a run, rebuild the app so the new words.json is bundled.
NOTE: if you ever rerun build_vocab.py it wipes translations — rerun
ru/build_ru.py then this script again (both read from cache, so it's fast).
"""

import argparse
import json
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
WORDS = HERE.parent.parent / "app" / "assets" / "words.json"
CACHE = HERE / "example_ru_cache.json"

PROMPT = (
    "Translate this English sentence into natural, correct Russian. "
    "Reply with ONLY the Russian translation — no quotes, no notes, no English.\n\n"
    "{text}"
)


def translate(host, model, text, timeout, think=False):
    # /api/chat applies the model's instruct template; think=False disables the
    # reasoning phase of thinking-models (e.g. gemma4:26b) so we get the answer
    # directly (~20x faster, and for simple sentence translation just as good).
    body = json.dumps({
        "model": model,
        "think": think,
        "messages": [{"role": "user", "content": PROMPT.format(text=text)}],
        "stream": False,
        "options": {"temperature": 0.2, "num_predict": 1024 if think else 160},
    }).encode()
    req = urllib.request.Request(
        host.rstrip("/") + "/api/chat", data=body,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        out = json.loads(r.read())["message"]["content"].strip()
    out = out.strip().strip('"').strip("«»").strip()
    if out.lower().startswith("russian:"):
        out = out.split(":", 1)[1].strip()
    return out


def collect_texts(data, also_defs):
    keys = ["example", "definition"] if also_defs else ["example"]
    seen, texts = set(), []
    for w in data["words"]:
        for s in w["senses"]:
            for k in keys:
                t = (s.get(k) or "").strip()
                if t and t not in seen:
                    seen.add(t)
                    texts.append(t)
    return texts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--words", default=str(WORDS))
    ap.add_argument("--model", default="gemma4:26b",
                    help="Ollama model tag (run `ollama list` to see yours)")
    ap.add_argument("--host", default="http://localhost:11434")
    ap.add_argument("--limit", type=int, default=1_000_000,
                    help="max NEW translations this run (default: all)")
    ap.add_argument("--think", action="store_true",
                    help="enable model 'thinking' (~20x slower, no quality gain "
                         "for simple sentences)")
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--also-definitions", action="store_true")
    args = ap.parse_args()

    data = json.loads(Path(args.words).read_text(encoding="utf-8"))
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}

    texts = collect_texts(data, args.also_definitions)
    todo = [t for t in texts if t not in cache]
    print(f"{len(texts)} unique texts · {len(cache)} cached · {len(todo)} to do "
          f"· model={args.model}")

    done, t0 = 0, time.time()
    try:
        for t in todo:
            if done >= args.limit:
                break
            try:
                cache[t] = translate(args.host, args.model, t, args.timeout,
                                     think=args.think)
            except urllib.error.URLError as e:
                print(f"\nOllama not reachable ({e}). Is `ollama serve` running "
                      f"and model '{args.model}' pulled? Stopping.")
                break
            done += 1
            if done % 25 == 0:
                CACHE.write_text(json.dumps(cache, ensure_ascii=False),
                                 encoding="utf-8")
                rate = done / max(1e-9, time.time() - t0)
                print(f"  {done}/{min(args.limit, len(todo))}  "
                      f"({rate:.1f}/s)  e.g. {t[:40]!r} -> {cache[t][:40]!r}")
    finally:
        CACHE.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")

    # write translations back into words.json
    filled = 0
    for w in data["words"]:
        for s in w["senses"]:
            ex = (s.get("example") or "").strip()
            if ex and ex in cache:
                s["exampleRu"] = cache[ex]
                filled += 1
            if args.also_definitions:
                d = (s.get("definition") or "").strip()
                if d and d in cache:
                    s["definitionRu"] = cache[d]
    Path(args.words).write_text(
        json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"newly translated: {done} · exampleRu filled: {filled} "
          f"-> {args.words}")


if __name__ == "__main__":
    main()
