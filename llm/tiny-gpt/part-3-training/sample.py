"""Generate text from a trained checkpoint.

  python sample.py gpu.pt "Holmes" --tokens 80 --temperature 0.8

Plain sampling with no KV cache, so every new token reruns the whole
context. Part 4 makes this fast and covers the sampling knobs properly.
"""

import argparse
import sys

import torch

from model import GPT, Config

sys.path.insert(0, "../part-1-tokenizer")
from bpe import BPE  # noqa: E402

ap = argparse.ArgumentParser()
ap.add_argument("checkpoint")
ap.add_argument("prompt", nargs="?", default="Holmes")
ap.add_argument("--tokens", type=int, default=80)
ap.add_argument("--temperature", type=float, default=0.8)
ap.add_argument("--seed", type=int, default=42)
args = ap.parse_args()

tok = BPE.load("../part-1-tokenizer/tokenizer.json")
ckpt = torch.load(args.checkpoint, map_location="cpu")
model = GPT(Config(**ckpt["config"]))
model.load_state_dict(ckpt["model"])
model.eval()

torch.manual_seed(args.seed)
idx = torch.tensor([tok.encode(args.prompt)])
print(tok.decode(model.generate(idx, args.tokens, args.temperature)[0].tolist()))
