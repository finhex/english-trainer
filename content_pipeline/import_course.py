#!/usr/bin/env python3
"""
Import the 1st-English course (grammar explanations + build-the-sentence drills)
from eng1stApp's content.db into our app's content.json as section 'course'.

Two things are reproduced from the original app rather than simplified:

  * The exercise is a SERIES OF CHOICES, not a word search. For each slot the
    original finds the lesson template the answer belongs to — a group of
    interchangeable words such as `my; your; his; her; our; their` — and offers
    a few of that group as one row. Rows appear in slot order. That layout is
    pre-built here (see build_rows, a port of the original's sentence.dart).

  * The colored glosses in the lesson text (blue Russian translations) survive
    the HTML -> markdown conversion as ==highlight== spans, which our markdown
    renderer paints in the accent color.
"""
import json, random, re, sqlite3
from html.parser import HTMLParser
from pathlib import Path

SRC_DB = "/home/konako/Documents/Claude/eng1stApp/desktop/assets/content.db"
CONTENT = Path("/home/konako/Documents/Claude/_git-backups/apps/words/app/assets/content.json")

PER_ROW = 4

# the four colors the course uses -> our markdown markers
BLUE, GRAY, RED, GREEN = "==", "%%", "!!", "++"


def _color_mark(style):
    st = (style or "").lower()
    if "color" not in st:
        return ""
    if "005bd8" in st:
        return BLUE
    if "gray" in st or "grey" in st or "#808080" in st:
        return GRAY
    if "f00000" in st or "red" in st:
        return RED
    if "green" in st:
        return GREEN
    return BLUE


BLOCK_COLOR_TAGS = {"div", "p", "td", "th", "li", "blockquote"}
# markdown line prefixes that must stay outside the color marker
_PREFIX = re.compile(r"^(\s*(?:[-*+]\s+|\d+\.\s+|#{1,6}\s+|>\s*)?)(.*)$")


def _wrap_lines(segment, mark):
    """Wrap each non-empty line of a colored block in the marker."""
    out = []
    for line in segment.split("\n"):
        m = _PREFIX.match(line)
        prefix, body = m.group(1), m.group(2)
        body = body.strip()
        out.append(f"{prefix}{mark}{body}{mark}" if body else line)
    return "\n".join(out)


def normalise(tile):
    return re.sub(r"[^a-zа-яё0-9'\s]", "", (tile or "").lower()).strip()


def build_rows(slots, templates, bank=(), decoys=(), per_row=PER_ROW, seed=0):
    """Port of the original buildRows: one row of choices per slot."""
    rnd = random.Random(seed or (len(slots) * 31 + len(templates)))

    def template_for(word):
        want = normalise(word)
        for group in templates:
            for option in group:
                if normalise(option) == want:
                    return group
        return None

    rows = []
    for slot in slots:
        answer = next((o for o in slot if o), "")
        if not answer:
            continue
        group = template_for(answer)
        required = [o for o in slot if o]
        seen = {normalise(o) for o in required}
        source = group if group is not None else list(bank)
        extras = []
        for word in source:
            n = normalise(word)
            if n not in seen:
                seen.add(n)
                extras.append(word)
        rnd.shuffle(extras)
        room = max(0, min(per_row - len(required), per_row))
        row = required + extras[:room]
        rnd.shuffle(row)
        rows.append(row)

    # decoys sit at a position and are offered like any other choice
    for at, word in decoys:
        seen = {normalise(word)}
        group = template_for(word)
        extras = []
        for other in (group if group is not None else list(bank)):
            n = normalise(other)
            if n not in seen:
                seen.add(n)
                extras.append(other)
        rnd.shuffle(extras)
        row = [word] + extras[:per_row - 1]
        rnd.shuffle(row)
        rows.insert(max(0, min(at, len(rows))), row)
    return rows


