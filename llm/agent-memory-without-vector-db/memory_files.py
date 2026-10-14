"""Markdown-file memory: one fact per file plus an index the agent always loads."""
import re
import sys
from pathlib import Path


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")[:60] or "memory"


class FileMemory:
    def __init__(self, root: str = "memory"):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)

    @property
    def index_path(self) -> Path:
        return self.root / "MEMORY.md"

    def _rebuild_index(self) -> None:
        # One line per memory: "- [key](key.md): description". Rebuilt from the files.
        lines = []
        for p in sorted(self.root.glob("*.md")):
            if p.name == "MEMORY.md":
                continue
            desc = p.read_text().split("\n", 1)[0].removeprefix("description: ")
            lines.append(f"- [{p.stem}]({p.name}): {desc}")
        self.index_path.write_text("\n".join(lines) + ("\n" if lines else ""))

    def remember(self, key: str, description: str, body: str) -> str:
        key = slugify(key)
        # Same key overwrites: that is the update path.
        existed = (self.root / f"{key}.md").exists()
        (self.root / f"{key}.md").write_text(f"description: {description}\n\n{body}\n")
        self._rebuild_index()
        return f"{'updated' if existed else 'saved'} {key}"

    def index(self) -> str:
        return self.index_path.read_text() if self.index_path.exists() else ""

    def recall(self, query: str, limit: int = 5) -> list[dict]:
        # Plain substring scoring: count how many query words appear in the file.
        words = [w for w in re.findall(r"\w+", query.lower()) if len(w) > 2]
        hits = []
        for p in self.root.glob("*.md"):
            if p.name == "MEMORY.md":
                continue
            text = p.read_text()
            score = sum(text.lower().count(w) for w in words)
            if score:
                hits.append({"key": p.stem, "score": score, "text": text.strip()})
        return sorted(hits, key=lambda h: -h["score"])[:limit]

    def forget(self, key: str) -> str:
        p = self.root / f"{slugify(key)}.md"
        if not p.exists():
            return f"no memory named {key}"
        p.unlink()
        self._rebuild_index()
        return f"forgot {key}"


if __name__ == "__main__":
    m = FileMemory(sys.argv[1] if len(sys.argv) > 1 else "memory")
    print(m.index() or "(empty)")
