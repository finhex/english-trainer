#!/usr/bin/env python3
"""
Dedicated English→Russian translation with HuggingFace MT models (Opus-MT and
NLLB-200). These are purpose-built translators — small, fast, and they run on
CPU or the GPU. First run downloads the model from HuggingFace (cached).

Quick quality/speed test on a few sentences:
    .venv/bin/python ru/mt_models.py test            # both
    .venv/bin/python ru/mt_models.py test opus        # just Opus-MT
    .venv/bin/python ru/mt_models.py test nllb        # just NLLB-200

Bulk-translate the vocabulary example sentences into words.json (resumable):
    .venv/bin/python ru/mt_models.py run --engine opus       # fastest
    .venv/bin/python ru/mt_models.py run --engine nllb
"""

import argparse
import json
import time
from pathlib import Path

HERE = Path(__file__).parent
WORDS = HERE.parent.parent / "app" / "assets" / "words.json"
CACHE = HERE / "example_ru_cache.json"
# separate Russian layer bundled with the app (english example -> russian)
OUT_RU = HERE.parent.parent / "app" / "assets" / "examples_ru.json"

OPUS = "Helsinki-NLP/opus-mt-en-ru"
NLLB = "facebook/nllb-200-distilled-600M"

SAMPLES = [
    "The dog barked loudly.",
    "He listened to an address on minor Roman poets.",
    "She bought some fresh bread.",
    "The children played in the garden.",
    "I have lost my keys.",
]


class Opus:
    def __init__(self):
        from transformers import MarianMTModel, MarianTokenizer
        self.tok = MarianTokenizer.from_pretrained(OPUS)
        self.m = MarianMTModel.from_pretrained(OPUS)

    def translate(self, text):
        ids = self.tok([text], return_tensors="pt", padding=True, truncation=True)
        out = self.m.generate(**ids, max_length=80, num_beams=4)
        return self.tok.decode(out[0], skip_special_tokens=True).strip()


class Nllb:
    def __init__(self):
        from transformers import AutoTokenizer, AutoModelForSeq2SeqLM
        self.tok = AutoTokenizer.from_pretrained(NLLB, src_lang="eng_Latn")
        self.m = AutoModelForSeq2SeqLM.from_pretrained(NLLB)
        try:
            self.bos = self.tok.convert_tokens_to_ids("rus_Cyrl")
        except Exception:
            self.bos = self.tok.lang_code_to_id["rus_Cyrl"]

    def translate(self, text):
        ids = self.tok(text, return_tensors="pt", truncation=True)
        out = self.m.generate(**ids, forced_bos_token_id=self.bos,
                              max_length=80, num_beams=4)
        return self.tok.decode(out[0], skip_special_tokens=True).strip()


def engine(name):
    return Opus() if name == "opus" else Nllb()


def cmd_test(which):
    for name in (["opus", "nllb"] if which == "both" else [which]):
        print(f"=== {name} ({OPUS if name=='opus' else NLLB}) ===")
        t0 = time.time()
        eng = engine(name)
        print(f"  (loaded in {time.time()-t0:.1f}s)")
        for s in SAMPLES:
            t = time.time()
            r = eng.translate(s)
            print(f"  {time.time()-t:5.2f}s  {s[:38]!r} -> {r!r}", flush=True)


def cmd_run(which, limit):
    data = json.loads(Path(WORDS).read_text(encoding="utf-8"))
    cache = json.loads(CACHE.read_text(encoding="utf-8")) if CACHE.exists() else {}
    texts, seen = [], set()
    for w in data["words"]:
        for s in w["senses"]:
            e = (s.get("example") or "").strip()
            if e and e not in seen:
                seen.add(e)
                texts.append(e)
    todo = [t for t in texts if t not in cache]
    print(f"{len(texts)} unique examples · {len(cache)} cached · {len(todo)} to do "
          f"· engine={which}")
    eng, done, t0 = engine(which), 0, time.time()
    try:
        for t in todo:
            if done >= limit:
                break
            cache[t] = eng.translate(t)
            done += 1
            if done % 100 == 0:
                CACHE.write_text(json.dumps(cache, ensure_ascii=False),
                                 encoding="utf-8")
                print(f"  {done}/{min(limit,len(todo))}  "
                      f"({done/(time.time()-t0):.1f}/s)", flush=True)
    finally:
        CACHE.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    # write the SEPARATE Russian examples file (english example -> russian),
    # leaving words.json untouched. The app loads this as an overlay.
    OUT_RU.write_text(json.dumps(cache, ensure_ascii=False), encoding="utf-8")
    print(f"done: +{done} new · {len(cache)} total translations -> {OUT_RU}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["test", "run"])
    ap.add_argument("which", nargs="?", default="both")
    ap.add_argument("--engine", default="opus", choices=["opus", "nllb"])
    ap.add_argument("--limit", type=int, default=1_000_000)
    a = ap.parse_args()
    if a.cmd == "test":
        cmd_test(a.which)
    else:
        cmd_run(a.engine, a.limit)
