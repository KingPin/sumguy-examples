#!/usr/bin/env python3
"""
Local workhorse delegate — sends a task to a local Ollama/llama.cpp endpoint.
Usage: python3 delegate.py "your task description" [file1.py file2.py ...]

Configure via environment variables:
  WORKHORSE_URL    OpenAI-compatible base URL (default: http://localhost:11434/v1)
  WORKHORSE_MODEL  model name (default: gemma4:12b)
"""

import sys
import os
from pathlib import Path
from openai import OpenAI

# Point at your local model server.
# Ollama:   http://localhost:11434/v1
# llama.cpp http://localhost:8080/v1
BASE_URL = os.getenv("WORKHORSE_URL", "http://localhost:11434/v1")
MODEL = os.getenv("WORKHORSE_MODEL", "gemma4:12b")

client = OpenAI(api_key="ollama", base_url=BASE_URL)


def build_context(file_paths: list[str]) -> str:
    parts = []
    for path in file_paths:
        p = Path(path)
        if p.exists():
            parts.append(f"### {path}\n```\n{p.read_text()}\n```")
        else:
            print(f"Warning: {path} not found, skipping", file=sys.stderr)
    return "\n\n".join(parts)


def main():
    if len(sys.argv) < 2:
        print("Usage: delegate.py <task> [file1 file2 ...]", file=sys.stderr)
        sys.exit(1)

    task = sys.argv[1]
    files = sys.argv[2:]

    messages = [
        {
            "role": "system",
            "content": (
                "You are a precise code assistant. When asked to modify code, "
                "output ONLY the complete updated file contents with no explanation. "
                "When asked a question, answer concisely."
            ),
        }
    ]

    if files:
        context = build_context(files)
        messages.append({"role": "user", "content": f"{task}\n\n{context}"})
    else:
        messages.append({"role": "user", "content": task})

    response = client.chat.completions.create(
        model=MODEL,
        messages=messages,
        temperature=0.1,   # low temp — we want deterministic edits, not creativity
        # If your model has a "thinking"/reasoning mode, turn it OFF for grunt work.
        # This was an 18x speedup in testing (38s -> 2s) against a reasoning-capable
        # local model. This knob is honored by llama.cpp's server; Ollama silently
        # ignores unknown extra_body fields (harmless), and the flag name varies by
        # model (some want /no_think in the prompt, some reasoning_effort). Test it.
        extra_body={"chat_template_kwargs": {"enable_thinking": False}},
    )

    print(response.choices[0].message.content)


if __name__ == "__main__":
    main()
