"""Part 1's embedding check, rerun on a trained model.

Before training, " Holmes" was no closer to " Watson" than to " telegram".
After training, the embedding table has been shaped by next-token
prediction. Prints the same three cosine pairs, untrained vs trained, and
the nearest neighbours of a few tokens.

  python embeddings_after.py gpu1500.pt
"""

import sys

import torch
import torch.nn.functional as F

from model import GPT, Config

sys.path.insert(0, "../part-1-tokenizer")
from bpe import BPE  # noqa: E402

tok = BPE.load("../part-1-tokenizer/tokenizer.json")
ckpt = torch.load(sys.argv[1] if len(sys.argv) > 1 else "gpu1500.pt", map_location="cpu")
cfg = Config(**ckpt["config"])
torch.manual_seed(1337)  # same init train.py starts from
untrained = GPT(cfg).emb.weight.detach()
trained = ckpt["model"]["emb.weight"]
print(f"checkpoint from step {ckpt['step']}")


def tid(word: str) -> int:
    ids = tok.encode(word)
    assert len(ids) == 1, f"{word!r} is {len(ids)} tokens"
    return ids[0]


print(f"\n{'pair':<26} {'untrained':>10} {'trained':>8}")
for a, b in [(" Holmes", " Watson"), (" Holmes", " telegram"), (" Watson", " telegram")]:
    sims = [F.cosine_similarity(w[tid(a)], w[tid(b)], dim=0).item() for w in (untrained, trained)]
    print(f"{a + ' / ' + b:<26} {sims[0]:>+10.3f} {sims[1]:>+8.3f}")

normed = F.normalize(trained, dim=1)
for word in [" Holmes", " Watson", " telegram", " London", " said"]:
    sims = normed @ normed[tid(word)]
    sims[tid(word)] = -1  # skip the word itself
    top = sims.topk(6)
    near = ", ".join(f"{tok.decode([i])!r} {s:.2f}" for s, i in zip(top.values.tolist(), top.indices.tolist()))
    print(f"\nnearest to {word!r}: {near}")
