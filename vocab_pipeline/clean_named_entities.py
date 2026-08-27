#!/usr/bin/env python3
"""Remove WordNet named-entity senses (instance_hypernyms) from words.json.

WordNet mixes proper-noun *instances* into common words: `nut` carries "Egyptian
goddess of the sky" (the deity Nut), `world` carries "the 3rd planet from the
sun" (Earth). These are named entities — useless and confusing for a learner.
A synset that is an *instance* (ss.instance_hypernyms() non-empty) is a named
entity; a class adjective like `american` = "relating to the USA" is NOT an
instance, so it stays. Never drop a word to zero senses.
"""
import json,sys
from pathlib import Path
from nltk.corpus import wordnet as wn
A=Path("../app/assets")
data=json.load(open(A/"words.json"))
write="--write" in sys.argv

def is_named(word, definition):
    for ss in wn.synsets(word.replace(" ","_")):
        if ss.definition()!=definition: continue
        if not any(l.name().lower()==word.lower() for l in ss.lemmas()): return False
        return bool(ss.instance_hypernyms())
    return False

removed=0; samples=[]; POS={"n":"noun","v":"verb","a":"adjective","s":"adjective","r":"adverb"}
for x in data["words"]:
    keep=[]
    for s in x.get("senses",[]):
        if is_named(x["word"], s["definition"]):
            removed+=1
            if len(samples)<15: samples.append((x["word"],s["definition"]))
        else:
            keep.append(s)
    if keep and len(keep)<len(x["senses"]):
        x["senses"]=keep
        x["pos"]=[]  # rebuild pos order from surviving senses
        for s in keep:
            if s["pos"] not in x["pos"]: x["pos"].append(s["pos"])
print(f"named-entity senses removed: {removed}")
for w,d in samples: print(f"  {w:14} {d[:55]}")
if write:
    json.dump(data,open(A/"words.json","w"),ensure_ascii=False,separators=(",",":"))
    print("wrote words.json")
else:
    print("(report only; pass --write)")
