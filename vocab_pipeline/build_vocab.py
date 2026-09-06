#!/usr/bin/env python3
"""
Vocabulary pipeline: builds a bundled, offline, CEFR-leveled word list where
EACH word carries its part(s) of speech and MULTIPLE meanings.

  * level + POS + frequency  -> open CEFR-J/Oxford dataset (Maximax67)
  * senses (pos, definition, example) -> WordNet (offline, via NLTK)

Everything is baked into words.json so the app works fully offline.
Run under the venv that has nltk:  ./.venv/bin/python build_vocab.py
"""

import argparse
import csv
import json
import urllib.request
from pathlib import Path

from example_match import pick_example

HERE = Path(__file__).parent
DATA = HERE / "data"
DATASET = "https://raw.githubusercontent.com/Maximax67/Words-CEFR-Dataset/main/csv"

LEVEL_NAMES = {
    1: "A1 · Beginner", 2: "A2 · Elementary", 3: "B1 · Intermediate",
    4: "B2 · Upper-Intermediate", 5: "C1 · Advanced", 6: "C2 · Proficiency",
}

# Penn tag -> learner POS (proper nouns excluded on purpose)
POS_MAP = {
    "NN": "noun", "NNS": "noun",
    "VB": "verb", "VBD": "verb", "VBG": "verb", "VBN": "verb",
    "VBP": "verb", "VBZ": "verb",
    "JJ": "adjective", "JJR": "adjective", "JJS": "adjective",
    "RB": "adverb", "RBR": "adverb", "RBS": "adverb",
}

# grammatical/function words excluded — they belong to the grammar lessons
FUNCTION_WORDS = set("""
the and have has had that this these those they them their there then than
was were been being are you your yours she her hers him his its our ours
who whom whose which what when where why how not nor but for with from into
onto upon about over under between among through during before after above
below off out down would will shall should can could may might must ought
need dare does did done also just even still yet already such other another
each every either neither both all any some none more most very too here
thus hence therefore however moreover according cannot around
""".split())

# WordNet POS -> learner POS
WN_POS = {"n": "noun", "v": "verb", "a": "adjective", "s": "adjective",
          "r": "adverb"}


def ensure_dataset():
    DATA.mkdir(exist_ok=True)
    for f in ("words.csv", "word_pos.csv", "pos_tags.csv"):
        p = DATA / f
        if not p.exists():
            print(f"downloading {f} ...")
            urllib.request.urlretrieve(f"{DATASET}/{f}", p)


def load_candidates(top, lemmatize=None):
    """Flat list [(word, level, pos, freq)] of the `top` most frequent content
    words, each at its lowest CEFR level. If `lemmatize` is given, inflected
    forms are collapsed to their base form (states->state, running->run)."""
    tag_pos = {}
    with open(DATA / "pos_tags.csv", newline="") as f:
        for r in csv.DictReader(f):
            if r["tag"] in POS_MAP:
                tag_pos[r["tag_id"]] = POS_MAP[r["tag"]]
    id_word = {}
    with open(DATA / "words.csv", newline="") as f:
        for r in csv.DictReader(f):
            id_word[r["word_id"]] = r["word"]
    best = {}
    with open(DATA / "word_pos.csv", newline="") as f:
        for r in csv.DictReader(f):
            pos = tag_pos.get(r["pos_tag_id"])
            if not pos:
                continue
            word = id_word.get(r["word_id"], "")
            if not word.isalpha() or len(word) < 3:
                continue
            word = word.lower()
            if lemmatize:
                word = lemmatize(word, pos)
            if len(word) < 3 or word in FUNCTION_WORDS:
                continue
            try:
                lvl = min(6, max(1, round(float(r["level"]))))
                freq = int(r["frequency_count"] or 0)
            except ValueError:
                continue
            key = (word, lvl)
            if key not in best or freq > best[key][1]:
                best[key] = (pos, freq)
    lowest = {}
    for (word, lvl), (pos, freq) in best.items():
        if word not in lowest or lvl < lowest[word][0]:
            lowest[word] = (lvl, pos, max(freq, lowest.get(word, (0, 0, 0))[2]))
    flat = [(w, lvl, pos, freq) for w, (lvl, pos, freq) in lowest.items()]
    flat.sort(key=lambda t: -t[3])
    return flat[:top]


def wn_senses(wn, word, cap=6):
    """Return (senses, all_pos). Senses are diversified across parts of speech
    (round-robin) so a word like "run" shows both its verb and noun meanings,
    not just the first POS."""
    by_pos, order, seen = {}, [], set()
    for ss in wn.synsets(word):
        pos = WN_POS.get(ss.pos())
        if not pos:
            continue
        d = ss.definition()
        if not d or d in seen:
            continue
        seen.add(d)
        # A synset groups synonyms, so its first example often demonstrates a
        # different lemma ("use your head!" under `utilize`). Take the first
        # sentence that shows this word, and none if every sentence is about a
        # synonym — a wrong example teaches worse than no example.
        ex = pick_example(word, ss.examples())
        by_pos.setdefault(pos, [])
        if pos not in order:
            order.append(pos)
        by_pos[pos].append({"pos": pos, "definition": d,
                             "example": ex})
    # round-robin across POS buckets until we hit the cap
    out, i = [], 0
    while len(out) < cap and any(by_pos.values()):
        pos = order[i % len(order)]
        if by_pos[pos]:
            out.append(by_pos[pos].pop(0))
        i += 1
        if i > 200:
            break
    return out, order


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(HERE / "words.json"))
    ap.add_argument("--top", type=int, default=10000)
    ap.add_argument("--max-senses", type=int, default=6)
    args = ap.parse_args()

    import nltk
    nltk.download("wordnet", quiet=True)
    nltk.download("omw-1.4", quiet=True)
    from nltk.corpus import wordnet as wn
    from nltk.stem import WordNetLemmatizer

    lem = WordNetLemmatizer()
    simple_to_wn = {"noun": "n", "verb": "v", "adjective": "a", "adverb": "r"}

    def lemmatize(word, pos):
        return lem.lemmatize(word, simple_to_wn.get(pos, "n"))

    ensure_dataset()
    cands = load_candidates(args.top, lemmatize)

    # hand-written learner explanations/examples, merged over WordNet
    overrides = {}
    ov_path = HERE / "overrides.json"
    if ov_path.exists():
        overrides = {k: v for k, v in json.loads(ov_path.read_text()).items()
                     if not k.startswith("_")}

    words_out = []
    per_level = {l: 0 for l in LEVEL_NAMES}
    with_sense = 0
    with_simple = 0
    for word, lvl, pos, _ in cands:
        senses, poses = wn_senses(wn, word, args.max_senses)
        poses = poses or [pos]        # fall back to dataset POS if not in WordNet
        ov = overrides.get(word, {})
        words_out.append({
            "word": word, "level": lvl, "levelName": LEVEL_NAMES[lvl],
            "pos": poses, "senses": senses,
            "simple": ov.get("simple", ""),
            "myExamples": ov.get("examples", []),
        })
        per_level[lvl] += 1
        if senses:
            with_sense += 1
        if ov.get("simple"):
            with_simple += 1

    Path(args.out).write_text(
        json.dumps({"words": words_out}, ensure_ascii=False, indent=1),
        encoding="utf-8")
    for lvl in sorted(LEVEL_NAMES):
        print(f"  {LEVEL_NAMES[lvl]:<24} {per_level[lvl]} words")
    print(f"Total: {len(words_out)} | with WordNet senses: {with_sense} | "
          f"with my explanation: {with_simple}")
    print(f"-> {args.out}")


if __name__ == "__main__":
    main()
