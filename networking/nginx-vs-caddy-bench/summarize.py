#!/usr/bin/env python3
"""Print median results from results/ as Markdown tables."""
import glob, json, os, statistics as st

import sys
R = sys.argv[1] if len(sys.argv) > 1 else "results"
SERVERS = ["nginx", "nginx-upstream", "nginx-keepalive", "caddy", "caddy-keepalive"]
SCEN = ["static-http", "static-https", "big-http", "big-https", "newconn-https", "proxy-https", "proxy-fixed"]

def load(s, sc):
    return [json.load(open(f)) for f in sorted(glob.glob(f"{R}/{s}/{sc}-*.json"))]

def errors(d):
    """Client-side errors (excluding requests cut off by the test deadline) plus non-2xx responses."""
    client = sum(v for k, v in (d.get("errorDistribution") or {}).items() if "deadline" not in k)
    return client + sum(v for k, v in d["statusCodeDistribution"].items() if not k.startswith("2"))

def ok_rps(d):
    """Successful (2xx) responses per second. oha's requestsPerSec counts 502s too."""
    return sum(v for k, v in d["statusCodeDistribution"].items() if k.startswith("2")) / d["summary"]["total"]

def med(xs):
    return st.median(xs) if xs else None

print(f"## Throughput (median of runs, min-max in brackets)\n")
print("| scenario | server | ok req/s | p99 ms | server cores | loadgen cores | backend cores | failed requests |")
print("|---|---|---|---|---|---|---|---|")
for sc in SCEN:
    for s in SERVERS:
        runs = load(s, sc)
        if not runs:
            continue
        rps = [ok_rps(d) for d in runs]
        p99 = [d["latencyPercentiles"]["p99"] * 1000 for d in runs]
        h = lambda k: med([d["_host"][k] for d in runs])
        print(f"| {sc} | {s} | {med(rps):,.0f} [{min(rps):,.0f}-{max(rps):,.0f}] | {med(p99):.1f} "
              f"| {h('server_cores'):.2f} | {h('loadgen_cores'):.2f} | {h('backend_cores'):.2f} "
              f"| {sum(errors(d) for d in runs)} |")

print("\n## Fixed-rate proxy latency (proxy-fixed)\n")
print("| server | ok req/s | p50 ms | p90 ms | p99 ms | p99.9 ms | server cores | failed requests |")
print("|---|---|---|---|---|---|---|")
for s in SERVERS:
    runs = load(s, "proxy-fixed")
    if not runs:
        continue
    g = lambda k: med([d["latencyPercentiles"][k] * 1000 for d in runs])
    print(f"| {s} | {med([ok_rps(d) for d in runs]):,.0f} | {g('p50'):.2f} | {g('p90'):.2f} "
          f"| {g('p99'):.2f} | {g('p99.9'):.2f} | {med([d['_host']['server_cores'] for d in runs]):.2f} "
          f"| {sum(errors(d) for d in runs)} |")

print("\n## Sustained proxy, 90 s at full load\n")
print("| server | ok req/s | p99 ms | failed requests | TIME_WAIT at 20/40/60/80 s |")
print("|---|---|---|---|---|")
for s in SERVERS:
    f = f"{R}/{s}/proxy-sustained.json"
    if not os.path.exists(f):
        continue
    d = json.load(open(f))
    tw = open(f"{R}/{s}/proxy-sustained-timewait").read().split()
    print(f"| {s} | {ok_rps(d):,.0f} | {d['latencyPercentiles']['p99'] * 1000:.1f} | {errors(d)} | {' / '.join(tw)} |")

print("\n## Memory (cgroup, MiB)\n")
print("| server | idle | peak |")
print("|---|---|---|")
for s in SERVERS:
    try:
        idle = int(open(f"{R}/{s}/idle_mem_bytes").read()) / 2**20
        peak = int(open(f"{R}/{s}/peak_mem_bytes").read()) / 2**20
        print(f"| {s} | {idle:.1f} | {peak:.1f} |")
    except FileNotFoundError:
        pass

if os.path.exists(f"{R}/env.txt"):
    print("\n## Environment\n\n```text\n" + open(f"{R}/env.txt").read() + "```")