# --------------------------------------------------------------------------
# HTML -> Markdown
# --------------------------------------------------------------------------
class MdParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out = []
        self.list_stack = []
        self.oli = []
        self.in_a = None
        self.a_text = []
        self.row = None
        self.cell = None
        self.table_rows = None
        self.table_has_th = False
        self.color_stack = []
        self.block_color = []

    def _emit(self, s):
        if self.cell is not None:
            self.cell.append(s)
        elif self.in_a is not None:
            self.a_text.append(s)
        else:
            self.out.append(s)

    def _nl(self, n=1):
        while self.out and self.out[-1] == "\n":
            self.out.pop()
        self.out.append("\n" * n)

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        # the course colors its text — blue glosses, gray notes, red warnings,
        # green. Markdown has no color, so each keeps its own marker and the
        # app paints them. Colors sit on <span>, <ru>, <div> and <td> alike.
        mark = _color_mark(a.get("style") or "")
        if tag in BLOCK_COLOR_TAGS:
            # push for EVERY block tag so nesting pops the right entry.
            # Inside a table cell the text goes to the cell buffer, not out.
            buf = self.cell if self.cell is not None else self.out
            self.block_color.append((mark, len(buf), self.cell is not None))
            mark = ""            # applied per line when the block closes
        elif mark:
            self._emit(mark)
        self.color_stack.append((tag, mark))
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self._nl(2); self.out.append("#" * min(int(tag[1]) + 1, 6) + " ")
        elif tag == "p":
            self._nl(2)
        elif tag == "br":
            self._emit("  \n")
        elif tag in ("strong", "b"):
            self._emit("**")
        elif tag in ("em", "i"):
            self._emit("*")
        elif tag == "ul":
            self.list_stack.append("ul"); self._nl(2)
        elif tag == "ol":
            self.list_stack.append("ol"); self.oli.append(0); self._nl(2)
        elif tag == "li":
            self._nl(1)
            depth = max(len(self.list_stack) - 1, 0)
            if self.list_stack and self.list_stack[-1] == "ol":
                self.oli[-1] += 1
                self.out.append("  " * depth + f"{self.oli[-1]}. ")
            else:
                self.out.append("  " * depth + "- ")
        elif tag == "a":
            self.in_a = a.get("href", ""); self.a_text = []
        elif tag == "table":
            self.table_rows = []
            self.table_has_th = False
        elif tag == "tr":
            self.row = []
        elif tag in ("td", "th"):
            self.cell = []
            if tag == "th":
                self.table_has_th = True
        elif tag == "blockquote":
            self._nl(2); self.out.append("> ")

    def handle_endtag(self, tag):
        for k in range(len(self.color_stack) - 1, -1, -1):
            if self.color_stack[k][0] == tag:
                _, mk = self.color_stack.pop(k)
                if mk:
                    self._emit(mk)
                break
        if tag in BLOCK_COLOR_TAGS and self.block_color:
            mk, at, in_cell = self.block_color.pop()
            buf = self.cell if (in_cell and self.cell is not None) else self.out
            if at <= len(buf):
                seg = "".join(buf[at:])
                if mk and seg.strip():
                    del buf[at:]
                    buf.append(_wrap_lines(seg, mk))
                # stacked <div>s inside a cell would run together
                if in_cell and tag == "div" and seg.strip():
                    buf.append(" · ")
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self._nl(2)
        elif tag == "p":
            self._nl(2)
        elif tag in ("strong", "b"):
            self._emit("**")
        elif tag in ("em", "i"):
            self._emit("*")
        elif tag in ("ul", "ol"):
            if self.list_stack:
                k = self.list_stack.pop()
                if k == "ol" and self.oli:
                    self.oli.pop()
            self._nl(2)
        elif tag == "a":
            text = "".join(self.a_text).strip()
            href, self.in_a, self.a_text = self.in_a, None, []
            if text:
                self._emit(f"[{text}]({href})" if href else text)
        elif tag in ("td", "th"):
            if self.row is not None and self.cell is not None:
                txt = " ".join("".join(self.cell).split())
                txt = re.sub(r"(?:\s*·\s*)+$", "", txt).strip()
                self.row.append(txt)
            self.cell = None
        elif tag == "tr":
            if self.table_rows is not None and self.row:
                self.table_rows.append(self.row)
            self.row = None
        elif tag == "table":
            rows, self.table_rows = self.table_rows or [], None
            rows = [r for r in rows if any(c.strip() for c in r)]
            if rows:
                self._nl(2)
                width = max(len(r) for r in rows)
                if not self.table_has_th:
                    rows = [[""] * width] + rows
                rows = [r + [""] * (width - len(r)) for r in rows]
                self.out.append("| " + " | ".join(rows[0]) + " |\n")
                self.out.append("|" + "|".join([" --- "] * width) + "|\n")
                for r in rows[1:]:
                    self.out.append("| " + " | ".join(r) + " |\n")
                self._nl(2)

    def handle_data(self, data):
        if not data:
            return
        text = re.sub(r"\s+", " ", data)
        if text.strip() == "" and (not self.out or self.out[-1].endswith("\n")):
            return
        tail = (self.cell or self.a_text or self.out)
        if tail and str(tail[-1]).endswith("\n"):
            text = text.lstrip()
        self._emit(text)

    def markdown(self):
        md = "".join(self.out)
        md = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", md)
        for mk in (BLUE, GRAY, RED, GREEN):          # drop empty marks
            md = re.sub(re.escape(mk) + r"\s*" + re.escape(mk), "", md)
        md = re.sub(r"[ \t]+\n", "\n", md)
        md = re.sub(r"\n{3,}", "\n\n", md)
        md = re.sub(r"\*\*\s*\*\*", "", md)
        md = re.sub(r"[ \t]{2,}", " ", md)
        return md.strip() + "\n"


