"""Hand-rolled semantic cache: embed, cosine, threshold, TTL, namespaced by model + system prompt."""
import hashlib
import math
import time


def cosine(a, b):
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return dot / (na * nb) if na and nb else 0.0


class SemanticCache:
    def __init__(self, embed, threshold=0.92, ttl=3600, clock=time.time):
        self.embed = embed          # callable: str -> list[float]
        self.threshold = threshold  # cosine SIMILARITY, higher = stricter
        self.ttl = ttl              # seconds
        self.clock = clock
        self.entries = {}           # namespace -> list of (vector, query, answer, expires_at)

    @staticmethod
    def namespace(model, system_prompt):
        return hashlib.sha256(f"{model}\x00{system_prompt}".encode()).hexdigest()

    def get(self, model, system_prompt, query):
        """Return (answer, similarity) on a hit, else (None, best_similarity)."""
        ns = self.namespace(model, system_prompt)
        now = self.clock()
        live = [e for e in self.entries.get(ns, []) if e[3] > now]
        self.entries[ns] = live  # drop expired entries on the way past
        q = self.embed(query)
        best, best_sim = None, 0.0
        for vec, _, answer, _ in live:
            sim = cosine(q, vec)
            if sim > best_sim:
                best, best_sim = answer, sim
        if best is not None and best_sim >= self.threshold:
            return best, best_sim
        return None, best_sim

    def put(self, model, system_prompt, query, answer):
        ns = self.namespace(model, system_prompt)
        self.entries.setdefault(ns, []).append(
            (self.embed(query), query, answer, self.clock() + self.ttl)
        )
