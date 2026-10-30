#!/usr/bin/env python3
"""Write tuned-B2.env and tuned-B4.env from the matrix micro mix-max runs.
Usage: tune_split.py results-YYYY-MM-DD"""
import glob, json, statistics, sys

SVCS = ["gateway", "catalog", "cart", "orders"]  # also the tie-break order


def shares(runs):
    """Median over runs of each service's share of app CPU."""
    if len(runs) != 3:
        sys.exit(f"need 3 ok micro mix-max runs, found {len(runs)}")
    per = {s: [] for s in SVCS}
    for d in runs:
        total = sum(d["cpu_s"][s] for s in SVCS)
        if total <= 0:
            sys.exit("a run has zero app CPU")
        for s in SVCS:
            per[s].append(d["cpu_s"][s] / total)
    return {s: statistics.median(v) for s, v in per.items()}


def split(share, b):
    """Quotas in 0.1 CPU steps: at least 0.1 each (Docker reads 0 as no limit), sum exactly b.
    The difference goes to or comes from the largest quota; ties go to the earliest in SVCS."""
    q = {s: max(1, int(b * 10 * share[s] + 0.5)) for s in SVCS}
    diff = b * 10 - sum(q.values())
    while diff:
        big = max(SVCS, key=lambda s: (q[s], -SVCS.index(s)))
        step = 1 if diff > 0 else -1
        if q[big] + step < 1:
            sys.exit("budget too small for a 0.1 floor on every service")
        q[big] += step
        diff -= step
    return {s: v / 10 for s, v in q.items()}


if __name__ == "__main__":
    files = sorted(glob.glob(f"{sys.argv[1]}/matrix/micro/mix-max-r[0-9].json"))
    runs = [d for d in map(lambda f: json.load(open(f)), files) if d["status"] == "ok"]
    sh = shares(runs)
    for b in (2, 4):
        q = split(sh, b)
        with open(f"tuned-B{b}.env", "w") as f:
            f.write(f"# from {sys.argv[1]} matrix micro mix-max, shares {json.dumps({s: round(v, 4) for s, v in sh.items()})}\n")
            f.writelines(f"Q_{s.upper()}={v:.1f}\n" for s, v in q.items())
        print(f"B={b}: {q}")
