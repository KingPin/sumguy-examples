---
description: "Delegate a mechanical coding task to a cheap workhorse model."
---

Delegate a mechanical coding task to the cheap workhorse model.

Steps:
1. Identify the scope. Tell the user which files are being sent.
2. Run the workhorse against a clearly scoped task, e.g.:
   `copilot --model <cheap-model> --yolo --silent -p "<scoped task>"`
   (Swap in whatever CLI / endpoint your workhorse uses — GitHub's `copilot`,
   a local Ollama/llama.cpp endpoint, etc. See the companion guide for the
   local-model version.)
3. Read ALL affected files after the command completes.
4. Report back — do NOT skip the file review step.

The review step in (3) is mandatory. The workhorse is fast and cheap, not
infallible; the overseer's review is what keeps the pattern safe.
