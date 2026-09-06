#!/usr/bin/env python3
"""
Add common -ed PARTICIPIAL ADJECTIVES that are missing while their base verb is
present (e.g. abandon is in but abandoned isn't; added is in but many peers were
not). Only forms WordNet lists as an adjective of their own, frequency < 10k.
Own-lemma senses (correct POS), frequency-based CEFR level, DeepL Russian for the
word + defs + examples into the overlays. Skips anything already present.
"""
import csv
import json
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
        ex = pick_example(word, ss.examples())
        scored.append((sum(l.count() for l in lem),
                       {"pos": pos, "definition": d,
                        "example": ex, "ru": []}))
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


def deepl_key():
    f = HERE / "ru" / "deepl_key.txt"
    return f.read_text().strip() if f.exists() else ""


def deepl(texts, key):
    texts = list(texts)
    if not texts or not key:
        return {}
    url = ("https://api-free.deepl.com/v2/translate" if key.endswith(":fx")
           else "https://api.deepl.com/v2/translate")
    out = {}
    for i in range(0, len(texts), 45):
        b = texts[i:i + 45]
        data = [("text", t) for t in b]
        data += [("target_lang", "RU"), ("source_lang", "EN")]
        req = urllib.request.Request(
            url, data=urllib.parse.urlencode(data).encode(),
            headers={"Authorization": f"DeepL-Auth-Key {key}",
                     "Content-Type": "application/x-www-form-urlencoded"})
        try:
            with urllib.request.urlopen(req, timeout=60) as r:
                res = json.loads(r.read())["translations"]
        except urllib.error.HTTPError as e:
            if e.code == 456:
                print("  DeepL quota exhausted — remaining stay English")
                break
            raise
        for s, t in zip(b, res):
            out[s] = t["text"]
    return out


def main():
    data = json.loads((A / "words.json").read_text(encoding="utf-8"))
    have = {w["word"] for w in data["words"]}
    defc = json.loads((A / "definitions_ru.json").read_text(encoding="utf-8"))
    exc = json.loads((A / "examples_ru.json").read_text(encoding="utf-8"))

    rank = {}
    for row in csv.DictReader(open(HERE / "data" / "words.csv", newline="")):
        w = row["word"].strip().lower()
        if w and w not in rank:
            rank[w] = int(row["word_id"])

    def lvl(w):
        r = rank.get(w, 7000)
        return (1 if r < 1500 else 2 if r < 3000 else 3 if r < 5000
                else 4 if r < 8000 else 5)

    todo = []
    for w, r in sorted(rank.items(), key=lambda x: x[1]):
        if r > 10000:
            break
        if not w.endswith("ed") or w in have or len(w) < 5 or not w.isalpha():
            continue
        if any(s.pos() in ("a", "s") and w in {l.name().lower()
               for l in s.lemmas()} for s in wn.synsets(w)):
            todo.append(w)
    print(f"{len(todo)} participial adjectives to add")

    entries, nd, ne = [], set(), set()
    for w in todo:
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
        for x in s:
            if x["definition"] and x["definition"] not in defc:
                nd.add(x["definition"])
            if x["example"] and x["example"] not in exc:
                ne.add(x["example"])

    key = deepl_key()
    ruw = deepl([e["word"] for e in entries], key)
    defc.update(deepl(nd, key))
    exc.update(deepl(ne, key))
    for e in entries:
        t = (ruw.get(e["word"], "") or "").strip()
        e["ru"] = [t] if t else []

    data["words"].extend(entries)
    (A / "words.json").write_text(json.dumps(data, ensure_ascii=False),
                                  encoding="utf-8")
    (A / "definitions_ru.json").write_text(json.dumps(defc, ensure_ascii=False),
                                           encoding="utf-8")
    (A / "examples_ru.json").write_text(json.dumps(exc, ensure_ascii=False),
                                        encoding="utf-8")
    print(f"added {len(entries)} · new defs {len(nd)} exs {len(ne)} · "
          f"total {len(data['words'])}")


if __name__ == "__main__":
    main()
