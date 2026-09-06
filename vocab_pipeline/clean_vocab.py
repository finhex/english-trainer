#!/usr/bin/env python3
"""
Clean the 10k vocabulary IN PLACE (keeps the existing Russian layer + overlays):
  1. remove pure inflected duplicates whose base word is already present and
     which WordNet does NOT list as a word of their own (so building / meeting /
     painting / feeling — real words — are KEPT; added / generated / checking are
     dropped);
  2. add the common base verbs that build_vocab.py wrongly dropped via its
     len<3 / FUNCTION_WORDS filter (go, do, be, have), with WordNet senses, and
     translate their definitions/examples with DeepL into the ru overlays.

Writes app/assets/words.json, examples_ru.json, definitions_ru.json.
"""
import json
import urllib.parse
import urllib.request
from pathlib import Path

from nltk.corpus import wordnet as wn
from nltk.stem import WordNetLemmatizer
from example_match import pick_example

HERE = Path(__file__).parent
ASSETS = HERE.parent / "app" / "assets"
WORDS = ASSETS / "words.json"
EX_RU = ASSETS / "examples_ru.json"
DEF_RU = ASSETS / "definitions_ru.json"

WN_POS = {"n": "noun", "v": "verb", "a": "adjective", "s": "adjective",
          "r": "adverb"}
lm = WordNetLemmatizer()

# base verbs to add (dropped by build_vocab len<3 / function-word filters),
# with hand word-level Russian
ADD = {
    "go":   ["идти", "ходить", "ехать", "уходить"],
    "do":   ["делать", "выполнять"],
    "be":   ["быть", "являться", "находиться"],
    "have": ["иметь", "обладать"],
}


def is_own_word(w):
    return any(w in {l.name().lower() for l in s.lemmas()}
              for s in wn.synsets(w))


def base_of(w):
    for pos in ("v", "n"):
        b = lm.lemmatize(w, pos)
        if b != w and wn.synsets(b):
            return b
    return None


def wn_senses(word, cap=6):
    by_pos, order, seen = {}, [], set()
    for ss in wn.synsets(word):
        pos = WN_POS.get(ss.pos())
        if not pos:
            continue
        d = ss.definition()
        if not d or d in seen:
            continue
        seen.add(d)
        ex = pick_example(word, ss.examples())
        by_pos.setdefault(pos, [])
        if pos not in order:
            order.append(pos)
        by_pos[pos].append({"pos": pos, "definition": d,
                            "example": ex, "ru": []})
    out, i = [], 0
    while len(out) < cap and any(by_pos.values()):
        pos = order[i % len(order)]
        if by_pos[pos]:
            out.append(by_pos[pos].pop(0))
        i += 1
        if i > 200:
            break
    return out


def deepl_key():
    f = HERE / "ru" / "deepl_key.txt"
    return f.read_text().strip() if f.exists() else ""


def deepl(texts, key):
    if not texts:
        return {}
    url = ("https://api-free.deepl.com/v2/translate" if key.endswith(":fx")
           else "https://api.deepl.com/v2/translate")
    out = {}
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
    words = data["words"]
    vocab = {w["word"] for w in words}

    # 1) removals
    remove = set()
    for w in list(vocab):
        if len(w) < 3 or not w.isalpha() or is_own_word(w):
            continue
        b = base_of(w)
        if b and b in vocab:
            remove.add(w)
    before = len(words)
    words = [w for w in words if w["word"] not in remove]
    print(f"removed {before - len(words)} inflected duplicates")

    # 2) additions
    ex_cache = json.loads(EX_RU.read_text(encoding="utf-8"))
    def_cache = json.loads(DEF_RU.read_text(encoding="utf-8"))
    key = deepl_key()
    new_defs, new_exs = [], []
    new_entries = []
    for word, ru in ADD.items():
        if word in vocab:
            print(f"  {word} already present, skip")
            continue
        senses = wn_senses(word, cap=12)
        # these are primarily VERBS → show verb senses first (WordNet otherwise
        # surfaces obscure nouns first: be→beryllium, go→"a turn", do→"a party")
        senses.sort(key=lambda s: 0 if s["pos"] == "verb" else 1)
        senses = senses[:6]
        pos = []
        for s in senses:
            if s["pos"] not in pos:
                pos.append(s["pos"])
        new_entries.append({
            "word": word, "level": 1, "levelName": "A1 · Beginner",
            "pos": pos, "senses": senses, "simple": "", "myExamples": [],
            "ru": ru,
        })
        for s in senses:
            if s["definition"] and s["definition"] not in def_cache:
                new_defs.append(s["definition"])
            if s["example"] and s["example"] not in ex_cache:
                new_exs.append(s["example"])

    if key:
        print(f"DeepL: {len(new_defs)} defs + {len(new_exs)} examples")
        def_cache.update(deepl(new_defs, key))
        ex_cache.update(deepl(new_exs, key))
    else:
        print("no DeepL key — new senses will show English only")

    words.extend(new_entries)
    print(f"added {len(new_entries)} base verbs: "
          f"{[e['word'] for e in new_entries]}")

    data["words"] = words
    WORDS.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    EX_RU.write_text(json.dumps(ex_cache, ensure_ascii=False), encoding="utf-8")
    DEF_RU.write_text(json.dumps(def_cache, ensure_ascii=False),
                      encoding="utf-8")
    print(f"total words now: {len(words)}")


if __name__ == "__main__":
    main()
