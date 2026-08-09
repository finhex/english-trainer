#!/usr/bin/env python3
"""
Add genuinely useful HIGH-FREQUENCY words that the build filters wrongly dropped
(days of the week, teen/ten numbers, months, and common everyday nouns/verbs).
Curated allow-list (so we don't pull in names / acronyms / inflections). Each
gets WordNet own-lemma senses (correct POS), a frequency-based CEFR level, and
DeepL Russian for the word + its defs/examples. Skips anything already present.
"""
import csv
import json
import urllib.parse
import urllib.request
from pathlib import Path

from nltk.corpus import wordnet as wn

HERE = Path(__file__).parent
ASSETS = HERE.parent / "app" / "assets"
WORDS = ASSETS / "words.json"
EX_RU = ASSETS / "examples_ru.json"
DEF_RU = ASSETS / "definitions_ru.json"
POS = {"n": "noun", "v": "verb", "a": "adjective", "s": "adjective",
       "r": "adverb"}

CURATED = """
monday tuesday wednesday thursday friday saturday sunday
eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen
twenty thirty forty fifty sixty seventy eighty ninety
january february march april may june july august september october november december
tea navy steam treasury gentleman valve heaven membrane rubber leather gulf
remainder universe tour brick wool void chicken vein chapel mankind quartz
sewage alpha den gauge dawn summit grove ammonia bass inn cabin orchestra
canyon chin bark sulphur refuge insulin pearl sage ether ego antenna cardinal
rim herd apex bargain brigade aerial cortex barley scrap corpus altar prairie
mesh flora sorrow consul sauce ferry senate bureau ratio republic embassy
princess jail grace tin rod summit please across despite besides throughout within
""".split()


def own_senses(word, cap=6):
    by_pos, order, seen = {}, [], set()
    for ss in wn.synsets(word):
        if word not in {l.name().lower() for l in ss.lemmas()}:
            continue
        pos = POS.get(ss.pos())
        d = ss.definition()
        if not pos or not d or d in seen:
            continue
        seen.add(d)
        ex = ss.examples()
        by_pos.setdefault(pos, [])
        if pos not in order:
            order.append(pos)
        by_pos[pos].append({"pos": pos, "definition": d,
                            "example": ex[0] if ex else "", "ru": []})
    out, i = [], 0
    while len(out) < cap and any(by_pos.values()):
        p = order[i % len(order)]
        if by_pos[p]:
            out.append(by_pos[p].pop(0))
        i += 1
        if i > 200:
            break
    return out


def deepl_key():
    f = HERE / "ru" / "deepl_key.txt"
    return f.read_text().strip() if f.exists() else ""


def deepl(texts, key):
    if not texts or not key:
        return {}
    url = ("https://api-free.deepl.com/v2/translate" if key.endswith(":fx")
           else "https://api.deepl.com/v2/translate")
    out, texts = {}, list(texts)
    for i in range(0, len(texts), 45):
        batch = texts[i:i + 45]
        data = [("text", t) for t in batch]
        data += [("target_lang", "RU"), ("source_lang", "EN")]
        req = urllib.request.Request(
            url, data=urllib.parse.urlencode(data).encode(),
            headers={"Authorization": f"DeepL-Auth-Key {key}",
                     "Content-Type": "application/x-www-form-urlencoded"})
        with urllib.request.urlopen(req, timeout=60) as r:
            res = json.loads(r.read())["translations"]
        for src, tr in zip(batch, res):
            out[src] = tr["text"]
    return out


def freq_rank():
    rank = {}
    with open(HERE / "data" / "words.csv", newline="") as f:
        for row in csv.DictReader(f):
            w = row["word"].strip().lower()
            if w and w not in rank:
                rank[w] = int(row["word_id"])
    return rank


LEVEL_NAMES = {1: "A1 · Beginner", 2: "A2 · Elementary", 3: "B1 · Intermediate",
               4: "B2 · Upper-Intermediate", 5: "C1 · Advanced",
               6: "C2 · Proficiency / Advanced+"}
DAYS_NUMS_MONTHS = set("""monday tuesday wednesday thursday friday saturday sunday
eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty
thirty forty fifty sixty seventy eighty ninety january february march april may june
july august september october november december""".split())


def level_for(word, rank):
    if word in DAYS_NUMS_MONTHS:
        return 1
    r = rank.get(word, 6000)
    return 1 if r < 1500 else 2 if r < 3000 else 3 if r < 5000 else 4 if r < 8000 else 5


def main():
    data = json.loads(WORDS.read_text(encoding="utf-8"))
    have = {w["word"] for w in data["words"]}
    ex_cache = json.loads(EX_RU.read_text(encoding="utf-8"))
    def_cache = json.loads(DEF_RU.read_text(encoding="utf-8"))
    rank = freq_rank()

    todo = [w for w in dict.fromkeys(CURATED) if w not in have]
    print(f"{len(todo)} to add (of {len(set(CURATED))} curated)")

    entries, new_defs, new_exs = [], set(), set()
    for word in todo:
        senses = own_senses(word)
        if not senses:
            print(f"   skip {word}: no WordNet senses")
            continue
        pos = []
        for s in senses:
            if s["pos"] not in pos:
                pos.append(s["pos"])
        lvl = level_for(word, rank)
        entries.append({"word": word, "level": lvl,
                        "levelName": LEVEL_NAMES[lvl], "pos": pos,
                        "senses": senses, "simple": "", "myExamples": [],
                        "ru": []})
        for s in senses:
            if s["definition"] and s["definition"] not in def_cache:
                new_defs.add(s["definition"])
            if s["example"] and s["example"] not in ex_cache:
                new_exs.add(s["example"])

    key = deepl_key()
    ru_words = deepl([e["word"] for e in entries], key)
    def_cache.update(deepl(new_defs, key))
    ex_cache.update(deepl(new_exs, key))
    for e in entries:
        tr = (ru_words.get(e["word"], "") or "").strip()
        e["ru"] = [tr] if tr else []

    data["words"].extend(entries)
    WORDS.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    EX_RU.write_text(json.dumps(ex_cache, ensure_ascii=False), encoding="utf-8")
    DEF_RU.write_text(json.dumps(def_cache, ensure_ascii=False),
                      encoding="utf-8")
    print(f"added {len(entries)} words · new defs {len(new_defs)} "
          f"exs {len(new_exs)} · total {len(data['words'])}")


if __name__ == "__main__":
    main()
