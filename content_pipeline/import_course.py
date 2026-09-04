#!/usr/bin/env python3
"""
Import the 1st-English course (grammar explanations + build-the-sentence drills)
from eng1stApp's content.db into our app's content.json as section 'course'.

Explanations are converted from the original HTML to **markdown** (our app
renders markdown, not HTML).
"""
import json, re, sqlite3, sys
from html.parser import HTMLParser
from html import unescape
from pathlib import Path

SRC_DB = "/home/konako/Documents/Claude/eng1stApp/desktop/assets/content.db"
CONTENT = Path("/home/konako/Documents/Claude/_git-backups/apps/words/app/assets/content.json")

BLOCK = {"p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li",
         "table", "tr", "blockquote"}


class MdParser(HTMLParser):
    """Minimal HTML -> Markdown for these lesson pages."""

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out = []
        self.list_stack = []   # 'ul' | 'ol'
        self.oli = []          # counters for ol
        self.in_a = None
        self.a_text = []
        self.row = None        # current table row cells
        self.cell = None
        self.table_rows = None
        self.emphasis = 0

    # -- helpers -------------------------------------------------------
    def _emit(self, s):
        if self.cell is not None:
            self.cell.append(s)
        elif self.in_a is not None:
            self.a_text.append(s)
        else:
            self.out.append(s)

    def _nl(self, n=1):
        # collapse trailing newlines to at most n
        while self.out and self.out[-1] == "\n":
            self.out.pop()
        self.out.append("\n" * n)

    # -- tags ----------------------------------------------------------
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self._nl(2)
            self.out.append("#" * min(int(tag[1]) + 1, 6) + " ")
        elif tag == "p":
            self._nl(2)
        elif tag == "br":
            self._emit("  \n")
        elif tag in ("strong", "b"):
            self.emphasis += 1
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
            self.in_a = a.get("href", "")
            self.a_text = []
        elif tag == "table":
            self.table_rows = []
        elif tag == "tr":
            self.row = []
        elif tag in ("td", "th"):
            self.cell = []
        elif tag == "blockquote":
            self._nl(2); self.out.append("> ")

    def handle_endtag(self, tag):
        if tag in ("h1", "h2", "h3", "h4", "h5", "h6"):
            self._nl(2)
        elif tag == "p":
            self._nl(2)
        elif tag in ("strong", "b"):
            if self.emphasis:
                self.emphasis -= 1
                self._emit("**")
        elif tag in ("em", "i"):
            self._emit("*")
        elif tag in ("ul", "ol"):
            if self.list_stack:
                k = self.list_stack.pop()
                if k == "ol" and self.oli:
                    self.oli.pop()
            self._nl(2)
        elif tag == "li":
            pass
        elif tag == "a":
            text = "".join(self.a_text).strip()
            href = self.in_a
            self.in_a = None
            self.a_text = []
            if text:
                self._emit(f"[{text}]({href})" if href else text)
        elif tag in ("td", "th"):
            if self.row is not None and self.cell is not None:
                self.row.append(" ".join("".join(self.cell).split()))
            self.cell = None
        elif tag == "tr":
            if self.table_rows is not None and self.row:
                self.table_rows.append(self.row)
            self.row = None
        elif tag == "table":
            rows = self.table_rows or []
            self.table_rows = None
            if rows:
                self._nl(2)
                width = max(len(r) for r in rows)
                rows = [r + [""] * (width - len(r)) for r in rows]
                self.out.append("| " + " | ".join(rows[0]) + " |\n")
                self.out.append("|" + "|".join([" --- "] * width) + "|\n")
                for r in rows[1:]:
                    self.out.append("| " + " | ".join(r) + " |\n")
                self._nl(2)

    def handle_data(self, data):
        if not data:
            return
        # keep single spaces, drop newlines that HTML treats as whitespace
        text = re.sub(r"\s+", " ", data)
        if text.strip() == "" and (not self.out or self.out[-1].endswith("\n")):
            return
        # don't start a fresh line with a stray space (e.g. right after <br/>)
        tail = (self.cell or self.a_text or self.out)
        if tail and str(tail[-1]).endswith("\n"):
            text = text.lstrip()
        self._emit(text)

    def markdown(self):
        md = "".join(self.out)
        md = re.sub(r"[ \t]+\n", "\n", md)
        md = re.sub(r"\n{3,}", "\n\n", md)
        md = re.sub(r"\*\*\s*\*\*", "", md)          # empty bold
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

    # drills grouped by lesson
    drills = {}
    for lesson, eng, answer, slots, decoys, ru, form in db.execute(
            "select lesson,eng,answer,slots,decoys,ru,form from drills order by lesson,ord"):
        try:
            sl = json.loads(slots)
        except Exception:
            continue
        # tiles: first accepted alternative of each slot (always solvable)
        tokens = [alts[0] for alts in sl if isinstance(alts, list) and alts]
        if not tokens:
            continue
        try:
            dec = json.loads(decoys) or []
        except Exception:
            dec = []
        drills.setdefault(lesson, []).append({
            "prompt": ru.strip(),
            "answer": (answer or eng).strip(),
            "tokens": tokens,
            "distractors": [d for d in dec if isinstance(d, str)][:4],
        })

    data = json.loads(CONTENT.read_text())
    lessons = data["lessons"]
    # drop any previous import so re-running is safe
    lessons = [l for l in lessons if l.get("section") != "course"]
    max_ord = max((l.get("ord") or 0) for l in lessons)
    max_id = max((l.get("id") or 0) for l in lessons)

    added = 0
    total_items = 0
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
            "grammarMdRu": md,          # the course is taught in Russian
            "uniqueSentences": len(items),
            "level": 1,
            "levelName": f"Урок {i}",
            "section": "course",
            "practices": ({"word_order": {"goal": min(20, max(5, len(items) // 10)),
                                          "items": items}} if items else {}),
        }
        if subtitle:
            lesson["subtitle"] = subtitle
        lessons.append(lesson)
        added += 1
        total_items += len(items)

    data["lessons"] = lessons
    CONTENT.write_text(json.dumps(data, ensure_ascii=False))
    size = CONTENT.stat().st_size / 1048576
    print(f"course lessons added: {added}")
    print(f"practice items imported: {total_items}")
    print(f"content.json now: {len(lessons)} lessons, {size:.1f} MB")


if __name__ == "__main__":
    main()
