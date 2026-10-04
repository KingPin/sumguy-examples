# Train a Tiny GPT at Home

Companion code for the SumGuy's Ramblings series on building and training a
small GPT-style language model from scratch on home hardware.

| Part | Folder | Article |
|------|--------|---------|
| 1. Tokenizer and embeddings | [`part-1-tokenizer/`](part-1-tokenizer/) | <https://sumguy.com/train-tiny-gpt-tokenizer/> |
| 2. Attention and position | [`part-2-attention/`](part-2-attention/) | <https://sumguy.com/train-tiny-gpt-attention/> |
| 3. Model and training loop | [`part-3-training/`](part-3-training/) | <https://sumguy.com/train-tiny-gpt-training/> |
| 4. Inference: KV cache and sampling | [`part-4-inference/`](part-4-inference/) | <https://sumguy.com/train-tiny-gpt-inference/> |

Every part trains on the same corpus: nine public-domain Sherlock Holmes books
from Project Gutenberg (about 3.8 MB of text).

## Setup (once)

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install torch==2.14.1 --index-url https://download.pytorch.org/whl/cpu
pip install -r requirements.txt
python get_data.py          # writes data/holmes.txt
```

Each part's README lists what to run next.
