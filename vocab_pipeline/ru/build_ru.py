#!/usr/bin/env python3
"""
Add Russian translations to the bundled vocabulary.

  ru/overrides_ru.json  hand-written {"word": ["перевод", ...]}, wins over everything
  ru/kaikki_ru.jsonl    English Wiktionary translation tables (see filter_kaikki.py)
  ru/ruwikt_ru.jsonl    Russian Wiktionary glosses for English words (filter_ruwikt.py)
  ru/muse_en_ru.txt     MUSE en-ru word pairs, last resort

Writes back into app/assets/words.json:
  word["ru"]            -> ["время", "срок", ...]        (whole word, POS-ordered)
  word["senses"][i]["ru"] -> ["время", ...]              (that meaning specifically)

Run under the venv that has nltk:  ./.venv/bin/python ru/build_ru.py
"""

import argparse
import json
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
WORDS_JSON = ROOT / "app/assets/words.json"

# kaikki part-of-speech -> our learner POS. Our senses only ever use the four
# open classes; everything else lands in "other", which can still translate the
# word as a whole (something, because, ago, ...) but is never used for a sense.
OTHER = "other"
POS_MAP = {
    "noun": "noun", "verb": "verb", "adj": "adjective", "adv": "adverb",
    "pron": OTHER, "conj": OTHER, "prep": OTHER, "det": OTHER,
    "num": OTHER, "intj": OTHER, "particle": OTHER, "phrase": OTHER,
    "prep_phrase": OTHER, "postp": OTHER, "article": OTHER,
}

MAX_WORD_TR = 8      # translations kept for the word as a whole
MAX_SENSE_TR = 4     # translations kept per individual meaning

STOP = set("""
a an the of to in on at by for with from into onto and or but not no is are was
were be been being as that this these those it its his her their our your my
someone something one who which what when where how any all some other another
esp especially usually etc such very more most so than then also often used use
using having have has had do does did make makes made person people thing
things act action state quality manner way given specific particular
""".split())

# a translation is Russian if it is written in Cyrillic
CYR = re.compile(r"[Ѐ-ӿ]")
LAT = re.compile(r"[A-Za-z]")


def clean_ru(s: str) -> str:
    """Normalise one Russian translation cell from a Wiktionary table."""
    s = unicodedata.normalize("NFC", s or "")
    s = re.sub(r"\([^)]*\)", " ", s)          # parenthetical notes
    s = re.sub(r"[̀-ͯ]", "", s)     # stress / combining marks
    # ru.wiktionary prefixes glosses with usage labels: "рекл. устанавливать..."
    s = re.sub(r"^(?:[а-яё]+\.\s*)+", "", s.strip())
    s = s.replace("ё", "ё").strip(" .,;:!? ")
    s = re.sub(r"\s+", " ", s)
    if not s or LAT.search(s) or not CYR.search(s):
        return ""
    if len(s) > 40:
        return ""
    return s


def tokens(text: str) -> set:
    return {t for t in re.findall(r"[a-z']+", (text or "").lower())
            if t not in STOP and len(t) > 2}


def load_kaikki(path: Path):
    """word -> pos -> [ {ru, sense} ... ] preserving Wiktionary order."""
    by_word = defaultdict(lambda: defaultdict(list))
    if not path.exists():
        return by_word
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            try:
                e = json.loads(line)
            except Exception:
                continue
            pos = POS_MAP.get(e.get("pos"))
            if not pos:
                continue
            w = (e.get("word") or "").lower()
            for t in e["tr"]:
                ru = clean_ru(t.get("ru", ""))
                if ru:
                    by_word[w][pos].append({"ru": ru, "sense": t.get("sense") or ""})
    return by_word


def load_ruwikt(path: Path):
    """word -> pos -> [ {ru, sense} ... ] from the Russian Wiktionary glosses.

    A gloss is a Russian definition, often a list of synonyms
    ("оскорбление, брань"), so each one is split into separate translations.
    There is no English sense text to match against, hence sense="".
    """
    by_word = defaultdict(lambda: defaultdict(list))
    if not path.exists():
        return by_word
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            try:
                e = json.loads(line)
            except Exception:
                continue
            pos = POS_MAP.get(e.get("pos"))
            if not pos:
                continue
            w = e["word"].lower()
            for gloss in e["glosses"]:
                for part in re.split(r"[;,]| или ", gloss):
                    ru = clean_ru(part)
                    if ru:
                        by_word[w][pos].append({"ru": ru, "sense": ""})
    return by_word


