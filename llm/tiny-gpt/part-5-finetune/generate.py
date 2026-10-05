"""Side-by-side samples, plus a check for text the base model has memorized.

  python generate.py ../part-3-training/gpu1500.pt adapters/frac100

Every model gets the same prompts and the same sampling settings (Part 4's
"top-p 0.9, temp 0.8, penalty 1.3"). Gemma is loaded once; the LoRA adapter
is switched off for the base-model rows.
"""

import sys

import torch

from common import TINY_TOK, load_gemma, val_chunks

sys.path.insert(0, "../part-4-inference")
from cached import load  # noqa: E402
from sampling import pick  # noqa: E402

PROMPTS = [
    "It was a cold morning in Baker Street when",  # the corpus's home turf
    "Holmes picked up my laptop and",              # Holmes style, modern object
    "The capital of France is",                    # a fact, not a style
    "To restart a Docker container, you",          # nowhere near the corpus
]
SETTINGS = dict(temperature=0.8, top_p=0.9, penalty=1.3)
N_TOKENS = 40


def tiny_sample(model, prompt, greedy=False, n=N_TOKENS):
    torch.manual_seed(1)
    idx = torch.tensor([TINY_TOK.encode(prompt)], device="cuda")
    s = dict(temperature=0) if greedy else SETTINGS
    out = model.generate_cached(idx, n, pick=lambda logits, hist: pick(logits, history=hist, **s))
    return TINY_TOK.decode(out[0, idx.shape[1] :].tolist())


def gemma_sample(model, tok, prompt, greedy=False, n=N_TOKENS):
    torch.manual_seed(1)
    x = tok(prompt, return_tensors="pt").to("cuda")
    s = dict(do_sample=False) if greedy else dict(
        do_sample=True, temperature=SETTINGS["temperature"], top_p=SETTINGS["top_p"],
        repetition_penalty=SETTINGS["penalty"],
    )
    out = model.generate(**x, max_new_tokens=n, **s)
    return tok.decode(out[0, x.input_ids.shape[1] :], skip_special_tokens=True)


def oneline(text):
    return " ".join(text.split())


tiny = load(sys.argv[1], "cuda")
gemma, tok = load_gemma(sys.argv[2])
rows = [
    ("tiny GPT", lambda p, **k: tiny_sample(tiny, p, **k)),
    ("Gemma base", None),  # filled in below, with the adapter switched off
    ("Gemma + LoRA", lambda p, **k: gemma_sample(gemma, tok, p, **k)),
]

for prompt in PROMPTS:
    print(f"\n### {prompt}")
    for name, fn in rows:
        if fn is None:
            with gemma.disable_adapter():
                text = gemma_sample(gemma, tok, prompt)
        else:
            text = fn(prompt)
        print(f"{name:>13}: {oneline(text)!r}")

# Memorization: give each model 20 val passages it was never trained on and
# see whether greedy decoding reproduces the next 50 characters exactly.
chunks = val_chunks()
picks = [c for c in chunks if len(c[1]) >= 400][::10][:20]
print("\nexact 50-character continuations of 20 unseen val passages:")
for name, fn in rows:
    hits = 0
    for ctx, body in picks:
        k = body.rfind(" ", 0, 300)  # stop the prompt at a word boundary
        prompt, truth = ctx + body[:k], body[k : k + 50]
        if fn is None:
            with gemma.disable_adapter():
                text = gemma_sample(gemma, tok, prompt, greedy=True, n=24)
        else:
            text = fn(prompt, greedy=True, n=24)
        hits += text[:50] == truth
    print(f"{name:>13}: {hits}/20")
