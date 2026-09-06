#!/usr/bin/env python3
"""
Audit the "forms" block of every entry in word_full.json.

The forms (plural / past / comparative / superlative) were scraped from
Wiktionary and a good number of them are wrong. They fail in four distinct
ways, and each needs its own answer:

  unattested   a form for a part of speech the word does not have - "adult" is
               a noun and an adjective here, yet carries past "adulted", and
               "only" carries plural "onlys". Checked against three sources
               (the entry's own senses, words.json's POS list, and WordNet);
               a form is only called unattested when none of them has the
               part of speech it would need.

  irregular    a regular -ed past on a verb that is irregular - "beared" for
               bear, "sticked" for stick. Checked against irregular_verbs.json.
               Verbs with a genuine second, regular sense (ring/ringed,
               wind/winded) are reported separately and left alone.

  capitalised  the scraper took a proper-noun or acronym entry instead of the
               ordinary word: "act" -> "ACTs", "much" -> "Muches". Harmless to
               fix where lower-casing gives the regular inflection.

  malformed    leftover markup or editorial text, e.g. "partial" -> past
               "participle (US) partialed".

    python3 vocab_pipeline/audit_forms.py            # report only
    python3 vocab_pipeline/audit_forms.py --write    # apply the fixes

Reports to stdout and writes the full list to forms_audit.json. Nothing is
changed without --write.
"""
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).parent.parent
ASSETS = ROOT / "app" / "assets"
FULL = ASSETS / "word_full.json"
WORDS = ASSETS / "words.json"
IRREGULAR = ASSETS / "irregular_verbs.json"
REPORT = Path(__file__).parent / "forms_audit.json"

# which parts of speech make each form meaningful
NOUNY = {"noun", "name"}
ADJY = {"adj", "adjective", "adv", "adverb"}
NEEDS = {"plural": NOUNY, "past": {"verb"},
         "comparative": ADJY, "superlative": ADJY}


# Irregular plurals whose value the scrape sometimes gets wrong by applying the
# regular rule. Only entries where one spelling is simply wrong are listed:
# "indexes" and "farther" are both real, so they are not here.
IRREGULAR_PLURALS = {
    "child": "children", "man": "men", "woman": "women", "foot": "feet",
    "tooth": "teeth", "goose": "geese", "mouse": "mice", "louse": "lice",
    "person": "people", "ox": "oxen", "datum": "data", "criterion": "criteria",
    "phenomenon": "phenomena", "analysis": "analyses", "basis": "bases",
    "crisis": "crises", "thesis": "theses", "hypothesis": "hypotheses",
    "cactus": "cacti", "fungus": "fungi", "nucleus": "nuclei",
    "stimulus": "stimuli", "bacterium": "bacteria", "curriculum": "curricula",
    "sheep": "sheep", "deer": "deer", "species": "species", "series": "series",
}


# A handful the scrape simply got from the wrong entry, and which no rule
# catches because the entry itself carries an obscure verb sense: "doe" is a
# deer, "git" an insult, "sac" a pouch, yet each was given the past of the
# verb it merely resembles. Checked by hand, dropped by name.
# Every one of these was read individually. A heuristic cannot help here:
# whatever rule separates "doe" -> "did" from "smite" -> "smote" would have to
# know that a doe is a deer, so the wrong ones are simply named.
WRONG_BY_HAND = {
    ("belie", "past"): "belay",    # belie -> belied; belay is a different verb
    ("sac", "past"): "sacked",     # the pouch, not "to sack"
    ("born", "past"): "bornt",     # not a form of anything
    ("ethos", "plural"): "ethe",   # ethoses or ethea, never "ethe"
    ("doe", "past"): "did",        # a doe is a deer; "did" belongs to "do"
    ("git", "past"): "got",        # an insult; "got" belongs to "get"
    ("uptake", "past"): "uptook",  # a noun only
}


# Verbs that really do have both a regular and an irregular past, because two
# different verbs share the spelling: you ringed a bird but rang a bell, and
# you were winded running but wound a clock. Their "wrong" past is correct for
# the other sense, so they are reported and left alone.
HOMOGRAPH_VERBS = {"ring", "wind", "bust", "relay", "spit", "refit", "bid",
                   "found", "grind", "hang", "lie", "wound"}


def _third_person(word):
    """The -s form of a verb, which is what a scraped "plural" often is."""
    if re.search(r"(s|x|z|ch|sh|o)$", word):
        return word + "es"
    if re.search(r"[^aeiou]y$", word):
        return word[:-1] + "ies"
    return word + "s"


