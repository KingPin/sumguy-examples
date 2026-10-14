# Agent memory without a vector DB

Two small memory stores for a local LLM agent, plus a tool-calling loop that uses either one.

- `memory_files.py`: one Markdown file per memory plus a `MEMORY.md` index the agent always loads.
- `memory_fts.py`: SQLite FTS5 with BM25 ranking, upsert by key, and safe query escaping.
- `agent.py`: tool-calling loop (`remember`, `recall`, `forget`) against any OpenAI-compatible endpoint. Stdlib only (`urllib`), no `openai` package needed.
- `test_memory.py`: assert-based self-checks for both stores.

Write-up: https://sumguy.com/agent-memory-without-vector-db/

## Prerequisites and tested versions

- Python 3.14.7 (anything from 3.9 up should work; the code uses `str.removeprefix` and `list[dict]` hints)
- SQLite 3.53.4 (`sqlite3.sqlite_version`) with FTS5 compiled in, which is the default in current Python builds
- For `agent.py`: an OpenAI-compatible server with tool calling.
  - llama.cpp: start `llama-server` with `--jinja`, and use a model whose chat template supports tools.
  - Ollama: use a model tagged with tools support.

`test_memory.py` was run for real. `agent.py` was exercised against a stub server that returns one scripted tool call, to check the loop and both backends. It was not tested against a live model for this release.

## Run

```bash
python3 test_memory.py

export OPENAI_BASE_URL=http://localhost:8080/v1
export MODEL=your-model-name
python3 agent.py --backend files "I switched my editor to Helix"
python3 agent.py --backend fts   "Which editor do I use?"
```

Memory lands in `./agent_memory/` (override with `--dir`). The `files` backend puts the index in the system prompt. The `fts` backend leaves memory behind the `recall` tool.

`agent.py` sends `chat_template_kwargs: {"enable_thinking": false}` in the request body. llama.cpp passes this to the chat template. Servers that do not know the field should ignore it. Delete the line if yours rejects it.
