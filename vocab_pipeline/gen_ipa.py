#!/usr/bin/env python3
"""
Generate UK + US IPA for every word in app/assets/words.json into ipa.json
({word: {"uk": ..., "us": ...}}). British/American phonemes come from WikiPron
(IPA scraped from Wiktionary, wordlists/wikipron_{uk,us}_broad.tsv); stress marks
— which WikiPron omits — are placed using the CMU Pronouncing Dictionary's
stressed-vowel position + onset-cluster detection (diphthongs = one nucleus).
US falls back to a CMU→IPA conversion where WikiPron has no entry.
"""
import json
import re
from pathlib import Path

from nltk.corpus import cmudict

HERE = Path(__file__).parent
A = HERE.parent / "app" / "assets"
WL = HERE / "wordlists"
cmu = cmudict.dict()

ARPA_V = set('AA AE AH AO AW AY EH ER EY IH IY OW OY UH UW'.split())
VIPA = set('iɪeɛæɑɒɔoʊuʌəɜɐayøœɚɝ')
IPA_ONS3 = {('s', 'p', 'l'), ('s', 'p', 'ɹ'), ('s', 't', 'ɹ'), ('s', 'k', 'ɹ'),
            ('s', 'k', 'w')}
IPA_ONS2 = {('p', 'l'), ('p', 'ɹ'), ('b', 'l'), ('b', 'ɹ'), ('t', 'ɹ'),
            ('d', 'ɹ'), ('k', 'l'), ('k', 'ɹ'), ('ɡ', 'l'), ('ɡ', 'ɹ'),
            ('f', 'l'), ('f', 'ɹ'), ('θ', 'ɹ'), ('ʃ', 'ɹ'), ('s', 'p'),
            ('s', 't'), ('s', 'k'), ('s', 'm'), ('s', 'n'), ('s', 'l'),
            ('s', 'w'), ('t', 'w'), ('k', 'w'), ('h', 'j'), ('p', 'j'),
            ('b', 'j'), ('k', 'j'), ('f', 'j'), ('v', 'j'), ('m', 'j'),
            ('n', 'j'), ('d', 'j'), ('t', 'j'), ('ð', 'j')}
ARPA = {'AA': 'ɑ', 'AE': 'æ', 'AO': 'ɔ', 'AW': 'aʊ', 'AY': 'aɪ', 'B': 'b',
        'CH': 'tʃ', 'D': 'd', 'DH': 'ð', 'EH': 'ɛ', 'EY': 'eɪ', 'F': 'f',
        'G': 'ɡ', 'HH': 'h', 'IH': 'ɪ', 'IY': 'i', 'JH': 'dʒ', 'K': 'k',
        'L': 'l', 'M': 'm', 'N': 'n', 'NG': 'ŋ', 'OW': 'oʊ', 'OY': 'ɔɪ',
        'P': 'p', 'R': 'ɹ', 'S': 's', 'SH': 'ʃ', 'T': 't', 'TH': 'θ',
        'UH': 'ʊ', 'UW': 'u', 'V': 'v', 'W': 'w', 'Y': 'j', 'Z': 'z',
        'ZH': 'ʒ'}
ARP3 = {('S', 'P', 'L'), ('S', 'P', 'R'), ('S', 'T', 'R'), ('S', 'K', 'R'),
        ('S', 'K', 'W')}
ARP2 = {('P', 'L'), ('P', 'R'), ('B', 'L'), ('B', 'R'), ('T', 'R'), ('D', 'R'),
        ('K', 'L'), ('K', 'R'), ('G', 'L'), ('G', 'R'), ('F', 'L'), ('F', 'R'),
        ('TH', 'R'), ('SH', 'R'), ('S', 'P'), ('S', 'T'), ('S', 'K'),
        ('S', 'M'), ('S', 'N'), ('S', 'L'), ('S', 'W'), ('T', 'W'), ('K', 'W'),
        ('P', 'Y'), ('B', 'Y'), ('K', 'Y'), ('M', 'Y'), ('F', 'Y'), ('HH', 'Y')}


def load(f):
    m = {}
    for line in open(f, encoding='utf-8'):
        p = line.rstrip('\n').split('\t')
        if len(p) == 2 and p[0] not in m:
            m[p[0]] = p[1]
    return m


