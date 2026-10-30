#!/usr/bin/env python3
"""Median Markdown tables from a results directory. Counts only 2xx responses and status=ok runs.
Usage: summarize.py results-YYYY-MM-DD             all tables
       summarize.py calibrate results-YYYY-MM-DD   VUS and rates for bench.env, from the sweep phase"""
import glob, json, math, os, re, statistics, sys

REQ_PER_ITER = 1.05  # mix: 0.80 + 0.15 + 0.05 * 2
RUNS = 3
DESIGNS = ["monolith", "micro"]
APP = {"monolith": ["monolith"], "micro": ["gateway", "catalog", "cart", "orders"],
       "mono": ["monolith"], "micro-even": ["gateway", "catalog", "cart", "orders"],
       "micro-tuned": ["gateway", "catalog", "cart", "orders"]}
MAX_SCEN = ["browse-max", "cart-max", "checkout-max", "mix-max"]


def key(metric, scenario, route=None, ok=False):
    """Submetric name exactly as k6/shop.js declares it: scenario, route, expected_response."""
    tags = [f"scenario:{scenario}"] + ([f"route:{route}"] if route else []) + (["expected_response:true"] if ok else [])
    return f"{metric}{{{','.join(tags)}}}"


def val(d, name, field, default=0):
    """A k6 summary value; a submetric that is missing or has no samples counts as default.
    Counts default to 0 (no dropped iterations is an empty submetric); latencies use inf."""
    return d["k6"].get(name, {}).get("values", {}).get(field, default)


def step_rate(lo, hi, i):
    """Same as Math.round in k6/shop.js: halves round up (Python's round() rounds half to even)."""
    return math.floor(lo + (hi - lo) * i / 9 + 0.5)


def load(root, phase, config, scenario):
    """status=ok runs only. The -r<digit>.json glob also skips renamed *.noisy.json / *.failed.json files."""
    runs = [json.load(open(f)) for f in sorted(glob.glob(f"{root}/{phase}/{config}/{scenario}-r[0-9].json"))]
    return [d for d in runs if d["status"] == "ok"]


def med(xs):
    return statistics.median(xs)


def cell(xs, fmt="{:,.0f}"):
    """Median [min-max] of RUNS ok runs, or 'incomplete (n/RUNS)'."""
    if len(xs) < RUNS:
        return f"incomplete ({len(xs)}/{RUNS})"
    return f"{fmt.format(med(xs))} [{fmt.format(min(xs))}-{fmt.format(max(xs))}]"


def ok_rps(d, scenario="main", route=None, secs=None):
    return val(d, key("http_reqs", scenario, route, ok=True), "count") / (secs or d["dur_s"])


def errors(d, scenario="main"):
    return val(d, key("http_reqs", scenario), "count") - val(d, key("http_reqs", scenario, ok=True), "count")


def p(d, q, scenario="main", route=None):
    """A missing latency is inf, so it fails every gate and shows up in the tables."""
    return val(d, key("http_req_duration", scenario, route, ok=True), q, math.inf)


def cpu_per_1k(d, names):
    ok = val(d, key("http_reqs", "main", ok=True), "count")
    return sum(d["cpu_s"][n] for n in names) / ok * 1000 if ok else float("nan")


def verdict(a, b, names, higher_better=True):
    """Winner and margin, or 'tie' when the medians differ by less than the larger run spread."""
    if len(a) < RUNS or len(b) < RUNS:
        return "n/a"
    ma, mb = med(a), med(b)
    if ma == mb or abs(ma - mb) < max(max(a) - min(a), max(b) - min(b)):
        return "tie"
    a_wins = (ma > mb) == higher_better
    win, lose = (names[0], names[1]) if a_wins else (names[1], names[0])
    if min(ma, mb) == 0:  # a capacity of 0 (step 1 failed) has no percentage
        return f"{win} ({lose} at 0)"
    return f"{win} by {abs(ma - mb) / min(ma, mb) * 100:.0f}%"


