#!/usr/bin/env python3
"""KV cache size: 2 (K and V) x layers x kv_heads x head_dim x bytes x tokens x slots."""
import argparse
import json


def kv_bytes(layers, kv_heads, head_dim, ctx, dtype_bytes=2.0, slots=1):
    return 2 * layers * kv_heads * head_dim * dtype_bytes * ctx * slots


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--config", help="path to a HuggingFace config.json (fills layers/heads/head-dim)")
    p.add_argument("--layers", type=int)
    p.add_argument("--kv-heads", type=int)
    p.add_argument("--head-dim", type=int)
    p.add_argument("--ctx", type=int, default=32768, help="context length per sequence")
    p.add_argument("--dtype-bytes", type=float, default=2.0, help="f16=2, q8_0~1.0625, q4_0~0.5625")
    p.add_argument("--slots", type=int, default=1, help="parallel sequences")
    a = p.parse_args()
    if a.config:
        c = json.load(open(a.config))
        c = c.get("text_config", c)
        a.layers = a.layers or c["num_hidden_layers"]
        a.kv_heads = a.kv_heads or c["num_key_value_heads"]
        a.head_dim = a.head_dim or c.get("head_dim") or c["hidden_size"] // c["num_attention_heads"]
    if not (a.layers and a.kv_heads and a.head_dim):
        p.error("give --config or all of --layers --kv-heads --head-dim")
    per_tok = kv_bytes(a.layers, a.kv_heads, a.head_dim, 1, a.dtype_bytes)
    total = kv_bytes(a.layers, a.kv_heads, a.head_dim, a.ctx, a.dtype_bytes, a.slots)
    print(f"per token: {per_tok / 1024:.1f} KiB")
    print(f"ctx={a.ctx:,} x slots={a.slots}: {total / 2**30:.2f} GiB")


if __name__ == "__main__":
    main()
