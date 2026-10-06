#!/usr/bin/env python3
"""Print median results from results/results.csv as Markdown tables."""
import csv, os, statistics as st, sys
from collections import defaultdict

R = sys.argv[1] if len(sys.argv) > 1 else "results"
MIB = 2**20
runs = defaultdict(list)
order = []
for row in csv.DictReader(open(f"{R}/results.csv")):
    k = (row["dataset"], row["config"])
    if k not in runs:
        order.append(k)
    runs[k].append(row)

def med(rows, col):
    return st.median(float(r[col]) for r in rows)

for ds in dict.fromkeys(d for d, _ in order):
    print(f"## {ds}\n")
    print("| config | threads | ratio | compress MiB/s | decompress MiB/s | compress RSS MiB | decompress RSS MiB | compress s (min-max) |")
    print("|---|---|---|---|---|---|---|---|")
    for d, c in order:
        if d != ds:
            continue
        rs = runs[(d, c)]
        size = int(rs[0]["in_bytes"])
        cs = [float(r["comp_s"]) for r in rs]
        print(f"| {c} | {rs[0]['threads']} | {size / int(rs[0]['out_bytes']):.3f} "
              f"| {size / MIB / med(rs, 'comp_s'):,.1f} | {size / MIB / med(rs, 'decomp_s'):,.1f} "
              f"| {med(rs, 'comp_rss_kib') / 1024:.1f} | {med(rs, 'decomp_rss_kib') / 1024:.1f} "
              f"| {st.median(cs):.2f} ({min(cs):.2f}-{max(cs):.2f}) |")
    print()

if os.path.exists(f"{R}/env.txt"):
    print("## Environment\n\n```text\n" + open(f"{R}/env.txt").read() + "```")
