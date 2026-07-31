# Context Discipline for Local Coding Agents

Working files for running a local coding agent without drowning it in its own
context. Qwen3.6 and Gemma 4 advertise 256K-262K token windows; the people
shipping real code with them cap the working context around 32K on purpose.
These are the configs that enforce that.

Full write-up: <https://sumguy.com/local-coding-agents-context-discipline/>

## What's here

| File | What it is |
|------|------------|
| `Modelfile` | Ollama model definition pinning `num_ctx` to 32768, with a system prompt that tells the agent to ask for files rather than search for them. |
| `llama-server.sh` | llama.cpp server launcher with the context cap and an explicitly unquantized (`f16`) KV cache. |
| `context-budget.sh` | Counts the exact token cost of the files you are about to hand an agent, using the server's own tokenizer. Exits non-zero when you are over budget. |
| `AGENTS.md` | A repo instruction file written in positive framing: every rule shows the code we want, not a prohibition to avoid. |
| `subagents/*.yaml` | Role sketches for Explorer, Coder, and Tester: one job each, minimal toolset, context discarded on completion. |
| `prompts/adversarial-test-review.md` | The four-question prompt for reviewing tests in a fresh session, because an agent will always approve its own test. |
| `skills/new-service-class.md` | An example of a small focused skill file, loaded per-subtask instead of one giant instruction dump. |

## Prerequisites

- **Ollama** for the `Modelfile` path, or **llama.cpp** (`llama-server` on
  `PATH`) for the script path
- `curl` and `jq` for `context-budget.sh`
- A GGUF coding model. The examples name `qwen3.6:27b` (27B dense, roughly
  15-18 GB of RAM/VRAM). Substitute freely; nothing here is model-specific.

## How to run it

**Ollama:**

```bash
ollama create qwen-coder-32k -f Modelfile
ollama run qwen-coder-32k
```

**llama.cpp:**

```bash
chmod +x llama-server.sh
./llama-server.sh /path/to/qwen3.6-27b-instruct-q5_k_m.gguf
# CTX=16384 PORT=9090 ./llama-server.sh model.gguf   # override either
```

**Check what a file bundle actually costs before you send it:**

```bash
chmod +x context-budget.sh
./context-budget.sh src/auth.py src/models.py AGENTS.md
```

Illustrative output (your numbers depend on your files and your model's
tokenizer):

```text
  TOKENS  FILE
    1842  src/auth.py
     906  src/models.py
     598  AGENTS.md
    3346  TOTAL

Budget:    32768 tokens
Allowance: 16384 tokens (50% of budget reserved for files)
OK: 10% of the window used by files.
```

It exits `2` when the files exceed the allowance, so you can wire it into a
pre-flight check. Override with `BUDGET`, `SERVER`, and `WORKING_FRACTION`.

**Drop `AGENTS.md` at the root of your own repo** and adapt the examples to your
actual conventions. The rule that matters is not "functional-first Python", it is
that every rule ships with the code you want next to it.

## Tested versions

- llama.cpp server flags verified against upstream `tools/server/README.md`
  (2026-07): `-c/--ctx-size`, `-ctk/--cache-type-k`, `-ctv/--cache-type-v`
  (default `f16`), `-ngl/--n-gpu-layers`, `--temp`, `--top-p`
- `POST /tokenize` returns `{"tokens": [...]}`, which is what `context-budget.sh`
  counts
- `context-budget.sh` logic tested end to end (pass, over-budget, no-server,
  no-args, and missing-file paths) against a mock implementing that contract

## A note on the subagent YAML

Those files are **portable sketches, not any single product's schema.** Every
harness spells subagent definitions differently (Claude Code uses markdown with
YAML frontmatter under `.claude/agents/`, others use JSON or TOML). Copy the
three ideas, not the syntax: one job per agent, the fewest tools that job needs,
and a context that gets discarded the moment the job finishes.

## The part people skip

Capping the context is the easy half. The other half is spending roughly 80% of
your time evaluating, testing, and refactoring rather than generating, because
bad patterns self-propagate: once junk is in the codebase, the model reads it as
precedent and produces more of it. A clean repo is worth more than a clever
prompt.
