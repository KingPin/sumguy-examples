# Part 3: The Model and the Training Loop

Companion code for [Train a Tiny GPT, Part 3: Training](https://sumguy.com/train-tiny-gpt-training/).

Stacks Part 2's attention (with RoPE) and an MLP into a 5.8M-parameter GPT,
trains it on the Holmes corpus on a CPU and on an 8 GB GPU with the same
seed and the same batches, measures speed and VRAM, shows the model
overfitting, and reruns Part 1's embedding check on the trained weights.

| File | What it does |
|------|--------------|
| `model.py` | The GPT: embedding, 6 blocks (RoPE attention + MLP), tied output head. Run it to print the parameter budget and check that untrained loss equals ln(4096). |
| `train.py` | Training loop: 90/10 train/val split, AdamW, warmup + cosine LR, bf16 on GPU. Logs to `<out>.csv`, saves the best-val checkpoint to `<out>.pt`. |
| `bench.py` | Tokens/s and peak VRAM per batch size, fp32 vs bf16. |
| `embeddings_after.py` | Part 1's " Holmes" / " Watson" / " telegram" cosine check, untrained vs trained, plus nearest neighbours. |
| `sample.py` | Generate text from a checkpoint. No KV cache yet (that is Part 4). |

## Prerequisites

- Setup from the [series README](../README.md), plus `tokenizer.json` from
  [Part 1](../part-1-tokenizer/) (`python train_tokenizer.py` there)
- `train.py` tokenizes the corpus on its first run and caches the ids in
  `../data/holmes_ids.npy` (1,030,773 tokens, about a second)
- GPU runs need an NVIDIA GPU. Tested on an RTX 3070 Laptop GPU (8 GB) and
  its Intel i7-11800H CPU (8 cores), in the
  `pytorch/pytorch:2.14.1-cuda13.2-cudnn9-runtime` image
- Tested 2026-10-04 with torch 2.14.1 (CPU build and CUDA 13.2 build)

## Run

```bash
cd part-3-training
python model.py                                   # parameter count, < 1 s
python train.py --device cpu --threads 8 --steps 1500 --out cpu1500   # about 1 hour
python train.py --device cuda --steps 1500 --out gpu1500              # about 1 minute
python train.py --device cuda --steps 5000 --out gpu                  # the overfitting run
python bench.py cuda
python embeddings_after.py gpu1500.pt
python sample.py gpu1500.pt "Holmes" --seed 1
```

With Docker on a GPU box, from the `tiny-gpt` folder (the image is missing
`regex`, which the tokenizer needs):

```bash
docker run --rm --gpus all -v "$PWD":/work -w /work/part-3-training \
  pytorch/pytorch:2.14.1-cuda13.2-cudnn9-runtime sh -c \
  "pip install -q --break-system-packages regex==2026.9.29 && python train.py --device cuda --steps 1500 --out gpu1500"
```

## Expected output (abridged)

```text
total                                 5,781,504
untrained loss 8.379, ln(4096) = 8.318
```

```text
NVIDIA GeForce RTX 3070 Laptop GPU, torch 2.14.1+cu132, bf16, batch 32 x 256 = 8,192 tokens/step
step  1500  train 3.078  val 3.773  207,012 tok/s      59s *
CPU, 8 threads, torch 2.14.1+cu132, fp32, batch 32 x 256 = 8,192 tokens/step
step  1500  train 3.070  val 3.762    4,293 tok/s    2862s *
```

```text
pair                        untrained  trained
 Holmes /  Watson              -0.006   +0.355
 Holmes /  telegram            -0.045   +0.014
 Watson /  telegram            +0.124   +0.201

nearest to ' telegram': ' letter' 0.60, ' note' 0.57, ' narrative' 0.56, ' message' 0.55, ' photograph' 0.54, ' wire' 0.51
```

Speed depends on your hardware. Two GPU runs of the same command matched
to three decimal places. CPU (fp32) and GPU (bf16) runs see the same
batches but differ slightly in loss because of the precision.
