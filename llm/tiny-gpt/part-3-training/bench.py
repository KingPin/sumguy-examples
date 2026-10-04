"""How batch size and precision change speed and VRAM for one training step.

  python bench.py cuda     # batch 8 to 256, fp32 vs bf16
  python bench.py cpu      # batch 8 to 64, fp32, all threads

Random tokens are fine here: the cost of a step does not depend on the text.
"""

import sys
import time

import torch

from model import GPT, Config

dev = torch.device(sys.argv[1] if len(sys.argv) > 1 else "cpu")
cfg = Config()
cuda = dev.type == "cuda"
batches = [8, 16, 32, 64, 128, 256] if cuda else [8, 16, 32, 64]
precisions = ["fp32", "bf16"] if cuda else ["fp32"]
warm, runs = (5, 20) if cuda else (2, 5)

if cuda:
    print(f"{torch.cuda.get_device_name()}, torch {torch.__version__}")
else:
    print(f"CPU, {torch.get_num_threads()} threads, torch {torch.__version__}")
print(f"{'precision':>9} {'batch':>6} {'tokens/s':>10} {'ms/step':>8} {'peak MiB':>9}")

for prec in precisions:
    for b in batches:
        torch.manual_seed(0)
        model = GPT(cfg).to(dev)
        opt = torch.optim.AdamW(model.parameters(), lr=1e-3, fused=cuda)
        x = torch.randint(cfg.vocab_size, (b, cfg.context), device=dev)
        if cuda:
            torch.cuda.empty_cache()
            torch.cuda.reset_peak_memory_stats()
        try:
            for i in range(warm + runs):
                if i == warm:
                    if cuda:
                        torch.cuda.synchronize()
                    t0 = time.perf_counter()
                with torch.autocast(dev.type, dtype=torch.bfloat16, enabled=prec == "bf16"):
                    loss = model(x, x)[1]
                opt.zero_grad(set_to_none=True)
                loss.backward()
                opt.step()
            if cuda:
                torch.cuda.synchronize()
        except torch.OutOfMemoryError:
            print(f"{prec:>9} {b:>6} {'OOM':>10}")
            del model, opt
            continue
        ms = (time.perf_counter() - t0) / runs * 1000
        peak = f"{torch.cuda.max_memory_allocated() / 2**20:,.0f}" if cuda else "-"
        print(f"{prec:>9} {b:>6} {b * cfg.context / ms * 1000:>10,.0f} {ms:>8.1f} {peak:>9}")
        del model, opt