uk = load(WL / 'wikipron_uk_broad.tsv')
us = load(WL / 'wikipron_us_broad.tsv')


def cmu_ipa(ph):
    bs, st, vv = [], [], []
    for p in ph:
        m = re.match(r'([A-Z]+)(\d?)', p)
        bs.append(m.group(1))
        st.append(m.group(2))
        vv.append(m.group(1) in ARPA_V)

    def sy(b, s):
        if b == 'AH':
            return 'ʌ' if s in ('1', '2') else 'ə'
        if b == 'ER':
            return 'ɝ' if s in ('1', '2') else 'ɚ'
        return ARPA.get(b, b.lower())

    if sum(vv) <= 1:
        return ''.join(sy(b, '') for b in bs)
    marks, pv = {}, -1
    for i, b in enumerate(bs):
        if vv[i] and st[i] in ('1', '2'):
            cons = [bs[j] for j in range(pv + 1, i)]
            n = len(cons)
            on = (3 if n >= 3 and tuple(cons[-3:]) in ARP3
                  else 2 if n >= 2 and tuple(cons[-2:]) in ARP2
                  else 1 if n >= 1 else 0)
            marks[i - on] = 'ˈ' if st[i] == '1' else 'ˌ'
        if vv[i]:
            pv = i
    return ''.join(marks.get(i, '') + sy(bs[i], st[i]) for i in range(len(bs)))


def cmu_stress(ph):
    ords, vi = {}, 0
    for p in ph:
        m = re.match(r'([A-Z]+)(\d?)', p)
        if m.group(1) in ARPA_V:
            if m.group(2) in ('1', '2'):
                ords[vi] = m.group(2)
            vi += 1
    return ords, vi


def isv(t):
    return any(c in VIPA for c in t)


def nuclei(toks):
    sp, i, n = [], 0, len(toks)
    while i < n:
        if isv(toks[i]):
            s = i
            while i < n and isv(toks[i]):
                i += 1
            sp.append((s, i))
        else:
            i += 1
    return sp


def hybrid(toks, ords):
    nuc = nuclei(toks)
    marks = {}
    for vi, (s, e) in enumerate(nuc):
        if vi in ords:
            prev_end = nuc[vi - 1][1] if vi > 0 else 0
            cons = [toks[j] for j in range(prev_end, s)]
            n = len(cons)
            on = (3 if n >= 3 and tuple(c[0] for c in cons[-3:]) in IPA_ONS3
                  else 2 if n >= 2 and tuple(c[0] for c in cons[-2:]) in IPA_ONS2
                  else 1 if n >= 1 else 0)
            marks[s - on] = 'ˈ' if ords[vi] == '1' else 'ˌ'
    return ''.join(marks.get(i, '') + t for i, t in enumerate(toks))


def hyb_or_none(wp, k):
    if k not in wp:
        return None
    toks = wp[k].split()
    nv = len(nuclei(toks))
    if nv <= 1:
        return ''.join(toks)
    if k in cmu:
        ords, nc = cmu_stress(cmu[k][0])
        if nc == nv:
            return hybrid(toks, ords)
    return None


def uk_v(w):
    k = w.lower()
    h = hyb_or_none(uk, k)
    if h is not None:
        return h
    return ''.join(uk[k].split()) if k in uk else ''


def us_v(w):
    k = w.lower()
    h = hyb_or_none(us, k)
    if h is not None:
        return h
    if k in cmu:
        return cmu_ipa(cmu[k][0])
    return ''.join(us[k].split()) if k in us else ''


def main():
    vocab = [w['word'] for w in json.loads((A / 'words.json').read_text())['words']]
    out = {}
    for w in vocab:
        u, s = uk_v(w), us_v(w)
        if u or s:
            out[w] = {k: v for k, v in (('uk', u), ('us', s)) if v}
    (A / 'ipa.json').write_text(json.dumps(out, ensure_ascii=False))
    print(f"ipa.json: {len(out)} words | "
          f"UK {sum('uk' in v for v in out.values())} | "
          f"US {sum('us' in v for v in out.values())}")


if __name__ == "__main__":
    main()
