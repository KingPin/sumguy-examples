"""Causal self-attention by hand, checked against PyTorch's fused kernel.

One head first, every step spelled out. Then the multi-head version that
Part 3's model will use. Both are asserted equal to
torch.nn.functional.scaled_dot_product_attention.
"""

import math
import sys

import torch
import torch.nn as nn
import torch.nn.functional as F

sys.path.insert(0, "../part-1-tokenizer")
from bpe import BPE  # noqa: E402


def one_head(x, wq, wk, wv):
    """x: (T, d). Returns (T, d_head) plus the attention weights (T, T)."""
    q, k, v = x @ wq, x @ wk, x @ wv          # each (T, d_head)
    scores = q @ k.T / math.sqrt(q.shape[-1])  # (T, T): how much token i cares about token j
    T = x.shape[0]
    future = torch.triu(torch.ones(T, T, dtype=torch.bool), diagonal=1)
    scores = scores.masked_fill(future, float("-inf"))  # no peeking ahead
    weights = scores.softmax(dim=-1)           # each row sums to 1
    return weights @ v, weights


class MultiHeadAttention(nn.Module):
    def __init__(self, d_model: int, n_heads: int):
        super().__init__()
        assert d_model % n_heads == 0
        self.n_heads = n_heads
        self.qkv = nn.Linear(d_model, 3 * d_model, bias=False)  # all heads, one matmul
        self.out = nn.Linear(d_model, d_model, bias=False)

    def forward(self, x, fused: bool = True):
        B, T, C = x.shape
        q, k, v = self.qkv(x).split(C, dim=-1)
        # (B, T, C) -> (B, heads, T, head_dim): each head gets its own slice of C
        q, k, v = (t.view(B, T, self.n_heads, -1).transpose(1, 2) for t in (q, k, v))
        if fused:
            y = F.scaled_dot_product_attention(q, k, v, is_causal=True)
        else:
            scores = q @ k.transpose(-2, -1) / math.sqrt(q.shape[-1])
            mask = torch.triu(torch.ones(T, T, dtype=torch.bool), diagonal=1)
            y = scores.masked_fill(mask, float("-inf")).softmax(-1) @ v
        y = y.transpose(1, 2).reshape(B, T, C)  # glue the heads back together
        return self.out(y)


if __name__ == "__main__":
    torch.manual_seed(0)
    tok = BPE.load("../part-1-tokenizer/tokenizer.json")
    text = "Holmes examined the telegram."
    ids = tok.encode(text)
    pieces = [tok.decode([i]) for i in ids]
    print(f"{len(ids)} tokens: {pieces}")

    d_model, d_head = 256, 64
    emb = nn.Embedding(4096, d_model)
    x = emb(torch.tensor(ids))  # (T, 256)

    wq, wk, wv = (torch.randn(d_model, d_head) / math.sqrt(d_model) for _ in range(3))
    with torch.no_grad():
        out, weights = one_head(x, wq, wk, wv)
        ref = F.scaled_dot_product_attention(
            (x @ wq)[None], (x @ wk)[None], (x @ wv)[None], is_causal=True
        )[0]
    assert torch.allclose(out, ref, atol=1e-5), (out - ref).abs().max()
    print("single head matches F.scaled_dot_product_attention")

    print("\nattention weights (row = token doing the looking, untrained):")
    print(" " * 12 + "".join(f"{p!r:>12}" for p in pieces))
    for p, row in zip(pieces, weights):
        print(f"{p!r:>12}" + "".join(f"{w:>12.3f}" for w in row))

    mha = MultiHeadAttention(d_model, n_heads=4)
    with torch.no_grad():
        a, b = mha(x[None], fused=True), mha(x[None], fused=False)
    assert torch.allclose(a, b, atol=1e-5), (a - b).abs().max()
    n_params = sum(p.numel() for p in mha.parameters())
    print(f"\nmulti-head (4 x 64): hand-rolled == fused, output {tuple(a.shape)}, {n_params:,} params")
