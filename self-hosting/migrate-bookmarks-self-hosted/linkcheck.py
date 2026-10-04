#!/usr/bin/env python3
"""Check every URL in a Netscape HTML file and write a CSV triage report."""
import argparse, csv, json, sys, time
import urllib.error, urllib.parse, urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from urllib.parse import urlsplit

from normalize import NetscapeParser

UA = "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"
FIELDS = ["url", "status_class", "http_status", "final_url", "wayback_url", "error"]


def fetch(url, method, timeout):
    req = urllib.request.Request(url, method=method, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.geturl(), ""
    except urllib.error.HTTPError as e:
        return e.code, e.geturl() or url, ""


def classify(url, timeout):
    try:
        status, final, err = fetch(url, "HEAD", timeout)
        if status in (403, 405, 501):
            status, final, err = fetch(url, "GET", timeout)
    except Exception as e:  # DNS failure, timeout, SSL error, bad URL
        return dict(url=url, status_class="error", http_status="", final_url="",
                    wayback_url="", error=type(e).__name__)
    if status in (403, 429):
        cls = "blocked"
    elif status in (404, 410):
        cls = "gone"
    elif status >= 500:
        cls = "error"
    elif 200 <= status < 300:
        same = urlsplit(final).hostname == urlsplit(url).hostname
        cls = "ok" if same else "moved"
    else:
        cls = "error"
    return dict(url=url, status_class=cls, http_status=status, final_url=final,
                wayback_url="", error=err)


def wayback(row):
    api = "https://archive.org/wayback/available?url=" + urllib.parse.quote(row["url"], safe="")
    try:
        with urllib.request.urlopen(urllib.request.Request(api, headers={"User-Agent": UA}), timeout=20) as r:
            snap = json.load(r).get("archived_snapshots", {}).get("closest")
            row["wayback_url"] = snap["url"] if snap and snap.get("available") else ""
    except urllib.error.HTTPError as e:
        if e.code == 429:
            row["wayback_url"] = "rate-limited"  # unknown, retry later
    except Exception:
        pass


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", type=Path)
    ap.add_argument("--out", required=True)
    ap.add_argument("--workers", type=int, default=16)
    ap.add_argument("--timeout", type=int, default=10)
    ap.add_argument("--wayback", action="store_true", help="look up snapshots for gone/error rows")
    args = ap.parse_args()

    parser = NetscapeParser("check")
    parser.feed(args.input.read_text(encoding="utf-8"))
    urls = [r["url"] for r in parser.records]
    with ThreadPoolExecutor(args.workers) as pool:
        rows = list(pool.map(lambda u: classify(u, args.timeout), urls))

    if args.wayback:
        for row in rows:
            if row["status_class"] in ("gone", "error"):
                wayback(row)
                time.sleep(1.5)  # archive.org returns 429 fast

    with open(args.out, "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, FIELDS)
        w.writeheader()
        w.writerows(rows)
    for cls, n in sorted(Counter(r["status_class"] for r in rows).items()):
        print(f"{cls}: {n}", file=sys.stderr)


if __name__ == "__main__":
    main()
