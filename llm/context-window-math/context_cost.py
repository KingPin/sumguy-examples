#!/usr/bin/env python3
"""Simulate what an N-turn chat or agent loop costs when every call re-sends the history."""
import argparse


def simulate(turns, system, per_turn, out, in_price, out_price, read_mult, write_mult):
    """Return per-turn input sizes plus cumulative tokens and costs ($ per MTok prices)."""
    sizes, cached = [], 0  # cached = prefix tokens already in the cache
    cost_plain = cost_cache = total_in = 0.0
    for t in range(1, turns + 1):
        # input of turn t = system + all earlier (user+assistant) turns + this turn's new user part
        size = system + (t - 1) * per_turn + (per_turn - out)
        sizes.append(size)
        total_in += size
        cost_plain += size * in_price / 1e6
        # cache hit on the prefix from last call, write premium on the new tail
        hit, new = min(cached, size), size - min(cached, size)
        cost_cache += (hit * read_mult + new * write_mult) * in_price / 1e6
        cached = size  # the reply was generated, not cached: next call writes it
    out_cost = turns * out * out_price / 1e6
    return sizes, total_in, cost_plain + out_cost, cost_cache + out_cost


def closed_form(turns, system, per_turn, out):
    """Same sum, no loop: arithmetic series."""
    new = per_turn - out
    return turns * (system + new) + per_turn * turns * (turns - 1) // 2


def selftest():
    for n in (1, 5, 50, 200):
        _, got, _, _ = simulate(n, 3000, 700, 300, 1, 1, 1, 1)
        assert got == closed_form(n, 3000, 700, 300), n
    _, _, plain, cached = simulate(30, 3000, 700, 300, 2, 10, 1, 1)
    assert abs(plain - cached) < 1e-9  # multipliers of 1 mean caching changes nothing
    # by hand: turn 1 writes 1,050; turn 2 reads those 1,050 at 0.1 and writes 50 reply + 50 new
    _, _, _, cached = simulate(2, 1000, 100, 50, 1e6, 0, 0.1, 1)
    assert abs(cached - (1050 + 105 + 100)) < 1e-6, cached
    print("selftest ok")


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--turns", type=int, default=50)
    p.add_argument("--system", type=int, default=3000, help="system prompt + tool tokens")
    p.add_argument("--per-turn", type=int, default=700, help="tokens added per turn (user + assistant)")
    p.add_argument("--out", type=int, default=300, help="output tokens per turn (part of per-turn)")
    p.add_argument("--in-price", type=float, default=2.0, help="input $/MTok")
    p.add_argument("--out-price", type=float, default=10.0, help="output $/MTok")
    p.add_argument("--read-mult", type=float, default=0.05, help="cache read multiplier")
    p.add_argument("--write-mult", type=float, default=1.25, help="cache write multiplier")
    p.add_argument("--selftest", action="store_true")
    a = p.parse_args()
    if a.selftest:
        return selftest()
    sizes, tin, plain, cached = simulate(a.turns, a.system, a.per_turn, a.out,
                                         a.in_price, a.out_price, a.read_mult, a.write_mult)
    print(f"turns={a.turns}  first input={sizes[0]:,}  last input={sizes[-1]:,} tokens")
    print(f"cumulative input tokens: {tin:,.0f}")
    print(f"cost, no caching:   ${plain:,.4f}")
    print(f"cost, with caching: ${cached:,.4f}  ({cached / plain:.0%} of uncached)")
    step = max(1, a.turns // 5)
    for t in range(step, a.turns + 1, step):
        print(f"  turn {t:>4}: sends {sizes[t - 1]:>9,} input tokens")


if __name__ == "__main__":
    main()
