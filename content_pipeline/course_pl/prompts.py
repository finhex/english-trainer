#!/usr/bin/env python3
"""
Build Polish practice prompts for the drills that are purely formulaic.

Lesson 1 is 2,441 of the course's 10,154 prompts and every one of them is the
same shape: a pronoun, a tense, a polarity, and one verb from a list of 53.
Rather than writing those out by hand, they are generated here from the
English answer - not from the Russian prompt, because the course's Russian is
loose about aspect ("Я начну." is given for "I begin."). Generating from the
answer keeps the Polish true to the English the learner has to produce.

Polish drops the subject pronoun in the first and second person, where the
verb ending already carries it, and keeps it in the third, where it marks
gender. Past tense follows the gender the course chose: masculine for I, you
and he, feminine for she, masculine-personal plural for we and they.

Writes prompts.json, which build.py copies into app/assets/pl/.
"""
import json, re
from pathlib import Path

HERE = Path(__file__).parent
CONTENT = HERE.parent.parent / "app" / "assets" / "content.json"

PRON = {"i": "1sg", "you": "2sg", "we": "1pl", "they": "3pl",
        "he": "3sgm", "she": "3sgf", "it": "3sgn"}
SUBJECT = {"1sg": "", "2sg": "", "1pl": "", "3pl": "Oni ",
           "3sgm": "On ", "3sgf": "Ona ", "3sgn": "To "}
PRESENT = {"1sg": "p1", "2sg": "p2", "1pl": "p1pl", "3pl": "p3pl",
           "3sgm": "p3", "3sgf": "p3", "3sgn": "p3"}
FUTURE = {"1sg": "będę", "2sg": "będziesz", "1pl": "będziemy",
          "3pl": "będą", "3sgm": "będzie", "3sgf": "będzie",
          "3sgn": "będzie"}

# The objects lesson 1 attaches to its verbs, in the case Polish needs.
OBJECT = {
    "": "",
    "the door": " drzwi",
    "the window": " okno",
    "in london": " w Londynie",
    "in moscow": " w Moskwie",
    "in new york": " w Nowym Jorku",
    "in havana": " w Hawanie",
}

AUX = {"will", "won't", "do", "does", "did", "don't", "doesn't", "didn't"}

# Aspect is not the same in the past as in the future, and the course's Russian
# says which it means: "Я увижу" (perfective) but "Я видел" (imperfective) for
# the same verb. These are the verbs whose Russian past is perfective; every
# other verb keeps the imperfective there, so "I saw" is "Widziałem" rather
# than "Zobaczyłem".
PAST_PERFECTIVE = {
    "answer", "ask", "begin", "bring", "buy", "close", "finish", "forget",
    "give", "help", "leave", "lose", "meet", "open", "pay", "say", "show",
    "start", "tell", "turn", "understand",
}


def _ending(form, suffix):
    """Adds a personal ending to a past form, keeping a reflexive last:
    "uczył się" + "em" is "uczyłem się", not "uczył sięem"."""
    if form.endswith(" się"):
        return form[:-4] + suffix + " się"
    return form + suffix


def past(v, person):
    """The Polish past tense form for this person, in the course's gender."""
    if person == "3sgf":
        return v["pastF"]
    if person in ("1pl", "3pl"):
        stem = v["pastPl"]
        return _ending(stem, "śmy") if person == "1pl" else stem
    if person == "1sg":
        return v.get("past1") or _ending(v["pastM"], "em")
    if person == "2sg":
        return v.get("past2") or _ending(v["pastM"], "eś")
    return v["pastM"]


def parse(answer):
    """(person, tense, negated, question, verb, object) or None."""
    a = answer.strip()
    question = a.endswith("?")
    toks = re.findall(r"[a-z']+", a.lower())
    if not toks:
        return None
    negated = False
    tense = "present"
    person = None
    rest = []
    for w in toks:
        if w in PRON and person is None:
            person = PRON[w]
        elif w in AUX:
            if w == "will":
                tense = "future"
            elif w == "won't":
                tense, negated = "future", True
            elif w in ("did", "didn't"):
                tense = "past"
                negated = w == "didn't"
            elif w in ("don't", "doesn't"):
                negated = True
        else:
            rest.append(w)
    if person is None or not rest:
        return None
    verb, obj = rest[0], " ".join(rest[1:])
    # a bare past form with no auxiliary ("I called.")
    if tense == "present" and verb.endswith("ed") and len(verb) > 4:
        tense = "past"
    return person, tense, negated, question, verb, obj


