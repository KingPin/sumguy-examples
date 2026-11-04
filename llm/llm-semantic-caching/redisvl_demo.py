"""RedisVL SemanticCache with a local fastembed vectorizer. Needs Redis 8 on localhost:6391."""
from fastembed import TextEmbedding
from redisvl.extensions.cache.llm import SemanticCache
from redisvl.utils.vectorize import CustomTextVectorizer

model = TextEmbedding("sentence-transformers/all-MiniLM-L6-v2")
vec = CustomTextVectorizer(
    embed=lambda t, **kw: [float(x) for x in next(iter(model.embed([t])))],
    embed_many=lambda ts, **kw: [[float(x) for x in v] for v in model.embed(ts)],
)
# distance = 1 - cosine similarity, so 0.10 here means similarity >= 0.90
cache = SemanticCache(name="demo", vectorizer=vec, distance_threshold=0.10, ttl=3600,
                      redis_url="redis://localhost:6391", overwrite=True)
cache.store(prompt="How do I restart nginx?", response="sudo systemctl restart nginx")
for q in ["What's the command to restart nginx?", "How do I stop nginx?"]:
    hit = cache.check(prompt=q, num_results=1)
    print(q, "->", (hit[0]["response"], round(float(hit[0]["vector_distance"]), 3)) if hit else "MISS")
