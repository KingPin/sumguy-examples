#!/usr/bin/env python3
"""Merge Chrome/Firefox/Raindrop/Pocket/Pinboard exports into one Netscape HTML file."""
import argparse, csv, html, json, sys
from collections import Counter
from datetime import datetime
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import parse_qsl, quote, urlencode, urlsplit, urlunsplit

ROOT_FOLDERS = {"bookmarks bar", "other bookmarks", "mobile bookmarks", "bookmarks menu",
                "bookmarks toolbar", "unsorted bookmarks"}
BAD_PREFIXES = ("javascript:", "place:", "chrome://", "about:", "file://", "data:")


def normalize_url(url):
    """Mirror linkding: lowercase scheme and host, strip trailing slashes, sort query params."""
    p = urlsplit(url.strip())
    query = urlencode(sorted(parse_qsl(p.query, keep_blank_values=True)), quote_via=quote)
    return urlunsplit((p.scheme.lower(), p.netloc.lower(), p.path.rstrip("/"), query, p.fragment))


def to_unix(value):
    """Unix seconds from seconds, milliseconds, or an ISO 8601 string. 0 if unknown."""
    value = str(value or "").strip()
    if not value:
        return 0
    if value.isdigit():
        n = int(value)
        while n > 10**11:  # milliseconds, microseconds, nanoseconds
            n //= 1000
        return n
    try:
        return int(datetime.fromisoformat(value).timestamp())
    except ValueError:
        return 0


def rec(url, title="", add=0, tags=(), folders=(), toread=False, private=True, desc="", source=""):
    return dict(url=url, title=title, add=add, tags=set(tags), folders=list(folders),
                toread=toread, private=private, desc=desc, source=source, dups=0)


class NetscapeParser(HTMLParser):
    def __init__(self, source):
        super().__init__()
        self.source, self.records = source, []
        self.stack, self.pending = [], None   # open <DL> levels, folder name awaiting its <DL>
        self.cur, self.mode = None, None      # current <A> record, what text goes where

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag != "dd":
            self.mode = "title" if tag == "a" else "folder" if tag == "h3" else None
        if tag == "dl":
            self.stack.append(self.pending)
            self.pending = None
        elif tag == "h3":
            self.buf = ""
        elif tag == "a":
            tags = [t.strip() for t in a.get("tags", "").split(",") if t.strip()]
            self.cur = rec(a.get("href", ""), add=to_unix(a.get("add_date")), tags=tags,
                           folders=[f for f in self.stack if f], toread=a.get("toread") == "1",
                           private=a.get("private") != "0", source=self.source)
            self.records.append(self.cur)
        elif tag == "dd":
            self.mode = "desc"

    def handle_endtag(self, tag):
        if tag == "dl" and self.stack:
            self.stack.pop()
        elif tag == "h3":
            self.pending = self.buf.strip()
        if tag in ("a", "h3", "dl"):
            self.mode = None

    def handle_data(self, data):
        if self.mode == "folder":
            self.buf += data
        elif self.mode == "title" and self.cur:
            self.cur["title"] += data
        elif self.mode == "desc" and self.cur:
            self.cur["desc"] += data


def read_html(path):
    p = NetscapeParser(path.stem)
    p.feed(path.read_text(encoding="utf-8", errors="replace"))
    for r in p.records:
        r["desc"] = r["desc"].strip()
    return p.records


def split_tags(s, sep):
    return [t.strip() for t in (s or "").split(sep) if t.strip()]


def read_csv(path):
    with path.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))  # by column name, never by position
    pocket = bool(rows) and "time_added" in rows[0]
    out = []
    for row in rows:
        if pocket:
            tags = split_tags(row.get("tags"), "|")
            if row.get("status") == "archive":
                tags.append("pocket-archive")
            out.append(rec(row.get("url", ""), row.get("title", ""), to_unix(row.get("time_added")),
                           tags, toread=row.get("status") == "unread", source="pocket"))
        else:
            folders = [f for f in (row.get("folder") or "").split("/") if f]
            out.append(rec(row.get("url", ""), row.get("title", ""), to_unix(row.get("created")),
                           split_tags(row.get("tags"), ","), folders, source="raindrop"))
    return out