# English inflections back to the dictionary form
def base(verb, table):
    if verb in table:
        return verb
    for stem in (verb[:-1], verb[:-2], verb[:-3],
                 verb[:-2] + "e", verb[:-3] + "e", verb[:-3] + "y"):
        if stem in table:
            return stem
    return None


IRREGULAR = {
    "ate": "eat", "began": "begin", "bought": "buy", "brought": "bring",
    "came": "come", "drank": "drink", "felt": "feel", "flew": "fly",
    "flies": "fly", "forgot": "forget", "found": "find", "gave": "give",
    "goes": "go", "got": "get", "grew": "grow", "heard": "hear",
    "knew": "know", "left": "leave", "lost": "lose", "made": "make",
    "met": "meet", "paid": "pay", "ran": "run", "said": "say",
    "sat": "sit", "saw": "see", "slept": "sleep", "spoke": "speak",
    "studies": "study", "studied": "study", "told": "tell",
    "took": "take", "thought": "think", "understood": "understand",
    "went": "go", "wrote": "write", "read": "read", "put": "put",
    "set": "set", "cut": "cut",
}


def polish(answer, verbs, perfective):
    """Polish for one drill answer.

    Aspect follows the course's own choice, which its Russian records: a verb
    whose Russian future is "буду + infinitive" is imperfective, one that is a
    single word is perfective. Present tense is always imperfective; past and
    future use the perfective where the course does, so "I understood" comes
    out as "Zrozumiałem" rather than "Rozumiałem" ("I used to understand").
    """
    p = parse(answer)
    if not p:
        return None
    person, tense, negated, question, verb, obj = p
    if obj not in OBJECT:
        return None
    key = IRREGULAR.get(verb) or base(verb, verbs)
    if key not in verbs:
        return None
    v = verbs[key]
    # a past-looking irregular with no auxiliary is past tense
    if tense == "present" and verb in IRREGULAR and verb not in (
            "goes", "flies", "studies", "read", "put", "set", "cut"):
        tense = "past"
    pf = perfective.get(key)
    if tense == "future":
        # Polish makes the perfective future with the plain present endings
        core = (pf[PRESENT[person]] if pf
                else f"{FUTURE[person]} {v['inf']}")
    elif tense == "past":
        core = past(pf if (pf and key in PAST_PERFECTIVE) else v, person)
    else:
        core = v[PRESENT[person]]
    text = SUBJECT[person] + core + OBJECT[obj]
    if negated:
        text = ("Nie " + text[0].lower() + text[1:] if not SUBJECT[person]
                else SUBJECT[person] + "nie " + core + OBJECT[obj])
    if question:
        text = "Czy " + text[0].lower() + text[1:] + "?"
    else:
        text = text[0].upper() + text[1:] + "."
    return text


def main():
    verbs = json.loads((HERE / "verbs.json").read_text())
    perfective = json.loads((HERE / "verbs_pf.json").read_text())
    data = json.loads(CONTENT.read_text())
    course = [l for l in data["lessons"] if l.get("section") == "course"]
    out, done, skipped = {}, 0, 0
    existing = HERE / "prompts.json"
    if existing.exists():
        out = json.loads(existing.read_text())
    for l in course:
        for it in l.get("practices", {}).get("sentence", {}).get("items", []):
            ru, en = it["prompt"], it["answer"]
            if ru in out and out[ru]:
                continue
            pl = polish(en, verbs, perfective)
            if pl:
                out[ru] = pl
                done += 1
            else:
                skipped += 1
    (HERE / "prompts.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=1, sort_keys=True))
    print(f"generated now: {done} | not formulaic (left for hand): {skipped}")
    print(f"prompts.json total: {len(out)}")


if __name__ == "__main__":
    main()
