#!/usr/bin/env python3
"""
Content extraction pipeline for the English-learning app.

Reads the grammar reference markdown, splits it into chapters (= lessons),
mines the *example sentences* that already demonstrate each grammar point,
and emits a bundled SQLite `content.db` of PRE-BUILT practice items.

Design rules:
  * No runtime generation. Everything is baked here, at build time.
  * Every practice item is TIED to the grammar point it demonstrates
    (lesson + the bold "target" word the book highlighted).
  * We NEVER use the book's ✗ (wrong) examples as answers.
"""

import argparse
import json
import random
import re
import sqlite3
from pathlib import Path

# Optional in-context POS tagging (accurate word types). Requires nltk —
# run this script with vocab_pipeline/.venv/bin/python to enable it; without
# nltk it falls back to the static POS dictionary.
_PENN_TO_SIMPLE = {
    "NN": "noun", "NNS": "noun", "NNP": "noun", "NNPS": "noun",
    "VB": "verb", "VBD": "verb", "VBG": "verb", "VBN": "verb",
    "VBP": "verb", "VBZ": "verb",
    "JJ": "adjective", "JJR": "adjective", "JJS": "adjective",
    "RB": "adverb", "RBR": "adverb", "RBS": "adverb",
}
try:
    import nltk
    nltk.download("averaged_perceptron_tagger_eng", quiet=True)
    nltk.download("averaged_perceptron_tagger", quiet=True)
    from nltk import pos_tag as _nltk_pos_tag
    _nltk_pos_tag(["test"])
    _NLTK_OK = True
except Exception:
    _NLTK_OK = False


def sentence_pos(sentence):
    """Return (simple-POS-by-word, proper-noun-set) for a sentence, using the
    in-context POS tagger when available."""
    if not _NLTK_OK:
        return {}, set()
    words = re.findall(r"[A-Za-z']+", sentence)
    simple, proper = {}, set()
    for w, tag in _nltk_pos_tag(words):
        lw = w.lower()
        if tag in ("NNP", "NNPS"):
            proper.add(lw)
        sp = _PENN_TO_SIMPLE.get(tag)
        if sp and lw not in simple:
            simple[lw] = sp
    return simple, proper

# --- lexicons: closed sets used to build safe, related distractor tiles ---
LEXICON_SETS = [
    ["I", "you", "he", "she", "it", "we", "they"],                 # subject
    ["me", "you", "him", "her", "it", "us", "them"],               # object
    ["my", "your", "his", "her", "its", "our", "their"],           # poss. determiner
    ["mine", "yours", "his", "hers", "ours", "theirs"],            # poss. pronoun
    ["myself", "yourself", "himself", "herself", "itself",
     "ourselves", "yourselves", "themselves"],                    # reflexive
]

ITEMS_PER_LESSON = 70          # net-correct goal per practice (enforced in-app)
MAX_GAP_VARIANTS = 15          # up to this many blanked words per sentence
WT_VARIANTS_PER_BLANK = 4      # different option-sets per word (for variety)
WORD_ORDER_VARIANTS = 4        # tile-set variants per sentence
GAP_FILL_VARIANTS = 6          # option-set variants per closed-set gap

SUBJ, OBJ, POSS_DET, POSS_PRON, REFL = LEXICON_SETS

# grammar jargon → the line is talking ABOUT grammar, not a usable example
JARGON = {
    "subject", "object", "pronoun", "pronouns", "determiner", "determiners",
    "adjective", "adverb", "noun", "nouns", "verb", "verbs", "clause",
    "singular", "plural", "formal", "informal", "antecedent", "possessive",
    "reflexive", "agrees", "genitive", "auxiliary", "modifier",
}


# extra closed sets → grammatically-valid gap-fill distractors across many
# more grammar points (articles, prepositions, modals, quantifiers, ...).
ARTICLES = ["a", "an", "the"]
DEMONSTRATIVES = ["this", "that", "these", "those"]
QUANTIFIERS = ["some", "any", "much", "many", "little", "few", "enough", "several"]
PREPOSITIONS = ["in", "on", "at", "to", "for", "with", "by", "from", "of",
                "about", "into", "over", "under", "between", "through", "during"]
MODALS = ["can", "could", "may", "might", "will", "would", "shall", "should",
          "must", "ought"]
