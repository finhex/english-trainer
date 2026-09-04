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
    """Tint the Statement panel of the OUTER table.

    A conjugation box nests a table inside every panel, so matching <tr>/<td>
    anywhere paints the inner cells instead - which shows up as blue rectangles
    behind single words. Only cells at depth 1 of the outer table are panels.
    """
    if re.search(r'class="current"', block, re.I) or hl in block:
        return block

    depth = 0
    row_start = None
    rows = []                      # (start, end) of each depth-1 <tr>
    for m in re.finditer(r'<(/?)(table|tr)\b[^>]*>', block, re.I):
        tag, closing = m.group(2).lower(), bool(m.group(1))
        if tag == "table":
            depth += -1 if closing else 1
        elif tag == "tr" and depth == 1:
            if not closing:
                row_start = m.end()
            elif row_start is not None:
                rows.append((row_start, m.start()))
                row_start = None

    edits = []
    for a, b in rows:
        body = block[a:b]
        d, cells = 0, []
        for m in re.finditer(r'<(/?)(td|table)\b([^>]*)>', body, re.I):
            tag, closing = m.group(2).lower(), bool(m.group(1))
            if tag == "table":
                d += -1 if closing else 1
            elif tag == "td" and d == 0 and not closing:
                cells.append(m)
        if len(cells) < 3:
            continue
        cell = cells[1]            # the Statement panel
        attrs = cell.group(3)
        if "background" in attrs.lower():
            continue
        # Only a real PANEL is tinted. Some boxes are flat (aux | pronouns |
        # verb straight in the row); tinting a cell there paints a rectangle
        # behind a single word instead of a column, so leave those alone.
        nxt = cells[2].start() if len(cells) > 2 else b - a
        if "<table" not in body[cell.end():nxt].lower():
            continue
        st = re.search(r'style\s*=\s*"([^"]*)"', attrs, re.I)
        if st:
            new_attrs = attrs.replace(
                st.group(0), f'style="{st.group(1)};background: {hl}"')
        else:
            new_attrs = attrs + f' style="background: {hl}"'
        edits.append((a + cell.start(3), a + cell.end(3), new_attrs))
    for x, y, new in reversed(edits):
        block = block[:x] + new + block[y:]
    return block


# The tense label is set vertically, one letter per <br/>, so the cell needs
# almost no width - but an auto-layout table hands it whatever is left over and
# it ends up as wide as a content column. width:1% is the standard way to say
# "shrink to fit" in such a table.
_LABEL_CELL = re.compile(
    r'(<td)([^>]*)(>\s*(?:<small>\s*)?(?:<span[^>]*>\s*)?'
    r'[A-Za-zА-Яа-яЁё](?:\s*<br\s*/?>\s*[A-Za-zА-Яа-яЁё]){2,})',
    re.I)


def _shrink_labels(block):
    def repl(m):
        head, attrs, tail = m.group(1), m.group(2), m.group(3)
        if "width" in attrs.lower():
            return m.group(0)
        st = re.search(r'style\s*=\s*"([^"]*)"', attrs, re.I)
        # text-align sits on the outer table in the source and the renderer does
        # not inherit it down, so the stacked letters hug the left edge of their
        # cell. Centre them on the cell itself, across and down.
        extra = "width: 1%;text-align: center;vertical-align: middle"
        if st:
            attrs = attrs.replace(st.group(0), f'style="{st.group(1)};{extra}"')
        else:
            attrs = attrs + f' style="{extra}"'
        # the CSS width is ignored by the renderer; the legacy attribute is
        # what it actually reads for a table cell
        attrs = attrs + ' width="1"'
        return f"{head}{attrs}{tail}"
    return _LABEL_CELL.sub(repl, block)


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
        block = _shrink_labels(block)
        out.append(html[pos:m.start()])
        out.append(block)
        pos = end
    out.append(html[pos:])
    return "".join(out)