def step_passes(d, i):
    s = f"step{i + 1:02d}"
    reqs = val(d, key("http_reqs", s), "count")
    ok = val(d, key("http_reqs", s, ok=True), "count")
    sched = max(1, step_rate(*d["ramp_iters"], i) * d["step_s"])
    dropped = val(d, key("dropped_iterations", s), "count")
    return reqs > 0 and p(d, "p(99)", s) < 50 and (reqs - ok) / reqs < 0.001 and dropped / sched < 0.001


def capacity(d):
    """2xx req/s of the highest step that passes with every lower step passing; 0 if step 1 fails."""
    cap = 0.0
    for i in range(10):
        if not step_passes(d, i):
            break
        cap = ok_rps(d, f"step{i + 1:02d}", secs=d["step_s"])
    return cap


def all_pass(d):
    """Every ramp step passed: the capacity is a lower bound, not a ceiling."""
    return all(step_passes(d, i) for i in range(10))


def ncpus(cpuset):
    """CPU count of a cpuset list such as '3,4,5,11-13'."""
    n = 0
    for part in cpuset.split(","):
        lo, _, hi = part.partition("-")
        n += int(hi or lo) - int(lo) + 1
    return n


def pools(root, ph, config, scenario):
    """pgxpool counters [max, acquires, empty_acquires, acquire_ms] per pool, one list per ok run.
    They come from each service's shutdown log line, so they cover the warm-up and the measured run."""
    out = {}
    for d in load(root, ph, config, scenario):
        for f in glob.glob(f"{root}/logs/{ph}/{config}/{scenario}-r{d['run']}/*.log"):
            for m in re.finditer(r"pool (\w+): max=(\d+) acquires=(\d+) empty_acquires=(\d+) acquire_ms=(\d+)", open(f).read()):
                out.setdefault(m[1], []).append([int(x) for x in m.groups()[1:]])
    return out


def knee(points):
    """Lowest VU count within 5% of the best throughput. points: {vus: req/s}."""
    best = max(points.values())
    return min(v for v, r in points.items() if r >= 0.95 * best)


def calibrate(root):
    pts, runs = {}, {}
    for dsg in DESIGNS:
        pts[dsg] = {}
        for f in glob.glob(f"{root}/sweep/{dsg}/mix-max-v*-r1.json"):
            d = json.load(open(f))
            if d["status"] != "ok":
                sys.exit(f"{f} is {d['status']}; re-run the sweep")
            pts[dsg][d["vus"]] = ok_rps(d)
            runs[(dsg, d["vus"])] = d
    n = max(knee(pts[dsg]) for dsg in DESIGNS)
    thr = pts["monolith"][n]
    # Thresholds follow the split this sweep ran with (risk 1 may have moved a core to Postgres).
    cpus = dict(kv.split("=") for kv in next(l for l in open(f"{root}/sweep/env.txt") if l.startswith("cpus:")).split()[1:])
    k6n, pgn = ncpus(cpus["k6"]), ncpus(cpus["pg"])
    for dsg in DESIGNS:
        kd, d = knee(pts[dsg]), runs[(dsg, n)]
        k6 = max(runs[(dsg, v)]["k6_cores"] for v in pts[dsg] if v <= kd)  # risk 2: before this design's knee
        pg = d["cpu_s"]["pg"] / d["wall_s"]
        print(f"# {dsg}: knee {kd} VUs; at {n} VUs {ok_rps(d):,.0f} req/s, pg {pg:.2f} cores; k6 up to the knee {k6:.2f} cores")
        if k6 > 0.8 * k6n:
            print(f"# WARN {dsg}: k6 above 80% of {k6n} CPUs before the knee (spec risk 2)")
        if pg > 0.9 * pgn:
            print(f"# WARN {dsg}: Postgres above 90% of {pgn} CPUs (spec risk 1)")
    print(f"VUS={n}")
    print(f"FIXED_RATE={math.floor(0.5 * thr / REQ_PER_ITER + 0.5)}")
    print(f"RAMP_LO={math.floor(0.2 * thr / REQ_PER_ITER + 0.5)}")
    print(f"RAMP_HI={math.floor(1.5 * thr / REQ_PER_ITER + 0.5)}")


