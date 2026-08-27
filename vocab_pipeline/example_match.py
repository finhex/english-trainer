"""Does an example sentence actually demonstrate the headword?

WordNet attaches examples to a *synset*, and a synset groups synonyms, so the
stored sentence often illustrates a different lemma: the synset holding
"utilize" is use.v.01, whose first example is "use your head!".  Picking
examples[0] blindly puts that sentence under `utilize`, where it teaches the
wrong word.

`contains_headword` decides whether a sentence shows the word (in any inflected
or derived form); `pick_example` uses it to choose the best sentence a synset
offers, or nothing at all when every sentence is about a synonym.
"""

import json
import os
import re

_IRREGULAR_JSON = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "..", "app", "assets",
    "irregular_verbs.json")

_TOKEN = re.compile(r"[a-z']+")
_SIBILANT = re.compile(r"[sxz]$|ch$|sh$")


def _load_irregulars():
    """form -> {base}, so "said" is recognised as a form of "say"."""
    try:
        with open(_IRREGULAR_JSON, encoding="utf-8") as fh:
            raw = json.load(fh)
    except (OSError, ValueError):
        return {}
    out = {}
    for base, forms in raw.items():
        for field in forms:
            for form in re.split(r"\s*/\s*", field):
                form = form.strip().lower()
                if form:
                    out.setdefault(form, set()).add(base.lower())
    return out


_FORM_TO_BASE = _load_irregulars()


def _inflections(word):
    """Regular inflections and common derivations of `word`."""
    w = word.lower()
    forms = {w}
    if w.endswith("e"):
        forms |= {w[:-1] + "ing", w + "d", w + "s"}
    elif w.endswith("y"):
        forms |= {w[:-1] + "ies", w[:-1] + "ied", w + "ing", w + "s"}
    elif _SIBILANT.search(w):
        forms |= {w + "es", w + "ed", w + "ing"}
    else:
        forms |= {w + "s", w + "ed", w + "ing",
                  w + w[-1] + "ing", w + w[-1] + "ed"}
    forms |= {w + "ly", w + "ness", w + "er", w + "est",
              w + "ment", w + "ion", w + "al"}
    return forms


def _wordnet():
    """WordNet if importable, else None (the regular rules still work)."""
    global _WN
    if _WN is _UNSET:
        try:
            from nltk.corpus import wordnet as wn
            wn.synsets("test")
            _WN = wn
        except Exception:                        # noqa: BLE001
            _WN = None
    return _WN


_UNSET = object()
_WN = _UNSET
_DERIVED_CACHE = {}


def _derived_forms(word):
    """Words WordNet itself links to `word` — utilize→utilization, compare→comparison.

    Guessing these by chopping letters is unsafe: "state" minus its -e plus -ion
    yields "station", which is a different word entirely. WordNet knows the real
    derivational links, so ask it instead.
    """
    if word in _DERIVED_CACHE:
        return _DERIVED_CACHE[word]
    wn = _wordnet()
    out = set()
    if wn is not None:
        try:
            for syn in wn.synsets(word):
                for lemma in syn.lemmas():
                    if lemma.name().lower() != word:
                        continue
                    for rel in lemma.derivationally_related_forms():
                        out.add(rel.name().lower().replace("_", " "))
        except Exception:                        # noqa: BLE001
            out = set()
    _DERIVED_CACHE[word] = out
    return out


def contains_headword(word, sentence):
    """True if `sentence` shows `word` itself rather than one of its synonyms."""
    if not word or not sentence:
        return False
    w = word.lower()
    text = sentence.lower()
    if " " in w or "_" in w:                     # multiword entry: literal match
        return w.replace("_", " ") in text
    forms = _inflections(w)
    tokens = _TOKEN.findall(text)
    for token in tokens:
        if token in forms:
            return True
        if w in _FORM_TO_BASE.get(token, ()):    # irregular form of the word
            return True
    wn = _wordnet()
    if wn is not None:
        for token in tokens:                     # let WordNet undo the inflection
            for pos in ("n", "v", "a", "r"):
                if wn.morphy(token, pos) == w:
                    return True
    derived = _derived_forms(w)
    if derived:
        for token in tokens:
            if token in derived:
                return True
            if wn is not None:
                for pos in ("n", "v", "a", "r"):
                    if wn.morphy(token, pos) in derived:
                        return True
    return False


def pick_example(word, examples, prefer=None):
    """Best sentence in `examples` that demonstrates `word`, else "".

    `prefer` is an optional container of sentences that already have a Russian
    translation; among equally valid candidates the translated one wins so the
    app keeps showing both lines.
    """
    usable = [e for e in (examples or []) if contains_headword(word, e)]
    if not usable:
        return ""
    if prefer:
        for sentence in usable:
            if sentence in prefer:
                return sentence
    return usable[0]
