#!/usr/bin/env python3
"""Repair example sentences that demonstrate a synonym instead of the headword.

The senses in app/assets/words.json were built by taking a WordNet synset's
first example. A synset groups synonyms, so that sentence frequently shows a
different lemma: `utilize` shipped with "use your head!".

For every offending sense this looks through the rest of that synset's examples
and takes the first one that really uses the word (preferring a sentence that
already has a Russian translation, so the app keeps showing both lines). When a
synset offers nothing usable the example is cleared: the UI hides an empty
example, and no example is better than one teaching the wrong word.

    python3 fix_examples.py            # report only
    python3 fix_examples.py --write    # rewrite words.json
"""

import argparse
import json
import os
import sys

from example_match import contains_headword, pick_example

HERE = os.path.dirname(os.path.abspath(__file__))
WORDS = os.path.join(HERE, "..", "app", "assets", "words.json")
EX_RU = os.path.join(HERE, "..", "app", "assets", "examples_ru.json")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true",
                    help="rewrite words.json (default: report only)")
    ap.add_argument("--samples", type=int, default=8)
    args = ap.parse_args()

    try:
        from nltk.corpus import wordnet as wn
        wn.synsets("test")
    except Exception as exc:                       # noqa: BLE001
        sys.exit(f"WordNet unavailable ({exc}); run inside vocab_pipeline/.venv")

    with open(WORDS, encoding="utf-8") as fh:
        data = json.load(fh)
    with open(EX_RU, encoding="utf-8") as fh:
        translated = set(json.load(fh))

    total = bad = replaced = cleared = 0
    kept_ru = 0
    swaps, drops = [], []

    for entry in data["words"]:
        word = entry["word"]
        try:
            by_def = {s.definition(): s.examples()
                      for s in wn.synsets(word.replace(" ", "_"))}
        except Exception:                          # noqa: BLE001
            by_def = {}
        for sense in entry.get("senses", []):
            example = (sense.get("example") or "").strip()
            if not example:
                continue
            total += 1
            if contains_headword(word, example):
                continue
            bad += 1
            better = pick_example(word, by_def.get(sense.get("definition", ""), []),
                                  prefer=translated)
            sense["example"] = better
            if better:
                replaced += 1
                if better in translated:
                    kept_ru += 1
                if len(swaps) < args.samples:
                    swaps.append((word, example, better))
            else:
                cleared += 1
                if len(drops) < args.samples:
                    drops.append((word, example))

    print(f"examples inspected     : {total}")
    print(f"  showed a synonym     : {bad}")
    print(f"    replaced           : {replaced}  (kept Russian line: {kept_ru})")
    print(f"    cleared            : {cleared}")
    left = sum(1 for e in data["words"]
               for s in e.get("senses", []) if (s.get("example") or "").strip())
    print(f"examples remaining     : {left}")

    print("\nreplaced:")
    for word, old, new in swaps:
        print(f"  {word}\n     was ✗ {old!r}\n     now ✓ {new!r}")
    print("\ncleared (synset had nothing using the word):")
    for word, old in drops:
        print(f"  {word:<16} ✗ {old!r}")

    if args.write:
        with open(WORDS, "w", encoding="utf-8") as fh:
            json.dump(data, fh, ensure_ascii=False, separators=(",", ":"))
        print(f"\nwrote {WORDS}")
    else:
        print("\n(report only — pass --write to apply)")


if __name__ == "__main__":
    main()