BE_FORMS = ["am", "is", "are", "was", "were", "be", "been", "being"]
AUX = ["do", "does", "did", "have", "has", "had"]
CONJUNCTIONS = ["and", "but", "or", "so", "because", "although", "though",
                "while", "since", "unless", "when", "before", "after"]
FLAT_SETS = [ARTICLES, DEMONSTRATIVES, QUANTIFIERS, PREPOSITIONS, MODALS,
             BE_FORMS, AUX, CONJUNCTIONS]

LEVEL_NAMES = {
    1: "A1 · Beginner",
    2: "A2 · Elementary",
    3: "B1 · Intermediate",
    4: "B2 · Upper-Intermediate",
    5: "C1 · Advanced",
    6: "C2 · Proficiency / Advanced+",
}

# App configuration shipped inside content.json — edit here (or in the JSON)
# to change practice labels, order, icons, and the target number per practice.
PRACTICE_CONFIG = {
    "word_order": {"label": "Build the sentence", "order": 1,
                   "icon": "reorder",
                   "subtitle": "Arrange the word tiles into the correct sentence"},
    "gap_fill": {"label": "Fill the gap", "order": 2,
                 "icon": "space_bar",
                 "subtitle": "Choose the correct grammar word for the gap"},
    "word_type": {"label": "Word types", "order": 3,
                  "icon": "category",
                  "subtitle": "Pick the word of the right type (noun, verb, …)"},
}

# default target per practice — written into EACH lesson's own "goals" so you
# can edit any single lesson's goal in the JSON.
DEFAULT_GOAL = 70

# keyword (lowercase substring of the markdown-stripped chapter title) -> level.
# Matched longest-keyword-first so specific topics beat generic ones
# (e.g. "present perfect continuous" wins over "present").
LEVEL_KEYWORDS = {
    # ---- A1 ----
    "what a noun": 1, "types of noun": 1, "gender": 1, "what a pronoun": 1,
    "personal pronoun": 1, "possessive forms": 1, "demonstrative": 1,
    "articles": 1, "what an adjective": 1, "what an adverb": 1,
    "types of verb": 1, "verb to be": 1, "present simple": 1,
    "present continuous": 1, "imperative": 1, "have vs have got": 1,
    "have got": 1,
    # ---- A2 ----
    "past simple": 2, "past continuous": 2, "degrees of comparison": 2,
    "common adjective mistakes": 2, "types of adverb": 2,
    "position of adverbs": 2, "adverb vs adjective": 2,
    "future with will": 2, "be going to": 2, "other future forms": 2,
    "present perfect simple": 2, "quantifiers": 2,
    "reflexive and intensive": 2, "reciprocal pronoun": 2,
    "modal verbs — overview": 2, "modal verbs - overview": 2,
    "no / none": 2, "all / every": 2, "so / such": 2, "still / yet": 2,
    "my own": 2, "interrogative pronoun": 2,
    # ---- B1 ----
    "present perfect continuous": 3, "past perfect simple": 3,
    "the conditional structure": 3, "zero conditional": 3,
    "first conditional": 3, "second conditional": 3,
    "direct vs indirect speech": 3, "tense backshift": 3,
    "reporting questions": 3, "reporting commands": 3,
    "relative pronoun": 3, "relative clauses": 3, "noun clauses": 3,
    "gerunds": 3, "infinitives": 3, "infinitive vs gerund": 3,
    "question types": 3, "short answers": 3, "forming negatives": 3,
    "tag questions": 3, "conversion — active to passive": 3,
    "conversion - active to passive": 3, "why use the passive": 3,
    "common passive errors": 3, "passive in connected": 3,
    "there is vs it is": 3, "adverbs that change": 3,
    "coordinating conjunction": 3, "subordinating conjunction": 3,
    "fanboys": 3,
    # ---- B2 ----
    "third conditional": 4, "past perfect continuous": 4,
    "other conditional": 4, "wish": 4, "if only": 4,
    "reporting verbs": 4, "participle clauses": 4, "present participle": 4,
    "past participle": 4, "dangling participle": 4,
    "other uses of participles": 4, "common participle errors": 4,
    "finite vs non-finite": 4, "subjunctive": 4, "get-passive": 4,
    "get -passive": 4, "causative": 4, "reporting passive": 4,
    "subject-verb agreement": 4, "parallel structure": 4,
    "sentence types by": 4, "basic sentence patterns": 4,
    "used to / be used to": 4, "had better": 4, "would rather": 4,
    "it's time": 4, "correlative conjunction": 4, "narrative": 4,
    # ---- C1 ----
    "inversion": 5, "cleft": 5, "fronting": 5, "topicalis": 5,
    "dislocation": 5, "heavy np": 5, "end weight": 5,
    "emphasis with do": 5, "emphatic": 5, "ellipsis": 5,
    "substitution": 5, "extraposition": 5, "nominalization": 5,
    "appositive": 5, "absolute phrase": 5, "absolute construction": 5,
    "flat adverbs": 5, "be + to": 5, "pseudo-modal": 5, "semi-modal": 5,
    "modal idioms": 5, "perfect continuous modals": 5,
    "negative questions": 5, "middle voice": 5, "adverb even": 5,
    "exclamative": 5,
}


