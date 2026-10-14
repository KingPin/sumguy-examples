"""SQLite FTS5 memory: upsert by key, safe queries, BM25 ranking. Stdlib only."""
import re
import sqlite3


def fts_query(text: str) -> str:
    """Turn free text into a safe FTS5 query: every word becomes a quoted token.

    Quoting stops hyphens, colons, quotes and words like AND/NOT/NEAR from being
    parsed as FTS5 syntax. Tokens are OR-ed so one miss does not empty the result.
    """
    words = re.findall(r"\w+", text)
    return " OR ".join(f'"{w}"' for w in words)


class FtsMemory:
    def __init__(self, path: str = "memory.db"):
        self.db = sqlite3.connect(path)
        # key is stored but not indexed (UNINDEXED), so searches only hit description/body.
        self.db.execute(
            "CREATE VIRTUAL TABLE IF NOT EXISTS mem USING fts5("
            "key UNINDEXED, description, body, tokenize='porter unicode61')"
        )
        self.db.commit()

    def remember(self, key: str, description: str, body: str) -> str:
        # FTS5 tables have no UNIQUE constraint, so upsert is delete + insert.
        cur = self.db.execute("DELETE FROM mem WHERE key = ?", (key,))
        self.db.execute(
            "INSERT INTO mem(key, description, body) VALUES (?, ?, ?)",
            (key, description, body),
        )
        self.db.commit()
        return "updated " + key if cur.rowcount else "saved " + key

    def index(self) -> str:
        rows = self.db.execute("SELECT key, description FROM mem ORDER BY key").fetchall()
        return "".join(f"- {k}: {d}\n" for k, d in rows)

    def recall(self, query: str, limit: int = 5) -> list[dict]:
        q = fts_query(query)
        if not q:
            return []
        # bm25() returns negative numbers; lower (more negative) is a better match.
        # Weights: description counts 3x the body.
        rows = self.db.execute(
            "SELECT key, description, body, bm25(mem, 0.0, 3.0, 1.0) AS score "
            "FROM mem WHERE mem MATCH ? ORDER BY score LIMIT ?",
            (q, limit),
        ).fetchall()
        return [
            {"key": k, "score": s, "text": f"description: {d}\n\n{b}"}
            for k, d, b, s in rows
        ]

    def forget(self, key: str) -> str:
        cur = self.db.execute("DELETE FROM mem WHERE key = ?", (key,))
        self.db.commit()
        return f"forgot {key}" if cur.rowcount else f"no memory named {key}"