def html_to_md(html):
    p = MdParser()
    p.feed(html or "")
    p.close()
    return p.markdown()


def main():
    db = sqlite3.connect(SRC_DB)
    grammar = {r[0]: (r[1], r[2], r[3])
               for r in db.execute("select id,title,subtitle,html_light from grammar")}

    # per-lesson templates ("call; calls; called") and a flat word bank
    templates, bank = {}, {}
    for lesson, value in db.execute("select lesson,value from lesson_dict order by lesson,ord"):
        group = [w.strip() for w in (value or "").split(";") if w.strip()]
        if not group:
            continue
        templates.setdefault(lesson, []).append(group)
        bank.setdefault(lesson, []).extend(group)

    drills = {}
    for lesson, answer, slots, decoys, ru in db.execute(
            "select lesson,answer,slots,decoys,ru from drills order by lesson,ord"):
        try:
            sl = [s for s in json.loads(slots) if isinstance(s, list)]
        except Exception:
            continue
        if not sl:
            continue
        try:
            dec = [(int(a), str(w)) for a, w in (json.loads(decoys) or [])]
        except Exception:
            dec = []
        rows = build_rows(sl, templates.get(lesson, []), bank.get(lesson, []),
                          dec, seed=abs(hash((lesson, answer))) % 100000)
        if not rows:
            continue
        drills.setdefault(lesson, []).append({
            "prompt": (ru or "").strip(),
            "answer": (answer or "").strip(),
            "slots": sl,
            "rows": rows,
            "tokens": [s[0] for s in sl if s and s[0]],
        })

    data = json.loads(CONTENT.read_text())
    lessons = [l for l in data["lessons"] if l.get("section") != "course"]
    max_ord = max((l.get("ord") or 0) for l in lessons)
    max_id = max((l.get("id") or 0) for l in lessons)

    added = total = 0
    for i, gid in enumerate(sorted(grammar), start=1):
        title, subtitle, html = grammar[gid]
        md = html_to_md(html)
        items = drills.get(gid, [])
        if not md.strip() and not items:
            continue
        lesson = {
            "id": max_id + i,
            "ord": max_ord + i,
            "part": "COURSE — 1st English",
            "title": title,
            "titleRu": title,
            "grammarMd": md,
            "grammarMdRu": md,
            "uniqueSentences": len(items),
            "level": 1,
            "levelName": f"Урок {i}",
            "courseNo": i,
            "section": "course",
            "practices": ({"sentence": {"goal": min(70, len(items)),
                                        "items": items}} if items else {}),
        }
        if subtitle:
            lesson["subtitle"] = subtitle
        lessons.append(lesson)
        added += 1
        total += len(items)

    # register the practice type so the app labels it like the original
    data.setdefault("config", {}).setdefault("practices", {})["sentence"] = {
        "label": "Build the phrase", "order": 0, "icon": "reorder",
        "subtitle": "Pick the right word for each position",
    }
    data["lessons"] = lessons
    CONTENT.write_text(json.dumps(data, ensure_ascii=False))
    print(f"course lessons added: {added}")
    print(f"practice items imported: {total}")
    print(f"content.json now: {len(lessons)} lessons, "
          f"{CONTENT.stat().st_size / 1048576:.1f} MB")


if __name__ == "__main__":
    main()