def load_muse(path: Path):
    """word -> [ru, ...] in the order the dictionary lists them."""
    out = defaultdict(list)
    if not path.exists():
        return out
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            parts = line.split()
            if len(parts) != 2:
                continue
            en, ru = parts[0].lower(), clean_ru(parts[1])
            if ru and ru not in out[en]:
                out[en].append(ru)
    return out


def dedupe(seq, limit):
    seen, out = set(), []
    for x in seq:
        k = x.lower()
        if k not in seen:
            seen.add(k)
            out.append(x)
            if len(out) >= limit:
                break
    return out


# British spelling -> the American headword the dictionaries are keyed on.
# Only ever used when the rewrite actually exists in a dictionary, so a rule
# firing on the wrong word is harmless.
SPELLING = [
    ("ise", "ize"), ("ised", "ized"), ("ising", "izing"), ("isation", "ization"),
    ("iser", "izer"), ("yse", "yze"), ("ysed", "yzed"), ("ysing", "yzing"),
    ("our", "or"), ("ours", "ors"), ("oured", "ored"), ("ouring", "oring"),
    ("ourable", "orable"), ("ourite", "orite"),
    ("tre", "ter"), ("tres", "ters"), ("bre", "ber"),
    ("ogue", "og"), ("mme", "m"), ("xion", "ction"),
    ("ence", "ense"), ("ences", "enses"),
    ("aemia", "emia"), ("oeuvre", "euver"),
]


def variants(word: str):
    """Spelling variants worth trying: fulfil->fulfill, favour->favor, ..."""
    out = []
    for brit, amer in SPELLING:
        if word.endswith(brit):
            out.append(word[: -len(brit)] + amer)
    if word.endswith("l"):
        out.append(word + "l")          # fulfil / instal / enrol
    if word.endswith("lment"):
        out.append(word[:-5] + "llment")  # enrolment -> enrollment
    return out


def forms(word: str):
    """Every headword worth looking up, best first."""
    seen, out = set(), []

    def add(f):
        if f and f not in seen:
            seen.add(f)
            out.append(f)

    add(word)
    for v in variants(word):
        add(v)
    try:
        from nltk.corpus import wordnet as wn
        for tag in ("n", "v", "a", "r"):
            base = wn.morphy(word, tag)
            if base:
                add(base)
                for v in variants(base):
                    add(v)
    except Exception:
        pass
    return out


def entries_for(sources, word):
    """POS -> translation candidates, taking the first source that knows a POS.

    Sources are tried in quality order, and a later one only fills in the parts
    of speech the earlier ones had nothing for.
    """
    merged, exact, hit = {}, True, False
    for by_word in sources:
        for i, form in enumerate(forms(word)):
            entry = by_word.get(form)
            if not entry:
                continue
            for pos, cands in entry.items():
                if pos not in merged:
                    merged[pos] = cands
            hit = True
            if i:
                exact = False
            break
    return merged, hit and not exact


def rank(cands):
    """Order a POS's translations by how central they are.

    A word that Wiktionary gives for many different senses (вода) is the one a
    learner wants first; one tied to a single niche sense (моча) is not.
    Ties keep Wiktionary's own order.
    """
    count, first = defaultdict(int), {}
    for i, c in enumerate(cands):
        ru = c["ru"]
        count[ru] += 1
        first.setdefault(ru, i)
    return [ru for ru in sorted(count, key=lambda r: (-count[r], first[r]))]


