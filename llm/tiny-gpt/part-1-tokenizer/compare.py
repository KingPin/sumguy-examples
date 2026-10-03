"""Compare the homemade 4096-token BPE with OpenAI's tiktoken encodings.

Counts tokens for the same five snippets under each tokenizer, then times
encoding the whole corpus. Run train_tokenizer.py first.
"""

import pathlib
import time

import tiktoken

from bpe import BPE

HERE = pathlib.Path(__file__).parent
corpus = (HERE.parent / "data" / "holmes.txt").read_text(encoding="utf-8")

SAMPLES = {
    "holmes prose": (
        "It was a cold morning of the early spring, and we sat after breakfast "
        "on either side of a cheery fire in the old room at Baker Street."
    ),
    "tech prose": (
        "Pin the container image to a digest, mount the config read-only, and "
        "put the reverse proxy on its own Docker network."
    ),
    "python": (
        "def retry(fn, attempts=3):\n"
        "    for i in range(attempts):\n"
        "        try:\n"
        "            return fn()\n"
        "        except TimeoutError:\n"
        "            time.sleep(2 ** i)\n"
    ),
    "compose yaml": (
        "services:\n"
        "  redis:\n"
        "    image: redis:7-alpine\n"
        "    restart: unless-stopped\n"
        "    ports:\n"
        '      - "127.0.0.1:6379:6379"\n'
    ),
    "german + emoji": "Die Katze schläft auf dem Sofa. 🐈💤 Grüße aus München!",
}

ours = BPE.load(HERE / "tokenizer.json")
tokenizers = {"ours-4k": ours}
for name in ["gpt2", "cl100k_base", "o200k_base"]:
    tokenizers[name] = tiktoken.get_encoding(name)

print(f"{'':<16}" + "".join(f"{n:>13}" for n in tokenizers))
for label, text in SAMPLES.items():
    row = "".join(f"{len(t.encode(text)):>13}" for t in tokenizers.values())
    print(f"{label:<16}{row}")
print(f"{'vocab size':<16}" + "".join(
    f"{(len(t.vocab) if t is ours else t.n_vocab):>13,}" for t in tokenizers.values()))

print("\nhow each tokenizer splits the python snippet's first line:")
line = SAMPLES["python"].splitlines()[0]
for name, t in tokenizers.items():
    print(f"  {name:<12} {'|'.join(t.decode([i]) for i in t.encode(line))}")

print("\nencoding the full corpus:")
n_bytes = len(corpus.encode("utf-8"))
for name, t in tokenizers.items():
    if t is ours:
        t.cache.clear()
    start = time.perf_counter()
    n = len(t.encode(corpus))
    secs = time.perf_counter() - start
    print(f"  {name:<12} {n:>10,} tokens  {n_bytes / n:5.2f} bytes/token  {secs:6.2f}s")
