"""Why long context is expensive: time and memory of attention vs length.

"naive" builds the full (T x T) score matrix, like attention.py does.
"fused" is F.scaled_dot_product_attention, which on a recent GPU picks a
flash-attention kernel that never stores that matrix.

Shape matches Part 3's planned model: 1 sequence, 4 heads of 64 dims.

    python scaling.py          # CPU, fp32
    python scaling.py cuda     # GPU, fp16 (also reports peak VRAM)
"""

import math
import statistics
import sys
import time

import torch
import torch.nn.functional as F

HEADS, HEAD_DIM = 4, 64


def naive(q, k, v):
    T = q.shape[-2]
    scores = q @ k.transpose(-2, -1) / math.sqrt(q.shape[-1])
    mask = torch.triu(torch.ones(T, T, dtype=torch.bool, device=q.device), diagonal=1)
    return scores.masked_fill(mask, float("-inf")).softmax(-1) @ v


def fused(q, k, v):
    return F.scaled_dot_product_attention(q, k, v, is_causal=True)


def measure(fn, q, k, v, runs: int):
    """Median milliseconds over `runs`, plus peak extra memory in MiB (CUDA only)."""
    cuda = q.is_cuda
    fn(q, k, v)  # warm-up: kernel selection, allocator
    if cuda:
        torch.cuda.synchronize()
        torch.cuda.reset_peak_memory_stats()
        base = torch.cuda.memory_allocated()
    times = []
    for _ in range(runs):
        t0 = time.perf_counter()
        fn(q, k, v)
        if cuda:
            torch.cuda.synchronize()
        times.append((time.perf_counter() - t0) * 1000)
    peak = (torch.cuda.max_memory_allocated() - base) / 2**20 if cuda else None
    return statistics.median(times), peak


if __name__ == "__main__":
    device = sys.argv[1] if len(sys.argv) > 1 else "cpu"
    dtype = torch.float16 if device == "cuda" else torch.float32
    lengths = [256, 512, 1024, 2048, 4096, 8192] + ([16384, 32768] if device == "cuda" else [])
    torch.manual_seed(0)
    torch.set_grad_enabled(False)
    if device == "cuda":
        print(f"{torch.cuda.get_device_name()}, torch {torch.__version__}, fp16")
    else:
        print(f"CPU, {torch.get_num_threads()} threads, torch {torch.__version__}, fp32")

    elem = torch.finfo(dtype).bits // 8
    print(f"{'tokens':>7} {'score matrix':>13} {'naive ms':>10} {'fused ms':>10} {'speedup':>8}"
          + (f" {'naive MiB':>10} {'fused MiB':>10}" if device == "cuda" else ""))
    for T in lengths:
        q, k, v = (torch.randn(1, HEADS, T, HEAD_DIM, device=device, dtype=dtype) for _ in range(3))
        assert torch.allclose(naive(q[..., :64, :], k[..., :64, :], v[..., :64, :]),
                              fused(q[..., :64, :], k[..., :64, :], v[..., :64, :]), atol=1e-2)
        runs = 10 if T <= 2048 else 3
        matrix_mib = HEADS * T * T * elem / 2**20
        try:
            n_ms, n_mem = measure(naive, q, k, v, runs)
            n_txt = f"{n_ms:>10.2f}"
        except torch.OutOfMemoryError:
            n_ms, n_mem, n_txt = None, None, f"{'OOM':>10}"
            torch.cuda.empty_cache()
        f_ms, f_mem = measure(fused, q, k, v, runs)
        speed = f"{n_ms / f_ms:>7.1f}x" if n_ms else f"{'-':>8}"
        line = f"{T:>7} {matrix_mib:>9.1f} MiB {n_txt} {f_ms:>10.2f} {speed}"
        if device == "cuda":
            line += f" {n_mem:>10.0f}" if n_mem is not None else f" {'OOM':>10}"
            line += f" {f_mem:>10.1f}"
        print(line, flush=True)
