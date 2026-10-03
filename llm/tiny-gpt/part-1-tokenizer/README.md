# Part 1: Tokenizer and Embeddings

Companion code for [Train a Tiny GPT, Part 1: Tokenizers](https://sumguy.com/train-tiny-gpt-tokenizer/).

Builds a byte-level BPE tokenizer from scratch, trains it on the Holmes
corpus, compares it with OpenAI's `tiktoken` encodings, and shows what an
embedding layer does with the token ids.

| File | What it does |
|------|--------------|
| `bpe.py` | The tokenizer: train, encode, decode, save, load. `python bpe.py` runs a self-check. |
| `train_tokenizer.py` | Trains a 4,096-token vocabulary and saves `tokenizer.json` (used by later parts). |
| `compare.py` | Token counts for five snippets under ours, `gpt2`, `cl100k_base`, `o200k_base`, plus full-corpus encode speed. |
| `embeddings.py` | Embedding lookup, untrained similarity, and table size per vocabulary size. |

## Prerequisites

- Python 3.10 or newer (tested on 3.13 and 3.14)
- Setup from the [series README](../README.md): venv, requirements, `get_data.py`
- No GPU. Everything here runs on CPU.
- Tested 2026-10-03 with torch 2.14.1 (CPU build), tiktoken 0.14.0, regex 2026.9.29

## Run

```bash
cd part-1-tokenizer
python bpe.py               # self-check
python train_tokenizer.py   # about 2.5 minutes on one CPU core
python compare.py           # downloads the tiktoken encodings on first run
python embeddings.py
```

`train_tokenizer.py 1024` (or any other size) trains a different vocabulary
for comparison. Only the default 4,096 run writes `tokenizer.json`.

## Expected output (abridged)

```text
trained 4096 tokens in 140.5s
corpus: 3,793,263 bytes -> 1,030,773 tokens (3.68 bytes/token)

14 tokens: Holmes| examined| the| telegram|.| It| was| un|quest|ion|ably| from| Moriarty|.
```

```text
                      ours-4k         gpt2  cl100k_base   o200k_base
holmes prose               31           31           31           31
tech prose                 41           26           25           25
python                     61           82           36           37
compose yaml               57           59           41           41
german + emoji             44           29           20           17
```

Training time depends on your CPU. The tokens and counts are deterministic.
