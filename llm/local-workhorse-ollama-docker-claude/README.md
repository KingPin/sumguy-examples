# Local AI Coding Workhorse (Ollama / llama.cpp + Claude)

Self-host a small coding model in Docker, expose an OpenAI-compatible endpoint,
and wire it to Claude as a **workhorse** for mechanical grunt work (refactors,
boilerplate, renames, conversions). Claude stays the **overseer** — it scopes the
task, hands it to the local model, and reviews the diff before anything lands.
Your code never leaves the machine.

Full write-up: <https://sumguy.com/local-workhorse-ollama-docker-claude/>

This is the Tier 1 (local, free) deep-dive companion to the pattern article and
its example, [`cheap-workhorse-model-ai-coding`](../cheap-workhorse-model-ai-coding/)
(<https://sumguy.com/cheap-workhorse-model-ai-coding/>).

## What's here

| File | What it is |
|------|-----------|
| `docker-compose.ollama.yml` | Ollama backend — the recommended path. Built-in model management, OpenAI-compatible at `/v1`. |
| `docker-compose.llamacpp.yml` | llama.cpp `llama-server` backend — leaner, for running a specific GGUF you downloaded. |
| `delegate.py` | The delegation script. Sends a scoped task (+ optional file contents) to the local endpoint and prints the result. |
| `delegate.md` | A `/delegate` slash command for Claude Code that runs `delegate.py` and enforces the review step. |

## Prerequisites + tested versions

- Docker + Docker Compose
- Python 3.10+ and `pip install openai` (tested with `openai` 1.x)
- For GPU: NVIDIA drivers + the NVIDIA Container Toolkit (or `ollama/ollama:rocm` for AMD)
- A model — `gemma4:12b` is the recommended default (general-purpose, fits an 8 GB
  card, Apache 2.0). With 24 GB of VRAM, `qwen3-coder:30b-a3b` is the code-specialist
  upgrade. Any OpenAI-compatible local model works; `delegate.py` was validated
  against a Gemma 4 12B under `llama-server` and handled mechanical tasks cleanly.

## How to run it

### Ollama (recommended)

```bash
docker compose -f docker-compose.ollama.yml up -d
docker exec ollama ollama pull gemma4:12b
docker exec ollama ollama list   # verify it loaded
```

Endpoint: `http://localhost:11434/v1`

### llama.cpp

Drop a GGUF into `./models/` next to the compose file, then:

```bash
docker compose -f docker-compose.llamacpp.yml up -d
```

Endpoint: `http://localhost:8080/v1`

### Delegate a task

```bash
pip install openai

# Ollama (default)
python3 delegate.py "add type hints and a one-line docstring to each function" mymodule.py

# Point at llama.cpp instead
WORKHORSE_URL=http://localhost:8080/v1 WORKHORSE_MODEL=gemma4:12b \
  python3 delegate.py "rename UserManager to UserService" src/auth/manager.py
```

Copy `delegate.md` into `.claude/commands/` and edit the path inside it to run
`/delegate` from a Claude Code session.

## The two non-negotiables

- **Turn off the model's reasoning/thinking mode.** A reasoning model burns a huge
  invisible chain-of-thought before typing a single line — pure latency tax for
  grunt work. `delegate.py` passes `extra_body={"chat_template_kwargs":
  {"enable_thinking": False}}`, which was an **18x speedup** in testing
  (38s → 2.1s). The exact knob varies by model, so test it.
- **Always review the output.** The local model is fast, free, and dumber than
  frontier Claude. The overseer reads the diff before accepting. A workhorse that
  silently breaks something is worse than no workhorse.
