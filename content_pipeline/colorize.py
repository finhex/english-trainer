import re

# palette taken from the course's own lesson 1, per theme
PAL = {
    False: {"red": "#F00000", "hl": "#BCE1FF"},   # light
    True:  {"red": "#CF2222", "hl": "#003555"},   # dark
}

# the grammatical markers the course paints red: auxiliaries, modals, negatives
AUX = [
    "will not", "would not", "shall not", "should not", "can not", "cannot",
    "must not", "am not", "is not", "are not", "was not", "were not",
    "do not", "does not", "did not", "have not", "has not", "had not",
    "won't", "wouldn't", "shan't", "shouldn't", "can't", "mustn't",
    "don't", "doesn't", "didn't", "haven't", "hasn't", "hadn't", "isn't",
    "aren't", "wasn't", "weren't",
    "will", "would", "shall", "should", "can", "must",
    "does", "did", "do", "am", "is", "are", "was", "were",
    "have", "has", "had",
]
_AUX_RE = re.compile(
    r"(?<![\w'])(" + "|".join(sorted((re.escape(a) for a in AUX),
                                     key=len, reverse=True)) + r")(?![\w'])",
    re.I)

_TABLE = re.compile(r'<table\s+class="main"[^>]*>', re.I)
_TAGS = re.compile(r'<(/?)table\b[^>]*>', re.I)


def _span_end(html, start):
    """End of the <table> opened at start."""
    depth = 0
    for m in _TAGS.finditer(html, start):
        if m.group(1):
            depth -= 1
            if depth == 0:
                return m.end()
        else:
            depth += 1
    return len(html)


def _paint_text(block, red):
    """Red-mark the auxiliaries in text that carries no colour of its own."""
    out, pos = [], 0
    # skip anything already inside a coloured span or a pronoun <div>
    skip = re.compile(r'<(span|div)[^>]*color:[^>]*>.*?</\1>', re.I | re.S)
    guarded = []
    for m in skip.finditer(block):
        guarded.append((m.start(), m.end()))

    def shielded(i):
        return any(a <= i < b for a, b in guarded)

    for m in re.finditer(r'>([^<>]+)<', block):
        if shielded(m.start()):
            continue
        text = m.group(1)
        if not text.strip() or not _AUX_RE.search(text):
            continue
        new = _AUX_RE.sub(
            lambda a: f'<span style="color: {red}">{a.group(0)}</span>', text)
        out.append((m.start(1), m.end(1), new))
    for a, b, new in reversed(out):
        block = block[:a] + new + block[b:]
    return block


def _highlight(block, hl):
    """Tint the second content panel of each row, as lesson 1 does with one."""
    if re.search(r'class="current"', block, re.I) or hl in block:
        return block
    rows = list(re.finditer(r'<tr\b[^>]*>(.*?)</tr>', block, re.I | re.S))
    edits = []
    for row in rows:
        body, base = row.group(1), row.start(1)
        depth, cells = 0, []
        for m in re.finditer(r'<(/?)(td|table)\b([^>]*)>', body, re.I):
            tag, closing = m.group(2).lower(), bool(m.group(1))
            if tag == "table":
                depth += -1 if closing else 1
            elif tag == "td" and depth == 0 and not closing:
                cells.append(m)
        if len(cells) < 3:
            continue
        cell = cells[1]                      # the Statement panel
        attrs = cell.group(3)
        if "background" in attrs.lower():
            continue
        st = re.search(r'style\s*=\s*"([^"]*)"', attrs, re.I)
        if st:
            new_attrs = attrs.replace(st.group(0),
                                      f'style="{st.group(1)};background: {hl}"')
        else:
            new_attrs = attrs + f' style="background: {hl}"'
        edits.append((base + cell.start(3), base + cell.end(3), new_attrs))
    for a, b, new in reversed(edits):
        block = block[:a] + new + block[b:]
    return block


def colorize(html, dark):
    """Paint the conjugation boxes the way lesson 1's are painted."""
    pal = PAL[dark]
    out, pos = [], 0
    for m in _TABLE.finditer(html):
        if m.start() < pos:
            continue
        end = _span_end(html, m.start())
        block = html[m.start():end]
        block = _highlight(_paint_text(block, pal["red"]), pal["hl"])
        out.append(html[pos:m.start()])
        out.append(block)
        pos = end
    out.append(html[pos:])
    return "".join(out)
