"""Part 3's GPT with a KV cache, so each new token costs one position, not 256.

Without a cache, generating token N reruns attention and the MLP for every
token before it, even though their keys and values have not changed. The
cache keeps each layer's keys and values and only computes the new token.

Run it directly to check that cached and uncached greedy decoding agree:

  python cached.py ../part-3-training/gpu1500.pt
"""

import sys

import torch
import torch.nn.functional as F

sys.path.insert(0, "../part-3-training")
from model import GPT, Config, RoPEAttention  # noqa: E402


def rope_at(x, start: int, base: float = 10000.0):
    """Part 2's rope(), but the first row sits at position `start`, not 0.

    A cached decode step feeds one token. Part 2's rope() would rotate it as
    position 0 every time, so the model would see every new token at the
    very start of the text.
    """
    T, d = x.shape[-2], x.shape[-1]
    freqs = base ** (-torch.arange(0, d, 2, dtype=torch.float32) / d)
    angles = torch.arange(start, start + T, dtype=torch.float32)[:, None] * freqs
    cos, sin = angles.cos(), angles.sin()
    x1, x2 = x[..., 0::2], x[..., 1::2]
    return torch.stack((x1 * cos - x2 * sin, x1 * sin + x2 * cos), dim=-1).flatten(-2)


def greedy(logits, idx):
    return logits.argmax(-1)


class CachedAttention(RoPEAttention):
    def __init__(self, cfg: Config):
        super().__init__(cfg)
        self.context = cfg.context

    def forward(self, x, cache: dict | None = None, start: int = 0):
        """With no cache this is Part 3's attention, so model(idx) still works."""
        B, T, C = x.shape
        q, k, v = self.qkv(x).split(C, dim=-1)
        q, k, v = (t.view(B, T, self.n_heads, -1).transpose(1, 2) for t in (q, k, v))
        with torch.device(q.device):
            q, k = rope_at(q, start).to(v.dtype), rope_at(k, start).to(v.dtype)
        if cache is not None:
            if "k" in cache:
                assert T == 1, "after the prompt, feed one token at a time"
                k = torch.cat([cache["k"], k], dim=2)
                v = torch.cat([cache["v"], v], dim=2)
            # Keep only the last `context` positions. Keys were rotated at their
            # true positions and RoPE scores depend only on the distance between
            # q and k, so the rotation stays correct as the window slides. The
            # content does not: an old entry still carries context from tokens
            # that have left the window, which a full rerun would not see.
            cache["k"], cache["v"] = k[:, :, -self.context:], v[:, :, -self.context:]
        # is_causal=True with one query would mask out every key but the
        # first (PyTorch aligns the mask top-left). One new query may see
        # everything in the cache, so the mask is only needed for the prompt.
        y = F.scaled_dot_product_attention(q, k, v, is_causal=T > 1)
        return self.out(y.transpose(1, 2).reshape(B, T, C))


class CachedGPT(GPT):
    def __init__(self, cfg: Config):
        super().__init__(cfg)
        for block in self.blocks:  # same parameter names, so Part 3 checkpoints load
            block.attn = CachedAttention(cfg)

    def step(self, idx, caches, start: int):
        """Run only the new tokens through the model. Returns last-position logits."""
        x = self.emb(idx)
        for block, cache in zip(self.blocks, caches):
            x = x + block.attn(block.norm1(x), cache, start)
            x = x + block.mlp(block.norm2(x))
        return self.head(self.norm(x[:, -1]))

    @torch.no_grad()
    def generate_cached(self, idx, n_tokens: int, pick=greedy):
        """pick(logits, idx) chooses the next token; idx is everything so far."""
        caches = [{} for _ in self.blocks]
        prompt = idx[:, -self.cfg.context:]
        logits = self.step(prompt, caches, 0)  # prefill: the whole prompt in one pass
        pos = prompt.shape[1]
        for _ in range(n_tokens):
            nxt = pick(logits, idx)[:, None]
            idx = torch.cat([idx, nxt], dim=1)
            logits = self.step(nxt, caches, pos)
            pos += 1
        return idx

    @torch.no_grad()
    def generate_uncached(self, idx, n_tokens: int, pick=greedy):
        """Part 3's loop: rerun the last `context` tokens for every new token."""
        for _ in range(n_tokens):
            logits, _ = self(idx[:, -self.cfg.context:])
            idx = torch.cat([idx, pick(logits[:, -1], idx)[:, None]], dim=1)
        return idx


def load(path, device="cpu"):
    ckpt = torch.load(path, map_location=device)
    model = CachedGPT(Config(**ckpt["config"])).to(device)
    model.load_state_dict(ckpt["model"])
    return model.eval()


if __name__ == "__main__":
    model = load(sys.argv[1] if len(sys.argv) > 1 else "../part-3-training/gpu1500.pt")
    idx = torch.tensor([[1, 2, 3]])  # any prompt works for an equality check
    n = 600

    # Inside the window, the cache must change nothing.
    with_cache = model.generate_cached(idx, n)[0, 3:]
    without = model.generate_uncached(idx, n)[0, 3:]
    inside = model.cfg.context - 3
    assert torch.equal(with_cache[:inside], without[:inside]), "cache changed the output"
    print(f"first {inside} tokens identical with and without the cache")

    # Past the window the two loops see different things (see CachedAttention),
    # so they drift apart. Report where, rather than assert.
    diff = (with_cache != without).nonzero()
    first = diff[0].item() + 3 if len(diff) else None
    print(f"first difference at position {first} of {n + 3}" if first else f"all {n} identical")
