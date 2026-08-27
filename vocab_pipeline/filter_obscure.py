#!/usr/bin/env python3
"""Drop obscure/slang/archaic/proper-noun WordNet senses, confirmed by Wiktionary.

A sense is removed only when ALL hold (triple confirmation, conservative):
  1. WordNet-marginal: the headword is a count-0, non-primary lemma of the synset
     (i.e. the word is only a peripheral synonym in that meaning);
  2. no morphological tie: the gloss shares no word with the headword's stem
     (protects `violent`->"violence", `centre`->"central");
  3. Wiktionary positively flags the meaning bad (a sense tagged obsolete/archaic/
     dated/rare/vulgar/slang/offensive/derogatory/slur, or pos=name) AND offers no
     clean sense sharing a content word with the gloss.
Plus an explicit KEEP list for valid senses the token match mislabels, and never
leaves a word with zero senses.
"""
import json,re,sys
from pathlib import Path
from nltk.corpus import wordnet as wn
SCR="/tmp/claude-1000/-home-konako-Documents-Claude--git-backups-apps-words/270f0885-6ca7-4eda-94ea-274592317292/scratchpad"
A=Path("app/assets")
kaikki=json.load(open(SCR+"/kaikki_vocab.json"))
STOP=set("a an the of to in on at for and or is are be as by with from that this which who whom whose it its into out up used especially often usually".split())
BAD={"obsolete","archaic","dated","historical","rare","vulgar","slang","offensive","derogatory","slur"}
KEEP_DEFS={
 "exciting sexual desire",
 "kill in large numbers",
 "forbid the public distribution of ( a movie or a newspaper)",
 "form by stamping, punching, or printing",
 "of good quality and condition; solidly built",
 "(computer science) a sequence of instructions that a computer can interpret and execute",
 "program listings or technical manuals describing the operation and use of programs",
 "increase threefold",
 "come or be in close contact with; stick or hold together and resist separation",
 "include in scope; include as part of something broader; have as one's sphere or territory",
 "narrowly restricted in outlook or scope",
 "having or exerting a malignant influence",
 "having a quality that thrusts itself into attention",
 "of worldwide scope or applicability",
}
def toks(s): return {w for w in re.findall(r"[a-z]+", s.lower()) if w not in STOP and len(w)>2}
def marginal(word, definition):
    w=word.lower()
    for ss in wn.synsets(word.replace(" ","_")):
        if ss.definition()!=definition: continue
        names=[l.name().lower() for l in ss.lemmas()]
        if w not in names: return False
        idx=names.index(w); cnt=sum(l.count() for l in ss.lemmas() if l.name().lower()==w)
        return cnt==0 and idx>=1
    return False
def morpho(word, definition):
    stem=word.lower()[:4]
    return len(stem)>=4 and any(t.startswith(stem) for t in toks(definition))
def bad_confirmed(word, wn_def):
    bg=bb=0; A_=toks(wn_def)
    for s in kaikki.get(word.lower(),[]):
        o=len(A_ & toks(s['gloss']))
        isbad = s['pos']=='name' or bool(set(t.lower() for t in s['tags'])&BAD)
        if isbad: bb=max(bb,o)
        else: bg=max(bg,o)
    return bb>=1 and bg==0
def should_drop(word, definition):
    if definition in KEEP_DEFS: return False
    return marginal(word,definition) and not morpho(word,definition) and bad_confirmed(word,definition)

data=json.load(open(A/"words.json"))
dropped=0; touched=0; rows=[]
for x in data["words"]:
    senses=x.get("senses",[])
    if len(senses)<=1: continue
    keep=[s for s in senses if not should_drop(x["word"], s["definition"])]
    if not keep: keep=senses[:1]           # never empty a word
    if len(keep)<len(senses):
        for s in senses:
            if s not in keep: rows.append((x["word"], s["definition"])); dropped+=1
        x["senses"]=keep; touched+=1
        x["pos"]=[]
        for s in keep:
            if s["pos"] not in x["pos"]: x["pos"].append(s["pos"])
print(f"senses dropped: {dropped} across {touched} words")
if "--write" in sys.argv:
    json.dump(data,open(A/"words.json","w"),ensure_ascii=False,separators=(",",":"))
    print("wrote words.json")
else:
    print("(report only)")
