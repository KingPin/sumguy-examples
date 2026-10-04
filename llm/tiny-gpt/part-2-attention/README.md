# Part 2: Attention and Position

Companion code for [Train a Tiny GPT, Part 2: Attention](https://sumguy.com/train-tiny-gpt-attention/).

Builds causal self-attention by hand, proves it matches PyTorch's fused
kernel, shows that attention without position information cannot tell
word order apart, adds rotary position embeddings (RoPE), and measures how
attention's time and memory grow with sequence length.

| File | What it does |
|------|--------------|
| `attention.py` | Single-head attention step by step, then multi-head. Both asserted equal to `F.scaled_dot_product_attention`. |
| `position.py` | Shuffle proof (no position = no order), "Holmes shot Moriarty." vs "Moriarty shot Holmes.", and the RoPE relative-distance check. |
| `scaling.py` | Naive vs fused attention, 256 to 8,192 tokens on CPU (up to 32,768 on GPU), time and peak VRAM. |

## Prerequisites

- Setup from the [series README](../README.md), plus `tokenizer.json` from
  [Part 1](../part-1-tokenizer/) (`python train_tokenizer.py` there)
- `attention.py` and `position.py` run on CPU in under a second
- `scaling.py cuda` needs an NVIDIA GPU. Tested on an RTX 3070 Laptop GPU
  (8 GB) in the `pytorch/pytorch:2.14.1-cuda13.2-cudnn9-runtime` image
- Tested 2026-10-03 with torch 2.14.1 (CPU build and CUDA 13.2 build)

## Run

```bash
cd part-2-attention
python attention.py
python position.py
python scaling.py          # CPU, fp32, about 10 seconds
python scaling.py cuda     # GPU, fp16
```

With Docker on a GPU box, from this folder:

```bash
docker run --rm --gpus all -v "$PWD":/work -w /work \
  pytorch/pytorch:2.14.1-cuda13.2-cudnn9-runtime python scaling.py cuda
```

## Expected output (abridged)

```text
no position: max difference in final '.' vector = 0.000000
       RoPE: max difference in final '.' vector = 0.087948
RoPE score for 7 tokens apart at positions (10,3)=-3.7709, (110,103)=-3.7709, (507,500)=-3.7709
```

```text
NVIDIA GeForce RTX 3070 Laptop GPU, torch 2.14.1+cu132, fp16
 tokens  score matrix   naive ms   fused ms  speedup  naive MiB  fused MiB
   8192     512.0 MiB      20.99       1.80    11.6x       1600        4.1
  16384    2048.0 MiB      76.54       6.41    11.9x       6400        8.3
  32768    8192.0 MiB        OOM      22.14        -        OOM       16.5
```

Timings depend on your hardware. The asserts and the memory columns do not.
At 16,384 tokens PyTorch may print a `CUDACachingAllocator` OOM warning and
then succeed after freeing its cache. That warning is harmless.
