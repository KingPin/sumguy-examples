"""Train the model on the Holmes corpus, on CPU or GPU, and log what it costs.

  python train.py --device cpu --steps 300
  python train.py --device cuda --steps 5000

Same seed, same init, same batches on either device, so the loss curves are
comparable step for step. Writes <out>.pt (best validation loss so far) and
<out>.csv (one row per evaluation).
"""

import argparse
import csv
import math
import pathlib
import sys
import time

import numpy as np
import torch

from model import GPT, Config

sys.path.insert(0, "../part-1-tokenizer")
from bpe import BPE  # noqa: E402

DATA = pathlib.Path("../data")
tok = BPE.load("../part-1-tokenizer/tokenizer.json")


def load_ids() -> np.ndarray:
    """Tokenize the corpus once and cache the ids (4,096 ids fit in uint16)."""
    cache = DATA / "holmes_ids.npy"
    if not cache.exists():
        text = (DATA / "holmes.txt").read_text(encoding="utf-8")
        np.save(cache, np.array(tok.encode(text), dtype=np.uint16))
    return np.load(cache)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--device", default="cpu")
    ap.add_argument("--steps", type=int, default=5000)
    ap.add_argument("--batch", type=int, default=32)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--threads", type=int, default=0, help="CPU threads, 0 = torch default")
    ap.add_argument("--eval-every", type=int, default=250)
    ap.add_argument("--out", default="run")
    args = ap.parse_args()

    if args.threads:
        torch.set_num_threads(args.threads)
    dev = torch.device(args.device)
    use_bf16 = dev.type == "cuda"  # mixed precision on GPU, plain fp32 on CPU

    ids = torch.from_numpy(load_ids().astype(np.int64))
    split = int(len(ids) * 0.9)
    data = {"train": ids[:split], "val": ids[split:]}  # the last 10% is never trained on
    cfg = Config()
    print(f"{len(ids):,} tokens: {split:,} train, {len(ids) - split:,} val")

    torch.manual_seed(1337)
    model = GPT(cfg).to(dev)  # init happens on the CPU, so both devices start identical
    gen = torch.Generator().manual_seed(1337)  # batch sampling also on the CPU

    def batch(name, g=gen):
        d = data[name]
        starts = torch.randint(len(d) - cfg.context - 1, (args.batch,), generator=g)
        x = torch.stack([d[s : s + cfg.context] for s in starts])
        y = torch.stack([d[s + 1 : s + 1 + cfg.context] for s in starts])  # next token
        return x.to(dev), y.to(dev)

    def step_loss(x, y):
        with torch.autocast(dev.type, dtype=torch.bfloat16, enabled=use_bf16):
            return model(x, y)[1]

    @torch.no_grad()
    def evaluate():
        model.eval()
        g = torch.Generator().manual_seed(0)  # same eval batches every time
        out = {n: sum(step_loss(*batch(n, g)).item() for _ in range(20)) / 20 for n in data}
        model.train()
        return out

    def sample():
        torch.manual_seed(42)
        prompt = torch.tensor([tok.encode("Holmes")], device=dev)
        model.eval()
        with torch.autocast(dev.type, dtype=torch.bfloat16, enabled=use_bf16):
            text = tok.decode(model.generate(prompt, 40)[0].tolist())
        model.train()
        return " ".join(text.split())

    # AdamW with weight decay on matrices only (not norms or biases).
    decay = [p for p in model.parameters() if p.dim() >= 2]
    no_decay = [p for p in model.parameters() if p.dim() < 2]
    opt = torch.optim.AdamW(
        [{"params": decay, "weight_decay": 0.1}, {"params": no_decay, "weight_decay": 0.0}],
        lr=args.lr, betas=(0.9, 0.95), fused=dev.type == "cuda",
    )
    warmup = min(200, args.steps // 10)

    def lr_at(step):  # linear warmup, then cosine decay down to 10%
        if step < warmup:
            return args.lr * (step + 1) / warmup
        t = (step - warmup) / max(1, args.steps - warmup)
        return args.lr * (0.1 + 0.9 * 0.5 * (1 + math.cos(math.pi * t)))

    log = open(f"{args.out}.csv", "w", newline="")
    writer = csv.writer(log)
    writer.writerow(["step", "train_loss", "val_loss", "tokens_per_sec", "elapsed_sec"])
    tokens_per_step = args.batch * cfg.context
    best_val, best_step, train_time = float("inf"), 0, 0.0
    if dev.type == "cuda":
        torch.cuda.reset_peak_memory_stats()
    name = torch.cuda.get_device_name() if dev.type == "cuda" else f"CPU, {torch.get_num_threads()} threads"
    print(f"{name}, torch {torch.__version__}, {'bf16' if use_bf16 else 'fp32'}, "
          f"batch {args.batch} x {cfg.context} = {tokens_per_step:,} tokens/step")

    t0 = time.perf_counter()
    for step in range(args.steps + 1):
        if step % args.eval_every == 0 or step == args.steps:
            losses = evaluate()
            tps = tokens_per_step * step / train_time if train_time else 0.0
            writer.writerow([step, f"{losses['train']:.4f}", f"{losses['val']:.4f}", f"{tps:.0f}", f"{train_time:.1f}"])
            log.flush()
            mark = ""
            if losses["val"] < best_val:
                best_val, best_step, mark = losses["val"], step, " *"
                torch.save({"model": model.state_dict(), "config": cfg.__dict__, "step": step}, f"{args.out}.pt")
            print(f"step {step:>5}  train {losses['train']:.3f}  val {losses['val']:.3f}  "
                  f"{tps:>7,.0f} tok/s  {train_time:>6.0f}s{mark}")
            if step in (0, args.steps // 2, args.steps):
                print(f"  sample: {sample()!r}")
            if step == args.steps:
                break

        if dev.type == "cuda":
            torch.cuda.synchronize()
        ts = time.perf_counter()
        for g in opt.param_groups:
            g["lr"] = lr_at(step)
        loss = step_loss(*batch("train"))
        opt.zero_grad(set_to_none=True)
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        opt.step()
        if dev.type == "cuda":
            torch.cuda.synchronize()
        train_time += time.perf_counter() - ts  # time spent training, evals excluded

    print(f"\n{args.steps:,} steps, {args.steps * tokens_per_step / 1e6:.1f}M tokens seen "
          f"({args.steps * tokens_per_step / split:.1f} passes over the training set)")
    print(f"training time {train_time:.0f}s (wall clock incl. evals {time.perf_counter() - t0:.0f}s)")
    print(f"best val loss {best_val:.3f} at step {best_step}, saved to {args.out}.pt")
    if dev.type == "cuda":
        print(f"peak VRAM {torch.cuda.max_memory_allocated() / 2**20:,.0f} MiB")


if __name__ == "__main__":
    main()
