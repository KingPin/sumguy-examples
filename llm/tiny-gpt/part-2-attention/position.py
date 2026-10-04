"""Attention has no idea what order its inputs are in. RoPE fixes that.

1. With no position info and no mask, shuffling the tokens just shuffles
   the outputs. Word order is invisible.
2. With a causal mask, the last token still sees its past as an unordered
   bag: "Holmes shot Moriarty." and "Moriarty shot Holmes." give the final
   "." the exact same vector.
3. Rotary position embeddings (RoPE) rotate q and k by an angle that grows
   with position. The score between two tokens then depends only on how far
   apart they are, and the two sentences come apart.
"""

import math
import sys

import torch
import torch.nn as nn
import torch.nn.functional as F

sys.path.insert(0, "../part-1-tokenizer")
from bpe import BPE  # noqa: E402


def rope(x, base: float = 10000.0):
    """Rotate pairs of channels in x (..., T, d) by position-dependent angles."""
    T, d = x.shape[-2], x.shape[-1]
    freqs = base ** (-torch.arange(0, d, 2, dtype=torch.float32) / d)  # (d/2,) fast to slow
    angles = torch.arange(T, dtype=torch.float32)[:, None] * freqs      # (T, d/2)
    cos, sin = angles.cos(), angles.sin()
    x1, x2 = x[..., 0::2], x[..., 1::2]  # channel pairs (0,1), (2,3), ...
    out = torch.stack((x1 * cos - x2 * sin, x1 * sin + x2 * cos), dim=-1)
    return out.flatten(-2)  # interleave the pairs back


def attend(x, wq, wk, wv, causal: bool, use_rope: bool):
    q, k, v = x @ wq, x @ wk, x @ wv
    if use_rope:
        q, k = rope(q), rope(k)  # v is never rotated
    return F.scaled_dot_product_attention(q[None], k[None], v[None], is_causal=causal)[0]


if __name__ == "__main__":
    torch.manual_seed(0)
    tok = BPE.load("../part-1-tokenizer/tokenizer.json")
    d_model, d_head = 256, 64
    emb = nn.Embedding(4096, d_model)
    wq, wk, wv = (torch.randn(d_model, d_head) / math.sqrt(d_model) for _ in range(3))
    torch.set_grad_enabled(False)

    # 1. No mask, no position: a permutation in is the same permutation out.
    x = emb(torch.tensor(tok.encode("Holmes examined the telegram.")))
    perm = torch.tensor([3, 0, 4, 1, 2])
    a = attend(x, wq, wk, wv, causal=False, use_rope=False)
    b = attend(x[perm], wq, wk, wv, causal=False, use_rope=False)
    assert torch.allclose(a[perm], b, atol=1e-6)
    print(f"no position, no mask: shuffle {perm.tolist()} in -> same shuffle out")

    # 2. Causal mask, no position: the last token can't tell who shot whom.
    s1, s2 = " Holmes shot Moriarty.", " Moriarty shot Holmes."
    x1, x2 = emb(torch.tensor(tok.encode(s1))), emb(torch.tensor(tok.encode(s2)))
    for use_rope in (False, True):
        o1 = attend(x1, wq, wk, wv, causal=True, use_rope=use_rope)
        o2 = attend(x2, wq, wk, wv, causal=True, use_rope=use_rope)
        diff = (o1[-1] - o2[-1]).abs().max().item()
        label = "RoPE" if use_rope else "no position"
        print(f"{label:>11}: max difference in final '.' vector = {diff:.6f}")
        if not use_rope:
            assert torch.allclose(o1[-1], o2[-1], atol=1e-6)
        else:
            assert diff > 1e-3

    # 3. RoPE scores depend on distance, not absolute position.
    q, k = torch.randn(1, d_head), torch.randn(1, d_head)
    def score(qpos, kpos, T=600):
        Q = torch.zeros(T, d_head); Q[qpos] = q
        K = torch.zeros(T, d_head); K[kpos] = k
        return (rope(Q)[qpos] @ rope(K)[kpos]).item()
    pairs = [(10, 3), (110, 103), (507, 500)]  # all 7 apart
    scores = [score(m, n) for m, n in pairs]
    assert all(math.isclose(s, scores[0], rel_tol=1e-4, abs_tol=1e-4) for s in scores)
    print("RoPE score for 7 tokens apart at positions " +
          ", ".join(f"({m},{n})={s:+.4f}" for (m, n), s in zip(pairs, scores)))
    print(f"RoPE score for 1 token apart at (10,9) = {score(10, 9):+.4f}")
    # Rotation keeps length, so RoPE never changes a vector's size.
    assert torch.allclose(rope(x1[None]).norm(dim=-1), x1[None].norm(dim=-1), atol=1e-4)
    print("all position checks passed")
