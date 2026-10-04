"""Tokens per second with and without the KV cache, plus what the cache costs in memory.

  python bench.py cuda
  python bench.py cpu 8     # thread count is optional

Untrained weights and greedy picks: speed does not depend on what the
model has learned, only on how much work each step does.
"""

import sys
import time

import torch

from cached import CachedGPT, Config

dev = torch.device(sys.argv[1] if len(sys.argv) > 1 else "cpu")
if len(sys.argv) > 2:
    torch.set_num_threads(int(sys.argv[2]))
cuda = dev.type == "cuda"
cfg = Config()
torch.manual_seed(0)
model = CachedGPT(cfg).to(dev).eval()


def timed(fn, *args):
    if cuda:
        torch.cuda.synchronize()
    t0 = time.perf_counter()
    fn(*args)
    if cuda:
        torch.cuda.synchronize()
    return time.perf_counter() - t0


if cuda:
    print(f"{torch.cuda.get_device_name()}, torch {torch.__version__}")
else:
    print(f"CPU, {torch.get_num_threads()} threads, torch {torch.__version__}")
print(f"{'batch':>5} {'tokens':>6} {'no cache tok/s':>15} {'cache tok/s':>12} {'speedup':>8}")

for batch in [1, 16]:
    prompt = torch.randint(cfg.vocab_size, (batch, 8), device=dev)
    timed(model.generate_cached, prompt, 16)  # warm-up
    timed(model.generate_uncached, prompt, 16)
    for n in [64, 256, 1024]:
        slow = timed(model.generate_uncached, prompt, n)
        fast = timed(model.generate_cached, prompt, n)
        print(f"{batch:>5} {n:>6} {batch * n / slow:>15,.0f} {batch * n / fast:>12,.0f} {slow / fast:>7.1f}x")

# What the cache holds once the window is full: keys and values, every layer.
caches = [{} for _ in model.blocks]
with torch.no_grad():
    model.step(torch.zeros(1, cfg.context, dtype=torch.long, device=dev), caches, 0)
measured = sum(t.numel() * t.element_size() for c in caches for t in c.values())
formula = 2 * cfg.n_layers * cfg.context * cfg.d_model * 4  # k and v, fp32
print(f"\ncache at {cfg.context} tokens, batch 1: {measured / 2**20:.2f} MiB "
      f"(2 x {cfg.n_layers} layers x {cfg.context} tokens x {cfg.d_model} dims x 4 bytes "
      f"= {formula / 2**20:.2f} MiB)")
