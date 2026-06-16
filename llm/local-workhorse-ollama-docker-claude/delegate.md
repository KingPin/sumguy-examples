---
description: "Run a mechanical coding task using the local workhorse model."
---

Run a mechanical coding task using the local workhorse model.

Usage: /delegate <task description> [file paths]

This invokes the local model (Ollama/llama.cpp) for grunt work: refactoring,
boilerplate generation, conversions, renames. You MUST review the output before
accepting — check the diff, verify it compiles, make sure it didn't break
anything obvious.

Example:
$ARGUMENTS

Steps:
1. Run: python3 /path/to/delegate.py $ARGUMENTS
2. Review the output carefully — read every line the local model changed
3. If acceptable, apply the changes; if not, note what it got wrong and retry with clearer scope

The review step is mandatory. The workhorse is fast and cheap, not infallible;
the overseer's review is what keeps the pattern safe.
