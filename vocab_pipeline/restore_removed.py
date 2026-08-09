#!/usr/bin/env python3
"""
Undo the clean_vocab removals: bring back every word that clean_vocab.py dropped
(restored in full from ru/words_en_backup.json — senses/level/pos), re-attach a
Russian word-level translation via DeepL (their definition/example RU is already
in the overlays), and KEEP the added base verbs go/do/be/have. Result: the full
original 10,000 + the 4 additions.
"""
import json
import urllib.parse
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
WORDS = HERE.parent / "app" / "assets" / "words.json"
BACKUP = HERE / "ru" / "words_en_backup.json"


def deepl_key():
    f = HERE / "ru" / "deepl_key.txt"
    return f.read_text().strip() if f.exists() else ""


def deepl(texts, key):
    if not texts or not key:
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
    have = {w["word"] for w in words}
    backup = json.loads(BACKUP.read_text(encoding="utf-8"))["words"]

    missing = [w for w in backup if w["word"] not in have]
    print(f"restoring {len(missing)} words dropped by clean_vocab")

    key = deepl_key()
    ru_map = deepl([w["word"] for w in missing], key)
    print(f"DeepL word-level translations: {len(ru_map)}")

    for w in missing:
        w = dict(w)  # copy from backup
        # normalise senses to include an (empty) ru list like the rest
        w["senses"] = [{**s, "ru": s.get("ru", [])} for s in w["senses"]]
        tr = (ru_map.get(w["word"], "") or "").strip()
        w["ru"] = [tr] if tr else []
        words.append(w)

    data["words"] = words
    WORDS.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
    print(f"total words now: {len(words)}")


if __name__ == "__main__":
    main()
