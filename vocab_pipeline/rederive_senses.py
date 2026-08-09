#!/usr/bin/env python3
"""
Fix wrong parts-of-speech / explanations: for every word that WordNet lists as a
word OF ITS OWN (a lemma), use THOSE senses (correct POS + definition) instead of
the base verb's — e.g. building/meeting -> noun, increased/excited/tired ->
adjective, added -> (manual) adjective. Preserves word-level ru; new definitions
& examples are translated with DeepL into the overlays. Words that WordNet only
knows via their base (rare) keep their existing senses, unless overridden below.
"""
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

# participial adjectives WordNet has no own synset for (keeps them as verbs)
OVERRIDES = {
    "added": {"pos": "adjective",
              "definition": "gained or acquired; existing in addition",
              "example": "the added expense of insurance",
              "ru_word": ["добавленный", "дополнительный"]},
    "called": {"pos": "adjective",
               "definition": "given or identified by a particular name",
               "example": "a man called John",
               "ru_word": ["называемый", "именуемый"]},
}


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
    out = {}
    texts = list(texts)
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


def main():
    data = json.loads(WORDS.read_text(encoding="utf-8"))
    ex_cache = json.loads(EX_RU.read_text(encoding="utf-8"))
    def_cache = json.loads(DEF_RU.read_text(encoding="utf-8"))

    changed = 0
    new_defs, new_exs = set(), set()
    for w in data["words"]:
        word = w["word"]
        if word in OVERRIDES:
            o = OVERRIDES[word]
            w["senses"] = [{"pos": o["pos"], "definition": o["definition"],
                            "example": o["example"], "ru": []}]
            w["pos"] = [o["pos"]]
            if not w.get("ru"):
                w["ru"] = o["ru_word"]
            new_defs.add(o["definition"])
            if o["example"]:
                new_exs.add(o["example"])
            changed += 1
            continue
        own = own_senses(word)
        if not own:
            continue
        new_pos = []
        for s in own:
            if s["pos"] not in new_pos:
                new_pos.append(s["pos"])
        if new_pos == w.get("pos") and \
                [s["definition"] for s in own] == \
                [s["definition"] for s in w["senses"]]:
            continue
        w["senses"] = own
        w["pos"] = new_pos
        changed += 1
        for s in own:
            if s["definition"] and s["definition"] not in def_cache:
                new_defs.add(s["definition"])
            if s["example"] and s["example"] not in ex_cache:
                new_exs.add(s["example"])

    key = deepl_key()
    print(f"changed {changed} words · translating {len(new_defs)} defs + "
          f"{len(new_exs)} examples")
    def_cache.update(deepl(new_defs, key))
    ex_cache.update(deepl(new_exs, key))

    WORDS.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    EX_RU.write_text(json.dumps(ex_cache, ensure_ascii=False), encoding="utf-8")
    DEF_RU.write_text(json.dumps(def_cache, ensure_ascii=False),
                      encoding="utf-8")
    print("done")


if __name__ == "__main__":
    main()
