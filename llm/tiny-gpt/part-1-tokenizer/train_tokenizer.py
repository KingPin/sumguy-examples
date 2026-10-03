"""Train the series tokenizer on the Holmes corpus and show what it learned.

Usage: python train_tokenizer.py [vocab_size]   (default 4096)
Writes tokenizer.json next to this script. Parts 2-4 load that file.
"""

import pathlib
import sys
import time

from bpe import BPE

HERE = pathlib.Path(__file__).parent
CORPUS = HERE.parent / "data" / "holmes.txt"

vocab_size = int(sys.argv[1]) if len(sys.argv) > 1 else 4096
text = CORPUS.read_text(encoding="utf-8")

start = time.perf_counter()
tok = BPE.train(text, vocab_size, verbose=True)
print(f"\ntrained {vocab_size} tokens in {time.perf_counter() - start:.1f}s")

ids = tok.encode(text)
assert tok.decode(ids) == text
n_bytes = len(text.encode("utf-8"))
print(f"corpus: {n_bytes:,} bytes -> {len(ids):,} tokens ({n_bytes / len(ids):.2f} bytes/token)")

sample = "Holmes examined the telegram. It was unquestionably from Moriarty."
pieces = [tok.decode([i]) for i in tok.encode(sample)]
print(f"\n{len(pieces)} tokens: {'|'.join(pieces)}")

longest = sorted(tok.vocab.values(), key=len, reverse=True)[:10]
print("longest tokens:", [b.decode("utf-8", errors="replace") for b in longest])

if vocab_size == 4096:
    tok.save(HERE / "tokenizer.json")
    print(f"saved {HERE / 'tokenizer.json'}")
