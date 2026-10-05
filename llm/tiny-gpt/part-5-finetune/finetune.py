"""QLoRA fine-tune of Gemma 4 E4B on the Holmes train text, on an 8 GB GPU.

  python finetune.py --frac 0.1 --out adapters/frac10
  python finetune.py --frac 1.0 --out adapters/frac100

The 8B base weights stay frozen in 4-bit. Training only touches small LoRA
matrices next to the attention and MLP layers. One pass over the chosen
share of the train text, then the bits-per-byte score on the val text.
"""

import argparse
import math
import random
import time

import torch
from peft import LoraConfig, get_peft_model

from common import load_gemma, train_text
from eval_bpb import bpb_gemma

ap = argparse.ArgumentParser()
ap.add_argument("--frac", type=float, default=1.0)
ap.add_argument("--seq", type=int, default=512, help="tokens per training sequence")
ap.add_argument("--accum", type=int, default=8, help="sequences per optimizer step")
ap.add_argument("--rank", type=int, default=16)
ap.add_argument("--lr", type=float, default=2e-4)
ap.add_argument("--max-steps", type=int, default=0, help="stop early (0 = one full pass)")
ap.add_argument("--out", default="adapters/run")
args = ap.parse_args()

model, tok = load_gemma()
model.gradient_checkpointing_enable(gradient_checkpointing_kwargs={"use_reentrant": False})
model = get_peft_model(model, LoraConfig(
    r=args.rank, lora_alpha=2 * args.rank, lora_dropout=0.05,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj", "gate_proj", "up_proj", "down_proj"],
))
trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
print(f"trainable LoRA params: {trainable:,}")

# Cut the text into fixed-length sequences, each starting with <bos>.
ids = tok(train_text(args.frac), add_special_tokens=False).input_ids
n = args.seq - 1
seqs = [[tok.bos_token_id] + ids[i : i + n] for i in range(0, len(ids) - n + 1, n)]
random.Random(1337).shuffle(seqs)
steps = len(seqs) // args.accum
if args.max_steps:
    steps = min(steps, args.max_steps)
print(f"{len(ids):,} Gemma tokens -> {len(seqs)} sequences of {args.seq} -> {steps} steps")

opt = torch.optim.AdamW([p for p in model.parameters() if p.requires_grad], lr=args.lr, weight_decay=0.0)
warmup = max(1, steps // 10)


def lr_at(step):  # the same shape as Part 3: linear warmup, cosine down to 10%
    if step < warmup:
        return args.lr * (step + 1) / warmup
    t = (step - warmup) / max(1, steps - warmup)
    return args.lr * (0.1 + 0.9 * 0.5 * (1 + math.cos(math.pi * t)))


torch.cuda.reset_peak_memory_stats()
model.train()
t0 = time.perf_counter()
for step in range(steps):
    for g in opt.param_groups:
        g["lr"] = lr_at(step)
    total = 0.0
    for s in seqs[step * args.accum : (step + 1) * args.accum]:
        x = torch.tensor([s], device="cuda")
        loss = model(input_ids=x, labels=x).loss / args.accum
        loss.backward()
        total += loss.item()
    torch.nn.utils.clip_grad_norm_([p for p in model.parameters() if p.requires_grad], 1.0)
    opt.step()
    opt.zero_grad(set_to_none=True)
    if step % 10 == 0 or step == steps - 1:
        el = time.perf_counter() - t0
        print(f"step {step:>4}/{steps}  loss {total:.3f}  {el:>6.0f}s  "
              f"peak {torch.cuda.max_memory_allocated() / 2**20:,.0f} MiB", flush=True)

train_time = time.perf_counter() - t0
model.save_pretrained(args.out)
print(f"training time {train_time:.0f}s, {steps * args.accum * args.seq:,} tokens")
print(f"peak VRAM {torch.cuda.max_memory_allocated() / 2**20:,.0f} MiB allocated, "
      f"{torch.cuda.max_memory_reserved() / 2**20:,.0f} MiB reserved")

model.eval()
t1 = time.perf_counter()
print(f"val: {bpb_gemma(model, tok):.3f} bits per byte ({time.perf_counter() - t1:.0f}s)")