def assign_level(title):
    """Map a chapter title to a CEFR level (defaults to 6 = Advanced+)."""
    t = re.sub(r"[*_`]", "", title).lower()
    best_level, best_len = 6, -1
    for kw, lvl in LEVEL_KEYWORDS.items():
        if kw in t and len(kw) > best_len:
            best_level, best_len = lvl, len(kw)
    return best_level


# non-grammar / study-skill chapters that belong in the read-only Guides
# section rather than the practice lessons.
META_KEYWORDS = (
    "listening", "shadowing", "comprehension", "prosody", "diagramming",
    "confusable words", "final notes", "grammar mistakes",
    "sentence-level errors", "sentence rhythm", "anatomy of an english sentence",
)


def is_meta(title):
    t = title.lower()
    return any(k in t for k in META_KEYWORDS)


def lesson_pos(title):
    """The part of speech a lesson is about → the Word-types practice asks for
    THAT type (noun lessons ask for nouns, etc.). Defaults to noun."""
    t = title.lower()
    if "adverb" in t:
        return "adverb"
    if "adjective" in t:
        return "adjective"
    if "verb" in t:
        return "verb"
    if "noun" in t or "pronoun" in t:
        return "noun"
    return "noun"


def _low(s):
    return [w.lower() for w in s]


def related_distractors(target, sentence, k=3):
    """
    Up to k closed-set siblings of `target`, choosing the set from CONTEXT so
    ambiguous words (her/his/its) get grammatically valid distractors.
    """
    lw = target.lower()
    toks = sentence.rstrip(".?!").split()
    idx = next((i for i, t in enumerate(toks)
                if t.strip(",.;:").lower() == lw), None)
    followed_by_word = idx is not None and idx < len(toks) - 1
    is_first = idx == 0

    def sibs(s):
        return [w for w in s if w.lower() != lw][:k]

    if lw in _low(POSS_DET) and followed_by_word:      # "my book", "her dog"
        return sibs(POSS_DET)
    if lw in _low(POSS_PRON) and not followed_by_word:  # "is mine", "is his"
        return sibs(POSS_PRON)
    if lw in _low(SUBJ) and is_first:                   # sentence-initial subject
        return sibs(SUBJ)
    if lw in _low(OBJ):
        return sibs(OBJ)
    for s in LEXICON_SETS + FLAT_SETS:                 # fallback: first match
        if lw in _low(s):
            return sibs(s)
    return []


def split_chapters(text):
    """Yield (part_title, chapter_title, body_markdown) for each `## Chapter`."""
    lines = text.splitlines()
    current_part = ""
    chapters = []
    buf_title = None
    buf = []
    for ln in lines:
        pm = re.match(r"^#{1,2}\s+PART\b(.*)$", ln)   # v5 uses '#', v6 uses '##'
        cm = re.match(r"^##\s+((?:Chapter\s+\d+|Appendix\s+[A-Z])\..*)$", ln)
        if pm:
            current_part = ("PART" + pm.group(1)).strip()
            continue
        if cm:
            if buf_title is not None:
                chapters.append((buf_part, buf_title, "\n".join(buf).strip()))
            buf_title = cm.group(1).strip()
            buf_part = current_part
            buf = []
            continue
        if buf_title is not None:
            buf.append(ln)
    if buf_title is not None:
        chapters.append((buf_part, buf_title, "\n".join(buf).strip()))
    return chapters


