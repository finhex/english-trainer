#!/usr/bin/env python3
"""
Add the common base/root words that were missing (e.g. abortion is in but its
root `abort` was not). Source: BNC/COCA top-10k content words not already in the
vocab, base forms only (not inflections/plurals/proper). WordNet own-lemma senses
(correct POS, frequency-ordered), CEFR level from BNC frequency band, DeepL
Russian for word + definitions + examples (word-level first so every word gets a
translation even if the definition quota runs out).
"""
import csv
import json
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from nltk.corpus import wordnet as wn
from example_match import pick_example

HERE = Path(__file__).parent
A = HERE.parent / "app" / "assets"
POS = {"n": "noun", "v": "verb", "a": "adjective", "s": "adjective",
       "r": "adverb"}
LN = {1: "A1 · Beginner", 2: "A2 · Elementary", 3: "B1 · Intermediate",
      4: "B2 · Upper-Intermediate", 5: "C1 · Advanced",
      6: "C2 · Proficiency / Advanced+"}


def own_senses(word, cap=6):
    scored = []
    for ss in wn.synsets(word):
        lem = [l for l in ss.lemmas() if l.name().lower() == word]
        if not lem:
            continue
        pos = POS.get(ss.pos())
        d = ss.definition()
        if not pos or not d:
            continue
        scored.append((sum(l.count() for l in lem),
                       {"pos": pos, "definition": d,
                        "example": pick_example(word, ss.examples()),
                        "ru": []}))
    scored.sort(key=lambda t: -t[0])
    out, seen = [], set()
    for _, s in scored:
        if s["definition"] in seen:
            continue
        seen.add(s["definition"])
        out.append(s)
        if len(out) >= cap:
            break
    return out


def key():
    return (HERE / "ru" / "deepl_key.txt").read_text().strip()


class Quota(Exception):
    pass


def deepl(texts, k):
    texts = list(dict.fromkeys(texts))
    if not texts:
        return {}
    url = ("https://api-free.deepl.com/v2/translate" if k.endswith(":fx")
           else "https://api.deepl.com/v2/translate")
    out = {}
    for i in range(0, len(texts), 45):
        b = texts[i:i + 45]
        data = [("text", t) for t in b] + [("target_lang", "RU"),
                                           ("source_lang", "EN")]
        req = urllib.request.Request(
            url, data=urllib.parse.urlencode(data).encode(),
            headers={"Authorization": f"DeepL-Auth-Key {k}",
                     "Content-Type": "application/x-www-form-urlencoded"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                res = json.loads(r.read())["translations"]
        except urllib.error.HTTPError as e:
            if e.code == 456:
                raise Quota
            raise
        for s, t in zip(b, res):
            out[s] = t["text"]
        if i % 450 == 0:
            print(f"    deepl {i}/{len(texts)}", flush=True)
    return out


def main():
    words = Path("/tmp/missing_common.txt").read_text().split()
    # BNC group per word -> CEFR level
    grp = {}
    for r in csv.DictReader(
            open(HERE / "wordlists" / "bnc_coca.csv", encoding="utf-8-sig")):
        w = r["word"].strip().lower()
        try:
            g = int(r["group"])
        except ValueError:
            continue
        grp.setdefault(w, g)

    def lvl(w):
        g = grp.get(w, 8)
        return 2 if g <= 2 else 3 if g <= 4 else 4 if g <= 6 else 5

    data = json.loads((A / "words.json").read_text(encoding="utf-8"))
    have = {w["word"] for w in data["words"]}
    defc = json.loads((A / "definitions_ru.json").read_text(encoding="utf-8"))
    exc = json.loads((A / "examples_ru.json").read_text(encoding="utf-8"))
    k = key()

    entries = []
    for w in sorted(words, key=lvl):  # easiest first
        if w in have:
            continue
        s = own_senses(w)
        if not s:
            continue
        pos = []
        for x in s:
            if x["pos"] not in pos:
                pos.append(x["pos"])
        entries.append({"word": w, "level": lvl(w), "levelName": LN[lvl(w)],
                        "pos": pos, "senses": s, "simple": "",
                        "myExamples": [], "ru": []})
    print(f"building {len(entries)} entries", flush=True)

    # 1) word-level ru for ALL (cheap, guarantees a translation)
    try:
        ruw = deepl([e["word"] for e in entries], k)
    except Quota:
        ruw = {}
        print("quota hit during word translations")
    for e in entries:
        t = (ruw.get(e["word"], "") or "").strip()
        e["ru"] = [t] if t else []

    # 2) definitions then examples until quota
    nd = [d for e in entries for d in
          [s["definition"] for s in e["senses"]] if d not in defc]
    ne = [x for e in entries for x in
          [s["example"] for s in e["senses"]] if x and x not in exc]
    try:
        defc.update(deepl(nd, k))
        exc.update(deepl(ne, k))
    except Quota:
        print("DeepL quota exhausted — remaining defs/examples stay English")

    data["words"].extend(entries)
    (A / "words.json").write_text(json.dumps(data, ensure_ascii=False),
                                  encoding="utf-8")
    (A / "definitions_ru.json").write_text(json.dumps(defc, ensure_ascii=False),
                                           encoding="utf-8")
    (A / "examples_ru.json").write_text(json.dumps(exc, ensure_ascii=False),
                                        encoding="utf-8")
    print(f"added {len(entries)} · total {len(data['words'])}", flush=True)


if __name__ == "__main__":
    main()
