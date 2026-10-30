#!/usr/bin/env python3
"""Self-checks for summarize.py and tune_split.py. Run: python3 test_tools.py"""
import contextlib, io, json, os, tempfile

import summarize as S
import tune_split as T


def run(status="ok", **metrics):
    return {"status": status, "dur_s": 30, "step_s": 20, "ramp_iters": [100, 1000],
            "k6": {k: {"values": v} for k, v in metrics.items()}}


def step(i, reqs, ok, p99, dropped=None):
    s = f"step{i + 1:02d}"
    m = {S.key("http_reqs", s): {"count": reqs}, S.key("http_reqs", s, ok=True): {"count": ok},
         S.key("http_req_duration", s, ok=True): {"p(99)": p99}}
    if dropped is not None:
        m[S.key("dropped_iterations", s)] = {"count": dropped}
    return m


def test_step_rate_rounds_half_up():
    assert S.step_rate(0.5, 0.5, 0) == 1          # Python round() would give 0
    assert S.step_rate(100, 1000, 1) == 200
    assert [S.step_rate(100, 1000, i) for i in (0, 9)] == [100, 1000]


def test_missing_dropped_counts_as_zero():
    assert S.step_passes(run(**step(0, 2100, 2100, 12.0)), 0)


def test_step_fail_rules():
    assert not S.step_passes(run(**step(0, 2000, 1997, 12.0)), 0)             # 0.15% errors
    assert not S.step_passes(run(**step(0, 2100, 2100, 50.0)), 0)             # p99 not under 50 ms
    assert not S.step_passes(run(**step(0, 2100, 2100, 12.0, dropped=2)), 0)  # 2 of 2000 scheduled = 0.1%
    assert not S.step_passes(run(), 0)                                         # no requests at all
    m = step(0, 2100, 2100, 12.0)
    del m[S.key("http_req_duration", "step01", ok=True)]
    assert not S.step_passes(run(**m), 0)                                      # missing p99 is not 0 ms


def test_all_steps_pass_is_lower_bound():
    m = {k: v for i in range(10) for k, v in step(i, 2100, 2100, 10.0).items()}
    assert S.all_pass(run(**m)) and not S.all_pass(run(**step(0, 2100, 2100, 10.0)))


def test_ncpus():
    assert S.ncpus("3,4,5,11-13") == 6 and S.ncpus("0-3") == 4


def test_capacity_stops_at_first_failure():
    m = {**step(0, 2100, 2100, 10.0), **step(1, 4200, 4200, 60.0), **step(2, 6300, 6300, 10.0)}
    assert S.capacity(run(**m)) == 2100 / 20


def test_load_skips_bad_runs():
    with tempfile.TemporaryDirectory() as root:
        d = os.path.join(root, "matrix", "micro")
        os.makedirs(d)
        for name, status in [("mix-max-r1.json", "ok"), ("mix-max-r2.json", "noisy"),
                             ("mix-max-r3.json", "ok"), ("mix-max-r2.noisy.json", "ok")]:
            json.dump({"status": status}, open(os.path.join(d, name), "w"))
        runs = S.load(root, "matrix", "micro", "mix-max")
        assert len(runs) == 2
        assert S.cell([1.0, 2.0]) == "incomplete (2/3)"


def test_pools_reads_ok_runs_only():
    with tempfile.TemporaryDirectory() as root:
        d = os.path.join(root, "matrix", "monolith")
        os.makedirs(d)
        for r, status in [(1, "ok"), (2, "noisy")]:
            json.dump({"status": status, "run": r}, open(os.path.join(d, f"mix-max-r{r}.json"), "w"))
            logs = os.path.join(root, "logs", "matrix", "monolith", f"mix-max-r{r}")
            os.makedirs(logs)
            open(os.path.join(logs, "monolith.log"), "w").write(
                f"2026/10/30 01:00:00 pool shop: max=30 acquires=900 empty_acquires={r * 10} acquire_ms=5\n")
        assert S.pools(root, "matrix", "monolith", "mix-max") == {"shop": [[30, 900, 10, 5]]}


def test_verdict():
    assert S.verdict([100, 101, 102], [104, 105, 106], ("monolith", "micro")) == "micro by 4%"
    assert S.verdict([100, 104, 102], [103, 104, 105], ("monolith", "micro")) == "tie"
    assert S.verdict([10, 10, 10], [20, 20, 20], ("monolith", "micro"), higher_better=False) == "monolith by 100%"
    assert S.verdict([1, 2], [3, 4, 5], ("a", "b")) == "n/a"
    assert S.verdict([0, 0, 0], [100, 100, 100], ("monolith", "micro")) == "micro (monolith at 0)"
    assert S.verdict([0, 0, 0], [0, 0, 0], ("monolith", "micro")) == "tie"


def test_knee():
    assert S.knee({16: 100, 32: 180, 64: 196, 128: 200, 256: 199}) == 64


def test_split():
    q = T.split({"gateway": 0.5, "catalog": 0.3, "cart": 0.18, "orders": 0.02}, 2)
    assert q == {"gateway": 0.9, "catalog": 0.6, "cart": 0.4, "orders": 0.1}, q
    q = T.split({"gateway": 0.28, "catalog": 0.28, "cart": 0.28, "orders": 0.16}, 2)
    assert q == {"gateway": 0.5, "catalog": 0.6, "cart": 0.6, "orders": 0.3}, q   # tie -> gateway gives
    for b in (2, 4):
        q = T.split({"gateway": 0.97, "catalog": 0.01, "cart": 0.01, "orders": 0.01}, b)
        assert round(sum(q.values()), 6) == b and min(q.values()) >= 0.1, q


def test_shares_rejects_zero_cpu():
    zero = {"cpu_s": {s: 0.0 for s in T.SVCS}}
    try:
        T.shares([zero, zero, zero])
    except SystemExit:
        return
    raise AssertionError("zero app CPU must exit")


def test_report_incomplete_and_lower_bound():
    with tempfile.TemporaryDirectory() as root:
        for dsg, n in (("monolith", 3), ("micro", 2)):   # micro ramp has only 2 ok runs
            d = os.path.join(root, "matrix", dsg)
            os.makedirs(d)
            for r in range(1, n + 1):
                m = {k: v for i in range(10) for k, v in step(i, 2100, 2100, 10.0).items()}
                json.dump({**run(**m), "run": r}, open(os.path.join(d, f"mix-ramp-r{r}.json"), "w"))
        open(os.path.join(root, "matrix", "env.txt"), "w").write(
            "image mvm-monolith:bench 100 id\nimage mvm-gateway:bench 1 a\nimage mvm-catalog:bench 1 b\n"
            "image mvm-cart:bench 1 c\nimage mvm-orders:bench 1 d\n")
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            S.report(root)
        out = buf.getvalue()
        assert "| monolith | incomplete (0/1) |" in out        # no sustained run
        assert "incomplete (phase not run)" in out              # no scaling phase
        assert "| micro | incomplete (2/3)" in out              # ramp capacity, 2 ok runs
        assert "incomplete (2/3) |" in out.split("| step |")[1]  # per-step table cell
        assert "(lower bound: a run passed all 10 steps)" in out


if __name__ == "__main__":
    for name, fn in list(globals().items()):
        if name.startswith("test_"):
            fn()
    print("all checks passed")
