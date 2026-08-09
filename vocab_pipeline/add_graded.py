#!/usr/bin/env python3
"""
Add the learner-graded words that our frequency list missed — the union of
EFLLex (15k) + CEFR-J (6.5k) minus what we already have, restricted to real
content words with WordNet senses (list precomputed in missing_content.txt).

Every word gets WordNet own-lemma senses (freq-ordered → correct primary POS),
its CEFR level (CEFR-J explicit, else EFLLex first band), and Russian:
  * word-level ru for ALL words first (cheap, guarantees a translation), then
  * definitions & examples via DeepL, A1→C1 order, until the quota is hit
    (456 → stop translating, still add every word with English + word-ru).
"""
import csv
import json
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from nltk.corpus import wordnet as wn

HERE = Path(__file__).parent
A = HERE.parent / "app" / "assets"
WL = Path("/tmp/claude-1000/-home-konako-Documents-Claude--git-backups-apps-words"
          "/270f0885-6ca7-4eda-94ea-274592317292/scratchpad/wordlists")
POS = {"n": "noun", "v": "verb", "a": "adjective", "s": "adjective",
       "r": "adverb"}
LN = {1: "A1 · Beginner", 2: "A2 · Elementary", 3: "B1 · Intermediate",
      4: "B2 · Upper-Intermediate", 5: "C1 · Advanced",
      6: "C2 · Proficiency / Advanced+"}
LMAP = {"A1": 1, "A2": 2, "B1": 3, "B2": 4, "C1": 5, "C2": 6}


def own_senses(word, cap=6):
    scored = []
    for ss in wn.synsets(word):
        lem = [l for l in ss.lemmas() if l.name().lower() == word]
        pos = POS.get(ss.pos())
        d = ss.definition()
        if not pos or not d:
            continue
        # prefer senses where the word is the lemma; else base senses (low score)
        f = sum(l.count() for l in lem) if lem else -1
        scored.append((f, {"pos": pos, "definition": d,
                           "example": ss.examples()[0] if ss.examples() else "",
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
    f = HERE / "ru" / "deepl_key.txt"
    return f.read_text().strip() if f.exists() else ""


class Quota(Exception):
    pass


def deepl(texts, k):
    texts = list(texts)
    if not texts or not k:
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
        if i % 900 == 0:
            print(f"    deepl {i}/{len(texts)}", flush=True)
    return out


def levels():
    cj = {}
    for r in csv.DictReader(open(WL / "cefrj-main.csv", encoding="utf-8",
                                 errors="ignore")):
        w = (r.get("headword") or "").strip().lower()
        if w and w not in cj:
            cj[w] = LMAP.get(r.get("CEFR", ""), 0)
    ef = {}
    with open(WL / "efllex.tsv", encoding="utf-8") as f:
        for row in csv.DictReader(f, delimiter="\t"):
            w = row["word"].strip().lower()
            if w in ef:
                continue
            for i, band in enumerate(["a1", "a2", "b1", "b2", "c1"], 1):
                try:
                    if float(row.get(f"level_freq@{band}", 0)) > 0:
                        ef[w] = i
                        break
                except ValueError:
                    pass
    return lambda w: cj.get(w) or ef.get(w) or 4


def main():
    words = (WL / "missing_content.txt").read_text().split()
    lvl = levels()
    words.sort(key=lvl)  # A1 first

    data = json.loads((A / "words.json").read_text(encoding="utf-8"))
    have = {w["word"] for w in data["words"]}
    defc = json.loads((A / "definitions_ru.json").read_text(encoding="utf-8"))
    exc = json.loads((A / "examples_ru.json").read_text(encoding="utf-8"))
    k = key()

    entries = []
    for w in words:
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
    print(f"building {len(entries)} entries")

    # 1) word-level ru for ALL (cheap, guarantees a translation)
    try:
        ruw = deepl([e["word"] for e in entries], k)
    except Quota:
        ruw = {}
        print("  quota hit during word translations")
    for e in entries:
        t = (ruw.get(e["word"], "") or "").strip()
        e["ru"] = [t] if t else []

    # 2) defs then examples, A1->C1 order, until quota
    new_defs = [d for e in entries for d in
                ([s["definition"] for s in e["senses"]]) if d not in defc]
    new_exs = [x for e in entries for x in
               ([s["example"] for s in e["senses"]]) if x and x not in exc]
    try:
        defc.update(deepl(dict.fromkeys(new_defs), k))
        exc.update(deepl(dict.fromkeys(new_exs), k))
    except Quota:
        print("  DeepL quota exhausted — remaining senses stay English")

    data["words"].extend(entries)
    (A / "words.json").write_text(json.dumps(data, ensure_ascii=False),
                                  encoding="utf-8")
    (A / "definitions_ru.json").write_text(json.dumps(defc, ensure_ascii=False),
                                           encoding="utf-8")
    (A / "examples_ru.json").write_text(json.dumps(exc, ensure_ascii=False),
                                        encoding="utf-8")
    print(f"added {len(entries)} · total {len(data['words'])}")


if __name__ == "__main__":
    main()