def chapter_num(title):
    """Numeric id for a heading: 'Chapter 7' -> 7, 'Appendix C' -> 903."""
    m = re.search(r"Chapter\s+(\d+)", title)
    if m:
        return int(m.group(1))
    m = re.search(r"Appendix\s+([A-Z])", title)
    if m:
        return 900 + (ord(m.group(1)) - 64)  # A->901 … J->910
    return None


def parse_ru(path):
    """Parse the Russian edition into {chapter_number: (ru_title, ru_body)}."""
    out = {}
    if not path:
        return out
    text = Path(path).read_text(encoding="utf-8")
    for _part, title, body in split_chapters(text):
        cn = chapter_num(title)
        if cn is not None:
            out[cn] = (title, body)
    return out


BOLD_RE = re.compile(r"\*\*\*?([^*]+?)\*\*")   # **x** or ***x** (bold / bold-italic)


def clean_example_line(raw):
    """
    Turn one markdown bullet into (sentence, target) or None.
    Rejects ✗ wrong examples and non-sentence fragments.
    """
    line = raw.strip()
    if not line.startswith("-"):
        return None
    line = line[1:].strip()

    # Correction lines "✗ ... → ✓ ...": keep only the corrected (✓) side.
    if "→" in line:
        line = line.split("→")[-1].strip()
    if "✗" in line:            # still a wrong example → drop
        return None
    line = line.replace("✓", "").strip()

    # capture the highlighted grammar word BEFORE stripping emphasis
    bolds = BOLD_RE.findall(line)
    target = bolds[0].strip() if bolds else None

    # drop parentheticals and a leading "Label: " cue
    line = re.sub(r"\([^)]*\)", "", line)
    if re.search(r":\s*\*", raw):
        line = line.split(":", 1)[-1]

    # strip all emphasis / stray markup
    plain = re.sub(r"[*_`]+", "", line).strip()
    return _validate_sentence(plain, target)


def _validate_sentence(plain, target):
    """Shared gate: accept `plain` only if it reads as one clean example
    sentence, returning (sentence, target) or None. Used by both the bullet
    parser and the inline-italic scanner."""
    plain = re.sub(r"\s+", " ", plain).strip()

    # validate: looks like a single clean sentence
    if "/" in plain or "✗" in plain:
        return None
    # reject merged-span / awkward artifacts and rule statements
    if " ." in plain or " ," in plain or "  " in plain or " — " in plain or ";" in plain:
        return None
    low_words = set(re.findall(r"[a-z']+", plain.lower()))
    if low_words & JARGON:
        return None
    # reject enumerations / word lists ("London, room, garden, country.")
    segs = [s.strip() for s in plain.rstrip(".?!").split(",")]
    if len(segs) >= 3 and \
            sum(1 for s in segs if 0 < len(s.split()) <= 1) >= len(segs) * 0.6:
        return None
    m = re.match(r"^[\"']?[A-Z].*[.?!]$", plain)
    if not m:
        return None
    words = plain.rstrip(".?!").split()
    if not (3 <= len(words) <= 14):
        return None
    # target must actually appear as a whole word to be tie-able
    if target and not re.search(rf"\b{re.escape(target)}\b", plain):
        target = None
    return plain, target


# single-asterisk italic span (not the ** of bold), used to mine example
# sentences that live INSIDE prose paragraphs and table cells.
ITALIC_RE = re.compile(r"(?<!\*)\*(?!\*)([^*\n]+?)\*(?!\*)")


def inline_examples(raw):
    """Yield (sentence, target) for italic *…* example sentences embedded in a
    prose or table line — the way chapters like Articles/Determiners present
    their examples instead of as `-` bullets. Bullets, headings and blockquotes
    are handled elsewhere / skipped."""
    s = raw.lstrip()
    if s[:1] in ("-", "#", ">"):
        return []
    out = []
    for span in ITALIC_RE.findall(raw):
        if any(x in span for x in ("→", "✗", "/", "✓")):
            continue
        bolds = BOLD_RE.findall(span)
        target = bolds[0].strip() if bolds else None
        plain = re.sub(r"\([^)]*\)", "", span)
        plain = re.sub(r"[*_`]+", "", plain).strip()
        # keep only an author-marked (bold) target — no auto-guessing, so a
        # chapter never gets an off-topic gap-fill (e.g. is/are in "Articles")
        res = _validate_sentence(plain, target)
        if res:
            out.append(res)
    return out


