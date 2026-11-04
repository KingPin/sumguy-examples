"""Print cosine similarity for paraphrases and dangerous near-misses with real embedding models."""
import sys
from fastembed import TextEmbedding
from semantic_cache import cosine

PAIRS = [
    ("PARAPHRASE", "How do I restart nginx?", "What's the command to restart nginx?"),
    ("PARAPHRASE", "How do I reset my router password?", "I forgot my router password, how can I reset it?"),
    ("PARAPHRASE", "How do I renew a Let's Encrypt certificate?", "Renewing a Let's Encrypt cert, what do I run?"),
    ("PARAPHRASE", "Turn on the living room lights", "Switch on the lights in the living room"),
    ("NEAR-MISS", "How do I restart nginx?", "How do I stop nginx?"),
    ("NEAR-MISS", "How do I enable the firewall?", "How do I disable the firewall?"),
    ("NEAR-MISS", "How do I upgrade to PostgreSQL 16?", "How do I upgrade to PostgreSQL 17?"),
    ("NEAR-MISS", "How do I SSH into web01?", "How do I SSH into db01?"),
    ("NEAR-MISS", "Turn on the living room lights", "Turn off the living room lights"),
    ("NEAR-MISS", "Delete the backup from Monday", "Restore the backup from Monday"),
    ("UNRELATED", "How do I restart nginx?", "What is the capital of France?"),
]

for name in sys.argv[1:] or ["BAAI/bge-small-en-v1.5", "sentence-transformers/all-MiniLM-L6-v2"]:
    model = TextEmbedding(model_name=name)
    print(f"\n== {name} ==")
    for kind, a, b in PAIRS:
        va, vb = (list(map(float, v)) for v in model.embed([a, b]))
        print(f"{cosine(va, vb):.3f}  {kind:<10} {a!r} vs {b!r}")
