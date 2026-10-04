# Part 4: Inference, the KV Cache, and Sampling

Companion code for [Train a Tiny GPT, Part 4: Inference](https://sumguy.com/train-tiny-gpt-inference/).

Adds a KV cache to Part 3's model (no retraining, Part 3 checkpoints load
as is), checks that it changes nothing inside the 256-token window,
measures tokens per second with and without it on a CPU and an 8 GB GPU,
and compares sampling settings on the trained model.

| File | What it does |
|------|--------------|
| `cached.py` | `CachedGPT`: Part 3's GPT plus a per-layer key/value cache and `rope_at()`, a RoPE that starts at any position. Run it to check cached and uncached greedy decoding agree. |
| `sampling.py` | `pick()`: temperature, top-k, top-p, and repetition penalty. Run it for the self-check. |
| `bench.py` | Tokens/s with and without the cache, batch 1 and 16, plus cache size. |
| `sample_grid.py` | One prompt, one seed, eight sampling settings side by side. |

## Prerequisites

- Setup from the [series README](../README.md), `tokenizer.json` from
  [Part 1](../part-1-tokenizer/), and a checkpoint from
  [Part 3](../part-3-training/) (`gpu1500.pt` or `cpu1500.pt`)
- `bench.py` uses untrained weights, so it runs without a checkpoint
- Tested 2026-10-04 with torch 2.14.1 on an RTX 3070 Laptop GPU (8 GB) and
  its Intel i7-11800H CPU (8 threads), in the
  `pytorch/pytorch:2.14.1-cuda13.2-cudnn9-runtime` image, and with the CPU
  build of torch 2.14.1 for `cached.py`, `sampling.py`, and `sample_grid.py`

## Run

```bash
cd part-4-inference
python sampling.py                                         # < 1 s
python cached.py ../part-3-training/gpu1500.pt             # about 10 s
python bench.py cuda
python bench.py cpu 8
python sample_grid.py ../part-3-training/gpu1500.pt "Holmes"
```

With Docker on a GPU box, from the `tiny-gpt` folder:

```bash
docker run --rm --gpus all -v "$PWD":/work -w /work/part-4-inference \
  pytorch/pytorch:2.14.1-cuda13.2-cudnn9-runtime sh -c \
  "pip install -q --break-system-packages regex==2026.9.29 && python bench.py cuda"
```

## Expected output (abridged)

```text
first 253 tokens identical with and without the cache
first difference at position 322 of 603
```

Past the 256-token window the two loops stop agreeing. The uncached loop
reruns the last 256 tokens from scratch. The cache keeps entries that were
computed while older tokens were still in view. Both are valid ways to
slide the window; they are not the same computation.

```text
NVIDIA GeForce RTX 3070 Laptop GPU, torch 2.14.1+cu132
batch tokens  no cache tok/s  cache tok/s  speedup
    1     64             228          218     1.0x
    1   1024             194          223     1.1x
   16   1024           1,369        3,059     2.2x
CPU, 8 threads, torch 2.14.1+cu132
    1     64             164          279     1.7x
    1   1024              57          250     4.4x
   16   1024              93        1,705    18.4x

cache at 256 tokens, batch 1: 3.00 MiB (2 x 6 layers x 256 tokens x 256 dims x 4 bytes = 3.00 MiB)
```

At batch 1 the GPU gains nothing from the cache. A cached step launches
317 small kernels and, per `torch.profiler`, the GPU is busy for about 1 ms of it; the rest is
Python and launch overhead, which the cache does not touch. The CPU does
the math itself, so cutting the math shows up directly.

Speed depends on your hardware, and repeat runs on the same box vary by
about 5%. `sample_grid.py` runs on the CPU and its
output is the same on every run with the same seed.