def tokenize(sentence):
    """Split a sentence into tap-tiles, keeping trailing punctuation attached."""
    return sentence.split()


STOPWORDS = set(
    "a an the of to in on at for with by from and or but so is are was were be "
    "been being am do does did have has had not no it its this that these those "
    "i you he she we they me him her us them my your his our their as if then "
    "than very more most can could will would should may might must one".split()
)


# word -> primary part of speech (built from WordNet by the vocab pipeline).
# Used to keep fallback gap-fill distractors the same POS as the answer.
try:
    POS_DICT = json.loads((Path(__file__).parent / "pos_dict.json").read_text())
except Exception:
    POS_DICT = {}


def content_words(sentence):
    """Meaningful (non-stopword) words of a sentence, punctuation stripped."""
    out = []
    for w in sentence.split():
        w = re.sub(r"[^A-Za-z']", "", w)
        if len(w) >= 3 and w.lower() not in STOPWORDS:
            out.append(w)
    return out


def _match_case(word, like):
    """Return `word` capitalised to match the pattern of `like`."""
    if like[:1].isupper():
        return word[:1].upper() + word[1:]
    return word[:1].lower() + word[1:]


# small generic pool to top up distractors when a lesson is too short/stopwordy
GLOBAL_FILLER = ["time", "people", "water", "house", "world", "school",
                 "family", "money", "story", "music", "book", "friend",
                 "work", "place", "word", "night", "name", "reason"]

# Unambiguous words per part of speech. A content-word gap-fill offers the
# answer plus distractors of DIFFERENT parts of speech, so only one option
# fits the grammatical slot (a real grammar exercise, not a vocab guess).
POS_FILLER = {
    "noun": ["house", "table", "friend", "city", "money", "school", "garden",
             "market", "sister", "brother", "doctor", "window", "mountain",
             "language", "morning", "student", "river", "village"],
    "verb": ["become", "remember", "understand", "believe", "decide",
             "explain", "arrive", "happen", "prefer", "belong", "discover",
             "improve", "consider", "describe", "introduce", "achieve"],
    "adjective": ["happy", "small", "cold", "strong", "heavy", "clean",
                  "empty", "loud", "soft", "warm", "angry", "tired", "hungry",
                  "careful", "famous", "modern", "narrow", "gentle"],
    "adverb": ["quickly", "slowly", "often", "never", "always", "quietly",
               "loudly", "early", "carefully", "suddenly", "usually",
               "probably", "rarely", "nearly", "gently", "safely"],
}


# Fill-the-gap is limited to sets where the answer is grammatically DETERMINED
# (one correct option), avoiding ambiguous choices like possessives/articles
# where several words would fit equally well.
DETERMINED_GAP_SETS = [
    ["am", "is", "are"],          # present be — subject agreement
    ["was", "were"],              # past be — number agreement
    ["have", "has"],              # present perfect aux — agreement
    ["do", "does"],               # present aux — agreement
    ["a", "an"],                  # article — determined by following sound
    ["myself", "yourself", "himself", "herself", "itself",
     "ourselves", "yourselves", "themselves"],  # reflexive — subject match
]


def grammar_gap_options(target):
    """Siblings of `target` only if it's in a determined set (else [] → no gap)."""
    lw = target.lower()
    for s in DETERMINED_GAP_SETS:
        if lw in s:
            return [w for w in s if w != lw]
    return []


def _pick_blank(sentence, target):
    """Choose which word to blank: the tied target if usable, else the most
    salient content word, else the longest word of any kind."""
    if target:
        tw = re.sub(r"[^A-Za-z']", "", target)
        if len(tw) >= 3 and tw.lower() not in STOPWORDS and \
                re.search(rf"\b{re.escape(target)}\b", sentence):
            return target
    cws = content_words(sentence)
    if cws:
        return max(cws, key=len)
    # last resort: longest alphabetic token (keeps very short lessons covered)
    toks = [re.sub(r"[^A-Za-z']", "", w) for w in sentence.split()]
    toks = [t for t in toks if len(t) >= 2]
    return max(toks, key=len) if toks else None