def images(root, phase):
    """Image bytes per design from env.txt lines 'image mvm-<svc>:bench <bytes> <id>'."""
    sizes = {}
    for line in open(f"{root}/{phase}/env.txt"):
        f = line.split()
        if len(f) >= 3 and f[0] == "image" and f[1].startswith("mvm-"):
            sizes[f[1][4:].split(":")[0]] = int(f[2])
    return {"monolith": sizes["monolith"], "micro": sum(sizes[s] for s in APP["micro"])}


def report(root):
    ph = "matrix"
    print("## Throughput at fixed concurrency (closed loop, median [min-max] of 3 runs)\n")
    print("| scenario | design | 2xx req/s | p99 ms | app CPU-s / 1k | Postgres CPU-s / 1k | non-2xx | k6 cores | verdict |")
    print("|---|---|---|---|---|---|---|---|---|")
    for sc in MAX_SCEN:
        rps = {}
        for dsg in DESIGNS:
            runs = load(root, ph, dsg, sc)
            rps[dsg] = [ok_rps(d) for d in runs]
            v = verdict(rps["monolith"], rps["micro"], DESIGNS) if dsg == "micro" else ""
            print(f"| {sc} | {dsg} | {cell(rps[dsg])} | {cell([p(d, 'p(99)') for d in runs], '{:.1f}')} "
                  f"| {cell([cpu_per_1k(d, APP[dsg]) for d in runs], '{:.2f}')} | {cell([cpu_per_1k(d, ['pg']) for d in runs], '{:.2f}')} "
                  f"| {sum(errors(d) for d in runs)} | {cell([d['k6_cores'] for d in runs], '{:.2f}')} | {v} |")
    print("\ncheckout-max completed checkouts/s: " + ", ".join(
        f"{dsg} {cell([ok_rps(d, route='checkout') for d in load(root, ph, dsg, 'checkout-max')])}" for dsg in DESIGNS))

    print("\n## Latency at equal load (mix-fixed)\n")
    print("| design | 2xx req/s | p50 ms | p95 ms | p99 ms | non-2xx | verdict (p99) |")
    print("|---|---|---|---|---|---|---|")
    p99 = {}
    for dsg in DESIGNS:
        runs = load(root, ph, dsg, "mix-fixed")
        p99[dsg] = [p(d, "p(99)") for d in runs]
        v = verdict(p99["monolith"], p99["micro"], DESIGNS, higher_better=False) if dsg == "micro" else ""
        print(f"| {dsg} | {cell([ok_rps(d) for d in runs])} | {cell([p(d, 'p(50)') for d in runs], '{:.2f}')} "
              f"| {cell([p(d, 'p(95)') for d in runs], '{:.2f}')} | {cell(p99[dsg], '{:.2f}')} | {sum(errors(d) for d in runs)} | {v} |")

    print_capacity(root, ph, DESIGNS)

    print("\n## Memory (cgroup, MiB, mix-max) and image size\n")
    print("| design | idle | peak | images MiB |")
    print("|---|---|---|---|")
    img = images(root, ph)
    for dsg in DESIGNS:
        runs = load(root, ph, dsg, "mix-max")
        print(f"| {dsg} | {cell([d['mem_idle_bytes'] / 2**20 for d in runs], '{:.1f}')} "
              f"| {cell([d['mem_peak_bytes'] / 2**20 for d in runs], '{:.1f}')} | {img[dsg] / 2**20:.1f} |")

    print("\n## Sustained (mix-sustained, 90 s, one run)\n")
    print("| design | 2xx req/s | p99 ms | non-2xx | peak MiB |")
    print("|---|---|---|---|---|")
    for dsg in DESIGNS:
        runs = load(root, ph, dsg, "mix-sustained")
        if not runs:
            print(f"| {dsg} | incomplete (0/1) | | | |")
            continue
        d = runs[0]
        print(f"| {dsg} | {ok_rps(d):,.0f} | {p(d, 'p(99)'):.1f} | {errors(d)} | {d['mem_peak_bytes'] / 2**20:.1f} |")

    print("\n## Pool waits (pgxpool at shutdown: warm-up + measured run, median of ok runs)\n")
    print("| scenario | design | pool | max | acquires | empty acquires | acquire ms |")
    print("|---|---|---|---|---|---|---|")
    for sc in ("mix-max", "checkout-max"):
        for dsg in DESIGNS:
            for name, rows in sorted(pools(root, ph, dsg, sc).items()):
                print(f"| {sc} | {dsg} | {name} | " + " | ".join(f"{med([r[i] for r in rows]):,.0f}" for i in range(4)) + " |")

    for b in (2, 4):
        ph = f"scaling-B{b}"
        if not os.path.isdir(f"{root}/{ph}"):
            print(f"\n## CPU-quota allocation, budget B = {b}\n\nincomplete (phase not run)")
            continue
        cfgs = ["mono", "micro-even", "micro-tuned"]
        print(f"\n## CPU-quota allocation, budget B = {b} (mix-max)\n")
        print("| config | 2xx req/s | p99 ms | app CPU-s / 1k | throttled s | verdict vs mono |")
        print("|---|---|---|---|---|---|")
        base = [ok_rps(d) for d in load(root, ph, "mono", "mix-max")]
        for c in cfgs:
            runs = load(root, ph, c, "mix-max")
            rps = [ok_rps(d) for d in runs]
            v = verdict(base, rps, ("mono", c)) if c != "mono" else ""
            print(f"| {c} | {cell(rps)} | {cell([p(d, 'p(99)') for d in runs], '{:.1f}')} "
                  f"| {cell([cpu_per_1k(d, APP[c]) for d in runs], '{:.2f}')} "
                  f"| {cell([sum(d['throttled_s'][s] for s in APP[c]) for d in runs], '{:.1f}')} | {v} |")
        if b == 4:
            print_capacity(root, ph, cfgs)

    for ph in ("matrix", "scaling-B2", "scaling-B4"):
        if os.path.exists(f"{root}/{ph}/env.txt"):
            print(f"\n## Environment ({ph})\n\n```text\n" + open(f"{root}/{ph}/env.txt").read() + "```")


