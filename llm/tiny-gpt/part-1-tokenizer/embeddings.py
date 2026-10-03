"""From token ids to vectors: what an embedding layer is and what it costs.

1. An embedding lookup is plain row indexing into a (vocab_size, d_model) matrix.
2. Untrained, the rows are random noise: " Holmes" is no closer to " Watson"
   than to " telegram". Part 3 reruns this check on a trained model.
3. The table's size is vocab_size * d_model, which is why a tiny model
   wants a small vocabulary.
"""

import pathlib

import torch
import torch.nn.functional as F

from bpe import BPE

HERE = pathlib.Path(__file__).parent
tok = BPE.load(HERE / "tokenizer.json")
torch.manual_seed(0)

VOCAB, D_MODEL = len(tok.vocab), 256
emb = torch.nn.Embedding(VOCAB, D_MODEL)

# 1. Lookup == indexing == one-hot matrix multiply.
ids = torch.tensor(tok.encode("Holmes examined the telegram."))
vectors = emb(ids)
print(f"{len(ids)} token ids {ids.tolist()} -> tensor of shape {tuple(vectors.shape)}")
assert torch.equal(vectors, emb.weight[ids])
one_hot = F.one_hot(ids, VOCAB).float()
assert torch.allclose(vectors, one_hot @ emb.weight)
print("lookup matches weight[ids] and one_hot @ weight\n")


# 2. Untrained similarity is noise.
def vec(word: str) -> torch.Tensor:
    word_ids = tok.encode(word)
    assert len(word_ids) == 1, f"{word!r} is {len(word_ids)} tokens"
    return emb.weight[word_ids[0]]


for a, b in [(" Holmes", " Watson"), (" Holmes", " telegram"), (" Watson", " telegram")]:
    sim = F.cosine_similarity(vec(a), vec(b), dim=0).item()
    print(f"cosine({a!r}, {b!r}) = {sim:+.3f}")

# 3. What the table costs.
print(f"\n{'vocab':>9} {'d_model':>8} {'params':>13} {'fp32 MB':>9}")
for vocab in [4096, 50257, 100277, 200019]:
    for d in [256, 768]:
        params = vocab * d
        print(f"{vocab:>9,} {d:>8} {params:>13,} {params * 4 / 1e6:>9.1f}")