def _gap(sentence, answer, distractors, grammar_ref, gtype="gap_fill", pos=""):
    gapped = re.sub(rf"\b{re.escape(answer)}\b", "____", sentence, count=1)
    return {
        "type": gtype, "prompt": gapped, "answer": answer,
        "tokens": [], "distractors": distractors,
        "target": answer, "grammar_ref": grammar_ref, "pos": pos,
    }


def build_items(sentence, target, grammar_ref, word_pool):
    """Build the pre-tied practice items. Every sentence yields a word-order
    tile exercise AND a gap-fill, so every lesson has both practices."""
    items = []
    tokens = tokenize(sentence)

    # 1) word-order tile exercise (matches the screenshots). Several variants
    #    with DIFFERENT extra (distractor) tiles so it isn't the same each time.
    sent_low = {re.sub(r"[^A-Za-z']", "", t).lower() for t in tokens}
    _allfill = [w for lst in POS_FILLER.values() for w in lst]
    wo_sets, wo_seen = [], set()
    base = related_distractors(target, sentence, k=2) if target else []
    base = [w for w in base if w.lower() not in sent_low]
    for cand in [base] + [None] * WORD_ORDER_VARIANTS:
        if cand is None:
            rng = random.Random(hash(f"wo|{sentence}|{len(wo_sets)}") & 0xFFFFFFFF)
            pool = [w for w in _allfill if w.lower() not in sent_low]
            rng.shuffle(pool)
            cand = pool[:2]
        key = tuple(sorted(x.lower() for x in cand))
        if key in wo_seen:
            continue
        wo_seen.add(key)
        items.append({
            "type": "word_order",
            "prompt": "Put the words in the correct order.",
            "answer": sentence,
            "tokens": tokens,
            "distractors": cand,
            "target": target,
            "grammar_ref": grammar_ref,
            "pos": "",
        })

    # 2) gap-fill variants — "pick the word that fits the slot". Distractors are
    #    a DIFFERENT part of speech than the answer, so exactly one option fits
    #    the sentence grammatically (not an arbitrary same-POS guess).
    here = {w.lower() for w in content_words(sentence)}
    toks = sentence.split()
    first_tok = re.sub(r"[^A-Za-z']", "", toks[0]) if toks else ""
    ctx_pos, proper_set = sentence_pos(sentence)

    def _proper(w):
        # a tagged proper noun, or capitalised but not sentence-initial
        if w.lower() in proper_set:
            return True
        return w[:1].isupper() and w != first_tok

    blanks = []          # ordered list of (answer, distractors)
    used = set()

    # 2a) FILL THE GAP — closed-set grammar target → same-set options
    #     (their/my/your; a/an/the; in/on/at; can/must; ...). True grammar.
    #     Several variants using different option subsets from the set.
    if target and not _proper(target):
        siblings = grammar_gap_options(target)  # determined answers only
        if siblings:
            gf_seen = set()
            for v in range(GAP_FILL_VARIANTS):
                rng = random.Random(hash(f"gf|{sentence}|{target}|{v}") & 0xFFFFFFFF)
                pool = siblings[:]
                rng.shuffle(pool)
                opts = pool[:3]
                key = tuple(sorted(o.lower() for o in opts))
                if len(opts) >= 2 and key not in gf_seen:
                    gf_seen.add(key)
                    blanks.append((target, opts, "gap_fill", ""))
            used.add(target.lower())

    # 2b) WORD TYPES — "Select the <lesson's part of speech>". The answer is a
    #     word of the LESSON's POS (noun lesson → a noun); distractors are the
    #     other parts of speech. Consistent per lesson — never asks for a verb
    #     in a noun lesson.
    lpos = lesson_pos(grammar_ref)
    others_pos = [p for p in POS_FILLER if p != lpos]
    n_blanks = 0
    for blank in content_words(sentence):
        lw = blank.lower()
        if lw in used or _proper(blank):
            continue
        # answer must be the lesson's POS by the IN-CONTEXT tag AND not be
        # contradicted by the dictionary (guards tagger mistakes like the
        # imperative "come" being mis-tagged as a noun).
        ctxp = ctx_pos.get(lw)
        dictp = POS_DICT.get(lw)
        if ctxp != lpos:
            continue
        if dictp is not None and dictp != lpos:
            continue
        used.add(lw)
        # several option-sets for the same word → more variety in practice
        for v in range(WT_VARIANTS_PER_BLANK):
            rng = random.Random(hash(f"{lw}|{lpos}|{v}") & 0xFFFFFFFF)
            order = others_pos[:]
            rng.shuffle(order)
            distractors = []
            for p in order:                # one distractor per other POS
                choices = [w for w in POS_FILLER[p]
                           if w.lower() not in here and w.lower() != lw]
                if choices:
                    distractors.append(_match_case(rng.choice(choices), blank))
            if len(distractors) >= 2:
                blanks.append((blank, distractors[:3], "word_type", lpos))
        n_blanks += 1
        if n_blanks >= MAX_GAP_VARIANTS:
            break

    for answer, distractors, gtype, pos in blanks:
        items.append(_gap(sentence, answer, distractors, grammar_ref, gtype, pos))
    return items


