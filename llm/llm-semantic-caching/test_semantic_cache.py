"""Self-check with a deterministic fake embedder (bag of words, no model download)."""
from semantic_cache import SemanticCache

VOCAB = ["restart", "stop", "nginx", "docker", "how", "do", "i", "to", "reload"]


def fake_embed(text):
    words = text.lower().replace("?", "").split()
    return [float(words.count(w)) for w in VOCAB]


class Clock:
    t = 1000.0
    def __call__(self):
        return self.t


def test_all():
    clock = Clock()
    c = SemanticCache(fake_embed, threshold=0.99, ttl=60, clock=clock)
    sys_a, sys_b = "You are a docs bot.", "You are a pirate."

    c.put("m1", sys_a, "how do i restart nginx", "systemctl restart nginx")

    # hit: same words, different order and punctuation
    ans, sim = c.get("m1", sys_a, "How do I restart nginx?")
    assert ans == "systemctl restart nginx" and sim > 0.99

    # miss: one word differs ("stop"), similarity below threshold
    ans, sim = c.get("m1", sys_a, "how do i stop nginx")
    assert ans is None and 0 < sim < 0.99

    # namespace isolation: other system prompt and other model never share
    assert c.get("m1", sys_b, "how do i restart nginx")[0] is None
    assert c.get("m2", sys_a, "how do i restart nginx")[0] is None

    # TTL expiry
    clock.t += 61
    assert c.get("m1", sys_a, "how do i restart nginx")[0] is None
    print("ok: hit, near-miss, namespace isolation, TTL")


if __name__ == "__main__":
    test_all()
