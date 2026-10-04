"""The full model: Part 2's attention plus an MLP, stacked into a GPT.

Token ids -> embedding -> N transformer blocks -> final norm -> logits over
the vocabulary. Each block is attention (tokens look at earlier tokens) then
an MLP (each token thinks on its own), both wrapped in a residual add.

Run it directly to print the parameter budget and check that an untrained
model's loss is ln(vocab_size): a uniform guess over 4,096 tokens.
"""

import math
import sys
from dataclasses import dataclass

import torch
import torch.nn as nn
import torch.nn.functional as F

sys.path.insert(0, "../part-2-attention")
from attention import MultiHeadAttention  # noqa: E402
from position import rope  # noqa: E402


@dataclass
class Config:
    vocab_size: int = 4096
    d_model: int = 256
    n_heads: int = 4      # 4 heads x 64 dims, as promised in Part 2
    n_layers: int = 6
    context: int = 256    # tokens the model sees at once
    dropout: float = 0.1


class RoPEAttention(MultiHeadAttention):
    """Part 2's multi-head attention with q and k rotated by RoPE."""

    def __init__(self, cfg: Config):
        super().__init__(cfg.d_model, cfg.n_heads)
        self.dropout = cfg.dropout

    def forward(self, x):
        B, T, C = x.shape
        q, k, v = self.qkv(x).split(C, dim=-1)
        q, k, v = (t.view(B, T, self.n_heads, -1).transpose(1, 2) for t in (q, k, v))
        # rope() builds its angle tables with torch.arange, which lands on the
        # CPU by default. The context manager puts them next to q and k.
        with torch.device(q.device):
            q, k = rope(q).to(v.dtype), rope(k).to(v.dtype)
        p = self.dropout if self.training else 0.0
        y = F.scaled_dot_product_attention(q, k, v, is_causal=True, dropout_p=p)
        return self.out(y.transpose(1, 2).reshape(B, T, C))


class Block(nn.Module):
    def __init__(self, cfg: Config):
        super().__init__()
        d = cfg.d_model
        self.norm1, self.norm2 = nn.LayerNorm(d), nn.LayerNorm(d)
        self.attn = RoPEAttention(cfg)
        self.mlp = nn.Sequential(
            nn.Linear(d, 4 * d), nn.GELU(), nn.Linear(4 * d, d), nn.Dropout(cfg.dropout)
        )

    def forward(self, x):
        x = x + self.attn(self.norm1(x))  # mix information across tokens
        return x + self.mlp(self.norm2(x))  # process each token on its own


class GPT(nn.Module):
    def __init__(self, cfg: Config):
        super().__init__()
        self.cfg = cfg
        self.emb = nn.Embedding(cfg.vocab_size, cfg.d_model)
        self.blocks = nn.ModuleList(Block(cfg) for _ in range(cfg.n_layers))
        self.norm = nn.LayerNorm(cfg.d_model)
        self.head = nn.Linear(cfg.d_model, cfg.vocab_size, bias=False)
        self.head.weight = self.emb.weight  # tied: one table reads tokens in and scores them out
        self.apply(self._init)
        # Every block adds its output to the residual stream. Shrink the layers
        # that write into it so the sum stays the same size as depth grows.
        for name, p in self.named_parameters():
            if name.endswith(("attn.out.weight", "mlp.2.weight")):
                nn.init.normal_(p, std=0.02 / math.sqrt(2 * cfg.n_layers))

    @staticmethod
    def _init(m):
        if isinstance(m, (nn.Linear, nn.Embedding)):
            nn.init.normal_(m.weight, std=0.02)
        if isinstance(m, nn.Linear) and m.bias is not None:
            nn.init.zeros_(m.bias)

    def forward(self, idx, targets=None):
        x = self.emb(idx)
        for block in self.blocks:
            x = block(x)
        logits = self.head(self.norm(x))
        if targets is None:
            return logits, None
        loss = F.cross_entropy(logits.flatten(0, 1).float(), targets.flatten())
        return logits, loss

    @torch.no_grad()
    def generate(self, idx, n_tokens: int, temperature: float = 0.8):
        """Plain sampling. No KV cache: every step reruns the whole context (Part 4 fixes that)."""
        for _ in range(n_tokens):
            logits, _ = self(idx[:, -self.cfg.context:])
            probs = (logits[:, -1].float() / temperature).softmax(-1)
            idx = torch.cat([idx, torch.multinomial(probs, 1)], dim=1)
        return idx


if __name__ == "__main__":
    torch.manual_seed(0)
    cfg = Config()
    model = GPT(cfg)

    def count(module):
        return sum(p.numel() for p in module.parameters())

    per_block = count(model.blocks[0])
    print(f"embedding (shared with output head) {count(model.emb):>11,}")
    print(f"one block                           {per_block:>11,}")
    print(f"  attention                         {count(model.blocks[0].attn):>11,}")
    print(f"  MLP                               {count(model.blocks[0].mlp):>11,}")
    print(f"{cfg.n_layers} blocks                            {per_block * cfg.n_layers:>11,}")
    total = count(model)  # parameters() counts the tied weight once
    print(f"total                               {total:>11,}")
    assert total < 30_000_000

    idx = torch.randint(cfg.vocab_size, (4, cfg.context))
    model.eval()
    _, loss = model(idx, targets=torch.roll(idx, -1, dims=1))
    print(f"\nuntrained loss {loss.item():.3f}, ln({cfg.vocab_size}) = {math.log(cfg.vocab_size):.3f}")
    assert abs(loss.item() - math.log(cfg.vocab_size)) < 0.1
    print("untrained model guesses uniformly: OK")
