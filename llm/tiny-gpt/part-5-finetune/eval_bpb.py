"""Bits per byte on Part 3's val text, for either model.

  python eval_bpb.py tiny ../part-3-training/gpu1500.pt
  python eval_bpb.py gemma                     # the base model, no fine-tune
  python eval_bpb.py gemma adapters/frac100    # base model + a LoRA adapter

Loss per token cannot compare the two models: the tiny GPT has 4,096 tokens
and Gemma has 262,144, so one Gemma token covers more text. Bits per byte
divides the total loss by the size of the text instead. Lower is better.
"""

import math
import sys
import time

import torch
import torch.nn.functional as F

from common import TINY_TOK, val_chunks


@torch.no_grad()
def nats(model, ctx_ids, body_ids, device):
    """Total -log p of body_ids, given ctx_ids in front of them."""
    x = torch.tensor([ctx_ids + body_ids], device=device)
    out = model(x[:, :-1])
    logits = out[0] if isinstance(out, tuple) else out.logits
    logits = logits[0, len(ctx_ids) - 1 :].float()  # the positions that predict the body
    return F.cross_entropy(logits, x[0, len(ctx_ids) :], reduction="sum").item()


def bpb_tiny(path, device="cuda"):
    sys.path.insert(0, "../part-4-inference")
    from cached import load

    model = load(path, device)
    return bits_per_byte(sum(nats(model, TINY_TOK.encode(c), TINY_TOK.encode(b), device) for c, b in val_chunks()))


def bpb_gemma(model, tok):
    total = 0.0
    for c, b in val_chunks():
        ctx = tok(c, add_special_tokens=True).input_ids  # starts with <bos>
        total += nats(model, ctx, tok(b, add_special_tokens=False).input_ids, "cuda")
    return bits_per_byte(total)


def bits_per_byte(total_nats):
    n = sum(len(b.encode()) for _, b in val_chunks())
    return total_nats / n / math.log(2)


if __name__ == "__main__":
    t0 = time.perf_counter()
    if sys.argv[1] == "tiny":
        bpb = bpb_tiny(sys.argv[2])
    else:
        from common import load_gemma

        model, tok = load_gemma(sys.argv[2] if len(sys.argv) > 2 else None)
        bpb = bpb_gemma(model, tok)
    print(f"{' '.join(sys.argv[1:])}: {bpb:.3f} bits per byte ({time.perf_counter() - t0:.0f}s)")