def wordnet_pos():
    """WordNet's parts of speech per lemma, or None when NLTK is missing."""
    try:
        from nltk.corpus import wordnet as wn
    except ImportError:
        return None
    tags = {"noun": wn.NOUN, "verb": wn.VERB, "adj": wn.ADJ, "adv": wn.ADV}

    def look(word):
        # wn.synsets() lemmatises before it looks up, so "doe" finds the verb
        # "do" and "git" finds "get" - which is how "doe" ended up with the
        # past "did". Only count a part of speech when a synset actually
        # carries this exact spelling as a lemma.
        found = set()
        for name, tag in tags.items():
            for syn in wn.synsets(word, pos=tag):
                if any(l.name().lower() == word.lower() for l in syn.lemmas()):
                    found.add(name)
                    break
        return found

    def noun_used(word):
        """How often the NOUN reading is actually attested in a corpus.

        Mere presence in WordNet is not enough: "see" has a noun sense (a
        bishop's see) that no learner will ever meet, and trusting it is what
        let the verb "see" be given the plural "sees".
        """
        return sum(l.count() for syn in wn.synsets(word, pos=wn.NOUN)
                   for l in syn.lemmas()
                   if l.name().lower() == word.lower())

    def proper(word):
        """Is the Capitalised spelling a word in its own right (American)?"""
        cap = word[:1].upper() + word[1:]
        return any(l.name() == cap for s in wn.synsets(word) for l in s.lemmas())
    return look, proper, noun_used


def regular_plural(word):
    if re.search(r"(s|x|z|ch|sh)$", word):
        return word + "es"
    if re.search(r"[^aeiou]y$", word):
        return word[:-1] + "ies"
    return word + "s"


def regular_past(word):
    if word.endswith("e"):
        return word + "d"
    if re.search(r"[^aeiou]y$", word):
        return word[:-1] + "ied"
    return word + "ed"


def variants(cell):
    """"spat / spit" -> {"spat", "spit"}"""
    return {p.strip().lower() for p in cell.split("/") if p.strip()}


