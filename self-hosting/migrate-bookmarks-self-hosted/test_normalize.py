#!/usr/bin/env python3
"""Run with: python3 test_normalize.py"""
import tempfile
from pathlib import Path

import normalize

HERE = Path(__file__).parent
SAMPLES = sorted(str(p) for p in (HERE / "samples").iterdir())


def run(*flags):
    with tempfile.TemporaryDirectory() as d:
        out = Path(d) / "merged.html"
        normalize.main([*flags, "--out", str(out), *SAMPLES])
        parsed = normalize.NetscapeParser("t")
        parsed.feed(out.read_text(encoding="utf-8"))
        text = out.read_text(encoding="utf-8")
    return {r["url"]: r for r in parsed.records}, text


plain, text = run()
by_norm = {normalize.normalize_url(u): r for u, r in plain.items()}

# javascript: bookmarklet is dropped
assert not any(u.startswith("javascript:") for u in plain)
assert normalize.normalize_url("https://Ex.com/a/?b=2&a=1#f") == "https://ex.com/a?a=1&b=2#f"

# 16 records read, 1 dropped, 1 duplicate pair collapsed
assert len(plain) == 14, len(plain)

# chrome/firefox duplicate: one record, unioned tags, earlier ADD_DATE
caddy = by_norm["https://caddyserver.com/docs"]
assert {"proxy", "tls", "source:chrome", "source:firefox"} <= caddy["tags"], caddy["tags"]
assert caddy["add"] == 1450000000, caddy["add"]
assert caddy["title"] == "Caddy Documentation"  # longest title wins
assert caddy["desc"].startswith("Config reference")

# folder tags only appear with --folder-tags, and root folders never do
assert "home-lab" not in caddy["tags"]
folders, _ = run("--folder-tags")
fcaddy = {normalize.normalize_url(u): r for u, r in folders.items()}["https://caddyserver.com/docs"]
assert {"home-lab", "reverse-proxies"} <= fcaddy["tags"], fcaddy["tags"]
assert not any("bookmarks" in t or t == "other-bookmarks" for r in folders.values() for t in r["tags"])

# Pinboard toread=yes -> TOREAD="1"; shared=no -> PRIVATE="1"
later = plain["https://example.com/read-later"]
assert later["toread"] and later["private"]
assert 'TOREAD="1"' in text

# Pocket cursor column did not break parsing; archive and unread map correctly
sqlite = plain["https://sqlite.org/whentouse.html"]
assert sqlite["toread"] and {"database", "sqlite", "source:pocket"} <= sqlite["tags"]
assert "pocket-archive" in plain["https://example.org/rant/"]["tags"]

# the merge counter survives in memory
final = normalize.main(["--out", "/dev/null", *SAMPLES])
assert sum(r["dups"] for r in final) == 1

print("ok")
