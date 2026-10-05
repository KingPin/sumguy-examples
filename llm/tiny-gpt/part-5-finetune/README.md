# Part 5: From Scratch vs a QLoRA Fine-Tune

Companion code for [Train a Tiny GPT, Part 5: Fine-Tuning](https://sumguy.com/train-tiny-gpt-finetune/).

Puts Part 3's 5.8M-parameter model next to Gemma 4 E4B (8.0B parameters,
`google/gemma-4-E4B`, the pretrained base model) with a QLoRA fine-tune on
the same Sherlock Holmes train text, on an 8 GB GPU. Both models are scored
in bits per byte on Part 3's val text, because their tokenizers differ
(4,096 vs 262,144 tokens). Each one trains on 10%, 50%, and 100% of the
train text.

| File | What it does |
|------|--------------|
| `common.py` | The train/val text exactly as Part 3 split it, the 578 fixed val chunks both models are scored on, and `load_gemma()`, the 4-bit loader that fits E4B on 8 GB. Run it to check the chunks. |
| `eval_bpb.py` | Bits per byte on the val text, for a tiny GPT checkpoint or Gemma (with or without an adapter). |
| `finetune.py` | One pass of QLoRA over a share of the train text, then the val score. |
| `generate.py` | Same prompts and sampling settings for all three models, plus a memorization check on unseen val passages. |
| `quant_check.py` | How much 4-bit costs the base model: NF4 everywhere vs the bf16 keep list vs no quantization. |

Part 3's `train.py` gained a `--frac` flag for the smaller tiny-GPT runs.
The default (1.0) leaves Part 3's behavior unchanged.

## Prerequisites

- Setup from the [series README](../README.md), `tokenizer.json` from
  [Part 1](../part-1-tokenizer/), and `gpu1500.pt` from
  [Part 3](../part-3-training/)
- An NVIDIA GPU with 8 GB. Training peaks at 7,262 MiB allocated (7,653 MiB
  in `nvidia-smi`), so nothing else can share the card
- At least 6 GB of free system RAM, plus headroom while loading. E4B's per-layer embedding table holds 2.8B
  of its 8.0B weights, bitsandbytes does not quantize it, and it lives in
  CPU RAM (5.6 GB in bf16). `quant_check.py`'s bf16 row loads the whole
  model on the CPU and needs about 15 GB for the weights alone
- 15 GB of disk for the checkpoint. Gemma 4 is Apache 2.0 and not gated, so
  no Hugging Face token is needed
- Tested 2026-10-05 on an RTX 3070 Laptop GPU (8 GB) with 62 GB RAM, in the
  `pytorch/pytorch:2.14.1-cuda13.2-cudnn9-runtime` image, with
  transformers 5.18.0, peft 0.21.2, bitsandbytes 0.50.2, accelerate 1.15.0

## Run

With Docker, from the `tiny-gpt` folder. The packages install into
`./pyuser` and the model downloads into `./hf`, so both survive between
containers:

```bash
G="docker run --rm --gpus all -v $PWD:/work -w /work/part-5-finetune \
  -e PYTHONUSERBASE=/work/pyuser -e HF_HOME=/work/hf \
  pytorch/pytorch:2.14.1-cuda13.2-cudnn9-runtime"

$G pip install -q --user --break-system-packages regex==2026.9.29 \
  transformers==5.18.0 peft==0.21.2 bitsandbytes==0.50.2 accelerate==1.15.0

$G python common.py                                     # check the val chunks
$G python eval_bpb.py tiny ../part-3-training/gpu1500.pt
$G python eval_bpb.py gemma                             # base model, about 2 min
$G python finetune.py --frac 0.1 --out adapters/frac10  # about 5 min
$G python finetune.py --frac 1.0 --out adapters/frac100 # about 37 min
$G python generate.py ../part-3-training/gpu1500.pt adapters/frac100
$G python quant_check.py gpu                            # skip the slow bf16 row
```

The smaller tiny-GPT runs keep Part 3's 13.2 passes over the data:

```bash
cd part-3-training
python train.py --device cuda --steps 150 --eval-every 25 --frac 0.1 --out ../part-5-finetune/tiny_frac10
python train.py --device cuda --steps 750 --eval-every 50 --frac 0.5 --out ../part-5-finetune/tiny_frac50
```

## Expected output (abridged)

```text
3,381,794 train characters, 578 val chunks, 340,513 scored bytes
longest chunk is 256 tiny-GPT tokens (context window 256)

tiny ../part-3-training/gpu1500.pt: 1.626 bits per byte
gemma: 0.953 bits per byte

77,060 Gemma tokens -> 150 sequences of 512 -> 18 steps
peak VRAM 7,262 MiB allocated, 7,630 MiB reserved
val: 0.925 bits per byte

nf4 everywhere   1.483 bpb
nf4 + keep list  1.006 bpb
bf16 on CPU      0.925 bpb
```

| Model | 10% of train text | 50% | 100% |
|-------|------|------|------|
| tiny GPT, from scratch | 2.607 | 2.344 | 1.626 |
| Gemma 4 E4B + QLoRA | 0.925 | 0.906 | 0.865 |
| Gemma 4 E4B, no fine-tune | 0.953 | | |

## The 4-bit trap

The first version of `load_gemma()` put every linear layer in NF4. The base
model then scored 1.462 bits per byte instead of 0.953, and LoRA "improved"
it to 0.884, mostly by repairing quantization damage. `KEEP_BF16` in
`common.py` leaves the layers that 4-bit hurts most in bf16, following
Unsloth's dynamic 4-bit build of the same model. Run `quant_check.py` before
you trust a QLoRA gain on a new model.

Training times depend on your GPU. Sampled text in `generate.py` uses a
fixed seed, but GPU sampling is not bit-for-bit reproducible across
hardware or driver versions.
