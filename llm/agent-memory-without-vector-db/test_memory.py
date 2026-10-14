"""Run: python3 test_memory.py"""
import sqlite3
import tempfile
from pathlib import Path

from memory_files import FileMemory
from memory_fts import FtsMemory


def check(store):
    assert store.remember("editor", "User prefers Neovim", "Uses Neovim with lazy.nvim. Dislikes VS Code.") .startswith("saved")
    store.remember("db-choice", "Chose Postgres for the billing app", "Why: needs row-level locking. SQLite was rejected.")
    assert "editor" in store.index() and "db-choice" in store.index()

    hits = store.recall("which editor does the user like")
    assert hits and hits[0]["key"] == "editor", hits

    # Update by key replaces the old text instead of adding a duplicate.
    assert store.remember("editor", "User prefers Helix", "Switched to Helix in 2026.").startswith("updated")
    assert sum("editor" in l for l in store.index().splitlines()) == 1
    assert "Neovim" not in store.index()

    assert store.recall("zebra quantum") == []
    assert store.forget("db-choice").startswith("forgot")
    assert "db-choice" not in store.index()
    assert store.forget("db-choice").startswith("no memory")


with tempfile.TemporaryDirectory() as d:
    check(FileMemory(str(Path(d) / "mem")))
    fts = FtsMemory(str(Path(d) / "m.db"))
    check(fts)

    # Hostile input must not raise FTS5 syntax errors.
    fts.remember("net", "Home VPN is WireGuard", "Port 51820. Peer-to-peer mesh, not hub-and-spoke.")
    for q in ['peer-to-peer', 'say "hello', "it's", "AND", "NOT wireguard", "col:val", "(", "*", "a OR", "NEAR(x"]:
        fts.recall(q)
    assert fts.recall("peer-to-peer")[0]["key"] == "net"

    # Raw, unescaped text does crash FTS5: this is why fts_query exists.
    try:
        fts.db.execute("SELECT * FROM mem WHERE mem MATCH ?", ("peer-to-peer",)).fetchall()
        raise SystemExit("expected sqlite3.OperationalError")
    except sqlite3.OperationalError:
        pass

    # Porter stemming: "backups" matches "backup".
    fts.remember("bk", "Backup schedule", "Nightly backup at 02:00 to the NAS.")
    assert fts.recall("backups")[0]["key"] == "bk"

    # bm25: lower is better, results come back best first.
    fts.remember("w1", "WireGuard note", "wireguard wireguard wireguard config lives in /etc")
    scores = [h["score"] for h in fts.recall("wireguard")]
    assert scores == sorted(scores) and scores[0] < 0, scores

    # Paraphrase is the known miss: no shared words, no hit.
    assert fts.recall("automobile") == []
    fts.remember("car", "Daily driver", "Drives a Subaru")
    assert fts.recall("automobile") == []

print("all memory tests passed")
