"""Turn the model's logits into the next token.

The model only scores every token in the vocabulary. Everything about how
"creative" or "boring" the output reads is decided here, after the model
has finished. Run it directly for the self-check.
"""

import torch


def pick(logits, temperature=1.0, top_k=0, top_p=1.0, penalty=1.0, history=None):
    """Pick one token id per row of logits (B, vocab).

    temperature  0 = always the top token; below 1 sharpens, above 1 flattens
    top_k        keep only the k highest-scoring tokens (0 = off)
    top_p        keep the smallest set of tokens whose probability adds up to p
    penalty      above 1 makes tokens already in `history` (B, T) less likely
    """
    logits = logits.float().clone()
    if penalty != 1.0 and history is not None:
        seen = logits.gather(-1, history)
        # Divide positive scores, multiply negative ones: both push the token down.
        logits.scatter_(-1, history, torch.where(seen > 0, seen / penalty, seen * penalty))
    if temperature == 0:
        return logits.argmax(-1)
    logits /= temperature
    if top_k:
        kth = logits.topk(top_k, dim=-1).values[:, -1:]
        logits[logits < kth] = float("-inf")
    if top_p < 1.0:
        sorted_logits, order = logits.sort(dim=-1, descending=True)
        cum = sorted_logits.softmax(-1).cumsum(-1)
        # Drop a token if the tokens ranked above it already reach p.
        # The top token always survives.
        drop = cum - sorted_logits.softmax(-1) >= top_p
        logits.scatter_(-1, order, sorted_logits.masked_fill(drop, float("-inf")))
    return torch.multinomial(logits.softmax(-1), 1)[:, 0]


if __name__ == "__main__":
    torch.manual_seed(0)
    logits = torch.randn(4, 4096)
    top = logits.argmax(-1)
    assert torch.equal(pick(logits, temperature=0), top)
    assert torch.equal(pick(logits, top_k=1), top)
    assert torch.equal(pick(logits, top_p=1e-9), top)

    # top_k=5 never picks outside the top 5
    top5 = logits.topk(5, dim=-1).indices
    for _ in range(200):
        assert (pick(logits, top_k=5)[:, None] == top5).any(-1).all()

    # top_p keeps tokens until the kept mass reaches p
    probs = torch.tensor([[0.5, 0.3, 0.15, 0.05]])
    picked = {pick(probs.log(), top_p=0.75).item() for _ in range(500)}
    assert picked == {0, 1}, picked

    # the penalty pushes a repeated top token below the runner-up
    two = torch.tensor([[2.0, 1.5]])
    assert pick(two, temperature=0, penalty=2.0, history=torch.tensor([[0]])).item() == 1
    print("sampling self-check passed")