def read_json(path):
    out = []
    for row in json.loads(path.read_text(encoding="utf-8")):
        out.append(rec(row.get("href", ""), row.get("description", ""), to_unix(row.get("time")),
                       split_tags(row.get("tags"), " "), toread=row.get("toread") == "yes",
                       private=row.get("shared") == "no", desc=row.get("extended", ""),
                       source="pinboard"))
    return out


def read_any(path):
    ext = path.suffix.lower()
    if ext in (".html", ".htm"):
        return read_html(path)
    if ext == ".csv":
        return read_csv(path)
    if ext == ".json":
        return read_json(path)
    raise SystemExit(f"unsupported input: {path}")


def folder_tag(name):
    return name.strip().lower().replace(" ", "-")


def merge(records, folder_tags, min_depth, stats):
    merged = {}
    for r in records:
        if r["url"].strip().lower().startswith(BAD_PREFIXES) or not r["url"].strip():
            stats["skipped"] += 1
            continue
        if folder_tags:
            named = [f for f in r["folders"] if f.lower() not in ROOT_FOLDERS]
            r["tags"] |= {folder_tag(f) for f in named[min_depth - 1:]}
        r["tags"].add("source:" + r["source"])
        key = normalize_url(r["url"])
        old = merged.get(key)
        if not old:
            merged[key] = r
            continue
        old["dups"] += 1
        stats["merged"] += 1
        old["tags"] |= r["tags"]
        old["add"] = min([d for d in (old["add"], r["add"]) if d] or [0])
        old["title"] = max(old["title"].strip(), r["title"].strip(), key=len)
        old["desc"] = max(old["desc"], r["desc"], key=len)
        old["toread"] |= r["toread"]
        old["private"] |= r["private"]
    return list(merged.values())


def write_html(records, out):
    lines = ["<!DOCTYPE NETSCAPE-Bookmark-file-1>",
             '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">',
             "<TITLE>Bookmarks</TITLE>", "<H1>Bookmarks</H1>", "<DL><p>"]
    for r in sorted(records, key=lambda r: r["add"]):
        q = lambda s: html.escape(s, quote=True)
        attrs = (f'HREF="{q(r["url"])}" ADD_DATE="{r["add"]}" TAGS="{q(",".join(sorted(r["tags"])))}"'
                 f' PRIVATE="{int(r["private"])}"' + (' TOREAD="1"' if r["toread"] else ""))
        lines.append(f'    <DT><A {attrs}>{html.escape(r["title"].strip() or r["url"])}</A>')
        if r["desc"]:
            lines.append(f'    <DD>{html.escape(r["desc"])}')
    lines.append("</DL><p>")
    Path(out).write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("inputs", nargs="+", type=Path)
    ap.add_argument("--out", required=True)
    ap.add_argument("--folder-tags", action="store_true", help="turn folder names into tags")
    ap.add_argument("--min-tag-depth", type=int, default=1,
                    help="skip folders above this depth (1 = every non-root folder)")
    args = ap.parse_args(argv)
    stats = Counter()
    records = []
    for path in args.inputs:
        got = read_any(path)
        stats.update("read:" + r["source"] for r in got)
        records += got
    final = merge(records, args.folder_tags, args.min_tag_depth, stats)
    write_html(final, args.out)
    for k in sorted(k for k in stats if k.startswith("read:")):
        print(f"read {k[5:]}: {stats[k]}", file=sys.stderr)
    print(f"skipped non-http: {stats['skipped']}\nduplicates merged: {stats['merged']}\n"
          f"written: {len(final)}\ndistinct tags: {len(set().union(*(r['tags'] for r in final)) if final else [])}",
          file=sys.stderr)
    return final


if __name__ == "__main__":
    main()