def print_capacity(root, ph, configs):
    print(f"\n## Load capacity ({ph}, mix-ramp): p99 < 50 ms, non-2xx < 0.1%, dropped < 0.1%\n")
    print("| config | capacity, 2xx req/s | verdict |")
    print("|---|---|---|")
    ramp = {c: load(root, ph, c, "mix-ramp") for c in configs}
    caps = {c: [capacity(d) for d in ramp[c]] for c in configs}
    for c in configs:
        v = verdict(caps[configs[0]], caps[c], (configs[0], c)) if c != configs[0] else ""
        lb = " (lower bound: a run passed all 10 steps)" if any(all_pass(d) for d in ramp[c]) else ""
        print(f"| {c} | {cell(caps[c])}{lb} | {v} |")
    print("\n| step | offered iter/s | " + " | ".join(f"{c} p99 ms / non-2xx % / dropped %" for c in configs) + " |")
    print("|---|---|" + "---|" * len(configs))
    for i in range(10):
        s, cols, offered = f"step{i + 1:02d}", [], "?"
        for c in configs:
            runs = ramp[c]
            if runs:
                offered = step_rate(*runs[0]["ramp_iters"], i)
            if len(runs) < RUNS:
                cols.append(f"incomplete ({len(runs)}/{RUNS})")
                continue
            sched = max(1, offered * runs[0]["step_s"])
            err = [100 * (val(d, key("http_reqs", s), "count") - val(d, key("http_reqs", s, ok=True), "count"))
                   / max(1, val(d, key("http_reqs", s), "count")) for d in runs]
            drop = [100 * val(d, key("dropped_iterations", s), "count") / sched for d in runs]
            cols.append(f"{med([p(d, 'p(99)', s) for d in runs]):.1f} / {med(err):.2f} / {med(drop):.2f}")
        print(f"| {s} | {offered} | " + " | ".join(cols) + " |")


if __name__ == "__main__":
    if sys.argv[1] == "calibrate":
        calibrate(sys.argv[2])
    else:
        report(sys.argv[1])
