"""A byte-level BPE tokenizer in about 100 lines.

Training:
  1. Split text into chunks (words, numbers, punctuation runs, whitespace)
     with a regex, so merges never cross a word boundary.
  2. Turn every chunk into a tuple of raw UTF-8 bytes (ids 0-255).
  3. Count every adjacent pair of ids across all chunks.
  4. Give the most frequent pair a new id, replace it everywhere, repeat
     until the vocabulary reaches the target size.

Encoding replays the learned merges in the order they were learned.
"""

import json
from collections import Counter

import regex

# Same idea as the GPT-2 split pattern: contractions, letter runs, digit runs,
# punctuation runs, and whitespace each become separate chunks. A leading
# space stays attached to the word after it (" Holmes", not " " + "Holmes").
SPLIT = regex.compile(
    r"""'(?:[sdmt]|ll|ve|re)| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+"""
)


def pair_counts(words: dict[tuple[int, ...], int]) -> Counter:
    counts = Counter()
    for ids, freq in words.items():
        for pair in zip(ids, ids[1:]):
            counts[pair] += freq
    return counts


def merge(ids: tuple[int, ...], pair: tuple[int, int], new_id: int) -> tuple[int, ...]:
    out, i = [], 0
    while i < len(ids):
        if i + 1 < len(ids) and (ids[i], ids[i + 1]) == pair:
            out.append(new_id)
            i += 2
        else:
            out.append(ids[i])
            i += 1
    return tuple(out)


class BPE:
    def __init__(self, merges: list[tuple[int, int]] | None = None):
        self.merges = merges or []
        self.ranks = {pair: 256 + i for i, pair in enumerate(self.merges)}
        # id -> raw bytes. The first 256 ids are the bytes themselves.
        self.vocab = {i: bytes([i]) for i in range(256)}
        for pair, new_id in self.ranks.items():
            self.vocab[new_id] = self.vocab[pair[0]] + self.vocab[pair[1]]
        self.cache: dict[str, list[int]] = {}

    @classmethod
    def train(cls, text: str, vocab_size: int, verbose: bool = False) -> "BPE":
        # Deduplicate chunks first: " the" appears ~32k times but only needs
        # to be stored once with a count. This is what keeps training fast.
        words = Counter(tuple(c.encode("utf-8")) for c in SPLIT.findall(text))
        tok = cls()
        for new_id in range(256, vocab_size):
            counts = pair_counts(words)
            if not counts:
                break
            best = max(counts, key=counts.get)
            words = {merge(w, best, new_id): f for w, f in words.items()}
            tok.merges.append(best)
            tok.ranks[best] = new_id
            tok.vocab[new_id] = tok.vocab[best[0]] + tok.vocab[best[1]]
            if verbose and (new_id < 266 or new_id % 500 == 0):
                print(f"merge {new_id:>5}: {tok.vocab[new_id]!r:<16} seen {counts[best]:,}x")
        return tok

    def _encode_chunk(self, chunk: str) -> list[int]:
        if chunk in self.cache:
            return self.cache[chunk]
        ids = tuple(chunk.encode("utf-8"))
        while len(ids) > 1:
            # Apply the earliest-learned merge present in this chunk.
            pair = min(zip(ids, ids[1:]), key=lambda p: self.ranks.get(p, 1 << 30))
            if pair not in self.ranks:
                break
            ids = merge(ids, pair, self.ranks[pair])
        self.cache[chunk] = list(ids)
        return self.cache[chunk]

    def encode(self, text: str) -> list[int]:
        return [i for chunk in SPLIT.findall(text) for i in self._encode_chunk(chunk)]

    def decode(self, ids: list[int]) -> str:
        return b"".join(self.vocab[i] for i in ids).decode("utf-8", errors="replace")

    def save(self, path: str) -> None:
        with open(path, "w") as f:
            json.dump({"merges": self.merges}, f)

    @classmethod
    def load(cls, path: str) -> "BPE":
        with open(path) as f:
            return cls([tuple(p) for p in json.load(f)["merges"]])


if __name__ == "__main__":
    # Self-check: round-trips, merges shrink the sequence, unseen text still works.
    tok = BPE.train("the cat sat on the mat. the cat ate the rat. " * 20, vocab_size=280)
    for s in ["the cat sat", "a brand-new word: zebra 🦓", ""]:
        assert tok.decode(tok.encode(s)) == s, s
    assert len(tok.encode("the cat sat")) < len("the cat sat".encode())
    print("bpe.py self-check passed")