def main():
    write = "--write" in sys.argv
    full = json.loads(FULL.read_text())
    words = {e["word"]: set(e.get("pos") or [])
             for e in json.loads(WORDS.read_text())["words"]}
    irregular = json.loads(IRREGULAR.read_text())
    looked = wordnet_pos()
    if looked is None:
        sys.exit("needs NLTK + WordNet: run with vocab_pipeline/.venv/bin/python")
    wn_look, wn_proper, wn_noun_used = looked

    findings = defaultdict(list)

    for word, entry in full.items():
        forms = entry.get("forms") or {}
        if not forms:
            continue
        senses = {s.get("pos") for s in (entry.get("senses") or [])}
        known = senses | words.get(word, set()) | wn_look(word)

        for kind, value in list(forms.items()):
            if not isinstance(value, str) or not value.strip():
                findings["malformed"].append([word, kind, value, None])
                continue
            text = value.strip()

            # an article dragged in from the entry: "the nineties"
            if re.match(r"(?i)^(the|a|an)\s", text):
                findings["malformed"].append([word, kind, text, None])
                continue

            # editorial leftovers: a form is one word (or a "more x" phrase)
            if re.search(r"[,;()\[\]]", text) or text.count(" ") > 1:
                cleaned = text.split()[-1]
                findings["malformed"].append([word, kind, text, cleaned])
                continue

            # a form for a part of speech this word does not have
            if kind in NEEDS and not (known & NEEDS[kind]):
                findings["unattested"].append([word, kind, text, None])
                continue

            # A "plural" on a word the entry teaches only as a verb, whose
            # noun reading is never actually used, is not a plural at all: it
            # is the 3rd-person form. "see" -> "sees" was being shown to
            # learners as a plural noun. The app already has a label for this,
            # so the form is kept and renamed rather than thrown away.
            if kind == "plural" and "verb" in senses \
                    and not (senses & NOUNY) \
                    and text.lower() == _third_person(word) \
                    and wn_noun_used(word) == 0:
                findings["mislabelled"].append([word, kind, text, "present_3s"])
                continue

            # A capital where the headword has none. Two very different
            # cases: "american" -> "Americans" is simply correct, because the
            # word is capitalised in English; "act" -> "ACTs" means the
            # scraper read the entry for the ACT exam. WordNet tells them
            # apart - it knows American as a lemma and Act as nothing.
            if text[:1].isupper() and not word[:1].isupper():
                if wn_proper(word):
                    findings["proper"].append([word, kind, text, None])
                    continue
                lower = text.lower()
                expect = (regular_plural(word) if kind == "plural"
                          else regular_past(word) if kind == "past" else None)
                # Lower-casing is only a fix when the word really inflects
                # that way. "act" does ("acts"), but "much" and "soon" do not
                # own a plural at all, so "Muches" is wrong at any
                # capitalisation and goes. The entry's own senses decide -
                # WordNet is too generous here, listing "much" as a noun.
                own = kind in NEEDS and (senses & NEEDS[kind])
                # a word that is already a plural ("men") owns no plural
                if kind == "plural" and word in set(IRREGULAR_PLURALS.values()) \
                        and word not in IRREGULAR_PLURALS:
                    own = False
                fix = lower if (own and expect and lower == expect) else None
                findings["capitalised"].append([word, kind, text, fix])
                continue

            # the headword is already a plural, so it has none of its own:
            # "men" does not pluralise to "mens"
            if kind == "plural" and word in set(IRREGULAR_PLURALS.values()) \
                    and word not in IRREGULAR_PLURALS:
                findings["already_plural"].append([word, kind, text, None])
                continue

            # taken from the wrong entry, confirmed by hand
            if WRONG_BY_HAND.get((word, kind)) == text.lower():
                findings["wrong_entry"].append([word, kind, text, None])
                continue

            # an irregular plural given the regular ending: "stimuluses"
            if kind == "plural" and word in IRREGULAR_PLURALS:
                right = IRREGULAR_PLURALS[word]
                if text.lower() != right:
                    findings["wrong_value"].append([word, kind, text, right])
                    continue

            # a regular past on an irregular verb
            if kind == "past" and word in irregular:
                right = variants(irregular[word][1])
                if text.lower() not in right:
                    # a verb can be irregular in one sense and regular in
                    # another ("ringed" a bird, "rang" a bell) - only the
                    # naive -ed guess is treated as a mistake
                    known_both = word in HOMOGRAPH_VERBS
                    findings["homograph" if known_both else "irregular"].append(
                        [word, kind, text, irregular[word][1]])

    print(f"entries: {len(full)}  |  entries with forms: "
          f"{sum(1 for e in full.values() if e.get('forms'))}")
    print(f"{'-' * 62}")
    total = 0
    for name in ("unattested", "mislabelled", "capitalised", "already_plural",
                 "irregular", "wrong_value", "wrong_entry", "malformed",
                 "homograph", "proper"):
        rows = findings[name]
        total += len(rows)
        kinds = Counter(r[1] for r in rows)
        print(f"{name:12} {len(rows):5}   {dict(kinds)}")
        for r in rows[:5]:
            arrow = f" -> {r[3]}" if r[3] else " -> drop"
            print(f"     {r[0]:14} {r[1]:12} {r[2]!r}{arrow}")
    print(f"{'-' * 62}")
    print(f"{'total':12} {total:5}   "
          f"words affected: {len({r[0] for v in findings.values() for r in v})}")

    REPORT.write_text(json.dumps(findings, ensure_ascii=False, indent=1))
    print(f"\nfull list written to {REPORT.relative_to(ROOT)}")

    if not write:
        print("report only - pass --write to apply")
        return

    dropped = fixed = 0
    for name in ("unattested", "capitalised", "already_plural", "wrong_value",
                 "wrong_entry", "malformed"):
        for word, kind, _old, fix in findings[name]:
            forms = full[word]["forms"]
            if fix:
                forms[kind] = fix
                fixed += 1
            else:
                forms.pop(kind, None)
                dropped += 1
    for word, kind, text, newkey in findings["mislabelled"]:
        forms = full[word]["forms"]
        forms.pop(kind, None)
        forms[newkey] = text
        fixed += 1
    for word, kind, _old, right in findings["irregular"]:
        full[word]["forms"][kind] = right.split("/")[0].strip()
        fixed += 1
    for word, entry in full.items():
        if entry.get("forms") == {}:
            entry.pop("forms")
    FULL.write_text(json.dumps(full, ensure_ascii=False))
    print(f"applied: {fixed} corrected, {dropped} removed")


if __name__ == "__main__":
    main()
