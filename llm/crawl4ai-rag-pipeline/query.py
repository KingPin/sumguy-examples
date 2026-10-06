"""Ask the index a question; print the top hits with source URLs."""
import sys

import httpx
from qdrant_client import QdrantClient

question = " ".join(sys.argv[1:]) or "How do I limit how fast the crawler hits a site?"
r = httpx.post(
    "http://localhost:11434/api/embed",
    json={"model": "nomic-embed-text", "input": [f"search_query: {question}"]},
    timeout=60,
)
r.raise_for_status()
qd = QdrantClient(url="http://localhost:6333")
hits = qd.query_points("docs", query=r.json()["embeddings"][0], limit=3).points
for h in hits:
    print(f"{h.score:.3f}  {h.payload['url']}  [{h.payload['heading']}]")
    print("   ", h.payload["text"][:200].replace("\n", " "), "\n")
