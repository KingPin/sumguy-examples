"""How much does 4-bit cost the base model? Scores the first 40 val chunks.

  python quant_check.py            # all three rows (bf16 on the CPU is slow)
  python quant_check.py gpu        # skip the bf16 row

nf4 everywhere   every linear layer in 4-bit
nf4 + keep list  common.KEEP_BF16 left in bf16 (what every other script uses)
bf16 on CPU      no quantization, the reference
"""

import gc
import math
import sys

import torch

from common import GEMMA, KEEP_BF16, load_gemma, val_chunks
from eval_bpb import nats

sub = val_chunks()[:40]
nbytes = sum(len(b.encode()) for _, b in sub)


def bpb(model, tok, device):
    return sum(nats(model, tok(c).input_ids, tok(b, add_special_tokens=False).input_ids, device)
               for c, b in sub) / nbytes / math.log(2)


for name, keep in [("nf4 everywhere", ["lm_head"]), ("nf4 + keep list", KEEP_BF16)]:
    model, tok = load_gemma(keep_bf16=keep)
    print(f"{name:<16} {bpb(model, tok, 'cuda'):.3f} bpb", flush=True)
    del model
    gc.collect()  # free the first model before the next one loads
    torch.cuda.empty_cache()

if sys.argv[1:] != ["gpu"]:
    from transformers import Gemma4ForCausalLM

    model = Gemma4ForCausalLM.from_pretrained(GEMMA, dtype=torch.bfloat16, device_map={"": "cpu"},
                                              key_mapping={r"^model\.language_model\.": "model."}).eval()
    print(f"{'bf16 on CPU':<16} {bpb(model, tok, 'cpu'):.3f} bpb")
