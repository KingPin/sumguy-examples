"""Chunk markdown by headings, embed with Ollama, upsert into Qdrant."""
import json
import re
import uuid
from pathlib import Path

import httpx
from qdrant_client import QdrantClient
from qdrant_client.models import Distance, PointStruct, VectorParams

OLLAMA = "http://localhost:11434"
MODEL = "nomic-embed-text"  # 768 dimensions
COLLECTION = "docs"
MAX_CHARS = 1500            # ~400 tokens; nomic-embed-text handles 2048


def chunk(md: str) -> list[tuple[str, str]]:
    """Split on H1-H3. Returns (heading, text); the heading rides along in the text."""
    parts = re.split(r"(?m)^(?=#{1,3} )", md)
    out = []
    for part in parts:
        part = part.strip()
        if len(part) < 80:
            continue
        heading = part.splitlines()[0].lstrip("# ").strip()
        # Oversize sections: split on blank lines, repack under MAX_CHARS.
        buf = ""
        for para in part.split("\n\n"):
            if buf and len(buf) + len(para) > MAX_CHARS:
                out.append((heading, buf))
                buf = f"{heading}\n\n"
            buf += para + "\n\n"
        out.append((heading, buf.strip()))
    return out


def embed(texts: list[str]) -> list[list[float]]:
    r = httpx.post(f"{OLLAMA}/api/embed", json={"model": MODEL, "input": texts}, timeout=120)
    r.raise_for_status()
    return r.json()["embeddings"]


def main() -> None:
    qd = QdrantClient(url="http://localhost:6333")
    if not qd.collection_exists(COLLECTION):
        qd.create_collection(COLLECTION, vectors_config=VectorParams(size=768, distance=Distance.COSINE))

    total = 0
    for md_file in sorted(Path("pages").glob("*.md")):
        url = json.loads(md_file.with_suffix(".json").read_text())["url"]
        chunks = chunk(md_file.read_text(encoding="utf-8"))
        if not chunks:
            continue
        # nomic-embed-text wants a task prefix on documents.
        vectors = embed([f"search_document: {text}" for _, text in chunks])
        points = [
            PointStruct(
                # Stable ID: re-running overwrites instead of duplicating.
                id=str(uuid.uuid5(uuid.NAMESPACE_URL, f"{url}#{i}")),
                vector=vec,
                payload={"url": url, "heading": heading, "text": text},
            )
            for i, ((heading, text), vec) in enumerate(zip(chunks, vectors))
        ]
        qd.upsert(COLLECTION, points=points)
        total += len(points)
        print(f"{url}: {len(points)} chunks")
    print(f"upserted {total} chunks")


if __name__ == "__main__":
    main()
