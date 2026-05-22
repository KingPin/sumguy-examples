#!/usr/bin/env python3
"""Aggregate raw header captures into a Sec-Fetch / UA-CH comparison matrix."""
import json
import sys
from collections import defaultdict
from pathlib import Path

RAW = Path(__file__).parent / "results" / "raw.jsonl"

if not RAW.exists():
    print(f"missing {RAW}", file=sys.stderr)
    sys.exit(1)

records = []
for line in RAW.read_text().splitlines():
    line = line.strip()
    if not line:
        continue
    try:
        records.append(json.loads(line))
    except json.JSONDecodeError:
        continue

by_client = defaultdict(list)
for r in records:
    by_client[r["client"]].append(r)

# pick the navigation request (first GET to / or /index.html)
nav = {}
for client, reqs in by_client.items():
    for r in reqs:
        if r["method"] == "GET" and r["path"] in ("/", "/index.html"):
            nav[client] = r
            break
    else:
        # fall back to the first request if no nav captured
        if reqs:
            nav[client] = reqs[0]

# also try to capture an image subresource for Sec-Fetch-Dest=image evidence
img = {}
for client, reqs in by_client.items():
    for r in reqs:
        if r["path"] == "/image.png":
            img[client] = r
            break

PRIMARY = [
    "sec-fetch-site",
    "sec-fetch-mode",
    "sec-fetch-dest",
    "sec-fetch-user",
    "sec-ch-ua",
    "sec-ch-ua-mobile",
    "sec-ch-ua-platform",
]

SECONDARY = [
    "user-agent",
    "accept",
    "accept-language",
    "accept-encoding",
]


def fmt(v):
    if v is None:
        return "—"
    s = str(v)
    if len(s) > 60:
        s = s[:57] + "..."
    return "`" + s.replace("|", "\\|") + "`"


def print_table(title, headers, source):
    print(f"\n### {title}\n")
    cols = ["client"] + headers
    print("| " + " | ".join(cols) + " |")
    print("|" + "|".join(["---"] * len(cols)) + "|")
    for client in sorted(source.keys()):
        h = source[client]["headers"]
        row = [client] + [fmt(h.get(k)) for k in headers]
        print("| " + " | ".join(row) + " |")


print(f"# Sec-Fetch / UA-CH leak matrix\n")
print(f"Captured **{len(records)} requests** across **{len(by_client)} clients**.\n")

print_table("Navigation request — Sec-Fetch & UA Client Hints", PRIMARY, nav)
print_table("Navigation request — Identity headers", SECONDARY, nav)

if img:
    print_table(
        "Image subresource (/image.png) — Sec-Fetch only",
        ["sec-fetch-site", "sec-fetch-mode", "sec-fetch-dest", "sec-fetch-user"],
        img,
    )

print("\n### Per-client request count\n")
for client in sorted(by_client.keys()):
    print(f"- **{client}**: {len(by_client[client])} request(s)")
