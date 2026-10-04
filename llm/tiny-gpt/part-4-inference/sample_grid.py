"""Same checkpoint, same prompt, same seed, different sampling settings.

  python sample_grid.py ../part-3-training/gpu1500.pt "Holmes"
"""

import argparse
import sys

import torch

from cached import load
from sampling import pick

sys.path.insert(0, "../part-1-tokenizer")
from bpe import BPE  # noqa: E402

GRID = [
    ("greedy", dict(temperature=0)),
    ("temperature 0.5", dict(temperature=0.5)),
    ("temperature 1.0", dict(temperature=1.0)),
    ("temperature 1.5", dict(temperature=1.5)),
    ("top-k 40", dict(temperature=1.0, top_k=40)),
    ("top-p 0.9", dict(temperature=1.0, top_p=0.9)),
    ("greedy + penalty 1.3", dict(temperature=0, penalty=1.3)),
    ("top-p 0.9, temp 0.8, penalty 1.3", dict(temperature=0.8, top_p=0.9, penalty=1.3)),
]

ap = argparse.ArgumentParser()
ap.add_argument("checkpoint")
ap.add_argument("prompt", nargs="?", default="Holmes")
ap.add_argument("--tokens", type=int, default=60)
ap.add_argument("--seed", type=int, default=1)
args = ap.parse_args()

tok = BPE.load("../part-1-tokenizer/tokenizer.json")
model = load(args.checkpoint)
start = torch.tensor([tok.encode(args.prompt)])

for name, knobs in GRID:
    torch.manual_seed(args.seed)
    out = model.generate_cached(start, args.tokens,
                                lambda logits, idx: pick(logits, history=idx, **knobs))
    print(f"--- {name}\n{tok.decode(out[0].tolist())}\n")