def pick_for_sense(cands, definition, example, pos_default):
    """Best translations for one WordNet sense, matched on the gloss text.

    Scored as how much of the *Wiktionary* gloss the WordNet definition covers —
    WordNet definitions are much longer, so a symmetric measure would never fire.
    """
    want = tokens(definition) | tokens(example)
    if not want:
        return pos_default, False
    scored = []
    for c in cands:
        have = tokens(c["sense"])
        if not have:
            continue
        overlap = len(want & have)
        if overlap:
            scored.append((overlap / len(have), overlap, c["ru"]))
    if scored:
        best = max(s[0] for s in scored)
        if best >= 0.34:
            hits = [s for s in scored if s[0] >= max(0.34, best * 0.6)]
            hits.sort(key=lambda s: (-s[0], -s[1]))
            return dedupe([ru for _, _, ru in hits], MAX_SENSE_TR), True
    return pos_default, False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--words", type=Path, default=WORDS_JSON)
    ap.add_argument("--out", type=Path, default=None)
    args = ap.parse_args()
    out_path = args.out or args.words

    data = json.loads(args.words.read_text(encoding="utf-8"))
    words = data["words"]

    print("loading translation sources ...")
    kaikki = load_kaikki(HERE / "kaikki_ru.jsonl")
    ruwikt = load_ruwikt(HERE / "ruwikt_ru.jsonl")
    muse = load_muse(HERE / "muse_en_ru.txt")
    overrides = {}
    ov = HERE / "overrides_ru.json"
    if ov.exists():
        overrides = {k.lower(): v for k, v in
                     json.loads(ov.read_text(encoding="utf-8")).items()
                     if not k.startswith("_") and isinstance(v, list)}
    print(f"  en.wiktionary: {len(kaikki):,}   ru.wiktionary: {len(ruwikt):,}"
          f"   muse: {len(muse):,}   overrides: {len(overrides):,}")
    sources = [kaikki, ruwikt]

    stats = defaultdict(int)
    for w in words:
        word = w["word"].lower()
        by_pos, via_lemma = entries_for(sources, word)

        # per-POS shortlist, most central translation first
        pos_top = {p: rank(cs)[:MAX_SENSE_TR]
                   for p, cs in by_pos.items() if p != OTHER}
        other_top = rank(by_pos.get(OTHER, []))[:MAX_SENSE_TR]

        # The word as a whole. Round-robin across its parts of speech so a verb
        # like "run" leads with "бег … бежать" rather than four noun senses
        # before the first verb. POS the word actually has go first; the closed
        # classes ("because", "something") come last, or alone if that's all
        # Wiktionary has.
        own = [p for p in w.get("pos", []) if p in pos_top]
        groups = own + [p for p in pos_top if p not in own]
        # two at a time, so each POS keeps a usable pair instead of alternating
        ordered = []
        for chunk in range(0, MAX_SENSE_TR, 2):
            for p in groups:
                ordered += pos_top[p][chunk:chunk + 2]
        ru_word = dedupe(ordered + other_top, MAX_WORD_TR)

        if not ru_word and word in muse:
            ru_word = dedupe(muse[word], MAX_WORD_TR)
            stats["from_muse"] += 1
        elif ru_word:
            stats["from_wiktionary"] += 1
            if via_lemma:
                stats["via_lemma"] += 1

        if word in overrides:
            ru_word = dedupe(list(overrides[word]) + ru_word, MAX_WORD_TR)
            stats["overridden"] += 1

        w["ru"] = ru_word
        if not ru_word:
            stats["missing"] += 1

        for s in w.get("senses", []):
            # Never borrow another POS's translations: if Wiktionary knows this
            # word but not this POS, show nothing rather than something wrong.
            # ru_word is only used when there is no Wiktionary data at all.
            fallback = pos_top.get(s["pos"]) or (
                [] if pos_top else ru_word[:MAX_SENSE_TR])
            s["ru"], matched = pick_for_sense(by_pos.get(s["pos"], []),
                                              s.get("definition", ""),
                                              s.get("example", ""),
                                              fallback)
            if s["ru"]:
                stats["senses_translated"] += 1
            if matched:
                stats["senses_matched"] += 1
            stats["senses_total"] += 1

    out_path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")

    total = len(words)
    have = total - stats["missing"]
    print(f"\nwords with a Russian translation: {have:,}/{total:,} "
          f"({have / total:.1%})")
    print(f"  from Wiktionary : {stats['from_wiktionary']:,} "
          f"(of which {stats['via_lemma']:,} via a base form)")
    print(f"  from MUSE       : {stats['from_muse']:,}")
    print(f"  overrides       : {stats['overridden']:,}")
    print(f"  missing         : {stats['missing']:,}")
    print(f"senses translated : {stats['senses_translated']:,}/"
          f"{stats['senses_total']:,}  "
          f"({stats['senses_matched']:,} matched to that exact meaning, "
          f"the rest use the word's main translations for that part of speech)")
    print(f"written -> {out_path}  ({out_path.stat().st_size / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()
