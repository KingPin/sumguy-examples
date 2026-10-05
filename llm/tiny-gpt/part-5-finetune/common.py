"""Shared by every Part 5 script: the exact text Part 3 trained and validated
on, the fixed val chunks both models are scored on, and the Gemma loader.

Part 3 split by token id: the first 90% of ids train, the last 10% validate.
The Part 1 tokenizer decodes ids back to the original bytes, so decoding each
side gives the same split as plain text that any tokenizer can read.
"""

import pathlib
import sys

import numpy as np
import torch

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE / "../part-1-tokenizer"))
from bpe import BPE  # noqa: E402

TINY_TOK = BPE.load(HERE / "../part-1-tokenizer/tokenizer.json")
GEMMA = "google/gemma-4-E4B"  # the pretrained base model, not the -it chat version

LEAD = 200  # characters of context in front of each chunk (read, not scored)
BODY = 600  # characters scored per chunk


def _ids():
    ids = np.load(HERE / "../data/holmes_ids.npy").astype(int).tolist()
    return ids, int(len(ids) * 0.9)


def train_text(frac: float = 1.0) -> str:
    """The same prefix of the train split that Part 3's `--frac` trains on."""
    ids, split = _ids()
    return TINY_TOK.decode(ids[: int(split * frac)])


def val_chunks() -> list[tuple[str, str]]:
    """(context, body) pairs covering the whole val text exactly once.

    Bodies are cut at whitespace, so no word is split between two chunks.
    Each body gets the 200 characters before it as context. Both models read
    the same context and are scored on the same body, so the only thing that
    differs is how well each one predicts it.
    """
    ids, split = _ids()
    before, val = TINY_TOK.decode(ids[:split]), TINY_TOK.decode(ids[split:])
    chunks, i = [], 0
    while i < len(val):
        ctx = (before + val[:i])[-LEAD:]
        ctx = ctx[min(k for k in (ctx.find(" "), ctx.find("\n"), len(ctx)) if k >= 0):]  # start on a word
        j = min(len(val), i + BODY)
        # Shrink the body until context + body fit the tiny GPT's 256 tokens.
        # Plain prose fits easily; all-caps lists of book titles do not.
        while j < len(val) or len(TINY_TOK.encode(ctx + val[i:j])) > 256:
            j = max(val.rfind(" ", i + 1, j), val.rfind("\n", i + 1, j))
            if len(TINY_TOK.encode(ctx + val[i:j])) <= 256:
                break
        chunks.append((ctx, val[i:j]))
        i = j
    assert "".join(body for _, body in chunks) == val
    return chunks


# Layers that lose too much accuracy in 4-bit stay in bf16. NF4 on every
# layer took the base model from 0.93 to 1.48 bits per byte on our val text.
# This list follows Unsloth's dynamic 4-bit build of the same model.
KEEP_BF16 = [f"model.layers.{i}" for i in (0, 4, 10, 11, 22)] + \
    [f"model.layers.{i}.mlp" for i in (1, 5, 6)] + \
    [f"model.layers.{i}.self_attn" for i in (2, 3, 5, 6, 9, 23)] + \
    ["per_layer_input_gate", "per_layer_projection", "per_layer_model_projection", "lm_head"]


def load_gemma(adapter: str | None = None, keep_bf16: list[str] = KEEP_BF16):
    """Gemma 4 E4B, text only, 4-bit, sized for an 8 GB GPU.

    E4B holds 8.0B weights. 2.8B of them are the per-layer embedding table
    (262,144 tokens x 42 layers x 256), which bitsandbytes does not quantize:
    5.6 GB in bf16 on its own. It is a lookup table, so it stays in CPU RAM
    and only the looked-up rows travel to the GPU.
    """
    from transformers import AutoTokenizer, BitsAndBytesConfig, Gemma4ForCausalLM

    q = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.bfloat16,
        bnb_4bit_use_double_quant=True,
        llm_int8_enable_fp32_cpu_offload=True,  # allows the CPU-side table
        llm_int8_skip_modules=keep_bf16,
    )
    import transformers.integrations.accelerate as hf_acc

    # accelerate reads "cpu" in a device map as "store on CPU, run on GPU" and
    # copies the table to the GPU for every forward pass. That copy is the
    # 5.25 GiB we do not have. Skip its dispatch step and move only the
    # looked-up rows, with the two hooks below.
    dispatch, hf_acc.dispatch_model = hf_acc.dispatch_model, lambda *a, **k: None
    try:
        model = Gemma4ForCausalLM.from_pretrained(
            GEMMA, quantization_config=q, dtype=torch.bfloat16,
            device_map={"model.embed_tokens_per_layer": "cpu", "": 0},
            # The checkpoint is the full multimodal model. Take the text half
            # and leave the vision and audio towers on disk.
            key_mapping={r"^model\.language_model\.": "model."},
        )
    finally:
        hf_acc.dispatch_model = dispatch
    table = model.model.embed_tokens_per_layer
    table.register_forward_pre_hook(lambda m, args: tuple(a.cpu() for a in args))
    table.register_forward_hook(lambda m, args, out: out.to("cuda"))
    if adapter:
        from peft import PeftModel

        model = PeftModel.from_pretrained(model, adapter)
    return model.eval(), AutoTokenizer.from_pretrained(GEMMA)


if __name__ == "__main__":
    chunks = val_chunks()
    body_bytes = sum(len(b.encode()) for _, b in chunks)
    longest = max(len(TINY_TOK.encode(c + b)) for c, b in chunks)
    print(f"{len(train_text()):,} train characters, {len(chunks)} val chunks, {body_bytes:,} scored bytes")
    print(f"longest chunk is {longest} tiny-GPT tokens (context window 256)")
    assert longest <= 256