def fill_to_quota(pool, n=ITEMS_PER_LESSON):
    """Repeat the unique pool (as allowed) to reach exactly n items per lesson."""
    if not pool:
        return []
    out = []
    i = 0
    while len(out) < n:
        out.append(pool[i % len(pool)])
        i += 1
    return out[:n]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="English grammar markdown file")
    ap.add_argument("--src-ru", dest="src_ru", default="",
                    help="Russian edition markdown (adds grammarMdRu per chapter)")
    ap.add_argument("--out", required=True, help="output content.db")
    ap.add_argument("--chapters", default="", help="comma-sep chapter numbers, e.g. 24,25 (default: all with enough examples)")
    args = ap.parse_args()

    text = Path(args.src).read_text(encoding="utf-8")
    chapters = split_chapters(text)
    ru_map = parse_ru(args.src_ru)   # {chapter_number: (ru_title, ru_body)}

    wanted = set()
    if args.chapters:
        wanted = {int(x) for x in args.chapters.split(",") if x.strip()}

    # 1) mine every qualifying chapter into an in-memory lesson
    collected = []
    for part, title, body in chapters:
        cn = chapter_num(title)
        if cn is None:
            continue
        if cn >= 900:                       # appendices → their own Guides group
            part = "APPENDICES"
        if wanted and cn not in wanted:
            continue

        seen = set()
        pairs = []
        for raw in body.splitlines():
            cands = []
            res = clean_example_line(raw)   # `-` bullet examples
            if res:
                cands.append(res)
            cands.extend(inline_examples(raw))  # italic examples in prose/tables
            for sent, target in cands:
                if sent in seen:
                    continue
                seen.add(sent)
                pairs.append((sent, target))

        # A chapter becomes a practice LESSON when it has enough grammar
        # examples and isn't a study-skill chapter; everything else (phonetics,
        # morphology, skills, meta) is kept as a read-only GUIDE so no book
        # chapter is lost.
        if not is_meta(title) and cn < 900 and len(seen) >= 3:
            pool, pool_seen = [], set()
            for sent, _ in pairs:
                for w in content_words(sent):
                    if w.lower() not in pool_seen:
                        pool_seen.add(w.lower())
                        pool.append(w)
            base_items = []
            for sent, target in pairs:
                base_items.extend(build_items(sent, target, title, pool))

            # dedupe identical items across sentences (any type)
            seen_k, deduped = set(), []
            for it in base_items:
                k = (it["type"], it["prompt"], it["answer"].lower(),
                     tuple(sorted(d.lower() for d in it["distractors"])))
                if k in seen_k:
                    continue
                seen_k.add(k)
                deduped.append(it)

            ru_title, ru_body = ru_map.get(cn, ("", ""))
            collected.append({
                "id": cn, "part": part, "title": title, "body": body,
                "title_ru": ru_title, "body_ru": ru_body,
                "uniq": len(seen), "level": assign_level(title),
                "section": "grammar", "items": deduped,
            })
        elif body.strip():
            ru_title, ru_body = ru_map.get(cn, ("", ""))
            collected.append({
                "id": cn, "part": part, "title": title, "body": body,
                "title_ru": ru_title, "body_ru": ru_body,
                "uniq": len(seen), "level": 0,
                "section": "other", "items": [],
            })

    # 2) grammar lessons ordered beginner→advanced; guides in book order.
    grammar = sorted((c for c in collected if c["section"] == "grammar"),
                     key=lambda c: (c["level"], c["id"]))
    other = sorted((c for c in collected if c["section"] == "other"),
                   key=lambda c: c["id"])
    for i, c in enumerate(grammar, 1):
        c["ord"] = i
    for i, c in enumerate(other, 1):
        c["ord"] = i
    collected = grammar + other

    # 3) persist to SQLite + JSON
    db = sqlite3.connect(args.out)
    db.executescript("""
        DROP TABLE IF EXISTS lessons;
        DROP TABLE IF EXISTS items;
        CREATE TABLE lessons(
            id INTEGER PRIMARY KEY, ord INTEGER, part TEXT, title TEXT,
            grammar_md TEXT, unique_sentences INTEGER,
            level INTEGER, level_name TEXT, section TEXT
        );
        CREATE TABLE items(
            id INTEGER PRIMARY KEY, lesson_id INTEGER, seq INTEGER,
            type TEXT, prompt TEXT, answer TEXT,
            tokens_json TEXT, distractors_json TEXT, target TEXT, grammar_ref TEXT
        );
    """)

    bundle = {
        "config": {
            "practices": PRACTICE_CONFIG,
            "levels": {str(k): v for k, v in LEVEL_NAMES.items()},
        },
        "lessons": [],
    }
    total_items = 0
    for c in collected:
        ordv = c["ord"]
        level_name = LEVEL_NAMES.get(c["level"], c["part"])
        db.execute(
            "INSERT INTO lessons(id,ord,part,title,grammar_md,unique_sentences,level,level_name,section)"
            " VALUES(?,?,?,?,?,?,?,?,?)",
            (c["id"], ordv, c["part"], c["title"], c["body"], c["uniq"],
             c["level"], level_name, c["section"]),
        )
        # items grouped by practice type (no global seq)
        by_type = {}
        for seq, it in enumerate(c["items"], start=1):
            db.execute(
                "INSERT INTO items(lesson_id,seq,type,prompt,answer,tokens_json,distractors_json,target,grammar_ref)"
                " VALUES(?,?,?,?,?,?,?,?,?)",
                (c["id"], seq, it["type"], it["prompt"], it["answer"],
                 json.dumps(it["tokens"]), json.dumps(it["distractors"]),
                 it["target"], it["grammar_ref"]),
            )
            entry = {"answer": it["answer"], "distractors": it["distractors"]}
            if it["type"] != "word_type":
                entry["prompt"] = it["prompt"]     # word_type shows no sentence
            if it["tokens"]:
                entry["tokens"] = it["tokens"]     # only word_order
            by_type.setdefault(it["type"], []).append(entry)
            total_items += 1

        # each practice holds its own goal (+ pos for word_type) and its items
        practices = {}
        for t in PRACTICE_CONFIG:
            if t not in by_type:
                continue
            obj = {"goal": DEFAULT_GOAL, "items": by_type[t]}
            if t == "word_type":
                obj["pos"] = lesson_pos(c["title"])
            practices[t] = obj
        bundle["lessons"].append({
            "id": c["id"], "ord": ordv, "part": c["part"], "title": c["title"],
            "titleRu": c.get("title_ru", ""),
            "grammarMd": c["body"], "grammarMdRu": c.get("body_ru", ""),
            "uniqueSentences": c["uniq"],
            "level": c["level"], "levelName": level_name,
            "section": c["section"], "practices": practices,
        })
    db.commit()
    db.close()

    json_path = Path(args.out).with_suffix(".json")
    json_path.write_text(json.dumps(bundle, ensure_ascii=False, indent=1), encoding="utf-8")

    # 4) report
    gcount = sum(1 for l in bundle["lessons"] if l["section"] == "grammar")
    ocount = sum(1 for l in bundle["lessons"] if l["section"] == "other")
    print(f"Grammar lessons : {gcount}")
    print(f"Guide chapters  : {ocount}")
    print(f"Items written   : {total_items}")
    print(f"JSON bundle     : {json_path}")
    print("Level distribution (grammar):")
    for lvl in sorted(LEVEL_NAMES):
        cnt = sum(1 for l in bundle["lessons"] if l["level"] == lvl)
        print(f"  {LEVEL_NAMES[lvl]:<32} {cnt} lessons")


if __name__ == "__main__":
    main()
